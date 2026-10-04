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
$GODOT --path . -- --flags=intro_seen,saltmarrow_beacon_burned=knot \
    --quest=a_light_for_saltmarrow,across_the_grey:await_the_ferry  # late-game state (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --region=saltmarrow \
    --flags=intro_seen,saltmarrow_beacon_burned=gull,saltmarrow_ferry_passage \
    --act-end=act1 --screenshot=/abs/out.png               # show an act's end card (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --region=saltmarrow --flags=intro_seen \
    --pause-menu[=save|load|chapters|settings|controls] --screenshot=/abs/out.png     # pause menu (on a page) (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --screenshot=/abs/out.png
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --region=saltmarrow \
    --camera=0,26,34:0,0,0 --screenshot=/abs/out.png       # fixed overview camera (eye:target)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --region=gulls_head --flags=intro_seen \
    --at=0,-9,0 --settle=60 --screenshot=/abs/out.png      # player at x,z (camera yaw), wait N frames
$GODOT --headless --path . -s res://tools/debug/terrain_map.gd [-- <region>]  # ASCII walkability map
.tools/bin/blender-py tools/blender/build_props.py          # rebuild .glb props (pine, rocks, beacon, net-loft)
.tools/bin/blender-py tools/blender/build_characters.py [oda hob …]  # rebuild characters (assets/models/characters/)
.tools/bin/blender-py tools/blender/build_dressing.py [dock wreck …]  # rebuild the dressing kit (assets/models/dressing/)
.tools/bin/blender-py tools/blender/build_village.py [house_stilt house_wren net_loft_broken …]  # village buildings (same kit dir)
.tools/bin/blender-py tools/blender/build_thornwold.py [bramble bunkhouse tally_house saw_pit charcoal_clamp pine_dark …]  # Thornwold kit (same kit dir)
.tools/bin/blender-py tools/blender/build_woods.py [collier_hut (+ collier_hut_cold) sack_cart waymark trail_stake greyed_brush pine_grey]  # Thornwold woods kit (same kit dir)
.tools/bin/blender-py tools/blender/build_ridge.py [thornwold_beacon (+ _lit) keeper_lodge]  # the ridge: Thornwold's beacon + keeper's lodge (same kit dir)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . res://scenes/debug/character_lineup.tscn \
    -- --screenshot=/abs/out.png [--closeup] [--mood=gulls_head]  # art review: every character side by side
xvfb-run -a $GODOT --rendering-driver opengl3 --path . res://scenes/debug/prop_lineup.tscn \
    -- --screenshot=/abs/out.png [--only=dock,wreck] [--camera=…]  # art review: the dressing kit
