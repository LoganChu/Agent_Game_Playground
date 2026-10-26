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
$GODOT --path .                                             # play (opens on the title screen)
$GODOT --path . -- --region=saltmarrow                      # start in a region (debug)
$GODOT --path . -- --flags=intro_seen,saltmarrow_beacon_burned=knot \
    --quest=a_light_for_saltmarrow,across_the_grey:await_the_ferry  # late-game state (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --region=saltmarrow \
    --flags=intro_seen,saltmarrow_beacon_burned=gull,saltmarrow_ferry_passage \
    --act-end=act1 --screenshot=/abs/out.png               # show an act's end card (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --region=saltmarrow --flags=intro_seen \
    --pause-menu[=save|load|chapters|settings|controls] --screenshot=/abs/out.png     # pause menu (on a page) (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --scenario=lamp_named --region=thornwold_landing \
    --lane-map[=wrackholm] --settle=60 --screenshot=/abs/out.png   # Oda's lane map (focus on a port) (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --scenario=kindleby_lit \
    --journal=lanes --settle=60 --screenshot=/abs/out.png          # the journal on a tab (journal|satchel|lanes) (debug)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --screenshot=/abs/out.png   # the waking (debug args skip the title)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --title --settle=90 --screenshot=/abs/out.png  # the title screen
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --region=saltmarrow \
    --camera=0,26,34:0,0,0 --screenshot=/abs/out.png       # fixed overview camera (eye:target)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . -- --region=gulls_head --flags=intro_seen \
    --at=0,-9,0 --settle=60 --screenshot=/abs/out.png      # player at x,z (camera yaw), wait N frames
