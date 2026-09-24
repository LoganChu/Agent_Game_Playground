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
F9 quickload.

## Tests
```bash
tools/run_checks.sh    # import + unit/content tests + smoke playthrough + launch
```
All content (regions, NPCs, items, quests, flags, dialogue) is JSON under `data/` and
`story/`, and every cross-reference is validated by the tests.

## License
Original work, all rights reserved (commercial project). Third-party notices:
[`docs/THIRD_PARTY.md`](docs/THIRD_PARTY.md).
