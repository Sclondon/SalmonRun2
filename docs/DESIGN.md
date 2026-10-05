# Salmon Run 2: design document

What the game is and how it is put together, as built so far. The README covers how to run,
export and test it; this is the design. Last updated 2026-10-05.

## 1. The pitch

A low-poly trick racer about one sockeye salmon's life. You swim a course, jump, spin and
flip for points in time with a drum & bass soundtrack, and the courses add up to the salmon
life cycle: the long swim home from the ocean to spawn, then the next generation's run back
down to the sea.

- **Feel:** SSX-style tricks on water. Fast, forgiving, score-chasing.
- **Platform:** phones first (web build, one-finger gestures), also keyboard and gamepad.
- **Look:** chunky low-poly 3D behind an adjustable retro filter, with a clean 1990s
  educational ("Utopian Scholastic") interface over it.
- **Subject:** real, lightly taught. Stages are real places on a real globe, the life-cycle
  terms are the National Park Service's, and the fish changes the way a sockeye does.

Reference for the life cycle:
<https://www.nps.gov/olym/learn/nature/the-salmon-life-cycle.htm>

## 2. A run

A run is the whole life cycle, so every stage on it is swum twice.

1. **Spawning migration** (late summer into autumn, upstream). The adult swims from the
   Open Ocean to a spawning ground. It is silver at sea and turns red and green in fresh
   water. From the coast on, the water climbs.
2. **Seaward migration** (spring, downstream). The adults spawn and die; you swim the same
   stages back to the ocean as one of their young, a small silver smolt. The rivers fall
   away again and the scenery is in its spring colours.

Reaching the ocean ends the run. Best scores are kept per stage and per direction.

### Flow of screens

Title → **NEW RUN** → globe on the Open Ocean → START → intro → stage → results → globe (pick the
way on) → travel line → next stage → ... → spawning ground → spawning scene → the
same stages in reverse → the Open Ocean → outro → the run's summary page.

- **Cutscenes** are a handful of captions over the stage that is loaded, filmed by a roving
  camera between black bars while the salmon swims on its own. Any press skips them. There
  are three: the intro (the call home), spawning at the end of the way up (a different
  telling at a fish farm), and the outro when the young reach the ocean.
- **Results** are a field report on a sheet of paper after every stage: the rank stamped in
  red, the score, the figures, and whether the stage's goal was met.
- **The summary** at the end of a run lists both legs stage by stage with the total.

## 3. The map

Two routes, **North America** and **Japan**. They share the first three steps and part at
step 4. Each has a fish farm as a short, easy early ending and a home lake at the end of the
full run.

Each stage names the stages it leads to. The **first is the default** way on. The others are
**advanced** ways, opened by meeting that stage's goal; otherwise they are shown locked.

| Step | Stage | Where | Leads to (default first) | Goal to open the rest |
|---|---|---|---|---|
| 1 | Open Ocean | mid Pacific | Shallow Sea, Ocean Trench | collect 12 rings |
| 2 | Shallow Sea | Bering Sea | Coastline, The Harbor | 5 tricks on the beat |
| 2 | Ocean Trench | Mariana Trench | Coral Reef, Arctic Waters | 5 tricks on the beat |
| 3 | Coastline | off British Columbia | The Fish Ladder, Dry Riverbed | no more than 2 wipeouts |
| 3 | The Harbor | Puget Sound | The Fish Farm, The Fish Ladder | score 60K |
| 3 | Coral Reef | off Okinawa | Neon Harbor, Meandering River, Dry Riverbed | collect 14 rings |
| 3 | Arctic Waters | Bering Strait | Meandering River, Neon Harbor | collect 12 rings |
| 4 | Meandering River | inland of Seattle | Rainforest Falls, Alpine Run | score 70K |
| 4 | Dry Riverbed | near Bend, Oregon | Alpine Run, The Home Lake | collect 12 rings |
| 4 | The Fish Ladder | Seattle | Alpine Run, The Home Lake | 6 tricks on the beat |
| 4 | The Fish Farm | north Puget Sound | early ending | |
| 4 | Neon Harbor (Japan) | Tokyo Bay | The Hatchery, Bamboo River | score 60K |
| 5 | Rainforest Falls | Mount Rainier | The Home Lake | |
| 5 | Alpine Run | Mount Rainier | The Home Lake | |
| 5 | Bamboo River (Japan) | Hokkaido | The Crater Lake | |
| 5 | The Hatchery (Japan) | north Honshu | early ending | |
| 6 | The Home Lake | Mount Rainier | ending | |
| 6 | The Crater Lake (Japan) | Hokkaido | ending | |

Notes:
- The Home Lake can be reached a step early from Dry Riverbed or The Fish Ladder.
- The Crater Lake and The Hatchery play exactly like The Home Lake and The Fish Farm; only
  the scenery differs. Neon Harbor shares The Harbor's look in different light but has its
  own course.
