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
   Open Ocean to a spawning ground. It is silver at sea, turns as it enters fresh water,
   and is red and green by the upper rivers. From the coast on, the water climbs.
2. **Seaward migration** (spring, downstream). The adults spawn and die; you swim the same
   stages back to the ocean as one of their young: a fry in the lake, a barred parr in the
   rivers, a silver smolt by the sea. The rivers fall
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

**The stages are joined up into one run of water.** A run is not a string of separate
screens: the salmon never leaves the water between one stage and the next.

- **After the finish the salmon swims on by itself**, down a long run-out of plain water that
  every stage has beyond its finish (`Track.RUN_OUT`, 520 m), at its ease, while the results
  are read over the picture. CONTINUE lets the globe down from above the screen (just the
  globe, with nothing round it), which draws the way to the next stage, with the ways not
  taken greyed out and dashed (shut ones marked LOCKED), while that stage is made out of
  sight (`World.make_next`). When the globe has got there the salmon is on the new stage
  (`World.take_next`): the old one is gone, the sky, the haze and the light turn to the new
  one's over a moment, the globe goes back up, and the stage is under way at once, with no
  countdown. (`main._coast`, `_travel_on`, `_arrive`.) The way back down is joined up the
  same way; the cutscenes between the way up and the way down, and at the end, are as they
  were. PRACTICE and the tester's stage picker still go straight to a stage.
- **The way on is chosen on the water**, at a fork near the end of every stage whose way
  divides (`Track._plan_fork`). Something lies along the course there and divides it into as
  many ways as there are: the left-hand one is the default, the others the advanced. At sea,
  where there is room, it is a cruise ship as big as a real one (some 320 m by 48 m); in a
  river, an island; a stage with three ways on has two of them. A boom of red buoys runs
  from the right-hand edge of the water to the first bow and shuts every way but the
  left-hand one, with a sign over each saying what the goal is, for as long as the goal is
  not met; it opens the moment it is, and shuts again if a goal is lost (few wipeouts). The
  side the salmon passes the bow on is the way it goes.
- **The abyss is a special case.** On the Open Ocean the ship only lies in the course: the
  way on (Shallow Sea) is past it on either side, and the advanced way (Ocean Trench) is
  *down*: a giant current, 9 m across the radius, that begins a dive under the surface to
  the right of the ship and goes down six layers. It is only there once the goal is met.
  Dive into it and it carries the salmon down, through the finish, and on into the trench.
- **The Ocean Trench is swum all under the water** (`"submerged"` in `levels.gd`): six
  layers deep, nothing on its surface, no coming up and no jumping, until a current near
  its end climbs back to the surface and throws the salmon out, ahead of its own fork.
- **Every stage has a fork of its own**, and it need not be at the end (`"divider"` and
  `"fork_at"` in `levels.gd`): sea stacks in the Shallow Sea and at the end of the trench, a
  gravel bar on the Coastline, an iceberg in Arctic Waters, a pier in the harbours and the
  fish ladder, a reef in the Coral Reef (two of them: three ways), an island in the
  Meandering River, a logjam in the Dry Riverbed. Only the Open Ocean has the cruise ship.
  Once the way is chosen the rest of the stage is swum as usual.
- **The next stage comes up out of the distance.** It is joined on to the run-out some 130 m
  ahead of the salmon, in the haze, and swum up to: nothing appears round the salmon. When
  the globe has shown the way it goes back up, the sky, the light and the water (this stage's and the next one's together, so that there is no line where they meet) turn to the next
  stage's, and the salmon is the player's again from there.

Not done yet: the next stage is made in one go (about a third of a second on a desktop,
longer on a phone: a hitch while the globe is coming down).

Each stage names the stages it leads to. The **first is the default** way on. The others are
**advanced** ways, opened by meeting that stage's goal; otherwise they are shown locked.

