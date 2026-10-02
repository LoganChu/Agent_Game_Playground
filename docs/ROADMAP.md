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

- [x] [A] **Dressing follow-ups: the Wrens' house, broken lofts, wading foam**: every house
      planked on all four faces (side walls were flat); a new planked `house_stilt` retires
      the flat `stilt_house.glb`; **`house_wren`**, Aldous's family house (bleached boards,
      patched slate roof, boarded window, a cold Keeper's brazier, an ember-hook) with an
      **ember sign that follows the confession** (wrapped in sailcloth → uncovered) and a
      `wrens_door` inspectable (untold / grudging / full, + the sleeve-ember); Gull's Head's
      **`net_loft_broken`** ×2 (Hesk's loft stays whole); prop **`wading`** foam rings round
      the dock pilings and the stilts in the shallows (Day 16)

- [x] [C] **The crossing — Act II begins** (Day 17): "Cast off for Thornwold." on the evening
      tide (Mara and the green lantern, Pell per crossing outcome, the crew carrying the burned
      memory, steering off the Gull astern); *Across the Grey* completes; new region **Thornwold
      Landing** (cove, lumber camp, jetty, the bramble wall over the cart road, Greying in the
      woods behind it) with a landing scene; **Bram Kettle** (new character), who weighs the
      deed and the burn (knot grudge) and gives **A Light for Thornwold**; the bramble wall
      inspectable; Pell on Thornwold if aboard; the Slow Mercy plies back and forth
      (`lanes_ferry_at`). Engine: dialogue `travel` effect. Blender: bramble, log pile, stump,
      charcoal sacks, Bram.

### Art track (owner request, 2026-09-26)
The owner wants the look upgraded: characters and settings read as generic greybox.
**Cadence rule:** until the Vertical Slice looks shippable, at least every other session
must land one **[A]** item below (screenshots before/after in the devlog, via
`xvfb-run … --screenshot=`). Stay within GAME_DESIGN's art direction (flat-shaded low-poly,
palette colors, strong silhouettes); every asset from a re-runnable `tools/blender/` script,
each .glb < 5 MB.

### Next up
1. [A] **Art, due Day 18 — Thornwold's look**: the camp still borrows Saltmarrow's stilt and
   tall houses — a log **bunkhouse** and **tally-house** (round logs, bark roof, a stove pipe),
   a **saw-pit** / trestle, a **charcoal clamp** (smoking earth mound) for the woods edge,
   denser underbrush and fallen trunks; a darker pine variant so Thornwold's pines differ from
   Saltmarrow's. Screenshot before/after (`2026-10-02-crossing-*.png` are the "before").
2. [S] **Settings** in the pause menu: volume buses, text size (`UiTheme.set_text_scale`),
   camera sensitivity/invert, key rebinding (InputSetup is the hook); persisted to
   `user://settings.cfg` (not in saves).
3. [C] **Into the woods** (next content, by Day 21): what lies past the bramble wall — the
   shifting paths as a mechanic (paths that fade/re-route in the Greying; trust and
   misdirection), the charcoal folk (who brings the sacks?), the lantern on the ridge, the
   beacon-keeper; a Thornwold Remnant or two toward the next burn. Pay off Pell's tally stick
   and the ember leaning toward the thorns. Small Act I threads still open: Aldous noticing you
   read his sign; Tam and the broken lofts; Pell's pouch ("something lost, something GOOD")
   could take a Thornwold find.
4. [S] **Title screen**: New game / Continue (latest slot) / Load / Settings / Quit; then
   "Return to title" on the Act I end card and in the pause menu.
5. [P] **Color grading pass on a Vulkan machine** — sandbox screenshots (Compatibility
   renderer) are washed out; verify palette reads correctly in Forward+ (incl. beacon glow,
   the Day 12 glow/contrast/saturation grading, SSAO strength, the water colours).
   Needs the owner to run the game locally and report back.
