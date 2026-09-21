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
| `getCore():getRealOptionSoundVolume()`, `playerObj:playSoundLocal(name)`, `playerObj:getEmitter():setVolume(handle, v)` | PROVEN (client decompiled source: `Core.getRealOptionSoundVolume` = the Sound Volume option / 10, the option `client/OptionScreens/MainOptions.lua:1908-1922` edits; `IsoGameCharacter.playSoundLocal` -> `CharacterSoundEmitter.playSoundImpl`, no network; `CharacterSoundEmitter.setVolume(long, float)`). The slider only drives the Studio VCA `vca:/Settings_Sfx`, mod .ogg files play on `channelGroupInGameNonBankSounds` outside it, so the cue applies the slider itself. Confirmed by ear 2026-09-20: Sound Volume 0 did not silence the cue before | UNPROVEN | every call guarded with `type(x) == "function"`; a missing one means full volume / plain `playSound` |
| `playerObj:getModData()` + `playerObj:transmitModData()` (relay of a player's body and carried kg, fields `DeadWeightBody` and `DeadWeightCarried`; the regular stat syncs do not carry the Nutrition weight, so a remote body read from Nutrition alone drifts stale) | PROVEN by decompiled source (`IsoObject.transmitModData` sends `ObjectModDataPacket` on a client, `MovingObject` type 2 resolves the player by online id, the server relays with `sendToRelativeClients`, the receiver loads the table; vanilla uses it in `IsoPlayer.setUnwanted`, `ISHotbar.lua`) | UNPROVEN | guarded with `type(x) == "function"`, sent only when `isClient()`; not yet confirmed between two real clients |
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
| Direction the player faces to read a facing scale = the OPPOSITE of the object's own `Facing` (task 2026-09-18, point B) | Confirmed in game for one placed scale (character stood on the plate with its back to the column when facing `Facing` itself, so `Detect.facingFor` now inverts with an explicit N<->S/E<->W table); corrects the earlier deduction from vanilla's "Front" sit position, which is now false | PROVEN for the tested placement | Unverified: the other placed sprite's orientation is not yet confirmed by eye in game; see `docs/TEST-EN-JEU.md` points 30-38 |
| `square:getMovingObjects()` (occupants of one tile) | PROVEN (client decompiled source `IsoGridSquare.getMovingObjects`, returns `ArrayList<IsoMovingObject>`; dead bodies are not in it, they are `IsoDeadBody` objects) | UNPROVEN | `type(square.getMovingObjects) == "function"` checked in `WeightScaleOccupants.read`; missing means the viewer alone reads its own weight, as before this feature |
| `instanceof(obj, "IsoAnimal" / "IsoZombie" / "IsoPlayer")` | PROVEN (client lua, e.g. `client/ISUI/Animal/ISButcherHookUI.lua:557`; `IsoAnimal extends IsoPlayer`, so it is tested first) | UNPROVEN (`IsoAnimal` does not exist on B41: the test is simply false) | `type(instanceof) == "function"` checked in `WeightScaleOccupants` |
| `player:getNutrition():getWeight()` on a REMOTE player (MP) | PROVEN as readable (vanilla `IsoPlayer.java` reads it on other players, and `PlayerStatsPacket`/`SyncPlayerStatsPacket` carry Nutrition); sync cadence UNPROVEN, a slightly stale value is accepted | same as the local read above | nil-checked per call; an unreadable occupant is skipped |
| `animal:getData():getWeight()` | PROVEN (client decompiled source `IsoAnimal.getData()` returns `AnimalData`, `AnimalData.getWeight()` float); Nutrition is NOT the animal's weight | n/a (no animals on B41) | `type(...) == "function"` checked at both steps, nil weight skipped |
| `zombie:getOnlineID()` / `zombie:getID()` (zombie weight key) | PROVEN (client decompiled source `IsoZombie.getOnlineID()`, `-1` until MP assigns one; `IsoMovingObject.getID()`, a per session counter). `getPersistentOutfitID()` is NOT used: it encodes female bit, outfit index `<< 16` and a seed variant 1..500 (`PersistentOutfits.java`), so zombies in the same outfit collide | UNPROVEN | `type(...) == "function"` checked; the id falls back to `0` (same weight) if neither call answers. In SP `getID()` is a per session counter, not proven stable across save/reload, so a zombie's invented weight may change after a load (accepted). In MP every client zombie carries a server assigned `onlineId >= 0`, so both clients take the same branch; the `-1` state is only transient |
| `character:isDead()` (skip dead occupants) | PROVEN (jar `IsoGameCharacter.isDead`, lua usage `WeightScaleMain.pruneInactive`) | UNPROVEN | `type(o.isDead) == "function"` checked; missing is treated as alive |
| `getCell():getGridSquare(x, y, z)` (3x3 scan around the viewer) | PROVEN (client decompiled source `IsoCell.getGridSquare(int,int,int)`, ubiquitous in vanilla lua) | UNPROVEN | `type(getCell) == "function"` and `type(cell.getGridSquare) == "function"` checked; missing or an unloaded square finds no scale |
| `square:getX()/getY()/getZ()` | PROVEN (client decompiled source `IsoGridSquare`, int) | UNPROVEN | `type(...) == "function"` checked in `WeightScaleDetect.findScale` |
| `square:getRoom()` (same room rule; nil == nil counts as the same room) | PROVEN (client decompiled source `IsoGridSquare.getRoom`, returns the `IsoRoom` instance, compared by reference) | UNPROVEN | `type(square.getRoom) == "function"` checked; missing reads as no room |
| `player:getInventory():getContentsWeight()` (carried mass, sandbox `WeighCarried`) | PROVEN (client decompiled source `ItemContainer.getContentsWeight` ~line 2078 sums `InventoryItem.getUnequippedWeight()` of every item, i.e. actual weight + contents, so worn items and bags with contents count at 100%). NOT `getInventoryWeight` (worn at 30%) and NOT `getCapacityWeight` (0 for unlimited carry admins). 1 unit = 1 kg | UNPROVEN | `type(...) == "function"` at both steps in `WeightScaleOccupants.carriedWeight`; missing reads 0 (body only). Local players only (`isLocalPlayer`), see the remote row below |
| `player:isLocalPlayer()` | PROVEN (client decompiled source `IsoPlayer.isLocalPlayer`, boolean) | UNPROVEN | `type(o.isLocalPlayer) == "function"` checked; missing is treated as remote (body only) |
| Remote player carried mass (MP) | NOT READABLE: a remote player's backpack contents are not replicated to this client, `getInventory()` would read an empty bag | same | never read; `Occupants.remoteLoad(player)` returns 0 and is the seam for a client/server relay (follow up task) |
| `square:getWorldObjects()` (floor items of a tile) | PROVEN (client decompiled source `IsoGridSquare.getWorldObjects()` returns `ArrayList<IsoWorldInventoryObject>`, a Java list: 0-based `size()`/`get(i)`) | UNPROVEN | `type(square.getWorldObjects) == "function"` checked in `WeightScaleOccupants.floorWeight`; missing counts 0 |
| `worldObject:getOffX()` / `getOffY()` (where a floor item lies inside its square, 0..1) | PROVEN (client decompiled source `IsoWorldInventoryObject.getOffX/getOffY` return the `xoff`/`yoff` floats, the same offsets the item is rendered at; a zero offset is randomised at creation) | UNPROVEN | `type(...) == "function"` checked in `WeightScaleOccupants.onPlate`; missing or non numeric counts the item, as the whole tile did before. Only items within `Occupants.plateHalf` (0.28) of their sprite's plate centre per axis count (`WeightScale.Scales` plate centres, option `DeadWeight.WholeSquare`, default off, nil reads as off). The two centres were measured from the sprite art in `Tiles2x.pack` (`location_community_medical_01_8` plate centre 0.33,0.43; `_9` 0.48,0.37, plate top taken 4 px above the ground), not by eye; an unknown sprite falls back to the tile middle. The other scale sprites in the tileset (`_120`/`_121`, map decoration only: `solidtrans`, no `IsMoveAble`, not walkable) are not recognised by the mod |
| `worldObject:getOffZ()` / `setOffset(x, y, z)` (lift a floor item onto the plate) | PROVEN (client decompiled source `IsoWorldInventoryObject.getOffZ` returns `zoff`; `setOffset(float,float,float)` sets the three offsets, calls `syncIsoObject(false, 1, ...)` which transmits them, and invalidates the render chunk; vanilla drops at `getApparentZ`, which only knows marked surfaces, so an item dropped on the plate gets z 0 and hides under it) | UNPROVEN | all four functions checked with `type(...) == "function"` in `WeightScaleOccupants.liftOntoPlate`; missing means no lift, the item still counts. Runs whenever `WholeSquare` is off (whatever `WeighCarried` says), once per item (already at `Occupants.plateTop` is skipped). Every client polling the scale may send the same offset once; MP behaviour of that write is untested in game |
| `player:getPrimaryHandItem()` / `getSecondaryHandItem()` + `instanceof(item, "AnimalInventoryItem")` (a carried animal, menu option "Put Animal on Scale") | PROVEN (client lua `shared/TimedActions/Animals/ISPutAnimalInHutch.lua`: the carried animal is an `AnimalInventoryItem` in the primary hand) | n/a (no animals on B41: `instanceof` is false, the option never appears) | `type(instanceof) == "function"` and `type(playerObj[getter]) == "function"` checked in `WeightScaleMenu.heldAnimal` |
| Place the held animal: `luautils.walkAdj(player, square, false, {square})`, `ISUnequipAction` "place", `ISDropWorldItemAction` with `isPlaceItem = true` | PROVEN for ordinary items (vanilla `ISPlace3DItemCursor.lua` queues exactly this). UNPROVEN for an animal item: vanilla places animals only through the inventory Drop (transfer to the floor container, at the player's own square). `IsoGridSquare.AddWorldInventoryItem` handles `AnimalInventoryItem` (spawns an `IsoAnimal` at square x + 0.5, y + 0.5, ignoring the offsets, plays `put_down`), so the drop should work; in MULTIPLAYER `ISDropWorldItemAction:complete` runs on the server with `transmit = false` and the animal branch only sends its `DropAnimal` packet when `transmit` is true, so other clients may not see it (UNPROVEN, test with two clients) | n/a | the option is hidden without an `AnimalInventoryItem` in hand; nothing is queued if no square next to the scale is reachable |
| `character:faceLocation(x, y)` / `character:shouldBeTurning()` (turn towards the scale before the animal drop) | PROVEN (vanilla `ISPutAnimalInHutch.lua` faces in `waitToStart`, which returns `shouldBeTurning()`, and again in `update`; `faceLocation` is used by many shared timed actions, e.g. `ISPlowAction.lua`). Applied as instance overrides of `waitToStart`/`update` on the client's `ISDropWorldItemAction`, so the server's own copy is untouched. UNPROVEN in game for the drop action | n/a | none needed, the calls are the vanilla ones |
| The dropped animal is on the plate | PROVEN by source reading only: `new IsoAnimal(cell, x, y, z)` puts it at x + 0.5, y + 0.5 (`IsoGameCharacter` constructor), the tile middle, inside the plate box of both sprites (`WeightScale.Scales` entries, half size 0.28); it then wanders like any animal unless held (next row) | n/a | none needed |
| `animal:getBehavior():setBlockMovement(bool)` and `animal:getAnimalID()` (hold the dropped animal on the plate for `Menu.holdMs`, 3.5 s) | PROVEN as callable from client lua (vanilla `ISAnimalContextMenu.lua:89,495` calls `setBlockMovement(true)`; decompiled `BaseAnimalBehavior.setBlockMovement` stops all movement and blocks wandering, `getAnimalID` is the `animalId` int that `IsoAnimal.copyFrom` copies from the item's animal to the spawned one). The game's own release is `blockedFor >= 8000` behaviour ticks, far longer than 5 s, so the mod releases it itself. Confirmed in single player (2026-09-20): the flag alone does NOT keep the animal on the plate (26 pin corrections in 5 s (first test, hold was 5 s), cause not known), but with the pin it stays for the whole hold, its walk animation still playing, long enough to read the weight; so while held the animal is also pinned: it is first moved to the plate centre of its scale sprite (`Occupants.plateCentre`, the tile middle it spawns at is only near it), then each tick, if `getX/getY` drifted from that spot, `setX/setY` (+ `setNextX/Y`, `setLastX/Y`) put it back and `stopAllMovementNow()` runs (skipped on an MP client). The mod prints `[DeadWeight] animal held/released/never seen` lines to console.txt to diagnose. UNPROVEN in game; in MULTIPLAYER the server owns the animal, so both the block and the pin from a client may do nothing | n/a | `type(...) == "function"` checked; the tick handler is registered only while a drop is pending, checks every 6 ticks and gives up after 30 s if the drop never happens |
| `character:getX()` / `getY()` vs `square:getX()` / `getY()` (is the character on the plate) | PROVEN (client decompiled source `IsoMovingObject.getX/getY` floats in world units, `IsoGridSquare.getX/getY` ints; a square spans `[x, x+1)`) | UNPROVEN | `type(...) == "function"` and number checks in `Occupants.onPlate`; anything that cannot tell counts. Detect passes the viewer's own plate state as `selfOn`, so the step cue follows the plate, not the square |
| `SandboxVars.DeadWeight.WholeSquare` (boolean, default false) | PROVEN the same way as `WeighCarried` (`sandbox-options.txt`, `SandboxVars` refreshed by `toLua()` at world load and on `GameClient.receiveSandboxOptions`); the single player debug editor only calls `SandboxOptions.set`, so a mid game toggle reaches Lua after a reload | UNPROVEN | read as `sv.WholeSquare == true`: nil, missing table or false mean the plate area |
| `SandboxVars.DeadWeight.ViewDistance` (integer 0..5, default 2) | PROVEN the same way as `WholeSquare` (`sandbox-options.txt`, `type = integer, min, max, default`) | UNPROVEN | read in `Detect.viewDistance()` where the scale scan runs (viewer square change only), floored and clamped to `Detect.maxRadius` (5); nil, non numeric fall back to `Detect.radius` (2). A change mid game applies once the viewer moves to another square |
| `LosUtil.lineClear(getCell(), x0, y0, z0, x1, y1, z1, false)` (is a scale square visible from the viewer's square) | PROVEN by decompiled source (`zombie.iso.LosUtil`, class listed in `LuaManager$Exposer`; walks the squares between and returns `TestResults`, `Blocked` for a wall, closed door, barricade or curtain, clear through a window or open door). Not called from any vanilla Lua, so how the Kahlua bridge hands back the enum is unproven | UNPROVEN | result compared as `tostring(r) == "Blocked"`; the call sits in a `pcall`, and a missing `LosUtil`, missing `getCell` or an error all count as visible (the behaviour before the check). Run when a candidate scale is scanned and every `Detect.losEvery` (5) polls for the watched scale while the viewer is not on its square |
| `worldObject:getItem()` / `item:getUnequippedWeight()` | PROVEN (client decompiled source `IsoWorldInventoryObject.getItem()`; `InventoryItem.getUnequippedWeight()` = `getActualWeight() + getContentsWeight()`, so a dropped bag includes its contents) | UNPROVEN | `type(...) == "function"` per call, nil item or non number weight skipped |
| `SandboxVars.DeadWeight.WeighCarried` (boolean, default false) | PROVEN (client decompiled `CustomSandboxOptions` registers mod options into the sandbox table; `GameClient.receiveSandboxOptions` carries them to MP clients) | UNPROVEN | read as `type(SandboxVars) == "table"` then `SandboxVars.DeadWeight.WeighCarried == true`; nil anywhere means off (`Occupants.weighCarried`) |
| `sandbox-options.txt` locations | PROVEN (client decompiled `CustomSandboxOptions.init` reads `<versionDir>/media/sandbox-options.txt` then `<commonDir>/media/sandbox-options.txt`). One source `src/sandbox-options.txt`, copied by `tools/sync.sh` to `media/sandbox-options.txt` (Build 41, repo root) and `common/media/sandbox-options.txt` (Build 42). Syntax checked against a real boolean option in the Lifestyle Workshop mod. Translation keys `Sandbox_DeadWeight` (page), `Sandbox_DeadWeight_WeighCarried`, `..._tooltip`, shipped via `Sandbox.json` (B42, vanilla has the same file name) / `Sandbox_<LANG>.txt` (B41) | UNPROVEN (B41 has the same mod option loader by community knowledge, not testable here) | none needed: a build that ignores the file just never sets the option, which reads as off |

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
- Detection scan reuses `WeightScale.Scales` (one source, defined in
  `WeightScaleScales.lua`): the clicked `worldobjects` list, then
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

## 2026-09-18, every language the game ships

Owner's request (task 2026-09-18): translate for every language PZ supports,
correctly encoded per language.

**Language list, PROVEN** -- `media/lua/shared/Translate/*` on the installed
B42 client lists 29 folders: AR, CA, CH, CN, CS, DA, DE, EN, ES, ES_CL,
ES_MX, FI, FR, HU, ID, IT, JP, KO, NL, NO, PL, PT, PTBR, RO, RU, STREW, TH,
TR, UA. `language.json` in each gives its display name; e.g. `AR` is
"Español (Argentina)", not Arabic -- PZ ships no Arabic pack. **STREW is
excluded**: its `language.json` reports "Strewberrie" and every string in it
(checked `IGUI_Temp_Normal`, `ContextMenu_Walk_to`, item names) is the
literal word "Strewberrie" -- a debug/test locale, not a language a player
selects to play in, so this mod ships 28 real languages, not 29.

**B42 reads UTF-8 JSON, PROVEN for non-Latin scripts too.**
`42/media/lua/shared/Translate/{RU,KO,JP,CH,CN,TH}/*.json` were byte
inspected: none start with the UTF-8 BOM (`EF BB BF`), all decode cleanly as
UTF-8 (`json.loads` on the raw bytes succeeds and round trips), same flat
`{"KEY": "value"}` shape as EN/FR. This confirms the `Translator.class` path
format proven above (`"%s/media/lua/shared/Translate/%s/%s.json"`) is
charset-blind by folder, not by content -- one JSON parser, UTF-8 always.

**B41 encoding: PROVEN BY WORKSHOP SAMPLES for JP, CH, CN, RU, PL, TR and
KO** (2026-09-18), still guessed from documented modding knowledge for the
rest. `tools/gen-translate.py` (`LANG_CHARSET`) assigns each language a
legacy Windows code page: `cp1252` for
EN/FR/DE/ES/ES_CL/ES_MX/AR/CA/IT/PT/PTBR/NL/DA/NO/FI/ID (still UNPROVEN),
`cp1250` for PL/CS/HU/RO, `cp1251` for RU/UA, `cp1254` for TR. The evidence:
every root `media/lua/shared/Translate/<LANG>/*.txt` under installed
B41-era Workshop items on this machine (`~/.local/share/Steam/steamapps/
workshop/content/108600/`), excluding anything under `42/` or `common/`
(B42-side even when it reuses the legacy `.txt` shape), was byte-inspected.
JP (3/3 files), CH (5/5) and CN (12/12) decode cleanly and legibly as UTF-8
with no BOM. RU (10/10) and PL (10/10) decode cleanly only as CP1251/CP1250
respectively (UTF-8 only "succeeds" on their all-ASCII files, and produces
garbled text under the other's code page). TR (4/5, the fifth file is
all-ASCII) decodes cleanly only as CP1254. **KO was corrected by this same
pass**: it was assumed `utf-8` (no single-byte page can hold Hangul) but
8 of 10 sampled `Translate/KO/*.txt` files start with the UTF-16LE BOM
(`FF FE`) and decode cleanly as Korean text under `utf-16-le`; the other 2
are ASCII-only and consistent either way. `LANG_CHARSET["KO"]` is now
`"utf-16"` (Python's codec writes the same little-endian bytes with a
leading BOM on encode). **PL/CS/HU/RO's CP1250 is proven only for PL**;
CS/HU/RO share the family by documented convention but have no sampled
Workshop item of their own on this machine, so they stay UNPROVEN. The one
exception with real evidence beyond a sample is **TH, PROVEN**: the B42
client still ships `Translate/TH/language.txt` (every other language
dropped that file) with `charset = UTF-8,` inside it -- the only
per-language charset declaration found anywhere in the install. CH/CN/JP
have no single-byte code page that can hold their scripts, so `utf-8` here
is both the proven answer and the safe fallback: a deliberate choice that
can never lose data, not a guessed legacy page (documented in
`tools/gen-translate.py`'s module docstring).
The generator encodes each B41 `.txt` strictly in its assigned charset and
raises (`sys.exit`, loud, not a silent replace) if any string cannot fit.

**Vanilla wording reused, PROVEN per language** (client install,
`media/lua/shared/Translate/<LANG>/*.json`):
- `IGUI_WeightScale_Normal` copies `IGUI_Temp_Normal` (IG_UI.json) per
  language: the closest vanilla "Normal" to a body-status reading (a
  temperature status band, same shape as a scale reading Low/Normal/High).
  Difficulty labels (`UI_StarterCondition_Normal`), item-type
  (`IGUI_ItemType_Normal`), and sandbox-option "Normal" strings were
  rejected as wrong sense (checked and listed in the 2026-09-13 entry
  above too). `RO`'s `IGUI_Temp_Normal` is an empty string in vanilla (not
  translated there either) -- own translation, "Normal", for RO.
- The scale's noun reuses `Base.Mov_ScaleMedical` (ItemName.json), vanilla's
  own name for this exact medical/weighing scale moveable, per language.
  `CA` and `ES_CL` ship an empty string for that key in vanilla (own
  translation used instead: "Báscula" reused from the ES/ES_MX pattern
  glossed to each language). `KO`'s vanilla value is the literal English
  "Weighing Scale" (untranslated upstream) -- own translation used for the
  noun (che-jung-gye, "body-weight meter").
- `ContextMenu_WeightScale_StepOn`'s grammatical form (imperative vs.
  infinitive vs. nominalised gerund, capitalisation) was matched per
  language against that language's own `ContextMenu_Walk_to` and
  `ContextMenu_Climb_over` (ContextMenu.json) rather than translated in a
  single fixed form; FR is unchanged. Languages where the exact wording is
  this mod's own rendering (no vanilla phrase to copy verbatim, only the
  grammatical pattern): AR, CA, ES, ES_CL, ES_MX, CS, DA, DE, FI, HU, ID,
  IT, JP, KO, NL, NO, PL, PT, PTBR, RO, RU, TH, TR, UA -- every non-FR/EN
  language, since "step on scale" itself has no vanilla precedent; flagged
  here for a native speaker to review, same posture as any own-translation.

Bench: `tests/translate_spec.py`, extended to loop every language in
`tools/gen-translate.py`'s `LANGS`/`LANG_CHARSET` (imported, not
duplicated): every key in every language, B41 decodes and round trips in
its assigned charset with the vanilla `ContextMenu_<LANG> = {` header, B42
JSON has no BOM and matches source, EN/FR unchanged.

## 2026-09-18, PREFIX_TO_FILE: one key family, one file (Info tab word bug)

Owner's report, in game on B42, screenshot of the Info tab: the Weight row
showed the raw key `IGUI_WeightScale_Normal` instead of "Normal" -- the
five vanilla `UI_trait_*` bands rendered fine, only this mod's own word did
not, so the fault was in how OUR key was shipped, not in `bandOf` or the
patch mechanism.

**Root cause, PROVEN against the client install:** `tools/gen-translate.py`
put every key from `strings.json` into `ContextMenu.json` /
`ContextMenu_<LANG>.txt` regardless of its prefix, i.e. one file for both
key families. `zombie.core.Translator` loads a fixed file per key prefix,
not one file per mod: the installed B42 client's vanilla EN folder
(`~/.local/share/Steam/steamapps/common/ProjectZomboid/projectzomboid/
media/lua/shared/Translate/EN/`) has `ContextMenu.json` holding
`ContextMenu_*` keys and a SEPARATE `IG_UI.json` holding `IGUI_*` keys
(NOT `IGUI.json`) -- so `getText("IGUI_WeightScale_Normal")` looked in
`IG_UI.json`, where the key never existed, and returned the raw key.
B41-era Workshop mods on this machine confirm the same split for the
legacy format: `IG_UI_EN.txt` (Lua table `IGUI_EN`), distinct from
`ContextMenu_EN.txt` (Lua table `ContextMenu_EN`) -- e.g.
`~/.local/share/Steam/steamapps/workshop/content/108600/3290232938/mods/
SmarterStorage/media/lua/shared/Translate/EN/IG_UI_EN.txt`.

**Fix:** `tools/gen-translate.py` now derives each key's prefix (its first
`_`-separated segment) and looks it up in one explicit table,
`PREFIX_TO_FILE`, which fails the generator loud (`sys.exit`) on a prefix
it does not know, instead of silently defaulting somewhere:
- `ContextMenu` -> `ContextMenu.json` (B42) / `ContextMenu_<LANG>.txt`,
  table `ContextMenu_<LANG>` (B41).
