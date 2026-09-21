# Development

How to build, test and release Dead Weight. Player facing information is in
the [README](../README.md); the rules for working in this repository are in
[CLAUDE.md](../CLAUDE.md).

Requirements for the bench: `lua5.1` (or `lua`), `node` and `python3` on
`PATH`.

## Layout and tools

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
- `tools/gen-tiles.py` builds the Digital Scale's tile pack from
  `src/tiles/*.png` (called by `sync.sh`); `tools/gen-scale-art.py` draws
  those four faces and is run by hand only.
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
- `workshop/art/deadweight-banner.png` and `workshop/art/deadweight-banner-2.png`
  are the Workshop page banners (also the README images above); neither is
  shipped to players, see the `pack-workshop.sh` bullet above.
- `workshop/art/320/` holds the images the Workshop page shows, scaled to 320 px
  wide (a wider image makes Steam's mobile page scroll sideways);
  `tools/gen-workshop-art.py` regenerates them from the full size originals in
  `workshop/art/`, which the README uses. A new Workshop image goes into that
  script's list. `deadweight-sprites.png` there (the clinic scale next to the
  Digital Scale's four faces) comes from `tools/gen-workshop-sprites.py`, which
  needs a Project Zomboid install.
- `workshop/description.bbcode` is the hand edited source of the Workshop
  page text; `tools/gen-workshop-txt.py` regenerates the `description=`
  lines of `workshop/workshop.txt` from it and from `workshop/gif_url.txt`,
  which already holds the gif's raw GitHub URL
  (`https://raw.githubusercontent.com/Konijima/pz-dead-weight/main/workshop/art/320/deadweight-animation.gif`);
  an empty file emits no `[img]` tag rather than a broken one. The images
  load from `main`, so a new image is a broken link on the Workshop page
  until it is merged and pushed. The description's own
  [GitHub](https://github.com/Konijima/pz-dead-weight) link points bug
  reports and translation fixes back here.

## After the Workshop upload

Run `tools/set-workshop-id.sh` (no argument:
it reads the id Steam wrote into the staged copy). It records the id in
`workshop/workshop_id.txt`, fills the description's "Workshop ID:" line
and the README's Install link. `workshop/gif_url.txt` needs no change at that
point (it already carries the repo's raw gif URL); rerun
`tools/pack-workshop.sh`, and commit and push.

## Releasing (change notes)

Every player visible change gets a line
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

## Making the item public

The uploader reads `visibility=` from the
staged `workshop.txt` on every submit and writes it straight back
(**proven**, `SteamWorkshopItem.java`: `readWorkshopTxt` loads it,
`writeWorkshopTxt` saves it, both run on every Submit item pass). So
flipping the item to public from its own Steam page is not enough on its
own: set `visibility=public` in `workshop/workshop.txt` here too, or the
next upload resubmits `visibility=private` and flips it back.
