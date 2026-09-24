# Emberwake — Dev Log

Newest entries first. Each entry: what was done, decisions & why, problems, next steps.

## 2026-09-24 — Day 1: Foundation

**Did**
- Wrote the vision: `GAME_DESIGN.md` (Emberwake — a Wakebearer carrying a living ember
  through the memory-eating fog of the Lanternreach; pillars, loop, palette), `LORE.md`
  (world, factions, Saltmarrow cast, Act I–III outline, five long-term mysteries with
  secret answers), `ROADMAP.md`, `TECH.md`.
- Toolchain: `tools/setup.sh` installs Godot 4.7.2 (official build) and Blender 5.2.2 as the
  `bpy` PyPI module into `.tools/`. Download sources were partly blocked in the sandbox
  (godotengine.org, download.blender.org); GitHub release downloads worked; a Docker Hub
  fallback for Godot is scripted in case they don't next time.
- Godot project: autoloads `Content`, `GameState`, `SaveSystem`; pure-logic core
  (`ContentDatabase`, `WorldState`, `Conditions`, `DialogueRunner`, `ContentValidator`);
  third-person player with orbit camera and interaction sensor; data-built regions
  (terrain slabs, water, props, NPCs, pickups, exits); dialogue box and HUD; F5/F9
  quicksave/quickload.
- Content: Shingle Point (start) and Saltmarrow; Pell, Mara Tollen, Brother Aldous with
  branching dialogue; quests *Lost Things* (complete, with a give/keep choice on the humming
  pebble Remnant) and *A Light for Saltmarrow* (first two stages); 7 story flags.
- Blender: `tools/blender/build_props.py` → pine tree, rock cluster, stilt house, Gull's
  Beacon (.glb, 8–17 KB each). Every prop also has a procedural fallback shape.
- Tests: custom headless runner (11 tests) incl. content-link validation, orphan detection,
  dialogue termination on all paths, and a validator self-test with deliberately broken
  links; plus a smoke test that plays the real main scene (intro → every region twice →
  every NPC → pickups → save/load round-trip). `tools/run_checks.sh` runs everything and
  fails on any Godot `SCRIPT ERROR`/`ERROR:` output. CI workflow added (untested yet).

**Decisions**
- **Custom JSON dialogue instead of Ink.** godot-ink needs Godot .NET; compiling .ink needs
  inklecate (.NET). Our format mirrors Ink's knots/choices/conditions and is fully validated.
  Recorded in TECH.md.
- **Custom test runner instead of GUT.** No addon download needed, ~40 lines, sufficient now.
- **Scenes built in code from data** so content never needs `.tscn` edits and diffs stay
  readable.
- **Flags must be declared** in `data/flags.json`; the validator errors on undeclared or
  never-set flags, and warns on never-read ones unless marked `future`. This is how we keep
  "choices matter later" honest.

**Problems / notes**
- Screenshots are only possible with the OpenGL Compatibility renderer under Xvfb; it looks
  washed out/over-bright. Lighting was toned down but a real-GPU color pass is on the roadmap.
- Expected validator warnings: `a_light_for_saltmarrow` never completes yet.

**Next run should**
1. Check the first CI run of `.github/workflows/checks.yml`; fix if red.
2. Build the Quest journal (J) and Inventory (I) panels (ROADMAP #1–2).
3. Then content: net-lofts + headland path gated by the Harbormaster's Token (ROADMAP #3).
