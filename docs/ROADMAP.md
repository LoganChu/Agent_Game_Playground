# Emberwake — Roadmap

Prioritized top-down within each milestone. Each item should fit in one daily session.
Legend: **[C]** content · **[S]** systems · **[P]** polish/tech-debt · **[A]** art.

## Milestone 1 — Vertical Slice (Act I: Saltmarrow)
Goal: 30–45 minutes, playable start to finish: wake → Saltmarrow → relight the Gull's Beacon
with a meaningful burn choice → consequences visible in the village.

### Done
- [x] Project skeleton, data loader, validator, test runner, smoke test (Day 1)
- [x] Third-person controller, orbit camera, interaction, dialogue UI, HUD toasts (Day 1)
- [x] Save/load stub (F5/F9, JSON) (Day 1)
- [x] Shingle Point + Saltmarrow greybox; Pell, Mara, Aldous; quests *Lost Things* and
      *A Light for Saltmarrow* (first two stages) (Day 1)
- [x] Blender pipeline: 4 props (pine, rocks, stilt house, Gull's Beacon) (Day 1)
- [x] CI workflow (`.github/workflows/checks.yml`) running `tools/run_checks.sh` in the
      godot-ci container (Day 1)
- [x] Quest journal (J) and Satchel/inventory (I) panels (Day 2)
- [x] Gull's Head (net-lofts + headland) gated by the Harbormaster's Token; Tam Hollis,
      Old Hesk, the Remembering Knot Remnant; beacon examine advances *A Light for
      Saltmarrow* to `feed_the_beacon`; Mara learns Dunstan left willingly (Day 3)
- [x] Engine: gated exits (`requires`/`locked_text`), inspectable `objects` (Day 3)
- [x] Blender: net-loft prop (Day 3)
- [x] **The Burning choice** at the Gull's Beacon: pebble (Pell must consent if given),
      Remembering Knot, or Mara's memory of Dunstan (whittled gull, offered in person);
      confirm step; quest complete; fog thins live in all three regions; lantern light;
      aftermath lines for Mara/Pell/Hesk/Tam/Aldous; lent Remnants can be returned (Day 4)
- [x] Engine: flag-driven fog `overrides`, conditional props (`if`) refreshed live (Day 4)
- [x] [A] **Characters**: Blender base body + Wakebearer, Mara, Pell, Aldous, Tam, Hesk
      (seated, mending); procedural idle/walk `CharacterRig`; NPC `model`/`idle` fields,
      `player_model`; character lineup debug scene (Day 5)

### Art track (owner request, 2026-09-26)
The owner wants the look upgraded: characters and settings read as generic greybox.
**Cadence rule:** until the Vertical Slice looks shippable, at least every other session
must land one **[A]** item below (screenshots before/after in the devlog, via
`xvfb-run … --screenshot=`). Stay within GAME_DESIGN's art direction (flat-shaded low-poly,
palette colors, strong silhouettes); every asset from a re-runnable `tools/blender/` script,
each .glb < 5 MB.

### Next up
1. [C] **Aldous's confession** (Act I close): after the beacon is lit, Aldous tells the
   player the Snuffing was deliberate — sooner/fuller if `saltmarrow_aldous_approach=gentle`,
   grudging (maybe needs a second visit or a Remnant shown) if `pressed`. Reveal only what
   LORE allows (deliberate; a High Keeper; not *why*). Set a flag, hook to Act II (the
   ferry). He also reacts to the player being "too soon" (mystery #2 foreshadow).
2. [A] **Terrain**: replace box slabs with sculpted per-region meshes from Blender (or
   SurfaceTool) with vertex-colored shingle/sand/grass/rock — a real curved beach at
   Shingle Point, a harbor basin and stilt-lined waterfront in Saltmarrow, a *raised*
   headland at Gull's Head with walkable slopes. Keep colliders simple (trimesh or
   heightmap).
3. [A] **Saltmarrow dressing kit** (Blender): dock + pilings, smokehouse, beached and moored
   boats, barrels, drying racks with nets, lanterns on posts, fences, grass/reed clumps,
   a proper lit-lantern beacon model to replace the procedural `beacon_light`. Then
   re-dress all three regions so each has a distinct silhouette and landmark.