$GODOT --headless --path . -s res://tools/debug/terrain_map.gd [-- <region>]  # ASCII walkability map
$GODOT --headless --path . -s res://tools/debug/export_sounds.gd -- /abs/dir [ids…]  # the procedural sounds as .wav (audio review)
.tools/bin/blender-py tools/blender/build_props.py          # rebuild .glb props (pine, rocks, beacon, net-loft)
.tools/bin/blender-py tools/blender/build_characters.py [aldous aldous_seated oda hob hob_seated hob_lantern lamp lamp_named hesper corran corran_nocord unmoored_shawl unmoored_coat dunstan dunstan_seated dunstan_seated_cord dunstan_lantern dunstan_home dunstan_turning wenna wenna_nobrass jory yard_smock yard_smock_mallet yard_shawl yard_lad provost tobin keeper_sister keeper_brother …]  # rebuild characters (assets/models/characters/)
.tools/bin/blender-py tools/blender/build_dressing.py [dock wreck …]  # rebuild the dressing kit (assets/models/dressing/)
.tools/bin/blender-py tools/blender/build_village.py [house_stilt house_wren brazier_ash brazier_raked brazier_laid net_loft_broken net_loft_mended plank_bench …]  # village buildings (same kit dir)
.tools/bin/blender-py tools/blender/build_thornwold.py [bramble bunkhouse tally_house log_bench saw_pit charcoal_clamp pine_dark clamp_rake …]  # Thornwold kit (same kit dir)
.tools/bin/blender-py tools/blender/build_woods.py [collier_hut (+ collier_hut_cold, collier_hut_cold_cap, collier_hut_cold_empty) sack_cart waymark trail_stake greyed_brush pine_grey]  # Thornwold woods kit (same kit dir)
.tools/bin/blender-py tools/blender/build_fen.py [reed_house letting_post (+ letting_post_word) heron_light staithe boardwalk plank_path punt eel_traps alder_snag reed_bed keeper_skiff (+ _bell) tussock gold_streak gull_cord]  # Glasswater Fen kit (heron_light also writes heron_light_near, no block skiff, and since Day 35 `_lit` variants of both: horn panes glowing, a fire in the cradle; Day 36: the near lit one has the put-down things on the sill and the coat; Day 39: both near ones carry the landing and cleat at the ladder foot; `gull_cord` is built in the Heron's own frame and placed where the Heron is) (same kit dir)
.tools/bin/blender-py tools/blender/build_wrackholm.py [lane_house answering_horn (+ answering_horn_open) gannet_hulk (+ gannet_hulk_bare, gannet_hulk_named) salvage_stack float_pile wrack_light (+ wrack_light_lit) teeth_rock teeth_mark]  # Wrackholm kit (Day 40; the Day 43 variants: the horn unlashed, the board prised off, the Wrack lit; lane_house's chimney smoke at HALL_SMOKE, the Gannet's crew board at GANNET_BOARD — tests/test_wrackholm.gd pins both to the region) (same kit dir)
.tools/bin/blender-py tools/blender/build_ridge.py [thornwold_beacon (+ _lit) keeper_lodge ridge_steps keeper_ladder waymark_cap sack_dropped ridge_outcrops (+ _low) heather_silver waymark_tumbled]  # the ridge and the way up (same kit dir)
.tools/bin/blender-py tools/blender/build_old_road.py [northing_cairn cresset_coals cresset_lantern waymark_rake steps_foot boat_stage stage_lantern drift_fire drift_fire_out drift_shelter]  # the old Keepers' road north (Day 53) and the far shore below it (Day 55) (same kit dir)
.tools/bin/blender-py tools/blender/build_bend.py [clamp_spent clamp_spent_open hut_lantern]  # Coll's Hearth (Day 57): Wenna's clamp burned through (Day 58: and raked open, sacks filled, front on +Z); a Keeper's lantern on a forked stake by a hut door (glass centre Godot [0, 1.28, 0.32] = its `halo`) (same kit dir)
.tools/bin/blender-py tools/blender/build_kindleby.py [chapter_house candle_ledge vigil_bell quiet_house vigil_light vigil_light_lit]  # Kindleby (Day 62): the Keepers' chapter-house, the candle wall (a 2.4 m ledge, candles emissive — no lights), the quay bell, the Quiet House (barred), the Vigil Light (Day 64: `vigil_light_lit` — horn glowing, a fire in the cradle, the door open; the pane centre is Godot y ≈ 5.1 = its `halo`/`light`; the finial's ember now sits on the finial; Day 63: the chapter-house's open bell-cote, door hood and step candles; `_diamond` turns a box 45° in place — the primitives bake their location, so `obj.rotation_euler` on a placed box swings it round the model origin) (same kit dir)
xvfb-run -a $GODOT --rendering-driver opengl3 --path . res://scenes/debug/character_lineup.tscn \
    -- --screenshot=/abs/out.png [--closeup] [--mood=gulls_head] [--only=hob,lamp] [--pose=0.16] [--turn=60]  # art review: every character side by side (+ unplaced models); --pose freezes the idles at t s, --turn turns the models
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
    sound_synth.gd        SoundSynth — renders a data/audio.json recipe into an AudioStreamWAV
    sound_bank.gd         SoundBank — rendered sounds by id, cached, rendered off the main thread
    lanes.gd              Lanes — the lane map's logic: known ports, open lanes, voyage → knot
    act_recap.gd          ActRecap — act_ends in game.json: which acts are reached, recap lines
    json_util.gd, layers.gd
  autoload/    singletons (registered in project.godot)
    content.gd      "Content"    – the loaded ContentDatabase (validates in debug builds)
    game_state.gd   "GameState"  – current WorldState, region, signals (toast, dialogue_requested…)
    save_system.gd  "SaveSystem" – JSON saves in user://saves/<slot>.json: "quick" (F5 / F9)
                    and SLOTS slot1..slot3 (pause menu); slot_summary() for menus, latest_slot()
                    for the title's Continue (newest `saved_at`, quicksave included); `save_dir`
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
               audio_director.gd (the soundscape: ambience, footsteps, voices, cues, the
               Greying's muffle; a child of main), sound_emitter.gd (a prop's positional `sound`)
               Node groups: npcs, pickups, inspectables, exits (used by the smoke test)
  player/      player.gd — third-person controller, orbit camera, interaction sensor
  ui/          dialogue_ui.gd, hud.gd, journal_ui.gd (J/I/L three-tab panel: journal, satchel, the chart),
               lane_map.gd (`LaneMap`: Oda's chart, a child of DialogueUI — see "The lane map"), act_end_card.gd
               (full-screen end-of-act card: title, recap, coda, "Keep exploring" / "Return to title"),
               menu_screen.gd (`MenuScreen`: the page-based menu panel and the pages both menus
               share — Load, Chapter select (dev), Settings, Controls), pause_menu.gd (`PauseMenu`
               extends it; Esc/Start: pauses the tree; Resume / Save / Load / Settings / Return to
               title / Quit), title_screen.gd (`TitleScreen` extends it; Continue / New game / Load /
               Settings / Quit over the live start region) — built in code.
               ui_theme.gd: the one shared `Theme` (palette colours, font sizes, panel box)
               set on each UI root; widgets pick looks via `theme_type_variation`
               (UiTheme.SPEAKER, HINT, HUD_TOAST…), not per-widget overrides.
               `UiTheme.set_text_scale(s)` rescales every font live (settings hook). Modal UIs set `GameState.input_locked` while open and refuse
               to open if another modal already holds it.
  debug/       smoke_test.gd, screenshot.gd, character_lineup.gd, prop_lineup.gd (art-review scenes in scenes/debug/,
               lit by the game's Atmosphere through lineup_light.gd, `--mood=<region>`)
  main.gd      root scene script (scenes/main.tscn)
data/          game.json, flags.json, audio.json, regions/, npcs/, items/, quests/  (one JSON per record)
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

**Title screen (Day 41):** a plain launch (and `--smoke-test`) opens on `TitleScreen` (layer 20)
over the freshly built start region: `GameState.new_game()` has run, the waking narration waits,
the HUD is hidden, input is locked, the tree is *not* paused (the sea moves) and `main.gd` swings
the camera round the Wakebearer (`Player.turn_camera`, `TITLE_DRIFT`). Region arrival events wait
for it to close. Any debug arg that asks for a state or screen (`--scenario`, `--region`,
`--flags`, `--quest`, `--act-end`, `--pause-menu`, `--screenshot`) skips it — `main.wants_title()`;
`--title` forces it. **New game** → `main.start_new_game()` (reset, rebuild the start region, play
the waking). **Continue** loads `SaveSystem.latest_slot()`; a save that won't load keeps the title
up with a note. **Return to title** (pause menu, act-end card; both ask twice) →
`main.return_to_title()`: reset and rebuild behind the title, opened *deferred* so the closing
menu's deferred input unlock lands first. The big game name is a fixed 64 px (doesn't follow the
text-size setting; everything else on the screen does).

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
  "ambience": [{"sound": "surf", "volume": 0.8, "if": condition}],  // looping layers — see "Audio"
  "footsteps": "shingle", "footsteps_raised": "stone",  // surfaces (audio.json); raised = decks etc. (default boards)
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
               "reach": 1.8, "glint": [x,y,z] | false, "if": condition}],  // inspectables: start a dialogue
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
**A drop at the edge (Day 25, `thornwold_ridge`):** for a high place, make `base` the low ground
far below (-6) and the walkable top a `land` rect at 0 with a short falloff (2 m → a cliff). The
low ground is walkable but never *reachable*, so the bounds check (reachable cells only) passes;
a prop on the drop uses `"snap": false` (the ladder's feet at y -2.95 so its head meets the lip).
**Arrival events need the way in:** `_check_ground` in the smoke test (and any debug
`--region=`) teleports into every region on a new game, so an event whose `if` is only
`!flag:seen` fires there and holds input. Gate it on how the player gets in (the ridge's on
`flag:thornwold_ladder_stood`, the woods' on the parting).
Shapes `stool` (Dunstan's stool), `cups` (half-crate with two cups), `net_rack` (drying frame
with a whole net) and `net_frame` (a net begun from the middle) are small dressing props (Day 9).
Shape `signal_lantern` = post with a hanging lantern glowing in its `color` (default moss) +
OmniLight (Mara's ferry signal). Shape `beacon_light` = glowing lantern room + OmniLight for the Gull's Beacon (no collider).
**`light`** (Day 10) adds an OmniLight3D at `offset` (model space) to a **model** prop. Blender
exports no lights; procedural shapes build their own, so the validator rejects `light` on a
shape-only prop, and requires it on a model prop whose `shape` is one of
`PropFactory.LIT_SHAPES` (`signal_lantern`, `beacon_light`) — otherwise the model version
would go dark.
**Glint (Day 23):** every object shows a faint four-point star (`Glint`, `assets/shaders/glint.gdshader`:
camera-facing quad, alpha-blended, HDR-bright, depth-tested, twinkles every ~3 s with a phase
from its position) at `glint` above its spot (default `Glint.DEFAULT_OFFSET` = 1.1 m up;
`false` = none). It fades in between 11 and 7 m from the player and out again inside the
object's `reach`, where the "[E] Examine…" prompt takes over. Validated (`false` or [x,y,z]).
Objects have no visuals of their own otherwise (place a prop at the same spot); their dialogue runs
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
  The brazier's contents follow the same pattern (Day 47): `house_wren` keeps the bowl only, and
  `brazier_ash` (cold heap) / `brazier_raked` (after a `full` confession) / `brazier_laid` (after
  `saltmarrow_aldous_novice`) sit in it at the house's origin, `shape` "brazier", exactly one shown.
- `"wading": [[x, z, radius], ...]` (model props, not with `float`) — small level foam rings
  round legs and pilings standing in the sea (model space before `scale`; one mesh for all
  rings, `FloatingProp.wading_mesh`). At build time a ring is kept only if the ground under
  it is below `water_level`, so a house straddling the tide line gets rings on its wet legs
  only. Used by the dock and the houses in Saltmarrow's shallows.
- `"sound": {"id": "fire", "offset": [0, 4, 0], "range": 20, "volume": 1}` (model props) — a
  looping positional sound in model space (`SoundEmitter`; Day 46): every lit beacon `fire`,
  the charcoal clamps `embers`. See "Audio".
- `"smoke": [[x, y, z], ...]` (model props) — smoke vents in model space (before `scale`):
  each gets a `CPUParticles3D` column of low-poly puffs that swell, drift downwind and fade
  (`PropSmoke`; preprocessed so it is already standing at load; CPU particles so the
  Compatibility renderer shows it). Vents: `bunkhouse` (1.3, 3.95, -0.6), `tally_house`
  (-0.8, 3.25, -0.5), `charcoal_clamp` crown at y 0.95, radius 0.65 (four vents at
  0.4 + k·90° from +X, Godot z = -Blender y). `test_thornwold_kit.gd` checks vents sit on
  their model. Keep it to a few vents per region (12–16 particles each).
- `"halo": [x, y, z]`, `"halo_size": 1.8` (model props, Day 26) — a soft camera-facing glow at
  a lantern's glass (`LanternHalo` + `assets/shaders/lantern_halo.gdshader`: alpha-blended,
  unshaded, fog-disabled, a slow flame flicker, faint within ~2.5 m of the camera and full from
  ~9 m) so lanterns read across a clearing or through the fog **without a real light** (the
  light budget stands: ember, ferry lantern, beacon). Every `waymark_lit` carries one at
  `[0, 1.76, 0.5]` (its glass centre); `test_ridge_dressed.gd` checks that. Day 28: optional
  `"halo_strength"` (default 0.8) and `"halo_bloom"` (default 0; 0..2, validated) — the bloom adds
  a wide, faint glow over the whole quad (the fog lit round a beacon). The lit Ridge Light on the
  woods' skyline uses size 14 / strength 1 / bloom 0.35 (it is ~60 m off); on the ridge a size-6
  halo beside the real light. Every `lantern_post` carries one at `[0, 1.85, 0.58]`.
- `"idle": "still"` (Day 30) makes the prop a **figure**: its `model` must be a character model
  (`assets/models/characters/`, the rig contract) and it is built with `CharacterRig.instantiate` in
  that idle style — set dressing that breathes (the Unmoored by Stillhithe's pools), no name, no
  dialogue. Give it a `collider` like any prop; no `float`/`wading` (validated). The character
  lineup lists figures as "(figure)".
- `"averts": {"if": <condition>, "radius"?: 6}` (Day 31, figures only) — while the condition holds and
  the player is within `radius` m (fading out over the next metre), the figure won't look at them: the
  shoulders (0.25 rad) and head (1.1 rad) turn to the side away from the player and the chin drops, coming
  on at 1.2/s (deliberate, not startled); none if the player is already behind them. Layered on the idle by
  `CharacterRig` (`avert_if`/`avert_radius`; it finds the player by the `player` group and reads
  `GameState.world` each frame; `step_avert` and `avert_aim` are public for tests). Validated: a figure, an
  `if` that reads declared flags, radius 1..20, no other keys. The fen's three Unmoored avert on
  `flag:fen_ember=bare`.

### Arrival events & act ends (Day 13)
- **Region `events`** happen on arriving in a region: after `main.load_region`, the first
  event whose `if` holds applies its `set` flags and plays its `dialogue` (waiting for any
  open dialogue first) — `RegionEvents.arrival/fire`. The validator requires `if`, a known
  dialogue, and a `set` that switches the event off (one of its flags read as `!flag:x` in
  the `if`), so every event fires once. An event that moves a many-valued flag on (Day 49:
  `hob_up_the_ladder` takes `thornwold_hob_ladder` from `going` to `up`) can't read it as
  `!flag:x`, so it also sets a one-time bool (`thornwold_hob_told_fifth`) and reads that. The ferry's horn (`ferry_horn`) lives on Shingle
  Point and Gull's Head, not Saltmarrow: you hear it on coming back from somewhere.
- **NPCs in several places:** an NPC may be placed more than once (any regions) only if every
  placement has an `if` (Pell: beach until `saltmarrow_ferry_arrived`, then the dock; Hob:
  the clearing until `thornwold_hob_came_in`, then the tally-house step — set by the landing's
  `hob_comes_in` event, Day 27, which needs the Ridge Light lit and Hob paid in either order). The
  conditions must be mutually exclusive, and since Day 38 the validator proves it:
  `Conditions.joint_witness(conditions, flag_defaults)` searches the values
  the conditions mention (each flag at its default, every named value, true, false and one unnamed
  value; quests inactive/done/active at each named stage or another; items 0, 1, each named count)
  for a state where two placements both hold, and reports it (`{"flag:x": v, …}`). Every term reads
  one key, so since Day 61 it searches key by key (linear; until then it tried the whole product
  and gave up past 65 536 states — answering "exclusive"). A flag condition may name several values
  (`flag:thornwold_bend=road|hearth`, Day 61), so one placement can cover outcomes that look alike. Since Day 44 a
  string flag with a `values` list (all of them have one) is tried at exactly those values, so
  the search is exact for them; true/false flags are still tried at true/false.
- **Prop variants (Day 44):** two **model** props of one *family* (the same first word of the file
  name — `gannet_hulk` / `gannet_hulk_named` / `gannet_hulk_bare`, `teeth_rock` / `teeth_mark`)
  within 0.6 m of each other on the ground plane are variants of one thing: the validator proves with
  the same `joint_witness` that no state shows two (two unconditional ones are a deliberate pair and
  skipped). Props of different families on one spot are overlays and may stack (the gold streak on
  the lit Heron, Dunstan's cord on the near Heron's sill). Name a variant's model after its base.
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
stays on Thornwold. (Day 59: the lane map replaced the per-lane sailing choices — see **The lane
map** below; the flag is still the ferry's position.)
**The fen lane (Day 29):** `lanes_ferry_at=fen` puts the ferry and Oda at Glasswater Fen's staithe.
Saltmarrow's placements now read `!…=thornwold` **and** `!…=fen` (one more `!` term per new
port — keep them exact negations). Oda offers "Sail north-about to Glasswater Fen." on Thornwold once
*A Light for Thornwold* is done (first sailing: the full scene, sets `fen_landed` via the fen's
arrival event; later: one line) and only "Take me back to Thornwold." at the fen — lanes run light to
light, so the fen connects to Thornwold only. The smoke walk never talks to Oda on Thornwold (the
bramble wall moves it on first), so `_sail_the_fen_lane` asks her for the fen **by option text**
(`_choose`) after the passes, walks the fen twice (Hesper starts *The Letting Post* on the first trip,
the post is answered on the second) and lets Oda sail it back. `test_fen_lane.gd` covers the rest.

**Corran's punt (Day 33):** a dialogue `travel` between two regions with a person who goes with you.
`fen_punt_out` says where Corran and his punt are: true → in `heron_mere` (the Heron's legs; no exits,
reached only by the punt), false → at his fen landing. His fen placement and punt prop read
`!flag:fen_punt_out`, the mere's `flag:fen_punt_out`; `corran.json`'s `start` jumps to the `mere` knot
while it is set. Both ways land on a `from_punt` spawn. In the smoke walk Corran becomes a mover on the
second fen trip (the far trap is a pickup there once asked; the walk takes pickups before movers), so
`_walk_the_heron` walks the mere (the skiff, the ladder, the glimpse, then Corran poles back) and has Oda
sail it back to Thornwold **by option text**. `test_heron_light.gd` covers the rest.

**Glasswater's burning (Day 35):** the burn lives in `heron_ladder.json` (the ladder object is the way
up: `start` routes by quest stage — `up_the_ladder` → `dry_day`/`climb`, `feed_the_heron` → `cradle`, done
→ `lit`), like `ridge_light.json`. Corran's Remnant can be asked for at the legs or the landing: his new
knots end on `back_to_hub`, which returns to `mere_hub` while `fen_punt_out` is set, else `hub` — reuse it
for any NPC who talks in two places. After `fen_beacon_burned=channels` "Pole me out to the Heron again."
goes to `no_channels` (two options with the same text and exact-negation `if`s). Both regions swap
`heron_light{,_near}` for `_lit` on `quest:a_light_for_glasswater=done`, thin their fog (overrides) and
duplicate their deep Greying rects at strength 0.45–0.5 (Stillhithe's ellipse has no `if`: it stays). The
smoke walk lights the Heron live on the second fen trip (`_light_the_heron`: Hesper's question, the punt,
the climb, Corran's cord, the burn, back by the light; the menu walk alone never gets there), so the end
state is always `channels`; `test_heron_burning.gd` covers the name path and the rest.

**The Heron lit, dressed (Day 36):** an NPC can have **two placements on one spot with different
`model`s** and exclusive `if`s (Corran with/without his cord, by `fen_corran_cord_away`). When a flag swaps
them mid-talk, `Region.refresh_conditional` now removes before it builds and hands the leaving actor's
turn-to-the-player and body yaw to its replacement (`NpcActor.take_over`), so the swap reads as the cord
going, not a jump. Prop flag **`over_water`** (model props; validated bool) copies every surface material
with `render_priority` 1 so it draws after the transparent sea (as the floating props' foam rings); the lit
Heron's `gold_streak` uses it and sits 8 cm over the water level (the swell is ±7 cm). Glb byte output of a
character re-export isn't stable (same size, different bytes): don't commit a rebuilt model whose script
didn't change. `test_heron_dressed.gd` covers the sill row, the coat, the cord, the placements, the
hand-over, the streak on open water and the validator.

**After the Heron (Day 37):** NPC **`names`** — `[{"if": condition, "name": "..."}]`, first match wins, else `name`
(`ContentDatabase.npc_display_name`). Used for the dialogue speaker label (`DialogueRunner.speaker_name`), the
"Talk to …" prompt and the Label3D over the head (`NpcActor._refresh_prompt`, re-read on every flag change; the HUD
re-labels a focused prompt when it changes). Dunstan is "The big man" until `fen_dunstan_met` (set on the line where he
says it, so the rest of that talk is already "Dunstan Tollen") and always after the `gull` burn. Validated: a list of
entries each with an `if` (known flags) and a non-empty `name`. Dunstan sits at the end of the long walk on
`quest:a_light_for_glasswater=done` (two placements, `dunstan_seated` / `dunstan_seated_cord` by
`fen_dunstan_word=mara`); his lantern is a **halo** on the last board (not a light — the budget), and the fen's arrival
event `fen_lantern_for_after` (after the burn, any way in) starts *For After*. The smoke walk finds him after
`_light_the_heron` (`_find_dunstan`); `test_after_the_heron.gd` covers the rest.

**The east lane (Day 40):** `lanes_ferry_at=wrackholm` puts the ferry and Oda at Wrackholm's jetty (Saltmarrow's
placements gained a fourth `!` term). At the lit fen Oda's "Where does the lane go from here?" sets `fen_oda_lane_asked`;
"Sail east-about to Wrackholm." needs that **and** `fen_dunstan_met` ("done here"). The first sailing (`sail_wrackholm`)
is the full scene and honours `fen_dunstan_mara` / `fen_dunstan_rule`; the region's arrival event sets `wrackholm_landed`
and starts *A Light for Wrackholm*. From Wrackholm Oda only runs back to the fen. `test_wrackholm.gd` also proves Oda and
the ferry stand in exactly one region for every value of `lanes_ferry_at` — **add the next port's value to that test**.
The smoke walk sails it from the fen after `_light_the_heron` (`_sail_to_wrackholm`: the lane asked, the sailing, the
arrival scene, a region walk — board, Wenna, Jory, then Oda sails it back), before Oda takes the walk on to Thornwold.

**The Teeth (Day 42):** a region reached on foot only at low water, through a **gated exit** (Wrackholm's spit
→ `wrack_teeth`, `requires` `flag:wrackholm_tide=low` and `flag:wrackholm_teeth_marks`) rather than a dialogue
`travel`, so the smoke walk's region pass never wanders onto it; the way back is an object (`teeth_way_back`) whose
dialogue sets the tide in again and `travel`s to Wrackholm's `from_teeth` spawn (mid-yard: the spit is all fog, and
spawns must be clear). **`wrackholm_tide`** ('' / `low`) is a story flag, waited down at the spit's end
(`teeth_spit`); a real tide system (Milestone 2) should drive it, keeping those values. Wrackholm shows the ebb with
three off-spit slabs (`teeth_rock` bare / `teeth_mark` once the white is back, shape `rock`) — its water level never
changes. In `wrack_teeth` the marked slabs sit at y −0.38 (snapped) so the slab's top (`TEETH_TOP` 0.42 in
`build_wrackholm.py`) stands 4 cm proud of the reef road: no collider, the player walks over the white. The Wrack is
placed origin 2 m under (`snap: false`, `rotation_y` 90 turns its door east); its sill (stack top 3.5 m) meets the ramp
path's 1.45 top — `tests/test_the_teeth.gd` mirrors `WRACK_DOOR` and checks it. Narrow reef `path`s need a feature
`ragged` ≲ 0.35 and width ≥ 3 m or the coastline wobble cuts them into steep islands (check with `terrain_map.gd`).
The smoke walk sails east-about a second time (`_cross_the_teeth`) and leaves the tide down so the final gate check
finds the exit open; `_check_gates` now travels back to where it started (Wrackholm's gate sorts after Saltmarrow's).

**The Wrack's burning (Day 43):** the same shape as the Heron's: Remnants are made *on purpose* by their holders in
dialogue (`wennas_answer` from Wenna; `white_lead_pot` from Jory — or both from Wenna's `feed_together` knot when Jory
has gone up; Jory refuses outright when told the Keepers put the Spire out), plus one taken off a prop: Wenna's leave
(`wrackholm_board_leave`) lets the `gannet_board` inspectable prise the board off (`wrackholm_board_taken`, which also
swaps `gannet_hulk` → `gannet_hulk_bare`; putting it back sets it false). `wrack_light` weighs and burns in the cradle
(`wrackholm_beacon_burned` answer / board / white) and completes the quest; every Wrack/greying/light/fog entry in both
Wrackholm regions has a `!quest:a_light_for_wrackholm=done` dark twin and a `=done` lit twin (lit model with `light` and
`halo`, greying areas thinner and lower). Unburned Remnants go back by dialogue (Wenna, the transom, Jory). After the
lighting Wenna's hub runs the horn (`wrackholm_horn_sounded` → `answering_horn_open`), the Book
(`wrackholm_book_opened`, and `wrackholm_lamp_name_read` if `wrackholm_book_told`) and the oath (`wrackholm_sworn`).
`tests/test_wrack_burning.gd`; the smoke walk burns Wenna's answer (`_burn_the_wrack`) between the lantern room and the
last ebb, and reads conditional props by model file (`_shown_model`, reaching into `Region._conditional`).
After the fen lane the smoke walk **carries the Lamp's name home** (`_carry_the_name_home`, Day 48): back through the
bramble wall and up the ladder by their `travel` choices, the name said outright, down by the exits (`_take_exit`),
Oda's lane home to Saltmarrow, Aldous asked for Wynn's sake, and the Wrens' brazier checked raked → laid.

### The lane map (Day 59)
`data/lanes.json` is the chart: `ports` (`id` = its value of `lanes_ferry_at`, `name`, `light`, `lit`
and `known` conditions, `region`, `map` [x, y] in 0..1 from the top-left, `passage` knot), `landmarks`
(drawn only — Cindermoor, dark), `lanes` (`between` two ports, `name`, `open` / `sailed` conditions,
optional `closed_text`, `knots` {destination port → knot}), `dialogue` (the ferry's: `oda`) and `home`
(the port `''` means). `Lanes` (scripts/core/lanes.gd) is the logic: `current_port`, `known_ports`,
`known_lanes`, `route` (BFS over open lanes) and **`voyage(db, state, to)`** → `{ok, knot, route}` or
`{ok: false, reason}`:
- a neighbouring port plays that lane's knot (`sail_fen`, `back`…; the first sailings redirect
  themselves to their arrival story as before);
- a longer voyage needs **every lane on the way `sailed`** (a new lane is sailed from its near end, with
  its story) and plays the destination's `passage` knot (`passage_wrackholm`…: one line per start
  port, "puts in only long enough to take on water", then `set` + `travel` like any sailing).
In dialogue an **option with `"lane_map": true`** (Oda's "Where can you take me?", at every port once
*Across the Grey* is done; the first crossing stays the "Cast off for Thornwold." option because it
ends Act I) makes `DialogueRunner.choose` return `{"type": "lane_map"}` and wait; `sail_to(port)` jumps
to `voyage`'s knot, and `sail_to("")` (or a voyage the ferry won't make) re-offers the same choice.
`DialogueUI` hides its box and shows its `LaneMap` child (scripts/ui/lane_map.gd: a drawn chart, a
flat Button per known port, info line for the focused port, legend, "Not yet."; Esc/B or "Not yet."
turns back, interact/accept/click on a port sails). Validator (`_validate_lanes`): port ids are
values of `lanes_ferry_at`, real regions, map points in range, every lane/passage knot exists and
(through its gotos) sets `lanes_ferry_at` to its port and travels to its region; lane knots count as
reachable in the ferry dialogue; `lane_map` options only in that dialogue. Tests: `play_dialogue`
picks `"@<port>"` on the map; `test_lane_map.gd`. The smoke walk sails with `_sail(ui, port)`, its
region walker sails to the first neighbouring port (as the old option order did), and after the east
stair it takes the long passages Saltmarrow → Wrackholm → Saltmarrow live.
**The chart in the journal (Day 65):** the journal's third tab (**L**, rebindable; the pad's **LB/RB** step
between tabs — `tab_left`/`tab_right`, pad-only actions) shows the same `LaneMap` built `read_only` with a smaller
`chart_size` (`JournalUI.CHART_SIZE`): no frame, no "Not yet.", focus starts where the Slow Mercy lies, pressing a
port only tells of it ("Oda can sail you there." / why not), Esc is the journal's. It shows once `chart` in
lanes.json holds (`Lanes.chart_known`; `quest:across_the_grey=done`), else "No chart yet." The tab labels carry
the bound keys (none on a pad). Debug: `--journal=journal|satchel|lanes` opens the journal on a tab (reads an
arrival scene through first, like `--lane-map`). Tests: `test_lanes_tab.gd`; the smoke walk presses L, LB/RB and,
back at Saltmarrow after the east stair, checks the chart's ports and that pressing one sails nowhere.
**A new port:** add it to `lanes_ferry_at`'s `values`, a port + lane in lanes.json, the lane knots and a
`passage` knot (lines for each start port 2+ lanes away) in `oda.json`, and the ferry/Oda placements.

