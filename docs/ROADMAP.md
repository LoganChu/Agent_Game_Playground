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
- [x] **Aldous's confession** (Act I close): gentle → full account after the beacon (High
      Keeper, the light down the stair, "too soon" explained, Keeper's Sleeve-Ember);
      pressed/unasked → refused once, then the bare fact after showing the ember. Quest
      *Across the Grey* (Act II bridge) → Mara hangs the green ferry lantern (Day 6)
- [x] Engine: `signal_lantern` prop, quest `future` flag, `--flags=` / `--quest=` debug args (Day 6)
- [x] [A] **Terrain**: data-driven sculpted ground (`ground` in region JSON → `TerrainField`
      + `TerrainBuilder`): faceted vertex-coloured mesh, ragged coastlines, cliffs, shore-wall
      collider, ground-relative placement. Shingle Point is a curved beach with a spit and
      dunes; Saltmarrow has a harbor basin inside a breakwater with a stilt house in the
      water and a causeway to the loft yard; Gull's Head's headland is a 2.8 m cliff
      tableland reached by one ramp. Validator: everything reachable on foot (Day 7)
- [x] **Polish/debt pass**: walkable piers (Saltmarrow dock), live refresh of conditional
      NPCs/pickups/objects, shared `UiTheme` with a text-scale hook, TestCase dialogue
      helpers, lit-beacon screenshot (Day 8)
- [x] **Saltmarrow after the burn**: Dunstan's stool by Mara's door (+ two cups after the
      `gull` burn; the returned gull sits on it), drying nets in the village (begun from the
      middle after the `knot` burn), Pell's lost-things crate on Shingle Point (an empty,
      guarded nest after the `pebble` burn; green glass once the lantern is up); Pell asks to
      come on the ferry (`saltmarrow_pell_ferry_ask`), Tam explains Tidewright deed-fares
      (and minds the knot), Mara reads the sleeve-ember. New prop shapes `stool`, `cups`,
      `net_rack`, `net_frame` (Day 9)
- [x] [A] **Saltmarrow dressing kit** (Blender, `build_dressing.py`, 22 models): dock with
      pilings/ladder, moored fishing boat, rowboat, upturned rowboat, smokehouse, barrels,
      crate, lantern posts, fences, drying racks/frames with lattice nets, stool, cups,
      signal lantern, lit-beacon lantern room, driftwood logs, wreck ribs, reeds, grass.
      Every procedural stand-in in Act I replaced; all three regions re-dressed with a
      landmark each (Saltmarrow harbor + smokehouse, the Shingle Point wreck, Gull's Head
      cliff fences + lit lantern room). Engine: `light` on model props (validated); prop
      lineup art scene (Day 10)

### Art track (owner request, 2026-09-26)
The owner wants the look upgraded: characters and settings read as generic greybox.
**Cadence rule:** until the Vertical Slice looks shippable, at least every other session
must land one **[A]** item below (screenshots before/after in the devlog, via
`xvfb-run … --screenshot=`). Stay within GAME_DESIGN's art direction (flat-shaded low-poly,
palette colors, strong silhouettes); every asset from a re-runnable `tools/blender/` script,
each .glb < 5 MB.

### Next up
1. [S] **The Greying, v1**: fog volumes/areas with a local fog shader; standing in fog
   drains the ember (UI meter); leaving refills. No fail state — at zero you are gently
   walked back out ("you forget why you came"). Gull's Head (before the beacon) is the test
   bed; after the burn its areas should shrink (reuse `fog.overrides` idea).
2. [A] **Atmosphere & lighting** (art due again by Day 12): gradient sky, sun/ambient per
   region, glow on ember and beacon, stylized water shader (foam line at shores), SSAO;
   ember-hand point light on the player. The kit's lantern glass and smokehouse embers are
   emissive but unlit — decide which lanterns earn a real light (budget) here.
