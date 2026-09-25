# Emberwake — Roadmap

Prioritized top-down within each milestone. Each item should fit in one daily session.
Legend: **[C]** content · **[S]** systems · **[P]** polish/tech-debt.

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

### Next up
1. [C] **The Burning choice** at the Gull's Beacon (`story/gulls_beacon.json`, knot
   `waiting` — replace "Not yet." with real options): humming pebble if kept; if given,
   Pell must agree to part with it (visit Pell); the Remembering Knot (the village's
   founding craft — Hesk/Tam react); Mara's memory of Dunstan as a costly option (only if
   `saltmarrow_mara_told_of_dunstan`; she must be asked in person). Take the burned item,
   set `saltmarrow_beacon_burned` (value = what burned), complete the quest.
   Region fog recedes (Gull's Head + Saltmarrow density drop via flag-driven fog).
2. [S] **The Greying, v1**: fog volumes/areas with a local fog shader; standing in fog
   drains the ember (UI meter); leaving refills. No fail state — at zero you are gently
   walked back out ("you forget why you came"). Gull's Head is the natural test bed.
3. [C] **Aftermath**: NPC dialogue branches on the burn; Aldous confides (sooner if
   `saltmarrow_aldous_approach=gentle`) that the Snuffing was deliberate. Hook to Act II.
4. [S] Region state reacting to flags (props/NPC placement `if` conditions already
   supported; add per-region fog/mood overrides driven by flags).
5. [P] **Color grading pass on a Vulkan machine** — sandbox screenshots (Compatibility
   renderer) are washed out; verify palette reads correctly in Forward+.
6. [S] Pause menu: resume, save, load, settings, quit. Multiple save slots.
7. [S] Settings: volume buses, text size, camera sensitivity/invert, key rebinding
    (InputSetup is the hook).
8. [S] Audio hooks: bus layout, footsteps, ambient loop per region, dialogue "voice blips"
    per NPC (data field). Placeholder sounds generated procedurally.
9. [C] Blender: NPC base mesh(es), dock, smokehouse, boat props.
10. [P] Terrain: replace slab boxes with a heightmap/mesh per region (Blender or Godot
    SurfaceTool) with shingle/grass vertex colors.
11. [S] Interaction polish: face NPC when talking, camera framing during dialogue.

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
- Region terrain is box slabs; NPC bodies are primitive meshes.
- `a_light_for_saltmarrow` has no completion yet (validator warning, expected) — the beacon
  offers only "Not yet." until the Burning choice lands (Next up #1).
- Terrain slabs can't make slopes/steps (Y rotation only) and the player can't climb, so
  every region is flat; the Gull's Head headland should be raised once ramps exist
  (fold into the terrain item).
- Smoke test: parsed input needs two process frames when resuming from a physics frame;
  keep the double await in `_check_journal`.
- Region does not refresh live when flags change mid-visit (only on region load).
- UI is built in code with per-widget theme overrides; extract a shared `Theme` resource
  (palette, fonts, sizes) before the pause/settings menus so text-size settings apply
  everywhere at once.
- Journal quest order relies on `WorldState.quests` insertion order (Dictionary order is
  preserved through JSON saves); if save migration ever rebuilds that dict, keep the order.