| Step | Stage | Where | Leads to (default first) | Goal to open the rest |
|---|---|---|---|---|
| 1 | Open Ocean | mid Pacific | Shallow Sea, Ocean Trench | collect 12 rings |
| 2 | Shallow Sea | Gulf of Alaska | Coastline, The Harbor | 5 tricks on the beat |
| 2 | Ocean Trench | Mariana Trench | Coral Reef, Arctic Waters | 5 tricks on the beat |
| 3 | Coastline | off British Columbia | The Fish Ladder, Dry Riverbed | no more than 2 wipeouts |
| 3 | The Harbor | Puget Sound | The Fish Farm, The Fish Ladder | score 60K |
| 3 | Coral Reef | off Okinawa | Neon Harbor, Meandering River, Dry Riverbed | collect 14 rings |
| 3 | Arctic Waters | Bering Strait | Meandering River, Neon Harbor | collect 12 rings |
| 4 | Meandering River | inland of Seattle | Rainforest Falls, Mountain River | score 70K |
| 4 | Dry Riverbed | near Bend, Oregon | Mountain River, Alpine Lake | collect 12 rings |
| 4 | The Fish Ladder | Seattle | Mountain River, Alpine Lake | 6 tricks on the beat |
| 4 | The Fish Farm | north Puget Sound | early ending | |
| 4 | Neon Harbor (Japan) | Tokyo Bay | The Hatchery, Bamboo River | score 60K |
| 5 | Rainforest Falls | Mount Rainier | Alpine Lake | |
| 5 | Mountain River | Mount Rainier | Alpine Lake | |
| 5 | Bamboo River (Japan) | Hokkaido | The Crater Lake | |
| 5 | The Hatchery (Japan) | north Honshu | early ending | |
| 6 | Alpine Lake | Mount Rainier | ending | |
| 6 | The Crater Lake (Japan) | Hokkaido | ending | |

Notes:
- Alpine Lake can be reached a step early from Dry Riverbed or The Fish Ladder.
- The Crater Lake and The Hatchery play exactly like Alpine Lake and The Fish Farm; only
  the scenery differs. Neon Harbor shares The Harbor's look in different light but has its
  own course.
- The way down retraces the stages the run came up through.


### Lately (not yet worked into the sections above)

- **The screen:** no boost meter; the best score small under the score; the time beside a
  pause button drawn as a card; the beat kept by a row of four pixel salmon that leap in turn
  (`ui/beat_fish.gd`); the timing grades in a speech bubble beside the salmon (`fx/speech.gd`).
- **A waterfall not cleared** tumbles the salmon back down the stream (it is not set down
  further back), and the foot of a fall is made of the same drops and splats as its splash.
- **Far-off hills and mountains come up over the horizon** (`horizon_drop` in `psx.gdshader`,
  `Track.mat_far`), and pines have needles drawn on them (`needles`, `Track.mat_pine`).
- **Fresh water has trout and sturgeon** (`sea_visitors.gd`), and now and then a golden
  trout: touch it and it joins the pack for the rest of the run (`School.join`).
- **The salmon is the player's again as soon as the globe comes down** between stages;
  nothing scores until the next stage begins.
