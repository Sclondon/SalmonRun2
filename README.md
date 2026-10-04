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
**PRACTICE** on the title screen is a short, straight river with one of everything (ring slalom,
jump rings, ramps, rails, rocks, a waterfall) that loops forever, for trying the controls.

## Levels

The journey home, in order (all six are open from the start for now; SWIM! lists them):

| # | Level | What it is |
|---|---|---|
| 1 | Deep Ocean | open water at night: ice, buoys marking the current, sharks |
| 2 | Shallow Sea | bright reef between sandbars, coral heads, sharks |
| 3 | The Coast | the river mouth at golden hour: beaches, palms, driftwood; the water starts to climb |
| 4 | Jungle Falls | upstream through the jungle: waterfalls to leap up, bamboo rails, bears |
| 5 | Alpine Run | upstream again: narrow, steep and rocky, more waterfalls, bears |
| 6 | The Home Lake | calm, wide, no hazards: ramps, rails and rings to the spawning grounds |

Each level is one entry in `scripts/world/levels.gd` (course shape, what it is made of, bank
profile, scenery rules, colours, sky and light), so tuning or adding one is editing that table.
Best scores are kept per level, and ranks are scaled to a full-length course.

From the coast on you swim **upstream**: the river climbs, and a waterfall is a wall of water
2.6 to 4 m high. Jump (a swipe, or a fully charged Space) roughly 10 to 25 m before it to clear
the top; come up short and you are WASHED BACK 40 m for another run at it.

## Scoring

- Tricks bank on landing: flips, spins, corkscrews, grabs, airtime, Big Air, Bamboo Grind.
- **Flow** multiplier: +1 per clean trick (max x5); resets on wipeout or 4 s on the water without a trick.
- **On the beat**: landing within ~95 ms of a beat is x1.5, within ~45 ms is x2 (PERFECT).
- Rings: +250 and boost. Ranks D → S at 35k / 70k / 110k / 160k.

## Music

Every level has its own tune, each at its own tempo: Abyssal (150 BPM), Reef Break (160), River
Mouth (166), Jungle Falls (174), White Water (186) and Homecoming (178). The beat clock follows
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
| `scripts/world/levels.gd` | the six levels: everything that makes one look and play differently |
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
Plays a full race on autopilot (add `--level=N` to pick the level, or `--practice` for a minute on the practice level), saves screenshots to that folder, prints the result and quits
(autotest runs never touch your high score).