**Adding a port** (Day 62, Kindleby): a `ports` entry and a lane in `data/lanes.json`; a value of `lanes_ferry_at`
in `data/flags.json`; the region (Oda + `ferry.glb` placed `if flag:lanes_ferry_at=<port>`, and **Saltmarrow's
placements negate it** — Saltmarrow's ferry shows for `''` too); in `story/oda.json` a `start` redirect, the port's
menu knot (with the "word on the water" options and the map), the lane's two knots, the port's `passage` knot (a line
per start port 3+ lanes away) and a start-from-here line in every other `passage_*` knot that a route can now begin at
the new port; tests: the port lists in `test_lane_map`, `test_wrackholm` (one Oda, one ferry) and
`test_word_on_the_water`.

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
  `Region._refresh_greying` re-cuts every shown layer when the set of active clear areas changes.
  **The re-cut fades (Day 23):** `GreyingFog.recut(new, old, animate)` builds one mesh carrying
  both cuts (UV2.x = alpha under the old lights, UV2.y = under the new; COLOR.a = new too, 8-bit)
  and keeps every triangle either cut needs; the shader mixes them by `recut`, tweened 0 → 1 over
  `FADE_SECONDS` (4 s), then the mesh is rebuilt with the new cut only. Region loads re-cut
  instantly. The *gameplay* depth (ember drain, `Region.greying_depth`) eases with it since Day 54: whenever the active
  areas change live, it lerps from the old areas' depth to the new over the same 4 s (`_greying_blend`, ticked in
  `Region._process`, which pauses with the tree; a region load settles at once). Validator: `clear` must be a bool; the worst case
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
- **Region `water` (Day 30)** tunes the shader per region, every key optional (`WaterBuilder.SETTINGS`,
  validated ranges; `note` allowed): `swell` (× wave height, 0..2), `wash` (the broken foam lines,
  0..1), `foam` (× shore foam width, 0..2), `mirror` (0..1: a glancing look takes the `sheen` colour,
  glossier), colours `shallow`, `deep`, `sheen` (palette or #hex). No block = the old sea exactly.
  Glasswater Fen: `{swell 0.15, wash 0, foam 0.5, mirror 0.6, shallow pine, deep ink, sheen silverfog}`.

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
  "paint": [{"rect"|"ellipse"|"path": ..., "width": 2, "color": "driftwood", "if"?: cond}],  // first wins
  "piers": [{"rect": [x0,z0,x1,z1], "deck": 0.275}],  // walkable decks over water (absolute y)
  "note": "free text"
}
```
Each feature's influence is 1 inside and smoothsteps to 0 over `falloff` metres; a small
falloff makes cliffs (coloured `cliff` above `cliff_slope` rise/m, unwalkable above ~0.84).
Triangle colour order: paint → cliff → seabed (below water) → shore band → ground.
**Conditional paint (Day 26):** a paint zone may carry an `if`. `TerrainField.paint` holds the
zones in effect (unconditional ones until `select_paint(world)` runs; `all_paint` is the data);
`Region` selects before building the ground and, in `refresh_conditional`, re-selects and
`TerrainBuilder.recolor`s the ground **mesh only** (collider and heights never change) when the
set changed. Since the first matching zone wins, put a conditional override **before** the zone
it covers (the woods' grey patch under the fourth waymark sits first, over the clearing's green).
`land` can't be conditional (the validator says so) — ground shape is fixed per region.
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
  figure in its `color`. `idle` = `breathe` (default) | `mend` | `rake` | `chisel` (Day 26: the
  Lamp — bent over the bench, two taps of the left hand per `CHISEL_PERIOD` 3.4 s then a rest,
  the head turning aside to listen about once in three beats; `chisel_tap`/`chisel_listen` are
  static so tests can read the beat). While talking, an NPC's body
  eases round to face the player and back to its placed `rotation_y` after (the Wakebearer
  turns to it too); `"faces_player": false` opts out (Hesk keeps mending). Day 28: `sit` — a
  seated model resting (legs never swing): breathing, thumbs creeping along whatever is across the
  knees, and late in every `DOZE_PERIOD` (11 s) the head sinks (`sit_doze`), holds and comes up
  with a start (`sit_start`). Day 32: `bottle` — Aldous seated (legs never swing): the bottle turning
  in his left hand on his thigh, the right hand rubbing his knee, and late in every `BOTTLE_PERIOD`
  (14 s) a swig (`bottle_swig`, 0..1: up 0.9 s, drink 1.4 s, down 1.2 s) — the bottle arm comes up
  and in (`SWIG_LIFT`/`SWIG_IN`), the head goes back (`SWIG_HEAD`), the shoulders lean back a little.
- **Placement poses (Day 28):** a region's NPC placement may carry its own `model` and `idle`,
  which override the NPC's for that spot (`Region.placed_npc_data`; validated like the NPC's). Hob
  stands raking (`hob`, `rake`) in the clearing and sits on the camp bench (`hob_seated`, `sit`).
  Aldous sits on his plank bench by the Wrens' steps (`aldous_seated`, `bottle`; Day 32) — the NPC
  keeps the standing `aldous` for anywhere else he might be placed.
  The character lineup shows such models after the NPCs as "Name (model)".
- `data/game.json` also takes `player_model` (the Wakebearer character scene) and `act_ends`.
- Item: `id, name, description, kind (remnant|key|misc), color?, future?`
- Quest: `id, title, description, stages: [{id, text}], giver?, region?, future?` — first
  stage is entered on `quest_start`. `future: true` silences the "never completed" warning
  for a quest whose ending isn't written yet (e.g. *Across the Grey*, the Act II bridge).

### Flags (`data/flags.json`)
Every flag must be declared with a `description` (and optional `default`). The validator
errors on undeclared flags and on declared flags nothing sets; it warns on flags nothing reads
unless marked `"future": true` (payoff not written yet) or `"read_by_code": true`.

**String flags list their values (Day 44):** a flag whose `default` is a string must declare
`"values": ["", "answer", "board", "white"]` — every value it can take, the default among them
(`ContentDatabase.flag_values` / `flag_value_error`). The validator errors on a `set` (dialogue,
pickup, event), a `flag:x=v` condition or a scenario that uses a value not in the list, so a typo
can't silently make a condition never hold. Adding a new outcome = add it to the list first.
True/false flags have no list.

### Conditions
String or array of strings (AND). Prefix `!` negates.
`flag:<id>` (truthy) · `flag:<id>=<value>` (string compare; `flag:x=` means empty) ·
`flag:<id>=<a>|<b>` (any of them, Day 61; the validator checks each against the flag's `values`) ·
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
  Nothing may follow a step that always leaves its knot — an unconditional `goto`/`end`, or an
  unconditional `choice` whose every option jumps/ends/opens the lane map with one option always
  offered: the validator reports "step N never plays" (Day 61; Day 60 lost a line of Hesk's that way).
- Effects: `"set": {flag: value}`, `"quest_start": id`, `"quest_stage": [id, stage]`,
  `"quest_complete": id`, `"give_item": id`, `"take_item": id` (+ `"count": n`).
- `"travel": [region_id, spawn?]` (Day 17) — when the dialogue **closes**, the player is moved
  to that region/spawn (`DialogueRunner.pending_travel` → `DialogueUI._close` →
  `GameState.travel`). Put it on the last step so the scene finishes first; the destination's
  arrival `events` then fire as usual. Validated: known region and spawn. Used by Oda's ferry
  (`sail`, `sail_again`, `back` in `story/oda.json`).
- An option's `"lane_map": true` (Day 59) opens the lane map instead of a goto — see "The lane map".
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
footprint). **The old road kit (Day 53):** `tools/blender/build_old_road.py` (same kit dir, imports `build_woods` for its
lumps and the waymark) — `northing_cairn` (≈ 1.7 m across, the basket's rim at 2.5 m; the boat-lantern's arm and hook
reach out on -Y, the carved face-stone low on -Y), and two **overlays modelled at their place on it**, placed with the
cairn's own `position`/`rotation_y` and swapped by `if`: `cresset_coals` (charcoal glowing coal-red in the basket; give
it `smoke` at [0, 2.3, 0]) and `cresset_lantern` (a Keeper's lantern on the hook, emissive kindle, glass centre
[0, 1.69, 0.78] Godot model space = its `halo`; `test_the_northing.gd` pins the halo). Different families from the cairn
("cresset" vs "northing"), so they may stack on it; the two overlays are one family and must stay exclusive.
`waymark_rake` = the bare waymark with a clamp rake driven into its cairn beside the post. Ottie's character models
(`build_characters.py`): `ottie`, `ottie_cap` (standing, fire iron) and the seated `ottie_home`, `ottie_home_cap`,
`ottie_home_unshod`, `ottie_home_unshod_cap` (boots or sacking feet × cap or bare head). The seated ones are placed on
the cold hut's log seat in the woods at (-8.54, -58.85), `rotation_y` -63, `idle` `sit` — the seat is part of the hut
model, so moving the hut means moving them.
**The Old Road (Day 53, `thornwold_old_road`):** an inland ridge region built like the ridge top ("a drop at the edge"):
`base` -8, the spine one `path` land feature 11 m wide climbing 0 → 2 m north, ending in a knoll ellipse; the drop on
both sides is walkable-but-unreachable low ground. Reached from the ridge's NE corner by an exit gated on
`quest:a_light_for_thornwold=done` (the ridge top's reachable plateau stops short of the spine's waymarks; the spine
there rises 4 m in 2 m); coming back lands at the ridge's `from_old_road` spawn inside the lodge's coal pool (the only
unconditional clear ground near enough; the ridge's worst-case fog covers everything else). Greying: one 0.45 fleece
over the spine, a deep bank over the north cliff, and an unconditional clear pool round the Northing (something always
burns in the basket). The distant lit Ridge Light is the same far-prop trick as the woods' skyline (`snap: false`,
halo size 14). Its arrival event is gated on the Ridge Light lit (debug teleports and `_check_gates` must not fire it).
**The far shore kit (Day 55, `build_old_road.py`):** `steps_foot` (the bottom flight of the Keepers' steps cut up a
rock buttress: ten steps rising 0.26 m each along +X from the origin, the buttress behind on +Y, an iron rail on -Y; placed
at `rotation_y` 180 against the cliff, so the flight climbs toward -X), `boat_stage` (the dressing on the **end** of a
stone quay whose walkable top is the region's ground: kerbs, a bollard with the mooring ring, a lantern post with its
bracket reaching out on -Y; origin = the end's centre, the quay running back on +Y; placed `snap: false` at the quay's
deck height) and its overlay `stage_lantern` (the Ridge Light's lantern on the bracket's hook, glass centre
[-0.85, 1.87, 0.95] Godot model space = its `halo`; `test_far_shore.gd` pins it; family "stage", not "boat", so it
stacks on the stage), `drift_fire` / `drift_fire_out` (one family, exclusive) and `drift_shelter` (a lean-to, open on
-Y). Characters (`build_characters.py`): `wenna_coll` (seated on a folded sack, the `sit` idle; not `wenna`, who is
Wrackholm's lane-warden), `wenna_coll_lantern`, `wenna_coll_rake` (Day 58: stooped at the clamp, the rake a static `Stool` extra on the ground;
the skirt goes in `LegL` so the waist stoop doesn't swing it), `abe` (hands on hips), `tolly` (arms folded), `tolly_lantern`;
`_held_lantern(body, side)` is the shared lantern-by-the-bail for standing figures. **`_bent_arm(body, side, hand, out, …)`**
(Day 58) replaces base_body's straight arm with one bent at the elbow (two 0.27 m segments) reaching a hand point given in
the *posed* body (after `torso_rest`), the elbow bowing along `out` — for poses a rigid arm can't make (Abe's fists on his
hips, two hands on one pole). Leave `arm_rest` at zero for such arms; the idles still add their small swings.
**The Far Shore (Day 55, `thornwold_far_shore`):** a sea region under a 14 m `rect` cliff on +Z (its top walkable but
never reachable, like the ridge's drop), two ellipse buttresses closing the beach's ends, and the boat-stage as a `path`
land feature 2.6 m wide at 0.7 m (painted pale) running out north. The Greying is one 0.6 "lid" over the sea and the
shingle that fades out under the cliff (`rect` to z 0.5, falloff 4), so the spawn at the steps' foot is clear with no
lantern; the Ridge Light's lantern on the stage (`carried`) and Hob's (The Fifth, `gone`) cut conditional pools. The way
down is the old road's `keepers_steps` inspectable (a "Go down" choice that `travel`s, offered once
`thornwold_northing` is set); the way back up is an ordinary exit at the steps' foot to the old road's `from_far_shore`
spawn inside the Northing's clear pool. The arrival event is gated on `!flag:thornwold_northing=` (debug teleports).
Hob's shore and clearing placements for `gone` also read `flag:thornwold_hob_came_in` — `gone` implies it, but the
NPC-in-one-place check can't know that, and the woods' raking Hob reads `!…came_in`.
**Coll's Hearth (Day 57, `thornwold_colls_hearth`):** a closed hollow (banks on all sides; the west bank is "the trees
between here and the straight road") reached only by `travel` — Wenna's "Show me." at the woods' first waymark, then the
woods object `woods_old_bend` (shown once `thornwold_bend` is past `morning`) — with an ordinary exit back to the woods'
`from_bend` spawn inside the first waymark's clear pool. **"Next morning" without a clock:** `thornwold_bend=asked` is
answered by a woods arrival event (`woods_first_light`) on the player's *next* arrival; an event must switch itself off
with a `!flag:<bool>` term, so it also sets the one-time `thornwold_bend_first_light`. Wenna's placements across the
woods, the far shore and the hearth stay exclusive because every new one also reads `flag:thornwold_far_shore=up` (the
shore's reads `!…=up`) and a distinct `thornwold_bend` value. The `road` outcome's clear areas are conditional, so the
validator's worst case (no conditional lights) still had to pass with the bend in fog: the hearth and the ruts' entry
are unconditional clear pools ~6 m apart through 0.7 fog.
**The way up (Day 24):** `ridge_steps_lower` / `ridge_steps_upper` — one flight of
the Keepers' log stair each (risers + pegs, rope rail on stakes, the ember cut in the bottom
stake). A flight climbs along its **+X from the origin (the low end, on the ramp's centreline)
by exactly the rise its region `path` gives it** (`STAIR_FLIGHTS` in the script: lower 1.85 m
over 7.5 m, upper 1.6 m over 6 m, the upper placed at `rotation_y` 180 with its rail built on
+Y so it faces south too); `test_ridge_way.gd` mirrors those numbers and checks the ground
under each placed flight rises the same, so **change the script, the path and the test
together**. `keeper_ladder` (feet at the origin, leaning back toward Godot -Z, ≈ 3 m up) and
`keeper_ladder_fallen` (flat along X), `waymark_cap` (the bare waymark with a collier's cap on
its hook), `sack_dropped` (split, coal spilled toward -X). **The ridge, dressed (Day 26):**
`ridge_outcrop` (≈ 3.4 × 2.4 × 1.6 m: slabs on edge along +X, heather in the lee on -Y;
collider ≈ [3.2, 2.4, 1.4]) and `ridge_outcrop_low` (a broken shelf ≈ 0.7 m high), `heather_silver`
(a ~1.6 m patch of five silvered tufts; no collider), `waymark_tumbled` (the cairn spilled toward
-X, the post leaning 35° the same way, its arm in the heather). `collier_hut_cold_cap` = the cold
hut with Ottie's cap on the seat by the boots (same footprint; shown by flag in place of
`collier_hut_cold`). **The Ridge Light, lit (Day 28):** the lit tower's horn panes use `build_dressing.horn(name,
alpha, glow=…)` — an emissive palette material with alpha (glTF `alphaMode: BLEND`, faint emission
so it doesn't wash to white) — and the cradle holds a fire (coal-red coals, five ember tongues
leaning in, a kindle heart; all emissive), the rack's one lantern lit; the cold build is unchanged.
Keep the lit build ≤ 16 materials (the kit cap): reuse `kindle` glow rather than a new shade.
`build_thornwold.py log_bench`: a split-log bench 1.3 m along X, **seat top 0.44 m** (a seated
`Body`'s seat; Hob's camp seat, and Aldous's bench later), front at Godot +Z; no collider (the NPC
sitting on it has one). `build_characters.py hob_seated`: Hob as a seated Body with the rake
across his knees in the static `Stool` part.
**The fen, dressed (Day 30):** `build_fen.py` — `staithe` and `boardwalk` follow the dock's
replacement rule (2 × 6 m along Godot Z, deck top 0.675, placed at y -0.4 → the 0.275 pier deck; like
the dock they reach below their origin). The staithe's eight posts each carry a whittled gull facing
-Y (Godot +Z, out to sea); the boardwalk has nothing over its deck and its piles stand at
`BOARDWALK_PILES` (mirrored in `test_fen_dressed.gd` and the region's `wading` rings). `plank_path`
(1 × 3 m along Z, ~7 cm, no collider) lies on the ground; `punt` (origin at the bottom, place at the
water level − 0.15 with `float`), `eel_traps`, `alder_snag` (same trunk footprint as `pine_snag`),
`reed_bed` (3.2 m along X, no collider; place on the shoreline, ground ≈ water − 0.1). Characters:
`unmoored_shawl` / `unmoored_coat` are seated Bodies with their seat (tussock / upturned basket) in
the static `Stool` part — figure props with the `still` idle.
Note `bp.prism` creates its object through the data API and does **not** make it
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
  Torso             pivot at waist; may have a rest rotation (a stoop: Body `torso_rest`, Day 52 — with Body
                    `crouch` the standing legs bend at a knee forward of the hip and the hips drop)
    Head            pivot at neck
    ArmL, ArmR      pivot at shoulder; held items are part of the arm; may have rest rotation
  Stool             optional static extras
```
The rig stores each part's rest transform and applies small offsets on top, so rest poses
(Aldous's stoop, Hesk's hands over the net) are authored in Blender. `test_characters.gd`
checks every NPC/player model has the parts with the right parents. New character: add a
`build_<id>()` to the script, run it, set `model` in the NPC's JSON. A model built ahead of its
NPC (the Lamp, `lamp.glb`, Day 24) is still rig-checked (`test_characters.gd` takes every .glb in
`assets/models/characters/`) and shows at the end of the lineup scene as "(unplaced)".
Blender gotcha: bake rotation/scale into each primitive before joining (the script's
`_finish` does) — joined objects keep only the first object's transform and the rest pose
then overwrites it (this flipped every arm upward on the first try).