- **Bears are life size** (`Track.BEAR_SIZE`).
- **The spawning is played out** under the water at the end of the way up (`fx/spawning.gd`,
  filmed by the camera's STAGE mode): the nest dug, the eggs laid and fertilised and covered,
  the hatching, and the young setting off; then the way down begins.
- **On a log** the salmon arches its back and throws up wet sparks, and a swipe to one side
  spins it round (worth more, and named: "Log Ride + 360").
- **Alpine Lake** is 70 m wide and three layers deep, with no buoys.
- **The swoop:** swum up from the deep without a check, the salmon goes on up out of the
  water, the higher the further it climbed. Going up and down under the water is no faster
  than the water is deep, and takes a longer drag on a touch screen.

## 4. Stages

A stage is a course about 2.4 to 3.4 km long (roughly 55 to 95 seconds): open water 70 to
140 m wide at sea, a river 16 to 21 m wide inland, a lake or harbour 22 to 28 m. It is
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
| Predators | Bears in rivers strike on every other beat: jump them or steer wide. Sharks at sea keep no beat: each swims to and fro across your way, one at the surface and one under it, and touching it at its own depth is a wipeout, so go round, over or under. |
| Waterfalls | Going up: a wall 2.6 to 4 m high to leap, or be washed back 40 m. Going down: a drop of 9 to 20 m to launch off. |
| Currents, boost rings, sea nettles | Under the sea stages only: see "The layers under the water". |

There is a gate over the finish and none at the start.

**The stages at a glance**

The sea is wide and the rivers are narrow: the sea stages are 70 to 140 m of open water
(the Coastline and the Coral Reef with land along one side only), and the rivers after them
are 16 to 21 m between their banks.

| Stage | Look | Water | Predator | Notable |
|---|---|---|---|---|
| Open Ocean | broad daylight, deep blue water, buoys, ships far off | flat, open | shark (rare) | the gentle start: 140 m of open water, long empty stretches, no rock fields, no bottom in sight, no ramps; six layers to dive |
| Shallow Sea | cold open water off Alaska, the sea floor in sight, the fishing fleet about | flat | shark | 90 m wide; strings of crab-pot floats (dive under them); two layers to dive |
| Ocean Trench | near-black water, glowing jellyfish, seamounts | flat, open, 110 m wide, six layers deep and swum all under the water | none | the abyss: come into down a giant current from the Open Ocean, left by a current back to the surface; currents, boost rings and sea nettles |
| Coastline | the coast of Oregon under a grey sky: 70 m of sea with a rocky shore along the left only (dark sand, black rock, sea stacks, drift logs, spruce on the bluffs) and open water on the right | barely climbs | shark | |
| The Harbor | quays, cranes, sodium light | barely climbs | shark | |
| Coral Reef | pink dawn over clear water, 70 m wide, a beach along one side only, dense coral | flat, open | shark | |
| Arctic Waters | pack ice and icebergs under an aurora, 100 m wide | flat, open | shark | |
| Meandering River | farmland, barns, windmills; very winding | gentle climb | none | harvest gold in autumn, green in spring |
| Dry Riverbed | red-rock canyon, cacti, mesas | climbs | none | a few waterfalls; blooms in spring |
| The Fish Ladder | concrete channel through forest | climbs | none | a waterfall every 170 m |
| The Fish Farm | net pens on a grey lake | flat, open | none | short; feed barrels are the only obstacles |
| Neon Harbor | The Harbor under pink city light | barely climbs | shark | |
| Rainforest Falls | temperate rainforest: big conifers, ferns, mist | climbs | bear | the training course borrows its look |
| Mountain River | granite gorge; gold larches in autumn, snow in spring | steepest | bear | most waterfalls and rocks |
| Bamboo River | Japanese mountain stream: bamboo, torii, lanterns | climbs | bear | red maples in autumn, cherry blossom in spring |
| The Hatchery | The Fish Farm with bamboo ashore | flat, open | none | |
| Alpine Lake | wide calm lake ringed by peaks | flat, open | none | ramps, rails and rings only |
| The Crater Lake | Alpine Lake with maples and torii | flat, open | none | |

Seasons are part of each entry: the base settings are autumn (the way up), and a `spring`
block replaces whatever changes on the way down.

**A pack of six salmon** swims every course right round you, matching your life stage: each
steers as a flock does (boids: keep clear of your neighbours, swim the way they swim, make for the middle of them) and follows you besides; they leap when you leap and
dive when you dive, and each leaves a small V of foam behind it and a little splash where it leaves the water and lands. **In the flow** (from x2, fully at x3) the pack draws in close and falls
in step: as high out of the water as you are, and turning every spin, flip and corkscrew you
turn (`School.in_step`). **Other salmon** swim further off about their own business, and
there are more of them the higher the stage's score (3 at the start, up to 16 by 120,000).
All of them avoid rocks, ride ramps and leap falls. They are company only.

**On the salt water** there is more: swarms of sardines under the surface, each a ball
turning on itself; a wall of sardines that gathers at the edge of the course as you near it,
in place of a line of buoys (`edge_swarm.gd`); and a chance on every stage of a leatherback
turtle, a humpback whale off to one side (it rolls up to breathe and now and then throws
itself out of the water) and Pacific bluefin tuna that come by from behind
(`sea_visitors.gd`). Which of those a stage has is rolled when it is begun; more of each
turn up as the score climbs, and a kind the stage did not have turns up anyway once the
score is high enough. They are scenery: nothing touches them.

## 5. Controls

**Touch (and mouse, which counts as a finger)**

| Gesture | On the water | In the air |
|---|---|---|
| Drag | a stick under the thumb: drag to one side of where your finger came down and the salmon steers that way, harder the further you drag, for as long as you hold it there (until it meets the bank). Where on the screen you touch makes no difference | |
| Swipe up | full jump (also hops off a rail); dived, comes back up to the surface | backflip |
| Swipe down | dive one layer deeper | frontflip |
| Hard flick left / right | dash 3 m that way, turning a corkscrew as it goes (it takes a fast, flat flick well past the reach of the stick, so that turning does not set it off) | spin with a corkscrew |
| Swipe left / right / down / diagonal | | one full 360 that way: spin, frontflip, or both |
| Wiggle back and forth | boost | |
| Circles | boost | corkscrew, the way the finger goes round |

Touch has no grabs yet.

**Keyboard / gamepad** keep the fuller set: steer, swim harder or brake, hold-and-release
jump (charge), boost, corkscrew, four grabs. See the README for the bindings.

### The layers under the water

The salmon swims on the surface or **dived** under it. Swiping down goes down a layer;
swiping up comes up one (and from the surface, jumps). Once under, it can also be swum up
and down freely, to anywhere between the layers and back to the surface: up and down on the
keys or the stick, or a slow drag up or down with the finger held (a quick stroke is still a
swipe). Steering and speed are the same at
every depth. A river has one layer under the surface (1.7 m down). The **Open Ocean** has
six and the Ocean Trench three, 3.6 m apart; the Shallow Sea has two, 2.6 m apart.

- Dived, you pass under rails, under anything that only floats (containers, ice, feed
  barrels) and under a bear. Rocks that stand on the bed still block the way, and a shark
  comes from below.
- A ramp is solid all the way down: coming up to one brings you back to the surface.
- **Under water the camera goes under too**, and the picture changes: it sways, takes the
  colour of the water, shafts of light slant down from the surface, the distance goes murky
  and the music is muffled. Bubbles come up from the deep and specks hang in the water.

What is under the sea stages with layers (Open Ocean, Shallow Sea, Ocean Trench) is laid out
on its own along a trail of its own, whatever is on the surface above it
(`deep` in `levels.gd`):

- **Ocean currents** are rails under the water that wind about, from side to side and between
  down and up through every layer there is. Swim into one (each starts a layer or two down, under a row of arrows on the
  surface) and it carries you off at boost speed, filling the boost bar and scoring by how
  long you stay on. An up or down swipe leaves it early; otherwise it lets you go at whatever
  depth it ends. They come in all widths (3 to 4.5 m across the radius, and about one in three a great wide one of 5.5 to 7.5 m, drawn in where it comes near the surface). Each is a tunnel with no wall to it: a few strokes of wind, well spread out, winding round it in a spiral (each a thin tail fattening to a curled head), and grainy see-through rings travelling down it; its two ends are open, and everything in it thins away over the last 26 m at either end instead of stopping dead; and bubbles (little rings that face the eye: `current_bubbles.gd`) are swept along inside it. It is under the water like
  everything else there (so the surface tints it from above), and the murk does not hide it.
- **Launch currents** end by rising to the surface and throw you into the air, through three
  rings. About one current in three is a launch. The Open Ocean has no jump ramps: this is its way up, and its rails are ones you
  swim straight onto.
- **Ring trails** run under the sea as well: a few rings on one layer, then a few on the next
  one down or up.
- **Boost rings** (pale blue) are strung in a curve down through the layers and back. Each is
  a ring and a surge of speed.
- **Sea nettles** drift at every depth: amber jellyfish with long tentacles. Touching the
  bell or what trails under it stings (a stumble and lost speed, like a rock).
- **Shoals of small fish** swim under the water on every stage, each at a depth of its own,
  some with you and some the other way. They are scenery: nothing happens on touching them.

## 6. Scoring

- **Tricks** bank when you land: flips, spins (per 180), corkscrews, grabs, air time, Big
  Air, rail grinds. Three or more parts in one jump earn a 25% bonus.
- **Landing** must be roughly upright with no grab held, or it is a wipeout.
- **Flow** is the multiplier: +1 for each clean trick up to x5. It resets on a wipeout or a
  bump, or after 4 seconds on the water without a trick.
- **Timing:** every swipe is graded on how close to a beat it was made, and the salmon says so there and then, in a speech bubble beside it in the world (`fx/speech.gd`)
  and then (the jump itself is one; on keys and pads, so is the start of each held spin). A
  trick is worth the grade of its swipes taken together, not when it lands. The grades: MISS,
  SLOPPY, O.K. (x1.1), ALRIGHT (x1.15), NICE (x1.25), GOOD (x1.35), GREAT (x1.5), EXCELLENT
  (x1.75) and PERFECT! (x2). The windows are shares of the gap between beats, so they keep
  pace with the tune: at 174 BPM, PERFECT! is within about 25 ms and NICE within about 110.
  The callouts run from a dim blue-purple up through blue and green to gold for EXCELLENT,
  and PERFECT! is polished platinum with a gleam running across it. NICE or better counts
  as "on the beat" for the goals that ask for it.
- **Rings** are 250 points and some boost each. Tricks also refill boost.
- **Ranks** D to S at 35K / 70K / 110K / 160K, scaled so shorter stages are judged fairly.
- **Wipeout:** about one second out of control, then a moment of invulnerability.

## 6b. Water, wake and splashes

- **Water** is flat and painted, after an older water shader of the author's: matte colour
  with hardly any shine, clear close to and solid blue far off, faint pale lines wandering
  over it (`water_lines`) and drifts of flat, ragged white foam with clear water between
  them (`water_whitecaps`, more on the open sea). Under that:
  its colour runs from shallow to deep with how much water is really
  under each pixel, a rim of foam forms wherever something breaks the surface (banks, rocks,
  ramps, the fish), and patches of foam drift with the current. Every stage can set any of
  its controls (`water_*` in `levels.gd`: foam amount, depth range, rim width and so on).
- **Foam** is cut from a grey picture that wraps (`textures/foam_noise.png`, made by
  `scripts/tools/bake_foam.gd`; any picture that wraps can be set in its place on
  `materials/water.tres`). The noise in the water shader takes its random numbers from whole
  numbers, not the usual `fract(sin())`, which the desktop renderer gets wrong at the corners
  of each square (every square then shows as a block).
- **The swell is real.** The water's mesh is a few metres to a square and the shader lifts it
  into waves: four trains of different lengths crossing one another, the long ones travelling
  faster, as real waves do. A stage's `swell` says how rough its water is (higher and longer
  waves on the open sea than on a river); `water_swell_height`, `water_swell_length` and
  `water_swell_speed` shape it. The light falls on the slope worked out at every pixel, so
  the surface is smooth however coarse the mesh. Foam can ride the crests
  (`water_crest_amount`), and the water is paler looked down into than looked across
  (`water_view_clear`). `Track.swell_y()` works out the same waves, and the salmon, the
  other salmon, the wake and the splashes ride them. Nothing flashes on the beat: the water
  and the light are steady.
