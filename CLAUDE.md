# Dead Weight

A Project Zomboid mod. Stand on the clinic's beam scale and it reads your
exact weight, in kg or lb, to one decimal. The vanilla character screen's
Info tab only ever shows the weight category in words (Emaciated ... Obese),
never the number, so the scale is the only way to see it. Deliberately
light: no per frame world scanning, and the HUD element sits in the UI
manager only while its readout is actually on screen.

Supports Build 41 and Build 42 from one repository.

## Layout: src/ is truth, the rest is generated

```
src/          hand edited source, the ONLY place to make changes
  lua/client/WeightScale/   Lua modules, see Module map below
  lua/server/WeightScale/   Build 42 only: Digital Scale loot (Distributions) and world spawn (Spawn)
  translate/strings.json    every translation string, one file, all languages
  sandbox-options.txt       the DeadWeight.* sandbox options (WeighCarried, WholeSquare,
                            ViewDistance, HomeScaleSpawn, HomeScaleFloor; the last two only
                            act on Build 42, the file itself is shared with B41)
  tiles/                    the Digital Scale's four faces (digital_scale_{S,E,N,W}.png), hand
                            refinable art, the source of the tile pack
  textures/, sounds/, scripts/   scripts/deadweight_items.txt (the movable item) is B42 only

mod.info      Build 41 mod.info, root of the repo (root IS the mod folder)
media/        Build 41 generated tree (lua, textures, sound, scripts, sandbox-options.txt)
42/           Build 42 generated tree (mod.info, lua, icon, posters)
common/       Build 42 generated tree (textures, sound, scripts, sandbox-options.txt, and the
              Digital Scale tile pack: DeadWeightDigital.tiles, texturepacks/, depthmaps/, tileGeometry.txt)
```

Never hand edit `media/`, `42/` or `common/`. After any change under `src/`:

```
bash tools/sync.sh          # copies/regenerates src/ into media/, 42/, common/
bash tools/check-sync.sh    # fails if the generated trees drifted from src/
```

Generators:

- `tools/gen-geo.py`: writes `src/lua/client/WeightScale/WeightScaleGeo.lua`
  from `docs/maquettes/v2/assets/geometry.json`, the approved design
  contract (HUD layout, weight range, band thresholds and colours). Change
  the design there, never in `WeightScaleGeo.lua`. `--check` detects drift.
- `tools/gen-tiles.py`: builds the Digital Scale's tile pack (`.pack` texture
  page, binary `.tiles` definitions, depth map, empty `tileGeometry.txt`)
  under `common/media/` from `src/tiles/*.png` and its `TILE_PROPS`. Called
  by `sync.sh`; `--check` detects drift (also run by `tests/run.sh`, and
  `tests/tiles_spec.py` parses the output back). `42/mod.info` `pack=` and
  `tiledef=` point at it.