- `IGUI` -> `IG_UI.json` (B42) / `IG_UI_<LANG>.txt`, table `IGUI_<LANG>`
  (B41).

The generator now emits one file per prefix per language per build
(`gen_b41_txt`/`gen_b42_json` take a `prefix` and look up both the file
stem and, for B41, the Lua table name in `PREFIX_TO_FILE`). The stray
files the old code shipped under the wrong name (`IGUI_WeightScale_Normal`
inside `ContextMenu.json`/`.txt`) are gone; `IG_UI.json` /
`IG_UI_<LANG>.txt` are now generated and committed for all 28 languages.

**Bench, checked against the game, not against ourselves:**
`tests/translate_spec.py` now asserts `PREFIX_TO_FILE` against the CLIENT
INSTALL's own EN folder (each prefix's file exists there and holds at
least one key of that prefix; a visible `NOTICE` on stderr and the checks
skipped when the install is absent), asserts every literal
`getText("...")` key found in `src/lua` -- ours or a reused vanilla one
(`UI_trait_*`, `IGUI_char_Weight`) -- exists verbatim in the file its own
prefix maps to, and asserts no generated translation file exists outside
`PREFIX_TO_FILE`'s names. It was RED against the pre-fix generator
(`AttributeError`/missing `IG_UI.json` before `PREFIX_TO_FILE` existed)
and is GREEN after.