- **Open sea** stages have a floor of rolling hills below (`floor`) instead of a river bed:
  in sight in the Shallow Sea and the Coral Reef, and not drawn at all under the Open Ocean.
  From underneath, the surface is a bright ceiling that hides the sky.
- **The wake** is part of the water, drawn by the water shader from the salmon's trail: two
  bands of foam off the shoulders, opening
  out behind into a short V (it is a fish, not a boat) and fading, with the foam cleared
  between them, small white dots of spray tossed up off the shoulders (they stay round the
  fish, and are not left strung out behind),
  and a string of bubbles when dived.
- **Landing** throws up a splash that stays where the salmon went in, in the colours of the
  stage's own water (its shallow colour and its foam): three tubes of water
  one inside the other, like the tiers of a cake (the outer wide and low, the inner narrow
  and tall), with ragged crests and water streaming down them. They shoot up and drop back,
  with ripples across the surface, splattery drops and a spray of small dots. Its size follows how hard the landing
  was. (A few splashes are built once and used in turn: building one for each leap and
  landing made the game stumble at those moments.)
- **The salmon you play changes with its life.** On the way up it is the silver ocean adult
  at sea, the migrating adult (silver turning red) in the lower rivers, and the red and
  green spawner with its humped back and hooked jaw from the upper rivers on. On the way
  back down it is a fry in the lake, a barred parr in the rivers and a silver smolt by the
  sea. (The young are drawn bigger than life, or they would be lost on the screen.)