- `tools/gen-scale-art.py`: draws the four `src/tiles/` faces (a flat slab in
  the game's isometric projection). Run by hand, NOT by `sync.sh`, so a hand
  refined PNG is never overwritten.
- `tools/changelog-steam.py`: prints a `CHANGELOG.md` section as the Steam
  change note (see README, Releasing).
- `tools/gen-translate.py`: reads `src/translate/strings.json`, writes the
  per build, per language translation files below. Called by `sync.sh`;
  also takes a target directory for a drift check (used by `check-sync.sh`
  and the bench) without touching the real trees.
- `tools/gen-workshop-txt.py`: writes `workshop/workshop.txt`'s
  `description=` lines from `workshop/description.bbcode`,
  `workshop/gif_url.txt` and `workshop/workshop_id.txt`. Not shipped in the
  mod; it only stages the Workshop item's page text.

The two `mod.info` files (root, Build 41; `42/mod.info`, Build 42) are hand
maintained and must agree on `id=` and `name=` (`tests/modinfo_spec.py`).

## Module map (`src/lua/client/WeightScale/`)

- `WeightScaleCore.lua`: pure logic, no game API (weight to screen X,
  `bandOf`, one decimal formatting, kg/lb conversion), ported from the
  maquette's own JS sampler so the bench can diff Lua against it.
- `WeightScaleGeo.lua`: generated, see above. HUD geometry, weight ranges
  (the clinic scale's, and the Digital Scale's 0 to 130 kg), band thresholds
  and colours.
- `WeightScaleScales.lua`: pure data, no game API. The one table of every
  scale sprite (the two clinic sprites and the four Digital Scale facings),
  keyed by sprite name: kind (`medical`/`digital`), HUD style (`beam`/`panel`),
  plate centre and half size, plate height, whether it can be stood on,
  whether it has a column to face or a fixed `faceDir`, and which weight
  range it maps. Detect, Occupants, HUD, Menu and Core look scales up here; a
  new scale is one entry, not a lookup added in several modules.
- `WeightScaleDetect.lua`: per local player presence detection (is this
  player standing on a scale tile, or within `DeadWeight.ViewDistance`
  squares of one in the same room and in line of sight, and facing it: a
  scale other than the one under the player is read only while in front of
  them, which also applies to the clinic scale), occupancy polling
  of the nearest scale that has something on it, with a debounce,
  splitscreen aware. A scale drawn on a counter is never "stood on" (no
  step cue, no turn to face it).
- `WeightScaleOccupants.lua`: who stands on the scale tile and what each
  weighs (player, animal, zombie); the game API for it lives here. The plate
  box comes from the `Scales` entry; items dropped on a plate are lifted onto
  it, and a character in a counter scale's square counts only while above the
  counter (climbing through a window over it), not walking past. With the
  `DeadWeight.WeighCarried` sandbox option on it also adds each local
  player's carried mass and the tile's floor items (`Occupants.remoteLoad`
  is the relay seam for remote players).
- `WeightScaleHUD.lua`: the on screen readout, an `ISUIElement` sized to
  the readout, added to and removed from the UI manager as it appears. The look (beam
  head or native panel) and weight range follow the scale's `Scales` entry;
  there is no right click style switch any more.
- `WeightScalePrefs.lua`: per user prefs (the unit only; an old file's
  `style=` line still loads and is ignored), read and written with core Lua
  file APIs stable across both builds.
- `WeightScaleSound.lua`: step on/off cues, one shot per transition; every
  viewer plays them locally (no network) when the scale goes empty <-> occupied.
- `WeightScaleMenu.lua`: the right click "Step on Scale" context menu option,
  and "Put Animal on Scale" when the player holds an animal (Build 42). Neither is offered for a scale drawn on a
  counter.
- `WeightScaleCharScreen.lua`: patches the Info tab's weight line to show
  the category word instead of the number.
- `lua/server/WeightScale/WeightScaleDistributions.lua` (Build 42 only): adds the
  Digital Scale to the bathroom counter loot lists at `OnPreDistributionMerge`,
  weight from `DeadWeight.HomeScaleSpawn`.
- `lua/server/WeightScale/WeightScaleSpawn.lua` (Build 42, server and single
  player only): puts a Digital Scale on the floor of a big enough home or motel bathroom, in
  new chunks only (`MapObjects.OnNewWithSprite` on toilet sprites, examined at
  `LoadChunk`), against a wall, chance `DeadWeight.HomeScaleFloor`. Never uses
  `RoomDef.explored`, see `docs/API-COMPAT.md`.
- `WeightScaleMain.lua`: wires the modules to game events; computes
  nothing itself.

## Commands

Before any commit:

```
bash tools/sync.sh && bash tools/check-sync.sh && bash tests/run.sh
```

`tests/run.sh` needs `lua5.1` (or `lua`), `node` and `python3` on `PATH`
and fails loud, not silently, if one is missing. It runs, in order: the
geometry generator drift check, the `mod.info` guard (id/name match,
poster/icon files exist, no U+2014 anywhere tracked, description tags
space delimited, Workshop description under Steam's 8000 character cap), the translation bench, the `workshop.txt` generator
drift check, the tile pack drift check and its parse back bench, the
changelog guard (top released version equals `42/mod.info` `modversion=`, an
`Unreleased` section exists), nine Lua unit suites (core math, HUD lifecycle,
step sound volume, context menu, facing the scale, occupancy, the scale
table, loot and world spawn, the Info tab patch), and a JS/Lua parity check of the
animation sampler against the maquette's own `anim.js`.

Packing for the Workshop:

```
bash tools/pack-workshop.sh --check   # dry run, prints what would be staged
bash tools/pack-workshop.sh           # stages the upload copy
bash tools/pack-workshop.sh --clean   # removes the staged copy
```

After uploading, run `tools/set-workshop-id.sh` (no argument: reads the id
Steam wrote into the staged copy) to record it and refresh the
description's "Workshop ID:" line.

The uploader reads `visibility=` from the staged `workshop.txt` on every
submit and writes it straight back (`SteamWorkshopItem.java`,
`readWorkshopTxt`/`writeWorkshopTxt`), so when the item goes public on
Steam, set `visibility=public` in `workshop/workshop.txt` too, or the next
upload silently turns it private again.

## Hard won rules

- Prove client APIs against the client install, not a dedicated server
  install; they do not carry the same client only Lua. Record proof or
  its absence in `docs/API-COMPAT.md`. Build 41 support is kept but every
  Build 41 only call must be guarded (`type(x) == "function"`), since it
  may be untested.
- Bench stubs mirror the real game objects, never the code's assumptions.
  Example: `worldobjects` in `OnFillWorldObjectContextMenu` is a plain Lua
  table, while `square:getObjects()` returns a Java list; a stub that
  blurs the two passes against broken code (`tests/menu_spec.lua`).
- A UI element under the mouse consumes right click releases. The HUD
  element must stay sized to the readout and sit in the UI manager only
  while visible, or right click world context menus break everywhere.
- Translations load from exactly one file per key prefix, set in
  `tools/gen-translate.py`'s `PREFIX_TO_FILE`: `ContextMenu_` keys load
  from `ContextMenu.json` (B42) / `ContextMenu_<LANG>.txt` (B41, a Lua
  table); `IGUI_` keys load from `IG_UI.json` (B42, not `IGUI.json`) /
  `IGUI_<LANG>.txt` (B41). B41 `.txt` files are Lua tables encoded in that
  language's own charset (Korean is UTF-16); B42 reads JSON only, UTF-8
  without BOM. `Sandbox_` keys load from `Sandbox.json` (B42) / `Sandbox_<LANG>.txt`
  (B41). Add a new prefix to `PREFIX_TO_FILE` before using a new key
  family, or the key shows up raw in game.
- `mod.info` description quirks: rich text tags need a space on both sides
  or the parser glues the neighbouring word to the tag and it vanishes;
  `description=` lines concatenate with no separator; `url=` only accepts
  theindiestone.com and discord.gg links; `incompatible=` ids take a
  leading backslash on Build 42.
- The game prefers a staged Workshop copy over a dev copy sharing the same
  mod id: it loads the staged copy even when testing from source. Repack
  after every change (`tools/pack-workshop.sh`) or `--clean` the staged
  copy while developing. A symlinked mod folder does not load its scripts
  on Build 42: staging always writes a real copy.
- `tools/pack-workshop.sh` refuses to overwrite a staged Workshop id the
  repo does not know, to avoid orphaning that item and creating a
  duplicate on the next upload; run `tools/set-workshop-id.sh` first.
- Weight model numbers are owned by the code: range and band thresholds
  live in `docs/maquettes/v2/assets/geometry.json` (via generated
  `WeightScaleGeo.lua`); band matching (`bandOf`), one decimal formatting
  and the kg/lb conversion factor live in `WeightScaleCore.lua`. Change
  them there, not in a comment or a doc.

## Forking this repository

- Change `id=` and `name=` in both `mod.info` (root) and `42/mod.info`
  (`tests/modinfo_spec.py` fails if they disagree).
- Change the staging folder name in `tools/pack-workshop.sh` (`WS=` /
  `DEST=`, currently `DeadWeight`).
- Update the repo URL in `workshop/description.bbcode` and README.md.
- Empty `workshop/workshop_id.txt` and `workshop/gif_url.txt`: they belong
  to one specific Workshop item and gif upload.
- Read `LICENSE` first: as written it is source available, not open
  source. Cloning, building and sending pull requests back here is
  allowed; redistributing the mod or a modified copy anywhere else
  (including the Workshop), selling it, or reusing its name, logo or art,
  needs the copyright holder's written permission.

## Conventions

- English in code and comments. Most docs are English; `docs/TEST-EN-JEU.md`
  is French (in game manual test notes).
- No U+2014 (em dash) in any tracked file. `tests/modinfo_spec.py` scans
  every file `git ls-files` returns, so a new file needs `git add` before
  the bench sees it.
- Match the comment density of the file you are editing; the Lua modules
  explain the game API proof or the risk next to the code, repo wide facts
  go in `docs/API-COMPAT.md`.
- Keep the mod light: no new per frame or per tick work without a measured
  reason; prefer event driven checks (`WeightScaleDetect.lua`,
  square-changed only) over polling every tile every frame.
- Design changes (HUD layout, weight range, band thresholds/colours) start
  in `docs/maquettes/v2/assets/geometry.json` and its maquette, never in
  Lua; `tools/gen-geo.py` is the only writer of `WeightScaleGeo.lua`.
- Every player visible change gets a line under `Unreleased` in
  `CHANGELOG.md` as it lands.
