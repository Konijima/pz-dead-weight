# Changelog

Player facing notes, one entry per Workshop release. Every change adds its
line under **Unreleased** in the words a subscriber reads, not the words a
commit reads. At release, `python3 tools/changelog-steam.py` prints the
newest section in the form to paste into the Steam upload screen's change
note box.

## Unreleased

- New furniture, Build 42 only: the Digital Scale, a small bathroom scale you can place on the floor or on a counter, in four facings, and pick up again. This is the furniture only for now; it does not read your weight yet.
- The Digital Scale reads weight: people, animals and zombies on the floor, and items on it or on a counter. It shows the plain native panel and reads 0 to 130 kg. The clinic scale keeps its beam head readout.
- The Digital Scale can now turn up: inside bathroom counters, the cupboards under a basin (new sandbox setting "Digital Scale in bathroom counters", 0 to 20, default 3, 0 is never), and standing on the floor against a wall in big enough bathrooms that nobody has seen yet (new sandbox setting "Digital Scale on bathroom floors", percent, default 20, 0 is never). Only new loot and areas of the map you have not explored are affected: rooms you have already visited never get one. A counter never holds two, and a bathroom gives out at most one from its counters. Build 42 only.
- The right click style switch between the beam head and the panel is gone: each scale now has its own look. Left click still switches kg and lb.
- Stepping onto the Digital Scale turns you to look at its screen, like the clinic scale's column.
- You only read a scale you are facing. Turn away and the readout goes; turn back and it returns.
- On a counter, the Digital Scale sits back from the front edge and items you set on it are lifted onto its plate. "Step on Scale" is not offered for a scale on a counter.
- A survivor walking through the square of a scale on a counter (for example a low counter in front of a window) is no longer weighed, nor turned to face it. Climbing through the window over the scale still reads.
- Fixed the step on and off sound with two scales in reach: it no longer plays just because a scale with something on it comes into view or goes out of view. It plays only when something is put on, or taken off, the scale you are watching.

## 1.2.0 - 2026-09-21

The scale reads what lies on it and what you carry, and it works better with other people around.

- Everything lying on the scale's plate is weighed, once, and added to whoever stands on it. An item left on the scale is read by anyone in reach, as if someone were on it, and small items dropped on the plate are lifted onto it instead of sinking under it.
- The scale now reads only what stands or lies on the plate itself, not anything in its square. New sandbox setting "Weigh the whole square" (off by default) brings back the old whole square behaviour.
- New sandbox setting "Weigh what you carry" (off by default): each survivor's reading also adds everything they carry, worn items and bag contents included. Zombies and animals still read their body weight only.
- Multiplayer: everyone in reach reads the same number as the player on the scale, down to the last digit, including what the player carries when "Weigh what you carry" is on.
- New sandbox setting "Reading distance": how many squares from the scale you can stand and still read it. Default 2 (it was 1), 0 to 5.
- You read a scale only if you could see it: a wall, a shut door or a barricade between you and the scale hides it, and the reading comes back when the view opens again.
- With two scales side by side, you read the nearest one that has something on it, not just the nearest one. Walking straight from one scale onto the next turns you to face the new one.
- If the scale is picked up and set down again while you stand in range, you read it again right away instead of having to walk out and back.
- The step on and off cue plays on your own machine for everyone who sees the reading, including when only an item is put on the scale or taken off. In multiplayer it is no longer heard twice, and it follows the game's Sound Volume setting: at zero it is silent, before it was still heard.
- Holding an animal in your hands, the scale's right click menu offers "Put Animal on Scale": you walk up next to the scale, turn to face it, and set the animal down on the plate, where it reads its own weight. Build 42 only, and single player for now: in multiplayer the animal would vanish, so the option is hidden there.

## 1.1.0 - 2026-09-20

The scale now weighs whoever stands on it, not only you.

- Whatever stands on the scale is weighed: survivors, animals and zombies,
  added up. Zombies have no weight in the game, so each one gets a
  believable invented weight, the same every time you see it.
- Stand on the scale or one square away in the same room and you read the
  same number, so a doctor can weigh a patient.
- The number is always the true total: a light animal reads under 35 kg,
  two survivors together read over 130 kg. The beam simply rests at its low
  or high end.
- Only the first person to step on or off hears the sound.

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