- The way down retraces the stages the run came up through.

## 4. Stages

A stage is a river-shaped course about 2.4 to 3.4 km long (roughly 55 to 95 seconds),
generated from one entry in `scripts/world/levels.gd`. An entry sets the course (length,
width, slope, how much it bends, what it is made of, how often waterfalls come), the scenery
(bank shape and colours, a table of dressing rules), and the sky, fog, light and water.

**What a course is made of**

| Piece | What it does |
|---|---|
| Ramps | Kick you into the air. Rings mark the arc. |
| Rails | Bamboo, logs or pipes to grind along; land on one or swim onto its end. |
| Rocks | Rapids full of rocks (ice, coral heads, containers). Clip one swimming and you are bumped; hit one in the air and you wipe out. |
| Rings | Trails to collect: points and boost. |
| Predators | Sharks at sea, bears in rivers. They strike on every other beat; jump them or steer wide. |
| Waterfalls | Going up: a wall 2.6 to 4 m high to leap, or be washed back 40 m. Going down: a drop of 9 to 20 m to launch off. |

**The stages at a glance**

| Stage | Look | Water | Predator | Notable |
|---|---|---|---|---|
| Open Ocean | night, moon, buoys, ships far off | flat, open | shark | drifting containers as hazards |
| Shallow Sea | bright reef between sandbars | flat | shark | |
| Ocean Trench | near-black water, glowing jellyfish, seamounts | flat, open | shark | |
| Coastline | golden-hour river mouth, beaches, palms | barely climbs | shark | |
| The Harbor | quays, cranes, sodium light | barely climbs | shark | |
| Coral Reef | pink dawn lagoon, dense coral | flat, open | shark | |
| Arctic Waters | pack ice and icebergs under an aurora | flat, open | shark | |
| Meandering River | farmland, barns, windmills; very winding | gentle climb | none | harvest gold in autumn, green in spring |
| Dry Riverbed | red-rock canyon, cacti, mesas | climbs | none | a few waterfalls; blooms in spring |
| The Fish Ladder | concrete channel through forest | climbs | none | a waterfall every 170 m |
| The Fish Farm | net pens on a grey lake | flat, open | none | short; feed barrels are the only obstacles |
| Neon Harbor | The Harbor under pink city light | barely climbs | shark | |
| Rainforest Falls | temperate rainforest: big conifers, ferns, mist | climbs | bear | the training course borrows its look |
| Alpine Run | granite gorge; gold larches in autumn, snow in spring | steepest | bear | most waterfalls and rocks |
| Bamboo River | Japanese mountain stream: bamboo, torii, lanterns | climbs | bear | red maples in autumn, cherry blossom in spring |
| The Hatchery | The Fish Farm with bamboo ashore | flat, open | none | |
| The Home Lake | wide calm lake ringed by peaks | flat, open | none | ramps, rails and rings only |
| The Crater Lake | The Home Lake with maples and torii | flat, open | none | |

Seasons are part of each entry: the base settings are autumn (the way up), and a `spring`
block replaces whatever changes on the way down.

Other salmon (five to eight) swim every course alongside you, matching your life stage. They
avoid rocks, ride ramps and leap falls. They are company only.

## 5. Controls

**Touch (and mouse, which counts as a finger)**

| Gesture | On the water | In the air |
|---|---|---|
| Hold | the salmon swims to under your finger | |
| Swipe up | full jump (also hops off a rail) | backflip |
| Swipe left / right / down / diagonal | | one full 360 that way: spin, frontflip, or both |
| Wiggle back and forth | boost | |
| Circles | | corkscrew, the way the finger goes round |

Touch has no grabs yet.

**Keyboard / gamepad** keep the fuller set: steer, swim harder or brake, hold-and-release
jump (charge), boost, corkscrew, four grabs. See the README for the bindings.

## 6. Scoring

- **Tricks** bank when you land: flips, spins (per 180), corkscrews, grabs, air time, Big
  Air, rail grinds. Three or more parts in one jump earn a 25% bonus.
- **Landing** must be roughly upright with no grab held, or it is a wipeout.
- **Flow** is the multiplier: +1 for each clean trick up to x5. It resets on a wipeout or a
  bump, or after 4 seconds on the water without a trick.
- **On the beat:** landing within about 95 ms of a beat is x1.5; within about 45 ms is x2.
- **Rings** are 250 points and some boost each. Tricks also refill boost.
- **Ranks** D to S at 35K / 70K / 110K / 160K, scaled so shorter stages are judged fairly.
- **Wipeout:** about one second out of control, then a moment of invulnerability.

## 7. Music

Six tunes, one per step of the map, synthesized in code and baked to audio files. Stages on
the same step share a tune.