- **Every river meanders**: bends to the left and to the right, one after the other, on top
  of whatever else the stage does (`meander` in `levels.gd`).
- **Open water runs straight** (the sea stages), so the salmon is never turned without
  being steered. There it is the trail that wanders: the rings, rails, currents and
  everything else are strung along a path that swings from side to side across the water,
  up to about 24 m either way, and you steer to follow it.
- **The camera turns** to look the way the salmon is steering, up to about 30 degrees.
- **The salmon** animates on key poses: stretched long at take-off, squashed on landing,
  tucked as a trick starts. A swipe trick winds up the wrong way, whips round and runs a
  little past the mark before settling, and the body and tail follow on springs.

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
- **The card** is a page from a school encyclopedia: cream paper with a gold rule inside the
  border. A running head gives the stage, the season and the coordinates; under it are a
  mounted picture of the stage in hand, its name with an arrow either side to step between
  the ways on, a "Did you know?" fact about the salmon at that point of its life (the adult
  on the way up, the young on the way down), and two buttons (BACK and START or SWIM). It
  sits across the bottom of the screen, over the lower part of the Earth, on a phone and a
  desktop alike, with the top of the Earth always on the screen. The arrangement follows
  `conceptArt/ui/levelSelect.png`.
- **Between stages** the same globe draws the red line across to the next one.