**The five other vanilla bands, confirmed against the client's own
`UI.json`:** `UI_trait_emaciated` -> "Emaciated", `UI_trait_
veryunderweight` -> "Very Low Weight", `UI_trait_underweight` -> "Low
Weight", `UI_trait_overweight` -> "High Weight", `UI_trait_obese` -> "Very
High Weight" -- all five exist verbatim, matching the owner's own in game
report that only the Normal band was broken.

## 2026-09-18, own realistic weight words replace the vanilla trait keys

Owner, after seeing the Info tab in game: "why we use Very High Weight,
instead of obese. and word more realistic?" Build 42 renamed the vanilla
trait keys used above to soft terms (`UI_trait_obese` -> "Very High
Weight", `UI_trait_overweight` -> "High Weight", `UI_trait_underweight` ->
"Low Weight", `UI_trait_veryunderweight` -> "Very Low Weight",
`UI_trait_emaciated` unchanged at "Emaciated" -- reconfirmed against the
client install the same day). Riding vanilla's keys means riding vanilla's
wording, which just changed once already. **Chosen:** the mod's own key per
band, all six now `IGUI_WeightScale_*` (Emaciated, VeryUnderweight,
Underweight, Normal, Overweight, Obese), realistic medical terms, immune to
any future vanilla rename.

