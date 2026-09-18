# API compatibility, HUD rework

Every game API the rework calls, and the evidence behind it. B42 is checked
against the local install
(`~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/`):
`grep` on `media/lua`, `javap -p` on `projectzomboid.jar`. There is no B41
install here, so B41 status is either PROVEN (the call appears in
`legacy/b41/mods/WeightScale`) or UNPROVEN (guarded at the call site).

| Call | B42 | B41 | Guard / fallback |
| --- | --- | --- | --- |
| `getSpecificPlayer(0)` | PROVEN (jar + lua usage) | PROVEN (legacy `WeightScale.lua`) | none needed |
| `getPlayer():getNutrition():getWeight()` | PROVEN (task spec, verified fact) | PROVEN (task spec, verified fact) | none needed |
| `obj:getSprite():getName()` | PROVEN (jar `IsoObject.getSprite`) | PROVEN (legacy `WeightScale.lua`) | none needed |
| `square:getObjects()` | PROVEN (jar `IsoGridSquare.getObjects`) | UNPROVEN | nil-checked; if missing, detection is off (`WeightScaleDetect.hasScaleSprite`) |
| `square:isSolid()` | PROVEN (jar `IsoGridSquare.isSolid`) | UNPROVEN | nil-checked with `pcall`; missing/erroring treated as walkable (`WeightScaleDetect.isWalkable`), matching the verified fact that the scale tile walks |
| `square:getCell()` / `cell:getGridSquare(x,y,z)` | PROVEN (jar `IsoObject.getCell`, `IsoCell`) | UNPROVEN | nil-checked with `pcall`; missing means adjacency is skipped, only the exact square is checked (`WeightScaleDetect.neighbours`) |
| `playerObj:getCurrentSquare()` / `:getSquare()` | PROVEN (jar `IsoMovingObject`) | UNPROVEN | tries `getCurrentSquare` then falls back to `getSquare` |
| `getTimestampMs()` | PROVEN (lua usage, e.g. `ISHotbar.lua`) | UNPROVEN | none possible (animation needs a clock); documented risk only |
| `getCore():getScreenWidth/Height()` | PROVEN (lua usage) | PROVEN (legacy `WeightScaleWindow.lua`) | none needed |
| `getTexture(path)` | PROVEN (lua usage, e.g. `ServerCommands.lua`) | UNPROVEN | nil-checked; a missing texture is simply not drawn (`WeightScaleHUD.loadTextures`) |
| `ISUIElement:derive(name)` | PROVEN (lua usage, e.g. `TensionUI.lua`) | UNPROVEN | none possible, this is how the class exists at all |
| `self:drawTexture(tex,x,y,a,r,g,b)` | PROVEN (`ISUIElement.lua:1098`) | UNPROVEN | nil-checked on the texture only; not on the method itself |
| `self:drawRect(x,y,w,h,a,r,g,b)` | PROVEN (`ISUIElement.lua:1191`) | UNPROVEN | none possible, used for every band/border rect |
| `self:drawRectBorder(x,y,w,h,a,r,g,b)` | PROVEN (`ISUIElement.lua:1219`) | UNPROVEN | `type(self.drawRectBorder) == "function"` checked (the HUD no longer defines its own method of that name, so this resolves to the inherited native one when present); falls back to `HUD:drawRectBorderFallback`, four `drawRect` calls, otherwise |
| `self:DrawTextureAngle(tex,cx,cy,angleDeg)` | PROVEN (`ISUIElement.lua:1149`, jar `UIElement.DrawTextureAngle`) | UNPROVEN | `type(self.DrawTextureAngle) == "function"` checked; if missing, the beam is drawn level (angle 0), per the task's own example fallback |
| `self:drawSubTexture(tex,sx,sy,sw,sh,x,y,w,h,a,r,g,b)` | PROVEN (`ISUIElement.lua:1043`, jar `DrawSubTextureRGBA`) | UNPROVEN | `type(self.drawSubTexture) == "function"` checked; if missing, that glyph is skipped (numeral/unit silently do not draw, no crash) |
| `self:setAlwaysOnTop(b)` | PROVEN (`ISUIElement.lua:1319`) | UNPROVEN | none possible |
| `self:onMouseDown`/`onRightMouseDown` returning `false` to pass a click through | PROVEN (jar: `onMouseDown` returns `java.lang.Boolean`) | UNPROVEN | none possible; worst case on B41 is a click just outside the readout being swallowed instead of passed through, not a crash |
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
