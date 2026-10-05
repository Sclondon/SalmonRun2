# Salmon Run 2

Low-poly retro trick racer: you're a sockeye salmon heading home, from the deep ocean to the
mountain lake you hatched in, to a procedural
jungle / drum & bass soundtrack. SSX-style tricks, waterfalls, rails, sharks and bears.

Godot **4.7**, Forward+. Open `project.godot` and press F5.

## Controls

| Keyboard | Gamepad | Touch | On the water | In the air |
|---|---|---|---|---|
| A/D, ←/→ | left stick / d-pad | hold: swims to your finger | steer | spin |
| W/S, ↑/↓ | left stick / d-pad | — | swim harder / brake | front / back flip |
| Space (hold → release) | A | swipe up | charge + leap (a swipe is a full leap) | — |
| — | — | swipe any of 8 directions | — | one full turn that way: left / right spin, up backflip, down frontflip |
| Shift | LT | draw little circles | boost | — |
| Q / E | LB / RB | — | — | corkscrew |
| J K L I | X Y B RT | — | — | grabs (release before landing!) |
| Esc / P | Start | ⏸ | pause | |

Touch is gestures only for now (no corkscrew or grabs), and the mouse counts as a finger.
**PRACTICE** on the title screen opens a stage select (the globe with every stage listed beside
it): pick any stage, in either direction, to swim
it with no countdown, goal or finish (it loops, and nothing is saved). TRAINING COURSE there is
a short, straight river with one of everything (ring slalom,
jump rings, ramps, rails, rocks, a waterfall) that loops forever, for trying the controls.

## The journey

