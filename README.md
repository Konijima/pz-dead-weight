# Weight Scale

A small Project Zomboid mod: right-click a working weight scale to weigh
yourself, and read your weight, weight trend and nutrition values (calories,
carbohydrates, lipids, proteins) in a window.

Originally a Build 41 mod (Steam Workshop item `2833096579`). This repository
stages that B41 source in a Build 42 layout, mirroring `CeroSec`, ahead of the
actual B42 rework.

**Status: B41 code staged, B42 rework not started.** Nothing under `42/` has
been touched or verified against Build 42 yet; it is the original B41 Lua
copied into the new layout so the rework has somewhere to start from.

## Layout

- `42/` -- the Build 42 mod folder: `mod.info`, `poster.png`, and
  `media/lua/client/WeightScale` and `media/lua/shared/Translate` copied
  as-is from the B41 source. This is what the game loads once the mod is
  enabled.
- `common/` -- shared media (models, scripts, sound, textures) if a rework
  ever needs assets shared between builds. Empty for now.
- `legacy/b41/` -- the original downloaded B41 mod, untouched, kept as the
  reference for the rework.
- `docs/` -- rework notes and design docs. Empty for now.
- `workshop/` -- Steam Workshop material: `workshop.txt` (item id
  `2833096579` and the original description) and the original poster image.
- `tools/` -- scripts to help build, package or publish the mod. Empty for
  now.

## Install (from source)

Clone or copy the repository so `42/` becomes the mod folder Project Zomboid
loads, e.g. symlink or copy `42/` to `~/Zomboid/mods/WeightScale` once the
rework is ready to run (a symlinked mod folder does not reliably load its
scripts in Build 42, so use a real copy).

## Mod id

`mod.info` keeps the original id `WeightScale` so existing Workshop
subscribers are not orphaned by the rework.
