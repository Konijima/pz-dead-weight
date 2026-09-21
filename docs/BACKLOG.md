# Backlog and findings kept for later

Not in any release. Each item says what we learned so it is not redone.

## Other scale sprites, `location_community_medical_01_120` and `_121`

Found 2026-09-20 on the clinic map. Facts, from the game install (client
`media/newtiledefinitions.tiles.txt`, `Tiles2x.pack`, decompiled source):

- The art is the same two orientations as `_8` (Facing E) and `_9` (Facing S),
  not two new ones: `_121` looks like `_8` and `_120` like `_9`, each with the
  plate moved towards the middle and front of the tile. Judged from the pixels,
  not proven.
- Their tile definition is only `BlocksPlacement` and `solidtrans`: no
  `IsMoveAble`, no `CustomName`, no `Facing`. So they are map decoration:
  not pickable, and not walkable because `solidtrans` makes the square solid.
- Measured plate centres (tile fractions, plate top 4 px above ground, same
  method as `Occupants.plateCentres`): `_120` about (0.69, 0.52), `_121` about
  (0.52, 0.73). The mod does not recognise these sprites yet.

Follow-up (a), small, its own branch after 1.2.0:

- Remove the flag at load like vanilla `shared/Util/CustomTileProps.lua` does
  (`OnGameStart` and `OnServerStarted`):
  `IsoSpriteManager.instance:getSprite(name):getProperties():unset(IsoFlagType.solidtrans)`.
  Use the flag overload: the loader stores `solidtrans` as an `IsoFlagType` bit.
  `OnLoadedTileDefinitions` (fired in `IsoWorld` before chunks load) may be a
  better hook so chunk collision is built without the flag; untested.
- Add both names to `Detect.spriteNames` and `Occupants.plateCentres`; set
  `Facing` (`_121` E, `_120` S) so the turn towards the scale works.
- The patch must run on client and server, so it lives in a new
  `lua/shared` folder: `tools/sync.sh`, `tools/check-sync.sh` and
  `tests/run.sh` all hardcode `src/lua/client/WeightScale` and need it too.

Follow-up (b), large and possibly blocked: make them pickable and rotatable.

- `IsoWorld.SetCustomPropertyValues` registers `Noffset`/`Soffset`/`Woffset`/
  `Eoffset` values only for -96..96, and `PropertyContainer.set` maps an
  unregistered value to id 0. `_8`, `_9`, `_120`, `_121` are 1, 111, 112, 113
  apart in one sheet, so most face offsets cannot be stored. Check first in a
  debug game: `p:set("Noffset","112")` then `p:get("Noffset")`.
- If that fails, the way out is a mod-owned `.tiles` file (offsets are indices
  inside that sheet), a much bigger job. Setting `IsMoveAble` also turns every
  scale in the world into furniture and can clash with other mods.

## Lifting the character onto the plate

Asked 2026-09-20. What the decompiled source says:

- No render offset exists for characters. Setting `character:setZ(z + 0.04)`
  does not hold: `IsoGameCharacter.getHeightAboveFloor() > 0` puts the character
  in the falling branch (gravity pulls it back to the floor within frames), so
  it would jitter and also be sent to the server.
- The engine's own way to hold a character above the floor is a sloped
  surface: tile properties `SlopedSurfaceDirection`, `SlopedSurfaceHeightMin`,
  `SlopedSurfaceHeightMax` (percent, 0..100), read by
  `IsoMovingObject.handleSlopedSurface` and `IsoGridSquare.getApparentZ`. It
  needs no per frame Lua, lifts characters AND dropped items (items use
  `getApparentZ`, so `liftOntoPlate` would become unnecessary), and only B42
  tile data uses it today (`tiledefinitions_b42chunkcaching.tiles`).
- Unknown: whether `props:set("SlopedSurfaceHeightMin", "4")` from Lua stores
  the value (`set` maps a value missing from the registered list to id 0), what
  a 4 percent flat slope does to pathing and edge blocking between squares
  (`isSlopedSurfaceEdgeBlocked`), and B41. Try in a debug game on
  `location_community_medical_01_9` before designing anything.

## Multiplayer relay for body and carried weight

Built in 1.2.0 with no server file: each client publishes what its own player
weighs and carries in the player's modData (`DeadWeightBody`, `DeadWeightCarried`) and calls
`transmitModData()`; the server relays `ObjectModDataPacket` to nearby clients
(`sendToRelativeClients`) and the receiver stores it on the remote IsoPlayer.
Known limits: it reaches only clients near the sender, the packet replaces the
receiver's whole modData table for that player, and a viewer who arrives
between two heartbeats (3 s) reads body only until the next one. If a real
server shows the relay unreliable, the fallback is `sendClientCommand`/
`sendServerCommand` with a server Lua file (`tools/sync.sh`,
`check-sync.sh` and `pack-workshop.sh` would need the server path).

## Cue and pick-up rough edges with two scales in reach

From the 1.2.0 review (low severity, only with overlapping scales):
`settledEmpty` is not reset when the shown scale changes, so a viewer settled
by an empty scale A can get an "on" cue when occupied scale B comes into reach;
leaving occupied A's reach or a door closing while empty B is in reach can give
an "off" cue although nobody stepped off; and a straight step onto another
scale in the very window after a scale was dropped skips the turn to face it.
The `[DeadWeight] animal held/released` prints in `WeightScaleMenu.lua` can go
once the animal drop is settled.

## Put Animal on Scale in multiplayer

Two clients on one server, 2026-09-20: the animal disappears for everyone, and
our client never sees it (`animal drop never seen`). Cause: our
`ISDropWorldItemAction:complete` runs on the server and calls
`AddWorldInventoryItem(..., transmit=false)`, and the `DropAnimal` packet is only
sent when `transmit && GameServer.server`. Vanilla inventory Drop of the same
kind of animal works because `ISInventoryTransferAction` is completed by the
client too, after the server's `ItemTransactionPacket`. That path always drops
on the player's own square (`getNotFullFloorSquare`, the transaction carries no
target square), so it cannot put the animal on the scale from the next square.
The option is hidden on an MP client (`isClient()`). Ideas: stand on the plate,
drop, step off (weighs the player too); or find a Lua reachable call that
transmits a server made animal.

## Performance nit

`Detect.poll` walks the scale square's object list up to three times per poll
(`Occupants.onPlate` via `plateOf`, `hasScaleSprite`, then `Occupants.read` via
`plateOf`). Cache the plate centre next to `s.scaleSquare` when the scan sets it
and pass it into `read`.

## Values to tune in game

`Occupants.plateHalf` (0.28), `Occupants.plateCentres`, `Occupants.plateTop`
(0.04). The centres come from the sprite art; the half size and the lift height
are still estimates.

## Digital Scale art origin and licensing

`src/tiles/digital_scale_{S,E,N,W}.png` is placeholder art derived from the
vanilla scale sprites (`location_community_medical_01_8` and `_9`, 2x): plate
kept, column removed, shrunk to about 60 percent, a small LCD painted on top;
N and W are the S and E faces mirrored horizontally, not drawn faces. The
plate pixels are Indie Stone's. Whether a mod may ship art derived from them
(Workshop and the LICENSE notes) is an open question: settle it, or redraw the
plate from scratch, before the Digital Scale goes public.