| Step | Tune | BPM |
|---|---|---|
| 1 | Abyssal | 150 |
| 2 | Reef Break | 160 |
| 3 | River Mouth | 166 |
| 4 | Upriver | 174 |
| 5 | White Water | 186 |
| 6 | Homecoming | 178 |

The beat clock follows whichever tune is playing, so the countdown, on-beat landings,
predators and the pulsing scenery all keep time with it. The music is muffled briefly on a
wipeout and during long air.

## 8. The globe screen

The only map the run has. It is a full-screen scene: the Earth (NASA's Blue Marble picture,
drawn in big pixels) in space, with an atmosphere, a cloud layer above the ground and three
hurricanes. It turns to face the stage in hand and never zooms.

- **Pins** mark stages. A run shows only the pins it has touched.
- **The way so far** is a solid red line. **Ways on** are dashed until one is picked; locked
  ones are grey.
- **Ways on that are too close to tell apart** (the Rainier and Puget Sound groups) are
  fanned out round your pin.
- **The card** shows a picture of the stage in hand, its name, coordinates, a one-line
  description, and two buttons (BACK and START or SWIM). Arrows either side step between
  the ways on. It sits under the globe on a phone, covering a little of the bottom of the
  Earth, and beside it on a wide screen. The arrangement follows
  `conceptArt/ui/levelSelect.png`.
- **Between stages** the same globe draws the red line across to the next one.

## 9. Other modes and tools

- **Practice:** a stage select (the globe with every stage listed beside it). Any stage, in
  either direction, with no countdown, goal or finish; it loops and nothing is saved. Also
  the **training course**: a short straight river with one of everything.
- **Tester mode** (Options): start a run on any stage, and skip to the end of a stage with
  its goal met or missed.
- **Options:** music and SFX volume, and the retro filter in four sliders (pixel size,
  colour dither, wobble, dark corners). Also on the pause menu.
- **How to play** is off the menu until the controls settle.

## 10. Interface style

1990s educational software and science books: Libre Baskerville for headings, Jost for
everything else, navy plates with a cream rule, cream paper buttons that turn gold in hand,
and a few primary colours. The title is set like a book cover. Wording is terse and uses
the life-cycle terms. All of it is defined in `scripts/ui/ui_kit.gd`.

## 11. How it is built

Godot 4, almost entirely generated at startup: meshes, courses and scenery are procedural,
and the music and sound effects are synthesized offline by scripts in the project.

| Area | File |
|---|---|
| Game flow, menus, globe screen, results | `scripts/main.gd` |
| Stages and how they connect | `scripts/world/levels.gd` |
| Course generation from a stage | `scripts/world/track.gd` |
| Procedural meshes | `scripts/world/props.gd` |
| The salmon: movement, tricks, hazards, autopilot | `scripts/player/salmon.gd` |
| The other salmon | `scripts/world/school.gd` |
| Predators | `scripts/world/bear.gd` |
| Touch gestures | `scripts/ui/touch_controls.gd`, `scripts/autoload/game_input.gd` |
| Globe | `scripts/ui/globe.gd`, `shaders/globe.gdshader` |
| Music and the beat clock | `scripts/autoload/music.gd`, `scripts/audio/` |
| Saves and settings | `scripts/autoload/save.gd` |

Movement is simulated in "track space" (distance along the river, offset across it, height),
which keeps it robust on a twisting course. An autopilot plays the game for the title
screen and for the automated smoke test.

## 12. Known gaps

Things that are true of the build today and likely to matter for the next round of work.

- **Downstream courses are not the upstream ones reversed.** Same stage, same look, but a
  different layout.
- **Several stages have no predator** (Meandering River, Dry Riverbed, The Fish Ladder, the
  farms and lakes), and the sea stages all share the shark.
- **Stages differ mostly in scenery and mix**, not in mechanics. Only the uphill waterfalls
  and the open-water stages really play differently.
- **Touch cannot grab**, so the highest-scoring tricks are keyboard and
  gamepad only.
- **The smolt plays exactly like the adult**, only smaller.
- **Stages around Mount Rainier and Puget Sound are a few miles apart**, so their pins are
  fanned out rather than shown in place.
- **Phone performance and feel are lightly tested.** Most checks have been scripted runs on
  a desktop.
- **The cutscenes are captions over ordinary swimming.** Nothing in them is staged: no redd,
  no eggs, no death of the adults on screen.

## 13. Next up

The next round is level details, game feel and animation. Starting points:

- **Level details:** give each stage something of its own to do, not only to look at; set
  pieces and landmarks; hazards that fit the place; course layouts tuned by hand where the
  generator is bland.
- **Game feel:** take-off and landing weight, speed sensation, camera, boost, hit and
  wipeout feedback, the leap up a waterfall, rail grinds, sound on every action.
- **Animation:** the salmon's swim, jump, spin, flip, grab and wipeout; the life-stage
  change from ocean silver to spawning red; predators' strikes; the other salmon; water and
  splash effects; the spawning moment itself.
