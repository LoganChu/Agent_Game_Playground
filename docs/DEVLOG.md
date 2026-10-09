# Emberwake — Dev Log

Newest entries first. Each entry: what was done, decisions & why, problems, next steps.

## 2026-10-09 09:00 UTC — Day 31: Polish/debt pass three

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; checked out
  `main` (already at `origin/main`, Day 30's `a46cee7`). Baseline green (219 tests + smoke + launch).
- **Polish (due today; last pass Day 23):** ROADMAP *Next up* #1.
  - **`fen_ember` shows, not just tells.** Hesper says "don't hold it up to anyone's face. They've a right
    not to look" — now they don't: the three **Unmoored by the pools turn their faces away** from a bare
    ember when you come within 6 m (shoulders, then the head, to the side away from you; the chin drops),
    slowly, and drift back to the water when you go. Cupped, nobody turns. Engine: figure props take
    **`averts`** (`{"if": <condition>, "radius"?}`), layered on top of the idle by `CharacterRig` (it finds
    the player by group and reads the world each frame); validated (figures only, declared flags, radius
    1..20, no stray keys).
  - **Corran on a bare ember** (two new conditional lines): glad of it ("Somebody in this fen ought to look
    at things"), and, asked about the Unmoored, what the turning is — "somebody halfway through putting a
    thing down, and you've shown them where it was." The cupped path is unchanged. LORE updated.
  - **The test suite was about to break the gate.** The tests step took **280 s of its 300 s** limit (it
    timed out once this session with every test passing). The runner now times each test: every validator
    test spent ~11 s re-validating, 8.6 s of it in `Greying.ember_cost_map` on the woods — a LIFO
    label-correcting search that re-relaxed cells over and over. Now **Dijkstra on a binary heap: 43 ms**,
    identical costs on every region (checked against the old search; max difference 6e-6 from the old
    tolerance). **Suite: 280 s → 26 s.** `run_tests.gd` prints each test's time and the slowest eight.
  - **Smoke walk** checks the look-away live in the fen (second sailing, before the walk: next to a figure,
    cupped → no turn, bare → turned, then puts the answer and the player back and lets the screen's grey
    ease so the later fog checks read exactly).
- **Tests:** `test_fen_dressed.gd` +2 (the look-away: the condition per answer, the aim, slow easing, the
  real model's head turning from the player and the chin dropping, nothing when cupped; validator `averts`
  checks); `test_fen_lane.gd` checks Corran's bare-ember lines; `test_greying.gd` +1 (the heap). 220 tests +
  smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-09-fen-unmoored-*.png`): `bare` (the Unmoored at the head of the long
walk with her head turned from the player and down) vs `cupped` (looking out at the Deeps as before).

**Decisions**
- **Figures only, not Hesper/Corran.** They are NPCs who face you to talk; an aversion on an NPC would fight
  `faces_player` and the conversation framing. Hesper already "steps back a pace" in words.
- **Slow, not a flinch.** 1.2/s easing, a turn of the head and a lowered chin: the Unmoored aren't hurt by
  the ember, they just have a right not to look (LORE). No turn when you're behind them — they're already
  not looking.
- **Fix the algorithm, not the timeout.** Raising the 300 s limit would have hidden a 200× slowdown that every
  new validator test multiplies.
- The smoke walk's Thornwold Oda gap stays a known issue: `_sail_the_fen_lane` covers the sailing, and
  reworking pass ordering for one NPC's lore lines isn't worth the risk to the walk.

**Problems / notes**
- The first smoke placement put the player in a pool (the figures face the water) and the region's
  out-of-water safety moved them back to the staithe; the check now picks a dry spot beside a figure.
- Standing in Stillhithe's thin Greying leaves the screen-grey (`Atmosphere._greying_look`) easing across a
  region change; the next smoke check (Gull's Head fog) read it. Worth knowing for any debug teleport.

**Next run should**
1. **Art (due Day 32, the every-other-session rule)** — ROADMAP *Next up* #1: Aldous seated on a bench by the
   Wrens' steps, the greyed net-lofts as the broken variant; the fen's white light if time.
2. Then *The Heron Light, part one* (content, due by Day 33).

## 2026-10-08 21:00 UTC — Day 30: The fen, dressed (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; checked out
  `main` and fast-forwarded to `origin/main` (`c5b365b`, Day 29's head).
- **Art (due today; last art Day 28):** ROADMAP *Next up* #1, *The fen, dressed*, all parts:
  - **The staithe** (`staithe`, new Blender model on the dock's footprint and deck top): silvered planks,
    every piling rising through the deck as a post with **a whittled gull on it, all facing out to sea**
    (LORE), a slimed ladder at the channel end, no bollard. The fen no longer borrows the Saltmarrow dock.
  - **The west walk** is a low fen **`boardwalk`** (2 × 6 m, same deck top): crosswise split planks on two
    runners, stubby pile pairs (foam rings on each), one plank gone and one sprung — no ladder, bollards
    or rail.
  - **The long walk** has boards laid on it going in (`plank_path`, four 3 m runs, no collider, mossed and
    askew), fading into the Deeps' fog.
  - **Corran's landing:** a moored, floating **`punt`** (flat-bottomed, raked ends, tarred, a quant pole
    and a trap lying in her) replaces the upturned Saltmarrow rowboat; **`eel_traps`** (two wicker traps in
    the grass, one stood on end against a stake).
  - **Dead alders** (`alder_snag`: crooked dark trunk on a root boss, three limbs silvering at the tips,
    bracket fungus) replace the three pine snags, plus three more standing in the pools.
  - **Reed beds** (`reed_bed`, 3 m of reed with buff plumes and bulrushes) along seven pool edges, each
    placed on the shoreline (the fen's banks drop steeply — the first guesses stood in a metre of water).
  - **The Unmoored sit by the pools:** two new seated characters, **`unmoored_shawl`** (a woman on a reed
    tussock, hands in her lap) and **`unmoored_coat`** (a man on an upturned eel basket, a cup in his
    hands), three placements on Stillhithe's edges facing the water. Engine: **figure props** — a region
    prop with an `idle` is a character model with a `CharacterRig` (no dialogue; validated: a character
    model, a known style, no `float`/`wading`). New idle **`still`**: slow shallow breath, quiet hands, the
    head drifting down to look into the water and, sixteen seconds later, up again — no start, nothing
    calls them back (unlike Hob's `sit` doze). The character lineup lists figures as "(figure)".
  - **Mirror-still water:** a region **`water`** block (`swell`, `wash`, `foam`, `mirror`, `shallow`/`deep`/
    `sheen` colours; validated ranges) tunes the water shader; new `wash_strength` and `mirror` uniforms
    (a fresnel-ish blend toward the sky colour, glossier). The fen: swell 0.15, no wash, half foam, mirror
    0.6, pine shallows over ink depths — the pools now lie flat and silver instead of a choppy blue sea.
  - **The Heron's skiff reads:** pale boards, a bone gunwale and an oar across it, sitting higher — a pale
    shape at the legs' feet from the long walk.
  - **Hesper:** two dark locks fallen out of the shawl, its point down her back, a fringe at the shoulders.
    **Corran:** a bigger woven creel (hoops, a lid, an eel's tail over the rim, two shoulder straps).
- **Tests:** `test_fen_dressed.gd` (9): the staithe's deck height and gulls, the boardwalk (nothing over the
  deck, pier width, a foam ring per pile, walkable to the letting post), the boards on the long walk going
  into the fog, Corran's punt afloat in deep enough water and the traps on dry ground, alders/reed beds at
  the water's edge, the Unmoored (dry ground, reachable, facing the water, off the trodden way, out of
  everyone's way, built with a `still` rig), the `still` idle on the real model (head down, legs put), the
  water settings reaching the shader (and the sea elsewhere unchanged), the pale skiff, validator checks.
  `test_dressing` exempts the staithe/boardwalk from "stands on its origin" like the dock. 217 tests +
  smoke + launch pass. Checkpoint `glasswater_fen` re-shot.

Screenshots (`docs/screenshots/2026-10-08-pm-fen-*.png`): `staithe` vs `staithe-before`, `westwalk` vs
`westwalk-before` (the boardwalk, the mirror pool, the Unmoored by it), `gulls` (on the posts), `unmoored-west`,
`unmoored-east`, `corran` (punt, traps, alder), `longwalk` (the boards into the fog), `skiff`, `lineup`
(Hesper, Corran and the two Unmoored in the fen's light).

**Decisions**
- **Figures are props, not NPCs.** The Unmoored by the pools have nothing to say (Stillhithe's one rule);
  making them NPCs would put names and "[E] Talk" over them. A prop with an `idle` reuses the rig and the
  validator and costs nothing at runtime beyond the rig.
- **`still`, not `sit`.** Hob's doze ends with a start — he's pulled back. The Unmoored aren't: their head
  goes down to the water and comes up slowly, on its own time.
- **Water as data, not a second shader.** One water shader with region settings keeps Saltmarrow's sea
  untouched (defaults = the old look; tested) and lets the Deeps or a future tarn tune their own.
- **The staithe keeps the dock's deck top and pier rect** (the replacement rule), so nothing walkable moved;
  the boardwalk stays 2 m wide because piers must lie on the ground grid (the validator said so).

**Problems / notes**
- The validator rejected a 1.8 m pier rect (piers must sit on the 1 m ground grid); the boardwalk is 2 m.
- The mirror water reads very pale from above in Compatibility (fog + sheen); the peat-dark shows only
  looking down steeply. Judge with the Vulkan colour pass (mirror 0.6 may want 0.4 there).
- The first gull build looked every which way; LORE says they all face out to sea — rebuilt to match.

**Next run should**
1. **Polish/debt pass three (due Day 31)** — ROADMAP *Next up* #1.
2. Then *The Heron Light, part one* (content, due by Day 33).

## 2026-10-08 09:00 UTC — Day 29: The fen lane (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; fetched
  `origin/main` and fast-forwarded `main` to Day 28's head (`3687f43`). Baseline green (198 tests + smoke +
  launch).
- **Content (due by Day 31; last content Day 27):** ROADMAP *Next up* #1, *The fen lane — Act II goes on*:
  - **The sailing.** Once the Ridge Light is lit, Oda offers "Sail north-about to Glasswater Fen." on
    Thornwold: the Ridge Light dead astern, the reeds breathing, fog that hangs instead of drifting (later
    sailings are one line). `lanes_ferry_at` gains `fen`; from the fen Oda runs back to Thornwold only
    (lanes run light to light). Saltmarrow's ferry/Oda placements now exclude `fen` too.
  - **New region `glasswater_fen` (Glasswater Staithe):** a plank staithe with a whittled gull on every post,
    a dyke north to **Stillhithe** (three new Blender **reed houses**, a thin Greying the Unmoored live in on
    purpose, ground gone fog-coloured), mirror-still pools, a west walk to the **letting post**'s islet,
    Corran's eel landing, and the **long walk** north into **the Deeps** (deep Greying), where **the Heron
    Light** stands dark on four legs out in the mere (new Blender model, iron heron vane, the keeper's skiff
    tied to its legs). Arrival scene `fen_arrival`.
  - **Hesper Vail** (Unmoored, staithe-warden; new Blender character): asks you to **cup the ember** ("It
    doesn't hurt. It reminds.") — `fen_ember` cupped/bare; Stillhithe's one rule (nobody asks what you came
    to put down); the ember "puts the coat back on".
  - **Corran Teal** (last of the fen folk; new Blender character): why the fen folk left; the Unmoored
    filling his fen ("pools never used to hold a face that long" — mystery #3, unexplained); **the Heron
    Light's keeper poled out the night of the Snuffing and the light went out out there**; *A Light for
    Glasswater* begins (open — he'll pole you out "when I've decided whether I like you").
  - **Dunstan's thread:** his Saltmarrow rowboat at the staithe (inspectable; Oda knows a Tollen stem),
    the gulls he paid his mooring in, **the name he left with Hesper to keep**, the long walk "with a lantern
    that wasn't lit — it's for after". Side quest **The Letting Post**: tie on **Mara's word** (if she sent
    one), **word of your own**, or **leave nothing** (`fen_dunstan_word`; the post shows a sailcloth knot with
    a red cord — `letting_post_word`). After the `gull` burn his name slides off the Wakebearer.
  - 2 NPCs, 2 quests (one open), 8 flags, 5 new dialogues + Oda extended; checkpoint **`glasswater_fen`**.
- **Blender:** new `tools/blender/build_fen.py` (`reed_house`, `letting_post` + `_word`, `heron_light`);
  `build_characters.py` gains `hesper` and `corran` (~800 tris each).
- **Tests:** `test_fen_lane.gd` (9: the sailing only once lit, the lane both ways; the ferry/Oda in exactly
  one port; the fen's layout — staithe clear, Stillhithe thin, the Deeps deep and walkable into, every NPC
  and object reachable, the Heron out of reach; Hesper and the ember; the letting post three ways and "not
  yet"; the gull-burn variant; Corran and the Heron; the models). The smoke walk now **sails the fen lane
  twice** after its passes (`_sail_the_fen_lane`, choosing Oda's option by text) and checks the beats.
  `test_dressing` allows the Heron Light's height. 207 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-08-fen-*.png`): `staithe-hesper` (from the staithe: Hesper at its
foot, Dunstan's rowboat, Oda and the Slow Mercy), `stillhithe` (the reed houses, the Heron Light behind in
the fog), `letting-post`, `corran`, `folk-lineup` (Hesper, Corran, Oda); checkpoint
`docs/checkpoints/glasswater_fen.png`.

**Decisions**
- **Dunstan glimpsed, not met.** Mystery #5's payoff is big; this session lays the trail (boat, gulls, the
  kept name, "it's for after") and a choice that will matter when he is found. Meeting him belongs in the
  Deeps, later.
