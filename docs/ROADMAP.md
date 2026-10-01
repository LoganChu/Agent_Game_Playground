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
- [x] [S] **The Greying v1**: region `greying` areas (rect/ellipse, strength, falloff,
      `if`) with ground-hugging shader fog layers, thicker/desaturated environment inside;
      the ember drains with depth (paused in dialogue/menus), HUD "Ember" bar + grey wash +
      dimming ember light; at zero a fade and "You forget why you came." back on the last
      clear ground. Gull's Head headland drowned until the beacon burns, pockets after.
      Validator: no spawn in fog, every reachable spot ≤ 0.45 ember one way (Day 11)
- [x] [A] **Atmosphere & lighting**: region `light` moods (sun/ambient/sky, story overrides —
      Gull's Head cold and drained until the beacon burns, every Act I region warmer after),
      tweened with the fog by a new `Atmosphere` node; gradient sky shader with cloud bands
      and sun halo; glow on emissives; SSAO (Forward+); breathing ember-hand light; stylized
      water with depth baked from the ground (shallow→deep, faceted swell, shore foam line).
      Light budget decided: ember, ferry lantern, beacon only (Day 12)
- [x] [C] **The ferry's arrival — Act I ends** (pays off *Across the Grey*): the *Slow Mercy*'s
      horn heard on arriving at the beach/headland after the green lantern (region arrival
      events); the ferry (Blender) at the Saltmarrow dock; **Oda Farrow**, Tidewright
      ferry-master (new character model), weighs the deed (claimed/shared/brusque) and asks
      what the burn cost (off-islanders still remember a burned memory; it won't stick to
      those who lost it); passage only to Thornwold. Pell's ask honoured (promised → Mara's
      leave, aboard/let_down; refused → finding pouch; undecided/unasked → asks loudly on the
      dock). Mara's farewell (+ a message for Dunstan), Aldous and Tam react. Taking passage
      shows the **Act I end card** recapping the player's choices. Engine: region `events`,
      conditional multi-placement of NPCs, `act_ends` + `ActEndCard`, `--act-end=` (Day 13)
- [x] [A] **Village kit & harbor life** (dressing follow-ups): Blender `house_tall` (two
      storeys, slate and tarred boards, pine shingles, shutters) and `house_porch` (Mara's
      house: porch, steps down by Dunstan's stool, window box, a net over the rail) and
      `gate_post` (lashed post with a cork float); lattice nets on the net-lofts. The last
      procedural stand-ins are gone (Saltmarrow pine, Shingle Point rock, every gate post). A
      second stilt row stands in Saltmarrow's west shallows. Boats bob and roll on the swell
      with a waterline foam ring (`float`); extra prop `colliders`. Mara looks out over the
      harbor and every NPC turns to face the player while talking (and back after; Hesk keeps
      mending — `faces_player`); the Wakebearer turns to them too (Day 14)

- [x] [P] **Polish pass: camera, pause menu, save slots**: camera-only blockers over tall
      props (roofs, eaves, canopies) on a new `camera` layer, sphere-swept spring arm that
      snaps in and eases out; pause menu (Esc/Start: resume, save, load, quit) with three
      save slots + quicksave; HUD key hint hides under modals; ember meter no longer flashes
      on load; lineup scenes lit by `Atmosphere` (Day 15)

### Art track (owner request, 2026-09-26)
The owner wants the look upgraded: characters and settings read as generic greybox.
**Cadence rule:** until the Vertical Slice looks shippable, at least every other session
must land one **[A]** item below (screenshots before/after in the devlog, via
`xvfb-run … --screenshot=`). Stay within GAME_DESIGN's art direction (flat-shaded low-poly,
palette colors, strong silhouettes); every asset from a re-runnable `tools/blender/` script,
each .glb < 5 MB.

### Next up
1. [A] **Art due next session (Day 16)** — **Dressing follow-ups (small)**: house side walls
   (±X) are flat — boards on all four faces; a Gull's Head variant of the net-loft with a
   broken rail (Hushed, neglected); Aldous's house (the stilt house at (-9,-3)) could get a
   Keeper touch (a cold brazier, an ember-hook by the door) now that his secret is out.
   Also from terrain/atmosphere: foam rings around the dock pilings and stilt-house legs in
   the water (static `float` with bob 0, or a per-piling ring list); paint contrast in the
   Compatibility renderer (walkway vs. slate).
2. [C] **Content due by Day 17**: begin *The crossing* (see Milestone 2) once Thornwold has
   a greybox, or a small Act I side thread that pays off an open flag.
3. [S] **Settings** in the pause menu: volume buses, text size (`UiTheme.set_text_scale`),
   camera sensitivity/invert, key rebinding (InputSetup is the hook); persisted to
   `user://settings.cfg` (not in saves).
4. [S] **Title screen**: New game / Continue (latest slot) / Load / Settings / Quit; then
   "Return to title" on the Act I end card and in the pause menu.
5. [P] **Color grading pass on a Vulkan machine** — sandbox screenshots (Compatibility
   renderer) are washed out; verify palette reads correctly in Forward+ (incl. beacon glow,
   the Day 12 glow/contrast/saturation grading, SSAO strength, the water colours).
   Needs the owner to run the game locally and report back.