3. [A] **Terrain follow-ups** (fold into atmosphere sessions): shore foam line where ground
   meets water; paint reads weakly in the Compatibility renderer (walkway vs. slate) — pick
   stronger contrasts after the Vulkan colour check; a second Saltmarrow stilt row along the
   harbor edge; camera can clip into the Gull's Head cliffs when orbiting close.
4. [A] **Dressing follow-ups**: replace the last procedural pieces (Saltmarrow's pine at
   (-17, -3), Shingle Point's rock at (12, 4), the gate posts) with kit models; a Blender
   stilt-house variant or two (slate walls, a Mara's-house with a porch for the stool) so
   the village isn't one house repeated; Gull's Head net-lofts could carry lattice nets.
5. [P] **Color grading pass on a Vulkan machine** — sandbox screenshots (Compatibility
   renderer) are washed out; verify palette reads correctly in Forward+ (incl. beacon glow).
   Needs the owner to run the game locally and report back.
6. [S] Pause menu: resume, save, load, settings, quit. Multiple save slots.
7. [S] Settings: volume buses, text size (`UiTheme.set_text_scale`), camera
   sensitivity/invert, key rebinding (InputSetup is the hook).
8. [S] Audio hooks: bus layout, footsteps, ambient loop per region, dialogue "voice blips"
    per NPC (data field). Placeholder sounds generated procedurally.
9. [S] Interaction polish: face NPC when talking, camera framing during dialogue.

## Milestone 2 — Alpha (Act II begins)
- [C] **Ferry arrives** (pays off *Across the Grey*, flag `saltmarrow_ferry_lantern_hung`).
  Must honour `saltmarrow_pell_ferry_ask` (promised → Pell on the dock with a bundle and
  Mara to face; refused → Pell's "bring me something lost"; undecided → Pell asks, loudly),
  and the Tidewright deed-fare (Tam, Day 9: the lit Gull pays; knot-burn crews resent it):
  the horn, a Tidewright ferryman NPC at the Saltmarrow dock, Act I→II transition; the
  ferry travel system & map screen. Keepers met later should react to
  `saltmarrow_aldous_confessed` and the Keeper's Sleeve-Ember (item is `future`).
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
- The ferry signal lantern's moss glow reads almost white in the Compatibility renderer;
  check it with the colour-grading item.
- Character follow-ups (fold into later [A]/[S] items): NPCs don't turn to face the player
  (ROADMAP "Interaction polish"); the ember light is a fixed point in the player's model
  space rather than riding the arm; no facial expressions / talk motion during dialogue;
  models are ~700–900 tris — room for more silhouette detail (Mara's coat collar, Tam's
  boots) within the 1–2k budget.
- Smoke test: parsed input needs two process frames when resuming from a physics frame;
  keep the double await in `_check_journal`.
- The smoke test's menu walk always burns whichever Remnant is listed first (currently the
  pebble); the other burn paths are covered by `test_burning.gd` unit tests only.
- The HUD key hint ("[J] Journal [I] Satchel") is overlapped by the dialogue panel's
  bottom-left corner; hide it while dialogue is open (fold into Interaction polish).
- Next polish/debt pass due by session 16 (Day 8 was the last).
- Model props can't be tinted (the `color` field only affects procedural shapes), so tint
  variants are separate exports (`net_rack_pine`). If variants multiply, add a material
  override hook (e.g. recolour surfaces named `Tint*`).
- Model-prop colliders are one box each: the wreck's box keeps the player out of its ribs,
  and the upturned boat/trestles are one block. Fine for now; revisit with trimesh or
  compound colliders if exploring around props matters.
- Kit lantern glass (kindle) and the lit beacon glass read nearly white in the Compatibility
  renderer, like the moss signal glow — include in the colour-grading item.
- Inspectables have no visual cue until the prompt appears; with more of them now (stool,
  nets, lost things), consider a subtle highlight/glint (fold into Interaction polish).
- Journal quest order relies on `WorldState.quests` insertion order (Dictionary order is
  preserved through JSON saves); if save migration ever rebuilds that dict, keep the order.
