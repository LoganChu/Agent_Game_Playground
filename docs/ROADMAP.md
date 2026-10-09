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

- [x] [S] **Story checkpoints** (owner request, 2026-10-02): `data/scenarios.json`,
      `--scenario=<id>`, pause menu Chapter select (debug builds), `tools/checkpoints.sh` →
      `docs/CHECKPOINTS.md` gallery. **Every content session adds a checkpoint for what it built.**

- [x] [A] **Thornwold's look** (Day 18): Blender log **bunkhouse** and **tally-house**
      (saddle-notched logs, bark-slab roofs, stove pipes, lit windows, Bram's tally board, a
      lean-to porch), **saw trestle**, **charcoal clamp** (smouldering past the bramble wall),
      **pine_dark** for every Thornwold pine, Greyed **pine_snag**s at the wall's ends,
      **underbrush** and **fallen trunks**. Engine: prop **`smoke`** (CPU particle columns from
      model-space vents). Thornwold borrows nothing from Saltmarrow any more.

- [x] [S] **Settings** (Day 19): pause menu **Settings** (Master/Music/Ambience/Effects/Voices
      volume sliders on code-created buses, text size presets, camera sensitivity, invert
      left/right and up/down, reset) and **Controls** (rebind every movement/interaction key;
      swaps, Esc reserved), saved to `user://settings.cfg`; HUD/dialogue key hints follow the
      bindings; the menu list scrolls at large text sizes.

- [x] [A] **Woods kit** (Day 20): `build_woods.py` — the charcoal folk's **collier_hut** (cone
      of poles, bark and turf) and **sack_cart**, Keepers' **waymark** cairns (bare / lantern
      hung), a cutter's **trail_stake**, **greyed_brush** and **pine_grey**. Past the bramble
      wall the woods now go grey from the inside; the sack cart stands loaded by the clamp, the
      first waymark's hook is empty, and a trail stake points into the thorns.

- [x] [C] **Into the woods, part one** (Day 21): the ember **parts the bramble wall** (the
      bramble dialogue → `travel`); new region **The Woods Past the Wall** (`thornwold_woods`,
      an inland hollow under banks): the straight cart road runs north into deep Greying (the road
      lies), **lit waymarks** lead west off it to **the colliers' clearing** (two cone huts, a clamp,
      sacks); a lantern burns on the ridge out of reach. Engine: Greying **`clear` areas** (lantern
      light cuts pools out of fog; validator worst case). **Hob Marl** (new character): who brings
      the sacks and tends the clamp, "the Lamp" who hangs the lanterns, the five hearths. **Bram's
      tally board** inspectable (the salt row stops at three) and side quest **Salt for the
      Collier** (Bram had forgotten Hob; a fourth notch). Pell's tally stick is Hob's. Checkpoint
      `thornwold_woods`.