**Translation sources, per word, checked in this order:**
1. Game's own translation: any vanilla key whose EN value is exactly the
   word. Found only for **Emaciated** -- `UI_trait_emaciated` matches
   verbatim in the client install's EN `UI.json`, so its per-language value
   is reused for all 28 languages (e.g. FR "Émacié", DE "Abgemagert", RU
   "Крайне недостаточный вес", JP "やせ衰え").
2. B41-era Workshop translation: searched every installed Workshop item on
   this machine (`~/Zomboid/Workshop`, `~/.local/share/Steam/steamapps/
   workshop`) for the four `UI_trait_*` keys; only this mod's own staged
   copy of `WeightScaleCharScreen.lua` matched (source code, not a
   translation file) -- no B41-era translation sample found for "Very
   Underweight", "Underweight", "Overweight" or "Obese" in any language.
3. Own translation: used for **Very Underweight, Underweight, Overweight,
   Obese** in all 28 languages -- medically plain terms, a doctor's chart
   phrasing, capitalised per language the way its own vanilla trait names
   are (first letter only, matching `UI_trait_emaciated`'s per-language
   capitalisation). AR is Spanish (Argentina), not Arabic, per the language
   list proven above; ES/ES_CL/ES_MX/AR share the same Spanish wording,
   like several existing own-translations above. FR reuses the mod's own
   internal band-id words already used as Lua table keys (`tresMaigre`,
   `maigre`, `surpoids`, `obese`).
   Flagged here for a native speaker to review, same posture as any
   own-translation above: AR, CA, CH, CN, CS, DA, DE, ES, ES_CL, ES_MX, FI,
   FR, HU, ID, IT, JP, KO, NL, NO, PL, PT, PTBR, RO, RU, TH, TR, UA -- every
   language, for these four words only (Emaciated is vanilla-sourced, no
   review needed there).