## Settings (Day 19)
`GameSettings.current()` (loaded and applied by `GameState._ready`) holds the player's
settings; the pause menu's **Settings** and **Controls** pages edit it and save **as they
change** (Day 23: every toggle, rebind, reset and keyboard slider step; a mouse-dragged slider
once, on `drag_ended`) and again on leaving.
`user://settings.cfg` (ConfigFile) — never in save games:
```
[audio]    Master/Music/Ambience/Effects/Voice = 0..1 (linear; 0 mutes the bus)
[display]  text_scale = 0.75..2.0   (menu presets 0.85 / 1.0 / 1.25 / 1.5 → UiTheme)
           text_speed = 0..400 chars/s (presets Slow 25 / Normal 50 / Fast 100 / Instant 0)
           window_mode = "windowed" | "fullscreen", vsync = bool   (Day 56; DisplayServer)
[camera]   sensitivity = 0.25..2.5, invert_x, invert_y   (Player reads them per event)
[pad]      stick_deadzone = 0.05..0.5 (default 0.2) → InputMap deadzone of the PAD_AXES actions
[keys]     <action> = "<key name>"   only rebound actions, e.g. interact = "F"
```
- **Audio buses** are created in code (`GameSettings.ensure_bus`, sent to Master) — there is
  no `default_bus_layout.tres`. Everything plays through them by name (see "Audio").