- [x] [A] **The ridge kit** (Day 22): `build_ridge.py` — **Thornwold's beacon, the Ridge Light**
      (square dry-stone tower laced with timber, horn-paned timber lantern cage, iron pine vane,
      lantern rack with one lantern left; cold and lit variants, ~10 m) and **the keeper's lodge**
      (the Lamp's lantern bench: an open lantern, a shut iron box, hammer and chisel). Both placed
      dark on the woods' ridge, out of reach; the lit tower is held for the burn. **`collier_hut_cold`**
      (greyed, slipping sods, boots left on the seat) replaces the clearing's second hut; Hob's hut
      smokes. Hob gets a **`rake` idle** (CharacterRig style).

- [x] [P] **Polish/debt pass two** (Day 23): lantern `clear` areas **fade** when the light
      changes (the fog layers dissolve from the old cut to the new over 4 s — story-driven
      lanterns are now safe); Settings **save per change** (a dragged slider once, when let go);
      the **"[E]" prompt re-labels** at once on a rebind; inspectables **glint** (a faint
      twinkling star, data `glint` offset / `false`, fades in with distance and gives way to the
      prompt); the smoke test **walks only where a player could be** (reachable regions from
      where it stands, travellers last) — no more Bram/the wall/Gull's Head before their time —
      and now checks Hob and *Salt for the Collier*.

- [x] [A] **The way up** (Day 24): the **Keepers' stair** up the woods' north bank — a switchback
      earth ramp in the region's ground (`path`, walkable) dressed with two Blender flights of log
      steps with a rope rail (`ridge_steps_lower/upper`, each climbing exactly its path's rise) to a
      **landing under the last pitch**, where the **Keepers' ladder lies fallen** (the standing
      `keeper_ladder` waits for part two; the ridge top stays unreachable). The colliers' traces: a
      **felt cap on a waymark** at the stair's foot, a **dropped, split sack** on the turn. **The
      Lamp** (Blender character, unplaced): hooded oilskin cape over a Keeper's robe with a bright
      stitched ember, soot-black hands, a lantern pole with a lit lantern, two cold lanterns at the
      belt, half-Hushed silver hem and sleeve. Character lineup shows unplaced models (`--only=`).

- [x] [C] **Into the woods, part two — the ridge and the Lamp** (Day 25): the player **stands the
      Keepers' ladder** (its top cords cut from above) and climbs to **`thornwold_ridge`**, its own
      region (a plateau whose south lip drops sheer to the woods; the ladder's head, the cold Ridge
      Light, the keeper's lodge, the old Keepers' road going north-east). **The Lamp** (NPC, `lamp.glb`)
      at the lantern bench: its lost name, **the saved midwinter coal** broken into slivers for the
      lanterns, **why the ladder came down** (the four colliers went on north; "no fifth"), the coal gone
      cold on the Spire side, **Aldous** per confession (and the sleeve-ember's stitch), the Ridge Light
      wanting a memory. **Shifting paths:** *A Lantern for the Stair* — a new sliver, the fourth
      waymark's lantern moved (its pool closes, Hob notices), or refuse; a hung lantern lights the stair.
      **Ottie Swale's cap** to Hob. Checkpoint `thornwold_ridge`.

- [x] [A] **The ridge, dressed** (Day 26): the Lamp **chisels** at the bench (CharacterRig `chisel`:
      tap, tap, a rest, the hood turning to listen); **Ottie's cap on the cold hut's seat** by the boots
      (`collier_hut_cold_cap`, by `thornwold_hob_has_cap`); every lit waymark gets a **lantern halo**
      (a soft camera-facing glow, no light spent) so the stair-foot lantern and the ridge's read at a
      distance; the ridge top dressed from Blender — **stone outcrops** (tall and low), **silvered
      heather** in clumps, and the old Keepers' road's waymarks going on **north-east up the spine**
      (bare, bare, **tumbled**) — the procedural rocks gone. Engine: **conditional ground paint**
      (`if` on paint zones; the ground mesh recolours live) — the fourth waymark's moss goes grey when
      its lantern is taken. Character lineup `--pose=`/`--turn=`.

- [x] [C] **Thornwold's burning** (Day 27): the Lamp says what the Ridge Light wants (stage
      `feed_the_light`) and names two things Thornwold could spare — **Hob's memory of the four
      colliers** (Ottie Swale, Wenna Coll, Abe and Tolly Dray; Hob makes **Ottie's boots** a Remnant
      at the clearing's edge, the cold hut's seat goes bare — new Blender `collier_hut_cold_empty`) or
      **the camp's memory of the colliers** (Bram's **SALT row**, offered once Hob is paid; the board's
      pegs go bare). Weigh/confirm at the cradle; the **lit Ridge Light** on the ridge (the beacon's
      light) and on the woods' skyline (a halo); fog leans back and light warms in all three Thornwold
      regions; the unburned Remnant can be returned. **Hob comes in by daylight** (landing event, paid
      + lit, either order) to the tally-house step — Bram knows him, or doesn't (salt row). Aftermath:
      Hob forgets the four (boots), the Lamp stops breaking the coal and keeps the rest "for the four"
      (a stair sliver shows as a night less), Bram's new LIGHT row, Pell, **Oda opens the fen lane**
      (talk only). Smoke walk lights it. Checkpoint `thornwold_lit`.
