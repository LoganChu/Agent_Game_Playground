# Emberwake — Technical Notes

## Toolchain (pinned)
| Tool | Version | Installed by | Notes |
|---|---|---|---|
| Godot | **4.7.2-stable** (standard build, GDScript only) | `tools/setup.sh godot` | Official godot-builds release; falls back to extracting the same binary from Docker Hub `barichello/godot-ci:4.7.2` (`tools/fetch_godot_from_docker.py`) if GitHub downloads are blocked. |
| Blender | **5.2.2** as the `bpy` Python module | `tools/setup.sh blender` | PyPI wheel, needs `python3.13`. Invoked as `.tools/bin/blender-py <script>`. Scripts also run under a full Blender: `blender --background --python <script>`. |

Everything installs into `./.tools/` (git-ignored). Bump versions in `tools/setup.sh` **and** here.

## Commands
```bash
tools/setup.sh                    # install Godot + Blender(bpy) into .tools/
tools/run_checks.sh               # import + tests + smoke playthrough + launch (pre-push gate)

GODOT=.tools/bin/godot
$GODOT --headless --path . --import                         # parse scripts, import assets
$GODOT --headless --path . -s res://tests/run_tests.gd      # unit + content tests
$GODOT --headless --path . -- --smoke-test                  # automated playthrough
$GODOT --path .                                             # play
$GODOT --path . -- --region=saltmarrow                      # start in a region (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --screenshot=/abs/out.png
.tools/bin/blender-py tools/blender/build_props.py          # rebuild .glb props (pine, rocks, stilt house, beacon, net-loft)
```
`run_checks.sh` fails on any non-zero exit **or** any `SCRIPT ERROR` / `ERROR:` / `Parse Error`
in Godot's output (runtime script errors don't change Godot's exit code, so we grep).

## Architecture
```
scripts/
  core/        pure logic, no scene dependencies (unit-testable)
    content_database.gd   ContentDatabase — loads data/ + story/ JSON into dicts by id
    content_validator.gd  ContentValidator — cross-reference + orphan checks
    world_state.gd        WorldState — flags, quests, inventory, collected pickups; to/from dict
    conditions.gd         Conditions — tiny condition language (see below)
    dialogue_runner.gd    DialogueRunner — steps JSON dialogue, applies effects
    input_setup.gd        default input actions registered in code
    journal_model.gd      JournalModel — ordered view data for the quest journal + satchel
    json_util.gd, layers.gd
  autoload/    singletons (registered in project.godot)
    content.gd      "Content"    – the loaded ContentDatabase (validates in debug builds)
    game_state.gd   "GameState"  – current WorldState, region, signals (toast, dialogue_requested…)
    save_system.gd  "SaveSystem" – JSON saves in user://saves/<slot>.json (F5 / F9)
  world/       region.gd (builds a region from data), npc_actor.gd, pickup.gd,
               region_exit.gd (optionally gated), inspectable.gd (examine → dialogue),
               interactable.gd, prop_factory.gd (procedural low-poly props)
               Node groups: npcs, pickups, inspectables, exits (used by the smoke test)
  player/      player.gd — third-person controller, orbit camera, interaction sensor
  ui/          dialogue_ui.gd, hud.gd, journal_ui.gd (J/I two-tab panel) — built in code,
               palette-themed. Modal UIs set `GameState.input_locked` while open and refuse
               to open if another modal already holds it.
  debug/       smoke_test.gd, screenshot.gd
  main.gd      root scene script (scenes/main.tscn)
data/          game.json, flags.json, regions/, npcs/, items/, quests/  (one JSON per record)
story/         dialogue JSON, one file per conversation
assets/models/ Blender-exported .glb (+ Godot .import files — commit both)
tools/         setup.sh, run_checks.sh, blender/ scripts
tests/         run_tests.gd (runner), test_case.gd (base), test_*.gd
```
Scenes are mostly built in code from data so content never requires editing `.tscn` files.

**Physics layers:** 1 world, 2 player, 3 interactable.

## Content formats
Every record lives in its own file whose name equals its `id`.