## 9. Other modes and tools

- **Water lab:** on the title menu of the desktop game only (the web build has no button for it). The salmon swims a stage by itself beside a panel, the height of the window, of
  sliders and colour pickers for the water shader, which change the water as you watch. Each
  slider has a box with its number, and any number can be typed there, whatever the ends of
  the slider; a setting changed by hand is marked in red with a star, and a right click on
  its name puts it back. They are grouped as in the shader: colour; foam (the patches that
  drift down a river, its banks, rapids and rims); whitecaps (foam lying on open water: how
  much, how big, how gathered into drifts); crest foam (on the tops of the swell: how much,
  how big, how ragged); the swell; the surface (the ripples, and `glint_pixels`, which makes
  the light come off the water in squares of that many pixels); and the wake (how long, how
  wide, a wiggle, gaps, froth down the middle, a second pair of arms).
  What is set is **the stage's own preset**, used on that stage and no other. SAVE, BACK and
  the stage arrows write every stage's preset into `materials/water_presets.cfg`, which goes
  out with the game (web build included); RESET clears this stage's; COPY and PASTE carry
  one stage's to another. So the water of a stage is, in order: `materials/water.tres`, then
  the stage's `water_...` keys in `levels.gd`, then its preset.
  With a mouse and keys the view can be turned (drag), moved in and out (wheel, or Q and E)
  and moved over the water (W A S D), down to under the surface looking up; R puts it back.
  H hides the panel, F chooses whether the camera stands over one stretch of water or goes
  with the salmon (STILL / FOLLOW), and [ and ] change stage.
- **Field guide:** on the title menu. A page of the same encyclopedia with a model on it that
  turns slowly (drag to turn it yourself), its name and scientific name, how big it really
  is and a fact. The arrows step through the sockeye at each of six stages of its life (fry,
  parr, smolt, ocean adult, migrating adult, spawner) and then the sea nettle, a deep-sea
  jellyfish, the salmon shark and the brown bear.
- **Practice:** the same globe and card as a run, with no trail. Step through every stage with
  the arrows, choose the way up or down, and swim it with no countdown, goal or finish; it
  loops and nothing is saved. Its first entry is the **training course**: a short straight
  river with one of everything.
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
| The other salmon, and shoals of small fish | `scripts/world/school.gd`, `scripts/world/shoals.gd` |
| Predators | `scripts/world/bear.gd` |
| Camera | `scripts/world/chase_camera.gd` |
| Splash and wake | `scripts/fx/splash.gd`, `scripts/fx/wake.gd` (the wake is drawn in `shaders/water.gdshader`) |
| Water, underwater view, currents | `shaders/water.gdshader`, `shaders/post.gdshader`, `shaders/current.gdshader` |
| The water every stage starts from, and a scene for setting it up in the editor | `materials/water.tres`, `scenes/water_scene.tscn` (`scripts/tools/water_scene.gd`) |
| Scoring and timing grades | `scripts/game/score.gd` |
| Water lab, field guide | `scripts/ui/water_lab.gd`, `scripts/ui/model_viewer.gd` |
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
- **The young play exactly like the adult**, only smaller.
- **Nothing is designed for the dash yet**, and a fast first stroke of a turn or a boost
  wiggle can still set one off.
- **The download is about 19 MB** (10 MB of it the engine, 7 MB music). Each push to `main`
  rebuilds the public site, and GitHub fails builds that come too close together.
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