- [x] [A] **The Ridge Light, lit** (Day 28): the lit tower's horn panes see-through (new
      `build_dressing.horn` material, glTF BLEND) with a **fire in the cradle** (coals, ember tongues,
      a kindle heart) and the rack's one lantern lit; halos take `halo_strength`/`halo_bloom` — the
      woods' skyline halo is 14 m with a bloom (the fog glows round the tower), the ridge gets a cage
      halo by its light; **Hob seated** on a new split-log bench (`log_bench`) by the tally-house step
      (`hob_seated` model, new `sit` idle: thumbs on the pole, dozes off and wakes with a start) via
      new **placement poses** (a placement's own `model`/`idle`); halos on every lantern post
      (Saltmarrow ×2, the landing).

- [x] [C] **The fen lane — Act II goes on** (Day 29): Oda sails **north-about** from the lit Ridge Light
      (`lanes_ferry_at=fen`; back to Thornwold only) to **`glasswater_fen`** — Glasswater Staithe: a plank
      staithe with a whittled gull on every post, a dyke to **Stillhithe** (three Blender **reed houses**, a
      thin Greying the Unmoored live in on purpose), mirror pools, a west walk to the **letting post**, Corran's
      eel landing, the long walk north into **the Deeps**, and **the Heron Light** dark on its legs out in the
      mere (Blender, iron heron vane). **Hesper Vail** (Unmoored; asks you to cup the ember — `fen_ember`) and
      **Corran Teal** (last of the fen folk; *A Light for Glasswater* begins) — both new Blender characters.
      **Dunstan's thread:** his Saltmarrow rowboat, the gulls he paid his mooring in, the name he left with
      Hesper, the long walk "with a lantern that wasn't lit — it's for after"; side quest **The Letting Post**:
      tie on Mara's word, your own, or leave nothing (`fen_dunstan_word`). The `gull` burn makes his name slide
      off the Wakebearer. Checkpoint `glasswater_fen`; the smoke walk sails the lane twice.
- [x] [A] **The fen, dressed** (Day 30): the **staithe** (a whittled gull on every post, all facing out to sea),
      a low **boardwalk** for the west walk (no ladder/bollards; a plank gone), **boards laid along the long walk**
      into the fog, Corran's moored **punt** and **eel-traps**, dead **alders** (not pines), **reed beds** along the
      pools, **the Unmoored sitting by the pools** (`unmoored_shawl`, `unmoored_coat`; engine: **figure props** — a
      prop with an `idle` — and the new **`still`** idle), **mirror-still water** (region `water`: swell/wash/foam/
      mirror + colours), the Heron's skiff pale and readable, Hesper's locks and shawl, Corran's woven creel.
- [x] [P] **Polish/debt pass three** (Day 31): `fen_ember` shows — **the Unmoored by the pools turn their
      faces from a bare ember** (figure `averts`: a condition + radius; head and shoulders turn away from the
      player, the chin drops, slowly; nothing with a cupped hand), and **Corran** is glad of a bare ember and says
      why they turn. **The test suite went from 280 s to 26 s**: `Greying.ember_cost_map` was a LIFO
      label-correcting search (8.6 s per validation of the woods), now Dijkstra on a binary heap (43 ms, same
      costs) — the tests step had crept to within 20 s of the gate's 300 s limit. The runner prints each test's
      time and the slowest eight. The smoke walk checks the look-away live in the fen.
- [x] [A] **Saltmarrow: Aldous's bench and the gate lofts** (Day 32): **Aldous sits** on a salt-silvered
      **plank bench** on two slate piles by the Wrens' steps (an empty bottle under it) — `aldous_seated`
      (robe skirt over the knees, the bottle corked on his left thigh) and a new **`bottle`** idle (a swig
      every 14 s: the bottle up to his mouth, the head back). The two greyed **net-lofts by the boardwalk
      gate** are **broken** (`net_loft_broken`) until the Gull is lit and **half-mended** after
      (`net_loft_mended`, new: pale new boards in the gaps, sailcloth lashed over the roof hole, the rail
      splinted with rope, a new net hung, the fallen one folded, new rungs, more boards waiting).

### Art track (owner request, 2026-09-26)
The owner wants the look upgraded: characters and settings read as generic greybox.
**Cadence rule:** until the Vertical Slice looks shippable, at least every other session
must land one **[A]** item below (screenshots before/after in the devlog, via
`xvfb-run … --screenshot=`). Stay within GAME_DESIGN's art direction (flat-shaded low-poly,
palette colors, strong silhouettes); every asset from a re-runnable `tools/blender/` script,
each .glb < 5 MB.