### Region (`data/regions/<id>.json`)
```jsonc
{ "id", "name", "description",
  "water_level": -0.25,                         // optional water plane height
  "fog": {"density": 0.014, "color": "silverfog"},
  "spawn_points": {"default": [x,y,z], ...},    // "default" required
  "terrain": [{"size": [w,h,d], "position": [x,top_y,z], "color": "moss", "rotation_y": 0}],
  "props":   [{"model": "res://assets/models/x.glb", "collider": [w,h,d],   // or
               "shape": "pine|rock|house|post|crate|beacon|dock", "color": "...",
               "position": [...], "rotation_y": deg, "scale": 1.0}],
  "npcs":    [{"npc": id, "position": [...], "rotation_y": deg, "if": condition}],
  "pickups": [{"id": unique, "item": id, "position": [...], "count": 1, "if": condition,
               "set": {flag: value}, "quest_stage": [quest, stage]}],
  "objects": [{"id": unique, "prompt": "Examine ...", "dialogue": id, "position": [...],
               "reach": 1.8, "if": condition}],        // inspectables: start a dialogue
  "exits":   [{"to": region, "spawn": spawn_name, "position": [...], "prompt": "...",
               "requires": condition, "locked_text": "..."}] }   // gated exits
```
Objects have no visuals of their own (place a prop at the same spot); their dialogue runs
with no NPC. A gated exit is always shown; while `requires` is false, interacting toasts
`locked_text` (required with `requires`) instead of travelling.
The player cannot climb steps: keep walkable slab tops within ~0.05 of each other (no ramps
exist yet — slabs only rotate on Y).
Terrain slabs are positioned by their **top surface**. A prop with both `model` and `shape`
uses the model and falls back to the shape only if the model can't load.
Colors are palette names from `PropFactory.PALETTE` (= GAME_DESIGN palette) or `#hex`.

### NPC / Item / Quest
- NPC: `id, name, color, dialogue, faction?, bio?` — must be placed in exactly one region.
- Item: `id, name, description, kind (remnant|key|misc), color?, future?`
- Quest: `id, title, description, stages: [{id, text}], giver?, region?` — first stage is
  entered on `quest_start`.

### Flags (`data/flags.json`)
Every flag must be declared with a `description` (and optional `default`). The validator
errors on undeclared flags and on declared flags nothing sets; it warns on flags nothing reads
unless marked `"future": true` (payoff not written yet) or `"read_by_code": true`.

### Conditions
String or array of strings (AND). Prefix `!` negates.
`flag:<id>` (truthy) · `flag:<id>=<value>` (string compare; `flag:x=` means empty) ·
`quest:<id>=inactive|active|done` · `stage:<quest>=<stage>` · `item:<id>` · `item:<id>>=<n>`

### Dialogue format (`story/<id>.json`) — decision record
**Decision (Day 1):** we use our own JSON dialogue format instead of Ink. `godot-ink` needs
the .NET/C# build of Godot, and compiling `.ink` needs `inklecate` (.NET) — neither fits our
GDScript-only, headless-CI toolchain, and GitHub-hosted addons may be unreachable from the
build sandbox. The JSON format keeps Ink's core ideas (knots, gotos, conditional choices,
state effects) and is validated by our own tests. Revisit if a pure-GDScript Ink runtime
with a pure-GDScript compiler becomes practical.

```jsonc
{ "id": "mara",
  "knots": {                              // "start" required; every knot must be reachable
    "start": [ {step}, {step}, ... ] } }
```
A step does at most one *action* — `say` (+`text`), `choice`, `goto`, `end` — plus any number
of *effects*, and may be gated by `if` (skipped when false):
- `{"say": "<npc id>|player|narrator", "text": "..."}`
- `{"choice": [{"text": "...", "if": cond, "goto": knot | "end": true, <effects>}]}` —
  hidden options are filtered; if none are visible the step is skipped.
- `{"goto": "knot"}`, `{"end": true}` — reaching the end of a knot also ends the dialogue.
- Effects: `"set": {flag: value}`, `"quest_start": id`, `"quest_stage": [id, stage]`,
  `"quest_complete": id`, `"give_item": id`, `"take_item": id` (+ `"count": n`).
- `"note"` is ignored (writer comments).

## Save format
`user://saves/<slot>.json`: `{version, saved_at, region, spawn, player_position, world:
WorldState.to_dict()}`. Bump `SaveSystem.SAVE_VERSION` on breaking changes and add migration.

## Testing
- `tests/test_content.gd` — content loads, all references valid, every dialogue terminates,
  validator catches deliberately broken links.
- `tests/test_dialogue.gd`, `tests/test_world_state.gd`, `tests/test_journal_model.gd` — unit
  tests on fixtures.
- Smoke test — boots the real main scene, plays intro, checks every gated exit refuses
  travel on a new game, visits every region twice, talks to every NPC and examines every
  object walking each menu, collects pickups, checks gated exits now open and the Gull's
  Beacon quest stage was reached, opens the journal and satchel via real input
  actions, saves/loads and compares state.
- Add a `test_*.gd` extending `TestCase`; methods named `test_*` run automatically.

## Rendering notes
Project targets Forward+ (Vulkan). In the sandbox only the OpenGL Compatibility renderer
(`--rendering-driver opengl3` under Xvfb/llvmpipe) is available for screenshots, and it
renders noticeably brighter/washed-out; do color grading on a real GPU.
