# Dead Weight

![Dead Weight: step on the scale, face the truth](workshop/art/deadweight-banner.png)

*Step on the scale. Face the truth.*

A Project Zomboid mod that shows your exact body weight. The character
screen only tells you a category in words (Emaciated to Obese); step on a
scale and Dead Weight reads the real number, to one decimal, in kg or lb.

![Dead Weight in action](workshop/art/deadweight-animation.gif)

## Features

- **Exact weight on a scale.** Stand on the clinic's beam scale and read your
  weight on a brass and cream beam head that settles like the real thing.
  Walk off and it goes away. Nothing to craft.
- **Digital Scale (Build 42).** A small home scale you can find, place on the
  floor or on a counter, turn and pick up again. See below.
- **Weighs everyone and everything on it:** survivors, animals, zombies and
  items lying on the plate, added up. Anyone within reach reads the same
  number, in multiplayer too.
- **Unit choice.** Left click the readout to switch between kg and lb; the
  choice is remembered.
- **Right click helpers.** "Step on Scale" walks you to the scale; holding an
  animal (Build 42), "Put Animal on Scale" sets it down on the plate.
- **Light.** No per frame world scanning: the readout only exists while
  someone is on the scale and you are next to it.
- Splitscreen aware, 28 languages.

## The Digital Scale (Build 42 only)

A bathroom scale that reads 0 to 130 kg on a plain native panel.

- **On the floor** it weighs people, animals and zombies standing on it, and
  items lying on it.
- **On a counter** it weighs items, like a kitchen scale: right click an item
  and choose "Place Item" on the scale.
- Four facings. Stepping on it turns you to look at its screen, and you only
  read a scale you are facing.

It turns up in the world, only in homes and motels (never a public
restroom), only in new loot and in areas of the map nobody has explored, and
never in front of a toilet, basin or other fixture: inside bathroom counters,
and standing on the floor against a wall in big enough bathrooms.

![A survivor on the Digital Scale, reading in lb](workshop/art/deadweight-digital.png)

![A banana on a counter Digital Scale](workshop/art/deadweight-digital-counter.png)

Build 41 has the clinic scale only.

## Weighing others

With two scales side by side you read the nearest one that has something on
it. Two survivors together read their true combined weight, and a light animal
reads under 35 kg. A zombie has no weight in the game, so each one gets a
believable invented weight, the same every time you see it.

![An animal on the scale, read from the next tile](workshop/art/deadweight-animal.gif)

![A zombie on the scale, read from the next tile](workshop/art/deadweight-zombie.gif)

## Sandbox options

Page "Dead Weight" in the sandbox options.

| Option | Default | Effect |
| --- | --- | --- |
| Weigh what you carry | on | Adds worn items and bag contents to a survivor's reading, so strip naked to read your true body weight. Zombies and animals stay body weight only. |
| Weigh the whole square | off | Counts anything in the scale's square, not only what is on the plate. |
| Reading distance | 1 | Squares away you can stand and still read a scale (0 to 5), in the same room and in line of sight. |
| Digital Scale in bathroom counters | 3 | Loot weight of the Digital Scale in bathroom counters (0 to 20, 0 is never). Build 42 only. |
| Digital Scale on bathroom floors | 20 | Percent chance that an unexplored home or motel bathroom big enough gets one standing on its floor (0 is never). Build 42 only. |

Existing worlds keep the values they already saved.

## Installation

**Steam Workshop (recommended).** <!-- workshop-link:start -->[Dead Weight on the Steam Workshop](https://steamcommunity.com/sharedfiles/filedetails/?id=3804074600).<!-- workshop-link:end -->

**Manual.** The repository root is the mod folder and carries both builds.
Download or clone it into `Zomboid/mods/DeadWeight/` (in your user folder),
then enable **Dead Weight** in the mod list.

## Compatibility

- Build 42, with Build 41 support (the Digital Scale is Build 42 only).
- Singleplayer, multiplayer (client side) and splitscreen.
- Safe next to mods that replace the character screen: the scale keeps
  working and the Info tab stays as that mod or vanilla draws it.
- Incompatible with the original "Weight Scale" mod (item based, full
  nutrition panel): disable it first.

## Contributing

Bug reports and pull requests are welcome. The build, the test bench and the
release steps are in [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md); the changes
per version are in [CHANGELOG.md](CHANGELOG.md).

## Credits

Made by Konijima. Art (the beam head textures, poster and icon) and sounds
were generated with AI models.

## Licence

All rights reserved, see [LICENSE](LICENSE): you may read it, play it and
send pull requests from a fork; do not redistribute it or reupload it to the
Workshop.