- **Rebinding**: each `InputSetup.REBINDABLE` action's first key in `BINDINGS` is its
  primary; rebinding replaces it, swaps with whichever action held the new key, and refuses
  Esc and the menu keys (pause stays Esc/P/Start). Default secondaries (arrows, Enter) stay
  unless another action claims them. `InputSetup.apply_keys` rebuilds the keyboard events;
  pad bindings are untouched (not rebindable yet). HUD/dialogue hints use `InputSetup.hint()`.
- **Pad prompts (Day 56)**: `InputSetup.pad_last` flips on a pad button or a stick lean
  ≥ 0.5 and back on a key or mouse click (`note_device`, fed since Day 61 by `GameState.note_input`
  on the root window's `window_input` — before any node's `_input`, so a modal handling the event
  still sees it — which emits `GameState.input_device_changed`; the HUD key hint, the journal's
  "close", the menus' "back" and the lane map's legend re-label on it). `InputSetup.back_hint()` is
  `[Esc]` / `[B]` for `ui_cancel`, whose built-in key event has no physical keycode for `hint()`. While it's set, `hint()` gives the action's pad button
  (`PAD_LABELS`: A / Y / Back / Start) for actions that have one, the key otherwise.
- **Dialogue text speed (Day 56)**: `DialogueUI` sets each line's full text and reveals it
  with `RichTextLabel.visible_characters` in `_process` (paused with the tree). Interact/click
  mid-line (`press_continue`) shows the rest, never skips; `advance()` (tests, smoke) always
  moves on. Choices and closing finish the reveal; `Screenshot` finishes it before capturing
  (group `dialogue_ui`). No timing gates: nothing waits on the reveal.
