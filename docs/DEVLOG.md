# Emberwake — Dev Log

Newest entries first. Each entry: what was done, decisions & why, problems, next steps.

## 2026-09-29 21:00 UTC — Day 12: Atmosphere & lighting (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **Atmosphere & lighting** (ROADMAP [A] #1; art was due under the cadence rule):
  - **Region light moods.** New `light` block per region (sun colour/energy/pitch/yaw,
    ambient colour/energy, sky top/horizon) with `if` overrides like fog, resolved by
    `RegionMood.light` and validated (known keys, palette/#hex colours, numbers, `if`).
  - **`Atmosphere` node** (child of main) owns the environment and sun, replacing
    `main.gd`'s inline environment. Story changes tween the *whole* mood over 4 s — fog, sun,
    ambient and sky together — and the Greying look now lives there too.
  - **Sky:** a texture-free sky shader: tide→silverfog gradient, a sun halo, slow flat cloud
    bands near the horizon (heavier in thicker fog).
  - **Grading:** a touch more contrast and saturation; **glow** on emissives only (ember,
    lantern and beacon glass, windows, the smokehouse vent); **SSAO** on (Forward+ only).
  - **Ember:** the ember-hand light is a bit stronger and breathes (layered sine flicker);
    it still dims with the Greying.
  - **Water:** `WaterBuilder` bakes the sea's depth over the sculpted ground into vertex
    colour; the water shader gives shallow→deep colour, faceted swell that calms towards the
    shore, a ragged **foam line** where the sea meets land and a broken wash line rolling in.
    A skirt to the horizon shares the grid's edge vertices, so the swell opens no cracks.
  - **Act I moods:** Shingle Point a low morning sun; Saltmarrow greyed village light;
    **Gull's Head cold and drained** (silverfog sun at 0.6, slate sky) until the beacon burns.
    After the burn every Act I region's sun warms (`#F5C77E`/`#F5CF88`) and strengthens.
- **Tests:** `test_atmosphere.gd` (6 tests: light defaults/types, the burn warms every Act I
  region, validator light checks, water depth baking, water mesh foam/skirt/inland skip,
  Atmosphere applying a mood + the Greying). Smoke test now also checks the region light is
  applied on load. 70 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-09-29-atmosphere-*.png`): `before-saltmarrow` vs.
`after-saltmarrow` (same camera), `before-gulls-head` vs. `gulls-head-dark` (the cold, drained
headland) vs. `gulls-head-relit`, `harbor-water` (deep water, shallows, shore foam at the
dock), `shingle-ember` (the ember warming the sand).

**Decisions**
- **Depth baked from the terrain, not read from the depth buffer.** Screen-depth foam needs
  Forward+ (and breaks on transparent layering); we already know the ground height
  everywhere, so a half-metre water grid with baked depth gives the same foam in every
  renderer and is unit-testable.
- **One mood tween instead of per-property tweens**: `Atmosphere` blends two resolved mood
  snapshots, so new mood keys only need adding to `_resolve`/`_show`.
- **Light budget:** real OmniLights only for the ember, the ferry lantern and the lit beacon.
  By day, glow on the emissive glass is enough for street lanterns; they earn real lights
  when day/night lands (logged).
- **Region light is data, not canon** — but it follows LORE's rule that relit places regain
  warmth and colour, so no LORE change.

**Problems / notes**
- First sky pass used the azimuth angle for cloud noise and showed a hard seam where it
  wraps; switched to a polar mapping of the view direction.
- Clouds first reached the zenith and read as blotches; narrowed the band to the horizon.
- Everything is still judged in the Compatibility renderer (washed out, no SSAO); the Vulkan
  colour check (ROADMAP #4) now also covers glow/grading/SSAO/water.

**Next run should**
1. **Content** ([C], due by Day 13 — i.e. next session): the ferry's arrival (Alpha) or a
   smaller Act I thread (an NPC reacting to the player being turned back by the Greying,
   Greying v2 pockets on Saltmarrow/Shingle Point).
2. Art next due by Day 14: terrain & atmosphere follow-ups (piling foam, paint contrast,
   second stilt row) or the dressing follow-ups.

## 2026-09-29 09:00 UTC — Day 11: The Greying v1 (systems)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **The Greying v1** (ROADMAP [S] #1). The fog is now a place, not only a mood:
  - Region data `greying`: areas (`rect`/`ellipse`, `strength`, `falloff`, `height`, `if`).
    Pure logic in `Greying` (depth with smoothstep falloff, deepest area wins; active areas
    by condition) and `EmberMeter` (24 s to empty at full depth, 4 s to refill).
  - **Look:** `GreyingFog` builds five stacked translucent layers per area, hugging the
    ground or the water, alpha baked per vertex from the same depth function the gameplay
    uses, animated by a small texture-free shader (value-noise drift, slow swell, fade near
    the camera). Standing in it thickens the environment fog and drains colour (smoothed).
  - **Ember:** `GreyingWalker` samples depth under the player each physics frame; drain is
    paused whenever a modal UI holds input (dialogue, journal). HUD: "Ember" bar top-left
    (only in/near fog), a grey wash as it wanes, and the ember-hand light dims.
  - **No fail state:** at zero the screen fades to fog, the player is set back on the last
    clear ground they stood on, refilled, and toasted "You forget why you came."
  - **Gull's Head** is the test bed: before the burn the headland is drowned (the beacon in
    the thickest fog), a half-strength spill runs down the ramp over the northern lofts, and
    a bank sits on the water to the west. After the burn they fade out over 4 s, leaving a
    lip of fog on the headland's seaward edge and a thinner bank further out.
  - **Validator:** areas well-formed; no spawn inside any area; and — with every area
    present — every spawn/NPC/pickup/object/exit reachable from clear ground for ≤ 0.45
    ember one way (Dijkstra over the terrain's walkable cells), so fog can never strand
    content. The dark headland's beacon costs ≈ 0.1.
- Debug: screenshot args `--at=x,z[,yaw]` (place the player) and `--settle=N`.
- **Tests:** `test_greying.gd` (7 tests) + a smoke check that walks up into the fog with real
  input, sees drain and the meter, lets the ember run out (sped up), and checks the turn-back
  and refill; the beacon check now also asserts the fog left the headland. 64 tests + smoke +
  launch pass.
- LORE: Wakebearer canon — the ember wanes in fog; when it gutters you forget the errand and
  find yourself at the fog's edge (hook: the ember "knows the way out"); relit beacons leave
  pockets.

Screenshots (`docs/screenshots/2026-09-29-greying-*.png`): `gulls-head-before` vs.
`gulls-head-after` (overview), `from-the-lofts` (the headland hazed beyond Hesk; meter
lingering after a walk), `in-the-fog` (at the dark beacon: desaturated, meter draining).

**Decisions**
- **Areas, not FogVolumes.** Godot's volumetric fog is Forward+-only; the sandbox (and some
  players' machines) run Compatibility. Mesh layers + one shader work everywhere, and baking
  alpha from `Greying.area_depth` means what you see is exactly where the ember drains.
- **`if` per area** (like props/NPCs) instead of `fog.overrides`-style replacement: the
  after-burn pockets are different shapes, not thinner versions of the same ones, and
  conditional areas fade live through the existing `refresh_conditional` path.
- **The ember isn't saved** — it refills in seconds, and a save can't be made mid-turn-back
  (input is locked). Keeps the save format unchanged.
- **Drain pauses during dialogue**, so conversations in fog (the beacon choice) never cost
  ember; the budget validator only counts walking.

**Problems / notes**
- First smoke run: the walk into the fog stopped at the ramp's foot (depth 0.34); lengthened
  the walk. Validator crashed on a deliberately malformed area (index out of range) before
  reporting it — geometric Greying checks now skip regions whose areas are malformed.
- A long `--settle` under llvmpipe (slow frames, real-time physics) drained the ember and
  turned the player back before the shot — keep `--settle` short for fog screenshots.
- Fog layers barely read in the far overview under the pre-burn global fog (logged).

**Next run should**
1. **Atmosphere & lighting** ([A], ROADMAP #1) — art is due by Day 12 under the cadence rule.
2. Content is due by Day 13: the ferry's arrival (Alpha) or a smaller Act I thread
   (e.g. an NPC reacting to being turned back by the Greying, Greying v2 pockets on
   Saltmarrow/Shingle Point).

## 2026-09-28 21:00 UTC — Day 10: Saltmarrow dressing kit (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **Dressing kit** (ROADMAP [A] #1, art was due under the cadence rule): new
  `tools/blender/build_dressing.py` → 22 models in `assets/models/dressing/` (5–57 KB each):
  dock (planks, pilings, braces, ladder, mooring posts, bollard, rope coil), a moored
  single-masted fishing boat, rowboat, upturned rowboat on trestles, smokehouse (stone
  plinth, tarred boards, glowing roof vent, fish under the eave, woodpile), barrel and a
  barrel cluster, crate, lantern post, signal lantern (moss glass), fence section, drying
  rack with a lattice net and cork line / bare frame with a middle-begun patch (+ pine-net
  variants), Dunstan's stool, the two cups, driftwood log, **wreck ribs**, reeds, dune grass,
  and the lit lantern room for the Gull's Beacon (glass, flame core, mullions, gallery rail).
  Boat hulls are lofted from V cross-sections; rails and the foredeck follow the hull line.
  Every model is joined by material with its transform baked before export.
- **Every procedural stand-in in Act I replaced** (dock, crates, stilt houses, signal lantern,
  stool, cups, net racks/frames, beacon light) with the same footprint and heights, and all
  three regions **re-dressed** so each has its own silhouette:
  - *Saltmarrow*: harbor with the fishing boat and a rowboat by the dock, smokehouse by the
    walkway, lantern posts, barrels, a fenced patch west, reeds on the shore, grass on the
    hills.
  - *Shingle Point*: the **wreck** at the neck of the spit (landmark), an upturned rowboat,
    driftwood logs, dune grass and reeds.
  - *Gull's Head*: cliff-edge fences either side of the ramp top, drying racks and barrels in
    the loft yard, a hauled-up rowboat, the lit lantern room when the beacon burns.
- **Engine:** `light` on model props (`{color, energy, range, offset}` → OmniLight3D), since
  Blender exports no lights; validator rejects it on shape-only props and requires it on a
  model standing in for a self-lit shape (`PropFactory.LIT_SHAPES`). Art-review scene
  `scenes/debug/prop_lineup.tscn` (`--only=`, `--camera=`).
- **Tests:** `test_dressing.gd` (4 tests: every kit model loads, < 5 MB, ≤ 16 mesh nodes,
  sane bounds, stands on its origin; dock deck/beacon glass heights; model props get their
  light; light validation). 57 tests + smoke + launch pass. The smoke test's dock walk and
  burn-dressing checks run against the new models unchanged.
- LORE: Day 10 set-dressing canon (smokehouse, harbor boats, lantern posts; the Shingle Point
  wreck left as an explicitly *open* hook). TECH/ROADMAP updated.

Screenshots (`docs/screenshots/2026-09-28-dressing-*.png`): `before-saltmarrow` vs.
`after-saltmarrow`, `before-shingle` vs. `shingle-wreck`, `harbor`, `mara-door-lantern`
(gull burn + ferry lantern: stool, cups, signal lantern, dock, rowboat), `gulls-head-beacon`
(lit lantern room + fences), `kit-lineup`.

**Decisions**
- **A separate `build_dressing.py`** rather than growing `build_props.py`: the kit is 22
  pieces with its own helpers (beams, nets, hulls, merging); it imports `build_props` for
  the palette and primitives so there is still one palette. `build_dressing.py name …`
  rebuilds single pieces.
- **Lights live in region data, not in the .glb.** glTF light import changes units between
  Blender and Godot and has no range; an explicit `light` field is predictable and
  testable. Only the ferry lantern and the beacon have real lights; street lanterns and the
  smokehouse vent are emissive only, to keep the light budget for the atmosphere pass.
- **Replacement models keep their shape's dimensions**, and the region entries keep `shape`
  as the fallback, so the conditional-prop tests and the smoke test didn't need changing.
- **Tint variants are separate exports** (`_pine` nets) instead of a material-override hook,
  for now (logged).

**Problems / notes**
- The first moored-boat pass had its foredeck and stripes wider than the pointed bow (boxes
  placed by eye); rebuilt them from the hull's own stations.
- Joined beams kept their quaternion rotation mode, so the upturned boat's `rotation_euler`
  flip silently skipped the gunwale rail (a red arc floating over the beach). Fixed by
  resetting the joined object's rotation mode; caught in a close-up screenshot, not by
  tests.
- An over-broad slice while refactoring the hull code deleted four builders; the next
  Blender run failed loudly (`NameError`) and they were restored before anything was
  committed.

**Next run should**
1. **The Greying v1** ([S], ROADMAP #1) — systems are due; or the ferry's arrival ([C],
   Alpha) if content feels more urgent (last content: Day 9, so either is within the rules).
2. Art is next due by Day 12: Atmosphere & lighting (ROADMAP #2).

## 2026-09-28 09:00 UTC — Day 9: Saltmarrow after the burn (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **Saltmarrow after the burn** (ROADMAP [C] #1). The Act I choice now shows in the world,
  not only in dialogue:
  - **Dunstan's stool** (the one Mara's `lit_gull` scene mentions) now exists by her door,
    with an inspectable that tracks what she knows: a stranger's dent → "Dunstan's stool" →
    set square facing north once she knows he chose → the returned whittled gull sitting on
    it. After the `gull` burn, **two cups** appear beside it (one full and cold), and the
    description no longer names anyone.
  - **Drying nets** appear in the village once the beacon is lit (the lofts are reachable
    again). Normally whole nets, each begun at the same corner with the founding knot; after
    the `knot` burn they're **begun from the middle** (small patches on bare frames), and
    someone has tried and cut away a corner knot seven times.
  - **Pell's lost things** (the crates next to Pell on Shingle Point) are now inspectable: the
    pebble in its wool nest, or the nest pressed to its shape while you carry it, or — after
    the `pebble` burn, if Pell lent it — an empty nest nothing may touch ("DONT MOVE THE
    NEST"). A green glass chip marked FERRY appears once the lantern is up.
  - **Ferry-lantern reactions:** Pell begs to come on the ferry — promise / refuse / defer,
    recorded in the new `future` flag `saltmarrow_pell_ferry_ask` for the ferry's arrival.
    Tam explains **Tidewright deed-fares** (you pay the lanes a deed; the lit Gull weighs)
    and warns knot-burners that net-making crews may resent the cost.
  - **Mara reads the Keeper's sleeve-ember** once (new flag `saltmarrow_mara_saw_sleeve_ember`):
    Keepers are buried in those robes; hide it from Tidewrights, who blame the Keepers.
- **Engine:** procedural prop shapes `stool`, `cups`, `net_rack`, `net_frame`;
  `Region.shown_conditional_props(shape)` filters by shape.
- **Tests:** new `test_aftermath.gd` (9 tests: per-burn conditional dressing, the new shapes
  build, stool/nets/lost-things per state, Pell's three answers and one-time ask, Tam's fare
  with/without the knot line, Mara's one-time sleeve-ember). The smoke test now checks the
  lantern, beacon light and burn-specific nets/cups by shape — its old "exactly one
  conditional prop" check broke as soon as the nets existed. 53 tests + smoke + launch pass.
- LORE: Day 9 canon (stool, nets and the founding knot, Pell's nest, Tidewright deed-fares,
  Tidewright/Keeper distrust, Pell's ferry ask). TECH/ROADMAP updated.

Screenshots: `docs/screenshots/2026-09-28-gull-two-cups.png` (gull burn: stool + two cups by
Mara), `…-knot-net-frames.png` (knot burn) vs. `…-drying-nets.png` (any other burn).

**Decisions**
- **One prop per burn, plus one inspectable that reads the flags**, rather than three
  separate objects per burn: fewer ids, and one dialogue per thing keeps each description's
  whole history (before/after, told/untold) readable in one file.
- The stool is always present (it was already canon in Mara's dialogue); only the cups are
  burn-gated. Nets come out after *any* burn, since the lofts reopen either way.
- Pell's ask is recorded now so that the ferry arrival has a real choice to honour; its
  payoff is logged under Milestone 2's "Ferry arrives".
- New dressing is procedural (like the signal lantern) so this content session didn't
  depend on the art pipeline; Blender versions belong to the dressing kit next.

**Problems / notes**
- The first gull screenshot put the camera inside a house's roof (the slate house at
  13, 5); moved the camera.
- The ALSA "Unknown PCM default"/`ERR_CANT_OPEN` lines in Xvfb screenshot runs are the
  sandbox having no sound device — harmless, and not part of `run_checks.sh`.

**Next run should**
1. **Art is due** (cadence rule: Day 7 was the last [A]): the **Saltmarrow dressing kit**
   (ROADMAP #1) — include Blender versions of the stool, cups and net racks/frames.
2. Then The Greying v1 ([S]) or the ferry's arrival ([C], Alpha) — the ferry must honour
   `saltmarrow_pell_ferry_ask`.

## 2026-09-27 21:00 UTC — Day 8: Polish & tech-debt pass

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **Walkable dock (piers).** New `ground.piers: [{rect, deck}]`: collider vertices inside a
  pier are raised to the deck instead of the shore wall, and those cells count as walkable,
  so the wall still rises along the pier's sides and end. `Region.place`/`ground_y` stand
  content on the deck (`TerrainField.surface_at`) — ready for the ferryman. Saltmarrow's dock
  moved 1 m inland so it meets the walkway, and Mara stepped aside (7.8, 10.4) instead of
  blocking its head. Validator: pier rects on grid lines, deck above water, pier reachable.
  `terrain_map.gd` draws decks as `=`.
- **Live refresh for conditional NPCs, pickups and objects** (props and fog already did):
  `Region` tracks every `if` entry of any kind (and all pickups, which vanish once
  collected) and `refresh_conditional()` adds/removes them when a flag or quest changes.
  Unblocks "Saltmarrow after the burn" (people appearing/leaving mid-visit).
- **Shared UI Theme** (`UiTheme`): palette colours, font sizes and the ink/ember panel in one
  `Theme` set on each UI root; widgets choose type variations (SPEAKER, HEADING, HINT,
  HUD_TOAST…). `UiTheme.set_text_scale()` rescales every font live — the hook for the text
  size setting. ~35 per-widget overrides removed.
- **Tests**: `fresh_state`/`play_dialogue` helpers moved into `TestCase` (three copies of the
  dialogue driver in the burning/confession tests collapsed into one). New tests: pier
  decks + pier validation (`test_terrain.gd`), `test_ui_theme.gd`. Smoke test now walks the
  player out along the dock with real input (reaches z≈17.8 on the deck at y 0.275) and
  sideways into its wall, and checks conditional NPC/pickup/object probes appear and vanish
  live through the real flag signals (verified it fails with the refresh disabled).
  44 tests + smoke + launch pass.

Screenshots: `docs/screenshots/2026-09-27-beacon-lit.png` (the lit lantern room, via
`--flags`/`--quest` + `--camera` — closes that polish item), `…-saltmarrow-dock.png`,
`…-themed-dialogue.png`.

**Decisions**
- **Piers are terrain data, not a prop collider.** The shore wall lives in the terrain
  collider, so only the terrain can open a hole in it; and the validator's on-foot
  reachability needs to know the deck is there. The dock *visual* stays a separate prop so
  the coming Blender dressing kit can replace it without touching terrain.
- Panels unified to one style (dialogue was 0.92 alpha / radius 6, journal 0.96 / 8 → both
  0.94 / 8). Layout spacings stay local to each UI; only look-and-feel moved to the theme.
- Pickups are now always tracked by the conditional refresh, so a pickup whose `if`
  becomes true mid-visit appears without re-entering the region.

**Problems / notes**
- `git checkout <file>` while testing a deliberate break reverted an uncommitted edit —
  caught by the diff before committing. (Commit before sabotage-testing.)
- The HUD's "[J] Journal [I] Satchel" hint sits under the dialogue panel's bottom-left
  corner (visible in the dialogue screenshot) — small, logged.

**Next run should**
1. Content is due (last content was Day 6): **Saltmarrow after the burn** (ROADMAP #2) now
   that conditional NPCs refresh live — or go straight for the dressing kit if the art
   cadence rule demands it (Day 7 was art, so content first is within the rule).
2. Then the Saltmarrow dressing kit ([A]).

## 2026-09-27 09:00 UTC — Day 7: Terrain (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **Sculpted terrain** (ROADMAP [A] #1). Regions take a `ground` block: a height grid built
  from `land` features (rect / ellipse / path-ramp, each with a smoothstep `falloff`,
  max-combined over a seabed), per-vertex `roughness`, and `ragged` coastlines (smooth noise
  on the signed edge distance). New `TerrainField` (pure logic: heights, walkability,
  flood-fill reachability) and `TerrainBuilder` (flat-shaded, vertex-coloured mesh coloured
  by paint zones → cliff slope → seabed → shore band → ground; trimesh collider in which
  sea vertices become an invisible **shore wall**; a wide seabed plane so the grid edge
  never shows).
- **Ground-relative placement**: with `ground`, every y in the region is an offset above the
  surface; props can opt out (`"snap": false`) for the dock and a stilt house in the water.
- **Regions re-sculpted** (legacy slabs removed; still supported by the engine):
  - *Shingle Point*: a curved beach shelving into the sea, a spit hooking round to the east
    (finally a "point"), dunes rising to the north, the slate outcrop with the humming
    pebble raised on it.
  - *Saltmarrow*: village terrace with two low hills, the harbor basin to the south-east
    enclosed by a breakwater spit, one stilt house moved onto the harbor edge standing in
    the water, a causeway neck north to the loft yard.
  - *Gull's Head*: the net-loft flats, and the headland raised to a 2.8 m cliff-edged
    tableland reached by a single ramp between the gate posts.
- **Validator**: every spawn, NPC, pickup, object and exit must be reachable on foot from the
  default spawn; walkable ground must not touch the grid edge; malformed features and bad
  colours are errors. It caught a real bug on the first try (the ramp met the headland
  0.9 m short, stranding the beacon).
- **Debug tools**: `tools/debug/terrain_map.gd` prints an ASCII walkability map per region;
  `--camera=x,y,z:tx,ty,tz` for fixed overview screenshots.
- **Tests**: new `test_terrain.gd` (7 tests). The smoke test now checks the player lands on
  the ground at each spawn and NPCs stand on it, then **walks the player up the Gull's Head
  ramp with real input and physics** (reaches y≈2.75 on the headland) and into the shore
  wall (stays dry). 40 tests + smoke + launch pass.

Screenshots: `docs/screenshots/2026-09-27-before-gulls-head.png` →
`…-after-gulls-head.png`, `…-gulls-head-ramp.png`, `…-saltmarrow-overview.png`,
`…-shingle-point-overview.png` (Compatibility renderer, washed out as usual).

**Decisions**
- **Terrain in Godot from data, not Blender .glb.** Heights are needed at runtime (snapping,
  the reachability check) and content sessions can reshape a region in JSON. Blender stays
  for props/characters. Recorded in TECH "Ground".
- **Shore wall instead of invisible boxes**: raising sea vertices in the collider makes the
  coastline itself the play boundary, with no extra data to maintain.
- **Max-combined features** (no "dig"): simple and predictable; the harbor is made by
  leaving a gap in the land rather than carving it.
- Moved one Saltmarrow stilt house from inland (9, −4) to the harbor edge, per the
  roadmap's "stilt-lined waterfront". No NPC depended on it.

**Problems / notes**
- First build rendered the ground invisible (triangles wound counter-clockwise → culled);
  a test now asserts every ground normal faces up.
- The dock is over the sea behind the shore wall, so it isn't walkable yet — added to the
  polish item (needed before the ferry arrives).

**Next run should**
1. **Polish/debt pass** (ROADMAP #1) — it's due (session 8 is the deadline), and includes
   making the dock walkable.
2. Then content (Saltmarrow after the burn, or the ferry payoff) and the dressing kit.

## 2026-09-26 21:00 UTC — Day 6: Aldous's confession (Act I close)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **Aldous's confession** (ROADMAP #1, content). After the Gull's Beacon is lit:
  - **Gentle** (`saltmarrow_aldous_approach=gentle`): he offers on the spot ("the cork's in
    the bottle, for once") or later from the hub. Full account: he kept the Hearthspire's
    east stair; the flame was put out on purpose by the High Keeper (unnamed — "names carry,
    in this fog"); he doesn't know why and never asked; **a small light went *down* the
    stair past him, cupped in someone's hands**; and "too soon" explained — the flame wakes
    someone when it *fails*, and it hadn't. He gives the **Keeper's Sleeve-Ember** (new
    `future` item for Act II Keepers). `saltmarrow_aldous_confessed=full`.
  - **Pressed / never asked**: he refuses once (go see what it cost them) — new flag
    `saltmarrow_aldous_balked` — and on the next visit the player can hold out their ember;
    he gives only the bare fact and "you came too soon". `…confessed=grudging`.
  - Either way he points at Cindermoor and the Tidewright ferry → new quest **Across the
    Grey** (`future`, Act II bridge). Mara explains the ferry hasn't run since the Snuffing
    and hangs the **green signal lantern** outside her door (new `signal_lantern` prop,
    conditional on `saltmarrow_ferry_lantern_hung`); stage "wait for the ferry's horn".
  - After confessing, "What happened at the Hearthspire?" gets a short recap instead.
- **Systems**: `--flags=a=b,c` / `--quest=id[:stage]` debug args (from the polish item) so
  late-game states can be screenshotted; validator accepts `future` on quests.
- **Tests**: new `test_confession.gd` (6 tests: hidden before the beacon, gentle full path
  + sleeve-ember + recap, deferring, pressed/unasked two-visit grudging path, Mara's lantern,
  lantern prop). Smoke test runs a third region pass and asserts the confession, the ferry
  stage and the lantern at Saltmarrow. 33 tests + smoke + launch pass.
- LORE: new canon section (Day 6); TECH/ROADMAP updated.

Screenshot: `docs/screenshots/2026-09-26-ferry-lantern.png` (Saltmarrow after the burn,
via `--flags`/`--quest`; the lantern is right of the player by Mara's crates).

**Decisions**
- **Reveal "a High Keeper", not the name or the motive.** LORE's mystery #1 is the
  long-term payoff; the stair light seeds mystery #2 without saying whose hands. Grudging
  players miss the stair light — the gentle choice from Day 1 now pays off in *information*
  as well as a key item.
- **The "pressed" gate is a second visit, not a Remnant check**: after the burn the player
  may hold no Remnant at all, so "show him your ember" is always possible and on-theme.
- **Across the Grey is an intentionally unfinishable quest** (`future: true`) — it is the
  Act I → Act II bridge. It's the only open thread; pay it off (ferry arrives) before
  opening further hooks.
- Lantern moved from the dock to Mara's door: at the dock it sat behind the camera and no
  player would ever see it.

**Problems / notes**
- First cut of `--flags` truncated values at the second `=` (`get_slice`); fixed.
- The moss glow reads nearly white in the Compatibility renderer (known issue logged).

**Next run should**
1. Per the art cadence, **Terrain** (ROADMAP [A] #1).
2. Polish/debt pass is due by session 8 (ROADMAP #5), then the Greying v1.

## 2026-09-26 09:00 UTC — Day 5: Characters (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **Characters** (ROADMAP [A] #1, the owner's art-track request). New
  `tools/blender/build_characters.py`: one chunky base body (big head and hands, short
  legs, simple ink-dot face) plus costume pieces per character, exported to
  `assets/models/characters/*.glb` (700–900 tris, 62–77 KB each):
  - **Wakebearer** — deep abyss hooded cloak, ember-clasped collar, the ember glowing in a
    raised right hand over a scorched cuff.
  - **Mara** — broad, heavy dark coat with belt and buttons, coal-red scarf with a hanging
    tail, grey hair in a bun, heavy brows.
  - **Pell** — child-sized (0.78), oversized slate cap with a coal button, patched ochre
    jacket, net-needle held point-up, cocky head tilt.
  - **Aldous** — floor-length faded Keeper robe with the dull stitched ember on the chest,
    rope belt, grey fringe and beard, green bottle, a forward stoop.
  - **Tam** — tide oilskin and wide-brimmed sou'wester, tall iron-tipped gate pole.
  - **Hesk** — seated on a stool, moss shawl, long white plait, a greyed net with cords
    across her knees, head bowed to the work.
- **`CharacterRig`** animates the models procedurally (no skeletons): breathing, sway,
  head drift; a walk swing on the player driven by speed; Hesk's `mend` idle works her
  hands. Rest poses are authored in Blender and preserved.
- Data: NPCs gained optional `model` + `idle`; `game.json` gained `player_model`. The
  primitive bodies remain as the fallback. Validator checks both; player now starts facing
  away from the camera.
- Debug: `scenes/debug/character_lineup.tscn` (every character side by side, `--closeup`,
  `--screenshot=`) for art review.
- Tests: new `test_characters.gd` (4 tests: rig contract for every model, pose/rest,
  fallback, validator). Smoke test asserts the player and every NPC show their rigged model.
  27 tests + smoke + launch pass.

Screenshots (Compatibility renderer, so washed out — see ROADMAP colour-grading item):
`docs/screenshots/2026-09-26-before-saltmarrow.png` → `…-after-saltmarrow.png`, and
`docs/screenshots/2026-09-26-character-lineup.png`.

**Decisions**
- **Procedural rig over skeletal animation.** Six characters with only idle/walk needs
  don't justify armatures, skin weights and animation tracks per model; a node-hierarchy
  contract (Rig > Legs, Torso > Head, Arms) keeps the Blender script short, the .glb small,
  and motion tunable in GDScript. Revisit if characters need gestures or cutscene acting.
- **Tonal shades of palette colours** are allowed for characters (e.g. `slate -30%` for
  Mara's coat) — the pure 12-colour palette made every costume look the same.
- Hesk's shawl is moss rather than silverfog: an all-grey Hushed woman vanished into the fog
  colour; the greyness now lives in her hair and net.
- Tri budget came in under the roadmap's 1–2k; that's headroom, not a target.

**Problems / notes**
- First export had every arm pointing up: joined Blender objects keep the first primitive's
  rotation, which the rest-pose assignment then overwrote. Fixed by baking rotation/scale
  per primitive (`_finish`); noted in TECH.
- NPCs still don't face the player when spoken to, and the ember light doesn't follow the
  arm; logged in ROADMAP known issues.

**Next run should**
1. Aldous's confession & Act II hook (ROADMAP #1, content).
2. Then per the art cadence, Terrain (ROADMAP #2) the session after. Polish/debt pass due
   by session 8.

## 2026-09-25 21:00 UTC — Day 4: The Burning

**Did**
- Tooling: `tools/setup.sh` worked first try again (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **The Burning choice** (ROADMAP #1) — *A Light for Saltmarrow* can now be completed.
  The beacon's cradle offers every Remnant the player carries, each behind a "weigh it"
  step that spells out the cost, with "No. Not this." to back out and "Not yet." to leave:
  - **Humming pebble** (lullaby). If it was given to Pell, Pell must be asked in person and
    can be refused on their behalf (`saltmarrow_pell_lent_pebble`).
  - **Remembering Knot** (founding knot).
  - **Dunstan's Whittled Gull** — new item. Mara, if she has told you of Dunstan, can be
    asked to give her memory of him; she holds the gull in the fog at the gate until it
    becomes a Remnant (`saltmarrow_mara_offered_gull`).
  - Burning sets `saltmarrow_beacon_burned` = `pebble|knot|gull`, completes the quest and
    lights the lantern room.
  - Waiting-state hints point at Pell / Mara when those Remnants aren't in hand yet.
- **Aftermath lines**: Mara (one-time scene per burn — no song / no beginning / no brother,
  "two cups"), Pell, Hesk (stops humming if the knot burned), Tam, Aldous (reacts per burn,
  promises his story). Lent Remnants that weren't burned can be handed back.
- Aldous now explains Remnants can be *made on purpose* ("We Keepers knew that trick…
  far too well") — new canon, foreshadows mystery #1. LORE updated.
- **Systems**: region `fog.overrides` (first matching condition wins) resolved by new
  `RegionMood`; props accept `if`; both re-evaluate **live** on any flag/quest change, and
  fog tweens over 4 s so the player watches the Greying lean back after the burn. All three
  Saltmarrow regions thin once the quest is done. New `beacon_light` prop shape.
- Validator: fog override conditions/density/color and prop `if` conditions + self-test.
- Tests: new `test_burning.gd` (6 tests driving real story JSON through every burn path).
  Smoke test now asserts the menu walk relit the beacon, the light prop shows and the
  fog thinned. 23 tests + smoke + launch pass. The long-standing "quest never completes"
  validator warning is gone.

**Decisions**
- **Three options, not four**: Pell's pebble counts as the Pell option (via consent) rather
  than a separate "Pell's memory of their parents" Remnant — LORE's list was "e.g.", and
  three well-written costs beat four thin ones.
- **Mara's option needs her consent in person and an object**: Remnants are physical in
  canon, so the memory had to condense into something. That produced the "made on purpose"
  rule, which neatly seeds the Keepers' secret without revealing it.
- **The Wakebearer forgets the burned memory too.** Keeps the cost real for the player.
- **Aldous's confession deferred** to its own session (now ROADMAP #1): it's Act I's
  closing beat and deserves the same care as the burn.

**Problems / notes**
- The lit lantern room (`beacon_light`) is only asserted by tests, not eyeballed: there is
  no debug arg to start with a finished quest. Added a `--flags`/`--quest` debug arg to the
  polish item.
- The smoke test always burns the first listed Remnant (pebble); the other paths rely on
  unit tests.

**Next run should**
1. Aldous's confession & Act II hook (ROADMAP #1).
2. Then The Greying v1 (fog drain meter). A polish/debt pass is due within ~4 sessions.

## 2026-09-25 09:00 UTC — Day 3: Gull's Head (net-lofts & headland)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2 from GitHub/PyPI).
  Baseline checks green before starting.
- **Gull's Head** (ROADMAP #1): new region north of Saltmarrow — boardwalk through four
  greyed net-lofts to the headland, denser fog (0.045), the Gull's Beacon moved here from
  the village. Saltmarrow's north end is now a boardwalk gate with two net-loft silhouettes
  behind it.
- **Gated exits**: exits accept `requires` (condition) + `locked_text`. The boardwalk gate
  needs `item:harbor_token`; without it Tam's refusal is toasted. `harbor_token` is no
  longer `future` — it is now read.
- **Inspectable objects**: region `objects` start a dialogue with no NPC. The beacon uses it.
- Content: **Tam Hollis** (Tidewright gate guard), **Old Hesk** (Hushed netmender — first
  Hushed character on screen), **Remembering Knot** Remnant (Saltmarrow's founding knot),
  `gulls_beacon` dialogue that advances *A Light for Saltmarrow* to a new stage
  `feed_the_beacon` and reflects what the player carries/knows. Hesk saw Dunstan leave
  *laughing*; telling Mara lets her realise he went willingly (2 new flags). Aldous has a
  new line once you've seen the cradle (warmer if you were gentle with him).
- Blender: `net_loft.glb` (19 KB) added to `build_props.py`; other models re-export
  byte-identical.
- Tests: validator checks objects (unique id, prompt, dialogue ref, condition) and gated
  exits (condition ref, `locked_text` required) + a new self-test. Smoke test now verifies
  gated exits refuse travel on a new game and allow it at the end, examines every object,
  and asserts the beacon stage is reached. 16 tests + smoke + launch pass.

**Decisions**
- **Beacon moved into its own region** rather than being reachable from the village: it
  makes the Token matter and gives the Greying v1 a dense-fog test bed.
- **Stage stops at `feed_the_beacon`** with only a "Not yet." option: the Burning choice is
  the emotional peak of Act I and deserves its own session with all options wired
  (pebble/Pell, knot, Mara's memory). Better an honest pause than a rushed choice.
- The Remembering Knot realises LORE's "village's founding song" option as the founding
  *knot* (craft instead of song — fits a net-making village and Hesk). LORE updated.
- Regions stay flat: the player can't climb and slabs can't slope, so the "headland" is
  marked by moss ground and the beacon, not height. Logged as debt.

**Problems / notes**
- Smoke test flake-in-waiting found and fixed: `Input.parse_input_event` from a coroutine
  resumed on a physics frame isn't seen until two process frames later; the journal check
  now waits two frames.
- Expected validator warning remains: `a_light_for_saltmarrow` never completes.

**Next run should**
1. The Burning choice at the Gull's Beacon (ROADMAP #1) — replace "Not yet." in
   `story/gulls_beacon.json` `waiting`, complete the quest, set `saltmarrow_beacon_burned`,
   make fog recede via flag-driven region fog.
2. Then The Greying v1 (fog drain meter), using Gull's Head.

## 2026-09-24 — Day 2: Quest journal & Satchel

**Did**
- Confirmed CI green on `15719bd` (run #2) and `tools/setup.sh` still works (Godot 4.7.2 and
  bpy 5.2.2 both downloaded directly this time; no Docker fallback needed).
- **Quest journal + Satchel** (ROADMAP #1–2), one two-tab panel: `J` / gamepad View opens the
  Journal, `I` / gamepad Y the Satchel; pressing the same key again or Esc/B closes it.
  - Journal: active quests (newest first) then completed ones; detail pane shows the
    description, the current objective highlighted, and passed stages struck through.
  - Satchel: Remnants first (ember-colored), then key items, then oddments, by name;
    stack counts; kind label + description in the detail pane.
  - Refreshes live if a quest/item changes while open; locks player input like dialogue,
    and refuses to open over an open dialogue.
  - Small `[J] Journal  [I] Satchel` key hint in the HUD corner.
- `JournalModel` (pure logic) holds all ordering/text rules; `JournalUI` only renders.
  4 new unit tests (ordering, stage history, save round-trip keeps order, empty state).
  Smoke test now drives both tabs with real `InputEventAction`s and checks they mirror
  world state and that Esc unlocks input. 15 tests + smoke + launch all pass.

**Decisions**
- **One panel, two tabs** rather than two screens: fewer modals to juggle, and the future
  pause menu can add tabs (Map, Settings) in the same frame.
- **"Satchel"** as the player-facing name for inventory — fits the Wakebearer's
  travelling-pilgrim tone; code/actions still say `inventory`.
- Quest recency comes from `WorldState.quests` insertion order instead of a new
  timestamp field, so no save-format change was needed (verified by test).
- Avoided glyphs like ✓/▸ that Godot's default font may lack; used "(done)" and "•".

**Problems / notes**
- UI styling is duplicated as per-widget overrides across dialogue/HUD/journal; logged as
  tech debt (shared `Theme` resource) before the settings menu adds text-size scaling.

**Next run should**
1. Content: the net-lofts & headland zone gated by the Harbormaster's Token, and advance
   *A Light for Saltmarrow* at the Gull's Beacon (ROADMAP #1). Someone must actually give the
   token (Mara, after the Aldous conversation) — remove `future` from `harbor_token`.
2. Then The Greying v1 (fog drain meter) if time allows.

## 2026-09-24 — Day 1: Foundation

**Did**
- Wrote the vision: `GAME_DESIGN.md` (Emberwake — a Wakebearer carrying a living ember
  through the memory-eating fog of the Lanternreach; pillars, loop, palette), `LORE.md`
  (world, factions, Saltmarrow cast, Act I–III outline, five long-term mysteries with
  secret answers), `ROADMAP.md`, `TECH.md`.
- Toolchain: `tools/setup.sh` installs Godot 4.7.2 (official build) and Blender 5.2.2 as the
  `bpy` PyPI module into `.tools/`. Download sources were partly blocked in the sandbox
  (godotengine.org, download.blender.org); GitHub release downloads worked; a Docker Hub
  fallback for Godot is scripted in case they don't next time.
- Godot project: autoloads `Content`, `GameState`, `SaveSystem`; pure-logic core
  (`ContentDatabase`, `WorldState`, `Conditions`, `DialogueRunner`, `ContentValidator`);
  third-person player with orbit camera and interaction sensor; data-built regions
  (terrain slabs, water, props, NPCs, pickups, exits); dialogue box and HUD; F5/F9
  quicksave/quickload.
- Content: Shingle Point (start) and Saltmarrow; Pell, Mara Tollen, Brother Aldous with
  branching dialogue; quests *Lost Things* (complete, with a give/keep choice on the humming
  pebble Remnant) and *A Light for Saltmarrow* (first two stages); 7 story flags.
- Blender: `tools/blender/build_props.py` → pine tree, rock cluster, stilt house, Gull's
  Beacon (.glb, 8–17 KB each). Every prop also has a procedural fallback shape.
- Tests: custom headless runner (11 tests) incl. content-link validation, orphan detection,
  dialogue termination on all paths, and a validator self-test with deliberately broken
  links; plus a smoke test that plays the real main scene (intro → every region twice →
  every NPC → pickups → save/load round-trip). `tools/run_checks.sh` runs everything and
  fails on any Godot `SCRIPT ERROR`/`ERROR:` output. CI workflow added; its first run caught
  a benign `Unable to load fontconfig` engine error in the container, now allow-listed.

**Decisions**
- **Custom JSON dialogue instead of Ink.** godot-ink needs Godot .NET; compiling .ink needs
  inklecate (.NET). Our format mirrors Ink's knots/choices/conditions and is fully validated.
  Recorded in TECH.md.
- **Custom test runner instead of GUT.** No addon download needed, ~40 lines, sufficient now.
- **Scenes built in code from data** so content never needs `.tscn` edits and diffs stay
  readable.
- **Flags must be declared** in `data/flags.json`; the validator errors on undeclared or
  never-set flags, and warns on never-read ones unless marked `future`. This is how we keep
  "choices matter later" honest.

**Problems / notes**
- Screenshots are only possible with the OpenGL Compatibility renderer under Xvfb; it looks
  washed out/over-bright. Lighting was toned down but a real-GPU color pass is on the roadmap.
- Expected validator warnings: `a_light_for_saltmarrow` never completes yet.

**Next run should**
1. Confirm CI (`.github/workflows/checks.yml`) is green on the latest commit; fix if red.
2. Build the Quest journal (J) and Inventory (I) panels (ROADMAP #1–2).
3. Then content: net-lofts + headland path gated by the Harbormaster's Token (ROADMAP #3).
