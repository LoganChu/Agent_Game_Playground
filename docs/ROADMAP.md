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
      godot-ci container — **unverified until its first run; check it on Day 2** (Day 1)

### Next up
1. [S] **Quest journal UI** (J key): active/done quests with current stage text.
2. [S] **Inventory panel** (I key): items with descriptions; Remnants highlighted.
3. [C] **The net-lofts & headland**: greyed zone north of Saltmarrow gated by the
   Harbormaster's Token (`harbor_token`, currently `future`); path to the Gull's Beacon.
   Advance *A Light for Saltmarrow* at the beacon.
4. [S] **The Greying, v1**: fog volumes/areas with a local fog shader; standing in fog
   drains the ember (UI meter); leaving refills. No fail state — at zero you are gently
   walked back out ("you forget why you came").
5. [C] **The Burning choice** at the Gull's Beacon: offer available Remnants (humming pebble
   if kept; Pell's collection if given → Pell must agree; Mara's memory of Dunstan as a
   costly third option). Set `saltmarrow_beacon_burned`. Region fog recedes.
6. [C] **Aftermath**: NPC dialogue branches on the burn; Aldous confides (sooner if
   `saltmarrow_aldous_approach=gentle`) that the Snuffing was deliberate. Hook to Act II.
7. [S] Region state reacting to flags (props/NPC placement `if` conditions already
   supported; add per-region fog/mood overrides driven by flags).
8. [P] **Color grading pass on a Vulkan machine** — sandbox screenshots (Compatibility
   renderer) are washed out; verify palette reads correctly in Forward+.
9. [S] Pause menu: resume, save, load, settings, quit. Multiple save slots.
10. [S] Settings: volume buses, text size, camera sensitivity/invert, key rebinding
    (InputSetup is the hook).
11. [S] Audio hooks: bus layout, footsteps, ambient loop per region, dialogue "voice blips"
    per NPC (data field). Placeholder sounds generated procedurally.
12. [C] Blender: NPC base mesh(es), dock, net-loft, smokehouse, boat props.
13. [P] Terrain: replace slab boxes with a heightmap/mesh per region (Blender or Godot
    SurfaceTool) with shingle/grass vertex colors.
14. [S] Interaction polish: face NPC when talking, camera framing during dialogue.

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
- `a_light_for_saltmarrow` has no completion yet (validator warning, expected).
- Region does not refresh live when flags change mid-visit (only on region load).