```
```bash
$GODOT --path . -- --scenario=<id>       # start at a story checkpoint (data/scenarios.json); =list prints them
tools/checkpoints.sh [ids…]              # screenshot every checkpoint → docs/checkpoints/ + docs/CHECKPOINTS.md
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
    game_settings.gd      GameSettings — player settings (user://settings.cfg), see "Settings"
    input_setup.gd        default input actions registered in code
    journal_model.gd      JournalModel — ordered view data for the quest journal + satchel
    region_mood.gd        RegionMood — region fog and light after flag-driven overrides
    greying.gd            Greying — fog-area depth, active areas, ember-cost map (validator)
    ember_meter.gd        EmberMeter — ember drain/refill in the Greying
    terrain_field.gd      TerrainField — sculpted ground heights, walkability, reachability
    region_events.gd      RegionEvents — region arrival events (which fires, applying its flags)
    act_recap.gd          ActRecap — act_ends in game.json: which acts are reached, recap lines
    json_util.gd, layers.gd
  autoload/    singletons (registered in project.godot)
    content.gd      "Content"    – the loaded ContentDatabase (validates in debug builds)
    game_state.gd   "GameState"  – current WorldState, region, signals (toast, dialogue_requested…)
    save_system.gd  "SaveSystem" – JSON saves in user://saves/<slot>.json: "quick" (F5 / F9)
                    and SLOTS slot1..slot3 (pause menu); slot_summary() for menus; `save_dir`
                    is a var so the smoke test saves elsewhere
  world/       region.gd (builds a region from data), npc_actor.gd, pickup.gd,
               region_exit.gd (optionally gated), inspectable.gd (examine → dialogue),
               interactable.gd, prop_factory.gd (procedural low-poly props),
               character_rig.gd (loads a character .glb + procedural idle/walk motion),
               terrain_builder.gd (TerrainField → flat-shaded vertex-coloured mesh + collider)
               greying_fog.gd (one Greying area's fog layers), greying_walker.gd (ember drain +
               turn-back; a child of main), atmosphere.gd (environment, sky, sun; mood
               tweens; a child of main), water_builder.gd (sea mesh with baked shore depth),
               floating_prop.gd (a prop's `float`: bob/roll + waterline foam ring)
               Node groups: npcs, pickups, inspectables, exits (used by the smoke test)
  player/      player.gd — third-person controller, orbit camera, interaction sensor
  ui/          dialogue_ui.gd, hud.gd, journal_ui.gd (J/I two-tab panel), act_end_card.gd
               (full-screen end-of-act card: title, recap, coda, "Keep exploring"), pause_menu.gd (Esc/Start:
               pauses the tree; Resume / Save / Load / Quit, slot pages) — built in code.
               ui_theme.gd: the one shared `Theme` (palette colours, font sizes, panel box)
               set on each UI root; widgets pick looks via `theme_type_variation`
               (UiTheme.SPEAKER, HINT, HUD_TOAST…), not per-widget overrides.
               `UiTheme.set_text_scale(s)` rescales every font live (settings hook). Modal UIs set `GameState.input_locked` while open and refuse
               to open if another modal already holds it.
  debug/       smoke_test.gd, screenshot.gd, character_lineup.gd, prop_lineup.gd (art-review scenes in scenes/debug/,
               lit by the game's Atmosphere through lineup_light.gd, `--mood=<region>`)
  main.gd      root scene script (scenes/main.tscn)
data/          game.json, flags.json, regions/, npcs/, items/, quests/  (one JSON per record)
story/         dialogue JSON, one file per conversation
assets/models/ Blender-exported .glb (+ Godot .import files — commit both)
tools/         setup.sh, run_checks.sh, blender/ scripts
tests/         run_tests.gd (runner), test_case.gd (base), test_*.gd
```
Scenes are mostly built in code from data so content never requires editing `.tscn` files.

**Physics layers:** 1 world, 2 player, 3 interactable, 4 camera (blocks only the camera arm).

**Camera (Day 15):** the player's orbit camera is placed by a `SpringArm3D` that only
measures: it sweeps a 0.3 m sphere (`Player.CAMERA_PROBE_RADIUS`) out to 7 m on the world and
camera layers; the camera jumps in to a hit at once and eases back out at
`CAMERA_RETURN_SPEED` (`Player.next_camera_distance`). Every model prop with a `collider`
whose mesh is ≥ `Region.CAMERA_BLOCK_MIN_HEIGHT` (2.4 m) tall gets a `CameraBlocker` (layer 4
only) over its mesh bounds from the collider's top up — roofs, eaves, canopies. Automatic,
no data field.

**Pause (Day 15):** `PauseMenu` sets `get_tree().paused` as well as `input_locked`. Nodes that
must run under it use `PROCESS_MODE_ALWAYS` (the menu, `Hud`, `SmokeTest`). It is the last
modal added in `main.gd`, so it sees Esc first and ignores it while another modal holds input
(that modal then closes on the same press).

## Content formats
Every record lives in its own file whose name equals its `id`.

### Region (`data/regions/<id>.json`)
```jsonc
{ "id", "name", "description",
  "water_level": -0.25,                         // optional water plane height
  "fog": {"density": 0.014, "color": "silverfog",
          "overrides": [{"if": condition, "density": 0.007, "color": "..."}]},  // first match wins
  "light": {"sun_color": "kindle", "sun_energy": 1.0, "sun_pitch": -42, "sun_yaw": -35,
            "ambient_color": "silverfog", "ambient_energy": 0.3, "sky_top": "tide",
            "sky_horizon": "silverfog", "note": "...",
            "overrides": [{"if": condition, <any light key>...}]},  // see "Atmosphere"
  "greying": [{"rect"|"ellipse": [...], "strength": 1, "falloff": 2, "height": 2.4,
               "if": condition, "note": "..."}],        // fog areas that drain the ember — see "The Greying"
  "spawn_points": {"default": [x,y,z], ...},    // "default" required
  "ground": {...},                              // sculpted terrain — see "Ground" below
  "terrain": [{"size": [w,h,d], "position": [x,top_y,z], "color": "moss", "rotation_y": 0}],  // legacy slabs (absolute y)
  "props":   [{"model": "res://assets/models/x.glb", "collider": [w,h,d],   // or
               "shape": "pine|rock|house|post|crate|beacon|dock", "color": "...",
               "position": [...], "rotation_y": deg, "scale": 1.0, "if": condition,
               "snap": true,                            // false = absolute y (docks, stilts in water)
               "light": {"color": "kindle", "energy": 1.0, "range": 6, "offset": [x,y,z]}}],  // model props only
  "npcs":    [{"npc": id, "position": [...], "rotation_y": deg, "if": condition}],
  "pickups": [{"id": unique, "item": id, "position": [...], "count": 1, "if": condition,
               "set": {flag: value}, "quest_stage": [quest, stage]}],
  "objects": [{"id": unique, "prompt": "Examine ...", "dialogue": id, "position": [...],
               "reach": 1.8, "if": condition}],        // inspectables: start a dialogue
  "events":  [{"id": unique, "if": condition, "set": {flag: value}, "dialogue": id}],  // arrival events
  "exits":   [{"to": region, "spawn": spawn_name, "position": [...], "prompt": "...",
               "requires": condition, "locked_text": "..."}] }   // gated exits
```
Fog and conditional props, NPCs, pickups and objects (`if`) are re-evaluated **live**
whenever a flag or quest changes (`main.gd` → `Region.refresh_conditional()` +
`RegionMood.fog()`; fog changes tween over 4 s). Exits are always present; their
`requires` is checked on interaction.
**Inland regions (Day 21, `thornwold_woods`):** no `water_level`; the walkable floor is the
`base` height and steep `land` banks (rects along every edge, falloff ≲ 2 m) bound it, so the
reachable area never touches `ground.bounds`. With no water the colour rules treat `base` as
the waterline, so set `colors.shore`/`seabed` to the floor colour too.
Shapes `stool` (Dunstan's stool), `cups` (half-crate with two cups), `net_rack` (drying frame
with a whole net) and `net_frame` (a net begun from the middle) are small dressing props (Day 9).
Shape `signal_lantern` = post with a hanging lantern glowing in its `color` (default moss) +
OmniLight (Mara's ferry signal). Shape `beacon_light` = glowing lantern room + OmniLight for the Gull's Beacon (no collider).
**`light`** (Day 10) adds an OmniLight3D at `offset` (model space) to a **model** prop. Blender
exports no lights; procedural shapes build their own, so the validator rejects `light` on a
shape-only prop, and requires it on a model prop whose `shape` is one of
`PropFactory.LIT_SHAPES` (`signal_lantern`, `beacon_light`) — otherwise the model version
would go dark.
Objects have no visuals of their own (place a prop at the same spot); their dialogue runs
with no NPC. A gated exit is always shown; while `requires` is false, interacting toasts
`locked_text` (required with `requires`) instead of travelling.
Legacy terrain slabs are positioned by their **top surface** (absolute); the player can't
climb steps between slabs. All three Act I regions use `ground` instead. A prop with both `model` and `shape`
uses the model and falls back to the shape only if the model can't load.
Colors are palette names from `PropFactory.PALETTE` (= GAME_DESIGN palette) or `#hex`.

**Model prop extras (Day 14)** — both validated, model props only:
- `"colliders": [{"size": [w,h,d], "offset": [x,y,z]}]` — extra boxes beside the single
  `collider` (model space, base at `offset.y`), for models that aren't one block: Mara's
  `house_porch` has the house box plus one for the porch and one for its steps.
- `"float": {"bob": 0.05, "roll": 1.5, "period": 4.5, "foam": [rx, rz], "foam_y": 0}` wraps
  the model in a `FloatingProp`: it bobs `bob` m and rolls `roll`° (half that in pitch) over a
  `period`-second swell, phase from its position; `foam` adds a flat, level ring of
  vertex-alpha foam around the hull (inner radii across/along it, before `scale`) at `foam_y`
  above the origin (the waterline). Used by the ferry, the fishing boat and the rowboat.
  Colliders ride along with the model (a few cm; harmless).
- The village kit (`build_village.py`, Days 14 & 16): `house_stilt` (the plain cottage),
  `house_wren` (Aldous's family house: bleached boards, a cold Keeper's brazier at the steps,
  an ember-hook by the door), `house_tall` (two storeys, slate/tarred boards, pine shingles)
  and `house_porch` (Mara's) share one 2.6 × 2.2 m wall box on a 1.0 m deck, so the same
  `collider` [2.6, 3.6, 2.2] fits them (`house_tall` is 5.6 m tall); every house is planked on
  all four faces (`_boards`). `gate_post` replaces the procedural `post`. `net_loft_broken`
  (Gull's Head) keeps `net_loft`'s frame and collider. `ember_sign` / `ember_sign_wrapped` are
  modelled **at the hook's spot relative to `house_wren`'s origin**, so a region places them
  with the house's own `position` and `rotation_y` and only the `if` differs (a pattern for
  any story-swappable detail on a building). The old flat-walled `stilt_house.glb` was
  retired on Day 16. Every Act I prop is a Blender model (`test_village.gd` guards it).
- `"wading": [[x, z, radius], ...]` (model props, not with `float`) — small level foam rings
  round legs and pilings standing in the sea (model space before `scale`; one mesh for all
  rings, `FloatingProp.wading_mesh`). At build time a ring is kept only if the ground under
  it is below `water_level`, so a house straddling the tide line gets rings on its wet legs
  only. Used by the dock and the houses in Saltmarrow's shallows.
- `"smoke": [[x, y, z], ...]` (model props) — smoke vents in model space (before `scale`):
  each gets a `CPUParticles3D` column of low-poly puffs that swell, drift downwind and fade
  (`PropSmoke`; preprocessed so it is already standing at load; CPU particles so the
  Compatibility renderer shows it). Vents: `bunkhouse` (1.3, 3.95, -0.6), `tally_house`
  (-0.8, 3.25, -0.5), `charcoal_clamp` crown at y 0.95, radius 0.65 (four vents at
  0.4 + k·90° from +X, Godot z = -Blender y). `test_thornwold_kit.gd` checks vents sit on
  their model. Keep it to a few vents per region (12–16 particles each).

### Arrival events & act ends (Day 13)
- **Region `events`** happen on arriving in a region: after `main.load_region`, the first
  event whose `if` holds applies its `set` flags and plays its `dialogue` (waiting for any
  open dialogue first) — `RegionEvents.arrival/fire`. The validator requires `if`, a known
  dialogue, and a `set` that switches the event off (one of its flags read as `!flag:x` in
  the `if`), so every event fires once. The ferry's horn (`ferry_horn`) lives on Shingle
  Point and Gull's Head, not Saltmarrow: you hear it on coming back from somewhere.
- **NPCs in several places:** an NPC may be placed more than once (any regions) only if every
  placement has an `if` (Pell: beach until `saltmarrow_ferry_arrived`, then the dock). The
  conditions are expected to be mutually exclusive; the validator can't prove that.
- **`act_ends`** in `data/game.json`: `[{id, when, title, subtitle?, recap: [{if?, text}],
  coda}]`. When a dialogue closes and an act's `when` has *just* become true (compared with
  a snapshot taken on every region load, so loading a save never shows a card), `main.gd`
  shows `ActEndCard` with every recap line whose `if` holds. Act I ends on
  `flag:saltmarrow_ferry_passage`. The card is modal; "Keep exploring" (or Esc) closes it and
  play continues — the save carries on into Act II.

### The lanes (Day 17)
The *Slow Mercy* is the only way between islands for now. `lanes_ferry_at` ('' → still at
Saltmarrow after arriving, `thornwold`, `saltmarrow`) places the ferry prop and Oda in exactly
one region (Saltmarrow placements read `!flag:lanes_ferry_at=thornwold`, Thornwold's
`flag:lanes_ferry_at=thornwold` — exact negations). Oda's dialogue sets it and `travel`s; the
first sailing is the full crossing scene (completes *Across the Grey*), later ones are one
line. Pell crosses only if `saltmarrow_pell_crossing=aboard` (`thornwold_pell_landed`) and then
stays on Thornwold. When a ferry/map screen arrives (Milestone 2), it should replace these
dialogue choices, keeping the flag as the ferry's position.

### Story checkpoints (developer jump points)
`data/scenarios.json` → `Scenarios` (scripts/core/scenarios.gd): `{id, act, title,
description, region, spawn?, inherits?, flags?, quests?, items?, collected?, shot?}`.
`inherits` names an earlier checkpoint whose state it builds on (resolved earliest-first,
later keys win); `quests` maps id → stage or `"done"`; `items` id → count (0 drops an
inherited one); `collected` = pickup ids already taken; `shot` = extra screenshot args for
the gallery. Applying resets the world to a new game first (`Scenarios.apply`), so a jump never
mixes with the current playthrough; a checkpoint without `intro_seen` replays the waking.
Entry points: `--scenario=<id>` (main.gd), `GameState.start_scenario(id)`, the pause menu's
**Chapter select (dev)** page (only when `OS.is_debug_build()`), and `tools/checkpoints.sh`
(gallery: `docs/CHECKPOINTS.md`). Validated with the content (`ContentValidator` → `Scenarios.validate`:
known region/spawn, earlier `inherits`, declared flags, real quest stages/items/pickups).
**Rule:** every content session adds a checkpoint for what it built (with a `shot` that frames
it) and re-runs `tools/checkpoints.sh` for the new ids. Checkpoints are hand-written state,
not recordings of play: `test_scenarios.gd` checks the late ones still lead on (Oda casts off
from `act_one_end`, Bram's quest from `thornwold`) and every conversation in each checkpoint's
region finishes.

### The Greying (Day 11)
`greying` areas are the fog as a *place* (region `fog` is only the ambient mood). Depth at a
point = the area's `strength` (0..1, default 1) inside its `rect`/`ellipse`, smoothstepping to
0 over `falloff` m outside; overlapping areas take the deepest (`Greying.depth_at`). Areas
with `if` come and go live (`Region.refresh_conditional`, fading over 4 s) — Gull's Head's
headland areas carry `!quest:a_light_for_saltmarrow=done` and smaller pockets appear after.
- **Look:** `GreyingFog` = 5 stacked translucent layers over the area (`height` m tall)
  hugging `max(ground, water)`, each vertex's alpha baked from the same depth function,
  animated by `assets/shaders/greying_fog.gdshader` (value noise, swell, near-camera fade;
  no textures/depth buffer, so it works in Compatibility). Standing in it also thickens the
  environment fog (+0.05 × depth) and desaturates (−45 % × depth), smoothed in `main.gd`.
- **Ember:** `GreyingWalker` (child of main) samples depth under the player each physics
  frame and steps an `EmberMeter` (full → empty in `Greying.DRAIN_SECONDS` = 24 s at depth 1,
  refills in 4 s in the clear). **Paused while `GameState.input_locked`** (dialogue, journal).
  The HUD shows an "Ember" bar top-left while in or just out of the fog, a grey wash as it
  wanes, and dims the ember-hand light (`Player.set_ember`). No fail state: when it empties,
  the screen fades to fog, the player is put back on the **last clear ground they stood on**
  (else the default spawn), refilled, and toasted "You forget why you came." Not saved.
- **Validator:** well-formed areas (known keys, one shape, numbers in range); **no spawn
  point in any area**; and, with every area present (worst case), every spawn/NPC/pickup/
  object/exit must be reachable from clear ground spending ≤ `MAX_ONE_WAY_EMBER` (0.45)
  — a Dijkstra over walkable cells (`Greying.ember_cost_map`), so content can never be
  stranded in fog the player can't get into and back out of.
- **Lantern light — `clear` areas (Day 21):** an area with `"clear": true` is light holding
  the fog back (the waymark lanterns past Thornwold's bramble wall, the colliers' clearing). It
  draws no fog of its own; `depth_at` = (deepest fog area) × (1 − brightest clear area's depth),
  so a full-strength clear ellipse cuts a pool out of any fog, edged by its falloff. `GreyingFog`
  bakes the same cut into its layers (triangles fully inside a pool are dropped);
  `Region._refresh_greying` re-cuts every shown layer when the set of active clear areas changes
  (no tween yet). Validator: `clear` must be a bool; the worst case
  (`Greying.worst_case_areas`) is every fog area plus only the **unconditional** clear areas — a
  lantern the story may take away doesn't count toward the spawn-clear and ember-budget checks.

### Atmosphere & water (Day 12)
`Atmosphere` (child of main) owns the `WorldEnvironment` and the sun. A region's mood =
`RegionMood.fog` + `RegionMood.light` (every key optional, defaults in
`RegionMood.LIGHT_DEFAULTS`; overrides first-match like fog, validated: known keys, palette/#hex
colours, numbers, `if` required). Story changes tween the **whole mood** (fog, sun colour/
energy/angle, ambient, sky) over 4 s, so a relit beacon visibly warms the light; region loads
apply it instantly. The Greying look (thicker fog, −45 % saturation at full depth) is layered
on top by `follow_greying`.
- **Sky:** `assets/shaders/sky.gdshader` — zenith→horizon gradient from `sky_top`/`sky_horizon`,
  a sun halo (no disc), slow flat cloud bands near the horizon (polar noise, no seam), heavier
  in thicker fog. Keep `sky_horizon` ≈ the fog colour so the sea melts into it.
- **Grading:** Filmic, contrast ×1.08, saturation ×1.12; **glow** above HDR 1.0 (softlight), so
  only emissive materials bloom (ember, lantern/beacon glass, smokehouse vent, windows);
  **SSAO** is on but Forward+-only (a no-op in Compatibility screenshots).
- **Light budget decision:** real lights only for the ember hand (breathing flicker, dims
  with the Greying), the ferry signal lantern and the lit beacon. Street lanterns, windows and
  the smokehouse vent are emissive + glow only — enough by day; revisit with day/night.
- **Water:** `WaterBuilder` builds a half-metre grid over the ground bounds (cells well inland
  skipped) plus a skirt out to 300 m sharing the grid's edge vertices (no T-junction cracks
  when the swell moves them). Each vertex's `COLOR.r` = water depth over the ground / 1.2 m.
  `assets/shaders/water.gdshader`: shallow (tide+moss) → deep (abyss) colour, faceted normals
  from derivatives, swell that grows with depth (so the shoreline stays put), a ragged foam
  band at depth≈0 and a broken wash line moving in. No depth buffer → same in Compatibility.
  Foam follows the *ground* only; piers, pilings and boats get none (yet).

### Ground (sculpted terrain)
**Decision (Day 7):** terrain is generated in Godot from region data, not modelled in
Blender. Heights must be known at runtime (to snap content onto the ground, and for the
validator's "can the player reach it" check), and keeping it in JSON lets content sessions
reshape a region without touching a Blender script. Blender stays the tool for props and
characters.
```jsonc
"ground": {
  "bounds": [x_min, z_min, x_max, z_max],   // grid extent; keep all land well inside it
  "cell": 1.0, "base": -1.6,                // grid spacing; seabed height
  "seed": 3, "roughness": 0.06,             // per-vertex height jitter (faceted look)
  "ragged": 1.2, "ragged_scale": 5.0,       // coastline wobble (m) on rect/ellipse edges
  "wade_depth": 0.35,                       // deeper than water_level - this = shore wall
  "land": [                                 // height = max over features
    {"rect": [x0,z0,x1,z1], "height": 0.3, "falloff": 3},
    {"ellipse": [cx,cz,rx,rz], "height": 2.8, "falloff": 1.2, "ragged": 0.5},
    {"path": [[x,z,h], ...], "width": 4, "falloff": 1.2}      // ramps/spits; h interpolates
  ],
  "colors": {"ground": "moss", "shore": "driftwood", "shore_height": 0.35,
             "seabed": "slate", "cliff": "slate", "cliff_slope": 0.9},
  "paint": [{"rect"|"ellipse"|"path": ..., "width": 2, "color": "driftwood"}],  // first wins
  "piers": [{"rect": [x0,z0,x1,z1], "deck": 0.275}],  // walkable decks over water (absolute y)
  "note": "free text"
}
```
Each feature's influence is 1 inside and smoothsteps to 0 over `falloff` metres; a small
falloff makes cliffs (coloured `cliff` above `cliff_slope` rise/m, unwalkable above ~0.84).
Triangle colour order: paint → cliff → seabed (below water) → shore band → ground.
**With `ground`, every position's y is an offset above the ground** (spawns, NPCs, pickups,
objects, exits, props unless `"snap": false`). The collider is the same grid with sea
vertices raised `WALL_HEIGHT` above the water, so the coastline is the edge of the playable
area. A wide seabed plane hides where the grid ends.
**Piers** (Day 8) make a dock walkable: collider vertices inside a pier rect are raised to
the `deck` height instead of the shore wall, and those cells count as walkable, so the wall
still rises along the pier's sides and end. `Region.place`/`ground_y` use the deck over a
pier (`TerrainField.surface_at`), so content can stand on it. A pier has no visuals — put a
`dock` prop (`"snap": false`) over it. Its rect must lie on grid lines (the collider only
spans the vertices inside it), its deck must be above the water, and it must be reachable.
The validator builds each field and errors if a spawn/NPC/pickup/object/exit can't be
reached on foot from the default spawn (flood fill over walkable cells), if walkable ground
touches the bounds, or on malformed features. Tune shapes with `tools/debug/terrain_map.gd`
(ASCII map: `#` reachable, `^` too steep, `~` sea, `@` content) and overview screenshots
with `--camera=`.

### NPC / Item / Quest
- NPC: `id, name, color, dialogue, model?, idle?, faces_player?, faction?, bio?` — must be placed at least
  once (several placements only if each has an `if`; see *Arrival events*). `model` = character scene (see *Characters*); without it the NPC is a primitive
  figure in its `color`. `idle` = `breathe` (default) | `mend` | `rake`. While talking, an NPC's body
  eases round to face the player and back to its placed `rotation_y` after (the Wakebearer
  turns to it too); `"faces_player": false` opts out (Hesk keeps mending).
- `data/game.json` also takes `player_model` (the Wakebearer character scene) and `act_ends`.
- Item: `id, name, description, kind (remnant|key|misc), color?, future?`
- Quest: `id, title, description, stages: [{id, text}], giver?, region?, future?` — first
  stage is entered on `quest_start`. `future: true` silences the "never completed" warning
  for a quest whose ending isn't written yet (e.g. *Across the Grey*, the Act II bridge).

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
- `"travel": [region_id, spawn?]` (Day 17) — when the dialogue **closes**, the player is moved
  to that region/spawn (`DialogueRunner.pending_travel` → `DialogueUI._close` →
  `GameState.travel`). Put it on the last step so the scene finishes first; the destination's
  arrival `events` then fire as usual. Validated: known region and spawn. Used by Oda's ferry
  (`sail`, `sail_again`, `back` in `story/oda.json`).
- `"note"` is ignored (writer comments).

## Dressing kit (Day 10)
`tools/blender/build_dressing.py` builds the set-dressing models into `assets/models/dressing/`
(dock, rowboat, rowboat_upturned, moored_boat, smokehouse, barrel(s), crate, lantern_post,
signal_lantern, fence, stool, cups, net_rack/net_frame (+ `_pine` variants, since a model
prop can't be tinted), driftwood_log, wreck, reeds, grass, beacon_lit, **ferry** (the *Slow Mercy*,
9 m, origin at the waterline, port side/boarding plank at +X — the one model allowed past the
8 m bounds in `test_dressing.gd`), **bundle** (Pell's travelling sack)). It reuses
`build_props.py`'s palette and primitives and adds tonal shades (`mat(name, shade)`), beams
and rods between two points, net lattices, and a lofted boat hull (`hull_stations` → `hull`,
`gunwale`, `deck`). Before export every mesh is **joined by material and its transform
baked** (`merge_by_material`), so a net's strands are one draw call and every mesh sits at the
model origin.
**Replacement rule:** a model that replaces a procedural shape keeps that shape's footprint
and key heights (dock deck top 0.675; beacon glass 4.14–5.0; lantern glass centre
(0, 1.85, 0.58) in Godot space), so region data swaps `shape` for `model` without moving
anything. Region entries keep `shape` as the fallback — tests and the smoke test find
conditional props by it (`Region.shown_conditional_props(shape)`). Boats are placed with
`"snap": false`: `moored_boat`'s origin is the waterline; `rowboat` sits on its keel.
`tests/test_dressing.gd` loads every kit model (< 5 MB, ≤ 16 mesh nodes, sane bounds, standing
on its origin), checks the dock/beacon heights, model-prop lights and the light validation.
**Woods kit (Day 20):** `tools/blender/build_woods.py` (same kit dir, same conventions) —
`collier_hut` (charcoal-burner's cone hut, 3 m across: one hand-built cone mesh whose faces
carry a patchwork of bark/turf materials, a gabled doorway at -Y, hearth and log seat in
front), `sack_cart` (handcart, shafts to -X, ~2.6 × 1.3 m), `waymark` / `waymark_lit` (Keeper
cairn + post with the carved ember; lantern glass centre (0, 1.77, 0.5) in Godot space — give
`waymark_lit` a `light` there if one is ever wanted; it's emissive-only by the light budget),
`trail_stake` (pointer along +X, notches on the -X face: `rotation_y` 90 points it to -Z),
`greyed_brush` and `pine_grey` (same trunk footprint/collider as `pine_dark`). Keep each model
to a few shades: the kit test caps a model at 16 mesh nodes after the merge by material.
**Ridge kit (Day 22):** `tools/blender/build_ridge.py` (same kit dir, imports `build_woods` for
its lumps) — `thornwold_beacon` / `thornwold_beacon_lit` (≈ 4.8 × 10.1 × 5.4 m: the one model
`test_dressing.gd` lets stand up to 11 m; door and carved ember on -Y, lantern rack on +X,
lantern cage 6.1–7.5 m with the pane centre ≈ (0, 6.7, 0) for a future `light`; lit = emissive
kindle panes) and `keeper_lodge` (4.8 × 3.3 × 3.2 m, door right of centre on -Y, lantern bench
under the eave at -X). `build_woods.py collier_hut` also writes `collier_hut_cold` (same
footprint). Note `bp.prism` creates its object through the data API and does **not** make it
active — use its return value (e.g. to rotate it), never `bpy.context.active_object`.

## Characters
Built by `tools/blender/build_characters.py` from one chunky base body (~700–900 tris, ~65 KB
each) plus per-character costume pieces; palette colors and tonal shades of them only.
Models face **+Z** in Godot. No skeleton: each model is a node hierarchy that
`CharacterRig` animates procedurally (breathing, sway, head drift, walk swing driven by the
player's speed, `mend` hand motion for Hesk, `rake` pulls and a forward lean for Hob):
```
Rig (root, may be scaled — Pell is 0.78)
  LegL, LegR        pivot at hip
  Torso             pivot at waist
    Head            pivot at neck
    ArmL, ArmR      pivot at shoulder; held items are part of the arm; may have rest rotation
  Stool             optional static extras
```
The rig stores each part's rest transform and applies small offsets on top, so rest poses
(Aldous's stoop, Hesk's hands over the net) are authored in Blender. `test_characters.gd`
checks every NPC/player model has the parts with the right parents. New character: add a
`build_<id>()` to the script, run it, set `model` in the NPC's JSON.
Blender gotcha: bake rotation/scale into each primitive before joining (the script's
`_finish` does) — joined objects keep only the first object's transform and the rest pose
then overwrites it (this flipped every arm upward on the first try).

## Settings (Day 19)
`GameSettings.current()` (loaded and applied by `GameState._ready`) holds the player's
settings; the pause menu's **Settings** and **Controls** pages edit it and save on leaving.
`user://settings.cfg` (ConfigFile) — never in save games:
```
[audio]    Master/Music/Ambience/Effects/Voice = 0..1 (linear; 0 mutes the bus)
[display]  text_scale = 0.75..2.0   (menu presets 0.85 / 1.0 / 1.25 / 1.5 → UiTheme)
[camera]   sensitivity = 0.25..2.5, invert_x, invert_y   (Player reads them per event)
[keys]     <action> = "<key name>"   only rebound actions, e.g. interact = "F"
```
- **Audio buses** are created in code (`GameSettings.ensure_bus`, sent to Master) — there is
  no `default_bus_layout.tres`. The audio-hooks item should play through these buses by name.
- **Rebinding**: each `InputSetup.REBINDABLE` action's first key in `BINDINGS` is its
  primary; rebinding replaces it, swaps with whichever action held the new key, and refuses
  Esc and the menu keys (pause stays Esc/P/Start). Default secondaries (arrows, Enter) stay
  unless another action claims them. `InputSetup.apply_keys` rebuilds the keyboard events;
  pad bindings are untouched (not rebindable yet). HUD/dialogue hints use `InputSetup.hint()`.
- Loading clamps every value and ignores unknown/reserved/duplicate keys, so an old or
  hand-edited file never breaks the game. Tests use their own instance and path
  (`GameSettings.set_current`); the smoke test writes `user://smoke_settings.cfg`.
- Range controls don't emit `value_changed` outside the scene tree (Godot 4.7): tests that
  drive a menu slider emit it by hand.

## Save format
`user://saves/<slot>.json`: `{version, saved_at, region, spawn, player_position, world:
WorldState.to_dict()}`. Bump `SaveSystem.SAVE_VERSION` on breaking changes and add migration.

## Testing
- `tests/test_content.gd` — content loads, all references valid, every dialogue terminates,
  validator catches deliberately broken links.
- `tests/test_burning.gd` — the Act I beacon choice through real story content (each burn
  path, Pell's consent, Mara's gull, returning unburned Remnants, fog thinning).
- `tests/test_confession.gd` — Aldous's confession (gentle/full vs. pressed/grudging with a
  second visit), the *Across the Grey* hook and Mara's ferry lantern.
- `tests/test_aftermath.gd` — Saltmarrow after the burn: which conditional props each burn
  shows, the stool/nets/lost-things inspectables per state, Pell's ferry ask, Tam's fare,
  Mara and the sleeve-ember.
- `tests/test_dressing.gd` — the Blender dressing kit (see *Dressing kit*).
- `tests/test_wrens_and_lofts.gd` — houses planked on every side, the retired stilt house,
  the Wrens' house and its ember sign per confession (+ the `wrens_door` inspectable), Gull's
  Head's broken lofts (Hesk's stays whole), `wading` foam only over the sea, validator checks.
- `tests/test_thornwold_kit.gd` — Thornwold's own kit is placed (no Saltmarrow houses or pines
  left there), smoke vents on their models, one emitter per vent, validator checks, the clamp
  past the wall.
- `tests/test_woods_kit.gd` — the woods kit exists (< 5 MB, base-centred), is placed past the
  wall (hut and lit waymark only in the woods region), Greyed growth/cart/waymark stand
  in the Greying and the trail stake on clear camp ground, the lit waymark's glass glows.
- `tests/test_woods.gd` — `clear` areas (pools, edges, light alone is no fog, worst case), the
  fog layers cut around pools, validator `clear` check, the ember parting the bramble wall
  (quest gate, travel, stage, parting again), the woods layout (spawns and lit waymarks in clear
  pools, bare waymarks and the straight road deep, the clearing clear, the ridge lantern out of
  reach, the arrival scene once and only after the parting), Hob and the Lamp, the tally board
  and *Salt for the Collier* end to end, the tally stick (only with Pell).
- `tests/test_ferry.gd` — the ferry's arrival: the horn event fires once and only away from the
  harbor, Pell/Oda/ferry/bundle placement, Oda weighing the deed per burn, passage and the Act I
  recap, a promised Pell needing Mara's leave (both answers), Pell's dock ask and the pouch,
  Mara's farewell and message for Dunstan, validator rules for events and multi-placement.
- `tests/test_crossing.gd` — the crossing: casting off completes *Across the Grey* and travels,
  narration per burn and per Pell outcome, ferry/Oda/Pell placement on both ends of the lane
  (there and back), the landing scene once, Bram per deed/burn (knot grudge), the bramble wall
  advancing *A Light for Thornwold*, Pell on Thornwold, travel validation.
- `tests/test_scenarios.gd` — story checkpoints: validation, inheritance, reset-then-apply,
  each burn checkpoint, the story continuing from the late ones, every conversation finishing.
- `tests/test_settings.gd` — settings defaults, bus volume/mute, text size presets, camera
  sensitivity/invert, rebinding (swaps, claimed secondaries, reserved keys), file round trip,
  bad-file tolerance, the pause menu's Settings and Controls pages (key capture, Esc cancels,
  reset asks twice, leaving saves). The smoke test rebinds the journal with a real key press.
- `tests/test_greying.gd` — area depth/falloff, Gull's Head fog leaning back after the burn,
  EmberMeter drain/refill/emptied, the ember-cost map, the fog layer mesh, validator checks
  (malformed areas, spawn in fog, ember budget on a 120 m fixture strip).
- `tests/test_atmosphere.gd` — region light defaults/overrides (the burn warms every Act I
  region), validator light checks, water depth baking (land 0, sea 1, shallows exist), water
  mesh (shore foam vertices, skirt, inland cells skipped), Atmosphere applying a mood + Greying.
- `tests/test_terrain.gd` — TerrainField heights, mesh/triangle agreement, ramp/cliff/sea
  reachability, colour rules, mesh faces up + shore-wall collider, ground-relative placement,
  validator ground checks.
- `tests/test_characters.gd` — character models follow the rig contract; the rig poses and
  returns to rest; missing models fall back; validator catches bad `model`/`idle`.
- `tests/test_dialogue.gd`, `tests/test_world_state.gd`, `tests/test_journal_model.gd` — unit
  tests on fixtures.
- Smoke test — boots the real main scene, checks the player and every NPC show their rigged
  character model, plays intro, checks the player lands on the ground in every region and NPCs
  stand on it, walks up the Gull's Head ramp and into its shore wall with real
  input + physics, walks from clear ground up into the Greying (depth, drain, meter shown),
  lets the ember run out (sped up) and checks the turn-back to clear ground, checks every
  gated exit refuses
  travel on a new game, visits every region twice, talks to every NPC and examines every
  object walking each menu, collects pickups, checks gated exits now open, that the menu
  walk relit the Gull's Beacon (quest done, a Remnant burned, beacon light shown, fog
  thinned, the region light applied), that a third pass reached Aldous's confession and Mara's ferry lantern, that the horn sounded
  on arriving elsewhere (arrival events are clicked through), that passes 4–5 met Oda, settled
  Pell and took passage (the Act I end card showed a recap naming the burn, and was closed), that
  a late pass cast off with Oda to Thornwold (a `travel` mid-walk ends that region's walk; the
  landing scene is clicked through) and met Bram, that the bramble wall's menu walk went
  through the gap into the woods (an inspectable's `travel` also ends the region's walk), and that ferry, Oda and Pell stand where the
  lane left them (and that
  Saltmarrow's burn-specific dressing matches the burn — `Region.shown_conditional_props(shape)`), opens the journal and satchel via real input
  actions, saves/loads and compares state.
- Add a `test_*.gd` extending `TestCase`; methods named `test_*` run automatically.

## Rendering notes
Project targets Forward+ (Vulkan). In the sandbox only the OpenGL Compatibility renderer
(`--rendering-driver opengl3` under Xvfb/llvmpipe) is available for screenshots, and it
renders noticeably brighter/washed-out; do color grading on a real GPU.