Bench: `tests/charscreen_spec.lua`'s `WORD_KEY`/`TEXT`/`CASES` moved to the
six `IGUI_WeightScale_*` keys and their English words; a new case (12)
proves that when `getText` returns the raw key (broken/missing translation
file on some install) the word falls back to the hardcoded English word,
never the key itself. `tests/translate_spec.py` is unchanged in logic (it
loops `source.keys()`, not a hardcoded count) and now covers 7 keys instead
of 2.

## 2026-09-21, Digital Scale tile pack (Build 42, PROVEN by decompile plus a real mod)

Client install decompiled (`projectzomboid.jar`, CFR; `ChooseGameInfo` via
`javap -c`, CFR fails on it), cross checked against Workshop item 3747396551
(FoodDrying), which ships one `.tiles` and one `.pack`.

- `mod.info` `pack=<name>` (`ChooseGameInfo`): read as `media/texturepacks/<name>.pack`
  (`ZomboidFileSystem.loadModPackFiles`), mounted by `GameWindow.LoadTexturePack`.
- `mod.info` `tiledef=<name> <number>`: exactly two whitespace separated fields,
  number must be in 100..8189, read as `media/<name>.tiles`
  (`ZomboidFileSystem.loadModTileDefs`), `IsoWorld.LoadTileDefinitions(..., number)`.
  Two mods with the same number: the second is refused. 6417 is unused by every
  installed Workshop mod on this machine (used: 741-743, 2026, 4048, 4126, 4848,
  5620, 7551, 7811, 8188, 8189).