6. [S] **The Greying v2** (fold pieces into later sessions): fog pockets/banks on
   Saltmarrow and Shingle Point too (offshore, leaning back after the burn); the ember light
   pushing fog back in a small radius around the player; paths that fade in thick fog
   (LORE: "a road forgets where it goes"); a Hushed NPC drifting in a pocket; audio cue
   (muffling low-pass + heartbeat-ish ember crackle) with the audio item; colourblind-safe
   meter check with the accessibility item. Consider a story flag when the player is first
   turned back (an NPC remarks on it).
7. [S] Audio hooks: bus layout, footsteps, ambient loop per region, dialogue "voice blips"
    per NPC (data field). Placeholder sounds generated procedurally.
8. [S] Interaction polish: camera framing during dialogue; inspectable glint; fade the
   player model when the camera is pushed in close behind them (a wall at their back).
   (Facing while talking landed Day 14; the key hint hides in dialogue since Day 15.)

## Milestone 2 — Alpha (Act II begins)
- [C] **The crossing** (Act I→II transition; the arrival itself landed Day 13): Oda's "When do
  we sail?" becomes casting off on the evening tide once Thornwold exists — narration of
  leaving Saltmarrow (Mara on the dock with the green lantern; Pell at the rail if
  `saltmarrow_pell_crossing=aboard`), the quest *Across the Grey* completes, arrive at
  Thornwold. Ferry travel system & map screen (lanes open beacon to beacon). Honour on
  Thornwold: `saltmarrow_ferry_deed` (how Tidewrights greet you), `saltmarrow_oda_saw_sleeve_ember`,
  Pell aboard (a companion who finds things?) or the finding pouch (`pells_pouch`), the
  unnamed Keeper beacon-keeper Aldous mentioned. Keepers met later should react to
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
- Character follow-ups (fold into later [A]/[S] items): the ember light is a fixed point in the player's model
  space rather than riding the arm; no facial expressions / talk motion during dialogue;
  models are ~700–900 tris — room for more silhouette detail (Mara's coat collar, Tam's
  boots) within the 1–2k budget.
- Smoke test: parsed input needs two process frames when resuming from a physics frame;
  keep the double await in `_check_journal`.
- The smoke test's menu walk always burns whichever Remnant is listed first (currently the
  pebble); the other burn paths are covered by `test_burning.gd` unit tests only.
- Next polish/debt pass due by session 23 (Day 15 was the last).
- The Greying's fog layers barely read from far overviews under the pre-burn global fog
  (0.045) in the Compatibility renderer; up close they read fine. The Day 12 cold light helps
  Gull's Head read as drained; re-judge the density with the Vulkan colour check.
- Day/night isn't in yet: the sky has one sun per region mood. When day/night lands, it
  should drive `Atmosphere` (sun angle/colour) and give street lanterns real lights at night.
- `GreyingWalker` returns the player to the last clear ground they *stood* on; if a future
  region spawns the player inside a pocket via a save, they go to the default spawn
  (validator keeps spawns clear, but saved positions aren't checked).
- Last content session: Day 13 (the ferry); content next due by Day 17 at the latest.
- Last art session: Day 14 (village kit); art next due by Day 16 (next run) under the cadence rule.
- Camera blockers are mesh-bounds boxes: a tree's blocker is its whole canopy box, so the
  camera pulls in a little early beside pines. Fine for now; per-part shapes if it bothers.
- Pause pauses the whole tree; anything that must run under the menu (HUD, smoke test) sets
  `PROCESS_MODE_ALWAYS`. Toast tweens keep running under the menu (HUD is always-on).
- Save slots have no thumbnails or play time yet (full save system item, Milestone 3).
- The Vertical Slice is now playable start to finish (wake → beacon → ferry → Act I card).
  After the card the player keeps exploring Saltmarrow with passage taken; nothing sails until
  Act II. Remaining slice work is systems/polish (pause menu, settings, audio, interaction
  polish) and art.
- Smoke test now walks 5 passes (the ferry needs Pell's dock ask before Mara's leave); it
  takes one Pell path per run (whichever the menu walker reaches — currently promised →
  Mara says yes). Other ferry paths are covered by `test_ferry.gd`.
- NPCs placed in several regions: the validator only checks each placement is conditional,
  not that the conditions are mutually exclusive — keep them as exact negations.
- Model props can't be tinted (the `color` field only affects procedural shapes), so tint
  variants are separate exports (`net_rack_pine`). If variants multiply, add a material
  override hook (e.g. recolour surfaces named `Tint*`).
- Model-prop colliders are boxes (one `collider`, plus `colliders` since Day 14): the wreck's
  box keeps the player out of its ribs, and the upturned boat/trestles are one block; Mara's
  porch steps are a block too (the player can't climb onto the porch). Revisit with trimesh
  colliders if exploring around props matters.
- Floating boats' colliders bob with the model (a few cm). Harmless while nobody walks on a
  boat; when boarding the ferry becomes playable, keep the deck collider static.
- NPC turn-to-face only rotates the body; the name label and interaction area stay put
  (fine: both are round). The turn is purely visual and not saved.
- Kit lantern glass (kindle) and the lit beacon glass read nearly white in the Compatibility
  renderer, like the moss signal glow — include in the colour-grading item.
- Inspectables have no visual cue until the prompt appears; with more of them now (stool,
  nets, lost things), consider a subtle highlight/glint (fold into Interaction polish).
- Journal quest order relies on `WorldState.quests` insertion order (Dictionary order is
  preserved through JSON saves); if save migration ever rebuilds that dict, keep the order.
