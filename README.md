# Emberwake

A stylized low-poly 3D narrative exploration RPG built in **Godot 4 (GDScript)**. You are a
Wakebearer, carrying a living ember through the Greying — a sea-fog that makes the world
forget. Explore, listen, choose what is worth remembering.

- Vision: [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) · World bible: [`docs/LORE.md`](docs/LORE.md)
- Plan: [`docs/ROADMAP.md`](docs/ROADMAP.md) · Log: [`docs/DEVLOG.md`](docs/DEVLOG.md)
- Architecture, content formats, commands: [`docs/TECH.md`](docs/TECH.md)

## Quick start (Linux)
```bash
tools/setup.sh                       # installs Godot 4.7.2 (+ Blender bpy) into .tools/
.tools/bin/godot --path . --import   # first-time asset import
.tools/bin/godot --path .            # play
```
On Windows/macOS, install Godot 4.7.2 yourself and open `project.godot`.

**Controls:** WASD / left stick to move · right-mouse drag, Q/R or right stick to turn the
camera · E / Enter / A to talk, pick up and continue · 1–9 or click to choose · F5 quicksave ·
J / View button journal · I / Y satchel (inventory) · Esc / B close panel · Esc / P / Start pause menu (save slots, load, settings, quit) · F9 quickload.
Keys can be rebound, and volumes, text size and camera sensitivity/invert set, under
**Esc → Settings** (saved to `user://settings.cfg`, separate from save games).

## See the progress without playing it all
The story is split into **checkpoints** (`data/scenarios.json`), from waking on the beach to the
latest content. Three ways in:

- **Just look:** [`docs/CHECKPOINTS.md`](docs/CHECKPOINTS.md) is a one-page gallery with a
  screenshot and a short "what's here" note for every checkpoint. Rebuild it with
  `tools/checkpoints.sh` (needs `xvfb-run`).
- **Play from a checkpoint:** `.tools/bin/godot --path . -- --scenario=thornwold` starts right
  there, with the earlier choices already made. `--scenario=list` prints every id.
- **Jump around while playing:** in a debug build (the editor, or running from source), press
  Esc → **Chapter select (dev)**. It isn't shown in release exports.

Each content session adds a checkpoint for what it built, so the newest content is always one
jump away.

## Tests
```bash
tools/run_checks.sh    # import + unit/content tests + smoke playthrough + launch
```
All content (regions, NPCs, items, quests, flags, dialogue) is JSON under `data/` and
`story/`, and every cross-reference is validated by the tests.

## License
Original work, all rights reserved (commercial project). Third-party notices:
[`docs/THIRD_PARTY.md`](docs/THIRD_PARTY.md).
