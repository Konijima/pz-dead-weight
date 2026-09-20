# Changelog

Player facing notes, one entry per Workshop release. Every change adds its
line under **Unreleased** in the words a subscriber reads, not the words a
commit reads. At release, `python3 tools/changelog-steam.py` prints the
newest section in the form to paste into the Steam upload screen's change
note box.

## Unreleased

- The scale now reads everyone standing on it: the readout adds up the
  weight of every survivor, animal and zombie on the tile (zombies get an
  invented weight), and two people together simply pin the beam at the top.
  A doctor standing within two squares in the same room reads it too, so
  you can weigh a patient. Only the first person stepping on or off makes
  the sound.

## 1.0.0 - 2026-09-18

First release of Dead Weight, the successor of the old "Weight Scale" mod,
rebuilt for Build 42 while keeping Build 41 support.

- Stand on the clinic's beam scale to read your exact weight. No item and
  no menu needed.
- The beam head readout slides toward your weight and settles, to one
  decimal.
- Left click the readout to switch kg and lb. Right click it to switch to
  a plain panel instead of the beam head look. Both choices are
  remembered.
- The character screen's Info tab now shows only a weight category
  (Emaciated to Obese) with its trend arrow. See the exact number on the
  scale.
- Your survivor turns to face the scale when you stop on it.
- Two short sounds, stepping on and stepping off.
- "Step on Scale" at the top of the scale's right click menu.
- Splitscreen: each local player gets their own readout.
- 28 languages. Corrections welcome.
- Very light: no per frame scanning.
- The old item based Weight Scale and its full stats panel are retired.
  Disable the old mod before enabling this one.
