# Dead Weight

![Dead Weight: step on the scale, face the truth](workshop/art/deadweight-banner.png)

![Dead Weight in action](workshop/art/deadweight-animation.gif)

*Step on the scale. Face the truth.*

A small Project Zomboid mod: step on a working medical scale and your exact
body weight appears on screen, to one decimal, in a brass and cream beam
head readout that settles like the real thing. Walk off and the number
goes with you; nowhere else in the game can you read it that precisely.

## Features

- A brass and cream beam head readout, the poise sliding to your weight and
  settling instead of snapping, because a real scale wobbles.
- One decimal of precision.
- Your unit and display style are remembered between sessions.
- The character screen's Info tab shows only your weight category in words
  (Emaciated to Obese) with its trend arrow; the exact number stays on the
  scale.
- Your survivor turns once to face the scale's column on stopping.
- Two short sounds: stepping on, stepping off.
- A "Step on Scale" option at the top of the scale's right click menu, with
  its own icon, walks you there.
- Every local splitscreen player gets their own readout.
- No per frame scanning: the reading only exists while you are standing on
  the scale.
- 28 languages, every one the game ships.

## Controls

- Left click the readout: switch between kg and lb.
- Right click the readout: switch between the beam head look and a plain
  native panel.

## Compatibility

Built for Build 42, keeps Build 41 support. Singleplayer and multiplayer
(client side), splitscreen aware. If another mod replaces the character
screen, this fails safe: the scale keeps working and the Info tab simply
stays as that mod or vanilla draws it. Incompatible with the original
"Weight Scale" mod (item based, full nutrition panel): disable it first,
the two should not run together.

## Install

**From the Steam Workshop.** <!-- workshop-link:start -->[Dead Weight on the Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3804074600).<!-- workshop-link:end -->

**Manual install.** Copy the `42/` folder's contents into a new folder under
`~/Zomboid/mods/DeadWeight/` (create `mod.info`, `poster.png` and `media/`
there from `42/mod.info`, `42/poster.png` and `42/media/`), or, for Build 41,
copy the repository root's own `mod.info`, `poster.png` and `media/` the same
way into `~/Zomboid/mods/DeadWeight/`. Then enable **Dead Weight** in the mod
list.

## Development

The repository root is the mod folder itself, laid out so Build 41 and
Build 42 can load from the same copy.

- `src/` is the single source of truth: Lua modules, textures, sounds,
  sound scripts and translations. **Never hand edit `media/`, `42/media/`
  or `common/media/textures`, they are generated.**
- `tools/sync.sh` regenerates the Build 41 tree (root `mod.info`, `media/`)
  and the Build 42 tree (`42/`, `common/`) from `src/`. Run it after any
  change under `src/`.
- `tools/check-sync.sh` fails if the generated trees have drifted from
  `src/`.
- `tools/gen-geo.py` regenerates the HUD geometry from the approved
  maquette's `docs/maquettes/v2/assets/geometry.json`; never hand edit
  `WeightScaleGeo.lua`.
- `bash tests/run.sh` runs the full bench: the Lua unit suites, the
  mod.info guard, the translation bench, the workshop.txt drift check and
  the JS/Lua parity check against the maquette's own sampler. Must exit 0
  before any commit.
- `tools/pack-workshop.sh` stages the upload copy under
  `~/Zomboid/Workshop/DeadWeight/` (`--check` for a dry run, `--clean` to
  remove it). Rerun it after any change before testing in game: once a
  staged copy and the repo copy share the same mod id, the game loads the
  staged copy, not the repo.
- `workshop/art/deadweight-banner.png` is the Workshop page banner (also
  the README hero image above); it is not shipped to players, see the
  `pack-workshop.sh` bullet above.
- `workshop/description.bbcode` is the hand edited source of the Workshop
  page text; `tools/gen-workshop-txt.py` regenerates the `description=`
  lines of `workshop/workshop.txt` from it and from `workshop/gif_url.txt`,
  which already holds the gif's raw GitHub URL
  (`https://raw.githubusercontent.com/Konijima/pz-dead-weight/main/workshop/art/deadweight-animation.gif`);
  an empty file emits no `[img]` tag rather than a broken one. That URL
  only resolves once this repository is public, so **at release, make the
  repository public before making the Workshop item public**, or Steam
  shows, and may cache, a broken image. The description's own
  [Source](https://github.com/Konijima/pz-dead-weight) link points bug
  reports and translation fixes back here.

**After the Workshop upload.** Run `tools/set-workshop-id.sh` (no argument:
it reads the id Steam wrote into the staged copy). It records the id in
`workshop/workshop_id.txt`, fills the description's "Workshop ID:" line
and the README link above. `workshop/gif_url.txt` needs no change at that
point (it already carries the repo's raw gif URL); rerun
`tools/pack-workshop.sh`, and commit and push.

**Releasing (change notes).** Every player visible change gets a line
under `CHANGELOG.md`'s `Unreleased` heading as it lands, in plain player
words. To cut a release:

1. Move the `Unreleased` lines under a new `## <version> - <date>` heading.
2. Bump `modversion=` in `42/mod.info` (and the root `mod.info`) to match.
3. `bash tests/run.sh` (the changelog bench checks the two agree).
4. `python3 tools/changelog-steam.py` prints the new section as a Steam
   change note and writes it to `workshop/changenote.txt`.
5. `bash tools/pack-workshop.sh` stages the upload and, at the end, prints
   the path to `workshop/changenote.txt` again.
6. Upload from the game (main menu, Workshop, Submit item), and on the
   changelog page of that screen, paste the contents of
   `workshop/changenote.txt` into the text box. **Proven** (client
   install's `WorkshopSubmitScreen.lua`, `SteamWorkshopItem.java`): the
   change note is a plain string typed or pasted into a multi-line
   `ISTextEntryBox` (it takes paste, and up to 512 lines); it is sent
   straight to Steam by `item:submitUpdate()`, never read from
   `workshop.txt` or any other staged file, and the game takes one even on
   the very first upload of a brand new item (it creates the item, then
   immediately submits the same update). No BBCode is parsed on this path
   and no client side length limit was found, so the note is plain text.
7. Commit and push.

**Making the item public.** The uploader reads `visibility=` from the
staged `workshop.txt` on every submit and writes it straight back
(**proven**, `SteamWorkshopItem.java`: `readWorkshopTxt` loads it,
`writeWorkshopTxt` saves it, both run on every Submit item pass). So
flipping the item to public from its own Steam page is not enough on its
own: set `visibility=public` in `workshop/workshop.txt` here too, or the
next upload resubmits `visibility=private` and flips it back.

## Credits

Made by Konijima. Art (the beam head textures, poster and icon) generated
with an AI image model. Sounds (stepping on and off the scale) generated
with an AI sound model.

## Licence

All rights reserved, see [LICENSE](LICENSE): read it, play it, send pull
requests from a fork; do not redistribute it or reupload it to the
Workshop.