- **Display (Day 56)**: `_apply_display` is a no-op under the headless display server, so
  tests and CI only check the stored values; it leaves a maximized window alone when windowed.
- Loading clamps every value and ignores unknown/reserved/duplicate keys, so an old or
  hand-edited file never breaks the game. Tests use their own instance and path
  (`GameSettings.set_current`); the smoke test writes `user://smoke_settings.cfg`.
- Range controls don't emit `value_changed` outside the scene tree (Godot 4.7): tests that
  drive a menu slider emit it by hand.

## Audio (Day 46)
No audio files yet: every sound is a **procedural placeholder**, a small recipe in
`data/audio.json` `sounds` rendered at runtime by `SoundSynth` (`scripts/core/sound_synth.gd`;
16-bit mono, 22 050 Hz). Kinds: `noise` (white/pink/brown, low/high-pass, `swell` for the
sea, `gusts` for wind), `crackle` (fire), `tone` (harmonics, slide, vibrato, breath — horns,
voices, ticks), `chirps` (calls scattered over a loop — gulls, birds, frogs), `chime` (struck
notes — quest cues), `mix` (parts summed). One-shots take `attack`/`decay`/`release`;
`loop: true` renders a little long and crossfades the tail into the head (seamless; tests check
the wrap). Renders are seeded by the sound's id, so a sound is the same every run. To swap in a
recording later, replace the recipe with `{"bus": …, "file": "res://assets/audio/x.ogg"}`.