6. [S] **The Greying v2** (fold pieces into later sessions): fog pockets/banks on
   Saltmarrow and Shingle Point too (offshore, leaning back after the burn); the ember light
   pushing fog back in a small radius around the player; paths that fade in thick fog
   (LORE: "a road forgets where it goes" — now Thornwold's theme, see item 3); a Hushed NPC
   drifting in a pocket; audio cue (muffling low-pass + heartbeat-ish ember crackle) with the
   audio item; colourblind-safe meter check with the accessibility item. Consider a story flag
   when the player is first turned back (an NPC remarks on it).
7. [S] Audio hooks: bus layout, footsteps, ambient loop per region, dialogue "voice blips"
    per NPC (data field). Placeholder sounds generated procedurally.
8. [A] Saltmarrow dressing follow-ups: paint contrast in the Compatibility renderer (walkway
   vs. slate); Saltmarrow's two greyed net-lofts by the boardwalk gate could take the broken
   variant (or a half-mended one after the burn); Aldous still stands — a bench by the Wrens'
   steps (LORE says he sits on one) wants a seated idle like Hesk's; a lit-window variant for
   nights once day/night exists.
9. [S] Interaction polish: camera framing during dialogue; inspectable glint; fade the
   player model when the camera is pushed in close behind them (a wall at their back).
   (Facing while talking landed Day 14; the key hint hides in dialogue since Day 15.)

## Milestone 2 — Alpha (Act II begins)
- [x] [C] **The crossing** — landed Day 17 (see Done).
- [S] **Ferry travel system & map screen** (lanes open beacon to beacon): replace Oda's
  sail/back dialogue choices with a lane map; `lanes_ferry_at` stays the ferry's position.
  Still to honour on Thornwold: `pells_pouch` (Pell stayed), the beacon-keeper; Keepers met
  later should react to `saltmarrow_aldous_confessed` and the Keeper's Sleeve-Ember (`future`).
- [C] Thornwold (forest, shifting paths) beyond the landing: 2–3 more NPCs, beacon + burn choice (landing + Bram since Day 17).
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
- Last content session: Day 17 (the crossing, Thornwold Landing); next content due by Day 21.
- Last art session: Day 16 (Wrens' house, broken lofts, wading foam); art is due **next run (Day 18)** — Thornwold's own buildings.
- Camera blockers are mesh-bounds boxes: a tree's blocker is its whole canopy box, so the
  camera pulls in a little early beside pines. Fine for now; per-part shapes if it bothers.
- Pause pauses the whole tree; anything that must run under the menu (HUD, smoke test) sets
  `PROCESS_MODE_ALWAYS`. Toast tweens keep running under the menu (HUD is always-on).
- Save slots have no thumbnails or play time yet (full save system item, Milestone 3).
- The Vertical Slice is now playable start to finish (wake → beacon → ferry → Act I card).
  After the card the player keeps exploring Saltmarrow with passage taken; nothing sails until
  Act II. Remaining slice work is systems/polish (pause menu, settings, audio, interaction
  polish) and art.
- Smoke test walks 6 passes since Day 17 (a late pass casts off). It visits every region on every pass,
  so (from its first pass) it meets Bram on Thornwold *before* the crossing — impossible in play (the landing is only
  reachable by ferry), harmless for the test; `_check_crossing` checks the sailing itself.
  A `travel` mid-walk ends that region's walk (nodes are freed).
- Thornwold Landing has no exits yet: the only way on or off is Oda's ferry. The woods past the
  bramble wall are walkable but deep Greying (you are turned back) — by design until "Into the
  woods".
- Smoke test ferry paths: the ferry needs Pell's dock ask before Mara's leave; the walk
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
- `wading` foam rings are static (no breathing like the boats' rings) and are dropped per leg
  where the ground is above the water; a leg standing exactly at the tide line gets none.
- The ember signs are separate props positioned by sharing the house's origin; if the Wrens'
  house ever moves, move both signs with it (`test_wrens_and_lofts.gd` checks they match).