- Both lookups go through `activeFileMap`, which `ZomboidFileSystem.loadMod` fills
  from the mod's `common/` dir AND its version dir (`42/`), keyed by the path
  relative to each and lower cased. So `common/media/...` and `42/media/...` are
  equivalent; FoodDrying uses `42/media/`, this mod uses `common/media/` like its
  scripts and sounds. Root `media/` (Build 41) is not involved: the root
  `mod.info` carries neither line.
- `.tiles`: int32 little endian, strings end with `\n`: `tdef`, version 1, sheet
  count; per sheet name, png name, wTiles, hTiles, tilesetNumber (1..512), nTiles;
  per tile nProps then (key, value) pairs. Sprites are `<sheet>_<index>`; sprite id
  is `0x100000 + (number-2)*262144 + (tilesetNumber-1)*512 + index`.
- `.pack`: `PZPK`, version 1, page count; per page: name, entry count, mask flag,
  per entry name and 8 int32 (x, y, w, h, offsetX, offsetY, frameW, frameH), PNG
  length, PNG bytes; strings are int32 length plus bytes. Entries are the sprite
  names; the frame is the 2x 128x256 and offsets place the trimmed rect in it.
- Movable groups: the loader groups tiles by `GroupName` and `Facing`, and adds
  `Noffset`/`Eoffset`/... itself from the sprite order. `GroupName=DeadWeight`
  (not vanilla's `Weighing`) keeps the two scales in separate groups. The
  display name key is `<GroupName> <CustomName>` with spaces turned to `_`
  (`Translator.getMoveableDisplayName`), so `DeadWeight_Digital_Scale` in
  `Moveables.json`; the item's script name loads from `ItemName.json`
  (`Base.Mov_DeadWeightDigital`).
- Tabletop placement (`ISMoveableSpriteProps.canPlaceMoveableInternal`): with
  `IsTableTop` and `BlocksPlacement` the object also places on a free floor tile;
  the game sets the object's render offset to the table's own surface height
  (`setRenderYOffset(currentSurface)`, minus the object's own `Surface` when it
  carries `IsSurfaceOffset`, which the vanilla Microscope does because its art is
  drawn raised). The Digital Scale therefore has NO `IsSurfaceOffset`: its art
  (`tools/gen-scale-art.py`) is drawn at floor level, footprint 0.6 tile
  centred, and the same sprite sits right on a floor and, lifted by the game, on
  a counter. `Surface=4` is the slab top in 1x pixels. Unverified until placed in
  game on a floor and on a counter.
- NOT verified: that 1x tile scale (`Core.tileScale == 1`) finds the 2x sprite
  (only 2x art is shipped); that Build 41 ignores or survives `deadweight_items.txt`
  (it is therefore staged for Build 42 only). In game placement is the open gate.