`SoundBank` caches rendered streams for the session and renders off the main thread
(`WorkerThreadPool`): `warm(db, ids)` starts renders, `is_ready` polls, `stream` waits or
renders on the spot. All ~40 sounds take ~3 s of CPU in total (8 MB); a region only warms what
it uses (ambience on arrival, prop sounds as it builds; every one-shot cue at startup).

`AudioDirector` (child of main, `main.audio`) plays it all through the Settings buses:
- **Ambience**: a region's `"ambience": [{"sound", "volume" 0..1, "if"}]` layers (each must
  loop), faded in/out over 1.6 s on arrival and when the story changes them; a layer shared
  with the last region carries on. The world sounds different after a burn: gulls come back
  to Saltmarrow and Shingle Point once the Gull's Beacon burns (and the headland's wind
  drops), birds to Thornwold, frogs to the fen, gulls to Wrackholm and the Teeth.
- **Prop sounds**: a prop's `"sound": {"id", "offset", "range", "volume"}` is a positional
  `SoundEmitter` (AudioStreamPlayer3D) that starts once rendered — every lit beacon's `fire`,
  the charcoal clamps' `embers`.
- **Footsteps**: `CharacterRig.footfall` fires twice per walk cycle (in step with the legs);
  `Player.stepped` (on the floor only) → `Region.footstep_surface(pos)`: a pier deck or
  anything built ≥ 0.2 m above the ground is `boards` (or the region's `footsteps_raised` —
  the Teeth's slabs are `stone`), shallow water `wade`, else the region's `footsteps`
  (`audio.json footsteps.surfaces` maps each surface to a sound).
- **Voices**: `DialogueUI.line_shown` → `speak()`: one blip per three words (1..6) in the
  speaker's `voice` (`{sound, pitch}` on the NPC; `player_voice` in audio.json; the narrator is
  silent), each a little off-pitch. A new line cuts the last one off.
- **Story sounds**: a dialogue step's `"sound": "<id>"` (an effect, one-shot only) — the
  ferry's horn (`horn_far`), the answering horn (`horn_near`), each beacon catching (`kindle`), the ember's single knock
  (`ember_knock`, Day 47) where Aldous can't find the seventh novice's face.
- **Cues**: `audio.json events` — quest started/updated/done chimes, an item gained, a tick
  on every button press (any `BaseButton` added to the tree) and on focus moves.
- **The Greying**: a low-pass on the Ambience bus closes toward `greying.muffle_cutoff` with
  depth, the ember's heartbeat (`greying.heart`) comes up under it, and `turn_back` plays when
  the fog turns the player back.
The validator checks every recipe (kind, bus, numbers, length ≤ 20 s, colours, mix parts),
every sound named anywhere (regions, props, NPC voices, dialogue, footsteps, events), that
layers and prop sounds loop and dialogue sounds don't, and warns on a sound never played.
`main.audio.history` lists recent one-shots (the smoke run checks footsteps on the dock,
Pell's blips, the Greying's muffle and heart, the turn-back, the gulls back on the headland).

**Quitting:** a sound still playing at the instant the process ends shows as "N ObjectDB
instances were leaked at exit" (the audio server never drains its playback list; a player
stopped a few frames earlier doesn't leak). The menus' Quit and the smoke run go through
`AudioDirector.quit_game(tree, code)` (stop everything, wait 3 frames, quit); a bare
`--quit-after` launch still prints the warning — benign, a warning not an error.

Listen to the sounds: `$GODOT --headless --path . -s res://tools/debug/export_sounds.gd -- /abs/dir [ids…]`
writes each as a .wav (never commit them).

## Save format
`user://saves/<slot>.json`: `{version, saved_at, region, spawn, player_position, world:
WorldState.to_dict()}`. Bump `SaveSystem.SAVE_VERSION` on breaking changes and add migration.

## Testing
- `tests/test_content.gd` — content loads, all references valid, every dialogue terminates,
  validator catches deliberately broken links.
- `tests/test_polish_eight.gd` — (Day 61) `flag:x=a|b` conditions (parse, evaluate, joint_witness, the validator checks
  every alternative), Wenna's single rake/seat placements, joint_witness with no state limit, steps that never play,
  the back hint following the device in the journal, title menu and lane map.