- **The letting post honours the theme both ways.** Leaving nothing completes the quest as fully as tying
  on a word: the right to forget is a real answer, and Hesper says so.
- **Hesper keeps his name** (Hesk's "come back for his name" made literal) — a hook for whether the
  Wakebearer, the Unmoored or Mara gets to decide what Dunstan remembers.
- **The Heron Light's quest opens but doesn't advance** (marked `future`): the fen's main line needs the mere
  (a punt, the Deeps), which is a session of its own. It is the one new open thread; the colliers and the
  Lamp's coal stay open as planned.
- **The fen kit was built now, not tomorrow.** A fen of Saltmarrow houses would have read wrong in the
  checkpoint; three quick models (reed house, letting post, Heron Light) and two characters let tomorrow's
  art session *dress* instead of *build*.
- **Smoke walk: a dedicated fen-lane trip instead of more passes.** The passes never reach Thornwold's Oda
  (the bramble wall moves them on first); choosing her option by its text is how a player gets there too.

**Problems / notes**
- The first reed-house roof slabs were rotated wrong (splayed like ramps); `beam` from eave to ridge fixed it.
- The west walk re-uses the Saltmarrow dock model (ladder and bollards); logged for the art pass.
- `fen_ember` changes lines only; the Unmoored turning away from a bare ember is told, not shown (logged).
- The fen's flat white light washes out in Compatibility like every foggy region; judge with the Vulkan pass.

**Next run should**
1. **Art (due Day 30):** *The fen, dressed* (ROADMAP *Next up* #1): a low boardwalk, gulls on the staithe
   posts, eel traps/punt, alder snags, Unmoored sitting by the pools, a stiller water look.
2. **Polish/debt pass three by Day 31** (*Next up* #2).

## 2026-10-07 21:00 UTC — Day 28: The Ridge Light, lit (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again;
  checked out `main` and fast-forwarded to `origin/main` (`2ce60a4`, Day 27's head). Baseline green
  (191 tests + smoke + launch).
- **Art (due today; last art Day 26):** ROADMAP *Next up* #1, all parts:
  - **The fire through the horn.** The lit tower's horn panes were an opaque emissive box. A new
    `build_dressing.horn()` material (emissive palette colour with alpha → glTF `BLEND`, faint
    emission) lets the cradle's new **fire** show: coal-red coals, five ember tongues leaning in, a
    kindle heart. The rack's one lantern at the tower's foot now burns too. The cold build is
    unchanged.
  - **The light reads from the woods.** Halos take `halo_strength` and `halo_bloom` (a wide faint
    glow over the whole quad). The woods' skyline tower: 14 m, strength 1, bloom 0.35 — the fog
    round the cage glows gold and the tower is the warm thing on the skyline (compare
    `2026-10-07-woods-ridge-after.png` with `2026-10-07-pm-woods-ridge-lit.png`). On the ridge a
    6 m cage halo joins the beacon's real light.
  - **Hob sits.** A seated Hob (`hob_seated`: a seated `Body`, the rake across his knees in the
    static `Stool` part) on a new split-log **`log_bench`** (seat top 0.44 m, the seated-body seat)
    by the tally-house step, both placed at the same spot. A new `sit` idle: breathing, thumbs
    creeping on the pole, and late in every 11 s cycle the head sinks — he dozes off — and comes
    up with a start. Engine: **placement poses** — a region NPC placement's own `model`/`idle`
    override the NPC's there (`Region.placed_npc_data`, validated), so Hob rakes in the clearing
    and sits at the camp. The character lineup shows such models as "Name (model)".
  - **Optional:** halos on every lantern post (Saltmarrow's two, the landing's one) — subtle by
    day, there for nights later.
- **Tests:** `test_ridge_lit.gd` (7): the horn is the one see-through material with the fire
  glowing behind it (and the cold tower has neither), far/ridge halos and their shader params,
  lantern-post halos, placement pose overrides, Hob on the bench (same spot and facing, seat height,
  by the step), the doze/start on the real model with the legs still, validator checks. 198 tests +
  smoke + launch pass. Checkpoint `thornwold_lit` re-shot.

Screenshots (`docs/screenshots/2026-10-07-pm-*.png`): `woods-ridge-lit` (vs. the morning's
`2026-10-07-woods-ridge-after.png`), `cage-fire` (the fire through the horn from the gallery),
`hob-on-the-bench`, `hob-seated-lineup` vs `hob-dozing-lineup`, `saltmarrow-post-halos`.

**Decisions**
- **Bloom, not a beam.** A sweeping lighthouse beam would read further but isn't this world's
  beacon (a fire in a cage); a halo whose bloom lights the fog round it says "fire in the fog" and
  costs one quad.
- **A second model, not a procedural bend.** The rig has no knees; folding a standing model's legs
  reads as sitting on the floor. A seated build of the same character (as Hesk is built) plus a
  per-placement pose keeps the rig simple and serves Aldous next.
- **The bench has no collider** — the NPC sitting on it has one; the bench is a seat, not a wall.
- **New canon, small:** the rack's lantern burns now (a light at the end of the road for the four —
  seen, never explained), and Hob dozes on the step (he "sleeps now" after the boots; in the salt-row
  world it reads as the same old man nodding off). LORE updated.

**Problems / notes**
- Hob's bench sits in the tally house's shadow (the landing's sun is west); he reads dark from the
  yard in Compatibility. Logged for the Vulkan colour pass.
- The sit idle runs the same in both burn outcomes; a salt-row Hob who "counts something on his
  fingers" could get a counting beat later.
- `build_dressing.py`'s full rebuild re-exports `thornwold_beacon.glb` byte-identical; `hob.glb`
  re-exports with a different material order after the `_hob()` refactor (same geometry) — the
  committed file was kept to avoid binary churn.

**Next run should**
1. **Content (due by Day 31): the fen lane** — sail north-about to Glasswater Fen (ROADMAP *Next up*
   #1): new region, arrival scene, one or two Unmoored, Dunstan's thread, checkpoint.
2. Art next by Day 30: Aldous seated on a bench by the Wrens' steps (cheap now) or the fen's kit.

## 2026-10-07 09:00 UTC — Day 27: Thornwold's burning (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again;
  fetched `origin/main` (`cfee541`, Day 26's head) before `checkout -B main`. My first baseline run
  overlapped my own edits (meaningless); every later run was on a settled tree.
- **Content (due today; last content Day 25):** ROADMAP *Next up* #1, *Thornwold's burning*:
  - **What the light wants.** Asking the Lamp about the cold Ridge Light now moves *A Light for
    Thornwold* to a new stage, **`feed_the_light`**; a new Lamp question names what Thornwold could
    spare — Hob's memory of the four, the camp's salt row — and keeps the woods out of it.
  - **Two Remnants, made on purpose** (like Mara's gull): **Ottie's boots** — Hob names the four
    (Ottie Swale, Wenna Coll, Abe and Tolly Dray), carries the boots (and the cap) to the clearing's
    edge and holds them in the fog; the cold hut's seat goes bare (new Blender variant
    **`collier_hut_cold_empty`**). **The salt row** — Bram unpegs the SALT stick (only once Hob is
    paid: an unpaid camp has nothing it would miss) and holds it into the fog in the pines; the board's
    bottom pegs go bare.
  - **The cradle** (the Ridge Light inspectable): climb into the lantern cage, weigh either Remnant
    (refuse returns to the cradle), confirm, burn. The quest completes; `thornwold_beacon_burned` =
    `boots` | `salt_row`. The **lit tower** replaces the cold one on the ridge (with the beacon's light)
    and on the woods' skyline (a halo, no light); fog overrides and warmer light in all three Thornwold
    regions; the woods' and the ridge's deep Greying lean back to a thin fleece (strength 0.4 — the
    lanterns still cut their pools). The unburned Remnant can be given back (Hob sets the boots out
    again; Bram re-hangs his row).
  - **Forgetting:** boots — Hob never had neighbours, the hut is nobody's ("good poles in it"), a cap
    brought later is a stranger's. Salt row — the board's gap for good, Bram no longer knows Hob.
  - **Hob comes in by daylight** (pays off his Day 21 promise): a landing arrival event once the light
    is lit *and* his salt is paid, in either order; Hob moves from the clearing to the tally-house
    step (conditional multi-placement). Bram greets him — or, after the salt row, doesn't know him and
    gives him salt without knowing why.
  - **Aftermath:** the **Lamp** stops breaking the coal (the road is the beacon's), keeps the rest
    "for the four", and a stair sliver shows as "a night less"; **Bram** cuts a LIGHT row; **Pell**
    (an off-islander) still remembers Hob; **Oda** says the fen lane is open — talk only for now.
  - 2 items, 5 flags, 1 new dialogue (`hob_comes_in`), 7 dialogues extended; checkpoint
    **`thornwold_lit`** (boots path).
- **Tests:** `test_thornwold_burning.gd` (10). Two older tests' "the lit tower waits" assertions now
  check the lit tower's condition instead. The smoke walk now plays the whole burn in the real scene
  (it meets Hob's offer first, burns the boots, and Hob comes in) — its Day 25 "stage is the_lamp"
  check is relaxed and new checks cover the light, the burn and Hob at the camp. 191 tests + smoke +
  launch pass.

Screenshots: checkpoint `docs/checkpoints/thornwold_lit.png` (the lit tower from the ladder's head);
`docs/screenshots/2026-10-07-woods-ridge-before.png` vs `…-after.png` (the ridge from the clearing),
`…-cold-hut-before.png` vs `…-cold-hut-after.png` (boots and cap on the seat, then bare),
`…-hob-at-camp.png`.

**Decisions**
- **Two choices, not three.** The ROADMAP listed four candidates. Pell's count-stick needs Pell
  aboard *and* the stick talk, and "the woods' liking" would explain a mystery LORE keeps closed, so
  the Lamp itself rules the woods out. Two well-weighed burns with distinct aftermaths beat four thin
  ones; both cost Hob something different (his past vs. his place in the camp).
- **The salt row needs Hob paid**: Bram can only give up a memory he has. That also makes the salt
  quest matter to the burn.
- **Remnants can be returned**, as in Act I, so the unburned one doesn't sit in the satchel forever
  and the cold hut can show its boots again. The hut's state is a separate `thornwold_boots_away` flag
  so props stay simple AND-conditions.
- **Hob's arrival is an event, not a dialogue effect**, so paying him after the burn still works and
  an NPC never vanishes mid-conversation.
- **The fog thins, it doesn't lift** — Thornwold's theme is that the road can't be fully trusted;
  the lanterns still matter for the moment. The lane to Glasswater Fen is opened in talk only, so the
  next content session can build the sailing with the region.

**Problems / notes**
- From the woods the lit tower barely reads in Compatibility (a small gold cage in the fog; the halo
  is faint at that size). Next art session.
- Hob moves to the camp for good (no day/night yet). Known issue logged.
- The player's own lines can still name the four after the boots burn (like Act I; logged).

**Next run should**
1. **Art (due Day 28):** *The Ridge Light, lit* — make the lit tower read from the woods, a lit pass on
   the ridge, Hob's seated idle on the step (reusable for Aldous's bench). ROADMAP *Next up* #1.
2. Then content by Day 31: **the fen lane** — sail to Glasswater Fen.

## 2026-10-06 21:00 UTC — Day 26: The ridge, dressed (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Checkout was a detached
  HEAD again; fetched `origin/main` first (`82df173`, Day 25's head), then `checkout -B main`.
  Baseline green (173 tests).
- **Art (due today; last art Day 24):** ROADMAP *Next up* #1, all five parts:
  - **The Lamp chisels.** New CharacterRig style `chisel` (the Lamp's `idle`): bent over the bench,
    the left hand lifts and strikes twice per 3.4 s beat, then rests; about once in three beats the
    head turns aside and holds, **as if listening**, then goes back to the work. The pole hand barely
    moves.
  - **Ottie's cap on the seat.** `collier_hut_cold_cap` (build_woods.py): the cold hut with the felt
    cap crown-up on the log seat beside the boots, brim toward the door. It replaces
    `collier_hut_cold` by `if: flag:thornwold_hob_has_cap` — Day 25's gift now shows in the clearing.
  - **Lanterns read at a distance.** The stair-foot lantern was a 10 cm emissive cylinder. Rather
    than spend a light (the budget is ember, ferry lantern, beacon), a new prop field **`halo`**
    puts a soft camera-facing glow at the glass (`LanternHalo` + `lantern_halo.gdshader`: alpha
    blended, fog-disabled, a slow flicker, faint close up and full from ~9 m). Every `waymark_lit`
    in the woods and on the ridge has one. Its rotation was fine.
  - **The ridge top from Blender** (build_ridge.py): **`ridge_outcrop`** (grey slabs heaved up on
    edge, lichen on top, heather in the lee) and **`ridge_outcrop_low`** (a broken shelf) replace the
    four procedural rocks (six placed, kept clear of the trodden paths); **`heather_silver`** patches
    (14, in clumps); and the **old Keepers' road** goes on north-east up the spine: a second bare
    `waymark` at the edge of seeing, then **`waymark_tumbled`** (cairn spilled, post leaning 35°,
    arm lying in the heather), both out of reach. The road's paint runs on to them.
  - **Conditional ground paint.** Paint zones take an `if`; `TerrainField.select_paint` picks the zones
    in effect and `Region` recolours the ground mesh (mesh only) when the set changes. The woods'
    fourth waymark sits inside the clearing's big green zone, so the fix is a **grey patch listed
    first** (`if: flag:thornwold_fourth_lantern_taken`) rather than an `if` on its own moss.
- Debug: the character lineup takes `--pose=<s>` (freeze every idle at that moment) and
  `--turn=<deg>`, to see the beats of an idle side-on.
- **Tests:** `test_ridge_dressed.gd` (8): kit loads/sizes; the chisel beat and the real model's
  pose (bent, hand lifts, hood turns); exactly one cold hut per cap state; halos on every lit waymark;
  conditional paint (fixture + the woods' fourth waymark) and the mesh recolour; validator paint
  `if`/`land` `if`/halo checks; ridge outcrops off the paths and the road's waymarks going
  north-east up out of reach. 181 tests + smoke + launch pass. Checkpoints `thornwold_woods` and
  `thornwold_ridge` re-shot.

Screenshots (`docs/screenshots/2026-10-06-*.png`): `ridge-dressed` (vs. Day 25's
`docs/checkpoints` shot, now re-shot — compare the procedural rocks in git history), `ridge-road`
(the old road's waymarks up the spine), `ridge-dressing-lineup`, `lamp-chisel-tap` vs
`lamp-chisel-listen`, `cap-on-seat`, `stair-lantern-halo` (vs. Day 25's `stair-lit`),
`fourth-lit` vs `fourth-taken` (the moss gone grey and the lantern's pool closed).

**Decisions**
- **A halo, not a light.** Real lights stay budgeted; a fog-ignoring billboard says "lantern in the
  fog" in both renderers at the cost of one quad. It fades out near the camera so it never fogs the
  view of the glass up close.
- **Paint conditions recolour, never reshape.** Only `paint` may be conditional (`land` is rejected
  by the validator) so the collider, reachability and the ember map never depend on flags.
- **The far waymark is tumbled**, not lit or bare: new canon that the old road hasn't been tended in
  years, which points at the four colliers' road without saying who stopped walking it (LORE hook).
- **The listening pause is unexplained on purpose** (LORE): it may pay off with the ladder or the four.

**Problems / notes**
- Halos show through Greying fog layers (the layers don't write depth). That reads as light in the
  fog, which is the point; re-judge in Forward+ with the colour pass.
- The hood's turn (0.5 rad) is hard to see from most angles. A bigger turn would read better;
  check the hood against the cape for clipping before raising it.
- The tumbled waymark is mostly lost in the fog from the plateau.

**Next run should**
1. **Content: Thornwold's burning** (ROADMAP *Next up* #1, due by Day 28). The cap on the seat is
   now visible, so a burn of Hob's memory of the four has a thing in the world to change.
2. Then art on Day 28 (Ridge Light lit from the woods; Saltmarrow's bench) or the title screen.

## 2026-10-06 09:00 UTC — Day 25: The ridge and the Lamp (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). This time the checkout
  was already on `main` at the real head (`aa72197`); fetched first anyway. Baseline green (165).
- **Content (due today; last content Day 21):** ROADMAP *Next up* #1, *Into the woods, part two*:
  - **Standing the ladder.** The fallen ladder on the stair's landing is an inspectable
    (`keeper_ladder`): its top cords were **cut clean from the bank side** (pulled down from above).
    Stand it (`thornwold_ladder_stood`; the prop swaps to the standing `keeper_ladder` by `if`), then
    climb — a dialogue `travel`, like the bramble wall.
  - **`thornwold_ridge`, its own region:** a plateau in deep Greying whose south lip drops sheer to
    the woods (base -6, unreachable), the ladder's head at the lip, a lit waymark there (the lantern
    the woods see), the cold Ridge Light (inspectable: the rack, seven hooks empty), the keeper's
    lodge, the old Keepers' road leaving north-east past a bare waymark. Climbing down (an exit)
    lands at the colliers' clearing. One-time arrival scene.
  - **The Lamp** (NPC; Day 24's model): first meeting advances *A Light for Thornwold* to `the_lamp`.
    A hub: its **lost name**; **the iron box** (the saved midwinter coal, a sliver a night — the planned
    secret, now told on the ridge as LORE said); **the ladder** ("I put it down… so there'd be no
    fifth. Hob's the fifth"); **Aldous** — per `saltmarrow_aldous_confessed` (full: the cupped light
    on the stair; grudging: "leave him the rest"), and with the sleeve-ember it knows the Spire stitch
    and Wren of the east stair; the coal **went cold on the Spire side** the night of the Snuffing;
    **the Ridge Light** wants a memory, not the Lamp's.
  - **Shifting paths — *A Lantern for the Stair*:** ask about the dark stair and choose: a **new
    sliver** (the coal shrinks; given at once), **move the fourth waymark's lantern** (a new conditional
    object; its pool and lit prop go, the bare post shows, the fog closes in with Day 23's fade; Hob
    notices), or **refuse**. Hanging it on the stair-foot waymark takes down the cap and lights the
    stair (a conditional `clear` pool).
  - **Ottie Swale's cap** goes to Hob, who sets it by the boots on the cold hut's seat. Hob also
    hears about the ridge.
  - 2 items, 1 quest, 11 flags, 7 dialogues; checkpoint **`thornwold_ridge`**.
- **Tests:** `test_ridge_top.gd` (8). Updated three older tests whose "not yet" assumptions this
  session retired (beacon/lodge now also on the ridge; the standing ladder placed; the cap and the
  fourth lantern conditional). Smoke now checks the climb, the Lamp, the stair lantern and the cap.
  173 tests + smoke + launch pass.

Screenshots: checkpoint `docs/checkpoints/thornwold_ridge.png` (the ridge from the ladder's head);
`docs/screenshots/2026-10-06-lamp-bench.png` (the Lamp at the bench), `…-stair-dark.png` vs
`…-stair-lit.png` (the stair before and after the lantern).

**Decisions**
- **The ridge is its own region** (as Day 24 recommended), with the drop modelled as low base
  ground nobody can reach — no rework of the woods' bounds, and the woods keep their view of the
  ridge.
- **The secret is told, the questions stay.** LORE said reveal the coal on the ridge; I did, and
  kept open the Lamp's name, why the coal was saved, how long it lasts and where the four went.
  The new canon (the coal cold on the Spire side, Aldous as the door-warden who never asked) points
  at mystery #2 without answering it.
- **A shifting-paths choice with a cost either way**: lighting the stair costs the coal's life or
  the colliers' road; refusing costs the player the convenience. `thornwold_stair_light` is kept for
  the burning/lanterns-going-out payoff.
- **Climbing down lands in the clearing**, not on the landing: a spawn must stand in clear ground
  and the landing is in fog unless the stair is lit.
- **Arrival events are gated on the way in** — the ridge's first version fired on the smoke test's
  new-game teleport and hung it (input locked). Recorded in TECH.

**Problems / notes**
- The lit/dark stair difference is subtle in Compatibility screenshots, and the stair-foot lantern
  doesn't read at a distance — on the art list.
- Paint is static: the fourth waymark keeps its moss when its lantern is moved.
- The ridge is sparse (procedural rocks, a few pines and brush) — first-pass dressing.

**Next run should**
1. **Art (due Day 26):** *The ridge, dressed* — the Lamp's chisel idle, Ottie's cap on the seat,
   the stair lantern reading at a distance, Blender ridge dressing. ROADMAP *Next up* #1.
2. Then content: **Thornwold's burning** (by Day 28). Systems (title screen) is waiting behind it.

## 2026-10-05 21:00 UTC — Day 24: The way up (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). The checkout was a
  detached HEAD and the local `origin/main` ref was **stale (Day 13)** — `git checkout -B main
  origin/main` briefly put the tree back eleven days. A `git fetch origin main` and a reset to the
  real head (`bacc3ed`) fixed it; nothing was lost. Next runs: **fetch before resetting `main`**.
  Baseline green (159 tests).
- **Art (due today; last art Day 22):** ROADMAP *Next up* #1, all three parts:
  - **The Keepers' stair up the woods' north bank.** A switchback earth ramp in the region's
    ground (one `path` land feature: east from the clearing's edge 1.85 m over 7.5 m, a turn, back
    west 1.6 m over 6 m to a landing at ≈ 3.8 m), painted trodden earth, dressed with two new
    Blender flights (`ridge_steps_lower/upper`: bark-dark log risers pegged into the ramp, a rope
    rail sagging between split stakes on the open side, the Keepers' ember cut in the bottom stake).
  - **The landing under the last pitch**, where the **Keepers' ladder lies fallen**
    (`keeper_ladder_fallen`: two rungs snapped out, its top end silvered). A standing
    `keeper_ladder` is built for part two. The ridge top stays unreachable (terrain map + test).
  - **The colliers' traces:** a bare waymark at the stair's foot with a **collier's felt cap** on
    its hook where a lantern should be (`waymark_cap`), and a **dropped sack**, split, its charcoal
    spilled downhill on the turn (`sack_dropped`).
  - **The Lamp** (`build_characters.py lamp`, ~1.1k tris): stooped under a deep-hooded oilskin cape
    (the face a shadow — nobody has seen it), a Keeper's robe with the ember stitched *bright*,
    soot-black hands, a lantern pole with a lit lantern on its crook, two cold lanterns at the belt,
    the hem and left sleeve gone silver (half-Hushed). Unplaced until part two.
- Debug: the character lineup now appends models no NPC wears yet ("(unplaced)") and takes
  `--only=hob,lamp`; `test_characters.gd` rig-checks every model in the characters folder.
- **Tests:** `test_ridge_way.gd` (6: kit models; each flight's rise matches the ground under it
  step by step; landing reachable, ridge top not, standing ladder unplaced; ladders stand/lie;
  cap and sack by the stair; the Lamp's one glowing surface is the lantern on ArmR). 165 tests +
  smoke + launch pass. Checkpoint `thornwold_woods` re-shot.

Screenshots (`docs/screenshots/2026-10-05-*.png`): `lamp-lineup` (Aldous, Hob, the Lamp, the
Wakebearer), `stair-before` vs `stair-after` (from the clearing toward the bank), `stair-turn`,
`stair-landing`.

**Decisions**
- **Ground carries the climb, models only dress it.** Terrain stays data (Day 7 decision): the
  walkable stair is a `path` ramp, so reachability, the validator and the ember costs all see it.
  A flight model is fitted to its straight ramp (climbs exactly its rise along +X from the low
  end) rather than one prop per step — two entries instead of ~17, and a test keeps the script,
  the path and the placement in step.
- **Reachable to the landing, not to the ridge.** Making the ridge top walkable in place would
  expose the beacon and lodge a session early and the ridge touches the ground bounds (validator).
  The fallen ladder is the diegetic "not yet": part two stands it. I recommend part two make the
  ridge **its own region**, reached by climbing (a `travel`, like the bramble wall).
- **The ladder's fall is left open** in LORE (fell, knocked down, or pulled up from above) — a
  hook for part two, not an answer.
- **The Lamp's ember is bright, Aldous's faded**: the Lamp never stopped being a Keeper. The hood
  hides the face by design (canon: nobody has seen it); the reveal can lower it.
- The stair sits in deep Greying on purpose — a ~0.2-ember climb — so lanterns on it are the
  natural first *shifting paths* beat.

**Problems / notes**
- The fog washes the stair out in Compatibility screenshots (as everything past the wall); the
  dark risers were darkened after the first shots to read against the trodden-earth paint.
- The bank's ragged edge buries the uphill ends of some upper risers (reads as cut into the bank).

**Next run should**
1. **Content (due Day 25):** *Into the woods, part two* — stand the ladder, the ridge (own region),
   the Lamp, shifting paths, a checkpoint. See ROADMAP *Next up* #1.
2. Then systems: the title screen.

## 2026-10-05 09:00 UTC — Day 23: Polish/debt pass two

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again;
  reset `main` to `origin/main`. Baseline green (152 tests).
- **Polish/debt (due today; last pass Day 15):** ROADMAP *Next up* #1, all four items plus the
  first one it named:
  - **Lantern pools fade.** When the set of lit `clear` areas changes, each fog layer now
    dissolves from the old cut to the new over 4 s instead of snapping:
    `GreyingFog.recut(new, old, animate)` bakes both cuts into one mesh (UV2.x old, UV2.y new),
    keeps every triangle either needs, and the shader mixes them by a tweened `recut`; after
    the fade the mesh is rebuilt with the new cut only. Region loads stay instant. This
    unblocks *shifting paths* (lanterns that go out with the story) for part two.
  - **Settings save as they change**: every toggle, rebind, reset and keyboard slider step
    writes `user://settings.cfg`; a mouse-dragged slider saves once, when it is let go.
  - **The "[E] Talk to…" prompt follows a rebind** at once (it stays up under the pause menu,
    since the player is paused with its focus, so it showed the old key until you moved).
  - **Inspectables glint**: a faint, camera-facing four-point star (new
    `assets/shaders/glint.gdshader` + `Glint`) that twinkles every ~3 s, fades in from 11 m and
    gives way to the prompt inside the object's reach. Data: `glint` offset (default 1.1 m up)
    or `false`; validated. Dunstan's stool has its glint low (0.8 m).
  - **The smoke test walks only where a player could be.** Each pass covers the regions
    reachable on foot (open exits) from where the last left off; a sailing or the bramble wall
    moves the walk on; whoever can `travel` the player (Oda, the wall) is visited last, objects
    before people. No more Gull's Head before the token, Bram before the crossing, or the wall
    parted on pass one. Needed 9 passes (was 6). New checks: every region reached, Hob met,
    *Salt for the Collier* done.
- **Tests:** `test_polish_two.gd` (7: re-cut mesh carries both cuts and keeps the pool's
  triangles either way; animated vs instant re-cut on the node; prompt re-labels on rebind;
  glint default/offset/opt-out; distance fade; sane heights; validator). `test_settings.gd`
  checks saving per change and a drag saving once. 159 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-05-*.png`): `glint-stool` (the star over Dunstan's
stool by Mara's steps, between twinkles), `glint-beacon` (at the Gull's Beacon door in the fog —
faint, see notes).

**Decisions**
- **Fade in the shader, not by cross-fading two nodes.** Two translucent copies at partial
  opacity dip in the middle of the fade and double the draw; one mesh with two alpha channels
  is exact at both ends. The new alpha also lives in UV2.y because vertex colours are 8-bit
  and would pop by ~1/255 at the end.
- **The ember drain follows the light at once**; only the look fades. The drain is already
  gradual (24 s at full depth), so a lantern going out doesn't punish instantly. Noted in Known
  issues in case it feels abrupt.
- **Save per change, but not per drag tick** — writing a ConfigFile 20 times a second while
  dragging is pointless; `drag_ended` covers the mouse, and keyboard/pad steps are discrete.
- **The glint is always on, not "until examined".** Examining things again matters (their text
  changes with the story), so a cue that vanishes would hide content. It stays subtle: low rest
  brightness, a short twinkle, and it never competes with the prompt.
- **The smoke walk is driven by the exit graph**, not a hand-kept region order, so new regions
  join it automatically — and one reachable only some other way fails a check rather than being
  silently teleported to.

**Problems / notes**
- First glint was additive and vanished on pale ground in Compatibility; switched to alpha
  blend with an HDR-bright colour (blooms in Forward+). In deep Greying it is still white on
  white — re-judge with the colour-grading item.
- The first smoke rework sailed Oda back and forth (talked to him before Bram and the wall);
  hence "travellers last".
- No story lantern changes yet, so the fade has no in-game screenshot; it is covered by tests
  and will show in part two.

**Next run should**
1. **Art (due Day 24):** ROADMAP *Next up* #1 — what the ridge needs for part two: the climb
   up the woods' north bank, the Lamp as a character, traces of the four colliers.
2. **Content by Day 25:** *Into the woods, part two* (the ridge, the Lamp, shifting paths —
   now with fading lantern pools).

## 2026-10-04 21:00 UTC — Day 22: The ridge kit (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). The checkout was a
  detached HEAD again; reset `main` to `origin/main`. Baseline green (146 tests).
- **Art (due today under the cadence rule; last art was Day 20):** ROADMAP *Next up* #1 — what
  the ridge needs for *Into the woods, part two*. New script `tools/blender/build_ridge.py`:
  - **`thornwold_beacon` / `thornwold_beacon_lit` — the Ridge Light.** Decided in LORE first: a
    square, dry-laid tower of grey stone, coursed and staggered, paler quoins, a bark-dark timber
    lacing band every fourth course; a plank gallery on cantilevered beams; a timber lantern cage
    with horn panes; a flared bark-shingle roof; **an iron pine** for a vane (the Gull's Beacon
    wears an iron gull — each beacon wears its island's sign). Iron cradle on a plinth in the
    cage (ash in it when cold). The ember carved over the door; a **lantern rack** of eight hooks
    on the flank with one cold lantern left. ~10 m to the vane. Lit = glowing horn panes.
  - **`keeper_lodge`** — the Lamp's house: stone walls, bark-and-turf roof, cold chimney, ember
    over the door, and the **lantern bench** under the eave: an open lantern waiting, **a shut
    iron box, a hammer and a cold chisel** (the planned secret — breaking the saved Firstflame
    coal into slivers — shown, not said), three cold lanterns on pegs, one peg empty.
  - **`collier_hut_cold`** (`build_woods.py`, a variant of the hut builder; `collier_hut.glb`
    rebuilt byte-identical): greyed sods slipping off the cone with dark gaps between the poles,
    no curtain, the hearth ring kicked apart, the rake by the door, and **a pair of boots set
    side by side on the log seat**.
- **Placed:** the cold Ridge Light and the lodge stand on the woods' ridge, seen from the
  clearing through the fog, out of reach (the lit tower is held for Thornwold's burn); the
  clearing's second hut is now the cold one; Hob's hut smokes at its peak.
- **Hob rakes:** new `CharacterRig` style **`rake`** (slow pulls with a forward lean, blended
  out while walking); `hob.json` `idle: "rake"`.
- **Tests:** `test_ridge_kit.gd` (6: models exist/small/centred; the Ridge Light is ~10 m and
  taller than the Gull's; beacon and lodge on the ridge top, unconditional, out of reach, only
  in the woods, lit tower unplaced; lit glows/cold and lodge don't; warm hut smokes and cold hut
  doesn't, both in the clearing; Hob's rake pose reaches, leans and draws back).
  `test_woods.gd` counts both hut models; `test_dressing.gd` lets Thornwold's beacon stand up to
  11 m. Checkpoint `thornwold_woods` re-shot. 152 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-04-*.png`): `ridge-kit` (lineup: both huts, the lodge,
the tower cold and lit), `ridge-before` vs `ridge-after` (from the clearing up to the ridge),
`ridge-close`, `clearing-before` vs `clearing-after` (the cold hut, Hob's smoke).

**Decisions**
- **Square and tall, not a second Gull's stub.** Saltmarrow builds low against wind;
  Thornwold has to see over trees. The square plan, timber lacing and horn panes say "the same
  order, a different island's materials"; the iron vane carrying the island's sign makes the
  two beacons a pair. Recorded in LORE.
- **The secret stays a prop.** The lodge shows a box, a hammer and a chisel by an open
  lantern; nothing glows (the test pins that) and no line explains it before the ridge.
- **Placed now, reached later.** The ridge has had a single lit waymark since Day 21; putting
  the tower and lodge there today gives part two its goal on the skyline and lets the content
  session spend its time on the road, the Lamp and the burn. Both are unconditional; the lit
  tower waits.
- **Boots on the seat** — a quiet, concrete hook for the colliers who "went up after the Lamp":
  nobody climbs a ridge barefoot by choice. Recorded as an open hook in LORE.
- Quoins were bone-pale at first and the tower read as a checkerboard; toned to light slate.

**Problems / notes**
- The lodge first exported with 19 materials (> 16 mesh-node cap); folded shades.
- `bp.prism` doesn't make its object active, so the first lodge roof rotated the wrong object
  (noted in TECH).
- The tower's height (10.1 m) broke `test_dressing.gd`'s 7 m sanity bound; it now has its own.
- From the clearing, the ridge reads through the fog as a pale silhouette in Compatibility
  screenshots — fine as "dark beacon in the Greying"; re-judge with the Vulkan colour pass.

**Next run should**
1. **Polish/debt pass (due Day 23):** ROADMAP *Next up* #1 — start with the fade for lantern
   `clear` areas (part two needs it).
2. **Art by Day 24**, then **content by Day 25:** *Into the woods, part two* — the road up the
   ridge to the Ridge Light and the lodge; the Lamp.

## 2026-10-04 09:00 UTC — Day 21: Into the woods, part one (content track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). The local checkout was a
  detached HEAD behind origin; reset `main` to `origin/main` first. Baseline green (137 tests).
- **Content (due today; last content was Day 17):** ROADMAP *Next up* #1, *Into the woods* —
  the first half of it, sized to one session.
  - **The ember parts the bramble wall.** Once Bram has given *A Light for Thornwold*, the wall's
    inspect offers "Hold the ember to the thorns": the canes draw back, a gap opens
    (`thornwold_bramble_parted`), and "Go through." travels into the new region. Later visits
    open it again.
  - **New region `thornwold_woods` — The Woods Past the Wall:** an inland hollow under steep
    banks. The cart road runs straight north into deep Greying (**the road lies**; a cutter's
    stake on this side points north too, two bare waymarks stand in the fog). **Lit waymarks**
    lead west off the road, pool to pool, to **the colliers' clearing** (two cone huts, a
    smoking clamp, sacks, a log pile) where the fog stands back with no lantern at all. The
    first waymark — empty from the camp — has a lantern from this side. A lantern burns on the
    ridge, out of reach. One-time arrival scene. The clamp and cart the camp sees past the wall
    stand at the same spots here.
  - **Hob Marl** (new Blender character): the last collier this side of the ridge, half-Hushed.
    He brings the sacks down by the lanterns, tends the clamp, calls whoever hangs the lanterns
    "the Lamp", and forgot to take his salt after the third load. Asking about the Lamp moves *A
    Light for Thornwold* to `the_ridge` (still being written).
  - **Bram's tally board** (inspectable by the tally-house door): TIMBER, CHARCOAL, FLOUR AND
    OIL, UP — and SALT, three notches then bare wood. Telling Bram about Hob: he'd forgotten Hob
    existed since the Snuffing. Side quest **Salt for the Collier** — carry the crock to Hob; he
    remembers Bram, promises to come in by daylight; the board gets a fourth notch.
  - **Pell's tally stick is Hob's** ("the night I forgot what I was counting"); Pell keeps it
    *for* him.
  - Paid off: who brings the sacks, who tends the clamp past the wall, the short bottom row,
    Pell's half-notched stick, the lantern on the ridge (seen), the empty waymark hook, the
    collier hut and lit waymark models. LORE gains the canon and a planned [SECRET] answer for the
    Lamp (the beacon-keeper rationing a saved coal of the last midwinter's Firstflame).
- **Engine: lantern light in the Greying** — `clear` areas cut pools out of the fog (logic, fog
  layer meshes, live re-cut, validator worst case = only unconditional lights count).
- **Tests:** `test_woods.gd` (9). `test_woods_kit.gd` now expects the hut/lit waymark in the
  woods. Smoke: an inspectable's `travel` ends the region walk like Oda's; asserts the walk went
  through the wall. Checkpoint **`thornwold_woods`**. 146 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-04-*.png`): `woods-overview` (the road north vs. the
lanterns west), `woods-arrival` (the wall from inside, the lit first waymark), `woods-clearing`,
`hob-lineup`.

**Decisions**
- **A separate region, not the landing's own strip past the wall.** The canon says the road
  "goes somewhere else": entering through the gap and finding the first waymark *lit* on this
  side sells that better than walking past the wall in one space, and keeps the landing's
  Greying as the "you can't just walk in" wall.
- **Trust and misdirection as layout, not a new system:** the road (and a camp trail stake) point
  straight into deep fog; the lights lead off it. Story-driven shifting (lanterns that go out or
  move) is supported by `clear` + `if` and waits for the ridge, where it means something.
- **`clear` areas instead of carving the fog out of rect strips:** light pushing the Greying back
  is canon, will be reused (the ember radius idea in *The Greying v2*, a relit beacon's pockets),
  and keeps region data readable.
- **The lanterns burn Firstflame coal.** Ordinary fire barely helps against the Greying (canon),
  so the lanterns had to be something more; shown, not explained. The Lamp is planned as the
  beacon-keeper, kept unnamed and unseen.
- **Bram forgot Hob too.** The camp forgetting the colliers mirrors Hob forgetting his pay; it
  explains "nobody sees who brings them" without the camp being incurious.
- The woods arrival event also requires `thornwold_bramble_parted` — the smoke test visits regions
  directly, and an event playing there locked input for the next check.

**Problems / notes**
- With no `water_level`, ground colour rules treat `base` as the waterline, so the whole floor
  first rendered as pale "shore"; the region sets `shore`/`seabed` to `pine` (TECH notes it).
- The first smoke run timed out: the menu walk chose "Go through" at the wall and freed the
  region mid-loop. Fixed in the smoke test (not in the game).
- Two lit-waymark lanterns and the exit marker near the spawn read similar in Compatibility
  screenshots.

**Next run should**
1. **Art (due by Day 22):** ROADMAP *Next up* #1 — something the ridge needs (Thornwold's beacon,
   the Lamp's place), a cold hut variant, or Aldous's bench.
2. **Content by Day 25:** *Into the woods, part two* — the ridge, the Lamp, the beacon and burn.
3. Polish/debt pass due by session 23; title screen after.

## 2026-10-03 21:00 UTC — Day 20: The woods kit (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). The local `main` was
  31 commits behind origin; fast-forwarded before starting. Baseline green (133 tests).
- **Art (due today under the cadence rule; last art was Day 18):** ROADMAP *Next up* #2, a
  first kit for the woods past the bramble wall so Day 21's *Into the woods* has it.
  New script `tools/blender/build_woods.py` (seven models into the dressing kit):
  - **`collier_hut`** — the charcoal folk's cone hut: a hand-built cone mesh whose faces are a
    patchwork of bark and turf, crossed pole tops, a gabled doorway with a sacking curtain, a
    hearth ring with a spit and a log seat, a rake and a sack.
  - **`sack_cart`** — a two-wheeled handcart with spoked wheels, rails, shafts on the ground,
    five sacks of charcoal (one lying across), a rope coil, a lantern hook on the tail.
  - **`waymark`** / **`waymark_lit`** — a Keepers' cairn with a weathered post carved with the
    ember (a flame in a ring) and an iron arm; the lit one has a Keeper's lantern on the hook.
  - **`trail_stake`** — a cutter's stake with the camp's "this way home" notches, a red rag and
    a pointer slat.
  - **`greyed_brush`**, **`pine_grey`** — undergrowth and pines the Greying has had: silvered,
    thinned, ragged tiers, bare spars.
- **Thornwold Landing dressed:** past the wall the pines now go grey from the inside (three
  deep `pine_dark`s become `pine_grey`, six more Greyed pines and six Greyed brushes deeper
  in); **the sack cart stands loaded by the clamp**; **the first waymark** stands on the cart
  road just past the wall, hook empty; **a trail stake** on the camp side points into the
  thorns. Canon added to LORE (waymarks, the cart, cone huts). The hut and the lit waymark
  are built but held for *Into the woods*.
- **Tests:** `test_woods_kit.gd` (4: models exist/small/base-centred; placed past the wall,
  hut and lit waymark held back; Greyed growth, cart and waymark stand in the Greying and the
  stake on clear camp ground; the lit waymark glows, the bare one doesn't). Checkpoint
  `thornwold` re-shot. 137 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-03-woods-*.png`): `kit` (lineup next to `pine_dark`),
`before-woods` vs `after-woods` (over the wall from the camp), `before-wall` vs `after-wall`,
`after-cart`, `after-stake`.

**Decisions**
- **A new script rather than growing `build_thornwold.py`** (480 lines): the woods kit is its
  own place and will keep growing with Act II.
- **Greyed growth only inside the Greying**, and tested that way: the gradient dark → grey
  from the wall inward is the woods' story ("going grey from the inside") told without words.
- **The waymark's hook is empty for now.** LORE has the charcoal folk seeing "a lantern along
  the ridge"; lit waymarks are the obvious payoff (someone hanging lanterns), so the lit model
  waits for the content session that decides who.
- **Hut as one patchwork mesh:** the first try laid bark slabs as beams over a cone; they
  stuck out like spikes. A hand-built cone with per-face materials reads as laid slabs and
  turf and costs one node.
- Emissive-only lantern glass on `waymark_lit` (light budget unchanged).

**Problems / notes**
- First export of the hut had 18 mesh nodes (> 16 cap); folded its shades into WOOD/BARK/CLOTH.
  The Greyed brush's jittered lumps dipped 0.2 m below the origin; raised.
- Sack necks in `coal` read as red apples at a distance; they're dark driftwood now
  (`charcoal_sacks.glb` from Day 17 still uses coal-red necks — fine on the jetty, left alone).
- Woods shots are taken from fixed cameras; the "[E] Talk to Oda Farrow" prompt shows because
  the player spawns on the jetty by Oda.

**Next run should**
1. **Content (due by Day 21):** *Into the woods* — ROADMAP *Next up* #1. The art is ready:
   place `collier_hut`/`waymark_lit` where the story needs them (update `test_woods_kit.gd`).
2. Title screen after that; art next due by Day 22; polish/debt pass due by session 23.

## 2026-10-03 09:00 UTC — Day 19: Settings (systems track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green (125 tests).
- **Systems:** ROADMAP *Next up* #1, **Settings**, the last big missing piece of the pause menu.
  - **`GameSettings`** (`scripts/core/game_settings.gd`): volumes for Master/Music/Ambience/
    Effects/Voice (buses created in code and routed to Master; 0 mutes), text size presets
    (Small/Normal/Large/Larger → `UiTheme.set_text_scale`), camera sensitivity (25–250%),
    invert left/right and up/down, rebound keys. Persisted to **`user://settings.cfg`**
    (ConfigFile), never in saves; loaded and applied by `GameState._ready`. Loading clamps
    everything and drops unknown, reserved or duplicate keys.
  - **Rebinding** (`InputSetup`): eleven actions (movement, interact, camera turn, journal,
    satchel, quicksave/load). The first key of each is its primary; rebinding swaps with
    whichever action held the key, refuses Esc and P (the menu), and keeps the arrow keys/Enter
    as secondaries unless another action claims them.
  - **Pause menu → Settings** (sliders with readouts, value buttons that cycle/toggle, Controls,
    Reset to defaults — asks twice, Back) and **→ Controls** (pick an action, press a key; Esc
    cancels and says what was kept; refusals say why). Saved when the settings pages are left
    or the menu closes. Esc backs out Controls → Settings → main.
  - The player camera reads sensitivity/invert (mouse drag and stick/Q-R yaw). The HUD key
    hint, the "[E] Talk to…" prompt and the dialogue "[E] continue" show the bound key.
  - The menu list now sits in a **scroll box** sized to the screen: at Larger text the Controls
    page ran off a 720p screen. Focus follows into view.
  - `--pause-menu=settings|controls` for screenshots.
- **Tests:** `test_settings.gd` (8: defaults, bus volume/mute, text size, camera, rebinding and
  the InputMap, file round trip, bad file, the menu pages end to end). The smoke test opens
  Settings, moves the master slider, rebinds the journal to K **with a real key event**, checks
  the HUD hint, backs out with Esc and checks the file was written, then resets (it runs on
  defaults from a scratch `user://smoke_settings.cfg`). 133 tests + smoke + launch pass.

Screenshots: `docs/screenshots/2026-10-03-settings.png`, `-controls.png`,
`-controls-larger-text.png` (scrolling at the largest text size).

**Decisions**
- **A plain class with a static `current()`**, not a fourth autoload: the test runner has no
  autoloads, and tests need their own instance and file path (`set_current`).
- **Buses in code** rather than a `default_bus_layout.tres`, so the bus list lives next to the
  settings that drive it; the audio-hooks item plays through them by name.
- **Rebind the primary only, keep secondaries.** Arrows/Enter keep working for players who
  never open the menu; the swap rule means a rebinding can never leave an action unbound.
- **Pause isn't rebindable** (Esc/P/Start): the one way back to the menu must never be lost.
- **Gamepad rebinding left out** — pad layout is conventional and the pad has no prompts yet;
  logged as a follow-up with fullscreen/vsync.
- Save on leaving the pages rather than per slider tick.

**Problems / notes**
- Godot 4.7's `Range` doesn't emit `value_changed` outside the scene tree, and the test
  runner's root isn't in the tree during `_initialize`; tests emit it by hand (TECH notes it).
- First scroll attempt hid the focused top row: focusing scrolls against the old page's
  layout. `_focus` now re-checks visibility a frame later.

**Next run should**
1. **Art (due by Day 20):** ROADMAP *Next up* #2 — ideally a first kit for the woods past the
   bramble wall, so Day 21's content has it.
2. **Content by Day 21:** *Into the woods*.
3. Title screen after that (reuse the Settings/Controls pages).

## 2026-10-02 21:00 UTC — Day 18: Thornwold's own look (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green (119 tests).
- **Art (due today under the cadence rule; last art was Day 16):** ROADMAP [A] #1, Thornwold's
  look. Until now the camp borrowed Saltmarrow's stilt and tall houses and pines.
  - `build_thornwold.py` gains eight models: **`bunkhouse`** (4.4 × 3.0 m saddle-notched round-log
    cabin with interlocking corners and pale cut ends, clay chinking, bark-slab gable roof,
    tin stove pipe, two lit windows with shutters, axe and bucksaw on the wall, woodpile
    under the eaves, footing stones); **`tally_house`** (smaller log hut with a lean-to porch
    and **Bram's tally board**: four rows of notched sticks on pegs, the bottom row only three);
    **`saw_pit`** (X-legged trestles, a log half sawn into planks, the pit saw left in the
    kerf, sawdust); **`charcoal_clamp`** (turfed earth dome, glowing vents, stake ring, ladder,
    rake, finished charcoal); **`pine_dark`** (narrower, five drooping deep-green tiers);
    **`pine_snag`** (a Greyed pine: silvered, bare spars, one last tier); **`underbrush`**
    (bush lumps, fern fronds, berries); **`fallen_trunk`** (mossy, branch stubs, root plate).
    Shared helpers `_log_walls` (with door/window cut-outs), `_bark_roof`, `_stove_pipe`.
  - **Engine: prop `smoke`** — `[[x, y, z], ...]` model-space vents, each a `CPUParticles3D`
    column of low-poly puffs that swell, drift and fade (`PropSmoke`, validated). The stoves
    smoke, and so does the clamp.
  - **Thornwold re-dressed:** the bunkhouse and tally-house replace the borrowed houses (same
    spots); all 20 pines are `pine_dark` except two `pine_snag`s at the wall's ends; a saw
    trestle by the log piles; two fallen trunks and twelve underbrush clumps under the pines;
    and **a charcoal clamp smoking just past the bramble wall**, in the Greying where nobody
    from the camp can go. Its smoke shows over the thorns from the camp. Canon noted in LORE.
- **Tests:** `test_thornwold_kit.gd` (6: kit placed, nothing borrowed from Saltmarrow, smoke
  vents on their models, one emitter per vent, validator, clamp past the wall). Story checkpoint
  `thornwold` re-shot. 125 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-02-thornwold-*.png`), same cameras before/after:
`before-camp` vs `after-camp`, `before-buildings` vs `after-buildings`, `before-woods` vs
`after-woods` (the clamp's smoke over the wall); plus `after-tally`, `after-clamp`, `after-saw`.

**Decisions**
- **The clamp goes past the wall, not in the camp.** The camp can't see who brings the sacks;
  a clamp tended by nobody-you-can-reach, smoking in the Greying, makes that hook visible
  without a line of dialogue, and gives *Into the woods* a landmark to walk toward.
- **Smoke as CPU particles** rather than static puffs (which read as floating balls in the
  first try) or a shader: works in both renderers, few draw calls, no new assets.
- **Log colours lifted** after the first lineup: the first pass (pine/coal at -0.6) read
  black-and-red striped under Thornwold's cold light; logs are now driftwood/pine mid-shades
  with pale chinking, roofs pine/slate, no coal red on buildings.
- Kept each building to one box collider, like the village houses.

**Problems / notes**
- First export failed the kit test: 22 materials per cabin (> 16 mesh nodes after merge); folded
  the shades into a shared set. The fallen trunk's root plate dipped below its origin; raised.
- The tally board isn't inspectable yet (noted under *Into the woods*).
- The tally-house front sits in its own shadow from most camp angles under Thornwold's
  low sun; fine, but the tally board is hard to see from the path.

**Next run should**
1. **Systems:** Settings in the pause menu (volumes, text size, camera sensitivity/invert,
   rebinding) persisted to `user://settings.cfg`.
2. Content by Day 21: *Into the woods* — past the bramble wall, toward the smoking clamp.
3. Art next due by Day 20.

## 2026-10-02 17:30 UTC — Owner request: story checkpoints (see progress without playing)

**Did**
- **Story checkpoints** (`data/scenarios.json`, `Scenarios`): ten named points from waking on
  Shingle Point to Thornwold Landing (each burn has its own aftermath checkpoint). Each one
  `inherits` the one before and lists only what changed.
- Three ways in: **`--scenario=<id>`** (`--scenario=list` prints them); a **Chapter select
  (dev)** page in the pause menu, debug builds only; and **`tools/checkpoints.sh`**, which
  screenshots every checkpoint into `docs/checkpoints/` and writes the gallery page
  **`docs/CHECKPOINTS.md`**. README has a "See the progress" section.
- Validated with the content (unknown regions/spawns/flags/stages/items/pickups, bad
  `inherits`). `test_scenarios.gd` (7): reset-then-apply, inheritance, each burn checkpoint,
  the story carrying on from the late ones, every conversation in each checkpoint's region
  finishing. The smoke test jumps to Thornwold through the real menu.

**Decisions**
- **Hand-written state, not recorded saves.** Saves break whenever content changes; a
  checkpoint is a few validated lines that inherit from each other, so it stays in step with
  content and the tests catch drift.
- **Jumping resets to a new game first**, so a jump never mixes into the current playthrough.
- **Dev-only in the menu** (`OS.is_debug_build()`): players of a release build won't see it.
- **Rule for future sessions:** each content session adds a checkpoint (with a `shot`) for
  what it built and re-runs `tools/checkpoints.sh` for it.

## 2026-10-02 09:00 UTC — Day 17: The crossing — Act II begins on Thornwold

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green (103 tests).
- **Content (due today; last was Day 13):** *The crossing*, the top Milestone 2 item, plus a
  first region for Act II.
  - **Casting off.** After passage, Oda's "When do we sail?" became **"Cast off for
    Thornwold."**: the plank comes in on the evening tide; Mara at the dock end with the green
    lantern (two cups behind her after the `gull` burn); Pell at the rail coiling rope wrong
    (aboard), shouting "something GOOD" (stayed), on the packed bundle not waving — then waving
    (let_down), or running the dock (unresolved). Oda steers with the Gull **dead astern,
    counting** — "a dark island's a hole in the sea, but holes have edges. Listen for the
    trees." The crew are off-islanders, so the burned memory is aboard and slides off you (a
    hummed lullaby / a knot you almost know / Dunstan's name). *Across the Grey* completes.
  - **Thornwold Landing** (new region): a stony cove under black pines, the Tidewright lumber
    camp (jetty with the Slow Mercy alongside, log piles, chopping stump, charcoal sacks,
    bunkhouse and tally-house), the old cart road north to the beacon — stopped by a
    **bramble wall** that grew across it the night of the Snuffing. Behind it the woods are
    deep Greying (walkable; you're turned back). A one-time **landing scene** on arrival.
  - **Bram Kettle** (new character + model), camp foreman: hears your deed from Oda
    (claimed/shared/brusque), holds the **knot burn** against you (`thornwold_bram_knot_grudge`,
    future) or hums the lullaby / names Dunstan at you, warns you off the sleeve-ember if Oda
    saw it, explains the wall, and gives **A Light for Thornwold** (future). Asks: the
    beacon-keeper (a Keeper, nameless, thirty years; a lantern on the ridge "the charcoal folk
    say"), the charcoal folk (their sacks arrive and nobody sees who brings them), Pell.
  - **"Look at the bramble wall"**: ruts running in and not out, a cutter's "this way home"
    notch pointing into the thorns, your ember leaning toward it → quest stage `past_the_wall`.
  - **Pell on Thornwold** if aboard (sorting Bram's nails; a half-notched tally stick).
  - **The ferry plies both ways**: `lanes_ferry_at` places the Slow Mercy and Oda at one end of
    the lane; Oda runs you back to Saltmarrow and out again (one-line sailings).
- **Engine:** dialogue effect **`travel: [region, spawn]`** — applied when the dialogue closes
  (validated: region + spawn exist). Saltmarrow gets a `from_ferry` spawn on the dock.
- **Blender:** `build_thornwold.py` — `bramble` (arching thorned canes over a lumpy thicket,
  red hips), `log_pile`, `stump` (axe bitten in, billets), `charcoal_sacks`; `bram` in
  `build_characters.py` (786 tris: apron, rolled sleeves, beard, axe on the shoulder).
- **Tests:** `test_crossing.gd` (9). Smoke test: 6 passes; a `travel` mid-walk ends that
  region's walk; it now sails Saltmarrow → Thornwold → Saltmarrow and checks the crossing,
  the landing, Bram's quest and where Oda/Pell/the ferry stand. 112 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-02-crossing-*.png`): `overview` (the landing from the
sea), `camp` (path, stump, log piles, Pell by the sacks, the wall beyond), `bramble`,
`jetty` (the Slow Mercy alongside, Oda and the player), `characters` (Bram in the lineup).

**Decisions**
- **Crossing as dialogue + `travel`, not a ferry/map screen yet.** One small engine effect gets
  Act II started; the map screen stays a Milestone 2 item and can take over the same
  `lanes_ferry_at` flag.
- **A return trip now** (rather than a one-way crossing): Saltmarrow still has open things
  (Pell's pouch, the stool, the sign), and stranding the player on a greybox island would be a
  soft lock in all but name.
- **No exit off the landing yet.** The woods past the wall are Greying, which already turns the
  player back — exactly the fiction ("the road goes somewhere else") — so no fake locked exit.
- **Bram is a Tidewright, not a Keeper**: Thornwold's Keeper beacon-keeper stays unnamed and
  unseen (Aldous: "names carry"); kept the pronoun out of it on purpose.
- Thornwold borrows Saltmarrow's `house_stilt`/`house_tall` as camp buildings for now; their
  own log buildings are tomorrow's art item.

**Problems / notes**
- First terrain was a rectangle with a cliff rim; reshaped to ellipses (rounded cove, softer
  beach) with `terrain_map.gd`, and the north ridge pulled in off the bounds.
- The bramble's first "core" boxes read as a concrete wall in screenshots; replaced with
  squashed ico-sphere thicket lumps.
- The smoke walk talks to Bram before the crossing (it visits every region each pass);
  impossible in play, noted in ROADMAP.

**Next run should**
1. **Art is due (Day 18)**: Thornwold's own buildings (log bunkhouse, tally-house, saw-pit,
   charcoal clamp), underbrush, a darker pine — before/after against today's screenshots.
2. Systems after that: settings (text size, volumes, camera) with a persisted settings file.
3. Content by Day 21: *Into the woods* — the shifting paths past the bramble wall.

## 2026-10-01 21:00 UTC — Day 16: The Wrens' house, broken lofts, wading foam (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green (94 tests).
- **Dressing follow-ups** (ROADMAP [A] #1, art was due today under the cadence rule):
  - **Houses planked on all four faces.** `_boards` in `build_village.py` now boards the ±X
    sides too (they were flat colour); Mara's porch house swapped its side slabs for corner
    posts; the tall house got corner posts.
  - **`house_stilt`** — a planked, shuttered, coal-shingled remake of the plain stilt house
    (same footprint and heights; steps with stringers down from the door). It retires
    `build_props`' flat-walled `stilt_house.glb` (builder and file removed).
  - **`house_wren`** — *the Wrens' old house*, which Aldous sits beside: bleached,
    salt-grey boards with two missing from the side, a patched slate roof, shutters closed,
    a side window boarded with a cross of planks, a **cold Keeper's brazier** at the steps
    (grey ash, dead coals) and an **ember-hook** by the door.
  - **The ember sign follows the story.** Two small models on the hook — `ember_sign_wrapped`
    (sailcloth, red cord) until `saltmarrow_aldous_confessed` is set, then `ember_sign` (a
    bone-white disc with the Keepers' ember on each face). A new inspectable, **"Look at the
    Wrens' door"** (`story/wrens_door.json`), reads three ways: untold (wrapped, cold), grudging
    (the sacking dropped under the hook, nothing cleaned), full (cleaned, facing the road, the
    ash *raked* "the way you'd make up a bed for someone expected"), plus a line if you carry
    his sleeve-ember. Canon added to LORE.
  - **`net_loft_broken`** for Gull's Head: holed plank roof with a slipped strip, snapped
    rail, missing floor and wall boards, one net hanging by a corner, one heaped on the floor,
    a ladder short two rungs. Two of the four lofts use it; Hesk's loft stays mended.
  - **Wading foam:** new prop field `wading: [[x, z, r], ...]` — small level foam rings round
    legs and pilings in the sea, one mesh per prop, kept only where the ground under the leg
    is below the water. On the dock's 8 pilings and the three houses in the shallows.
- **Tests:** `test_wrens_and_lofts.gd` (9: boards on both sides of every house, stilt house
  retired, Wrens' house by Aldous with both signs sharing its origin, exactly one sign per
  confession state, the door text per state, broken lofts + Hesk's whole one, wading foam on
  the water only over the sea, ring mesh, validator). `test_village`/`test_aftermath` updated.
  103 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-01-wrens-*.png`): `before-wren` vs `after-wren` (same
camera), `after-wren-told` (the uncovered sign and raked brazier after a full confession),
`before-lofts` vs `after-lofts` (Gull's Head), `after-dock` (foam round the pilings), `kit`.

**Decisions**
- **Story-swappable details as separate props sharing the building's origin.** The sign
  models are built where the hook is relative to the house, so data places them with the
  house's own position/turn and only `if` differs — no maths in data, no new engine feature.
- **One inspectable for hook + brazier**, not two: they're half a metre apart and two prompts
  would fight each other (and Aldous's) for the nearest-interactable slot.
- **No light on the brazier.** It's cold on purpose (the Keepers' fire is out), and the light
  budget (ember, ferry lantern, beacon) stands.
- **Wading rings are filtered by the terrain at build time** instead of hand-listing only wet
  legs, so houses can be moved without breaking the foam. Static rings: the legs don't bob.
- Retired `stilt_house.glb` rather than keep two versions of the same house.

**Problems / notes**
- `house_wren` first exported 19 material groups (budget 16); folded near-identical shades.
- The board-coverage test first counted vertex heights (boards are vertical, so all the same);
  it counts board edges along the wall now.

**Next run should**
1. **Content is due (Day 17)**: a small Act I side thread paying off open flags, or the
   Thornwold greybox + *The crossing*. A cheap hook from today: Aldous noticing you read his
   sign (the `wrens_door` text could set a flag he answers).
2. Systems after that: settings (text size, volumes, camera) with a persisted settings file;
   a title screen.

## 2026-10-01 09:00 UTC — Day 15: Polish pass — camera, pause menu, save slots

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green (88 tests).
- **Polish/debt pass** (due by session 16; Day 8 was the last) plus the top systems item:
  - **Camera collision.** The orbit camera already had a spring arm, but a bare ray: it let
    the near plane sit on walls and cliffs, and roofs/eaves weren't in any collider, so the
    camera slid straight through Mara's porch roof (screenshots `camera-before` vs `-after`,
    same spot). Now: a new physics layer 4 **`camera`**; every model prop with a `collider`
    and at least 2.4 m tall gets a camera-only **`CameraBlocker`** box over its mesh bounds
    *above* its walk collider (roofs, eaves, canopies — the player never touches it); the
    arm sweeps a 0.3 m sphere, and the camera **snaps in** to a hit but **eases back out**
    (4 m/s), so it no longer pops. No data changes needed.
  - **Pause menu** (Esc / P / gamepad Start): pauses the tree, Resume / Save game / Load
    game / Quit to desktop. **Three manual save slots** (plus the F5 quicksave on the load
    page), each listed as "Slot 1 — Saltmarrow · 2026-10-01 09:12"; overwriting a used slot
    and quitting each need a second press. Esc backs out of a page, then resumes. Loading
    closes the menu and unpauses into the loaded region.
  - **HUD key hint** ("[J] Journal [I] Satchel [Esc] Menu") hides while any modal holds input —
    it sat under the dialogue panel's corner (known issue since Day 2).
  - **Ember meter flash** fixed: it faded in for 1.5 s on every load (its idle timer started
    at 0). Found in the pause-menu screenshot.
  - **Lineup scenes** (character + prop art review) are now lit by the game's own
    `Atmosphere` (sky, sun, glow, grading) via `LineupLight`, `--mood=<region>`; distance fog
    off so the prop overview stays readable.
- **Engine:** `SaveSystem.SLOTS`, `slot_label/slot_info/slot_summary`, a `save_dir` var (the
  smoke test now saves into `user://smoke_saves`, never touching real saves); `pause` input
  action; `--pause-menu[=save|load]` debug arg for screenshots.
- **Tests:** `test_polish.gd` (6 tests: house blocker on the camera layer only, starting at
  the walls' top and reaching the peak; crates/fences/stools get none; every building stops
  the camera to its peak; snap-in/ease-out maths; slot labels; pause binding). Smoke test
  checks the key hint hides in dialogue and drives the pause menu: save to slot 1, overwrite
  confirm, Esc back, load restores state, Esc resumes. 94 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-01-polish-*.png`): `camera-before` vs `camera-after`
(by Mara's porch: the roof filled the frame), `pause`, `pause-save`, `prop-lineup` and
`character-lineup` (now in the game's light).

**Decisions**
- **Camera blockers from mesh bounds, on their own layer**, rather than taller walk colliders
  or per-prop data: eaves and canopies stick out past the walls, and widening walk colliders
  would push the player away from doors. Bounds are computed at build time, so new models
  get it free. Starting the box at the collider's top keeps it off the ground, so the pivot
  is never inside it (first try used the full bounds and jammed the camera into the player's
  head under the eaves). The net-lofts' colliders already reach their peak, so they get none.
- **Pause pauses the tree** (NPCs, water, fog all freeze) as well as locking input. The HUD
  runs always so the hint hides under the menu; the smoke test runs always so it can drive it.
- **No settings page yet**: settings (text size, volume, camera sensitivity) is its own item
  and needs a persisted settings file; the menu has room for it.
- **No "Return to title"** on the Act I card: there is still no title screen. Logged.

**Problems / notes**
- Deferred `grab_focus` on menu buttons errored when a page was rebuilt in the same frame
  (the smoke test presses fast) — focus now checks the button is still in the tree.
- With a wall right behind the player the camera still sits close behind their head (it
  can't go through the wall). Fading the player model at very short distances is logged.

**Next run should**
1. **Art** ([A], due by Day 16 — next run): dressing follow-ups (house side walls, Gull's Head
   broken net-loft, Aldous's Keeper touches) or the remaining terrain/atmosphere follow-ups
   (foam rings round pilings, Compatibility paint contrast).
2. Content is due by Day 17: the crossing / Thornwold opening, or a smaller Act I side thread.
3. Systems after that: settings (text size, volumes, camera sensitivity/invert) wired into
   the pause menu with a persisted settings file; a title screen.

## 2026-09-30 21:00 UTC — Day 14: Village kit & harbor life (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **Dressing follow-ups** (ROADMAP [A] #1, art was due by today):
  - New Blender script `tools/blender/build_village.py` (into the dressing kit):
    **`house_tall`**, a narrow two-storey stilt house (slate-blue planked ground floor, a
    jettied upper floor in tarred boards, a steep pine-shingled roof, tide-blue shutters, a
    stovepipe, a side ladder); **`house_porch`**, Mara's house (warm planked walls, coal
    roof, a front porch with rails and steps down, a window box of moss, a lantern hook, a
    net drying over the rail); **`gate_post`** (a leaning post with coal-red lashings, a cork
    float on a line, stones at its foot).
  - **Net-lofts** now carry lattice nets (the kit's `net`) instead of flat sheets.
  - **No procedural stand-ins left in Act I:** Saltmarrow's last pine, Shingle Point's rock
    and every gate post (all three regions) are Blender models.
  - **Saltmarrow re-dressed:** Mara's house is the porch house, its steps coming down by
    Dunstan's stool; the harbor-edge house is the tall one; a **second stilt row** stands in
    the west shallows (a tall house and a stilt house, doors to the shore). Four identical
    houses became three kinds.
  - **Harbor life:** the ferry, the fishing boat and the rowboat **bob and roll** on a slow
    swell (out of step with each other) with a **foam ring** where the hull meets the water
    (new prop field `float`, `FloatingProp`).
  - **Mara looks out over the harbor** (she stood with her back to it), and **every NPC now
    turns to face the player while talking**, easing back to their placed facing after; the
    Wakebearer turns to them too. Hushed Hesk doesn't look up from her net
    (`"faces_player": false`).
- **Engine:** prop `colliders` (extra boxes; the porch and its steps), prop `float`, NPC
  `faces_player` — all validated.
- **Tests:** `test_village.gd` (9 tests: no procedural props left in Act I, house variants in
  use, houses stand on the ground, porch colliders, validator checks, boats float + bob within
  amplitude, foam ring fades outward, NPC facing maths/easing, Hesk keeps mending). Smoke test
  now checks Mara actually turns to the player in the running game. 88 tests + smoke + launch
  pass.

Screenshots (`docs/screenshots/2026-09-30-village-*.png`): `before-overview` vs.
`after-overview` (same camera), `before-mara` vs. `after-mara` (the porch house; Mara now
faces the harbor), `stilt-row` (the new houses in the west shallows), `boat-foam` (ferry and
fishing boat with foam rings, the tall harbor house), `lofts-gate` (Gull's Head gate posts and
lattice nets), `kit` (the new models).

**Decisions**
- **Houses keep the stilt house's wall box and deck** so one `collider` fits every variant and
  swapping a house is a one-line data change. The porch reaches out in front, so it gets its
  own boxes via `colliders` rather than a bigger box that would stick out behind.
- **Foam as a ring mesh, not in the water shader:** the water's foam comes from depth baked
  from the ground, which knows nothing about boats. A level vertex-alpha ring works in every
  renderer, can breathe with the bob, and costs one draw call per boat.
- **Turning is visual only:** the NPC's body turns, not its node, so placement data, the
  interaction area and saves don't change. Mara could face the sea without being rude.
- **Hesk opts out** — she's Hushed and "knows no one"; not looking up fits her better.
- Kept the new models under the dressing test's 16-mesh budget by folding near-identical
  shades (first builds had 18 and 25 material groups).

**Problems / notes**
- The first harbor screenshot showed a stale import (a removed rope coil still visible);
  re-importing fixed it. Always `--import` after re-running a Blender script.
- House side walls (±X) are flat colour (boards only front and back) — logged.
- The camera can now clip into the tall houses when orbiting close, like the Gull's Head
  cliffs — a camera collision ray is logged under the terrain/atmosphere follow-ups.

**Next run should**
1. The **polish/debt pass is due by session 16** (Day 8 was the last): the next session or
   the one after. Good candidates: camera collision (cliffs + tall houses), HUD key hint
   under the dialogue panel, the lineup scenes reusing `Atmosphere`.
2. Systems: the **pause menu** (with "Return to title" for the Act I card) or settings.
3. Art next due by Day 16; content by Day 17.

## 2026-09-30 09:00 UTC — Day 13: The ferry's arrival — Act I ends (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Baseline green.
- **The ferry's arrival** (ROADMAP [C] #1; content was due by today). Pays off *Across the
  Grey* and every ferry flag Act I left open:
  - **The horn.** After Mara hangs the green lantern, arriving on Shingle Point or Gull's Head
    plays the horn (one long, two short) and a green light answers hers — "watched harbors
    never get ferries", so it never sounds in Saltmarrow itself. Quest → `meet_the_ferry`.
  - **The *Slow Mercy*** (new Blender model, 101 KB) berths on the east side of the dock with
    its boarding plank on the deck and a green masthead light; the fishing boat and rowboat
    moved to make room.
  - **Oda Farrow**, Tidewright ferry-master (new character: greatcoat, pine watch cap, white
    braid, brass deed-scale, bone horn). She weighs the deed — the player tells it as
    *claimed*, *shared* or *brusque* — then asks what the burn cost: she can still hum the
    lullaby (it slides off the player "like rain off a coat"), her crew bristles at the
    knot, and after the gull burn she remembers **Dunstan**, who crewed for her; the name
    won't stay with the player. Passage only as far as **Thornwold** (lanes run light to
    light; nobody lands on Cindermoor). She reacts coldly to the sleeve-ember.
  - **Pell's promise honoured**: Pell moves from the beach to the dock. *Promised* → a packed
    bundle, and lane law (children cross with their kin's leave) sends the player to Mara:
    vouch "on the ember" (Pell **aboard**) or side with her (**let_down**). *Refused* → Pell
    gives the player a **finding pouch** ("something lost, something GOOD"). *Undecided* or
    never asked → Pell asks, LOUD, on the dock. Oda won't take passage while a promised Pell
    is unanswered.
  - **Farewells:** Mara (one line per burn — after the gull burn she offers the traveller the
    cold second cup; if she knows Dunstan chose the fog she sends word that the stool is
    still by the door), Aldous won't cross and mentions Thornwold's old Keeper beacon-keeper
    (unnamed), Tam on Oda.
  - **Act I end card:** taking passage ("evening tide") shows a full-screen card — *Act I —
    The Wake* — recapping the player's choices (burn, Pell, Aldous, Dunstan, Oda and the
    sleeve), then "Keep exploring". The Vertical Slice is now playable start to finish.
- **Engine:** region **arrival `events`** (`RegionEvents`; validator: every event must switch
  itself off), **conditional multi-placement** of NPCs, **`act_ends`** in game.json
  (`ActRecap` + `ActEndCard`, shown only when an act ends *in play*), `--act-end=` debug arg.
- **Tests:** `test_ferry.gd` (9 tests); `test_dressing.gd` allows the ferry's bigger bounds;
  smoke test now 5 passes — hears the horn, meets Oda, settles Pell, takes passage and checks
  and closes the Act I card. 79 tests + smoke + launch pass.
- LORE: Day 13 canon — the *Slow Mercy* and Oda Farrow, the horn signal, lanes light to light,
  **the burn rule clarified** (off-islanders keep a burned memory, but it won't take root again
  in those who lost it), lane law, Keepers pay twice, Mara's message, Aldous's hook.

Screenshots (`docs/screenshots/2026-09-30-ferry-*.png`): `before-harbor` vs. `after-harbor`
(same camera), `dock` (Pell with the bundle, Mara, the plank), `oda` (Oda at the dock end by
the *Slow Mercy*), `card` (the Act I end card), `kit` (ferry, bundle and the fishing boat).

**Decisions**
- **Passage ends Act I, the crossing starts Act II.** Sailing now would land the player
  nowhere, so taking passage sets `saltmarrow_ferry_passage` and the quest waits at
  `evening_tide` (still `future`). The card says Act II is being written; play continues in
  Saltmarrow with a coherent world (the ferry stays in, Oda: "When the tide's right").
- **The horn as a data-driven arrival event** rather than a timer: there's no clock yet, and
  "you hear it on coming back" needs no save-format change. Events must switch themselves
  off, so they can't loop.
- **Pell appears in two regions** via exclusive `if`s instead of a new "NPC moves" system —
  the smallest change that keeps NPC data in one place.
- **Burn rule:** made explicit that burned memories survive off-island but can't be re-taught.
  It gives Oda her scene and future islands a way to mourn Saltmarrow's losses without
  undoing any choice.
- **Card on a snapshot diff:** act ends are compared with a snapshot taken at every region
  load, so loading a save (or a debug `--flags=`) never pops the card.

**Problems / notes**
- First smoke run failed: Pell's dock ask came after the Mara visit in the same pass, so a 5th
  pass was needed to get Mara's leave before Oda would sail.
- The ferry first had 20 material shades (> 16 mesh nodes); consolidated to 10.
- NPC rotations: Pell and Oda faced the sea at first (caught in screenshots, fixed). Mara
  has always stood with her back to the harbor — logged for the art pass.
- The end card's unlock race: DialogueUI unlocks input on a deferred call, so the card is
  shown deferred too (otherwise it would open unlocked).

**Next run should**
1. **Art** ([A], due by Day 14): terrain & atmosphere follow-ups or dressing follow-ups
   (ROADMAP #2/#3); fold in Mara's rotation and a waterline ring for the ferry.
2. Then systems: pause menu (with "Return to title" for the end card) or settings/audio.
   Polish/debt pass due by session 16.

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