### Next up
1. [C] **The Heron Light, part one** (next content, due by Day 33 — next run): Corran decides he likes you (what tips
   it? the ember shown, not cupped? an eel-trap errand?) and poles you out through the channels to the
   Heron Light's legs in the Deeps (a punt `travel`, own region or the mere's edge); the keeper's skiff; what
   happened to her (keep it open-ish); Unmoored further in; Dunstan glimpsed, not met. Keep the four
   colliers and the Lamp's coal open.
2. [A] **Art (due Day 34)**: the fen's flat white light — the pale shore band, the silverfog paint on
   Stillhithe (see Known issues); or what part one of the Heron Light needs dressed (the legs up close,
   the keeper's skiff, the channels).
3. [S] **Title screen**: New game / Continue (latest slot) / Load / Settings / Quit; then
   "Return to title" on the Act I end card and in the pause menu. Reuse the pause menu's
   Settings/Controls pages (move the page builders into a shared `SettingsPages` control).
4. [P] **Color grading pass on a Vulkan machine** — sandbox screenshots (Compatibility
   renderer) are washed out; verify palette reads correctly in Forward+ (incl. beacon glow,
   the Day 12 glow/contrast/saturation grading, SSAO strength, the water colours).
   Needs the owner to run the game locally and report back.
5. [S] **Settings follow-ups**: gamepad rebinding and stick deadzone; a fullscreen/window
   and vsync toggle; a subtitle/dialogue-speed option with the accessibility item; prompts
   that show pad glyphs when a pad was used last.
6. [S] **The Greying v2** (fold pieces into later sessions): fog pockets/banks on
   Saltmarrow and Shingle Point too (offshore, leaning back after the burn); the ember light
   pushing fog back in a small radius around the player; paths that fade in thick fog
   (LORE: "a road forgets where it goes" — now Thornwold's theme, see item 3); a Hushed NPC
   drifting in a pocket; audio cue (muffling low-pass + heartbeat-ish ember crackle) with the
   audio item; colourblind-safe meter check with the accessibility item. Consider a story flag
   when the player is first turned back (an NPC remarks on it).
7. [S] Audio hooks (buses exist since Day 19 — play through them by name), footsteps, ambient loop per region, dialogue "voice blips"
    per NPC (data field). Placeholder sounds generated procedurally.
8. [A] Saltmarrow dressing follow-ups: paint contrast in the Compatibility renderer (walkway
   vs. slate); a lit-window variant for nights once day/night exists; after a `full` confession the
   brazier's ash raked (LORE, Day 16 — not yet shown); the mended lofts could get someone at work on
   them (Tam off the gate?) once Saltmarrow has more people. (Aldous seated and the gate lofts: Day 32.)
9. [S] Interaction polish: camera framing during dialogue; fade the
   player model when the camera is pushed in close behind them (a wall at their back).
   (Facing while talking landed Day 14; the key hint hides in dialogue since Day 15.)

## Milestone 2 — Alpha (Act II begins)
- [x] [C] **The crossing** — landed Day 17 (see Done).
- [S] **Ferry travel system & map screen** (lanes open beacon to beacon): replace Oda's
  sail/back dialogue choices with a lane map; `lanes_ferry_at` stays the ferry's position.
  Still to honour on Thornwold: `pells_pouch` (Pell stayed), the beacon-keeper; Keepers met
  later should react to `saltmarrow_aldous_confessed` and the Keeper's Sleeve-Ember (`future`).
- [x] [C] Thornwold (forest, shifting paths): landing + Bram (Day 17), woods + Hob (Day 21), ridge + the Lamp (Day 25), the burn (Day 27). Later: the old Keepers' road north along the ridge — where the four colliers went (and whether Hob goes after them).
- [C] Glasswater Fen (Unmoored), the right-to-forget storyline; Dunstan Tollen. Begun Day 29 (the staithe, Stillhithe, Hesper, Corran, the letting post); next: the Heron Light out in the mere, the Deeps, Dunstan found.
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
- The smoke test's menu walk always burns whichever Remnant is listed first (Act I: currently the
  knot; Thornwold: Hob's boots — it meets Hob before Bram); the other burn paths are covered by
  `test_burning.gd` / `test_thornwold_burning.gd` unit tests only.
- Next polish/debt pass due Day 39 (Day 31 was the last). Candidates: the smoke walk's Thornwold Oda (below);
  Hesper's first talk can be walked past (then `fen_ember` stays unset and nobody turns — fine, but check
  it reads); the fen's mirror water/colour with the Vulkan pass.
- Test time budget: `tools/run_checks.sh` gives each step 300 s. Day 31: tests 26 s, smoke ~45 s, import the
  longest. The runner prints the slowest tests — check them when adding a validator pass over every region.
- The Greying's fog layers barely read from far overviews under the pre-burn global fog
  (0.045) in the Compatibility renderer; up close they read fine. The Day 12 cold light helps
  Gull's Head read as drained; re-judge the density with the Vulkan colour check.
- Day/night isn't in yet: the sky has one sun per region mood. When day/night lands, it
  should drive `Atmosphere` (sun angle/colour) and give street lanterns real lights at night.
- `GreyingWalker` returns the player to the last clear ground they *stood* on; if a future
  region spawns the player inside a pocket via a save, they go to the default spawn
  (validator keeps spawns clear, but saved positions aren't checked).
- Settings save per change since Day 23, but a slider mid-drag when the OS closes the
  window loses that drag (saved on `drag_ended`). Harmless.
- Last content session: Day 29 (the fen lane); next content due by Day 33 (the Heron Light, part one).
- Last art session: Day 32 (Aldous's bench, the gate lofts). Next art due Day 34.
- Hob's camp bench is in the tally house's shadow under the landing's sun (west); he reads dark from
  the yard in Compatibility. Judge with the Vulkan colour pass; a fill light is not in the budget.
- Prop `smoke` is CPU particles (pauses with the tree under the menu): fine at a few vents;
  if a region ever wants dozens, use GPUParticles3D on Forward+ and keep CPU for Compatibility.
- Thornwold's log buildings use one box collider each (the porch of the tally-house is
  walk-through under its roof; its posts have no collider).
- Camera blockers are mesh-bounds boxes: a tree's blocker is its whole canopy box, so the
  camera pulls in a little early beside pines. Fine for now; per-part shapes if it bothers.
- Pause pauses the whole tree; anything that must run under the menu (HUD, smoke test) sets
  `PROCESS_MODE_ALWAYS`. Toast tweens keep running under the menu (HUD is always-on).
- Save slots have no thumbnails or play time yet (full save system item, Milestone 3).
- The Vertical Slice is now playable start to finish (wake → beacon → ferry → Act I card).
  After the card the player keeps exploring Saltmarrow with passage taken; nothing sails until
  Act II. Remaining slice work is systems/polish (pause menu, settings, audio, interaction
  polish) and art.
- Day 29: the smoke passes never talk to Oda on Thornwold Landing — the bramble wall (a mover, objects first)
  always moves the walk into the woods first. The fen lane is therefore sailed by `_sail_the_fen_lane` after the
  passes (choosing Oda's option by text). If later lanes open from Thornwold or the fen, extend that helper
  (or teach the walk to prefer an unwalked travel target) rather than adding passes.
- Day 31: `fen_ember` bare turns the Unmoored figures' faces away (`averts`) — figures only; Hesper and Corran
  are NPCs and still face the player to talk (an NPC `averts` would need to fight `faces_player`).
- Day 30: the fen's mirror water (region `water`, mirror 0.6) reads very pale from above in Compatibility —
  fog plus sheen; re-judge with the Vulkan colour pass. Figure props (the Unmoored) have a box collider each;
  an `if` works like any prop's, and `averts` (Day 31) turns their heads from the player.
- Smoke test walks 9 passes since Day 23, each over the regions reachable on foot from where
  it stands (travellers — Oda, the bramble wall — last). A `travel` mid-walk ends that region's
  walk (nodes are freed). Oda is always talked to last and the walk never sails back to
  Saltmarrow (the back trip is covered by `test_crossing.gd`). If content ever adds a region
  reachable only by a route the walk can't take, the "walk reached every region" check fails —
  extend `_reachable` rather than teleporting.
- Thornwold Landing has no exits: the ferry, and the bramble wall's dialogue (which `travel`s
  into `thornwold_woods`) are the ways off. The landing's own strip of woods past the wall is
  still deep Greying (you are turned back) — the way in is through the gap, by design.
- The smoke test's menu walk always takes "Go through" at the bramble wall.
- Lantern `clear` areas fade their fog re-cut over 4 s (Day 23), but the ember drain follows
  the new light at once. If a lantern going out under the player feels abrupt, ramp
  `Greying.depth_at` with the same tween.
- Inspectable glints read faintly inside deep Greying (white on white in Compatibility);
  re-judge with the colour-grading item (they bloom in Forward+).
- The woods region is a large hollow (≈ 50 × 50 m walkable) with nothing in its deep Greying but
  bare waymarks and pines; the ridge content (part two) should give the north half a purpose.
  The stair (Day 24) climbs the bank's east half; its landing is walkable and sits in fog.
- Stair flights are single models fitted to a straight ramp: if the woods' ground `path` for the
  stair changes, rebuild the flights to match (`STAIR_FLIGHTS`) — `test_ridge_way.gd` fails if
  they drift apart. The bank's ragged edge buries the uphill ends of a few upper risers (reads as
  steps cut into the bank).
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
- Journal quest order relies on `WorldState.quests` insertion order (Dictionary order is
  preserved through JSON saves); if save migration ever rebuilds that dict, keep the order.
- `wading` foam rings are static (no breathing like the boats' rings) and are dropped per leg
  where the ground is above the water; a leg standing exactly at the tide line gets none.
- The ember signs are separate props positioned by sharing the house's origin; if the Wrens'
  house ever moves, move both signs with it (`test_wrens_and_lofts.gd` checks they match).
- Conditional ground paint recolours the whole ground mesh (regenerated in GDScript, a few ms
  for the woods) when its set changes — fine at story beats; don't drive it from anything per
  frame. The colour snaps while lantern pools fade over 4 s (usually off-screen: the woods'
  fourth lantern is moved from the ridge).
- Lantern halos are depth-tested quads that ignore distance fog on purpose (a lantern reads through
  it); a halo behind a Greying fog layer still shows through the layer (the layers don't write
  depth). Reads as "light in the fog", which is the intent — re-judge in Forward+.
- The tumbled waymark at the far end of the ridge's road is mostly lost in the fog from the
  plateau (by design, but it barely reads in screenshots).
- Hob comes in by daylight for good once he's at the camp (`thornwold_hob_came_in`): there's no
  day/night yet, so he never goes home to his clamp. When day/night lands, give him a schedule
  (camp by day, clearing by night) instead of a one-way move.
- After the boots burn, the player's own lines still name the four (e.g. the Lamp's ladder story is
  told before the burn). Like Act I, the burned memory "slides off" only in narration; a pass over
  later dialogue should keep the player from naming the four to Hob.
- Oda's `route` line still says the lane past Thornwold leads "to Cindermoor"; the fen lane comes
  first (LORE Day 27). Reword it when the fen sailing lands.