- `tests/test_bend_in_the_road.gd` — (Day 57) *The Bend in the Road*: asking Wenna (home from the far shore) starts it;
  the next woods arrival is first light (once; she's by the first waymark); the fork's talk; "Show me." travels to Coll's
  Hearth (arrival once; cold hut, spent clamp, bare waymark; the way back to the woods' `from_bend`); the clamp and her
  hearth talk; **road** (two more clear areas, the waymark lit, the fire in, Hob and the BEND stick) and **hearth** (her
  lantern by the door, the fog as it was, Hob, no BEND); the boots path; Hob gone and home; Hob's hut lantern. The smoke walk
  takes it live (`_walk_the_bend`: ask, down to the landing and back through the wall, show, road, back along the ruts).
- `tests/test_far_shore.gd` — (Day 55) *The Far Shore*: the steps go down only with a light at the Northing (and
  start the quest); the arrival scene once, never on a debug teleport; who waits on the shore (the three, Ottie if he
  carried the lantern down, Hob if he went; the stage's lantern); meeting Wenna (Ottie beside her, the road that lies, the
  bollard's day-strokes, the Drays, Aldous's "put out"); come up (the shore empty, the fire raked out, the lantern left
  for the boat, the three home in the clearing, Ottie in his boots, the Lamp breaking the warm side of the coal, Hob and
  the board on the salt-row and stayed paths); by the Northing's light; wait (they stay; asked again later, up); Hob gone
  and home; the boots path (strangers to Hob); the kit (glow only where it burns, the stage lantern's halo). The smoke
  walk takes the far shore live after hanging the Northing's lantern (`_walk_the_far_shore`: down, Wenna, up).
- `tests/test_walk_back.gd` — (Day 51) *The Walk Back*: the models; not before the Wrack is lit, then once (Dunstan
  standing on the long walk, the last board's halo gone); walking him in (wait, walk, the cupped ember opened just this
  once); Hesper won't hand the name over, he asks himself (the gull burn, her own name burned); home (his boat gone
  from the fen, his stool by Mara's door, the dock's second rowboat, Mara once; the stranger and the second cup);
  "yours to choose" is home; stay (the first two boards turned half round in place, the gull stays the player's).
  The smoke walk takes it live after the Teeth (`_walk_dunstan_back`: walk in, name, stay). Day 52: the `stayed`
  Dunstan is `dunstan_turning` (rigged, the torso bent 0.6–1.1 rad, lower than standing, the lantern's glow on `Stool`).
- `tests/test_polish_six.gd` — (Day 48) **no model prop stands wholly under the sea** in any region (its top, placed as
  `Region.place` does from the model's mesh bounds × `scale`, must clear `water_level` by 2 cm: an "awash" rock breaks
  the surface, reeds stand in the shallows, not 1.6 m down). It loads every model, so it lives in the tests rather than
  the validator (which runs at every debug start). Also the Teeth's road rocks on the road's shoulder, and the title
  screen's name (`UiTheme.GAME_TITLE`, 64 px × the text scale).
- `tests/test_wrack_burning.gd` — Wrackholm's burning (Day 43): who gives what (Wenna; the yard's leave for the
  board; Jory, never to a Keeper's fire; the two together), each burn and its aftermath, the lit Wrack in both regions,
  the horn (it takes two), the Book, the oath, unburned Remnants returned, the kit variants.
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
  reset asks twice, saving per change, a drag saving once). The smoke test rebinds the journal with a real key press.
- `tests/test_title_screen.gd` — Day 41: which launches open on the title, Continue = the latest
  save (quicksave counts, unreadable skipped), the title's pages (shared Settings/Controls/Load,
  Esc page by page, the name only on the main page), "Return to title" asking twice on the pause
  menu and the act-end card. The smoke run starts from the title (New game) and, near its end,
  returns to the title from the pause menu and Continues into a slot it saved.
- `tests/test_polish_two.gd` — Day 23: the fog re-cut mesh carries both cuts (and keeps the
  pool's triangles while fading either way), the fog node's animated vs instant re-cut, the
  "[E]" prompt re-labelling on a rebind, inspectable glints (default/offset/opt-out, distance
  fade, sane heights, validator).
- `tests/test_ridge_way.gd` — Day 24: the way up the woods' north bank (kit models small; each
  stair flight's rise matches the ground under it, step by step; the landing reachable and the
  ridge top not; ladders stand/lie; the colliers' cap and sack by the stair) and the Lamp's
  model (one glowing surface, the lantern, on the right arm).
- `tests/test_ridge_top.gd` — Day 25: standing and climbing the ladder (an inspectable `travel`),
  the ridge layout (spawns in lantern light, deep fog between, the Lamp in the coal's pool, the
  ladder's head at the lip, the woods below unreachable, climbing down lands clear), the arrival
  scene (only after the ladder), the Lamp's hub (name, coal, ladder, Ridge Light) and Aldous per
  confession, *A Lantern for the Stair* three ways (sliver / the fourth mark's lantern moved — its
  pool closes and Hob notices / refused), the stair's conditional pool, Ottie's cap to Hob.
- `tests/test_thornwold_burning.gd` — Day 27: the Lamp sending the player to Hob and the camp
  (`feed_the_light`); Hob's boots and Bram's salt row as Remnants (kept/given, Bram only once Hob is
  paid), the cold hut's three variants by flag; each burn (weigh/refuse/confirm, what Hob and the
  board forget, the unburned Remnant returned); the island lit (cold → lit tower in both regions, the
  ridge's light vs the woods' halo, fog/light overrides in all three regions, the woods' fog leaning
  back but staying); Hob's daylight arrival event (only paid, once, either order) and his move to the
  camp; Bram, Pell, Oda and the Lamp after (the stair's sliver showing); the `thornwold_lit` checkpoint.
- `tests/test_greying.gd` — area depth/falloff, Gull's Head fog leaning back after the burn,
  EmberMeter drain/refill/emptied, the ember-cost map, the fog layer mesh, validator checks
  (malformed areas, spawn in fog, ember budget on a 120 m fixture strip).
- `tests/test_atmosphere.gd` — region light defaults/overrides (the burn warms every Act I
  region), validator light checks, water depth baking (land 0, sea 1, shallows exist), water
  mesh (shore foam vertices, skirt, inland cells skipped), Atmosphere applying a mood + Greying.
- `tests/test_terrain.gd` — TerrainField heights, mesh/triangle agreement, ramp/cliff/sea
  reachability, colour rules, mesh faces up + shore-wall collider, ground-relative placement,
  validator ground checks.
- `tests/test_ridge_dressed.gd` — Day 26: the dressing kit loads (< 5 MB), the Lamp's chisel
  beat (two taps, a rest, the hood turning) on the real model, the cap hut exactly one of two by
  flag, halos on every lit waymark, conditional paint (field selection, the woods' fourth waymark
  greying, the ground mesh recoloured), validator paint/halo checks, ridge outcrops clear of the
  paths and the old road's waymarks going north-east up out of reach.
- `tests/test_ridge_lit.gd` — Day 28: the lit tower's horn is the one see-through material and
  the fire glows behind it (the cold tower has neither), the far halo's size/bloom and the ridge's
  halo + light, halo parameters reach the shader, lantern posts' halos, placement pose overrides,
  Hob seated on the bench (same spot/facing, seat top 0.44 m, by the tally-house step), the `sit`
  doze and start on the real model (legs stay put), validator placement-pose and halo-number checks.
- `tests/test_aldous_bench.gd` — Day 32: Aldous seated on the plank bench (same spot/facing, seat top
  0.44 m, by the Wrens' house; the NPC itself still standing), the `bottle` swig curve and pose on the real
  model (the bottle hand comes up and in, the head goes back, the legs stay put), Saltmarrow's two gate
  lofts broken before the burn and half-mended after (one model per spot, same footprint and collider).
- `tests/test_fen_dressed.gd` — Day 30: the staithe (deck height, gulls on the posts), the boardwalk
  (nothing over the deck, pier width, a foam ring per pile, walkable), boards along the long walk into
  the fog, Corran's punt afloat and the traps on dry ground, alders and reed beds at the water's edge,
  the Unmoored figures (dry, reachable, facing the water, off the paths, a `still` rig), the `still`
  idle on the real model, region `water` reaching the shader (the sea elsewhere unchanged), the pale
  skiff, validator figure/water checks.
  Day 31 adds the look-away (`averts`: the aim, slow easing, the real model's head turning from the
  player and the chin dropping; nothing when cupped) and its validator checks.
- `tests/run_tests.gd` prints each test's time and the slowest eight (Day 31). Keep the suite well
  inside `run_checks.sh`'s 300 s per step: a validator pass over every region runs once per validator
  test (~20 of them), so a slow per-region check multiplies. Day 31: 26 s.
- `tests/test_wrackholm.gd` — Day 40: the east lane (asked + done here; the full sailing honouring what was carried to
  Dunstan; back to the fen only; later sailings short), Oda and the ferry in exactly one region on every lane, the
  layout (reachable, the yard's thin fog, Wenna by the horn and the door, the Wrack Light out of reach in the Teeth's fog,
  the board object's glint on the hulk's transom), the kit (the blank board, one glowing surface on the lane-house, the
  rig), Wenna (the law, the Gannet, the names said into the horn, read-first, the Teeth, deeds, the sleeve-ember and the
  Book, the Lamp's name), Jory (his brother's name, who called them in three ways) and the glass float to Pell.
- `tests/test_kindleby_chapter.gd` — Day 64: the chapter can't sit till the ember holds the ring (Tobin's hint, the offer,
  bowed/refused), holding the ring from the crown (the Boats' Lantern given, the skiff north only if told of the stage),
  what the chapter weighed, Tobin's coal-pan (kept/carried, the cradle offering both, the rite reminder), the burning
  four ways (rite × Remnant: quest done, port lit, the lit model, the fog past the wall thinner, the light warmer, the
  Provost/Tobin/Oda after), the pan handed back, the lit model (glow, halo in the lantern room).
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
  travel on a new game, then walks 9 passes **only where a player could be** (Day 23): each
  pass covers the regions reachable on foot (open exits) from where the last one left off;
  in each it talks to every NPC and examines every object walking each menu and collects
  pickups — anyone/anything whose dialogue can `travel` (Oda, the bramble wall) last, objects
  before people — and a travel moves the walk on to the new place (never back by teleport;
  every region must be reached by the end). It then checks checks gated exits now open, that the menu
  walk relit the Gull's Beacon (quest done, a Remnant burned, beacon light shown, fog
  thinned, the region light applied), that a third pass reached Aldous's confession and Mara's ferry lantern, that the horn sounded
  on arriving elsewhere (arrival events are clicked through), that passes 4–5 met Oda, settled
  Pell and took passage (the Act I end card showed a recap naming the burn, and was closed), that
  a late pass cast off with Oda to Thornwold (a `travel` mid-walk ends that region's walk; the
  landing scene is clicked through) and met Bram, that the bramble wall's menu walk went
  through the gap into the woods (an inspectable's `travel` also ends the region's walk), met
  Hob and carried Bram's salt (*Salt for the Collier* done), climbed to the Lamp and (Day 27) lit
  the Ridge Light with the first Remnant it was offered (Hob's boots) and saw Hob come in by daylight
  (he stands at the landing after), and that ferry, Oda and Pell stand where the
  lane left them (and that
  Saltmarrow's burn-specific dressing matches the burn — `Region.shown_conditional_props(shape)`), opens the journal and satchel via real input
  actions, saves/loads and compares state.
- Add a `test_*.gd` extending `TestCase`; methods named `test_*` run automatically.

## Rendering notes
Project targets Forward+ (Vulkan). In the sandbox only the OpenGL Compatibility renderer
(`--rendering-driver opengl3` under Xvfb/llvmpipe) is available for screenshots, and it
renders noticeably brighter/washed-out; do color grading on a real GPU.

**Striped shadows on thin props (Day 39).** Zig-zag bands on a thin pole are usually a near thing's real
shadow (a ladder's rungs on its leg, under a high sun), not bias acne: check with the sun's shadow off
before touching `shadow_bias`/`shadow_normal_bias` (raising them changed nothing on the Heron's leg).
The fix is in the model: put the shadow-caster tight against what it shades.

**Region colours as hex (Day 39).** Region fog/light/ground/water colour keys take palette names or
`#hex` (tonal mixes of palette colours, per GAME_DESIGN). The fen uses neutral whites (`#CBCCC9`) instead
of `silverfog`, whose blue reads lavender over its water; `tests/test_fen_art.gd` keeps blue out of it.