A run is the whole life cycle (after the National Park Service's
[salmon life cycle](https://www.nps.gov/olym/learn/nature/the-salmon-life-cycle.htm)), so every
stage is swum twice:

1. **Spawning migration** (late summer into autumn): the adult swims from the deep ocean up
   to the spawning grounds. It is silver at sea and turns red and green in fresh water.
2. **Seaward migration** (spring): the adults spawn and die, and you swim the same stages back
   down to the ocean as one of their young, a small silver smolt.

All stages are open from the map for now, in either direction.
SWIM! always starts a run at the Open Ocean. The way up branches like Star Fox 64's map, and
the map is a little globe (NASA's Blue Marble picture, pixelated, under drifting cloud): when
you finish a stage it shows the way you have come as a red line and the ways on as pins. Look
between them with left / right or a tap, then swim; ways you did not earn are shown locked.
The same globe then draws the line across to the stage you picked.

Each stage lists the stages it leads to (`next` in `levels.gd`). The first is the default way
on; the others are more advanced routes, opened by meeting that stage's goal (shown under the
progress bar: so many rings, tricks on the beat, a flow, a score, or few wipeouts).

| Step | Stage | Leads to (default first) |
|---|---|---|
| 1 | Open Ocean | Shallow Sea, Ocean Trench |
| 2 | Shallow Sea | Coastline, The Harbor |
| 2 | Ocean Trench | Coral Reef, Arctic Waters |
| 3 | Coastline | The Fish Ladder, Dry Riverbed |
| 3 | The Harbor | The Fish Farm, The Fish Ladder |
| 3 | Coral Reef | **Neon Harbor**, Meandering River, Dry Riverbed |
| 3 | Arctic Waters | Meandering River, **Neon Harbor** |
| 4 | Meandering River | Rainforest Falls, Alpine Run |
| 4 | Dry Riverbed | Alpine Run, The Home Lake (an early finish) |
| 4 | The Fish Ladder | Alpine Run, The Home Lake (an early finish) |
| 4 | The Fish Farm | an early ending |
| 4 | **Neon Harbor** | **The Hatchery**, **Bamboo River** |
| 5 | Rainforest Falls, Alpine Run | The Home Lake |
| 5 | **The Hatchery** | an early ending |
| 5 | **Bamboo River** | **The Crater Lake** |

There are two routes. Everything is shared up to step 3; from step 4 the **Japan route** (bold
above, pink on the map) splits off at Neon Harbor, which can only be reached from Coral Reef or
Arctic Waters, and the rest is North America. Each route has a fish farm as a quick, easy early
ending (the default way on from its harbor) and a home lake at the end of the full run.

The pins are real places: the open ocean in the mid Pacific, the Bering Sea, the Mariana
Trench, a reef off Okinawa, the British Columbia coast, Puget Sound and the rivers behind it, Bend in Oregon and
Mount Rainier; then Tokyo Bay and Hokkaido. Stages can be oceans or a few miles apart, so the globe zooms in
until the stage in hand and its neighbours are clear of each other.
The way back down retraces the stages you came up through.

Each stage is one entry in `scripts/world/levels.gd` (tier, route, goal, course shape, what it
is made of, bank profile, scenery rules, colours, sky and light, plus a `spring` block for
whatever changes on the way back down), so tuning or adding one is editing that table.
Best scores are kept per stage and direction, and ranks are scaled to a full-length course.

Heading up, from the coast on, the river climbs and a waterfall is a wall of water 2.6 to 4 m
high. Jump (a swipe, or a fully charged Space) roughly 10 to 25 m before it to clear the top;
come up short and you are WASHED BACK 40 m for another run at it. Heading down, the same
rivers fall away and the waterfalls are big drops to launch off.

Other salmon swim the course with you. They are company, not obstacles.

## Scoring

- Tricks bank on landing: flips, spins, corkscrews, grabs, airtime, Big Air, Bamboo Grind.
- **Flow** multiplier: +1 per clean trick (max x5); resets on wipeout or 4 s on the water without a trick.
- **On the beat**: landing within ~95 ms of a beat is x1.5, within ~45 ms is x2 (PERFECT).
- Rings: +250 and boost. Ranks D → S at 35k / 70k / 110k / 160k.

## Music

Every tier of the map has its own tune (stages side by side share one), each at its own tempo:
Abyssal (150 BPM), Reef Break (160), River
Mouth (166), Upriver (174), White Water (186) and Homecoming (178). The beat clock follows
the tune, so on-beat landings, the countdown and the predators all keep time with it. They are
the `STYLES` in `scripts/audio/dnb_synth.gd`, listed in level order in `Songs.TRACKS`.

## Project layout

| Path | What |
|---|---|
| `scripts/main.gd` | game flow (title → countdown → race → results), menus, low-res render target, autotest |
| `scripts/autoload/music.gd` | plays the baked soundtrack; beat clock + `beat_pulse` shader global |
| `scripts/autoload/sfx.gd` | plays the baked sound effects |
| `scripts/audio/` | the procedural DnB + SFX synthesizers and the song arrangements |
| `scripts/tools/bake_audio.gd` | renders the synths into `audio/*.wav` |
| `scripts/world/levels.gd` | the stages and the map: everything that makes one look and play differently, and how they connect |
| `scripts/world/school.gd` | the other salmon swimming along with you |
| `scripts/ui/globe.gd` | the globe on the map and travel screens (stage pins come from each stage's `at`) |
| `scripts/world/track.gd` | course generation from a level: centre-line, waterfalls, ramps, rails, rocks, rings, predators, scenery |
| `scripts/world/props.gd` | procedural low-poly meshes (salmon, trees, bear, shark, icebergs, coral, speakers…) |
| `scripts/player/salmon.gd` | movement in track space (s, x, y), tricks, grinds, wipeouts, autopilot |
| `shaders/` | PS1 vertex snap, water, fish wag, sunset sky, dither post-process |

Meshes are generated at startup. Music and SFX are synthesized in GDScript too, but offline:
per-sample GDScript is far too slow to run live on the web, so after changing anything in
`scripts/audio/` re-bake them:

```
godot --headless --path . -s scripts/tools/bake_audio.gd
godot --headless --path . --import
```

Tweak a course with its `length`, `seed` and `kinds` in `levels.gd`.
The UI font is Pixelify Sans (SIL OFL, see `fonts/PixelifySans-OFL.txt`).

## Web build / Scareathon arcade

The game is published with GitHub Pages at <https://sclondon.github.io/SalmonRun2/build/> and
runs as a cabinet in the Scareathon arcade. When a race finishes it posts
`{ type: 'PLAYER_DIED', score }` to the parent page, which submits it to the arcade leaderboard.

To update it: export the **Web** preset (Project → Export, or
`godot --headless --path . --export-release "Web" build/index.html`), commit `build/`, push, then
bump the `?v=` cache-buster on `SALMON_RUN_2_URL` in the arcade's `src/pages/Arcade/page.tsx`.
Web builds use the Compatibility renderer and have no threads.

## Automated smoke test

```
godot --path . -- --autotest=C:/some/folder
```
Plays a full race on autopilot (add `--level=N` to pick the stage and `--down` for the downstream leg, or `--practice` for a minute on the practice level), saves screenshots to that folder, prints the result and quits
(autotest runs never touch your high score).
