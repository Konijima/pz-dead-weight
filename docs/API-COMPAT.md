# API compatibility, HUD rework

Every game API the rework calls, and the evidence behind it. B42 is checked
against the local install
(`~/pzserver/`, a B42 install: `media/lua/client/Entity/` only exists on B42):
`grep` on `media/lua`, `javap -p` on `projectzomboid.jar`. There is no B41
install here, so B41 status is either PROVEN (the call appears in the 2022
B41 release, kept in git history at commit `6631165`) or UNPROVEN (guarded at
the call site).

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

DOUBT, not fixed here because it would change approved pixels: there is no
`drawSubTexture` anywhere in `~/pzserver/media/lua` (B42), and ISUIElement
derives plainly from `ISBaseObject`, so `type(self.drawSubTexture)` is `nil`
and `HUD:drawGlyphs` draws nothing. If the numeral is missing in game, that
is why. The `ISUIElement.lua:1043` reference above could not be reproduced.