4. [S] **The Greying, v1**: fog volumes/areas with a local fog shader; standing in fog
   drains the ember (UI meter); leaving refills. No fail state — at zero you are gently
   walked back out ("you forget why you came"). Gull's Head (before the beacon) is the test
   bed; after the burn its areas should shrink (reuse `fog.overrides` idea).
5. [A] **Atmosphere & lighting**: gradient sky, sun/ambient per region, glow on ember and
   beacon, stylized water shader (foam line at shores), SSAO; ember-hand point light on the
   player.
6. [P] **Polish/debt pass** (due by session 8 at the latest): shared UI `Theme` resource;
   live refresh of NPC/pickup/object `if` conditions (props already refresh); a debug
   `--flags=a=b,c` / `--quest=` CLI arg so screenshots can show late-game states (the lit
   beacon light has not been eyeballed yet — only asserted by the smoke test).
7. [C] **Saltmarrow after the burn**: small world changes per burn — e.g. `gull`: Dunstan's
   stool/second cup prop by Mara; `knot`: half-started nets; `pebble`: Pell's lost-things
   crate without the pebble. Use conditional props.
8. [P] **Color grading pass on a Vulkan machine** — sandbox screenshots (Compatibility
   renderer) are washed out; verify palette reads correctly in Forward+ (incl. beacon glow).
   Needs the owner to run the game locally and report back.
9. [S] Pause menu: resume, save, load, settings, quit. Multiple save slots.
10. [S] Settings: volume buses, text size, camera sensitivity/invert, key rebinding
    (InputSetup is the hook).
11. [S] Audio hooks: bus layout, footsteps, ambient loop per region, dialogue "voice blips"
    per NPC (data field). Placeholder sounds generated procedurally.
12. [S] Interaction polish: face NPC when talking, camera framing during dialogue.

## Milestone 2 — Alpha (Act II begins)
- [C] Ferry travel system & map screen; Tidewright ferryman NPC.
- [C] Thornwold region (forest, shifting paths), 3–4 NPCs, beacon + burn choice.
- [C] Glasswater Fen region (Unmoored), the right-to-forget storyline; Dunstan Tollen.
- [S] Day/night cycle & tides; NPC schedules.
- [S] Player memory Remnants (the player's own past resurfacing — mystery #2 foreshadowing).
- [S] Accessibility: colorblind-safe fog/ember cues, subtitles sizing, no timing gates.
- [P] Performance budget & profiling pass; LODs for props.

## Milestone 3 — Beta
- [C] 2 more islands; Keepers faction arc; Hollow Choir hints.
- [S] Full save system with migration, autosave, Steam Cloud-friendly paths.
- [S] Localization pipeline (dialogue string ids).
- [P] Controller-first UI pass; Steam Deck checks.

## Milestone 4 — Early Access
- [C] Cindermoor & the Hearthspire (Act III opening); endings scaffold.
- [S] Steamworks integration (achievements for choices, no telemetry).
- [P] Store assets, trailer capture tooling, crash-free week.

## Known issues / tech debt
- Region terrain is box slabs.
- Character follow-ups (fold into later [A]/[S] items): NPCs don't turn to face the player
  (ROADMAP "Interaction polish"); the ember light is a fixed point in the player's model
  space rather than riding the arm; no facial expressions / talk motion during dialogue;
  models are ~700–900 tris — room for more silhouette detail (Mara's coat collar, Tam's
  boots) within the 1–2k budget.
- Terrain slabs can't make slopes/steps (Y rotation only) and the player can't climb, so
  every region is flat; the Gull's Head headland should be raised once ramps exist
  (fold into the terrain item).
- Smoke test: parsed input needs two process frames when resuming from a physics frame;
  keep the double await in `_check_journal`.
- Region NPCs/pickups/objects do not refresh live when flags change mid-visit (only on
  region load); props and fog do.
- The smoke test's menu walk always burns whichever Remnant is listed first (currently the
  pebble); the other burn paths are covered by `test_burning.gd` unit tests only.
- UI is built in code with per-widget theme overrides; extract a shared `Theme` resource
  (palette, fonts, sizes) before the pause/settings menus so text-size settings apply
  everywhere at once.
- Journal quest order relies on `WorldState.quests` insertion order (Dictionary order is
  preserved through JSON saves); if save migration ever rebuilds that dict, keep the order.
