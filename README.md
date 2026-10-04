# Salmon Run 2 — Jungle Falls

Low-poly retro trick racer: you're a sockeye salmon running a jungle river to a procedural
jungle / drum & bass soundtrack (174 BPM). SSX-style tricks, waterfalls, bamboo rails, bears.

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

## Scoring

- Tricks bank on landing: flips, spins, corkscrews, grabs, airtime, Big Air, Bamboo Grind.
- **Flow** multiplier: +1 per clean trick (max x5); resets on wipeout or 4 s on the water without a trick.
- **On the beat**: landing within ~95 ms of a beat is x1.5, within ~45 ms is x2 (PERFECT).
- Rings: +250 and boost. Ranks D → S at 35k / 70k / 110k / 160k.

## Music

Options → TRACK picks the race tune: Jungle Falls, Deep Current (mellow, liquid) or Night Rapids
(darker, heavier). All three are 174 BPM with the same arrangement, so on-beat landings work the
same on each. They are the `STYLES` in `scripts/audio/dnb_synth.gd`, listed in `Songs.TRACKS`.

## Project layout

| Path | What |
|---|---|
| `scripts/main.gd` | game flow (title → countdown → race → results), menus, low-res render target, autotest |
| `scripts/autoload/music.gd` | plays the baked soundtrack; beat clock + `beat_pulse` shader global |
| `scripts/autoload/sfx.gd` | plays the baked sound effects |
| `scripts/audio/` | the procedural DnB + SFX synthesizers and the song arrangements |
| `scripts/tools/bake_audio.gd` | renders the synths into `audio/*.wav` |
| `scripts/world/track.gd` | river generation: centre-line, waterfalls, ramps, rails, rocks, rings, bears, jungle scatter |
| `scripts/world/props.gd` | procedural low-poly meshes (salmon, trees, bear, speakers, ruins…) |
| `scripts/player/salmon.gd` | movement in track space (s, x, y), tricks, grinds, wipeouts, autopilot |
| `shaders/` | PS1 vertex snap, water, fish wag, sunset sky, dither post-process |

Meshes are generated at startup. Music and SFX are synthesized in GDScript too, but offline:
per-sample GDScript is far too slow to run live on the web, so after changing anything in
`scripts/audio/` re-bake them:

```
godot --headless --path . -s scripts/tools/bake_audio.gd
godot --headless --path . --import
```

Tweak the course with `Track.length` / `track.build(seed)` in `world.gd`.
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
Plays a full race on autopilot (add `--practice` for a minute on the practice level), saves screenshots to that folder, prints the result and quits
(autotest runs never touch your high score).
