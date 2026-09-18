# API compatibility, HUD rework

Every game API the rework calls, and the evidence behind it. B42 is checked
against the local install
(`~/pzserver/`, a B42 install: `media/lua/client/Entity/` only exists on B42):
`grep` on `media/lua`, `javap -p` on `projectzomboid.jar`. There is no B41
install here, so B41 status is either PROVEN (the call appears in the 2022
B41 release, kept in git history at commit `6631165`) or UNPROVEN (guarded at
the call site).

**2026-09-18 rule for this pass:** client APIs are proven against the CLIENT
install only (`~/.local/share/Steam/steamapps/common/ProjectZomboid/`), never
against `~/pzserver/`, which is the DEDICATED SERVER's install and does not
carry the same client-only Lua (see the `drawSubTexture` correction below).

| Call | B42 | B41 | Guard / fallback |
| --- | --- | --- | --- |
| `getSpecificPlayer(0)` | PROVEN (jar + lua usage) | PROVEN (2022 release `WeightScale.lua`) | none needed |
| `getPlayer():getNutrition():getWeight()` | PROVEN (task spec, verified fact) | PROVEN (task spec, verified fact) | none needed |
| `obj:getSprite():getName()` | PROVEN (jar `IsoObject.getSprite`) | PROVEN (2022 release `WeightScale.lua`) | none needed |
| `square:getObjects()` | PROVEN (jar `IsoGridSquare.getObjects`) | UNPROVEN | nil-checked; if missing, detection is off (`WeightScaleDetect.hasScaleSprite`) |
| `playerObj:getCurrentSquare()` / `:getSquare()` | PROVEN (jar `IsoMovingObject`) | UNPROVEN | tries `getCurrentSquare` then falls back to `getSquare` |
| `getTimestampMs()` | PROVEN (lua usage, e.g. `ISHotbar.lua`) | UNPROVEN | none possible (animation needs a clock); documented risk only |
| `getCore():getScreenWidth/Height()` | PROVEN (lua usage) | PROVEN (2022 release `WeightScaleWindow.lua`) | none needed |
| `getTexture(path)` | PROVEN (lua usage, e.g. `ServerCommands.lua`) | UNPROVEN | nil-checked; a missing texture is simply not drawn (`WeightScaleHUD.loadTextures`) |
| `ISUIElement:derive(name)` | PROVEN (lua usage, e.g. `TensionUI.lua`) | UNPROVEN | none possible, this is how the class exists at all |
| `self:drawTexture(tex,x,y,a,r,g,b)` | PROVEN (`ISUIElement.lua:1098`) | UNPROVEN | nil-checked on the texture only; not on the method itself |
| `self:drawRect(x,y,w,h,a,r,g,b)` | PROVEN (`ISUIElement.lua:1191`) | UNPROVEN | none possible, used for every band/border rect |
| `self:drawRectBorder(x,y,w,h,a,r,g,b)` | PROVEN (`ISUIElement.lua:1219`) | UNPROVEN | `type(self.drawRectBorder) == "function"` checked (the HUD no longer defines its own method of that name, so this resolves to the inherited native one when present); falls back to `HUD:drawRectBorderFallback`, four `drawRect` calls, otherwise |
| `self:DrawTextureAngle(tex,cx,cy,angleDeg)` | PROVEN (`ISUIElement.lua:1149`, jar `UIElement.DrawTextureAngle`) | UNPROVEN | `type(self.DrawTextureAngle) == "function"` checked; if missing, the beam is drawn level (angle 0), per the task's own example fallback |
| `self:drawSubTexture(tex,sx,sy,sw,sh,x,y,w,h,a,r,g,b)` | PROVEN (`ISUIElement.lua:1043`, jar `DrawSubTextureRGBA`) | UNPROVEN | `type(self.drawSubTexture) == "function"` checked; if missing, that glyph is skipped (numeral/unit silently do not draw, no crash) |
| `self:setAlwaysOnTop(b)` | PROVEN but NOT USED any more (see 2026-09-18 below) | n/a | n/a |
| `self:onMouseDown`/`onRightMouseDown` returning `false` to pass a click through | WRONG AS A DESIGN, see 2026-09-18 below: the *down* return value is honoured, but the matching *up* event is consumed whatever the mod does | same | the element is now exactly the readout, so no click from elsewhere ever reaches it |
| `self:addToUIManager()` / `self:removeFromUIManager()` | PROVEN (`ISUIElement.lua`, jar `UIManager.AddUI` / `RemoveElement`, both deferred through `toAdd`/`toRemove`) | UNPROVEN | guarded by `HUD.shown`, so no double add and no remove of an absent element |
| Click rule: `Core.hitTest(mode, x, y, rect, alpha)` (pure, bench-covered) | n/a, game-independent | n/a, game-independent | idle HUD (nothing drawn) and a fully faded-out leaving frame (`alpha <= 0`) are never a hit, so the readout rectangle is not a permanent dead zone over the map when the HUD is hidden or finishing its exit |
| `getFileWriter(name, true, false)` / `getFileReader(name, bool)` | PROVEN (lua usage, e.g. `ModOptions.lua`) | UNPROVEN | every call wrapped in `pcall`; missing/erroring falls back to defaults (`WeightScalePrefs`) |
| `Events.OnGameStart`, `Events.OnResolutionChange` | PROVEN (lua usage) | UNPROVEN | none possible, these are the only hooks available |
| `Events.OnPlayerUpdate` | PROVEN (lua usage, e.g. `Steps.lua`) | UNPROVEN | `if Events.OnPlayerUpdate then ... else Events.OnTick.Add(...)` in `WeightScaleMain.lua` |
| `getNumActivePlayers()` | PROVEN (client lua, `Fishing/FishingHandler.lua:6`) | UNPROVEN | `Main.activeCount()` falls back to `1` if missing |
| `getSpecificPlayer(n)`, n > 0 | PROVEN (same call as n=0, client lua) | UNPROVEN | nil-checked per player slot throughout `WeightScaleMain.lua`/`WeightScaleDetect.lua` |
| `playerObj:getPlayerNum()` | PROVEN (`client/ISUI/ISFitnessUI.lua:324,328`) | UNPROVEN | falls back to player 0 if missing |
| `getPlayerScreenLeft/Top/Width/Height(n)` | PROVEN (`client/Hotbar/ISHotbar.lua:214-217`) | UNPROVEN | `WeightScaleHUD:anchor` falls back to `getCore():getScreenWidth/Height()` with left/top 0 |
| `playerObj:playSound(name)` | PROVEN (`client/ISUI/ISWorldObjectContextMenu.lua:1111`, jar `IsoGameCharacter.playSound(String)`) | UNPROVEN | `WeightScaleSound.lua` checks `type(playerObj.playSound) == "function"` |
| `Events.OnFillWorldObjectContextMenu` | PROVEN (`client/ISUI/ISWorldObjectContextMenu.lua:213`, `triggerEvent("OnFillWorldObjectContextMenu", ...)`) | UNPROVEN | none possible, this is the only hook for a world context menu entry |
| `test`/`ISWorldObjectContextMenu.Test`/`.setTest()` convention | PROVEN (`client/ISUI/ISBBQMenu.lua:8,28`, `client/FeedingTrough/ISUI/ISFeedingTroughMenu.lua:6`, `ISWorldObjectContextMenu.lua:125-126,178,216`) | UNPROVEN | `WeightScaleMenu.lua` follows it exactly: cheap early return when `test and ISWorldObjectContextMenu.Test`, `ISWorldObjectContextMenu.setTest()` once a scale is found on a test pass |
| `ISContextMenu:addOptionOnTop(name, target, onSelect, ...params)` | PROVEN (`client/ISUI/ISContextMenu.lua:914-928`) | UNPROVEN | `WeightScaleMenu.lua` checks `type(context.addOptionOnTop) == "function"` and falls back to `context:addOption(...)` |
| `option.iconTexture = getTexture(path)` | PROVEN (`client/ISUI/ISContextMenu.lua:880,899,906,1059-1061`, `getTexture` already PROVEN above) | UNPROVEN | same `getTexture` nil guard as the HUD textures |
| `ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, square))` | PROVEN (`client/TimedActions/WalkToTimedAction.lua:79`, used the same bare way in `client/ISUI/ISBBQMenu.lua:91,136`, `client/ISUI/Hutch/ISHutchMenu.lua:98`, `client/Farming/ISUI/ISFarmingMenu.lua:561`; no `ISTimedActionQueue.clear` first in any of those, so none is added here either) | UNPROVEN | none possible, this is the only walk-to-square primitive |
| `worldobjects:get(i):getSquare()` (context menu clicked objects) | PROVEN (jar `IsoObject.getSquare`, same pattern as `square:getObjects()` above) | UNPROVEN | nil-checked; a matching sprite with no square is skipped, same posture as `WeightScaleDetect.hasScaleSprite` |
| `obj:getFacing()` (IsoObject, reads the sprite's own `Facing` N/S/E/W tile property) | PROVEN (jar `IsoObject.getFacing`/`IsoSprite.getFacing`; lua usage `client/RestAction` chain aside, direct comparison against `IsoDirections.N/S/E/W` proven in `shared/TimedActions/ISAddTakeDispenserBottle.lua:46-67`); the property itself is PROVEN per placed tile in `media/newtiledefinitions.tiles.txt` (`location_community_medical_01_8` = `Facing = E`, `_9` = `Facing = S`) | UNPROVEN | `type(obj.getFacing) == "function"` checked in `WeightScaleDetect.facingFor`; a scale with no `Facing` (or the call missing) simply never arms a turn |
| `playerObj:faceDirection(IsoDirections.X)` | PROVEN (jar `IsoGameCharacter.faceDirection`; lua usage `client/TimedActions/ISClimbThroughWindow.lua:20`, `shared/TimedActions/ISRestAction.lua:213,241` -- the same call vanilla uses to turn a sitting/resting character toward furniture) | UNPROVEN | `type(playerObj.faceDirection) == "function"` checked in `WeightScaleDetect.updateFacing` |
| `playerObj:isPlayerMoving()` | PROVEN (jar `IsoGameCharacter.isPlayerMoving`; lua usage `client/Entity/ISUI/Controls/ISWidgetTitleHeader.lua:186`) | UNPROVEN | `type(playerObj.isPlayerMoving) == "function"` checked; missing means the queued turn is simply never consumed (safe no-op, not a crash) |
| `playerObj:isAiming()` | PROVEN (jar `IsoGameCharacter.isAiming`; lua usage `client/ISUI/ISFirearmRadialMenu.lua:320`) | UNPROVEN | `type(playerObj.isAiming) == "function"` checked; missing is simply not treated as aiming |
| `playerObj:hasTimedActions()` | PROVEN (lua usage `client/TimedActions/ISContextualActions.lua:130`) | UNPROVEN | `type(playerObj.hasTimedActions) == "function"` checked; missing is simply not treated as busy |
| Direction the player faces to read a facing scale = the SAME direction as the object's own `Facing` (task 2026-09-18, point B) | Deduced from vanilla's own "Front" sit position (`shared/TimedActions/ISRestAction.lua:150-167`: `dir = facing` when `sideStr` is nil), applied to the scale's column/beam-head side, which sits on the `Facing` side | n/a, game-independent reasoning | [doute] which side of the plate the column visually sits on is not confirmed by eye in game for either placed sprite yet; see `docs/TEST-EN-JEU.md` points 30-38 |

## B41 UNPROVEN calls, summary

Every draw primitive (`drawTexture`, `drawRect`, `DrawTextureAngle`,
`drawSubTexture`), `ISUIElement:derive`, `setAlwaysOnTop`, `getTimestampMs`,
`getTexture`, prefs file I/O, and most of `WeightScaleDetect`'s square/object
walking are B41 UNPROVEN: the old mod never touched textures, timers or file
I/O, only a label-based `ISCollapsableWindow`. There is no B41 install on this
machine to check against, so these are marked UNPROVEN rather than guessed at.
They are all long-standing, unchanged-looking core `ISUIElement`/engine calls
used throughout the shipped B42 game code, which is weak but real evidence
they predate the B41/B42 split; that is not the same as verification.

Where a nil check or `pcall` can produce a sane fallback without breaking the
feature, one is in place (see the table). Where there is no sane fallback
(the whole HUD is built on `ISUIElement:derive` and its draw primitives), the
mod simply would not render, not crash: every draw call happens after
`self.javaObject ~= nil` checks inside PZ's own wrappers, and every one of our
guarded calls is defensive on top of that.

## Sub-rectangle blits (task point 3)

`ISUIElement:drawSubTexture` takes a source rectangle and a destination
rectangle plus an RGBA tint, confirmed in the B42 jar
(`DrawSubTextureRGBA`). The glyph atlas (`glyphs.png`) is pure white-on-alpha,
so the same call also does the colour tint that the maquette does with a
separate canvas pass (`docs/maquettes/v2/js/glyphs.js` `tint()`). This means a
single atlas texture, not one PNG per glyph, is used on B42. Since
`drawSubTexture` is B41 UNPROVEN, `WeightScaleHUD:drawGlyphs` checks
`type(self.drawSubTexture) == "function"` before every call and skips the
glyph rather than throwing; on a B41 install where that turns out to be
missing, the numeral and unit simply would not draw, which is the intended
degraded state.

## 2026-09-18, why right click died everywhere (and what changed)

Measured on `~/pzserver` (B42), `javap -c -p` on `java/projectzomboid.jar`:

- `zombie.ui.UIManager.updateMouseButtons` walks the UI list top down for each
  button, and for every element whose `isOverElement(...)` says the cursor is
  inside it, calls `onConsumeMouseButtonUp(button, x, y)`. If that returns
  true, local 3 (right button) is set.
- Back in the same method, offsets `755..765`: `Mouse.isRightReleased()` then
  `iload_3 / ifne 812`, which skips *both* `OnRightMouseUp` and
  `OnObjectRightMouseButtonUp`.
- `ISObjectClickHandler.lua:455` registers the world context menu on
  `OnObjectRightMouseButtonUp`, so that gate is the whole context menu.
- `zombie.ui.UIElement.onRightMouseUp` offsets `425..438`: it calls the Lua
  `onRightMouseUp` through `LuaCaller.protectedCallBoolean` and returns
  `Boolean.TRUE` when the result is null. `KahluaThread.pcallBoolean` returns
  null unless the Lua function returned an actual boolean, and the inherited
  `ISUIElement:onRightMouseUp` (`ISUIElement.lua:1323`) has an empty body.

So a full screen element consumed every right release in the game, however
its `onRightMouseDown` answered. The fix is structural: the element is exactly
the readout rectangle and is only in the UI manager while the readout is on
screen.

`setAlwaysOnTop` was dropped: `ISUIElement:setAlwaysOnTop` is a no-op while
`self.javaObject` is nil, and the old code called it in `HUD.new`, before
`addToUIManager` instantiated the java object. The approved look therefore
never had it, and dropping the call keeps the rendering identical.

CORRECTED 2026-09-18 (was a false doubt): the previous pass looked for
`drawSubTexture` in `~/pzserver/media/lua`, which is the DEDICATED SERVER's
install, not the client's -- a different install with different client-only
Lua. It does not carry `media/lua/client/ISUI/ISUIElement.lua` at all in a
form comparable to the client's. Checked instead against the CLIENT install,
`~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/media/lua/client/ISUI/ISUIElement.lua:1043`:

    function ISUIElement:drawSubTexture(texture, subX, subY, subW, subH, x, y, w, h, a, r, g, b)

`drawSubTexture` is PROVEN there, matching the signature `WeightScaleHUD.lua`
already calls it with. The glyph atlas draws on B42 after all; the guard
(`type(self.drawSubTexture) == "function"`) stays in place regardless, since
B41 is still UNPROVEN and a missing method there must still degrade
gracefully rather than error.

## 2026-09-18, splitscreen and step on/off sounds (task point A/B)

Every local player, not only player 0 (client install, per the rule above):

- `getNumActivePlayers()` -- PROVEN, `client/Fishing/FishingHandler.lua:6`,
  `client/ISUI/ISPostDeathUI.lua:79`, `client/ISUI/ISInventoryPage.lua:1331`.
- `getSpecificPlayer(n)` for `n` beyond 0 -- PROVEN, same call already used
  for player 0; nothing in its usage elsewhere is player-0-specific.
- `playerObj:getPlayerNum()` -- PROVEN, `client/ISUI/ISFitnessUI.lua:324,328`.
- `getPlayerScreenLeft/Top/Width/Height(n)` -- PROVEN,
  `client/Hotbar/ISHotbar.lua:214-217`, `client/PZAPI/ui/atoms/Node.lua:118-119`,
  `client/ISUI/ISFirearmRadialMenu.lua:226-229`. With one local player these
  return `0, 0, screenWidth, screenHeight`, so `WeightScaleHUD:anchor`
  collapses to the exact same anchor it always used (bench-covered).
  B41 UNPROVEN; guarded, falls back to `getCore():getScreenWidth/Height()`
  with left/top at 0 (today's single-player formula) if any of the four are
  missing.
- `playerObj:playSound(name)` -- PROVEN,
  `client/ISUI/ISWorldObjectContextMenu.lua:1111`,
  `client/ISUI/ISInventoryPage.lua:1031` (`getSpecificPlayer(n):playSound(...)`),
  also `IsoGameCharacter.playSound(String): long` in the client jar
  (`javap -p`). B41 UNPROVEN; `WeightScaleSound.lua` checks
  `type(playerObj.playSound) == "function"` before calling it.
- Sound script `is3d` field -- confirmed on `zombie.audio.GameSound` in the
  client jar (`javap -p zombie.audio.GameSound`: `public boolean is3d;`).
  `sounds_weightscale.txt` sets `is3D = false` on both clips so the engine
  gives them no world-space distance/radius at all, unlike CeroSec's `is3D`
  machine sounds -- the mod must not attract zombies, and a non-3D clip has
  no `distanceMax` to propagate on.

## 2026-09-18, "Step on Scale" context menu option (task point B)

New module `WeightScaleMenu.lua`, hooked on `Events.OnFillWorldObjectContextMenu`
(client install, `~/.local/share/Steam/steamapps/common/ProjectZomboid/`, per
the rule above):

- The `test` convention: `ISWorldObjectContextMenu.lua:143-216` calls every
  handler once with `test == true` before the real pass, purely to answer
  "would any handler add an option" (used for controller users, `line 122`
  comment). `ISBBQMenu.lua:8` and `ISFeedingTroughMenu.lua:6` both open with
  `if test and ISWorldObjectContextMenu.Test then return true end` -- a cheap
  early return once some earlier handler already confirmed a menu will show
  -- then do their real scan, and only call `ISWorldObjectContextMenu.setTest()`
  (`ISWorldObjectContextMenu.lua:125-126`, sets the shared flag and returns
  `true`) once they know they would add an option. `WeightScaleMenu.lua`
  follows the same shape.
- `ISContextMenu:addOptionOnTop(name, target, onSelect, ...)` --
  `client/ISUI/ISContextMenu.lua:914-928`: rebuilds `self.options` shifted by
  one and inserts the new option at index 1, same parameter list as
  `addOption`. PROVEN on B42; UNPROVEN on B41 (no B41 install here), so
  `WeightScaleMenu.lua` checks `type(context.addOptionOnTop) == "function"`
  and falls back to `context:addOption(...)` (bottom of the list) if absent.
- `option.iconTexture = getTexture(path)` -- `ISContextMenu.lua:880` (nilled
  by `addOption`), `:899` (`addColorBoxOption`), `:906` (`addDebugOption`,
  `getTexture(...)` directly), `:1059-1061` (drawn with
  `drawTextureScaledAspect` when set). Same `getTexture` call the HUD
  textures already use (`WeightScaleHUD.lua`), same texture path convention
  (`media/textures/WeightScale/weightscale_icon.png`), loaded once and
  cached in a module-level local (`WeightScaleMenu.lua`'s `_icon`), never
  per menu open (bench-covered, `tests/menu_spec.lua` point 7).
- `option.onSelect(option.target, option.param1, ...)` --
  `ISContextMenu.lua:70,145,259`: called as a plain function with `target` as
  its first argument, not as a method on `target`. `WeightScaleMenu.lua`'s
  `onSelect(playerObj, square)` matches that call shape exactly
  (`context:addOption(label, playerObj, onSelect, square)`).
- `ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, square))` --
  class defined in `client/TimedActions/WalkToTimedAction.lua:79`
  (`function ISWalkToTimedAction:new(character, location, ...)`), added bare
  (no `ISTimedActionQueue.clear` first) the same way vanilla's own
  convenience "walk here and do X" menu options do it:
  `client/ISUI/ISBBQMenu.lua:91,136`, `client/ISUI/Hutch/ISHutchMenu.lua:98`,
  `client/Farming/ISUI/ISFarmingMenu.lua:561`. `ISTimedActionQueue.clear` is
  only used elsewhere for actions that must pre-empt whatever the player is
  already doing (map click-to-walk, world map, inventory context menu), which
  is not this option's job, so `WeightScaleMenu.lua` does not clear the queue
  either.
- Detection scan reuses `WeightScale.Detect.spriteNames` (one source, already
  defined in `WeightScaleDetect.lua`): the clicked `worldobjects` list, then
  each matching object's own `:getSquare()` (`IsoObject.getSquare`, same jar
  evidence class as `square:getObjects()` above), nil-guarded throughout.
  Stops scanning at the first match, so the option is never added twice.
- Translations: single source `src/translate/strings.json` (`KEY: {EN, FR}`),
  generated by `tools/gen-translate.py` into each build's own format
  (`tools/sync.sh` calls it; `tools/check-sync.sh` regenerates to a temp dir
  and diffs). **B42 reads JSON, not the legacy `.txt`, and there is no `.txt`
  fallback** -- corrects the previous version of this section, which had
  shipped `ContextMenu_EN.txt`/`ContextMenu_FR.txt` into the `42/` tree too.
  Proof, gathered against this machine's installed B42 client
  (`~/.local/share/Steam/steamapps/common/ProjectZomboid`):
  - `javap -v` on `zombie/core/Translator.class` (`projectzomboid.jar`) shows
    the path format string `"%s/media/lua/shared/Translate/%s/%s.json"` built
    with `org.json.JSONObject`/`JSONParserConfiguration`; no `.txt` pattern
    appears anywhere for per-category translation loading (the only `.txt`
    string constants in the class are unrelated report templates like
    `"ItemName_\u0001.txt\r\n"`, used for generating a missing-translation
    report, not for loading a mod's own strings).
  - The vanilla files themselves, e.g.
    `media/lua/shared/Translate/EN/ContextMenu.json`, are flat
    `{"KEY": "value", ...}` JSON, 4-space indent, UTF-8, no BOM, trailing
    newline; no legacy `.txt` exists anywhere under vanilla's `Translate/`.
  - `~/Zomboid/mods/CeroSec` (another B42 mod on this machine, read-only
    reference) ships the exact same shape:
    `42/media/lua/shared/Translate/{EN,FR}/ContextMenu.json`, matching the
    jar's path format and confirming this is the mod convention too, not
    just vanilla's.
  - No Workshop mod under
    `~/.local/share/Steam/steamapps/workshop/content/108600/` with a `42/`
    folder ships a `Translate/` directory at all, so none contradicts this.

  Chosen layout per build (both generated, never hand-edited):
  - B41 (unchanged, still the format its client reads): root
    `media/lua/shared/Translate/{EN,FR}/ContextMenu_{EN,FR}.txt`,
    `ContextMenu_<LANG> = { KEY = "value", }` Lua-table format, CRLF line
    endings, ASCII encoding -- matches the old B41 release's own file at git
    history commit `6631165`; safe only while every string stays ASCII (the
    bench in `tests/translate_spec.py` asserts this and fails loudly the day
    a non-ASCII FR string is added, since B41's `.txt` reader was never
    proven against non-ASCII bytes).
  - B42: `42/media/lua/shared/Translate/{EN,FR}/ContextMenu.json`, flat
    `{"KEY": "value"}`, 4-space indent, UTF-8, no BOM -- matches vanilla and
    CeroSec exactly, so FR accents (when added) round-trip losslessly; no
    `.txt` is shipped in the `42/` tree.

  `getText("ContextMenu_WeightScale_StepOn")` resolves against whichever of
  these the running build loaded. `getText` is used with a plain string
  fallback (`WeightScaleMenu.lua`) in case a runtime is missing it, matching
  every other B41-UNPROVEN guard in this file.

## 2026-09-18, Info tab shows the weight category in words

Owner's request (task 2026-09-18): the Info tab's "Weight 80" line must show
the weight CATEGORY in vanilla's own words, not the number, so a player needs
a scale to know the number.

- `ISCharacterScreen.render` -- PROVEN (client install,
  `media/lua/client/XpSystem/ISUI/ISCharacterScreen.lua:74`). Lines 116-130
  draw the label (`drawTextRight`), the number (`drawText`), then any of
  three trend textures (`drawTexture`) computed from `weightStr`'s measured
  width, a local inside `render()` out of reach from outside.
- `self:drawTextRight(text,x,y,r,g,b,a,font)` / `self:drawText(...)` -- PROVEN,
  same file, same lines; these are the panel's OWN methods (inherited via
  `ISPanel`/`ISUIElement`), reassignable per-instance like any Lua table
  field -- the same "shadow it on the instance" shape already used
  nowhere else in this mod but common PZ mod practice (e.g. UI element method
  overrides throughout vanilla's own `ISUIElement` subclasses).
- `self:drawTexture(tex,x,y,a,r,g,b)` -- already PROVEN above (HUD table).
- `getText("IGUI_char_Weight")` -- PROVEN, resolves via the client's own
  `Translate/EN/IG_UI.json` (label used unmodified, only as a match key).
- The five word keys, PROVEN in the client install's
  `media/lua/shared/Translate/EN/UI.json`:
  `UI_trait_emaciated` = "Emaciated", `UI_trait_veryunderweight` = "Very Low
  Weight", `UI_trait_underweight` = "Low Weight", `UI_trait_overweight` =
  "High Weight", `UI_trait_obese` = "Very High Weight" (lines 383-423). These
  are vanilla's own five weight-trait names, so every game language gets a
  correct word for free through `getText`.
- Normal band: no vanilla weight-specific term exists (checked `UI.json`,
  `IG_UI.json`, `Tooltip.json`, `Moodles.json`: only unrelated "Normal"
  strings for temperature, fish abundance, chum, item type, starter
  condition, option screens). Added this mod's own key
  `IGUI_WeightScale_Normal` (EN/FR "Normal") to `src/translate/strings.json`.

**Technique, and why it is safe.** `ISCharacterScreen.render` is one long
vanilla function drawing several other labelled numbers with the same font
and colour (Zombies Killed, Survived For, ...), so matching the patch by
string or by numeric value is wrong -- a Zombies Killed count equal to the
weight number must not be swapped. `WeightScaleCharScreen.lua` instead wraps
`ISCharacterScreen.render` once at load and, only for the duration of that
one call, shadows the instance's own `drawTextRight`/`drawText`/`drawTexture`.
It watches for the exact vanilla weight LABEL text; the very next `drawText`
call after it is, by vanilla's own source order (proven above), always the
weight value and nothing else -- so the discrimination is by draw ORDER, not
by content. The trend texture's x is recomputed from the word's own cached
measured width (`getTextManager():MeasureStringX`) instead of vanilla's
number-based one, so a longer word never collides with the arrow. The three
instance methods are restored via `pcall`/re-raise even if vanilla's own
`render()` throws. The word (and its measured width) is cached per
`ISCharacterScreen` instance and recomputed only when `WeightScale.Core
.bandOf` returns a different band id, so a player standing still in one band
costs zero extra table/closure allocation per frame; the three trap
functions themselves are created once at module load, not per render call.

**Fail-safe (task point 5).** `WeightScale.CharScreen.install()` checks, in
order: `ISCharacterScreen` is a table, `ISCharacterScreen.render` is a
function, `getText`/`getTextManager` are functions, and
`getText("IGUI_char_Weight")` resolves to a non-empty string. If any check
fails (another build, or another mod replacing the Info tab), `install()`
returns `false` and does nothing further: vanilla stays completely untouched.

**B41 status: UNPROVEN, no B41 install on this machine.** Everything this
patch touches -- `ISCharacterScreen`, its `render()`, `drawTextRight`/
`drawText`/`drawTexture`, `getText`, `getTextManager` -- is client-only UI
plumbing with no equivalent check possible here (same posture as every other
B41-UNPROVEN row above). The fail-safe guard is exactly what covers this: on
a B41 client where any of these differs or is missing, `install()` returns
`false` and the Info tab renders exactly as vanilla ships it, number and all.

Bench: `tests/charscreen_spec.lua`, stubs built strictly from the proven
lines above (same method names, same call signatures, same field names,
same draw order and the same Zombies-Killed-equals-weight hazard a
value-based patch would get wrong).
