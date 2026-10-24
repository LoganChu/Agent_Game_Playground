# Emberwake — Dev Log

Newest entries first. Each entry: what was done, decisions & why, problems, next steps.

## 2026-10-24 21:00 UTC — Day 62: Kindleby, the Keepers' mother-house (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD with a stale `origin/main` again;
  fetched and reset local `main` to Day 61's `5eab605`. Baseline green (432 tests + smoke + launch).
- **Content (due by ~Day 64; last Day 60):** ROADMAP *Next up* #1's main candidate, **the lane on from Wrackholm**, as the
  fifth island's first part. Act II's outline wanted the Keepers to court the player as the Tidewrights (the oath) and the
  Unmoored (the fen) have; nobody had met the Keepers as an *order* yet, only three strays (Aldous, the Lamp, Ottie's road).
  - **The Taper.** At Wrackholm with the Wrack lit, Oda's new "Where does the lane go from here?" tells of the Keepers'
    water south-about to **Kindleby** ("like steering down a wick"; "thanked every time, and never once asked in";
    `wrackholm_oda_lane_asked`). The first sailing weighs `wrackholm_who_answered=keepers` ("I'd not be the one to say it
    first on Kindleby"), `thornwold_lamp_name=told` and `thornwold_far_shore=waiting`; then hundreds of candles ringing an
    island, and **the quay bell answers before Oda blows** (one stroke, then three — a new `quay_bell` sound). Kindleby is
    the fifth port on the lane map (`data/lanes.json`: port, the Taper lane); every long passage knot learned to start or
    end there; Oda's `kindleby` port menu (her "word on the water" options too) and `kindleby_back`.
  - **New region `kindleby`:** a pale stone island, a quay and landing stage, **a ring of candle ledges** (17) inside the
    shore with the fog standing a cable's width off all round, the chapter-house up the steps, **the Quiet House** apart
    by the water, the chapter's skiff drawn up by the quay, the **Vigil Light** dark on the crown. Arrival event →
    **A Light for Kindleby** (`the_candles` → `the_rite` → `the_chapter`; `future`, the burning is a later session).
  - **Brother Tobin Ashe** (bell-porter, nineteen, never been to the Spire): the forty candles each ("barely isn't nothing"),
    the Provost ("never asked them a thing. ...Some of them, you'd want to ask"), being called up, the Quiet House ("they
    put the bar back after"; humming, "not quite the same tune").
  - **Provost Agathe Lorn:** weighs the sleeve-ember ("Aldous Wren. He always did pick at things... ran the furthest, and
    the least far"), the story off the Tidewright decks ("Stories like that get people drowned"), the oath. **The rite:**
    for nine hundred years a Keeper chose what a beacon burned, "so that others needn't"; she asks the Wakebearer to bow
    to it (`kindleby_rite` bowed / refused / think on it; "the chapter's wrong, and not yours"). **Aldous's word** (if he
    confessed) meets the order's ("the Firstflame failed"), and a full confession's light down the stair gets "...Did he."
    **The Lamp:** named → Wynn Sallow struck through in the Long Book ("never scraped"); not named → "that's not a name,
    that's a post" (she doesn't hand over the name Paid Twice finds). **The far shore's promise kept** (`waiting`): "There
    is no Spire to tell. There's me. Very well: you've told the Spire" — the skiff goes north when the chapter sits.
  - Inspectables: **the Quiet House** (barred from outside; humming) and **the Vigil Light's door** (the key is hers).
- **Art (folded in):** `tools/blender/build_kindleby.py` — `chapter_house`, `candle_ledge`, `vigil_bell`, `quiet_house`,
  `vigil_light`; characters `provost` (white robe, red stole, the key, hands folded) and `tobin` (lighting taper, candle).
- **Tests:** `test_kindleby.gd` (10: the Taper's gating and sailing, the sailing's memory, the layout and the candle ring,
  the kit, the arrival, the Provost's weighing, the rite three ways with Tobin and Oda after, Aldous and the Lamp, the far
  shore's promise, the Quiet House and the Vigil door). `test_lane_map`, `test_wrackholm` and `test_word_on_the_water`
  cover the fifth port. **Smoke walk** sails the Taper from the long passage out (Tobin, the Provost, bowed, the Quiet
  House) and comes home to Saltmarrow four lanes in one. 442 tests + smoke + launch pass. Checkpoint **`kindleby`**.

Screenshots (`docs/screenshots/2026-10-24-pm-*.png`): `the-provost`, `tobin-at-the-bell`, `the-quiet-house`,
`lane-map-taper`; `docs/checkpoints/kindleby.png`.

**Decisions**
- **Kindleby's theme is who chooses what's forgotten.** Four burnings the player chose alone; the Keepers' rite says a
  Keeper always chose for others. It sets up the next burning as a choice about the choice, and foreshadows mystery #1
  (the Keepers choosing what the Firstflame burned) without saying a word of it. The Quiet House (barred from outside,
  humming) foreshadows #1/#3 the same way; nothing about it is explained, and the player cannot go in.
- **Mystery #2 stays shut:** Tobin never went to the Spire; the Provost wasn't there that night and doesn't know the
  Wakebearer's face. No novices' roll here (that is the Spire's, in the warden's niche); the Keepers' **Long Book** of the
  dead/lost is a different book.
- **The Provost holds the order's word, not the truth:** she says the Firstflame *failed*. She may or may not know better;
  that is left for Kindleby's later parts.
- **A real Vigil Light model** rather than reusing Thornwold's beacon (the ridge-kit test rightly pins that to Thornwold).
- No `kindleby_beacon_burned` flag yet: the validator wants every declared flag set somewhere. The port's `lit` reads
  `quest:a_light_for_kindleby=done` until the burning is written (then switch to the flag, as the other ports do).
- Saltmarrow's ferry/Oda placements negate every other port; `kindleby` added (the exclusivity check caught it).

**Problems / notes**
- None blocking. The candle flames are small at a distance in the Compatibility renderer; the art session might give the
  ledges a soft `halo` (no OmniLights: the light budget stands).

**Next run should**
1. ROADMAP *Next up* #1 — an **art-led** session is due (~Day 63; last Day 58): Kindleby's look first (candle glow at
   distance, the chapter-house interior wall / bell-cote detail, a second Keeper or two on the candles so the island isn't
   empty), or Wrackholm's empty bracket. Content next ~Day 65 (Kindleby part two: the chapter sits). Fetch before trusting
   `origin/main`.

## 2026-10-24 09:00 UTC — Day 61: Polish/debt pass eight

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; fetched and reset local `main`
  to Day 60's `d60b5d8`. Baseline green (426 tests + smoke + launch, 2 min 57 s).
- **Polish/debt (due by Day 62; last Day 54):** ROADMAP *Next up* #1's list.
  - **`flag:x=a|b`** — a flag condition may name several values (any of them). `Conditions.parse` adds `values`;
    `joint_witness` tries each; the validator checks each against the flag's `values` list. Used at once: Day 58 split
    Wenna's rake placement (and her seat before it) into a `road` and a `hearth` copy because the exclusivity check couldn't
    know `thornwold_bend_breaking_out` only follows those two; each is one placement again (`thornwold_bend=road|hearth`).
  - **Steps that never play:** the validator reports any step after one that always leaves its knot — an unconditional
    `goto`/`end`, or an unconditional `choice` whose every option jumps, ends or opens the lane map, with one option
    always offered (Day 60's lost Hesk line, by hand). Current content has none.
  - **`joint_witness` searches key by key.** Every term reads one key and the conditions are all ANDed, so a joint state
    exists exactly when each key has a value satisfying its own terms. The old search walked the whole product of every
    key's values (re-parsing the terms for each state) and **gave up past 65 536 states by answering `{}` — "exclusive"**:
    a pair of placements with enough flags would have passed unproved. Linear now; placement checks 0.6 s → 0.07 s,
    tests 88 s → 69 s.
  - **The back hint follows the device:** `InputSetup.back_hint()` (`[Esc]` / `[B]`, for `ui_cancel`, which has no
    physical keycode to read). Device swaps are now noted once, by `GameState.note_input` on the root window's
    `window_input` (before any node's `_input`, so a modal that handles the event still sees the swap), and announced
    as `GameState.input_device_changed`; the HUD key hint, the journal's "close", the menus' "back" and the lane map's
    legend re-label on it (until now only the HUD and the map, the map only on open).
  - **Check times:** tests 69 s, smoke 65 s, the whole of `run_checks.sh` under 3 min; nothing to split. A validation run
    is now ~1.3 s, nearly all region checks (the woods ~0.2 s) — the next thing to profile if tests creep up.
- **Tests:** `test_polish_eight.gd` (6: alternatives parse/evaluate/witness, the validator on a misspelt alternative,
  Wenna's single placements per outcome, no state limit, steps that never play and ones that may fall through, the back
  hint in the journal/title menu/lane map). `test_settings` drives the device swap through `GameState.note_input`.
  432 tests + smoke + launch pass.

**Decisions**
- **Alternation, not flag implications.** I first sketched a `requires` field on flags ("breaking_out implies bend is
  road or hearth") for the witness search to honour; it needs an OR to say anyway, and once conditions have one the
  placement can simply say it. Smaller language change, no new data field.
- **The device swap is noted at the window, not in the HUD.** With several UIs wanting it, whichever `_input` ran first
  would have swallowed the change for the rest; the title screen has no HUD at all.
- No checkpoint (no new story point); no art.

**Problems / notes**
- `Conditions.joint_witness` answered "exclusive" on a parse error too; it still does (the error itself is
  reported by the condition check), noted here in case that ever hides something.

**Next run should**
1. ROADMAP *Next up* #1 — **content** (due by ~Day 64; last Day 60): the lane on from Wrackholm, or the small follow-ups
   listed there. An art-led session is due ~Day 63. Fetch before trusting `origin/main`.

## 2026-10-23 21:00 UTC — Day 60: Word on the Water (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Local `main` matched `origin/main` (`ad03e9e`)
  this time. Baseline green (417 tests + smoke + launch).
- **Content (due by Day 61; last Day 57):** of ROADMAP *Next up* #1's candidates I took the small follow-ups over the
  lane on from Wrackholm — they pay off threads already open (Dunstan's message for Oda has waited since Day 51; nobody
  on Saltmarrow but Mara had noticed him home) instead of opening a fifth island.
  - **Oda hears it** — a new option in all four of her port menus once *The Walk Back* is done: "Dunstan had word for
    you" ("The big man from the rowboat…" after the gull burn). "He's not laughing at the weather. He's laughing at
    something else." Two winters he crewed for her and laughed at every blow; she never asked what at ("You don't, on a
    deck"). After the gull burn: "his own sister doesn't know his face, and I do. That's the burn's way round."
  - **Quest *Word on the Water*** (`word_on_the_water`: `to_dunstan` → `to_oda`). **home:** "Tell him his berth's still
    swung on the Mercy. He'll not take it." He laughs like an anchor going over: no, thank you, **"it's a stool now"**;
    Oda: "A man ought to have one thing that stays where he left it." **stayed:** Oda knocks twice on the rail — when he's
    done turning boards he rides home on the Mercy, **no fare** ("Thirty-eight years sworn and I've never said that to a
    man"); he'll go home by oar, but wave from the staithe every time the Mercy goes by.
  - **Saltmarrow notices** (home): **Tam** rang the gate bell "like he was a fire" ("It seemed owed", for a stranger after
    the gull burn); **Hesk** — "The Tollen shoulders came home… Got it, did he?", and after the knot burn took the knot she
    mends, "I remember that. I remember that one"; **Pell** on Saltmarrow is learning to whittle on the stool nobody sits
    on ("a potato with opinions") or, let down, has been told they're "allowed to be cross a bit". **Aldous** (home or
    stayed, one-time, `saltmarrow_aldous_heard_walk_back`): the Keepers told every island for nine hundred years that the
    fog doesn't give back what walks into it, and he said it to Mara's face the week Dunstan went — "Then it was a lie. Or
    it was only true while the Spire burned, and none of us ever asked why that should be."
  - Checkpoint **`word_on_the_water`** (Saltmarrow, the Mercy at the dock, the berth to carry).
- **Tests:** `test_word_on_the_water.gd` (9: nothing before he's named, the option at every port with the map still
  there and "Not yet." last, home end to end, the gull burn, stayed, Tam, Hesk on every burn, Pell, Aldous). 426 tests +
  smoke + launch pass.

Screenshot: `docs/checkpoints/word_on_the_water.png` (Dunstan on his stool with his cup, Mara by her door).

**Decisions**
- **The message is a round trip, not a one-liner.** "She'll want to know" begged an answer; carrying Oda's word back and
  his answer back to her makes the lanes carry something other than the Wakebearer, and gives the stayed ending a seed
  for its walk home (by oar, waving at the Mercy) without resolving it.
- **No new flag for what was said** — the quest's stage is the state, and `fen_dunstan_walk` decides which word Oda sends.
- **Aldous's line foreshadows, it doesn't explain** (mysteries #1 and #3): the saying was true "while the Spire burned".
  Hesk keeps nothing of Dunstan after the gull burn — the Hushed holding burned memories would be a canon decision about
  mystery #3, not one to make in a follow-up.
- After the gull burn the islanders' lines never name him (the burn took him from everyone on Saltmarrow, LORE Day 9).

**Problems / notes**
- Appending a line to Hesk's `start_knot_burned` put it after the knot's `goto hub`, where it never plays; the test caught
  it. The validator could flag any step after an unconditional `goto`/`end` (added to the polish pass).

**Next run should**
1. ROADMAP *Next up* #1 — **polish/debt pass eight** (due by Day 62; last Day 54). Fetch before trusting `origin/main`.

## 2026-10-23 09:00 UTC — Day 59: The lane map (systems)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD with a stale `origin/main` again;
  fetched and reset local `main` to Day 58's `2c3eec6`. Baseline green (409 tests + smoke + launch).
- **Systems (due by ~Day 61; last Day 56):** Milestone 2's **ferry travel system & map screen**, which ROADMAP had
  carried since Day 17 ("replace Oda's sail/back dialogue choices with a lane map"):
  - **`data/lanes.json`**: the four ports (id = their `lanes_ferry_at` value, name, light, `lit`/`known` conditions,
    region, chart point, `passage` knot), Cindermoor as a dark landmark, and the three lanes (`open`, `sailed`, the
    knot that sails each way, Wrackholm's "Not this tide" closed text).
  - **`Lanes`** (scripts/core/lanes.gd): current port, known ports/lanes, a BFS route over open lanes, and
    `voyage(to)` → the knot to play or why not. A neighbouring port plays the lane's existing knot (first sailings
    still redirect to their arrival stories); a longer voyage needs every lane on the way sailed and plays the
    destination's new **`passage`** knot (four in `oda.json`, a line per start port: "puts in only long enough to
    take on water").
  - **Dialogue:** an option with `"lane_map": true` makes the runner return a `lane_map` event and wait;
    `sail_to(port)` jumps to the voyage's knot, `sail_to("")` re-offers the choice. Oda's per-lane options ("Sail
    north-about…", "Take me back to…" ×3, the later "Cast off for Thornwold.") are gone; every port offers **"Where can
    you take me?"** once *Across the Grey* is done. The first crossing stays a plain option (it ends Act I).
  - **`LaneMap`** (scripts/ui/lane_map.gd), a child of DialogueUI shown in place of the box: a drawn chart (faceted
    isles round dark Cindermoor and its cold spire, lit isles green with a beacon point and a glow, the ferry's port
    ringed in ember), lanes solid gold when sailed / dashed gold when not yet / grey dashed when closed, the chosen
    route in ember, a button per known port, an info line ("Wrackholm — the Wrack Light, lit. By way of Glasswater
    Fen. Press to sail."), a legend, and "Not yet." (Esc/B too). Interact, accept or a click sails.
  - **Validator:** lanes.json (port ids are flag values, real regions, chart points in 0..1, every lane/passage knot
    exists and — through its gotos — sets `lanes_ferry_at` to its port and travels to its region), lane knots count as
    reachable, `lane_map` options only in the ferry dialogue.
  - Debug **`--lane-map[=port]`** opens it (reads any arrival scene through first) for screenshots.
- **Tests:** `test_lane_map.gd` (8: home before the crossing, the chart growing as Oda tells of lanes, the map
  replacing the options but not Act I's crossing, turning back, neighbour voyages, long voyages both ways and the
  near-end rule, every passage naming the lights it passes, the validator). `play_dialogue` takes `"@port"` picks on
  the map; test_crossing / test_fen_lane / test_wrackholm moved from option texts to the map. The smoke walk sails by
  the map (`_sail`), its region walker sails to the first neighbouring port (same sailings list as before, checked
  against a baseline run), and after the east stair it takes **Saltmarrow → Wrackholm → Saltmarrow** live.
  417 tests + smoke + launch pass.

Screenshots: `docs/screenshots/2026-10-23-lane-map.png` (all four lit, the route to Wrackholm by the fen),
`docs/screenshots/2026-10-23-lane-map-first.png` (the Ridge Light just lit: the fen dark, its lane dashed).

**Decisions**
- **The map lives inside Oda's dialogue**, not as a separate travel screen: she's the one who sails, her lines for a
  first sailing (and everything they react to) stay hers, and the voyage knots didn't need rewriting. The chart only
  decides *which* knot.
- **Multi-lane passages only over sailed lanes.** Skipping a new lane's arrival story by sailing past its near port
  would lose content and break "lanes run light to light"; the refusal says where to go first.
- **The first crossing is not on the map.** It completes *Across the Grey* and ends Act I; it stays the explicit
  "Cast off for Thornwold." option until it's done.
- **A ring round Cindermoor** (now in LORE): Saltmarrow SW, Thornwold W, the fen N, Wrackholm NE, consistent with
  "north-about" and "east-about"; Cindermoor dark in the middle, not a port.

**Problems / notes**
- `ui_cancel`'s built-in binding has no physical keycode, so the legend says "[Esc]"/"[B]" itself rather than
  `InputSetup.hint`.
- The debug `--lane-map` had to read the Thornwold landing's arrival scene through first: an open event dialogue
  blocks `DialogueUI.open`.

**Next run should**
1. ROADMAP *Next up* #1 — **content** (due by Day 61): the lane on from Wrackholm, or the small follow-ups listed there.
   Fetch before trusting `origin/main`.

## 2026-10-22 21:00 UTC — Day 58: Breaking out the clamp; Abe's hands on his hips (art)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD with a stale `origin/main` again;
  fetched and reset local `main` to Day 57's `c3badea`. Baseline green (402 tests + smoke + launch).
- **Art-led (due ~Day 59; last Day 52):** ROADMAP *Next up* #1, the Coll's Hearth follow-ups from Day 57 and Abe:
  - **`_bent_arm`** (build_characters.py): replaces a straight base arm with one bent at the elbow (two 0.27 m segments)
    reaching a hand point given in the *posed* body, so a stoop (`torso_rest`) is accounted for; the elbow bows along a
    hint. Rigid arms rotated at the shoulder can't put a fist on a hip or two hands on one pole.
  - **Abe Dray** rebuilt with it: elbows out wide, fists on the coal-red sash, sleeves rolled at the elbow. (Before, his
    "hands on hips" were straight arms swung 38° out: arms held stiffly out, the far-shore Known issue.)
  - **`wenna_coll_rake`**: Wenna standing at her clamp with the hood pushed back, knees bent and stooped 25° into the work,
    the clamp rake in both soot-black hands (back hand at her hip, front hand down the pole), its iron head down in the
    charcoal ~1.4 m in front of her. The rake is the static `Stool` part so it stays on the ground under the idle.
  - **`clamp_spent_open`** (build_bend.py): the spent clamp with the front raked open to the hearth (black bed inside), a
    fan of charcoal drawn out on the moss, four tied sacks at the side and a fifth open with charcoal in its mouth.
    `clamp_spent` and `hut_lantern` rebuild byte-identical.
- **In the game:** a one-time arrival event at Coll's Hearth once *The Bend in the Road* is done
  (`colls_hearth_breaking_out` → `thornwold_bend_breaking_out`): you hear a rake in charcoal before you see her ("It's a
  sack at a time, this... You can't hurry a burn and you can't hurry the breaking"); variants for the lit bend and for the
  hearth way in. From then on she's at the clamp with the rake instead of on her seat, the open clamp replaces the spent one,
  and her talk and the clamp's description say so. The day she chooses she still sits by her door, as Day 57 wrote it.
- **Tests:** `test_clamp_broken_out.gd` (7: seated the day it ends, the next arrival on both outcomes and only once, not
  before she chooses, her talk and the clamp after, the rake on the ground in front of her, the open clamp's size, Abe's
  fists at his hips with elbows wide). The smoke walk now goes back out along the lit bend to find her at it. 409 tests +
  smoke + launch pass.

Screenshots: `docs/screenshots/2026-10-22-pm-breaking-out.png`, `docs/screenshots/2026-10-22-pm-wenna-rake.png`,
`docs/screenshots/2026-10-22-pm-abe-hips.png`.

**Decisions**
- **She's raking on the *next* visit, not the moment the quest ends.** Day 57's endings have her sit down by her door for
  the first time since the Snuffing; standing her up at once would undo that beat. An arrival event (like Day 57's first
  light) gives a "later" without a day/night clock; when the clock lands it can own this too.
- **The rake idle stays `breathe`, not `rake`.** The `rake` idle swings the arms ±17° at the shoulder; with a 1.7 m pole
  that drives the head 0.3 m into the ground. She reads as pausing mid-stroke; a pull animation for two-handed tools would
  need the pole to follow the hands (noted below).
- **The stooped skirt rides the legs.** A dress-length smock on the Torso part swings back like a bell when the waist bends;
  for the rake pose the skirt goes in `LegL` and only the bodice bends.
- No checkpoint: a small after-scene, not a new story point (the_bend_in_the_road's checkpoint still shows the choice).

**Problems / notes**
- The validator's NPC-exclusivity check doesn't know `thornwold_bend_breaking_out` only follows `road`/`hearth`, so the rake
  placement is split in two (one per outcome).
- The opened clamp's charcoal reads grey rather than black in the Compatibility renderer, like the rest of the ink tones;
  one more thing for the Vulkan colour pass.

**Next run should**
1. ROADMAP *Next up* #1 — **systems or content** (both due by ~Day 61). Fetch before trusting `origin/main`.

## 2026-10-22 09:00 UTC — Day 57: The bend in the road (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD with a stale `origin/main` again;
  fetched and reset local `main` to Day 56's `2328d57`. Baseline green (392 tests + smoke + launch).
- **Content (due by Day 59; last Day 55):** ROADMAP *Next up* #1, **Wenna's walk out along the lying cart road**, the
  thread Day 55 left open ("I'm going out along the cart road in the morning... If it's lying, I'll know, now"):
  - **Asking.** Home in the clearing after *The Far Shore*'s `up`, Wenna now takes "Can I walk out with you in the
    morning?" → *The Bend in the Road* begins; she'll be by the first waymark past the wall at first light.
  - **First light.** The player's next arrival in the woods is the morning (`woods_first_light`), Wenna under the first
    waymark with her lantern held over the moss. She explains how a road lies: the cart road used to **bend east** round a
    hollow past her hearth; the night of the Snuffing it straightened itself, and "it doesn't stop you. It just doesn't take
    you there." "Show me." — her light (the Lamp's warm-side coal) finds the ruts under the moss, and you walk them east.
  - **New region, Coll's Hearth** (`thornwold_colls_hearth`): a hollow where the fog stands back ("It was never the place
    that was lost. It was the way to it."), her cone hut cold since the Snuffing, her **clamp lit the evening of the
    Snuffing and burned clean through untended** (the best burn she ever had; she wasn't there for it), a truthful
    cutter's stake, and a Keepers' waymark at the bend with an empty hook. The ruts go on north into thick fog.
  - **The choice — where her one light goes:** **on the bend's waymark** (`road`: the fog leans off the whole bend, "Now
    it's a road"; Hob comes along it — "Road's a road again. Said I'd come in when it was", his Day 21 promise turned out to
    be about her road; Bram's board grows a stick marked BEND, her own cart to the gap) or **by her own door** (`hearth`: "a
    light of my own... I meant it"; the bend stays lost to everyone else; she carries her sacks to Hob's cart and stands
    there till he sees her). Either way she sits on her own seat for the first time since the Snuffing and puts the fire in.
    Boots-path variants for Hob and Wenna throughout; Hob-gone-and-home gets his line too.
  - **Folded in:** **a lantern by Hob's hut door** after `up` (Ottie's promise — the Known issue from Day 55), and **Bram's
    CHARCOAL row in four and five hands** after `up` (the roadmap's "five hands" follow-up; the older two-hands lines now
    stop at `up`).
- **Art (folded in):** new `tools/blender/build_bend.py` — `clamp_spent` (a clamp sunk to a grey hump, turf slipped
  silver, the front fallen in on finished charcoal, the stake ring leaning) and `hut_lantern` (a Keeper's lantern on a
  forked stake; used for Wenna's door and Hob's).
- **Tests:** `test_bend_in_the_road.gd` (10). The smoke walk now **takes the bend live** after the far shore (ask, down to
  the landing and back through the wall for first light, show, road, back along the ruts). 402 tests + smoke + launch
  pass. Checkpoint `the_bend_in_the_road`.

Screenshots: `docs/screenshots/2026-10-22-first-light.png`, `docs/screenshots/2026-10-22-colls-hearth.png`,
`docs/screenshots/2026-10-22-the-bend-lit.png`, `docs/screenshots/2026-10-22-hobs-lantern.png`;
`docs/checkpoints/the_bend_in_the_road.png`.

**Decisions**
- **The choice is a light of one's own vs. a road for everyone** — the same coal Wenna sat on a quay for. `road` costs her
  the thing she asked for and gives the woods a true road (and Hob's old promise a meaning); `hearth` honours her wish and
  leaves the lie in place. Neither is a punishment; both are recorded in `thornwold_bend` for later (e.g. Bram's camp
  or a Keeper reading the cart road).
- **"Next morning" without a day/night system:** a one-time arrival event on the next woods arrival. When the real clock
  lands (Milestone 2), it should own `thornwold_bend=morning`.
- **The Snuffing was three months ago** (LORE timeline): first drafts said "a year" in Wenna's mouth; all changed to "since
  the Snuffing". Worth a grep in future content.
- **Only light finds the bend** (Greying v2's "paths that fade", faked): the ruts' paint and the woods' way in appear
  only once walked; the north end stays faded unless the bend is lit. A real fading-path feature is still Greying v2 work.
- **One knot-name collision** (`hearth`, already Wenna's far-shore knot) silently replaced old dialogue in the first
  draft; `test_far_shore` caught it. The new outcome knot is `keep_it`.

**Problems / notes**
- The validator's event rule wants a `!flag:<bool>` term, so the string flag needed a companion `thornwold_bend_first_light`.
- Wenna sits on both outcomes (the seated model); a standing-with-rake variant is on the art list.

**Next run should**
1. ROADMAP *Next up* #1 — **art-led** (due ~Day 59). Content next due by Day 61 (the lane on from Wrackholm). Fetch before
   trusting `origin/main`.

## 2026-10-21 21:00 UTC — Day 56: Settings follow-ups (systems)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD with a stale `origin/main` again;
  fetched and reset local `main` to Day 55's `d090ce2`. Baseline green (387 tests + smoke + launch).
- **Systems (none since Day 46):** ROADMAP *Settings follow-ups* (#3), four pieces on the Settings page:
  - **Text speed** — dialogue lines now type out (Slow 25 / **Normal 50** / Fast 100 chars/s / Instant). Interact or a
    click mid-line shows the rest of the line; it never skips one. Choices and closing finish any reveal.
  - **Stick deadzone** slider (5–50 %, default 20 %) → the InputMap deadzone of the move and camera pad axes.
  - **Display** (Windowed / Fullscreen) and **VSync** (On / Off) toggles, applied through DisplayServer.
  - **Pad prompts** — once a pad button is pressed (or a stick leant past half-way) the HUD hints and the dialogue
    "continue" show the pad's buttons ([A] Talk, [Back] Journal, [Y] Satchel, [Start] Menu); a key press or click
    swaps them back.
  - All new values are in `user://settings.cfg` (`[display] text_speed/window_mode/vsync`, `[pad] stick_deadzone`),
    clamped on load like the rest; Reset puts them back.
- Small refactor: the Settings page's value buttons share one `_add_toggle` (change → save → rebuild, focus kept), which
  drops the hand-counted focus indices.
- **Tests:** `test_settings.gd` +5 (text speed cycle, the typewriter, the deadzone on the pad axes, window mode/vsync,
  pad prompts and the HUD hint) and the round-trip/bad-file/menu tests extended. 392 tests + smoke + launch pass.

Screenshot: `docs/screenshots/2026-10-21-pm-settings.png`.

**Decisions**
- **Default text speed is Normal (typing), not Instant.** It's the narrative game's voice; Instant is one press away
  and no gate waits on the reveal (accessibility pillar: no timing gates). `advance()` stays "next line" so tests, the
  smoke walk and the checkpoint tool are unaffected; only the player's press goes through `press_continue`.
- **Screenshots finish the reveal** before capturing (`dialogue_ui` group), so `--dialogue=` shots show whole lines.
- **Pad labels are Godot's SDL names** (A/Y/Back/Start), not drawn glyphs — readable on every pad for now; per-brand
  names and icon art are a later follow-up.
- **Display is skipped under the headless server**, so CI only checks the stored values; a maximized window is left
  alone when "Windowed" is applied.
- No checkpoint: nothing new in the story.

**Problems / notes**
- `get_viewport()` is null for a DialogueUI outside the tree, so the test drives `press_continue()` rather than a fake
  input event; `InputMap.event_is_action` ignores deadzones — the test uses `InputEvent.is_action_pressed`.
- Needs the owner's hands: fullscreen/vsync and the pad prompts can't be seen in the sandbox (no window, no pad).

**Next run should**
1. ROADMAP *Next up* #1 — **content or art-led** (both due by ~Day 59): Wenna's walk out along the lying cart road, or
   the lane on from Wrackholm; or the art follow-ups (Hob's hut lantern after `up`, Abe's pose, Wrackholm's bracket).
   Fetch before trusting `origin/main`.

## 2026-10-21 09:00 UTC — Day 55: The far shore (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; fetched and reset local
  `main` to Day 54's `867f914`. Baseline green (378 tests + smoke + launch).
- **Content (due by Day 57; last Day 53):** ROADMAP *Next up* #1, **the far shore below the Northing** — the three
  colliers' thread, open since Day 21 ("five hearths... the others went up after the Lamp") and Day 53 (where they went):
  - **The way down.** The old road's Keepers' steps now offer "Go down the Keepers' steps." once the Northing has a light
    (hung there, or carried down by Ottie), starting ***The Far Shore***; the way back up is an exit at the steps' foot.
  - **New region, The Far Shore** (`thornwold_far_shore`): a shingle beach under the 14 m north cliff (the Northing far
    overhead, its lantern or coals showing), closed by two buttresses, the fog a grey lid that thins in the cliff's lee,
    and the **Keepers' boat-stage** — a dressed-stone quay where the Spire's boat came in for the keeper: a bollard with a
    mooring ring worn bright on one side, thirty winters' strokes on its cap and Wenna's day-strokes after them, and the
    boat's lantern bracket (Ottie's lantern on it, if he carried it down).
  - **Wenna Coll, Abe and Tolly Dray** (new NPCs): Wenna on the end of the stage waiting for the Spire's boat to ask for a
    lantern ("a light of my own to find my clamp by" — her hearth is out along the cart road that lies); the Drays by a
    driftwood fire, Abe hopeful for the first time in forty years because Tolly isn't, and the story of their rake on the
    fifth mark. Ottie (carried) and Hob (The Fifth, gone) are there too.
  - **The Wakebearer's word:** **up** — "Somebody came down. That's what I was waiting for, maybe" — they climb, Ottie
    leaves his lantern on the bracket for the boat, the Lamp knows their faces and **breaks the warm side of the kept coal**
    into three lanterns (Wenna's hearth, the Drays', and Hob's hut, which Ottie promised him on Day 25); only the cold
    side is left. All four home in the colliers' clearing; Hob counts them in and stops counting (salt row), crosses all
    four notches (stayed), comes home with them (gone), or meets four friendly strangers (boots). Or **waiting** — the
    Wakebearer promises to tell the Spire there are colliers on the Northing's stage; they stay (Wenna can still be asked
    up later).
- **Art (folded in):** `build_old_road.py` — `steps_foot`, `boat_stage` + overlay `stage_lantern`, `drift_fire` /
  `drift_fire_out`, `drift_shelter`; `build_characters.py` — `wenna_coll`, `wenna_coll_lantern`, `abe`, `tolly`,
  `tolly_lantern` (780–970 tris) and a shared `_held_lantern`.
- **Tests:** `test_far_shore.gd` (9). The smoke walk now **takes the far shore live** after hanging the Northing's lantern
  (down the steps, Wenna told to come up, back up the steps) and checks the three home in the clearing.
  387 tests + smoke + launch pass. Checkpoint `the_far_shore`.

Screenshots: `docs/screenshots/2026-10-21-the-far-shore.png`, `docs/screenshots/2026-10-21-the-boat-stage.png`,
`docs/screenshots/2026-10-21-four-home.png`; `docs/checkpoints/the_far_shore.png`.

**Decisions**
- **The choice is coming home vs. keeping faith**, and the cost is the Lamp's coal: `up` spends what it kept "for the
  four" (paying off Day 27's line), `waiting` keeps it whole but leaves the colliers on a cold shore on the Wakebearer's
  promise to the Spire — a flag for Act III (`thornwold_far_shore=waiting`), not a new hook to chase now.
- **The coal's cold side stays.** "The side that faced the Spire" is kept "anyway" — the Day 25 detail stays a mystery
  with an object attached, instead of being burned away.
- **Wenna Coll's id is `wenna_coll`** (and her model `wenna_coll.glb`): Wrackholm's lane-warden already owns `wenna`.
- **No new idle styles.** Wenna uses `sit` (seated on a folded sack, the sack is her Stool part); Hob and Ottie on the
  shore reuse `hob_lantern` and `ottie`/`ottie_cap`.
- **The boat-stage is ground, the model is dressing.** The walkable quay is a `path` land feature; `boat_stage` only
  dresses its end, placed `snap: false` at the deck height — no pier collider needed.
- **Ottie's lantern stays on the stage after `up`** — a light burning for a boat that won't come; nobody explains it.

**Problems / notes**
- First test run: the NPC-in-one-place check found Hob `gone` could show with the woods' raking Hob (`!came_in`) — `gone`
  implies `came_in` but the validator can't know that, so the new `gone` placements read `flag:thornwold_hob_came_in` too.
- `boat_stage` first had a step down to the water below its origin; the kit test wants models standing on their origin,
  so the step went (the stage's own ground edge reads as the drop).
- The overlay was first named `boat_stage_lantern` — the same prop family as `boat_stage`, which the variant check would
  read as two variants on one spot; renamed `stage_lantern`.

**Next run should**
1. ROADMAP *Next up* #1 — **art-led or systems** (art due ~Day 59; systems last Day 46). Content next due by Day 59
   (Wenna's walk out along the lying cart road, or the lane on from Wrackholm). Fetch before trusting `origin/main`.

## 2026-10-20 21:00 UTC — Day 54: Polish pass seven (polish/debt)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). `main` was already at Day 53's `781c3d2`.
  Baseline green (374 tests + smoke + launch).
- **Polish/debt (due by Day 56; last Day 48):** ROADMAP *Next up* #1 / Known issues —
  - **The ember drain eases with the fog.** Since Day 23 a lantern lit or put out re-cut the fog over 4 s, but the
    drain (`Region.greying_depth`) jumped to the new light at once. It now lerps from the old active areas' depth to the
    new over the same `GreyingFog.FADE_SECONDS` whenever the areas change live (`_greying_blend`, ticked in
    `Region._process` — pauses with the tree; region loads settle at once).
  - **The old road falls away.** Its flanks were a pale green plain 8 m below the spine; the base is now -24 with slate
    shore/seabed, so from the road the sides are fog and from above the spine stands as a sheer slate wall.
  - **Small follow-ups (the Northing):** Hob notices Ottie home — salt-row, at the camp or the clearing: "Ottie's home…
    One. That's one. Three to come." (and the boots: on him, or "You've got his boots. Give a man his boots."); at the
    bottom of the road (*The Fifth*, stayed) Ottie stopped at his mark and Hob crossed the first notch through; boots
    path, "a man on the seat by the cold hut. Charcoal man…" and never his name. Bram's tally board: two charcoal notches
    a load in two hands (one new hand if Hob went down the steps), and Hob's stick of four shows the first crossed.
  - **Two stale Known issues closed** after an audit: Oda's "to Cindermoor" route line was reworded long ago, and the
    player never names the four to Hob after the boots burn (the cap and the Lamp's ladder story are already gated).
- **Tests:** `test_polish_seven.gd` (4: the drain's ease, Hob on Ottie home across five states, the board, the drop).
  378 tests + smoke + launch pass.

Screenshot: `docs/screenshots/2026-10-20-pm-the-old-road-falls-away.png`.

**Decisions**
- **`_process`, not a Tween, for the drain's ease**: the state is plain data the tests can step without a running tree,
  and it stops ticking once settled. A second light change mid-fade eases on from the areas just replaced (a small jump,
  noted in Known issues) rather than nesting blends.
- **Hob's lines are in his greet, not a new choice**: he says it unprompted, like the fourth mark going dark. Nothing on
  the `carried` path — Ottie never comes home, and nobody on Thornwold saw him go down.
- No checkpoint: nothing new to start from (the old road's look shows in `the_northing`'s next re-shoot).

**Problems / notes**
- The first ease test failed because a Region added to the root inside the test runner's `_initialize` isn't in the tree
  yet, so a Tween couldn't run there; moving the ease to `_process` fixed that and simplified it.

**Next run should**
1. **Content (due by Day 57; last Day 53):** ROADMAP *Next up* #1 — the far shore below the Northing, or the lane on
   from Wrackholm; add a checkpoint. Then art-led by ~Day 59. Fetch before trusting `origin/main`.

## 2026-10-20 09:00 UTC — Day 53: The Northing (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD with a stale `origin/main` again;
  fetched and reset local `main` to Day 52's `13ff58d`. Baseline green (364 tests + smoke + launch).
- **Content (due by Day 55; last Day 51):** ROADMAP *Next up* #1, **the old Keepers' road north** — where the four
  colliers went, open since Day 22 (Ottie's boots on the seat) and Day 25 (his cap on the stair's mark):
  - **New region, The Old Road** (`thornwold_old_road`): from the ridge's NE corner (exit gated on the Ridge Light lit)
    along Thornwold's spine — a few strides of grey stone and silvered heather falling sheer into the fog both sides —
    past three old marks (one with **Abe and Tolly Dray's rake** driven into its cairn) to **the Northing**, the
    Keepers' fire-cairn on the north cliff, with the **boat-watch** house beside it and the **Keepers' steps** going
    down into fog "thick as wool" over the far shore. The Ridge Light shows lit far behind. Arrival scene once.
  - **Ottie Swale** (new NPC, Blender `ottie` and five variants) keeps a **charcoal fire in the Northing's basket** for
    the three (Wenna Coll, Abe and Tolly Dray) who went down to the far shore to wait for the Spire's boat — the Lamp
    walked this road once a winter to meet it, so the colliers reckoned there were lanterns to spare at the end of it.
    He left his **boots** so Hob would know he was coming back; his **cap** comes back to him if the player carries it,
    and stays on the stair's mark otherwise ("Till I'm down, it's telling the truth"). What he hears of Hob follows the
    burn and *The Fifth* (counting / asleep and nobody's / built the mark at the bottom / went down the steps after them).
  - **Quest *The Northing*** (from the Lamp's new "Where does the old road north go?", or by meeting Ottie): told of
    Ottie, the Lamp lights a cold lantern at the Ridge Light's cradle (item `ridge_lantern`). The player's word —
    **hang it on the Northing** (`lit`: gold out over the cliff; Ottie rakes his charcoal out and goes home to his own
    seat in the colliers' clearing, in his boots, or in sacking if they burned — unburned boots the player carries can be
    handed back there) or **put it in his hand** (`carried`: he banks the charcoal and takes the light down the steps;
    the boots stay on the seat). The Lamp, the Northing, the steps and the cold hut all show it.
- **Art (folded in):** `build_old_road.py` — `northing_cairn` with two overlays modelled in place (`cresset_coals`,
  `cresset_lantern`), `waymark_rake`; `build_characters.py` — `ottie`, `ottie_cap`, `ottie_home`, `ottie_home_cap`,
  `ottie_home_unshod`, `ottie_home_unshod_cap` (~900–1130 tris).
- **Tests:** `test_the_northing.gd` (10). `test_ridge_kit.gd` loosened where it pinned the lodge and the lit Ridge Light
  to two regions (the boat-watch reuses the lodge; the old road shows the Ridge Light). The smoke walk now **takes the
  old road live** from the ridge (meet Ottie, the Lamp's lantern, hang it, Ottie on his seat in the woods on the way
  down). 374 tests + smoke + launch pass. Checkpoint `the_northing`.

Screenshots: `docs/screenshots/2026-10-20-the-old-road.png`, `docs/screenshots/2026-10-20-the-northing-lit.png`,
`docs/screenshots/2026-10-20-ottie-home.png`; `docs/checkpoints/the_northing.png`.

**Decisions**
- **One of the four found, three left below.** Pays off the boots and the cap and says where the four went, without
  emptying the thread: the far shore stays for a later session, now with a concrete question (people waiting on a boat
  that can't come while the Spire is dark).
- **The choice is what the light is for**, not home-or-stay again (Hob and Dunstan both had that): a light at the top
  for the three to climb to (and Ottie home), or a light carried down to them (the four together, nobody at the top).
- **The Lamp can give now.** Its "a lantern for one is a mark gone dark for the rest" no longer holds once the road is
  the beacon's (as with Hob's lantern, Day 49), so the lantern is lit off the Ridge Light, not the kept coal — which
  stays "for the four", unspent.
- **New canon, small and in keeping:** the Spire's boat called at the Northing for Thornwold's keeper each midwinter
  (how a keeper "never rode Oda's deck"); the Lamp stopped tending the far marks when its knees went (answers Day 26's
  "not said"). Nothing about the Spire's inside or the novices (mystery #2 stays shut).
- **Ottie leaves the cap hung** if it's still on the stair's mark — no prop swap needed, and it says something.
- Back from the old road lands inside the lodge's coal-light pool (the validator wants spawns clear in the worst case;
  nothing nearer the road's head is unconditionally clear).

**Problems / notes**
- The first smoke run failed in the pause-menu check: the walk never reached the old road before the "every region"
  check, so `_check_gates` teleported in later and the arrival scene held input. Fixed by walking the road live (and
  the event is gated on the Ridge Light); noted in Known issues for future gated regions.
- The lantern overlay's first build hung its glass 0.25 m below where the halo was put; caught by eye in the close-up,
  model and halo re-pinned (and tested).
- Low ground either side of the spine reads as a pale green plain under the fog rather than a drop (ROADMAP follow-ups).

**Next run should**
1. **Polish/debt pass (due by Day 56; last Day 48):** ROADMAP *Next up* #1 / Known issues. Then content by Day 57 (the
   far shore, or the lane on from Wrackholm), art-led by ~Day 59. Fetch before trusting `origin/main`.

## 2026-10-19 21:00 UTC — Day 52: Turning the boards; collars, cuffs and a mop (art-led)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). `main` was already at Day 51's `582a695`.
  Baseline: import, 363 tests and smoke green (the launch step tripped on my first fen edit, made while it ran — the
  new model wasn't imported yet; re-run clean afterwards).
- **Art-led (due ~Day 55; last Day 50):** ROADMAP *Next up* #1's candidates —
  - **`dunstan_turning`** (`build_characters.py`, 994 tris): the `stayed` ending of *The Walk Back* no longer stands
    holding the lantern. He's stooped at the head of the long walk, knees bent, a board lifted crosswise in both hands
    and half turned (grey driftwood, a moss stain at one end), the ship's lantern stood lit on the boards at his left
    boot. The fen's `stayed` placement uses it (same spot, same facing: toward the walk).
  - **Body `crouch` and `torso_rest`** in the character builder: standing legs bend at a knee forward of the hip, and
    the torso (with the head and arms) can rest bent at the waist. `CharacterRig` offsets from the rest transform, so
    no rig changes were needed; the `breathe` idle sways him like anyone standing.
  - **Silhouette touch-ups** (Known issues): Mara's coat collar turned up at the back and sides; Tam's sea boots with
    turned-down tops below his coat; Jory's hair a shaggy mop (clumps over the ears and nape, a tuft at the crown, the
    fringe fallen over the brow) instead of the flat-brimmed cap it read as.
- **Tests:** `test_walk_back.gd` +1 (`test_turning_a_board`: rigged, bent 0.6–1.1 rad at the waist, lower than
  standing, the only glow on `Stool` — the lantern at his boot); the `stayed` assertions expect the new model;
  `test_polish_four`'s boots-in-the-mere check skips it like the other standing Dunstan. 364 tests + smoke + launch pass.

Screenshots: `docs/screenshots/2026-10-19-pm-turning-the-boards.png`, `docs/screenshots/2026-10-19-pm-collars-cuffs-and-a-mop.png`.

**Decisions**
- **The board is part of his left arm**, not a ground prop: it moves with his hands. Both hands reach it from the
  rest pose, so the right hand's ±1 cm breath drift against it doesn't show.
- **No new idle style.** A slow heave (lift, turn, set down) would sell it better, but the board is baked into the
  pose; a proper "lift" style is noted for later rather than half-done now.
- **Bodies get `crouch`/`torso_rest` rather than a one-off leg rebuild**, so later stooped figures (a yard hand
  caulking low, someone at the mended lofts) can reuse them.
- No checkpoint re-shoot: Mara, Tam and Jory change by a few centimetres of collar, cuff and hair.

**Problems / notes**
- Blender's glTF export isn't byte-for-byte deterministic (rebuilding an untouched model changes the file); only the
  models meant to change were rebuilt and committed.
- The stooped gansey's skirt sits a little proud of his back when he bends (reads as his back; fine at play distance).

**Next run should**
1. **Content (due by Day 55; last Day 51):** ROADMAP *Next up* #1 — the lane on from Wrackholm or the old Keepers'
   road north; or the small Day 51 follow-ups (Oda hearing Dunstan's message, Pell/Tam/Aldous noticing him home).
   Add a checkpoint. Then the polish/debt pass (due by Day 56). Fetch before trusting `origin/main`.

## 2026-10-19 09:00 UTC — Day 51: The walk back (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again with a stale
  `origin/main`; fetched and reset local `main` to Day 50's `54dec82`. (My baseline run overlapped my first edits, so
  it isn't a clean baseline; Day 50 recorded 355 green and the untouched suites still pass.)
- **Content (due by Day 53; last content Day 49):** ROADMAP *Next up* #1, **Dunstan's walk back** — the last open
  thread of mystery #5 ("When I am, I'll walk back in with this and ask Hesper for my name. Not before.", Day 37):
  - **New quest *The Walk Back*** (`the_walk_back`, flag `fen_dunstan_walk`: '' / coming / in / home / stayed). Back on
    the fen any time after the Wrack is lit (arrival event `fen_dunstan_coming`): Hesper says the light is off the end of
    the long walk, halfway in, and stopped. She can't go out: his name is in her keeping.
  - **On the long walk** Dunstan stands with his lantern lit (`dunstan_lantern`): "Done. I think." The boards are all
    laid by people going in and tip you in the mere walked the other way; a lantern shows where you are, not where the
    next board is. The player walks ahead with the ember (opened "just this once" if it was cupped); the Unmoored turn
    from the light, and one or two turn back to look at who's walking out of the Deeps. `travel` to a new
    `from_long_walk` spawn at the staithe.
  - **His name:** Hesper won't hand it to the player ("He's to ask for it himself"); asked, she says it once —
    "Dunstan Tollen. Of Saltmarrow." (her own name burned: "I couldn't keep my own. I've still got yours"; after the
    `gull` burn it goes past the player like rain off a coat).
  - **The player's word:** **home** ("Mara's keeping the stool" / after the gull burn "there's a second cup going cold
    by her door" / "that's yours to choose" → "A Tollen goes backward") — he takes back Mara's gull if the player still
    has it and rows home from the staithe facing backward. At **Saltmarrow** he sits on his own stool by Mara's door
    with a cup (`dunstan_home`; the stool prop and its inspectable give way), his boat tied outboard of the dock's
    rowboat; Mara's one-time homecoming ("He came in backward. Course he did… Thank you."), or after the gull burn a
    big man who says he's her brother — "But the second cup's his." Or **stay** — he turns the long walk's boards
    round for whoever walks back next ("Mending's remembering." / "I've finished forgetting. Somebody may as well
    start the other thing."); the first two boards are visibly turned. Hesper has a line for each.
- **Art (folded in):** `build_characters.py dunstan_lantern` (standing, the lantern lit, head up) and `dunstan_home`
  (seated on his own driftwood stool, a cup in both hands).
- **Tests:** `test_walk_back.gd` (8). Two older tests loosened where they pinned the old state: Saltmarrow's
  conditional shapes now include the stool; Dunstan's boots-in-the-mere check skips his standing placements. The
  `stayed` placement was moved off an Unmoored figure's tussock after `test_fen_dressed` caught it. 363 tests + smoke + launch pass.
  The smoke walk takes the walk back (see Problems). Checkpoint `the_walk_back`.

Screenshots: `docs/screenshots/2026-10-19-the-walk-back.png`, `docs/screenshots/2026-10-19-home-on-the-stool.png`;
`docs/checkpoints/the_walk_back.png`.

**Decisions**
- **Pays off a thread rather than opening one.** Mystery #5 had one question left (does he walk back?). What he put
  down stays unknown for good — LORE says never tell it, and he says so himself ("Ask me again in a year").
- **Gated on the Wrack, not a timer.** There's no day/night or calendar yet; the Wrack lit is the first point where
  the player has been away from the fen long enough for "nearly" to become "done", and it can only come after he was
  found (the lane to Wrackholm needs it).
- **The player's light makes the walk possible** — the ember finally does something for the Unmoored instead of
  against them, which keeps the ember-holds-memory foreshadowing (mystery #2/#3) without explaining it.
- **Home is the default reading of "yours to choose"** (mirrors Hob's "yours to choose" → gone): a man who
  just took his name back would use it. **Stay** is the fen's answer, and it opens nothing new: he's still on the fen,
  just mending.
- **After the gull burn he still goes home**, as a stranger. The two cups have been on the crate since Day 9; this
  is what they were for. No new flag for Mara knowing him: she doesn't, and won't.
- Hesper's line names Corran seeing the light; Corran himself isn't changed (his punt state varies too much).

**Problems / notes**
- The `stayed` Dunstan uses the standing lantern model; a stooped "turning a board" pose would read better (ROADMAP).
- The checkpoint was first framed with the player standing in front of Dunstan; re-shot from the side.
- The smoke walk now sails back to the fen with the Wrack lit, so the new arrival scene broke it (Oda couldn't be
  talked to behind it). It now **takes the walk back live** — the light seen, walking him in (a `travel`), his name,
  `stayed` (so Saltmarrow stays as the later name-carrying walk expects). Home is covered by `test_walk_back.gd`.

**Next run should**
1. **Art-led session** (due ~Day 55) or **polish/debt pass** (due by Day 56) — ROADMAP *Next up* #1. Next content by
   Day 55. Fetch before trusting `origin/main`.

## 2026-10-18 21:00 UTC — Day 50: The yard's people (art-led)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again with a stale
  `origin/main`; fetched and reset local `main` to Day 49's `1d5213c`. Baseline green (351 tests).
- **Art-led (overdue: last Day 43):** ROADMAP *Next up* #1, Wrackholm's follow-up **"the yard's people"**. Canon
  (Day 43) says the yard folk come out on the shingle and stand looking at the lit Wrack — but nobody did; the yard
  had only Wenna and Jory in it.
  - **Blender** (`build_characters.py`, ~780–890 tris each): `yard_smock` (an old yard hand: tide-blue smock to the
    knee, red knitted cap, grey beard cut square, the cup he brought out from the fire), `yard_smock_mallet` (the same
    with a caulking mallet and iron), `yard_shawl` (a woman: shawl up over her head, arms folded under it, tarred
    apron), `yard_lad` (eleven or so: a gansey too big for him, a float off the come-home pile held to his chest).
  - **Wrackholm** (props with an `idle`, like the Unmoored — no names, no talk): inside until the Wrack is lit; **lit,
    the three stand at the shingle's west end looking at it** (`still`, within 15° of the Wrack, clear of the way out
    to the spit); **once the horn has answered** (`wrackholm_horn_sounded`) **the yard goes back to work** — the old
    hand caulking the sorted timber (`chisel` idle), the woman at the come-home pile, the lad on the hard watching the
    Slow Mercy.
- **Tests:** `test_yard_folk.gd` (4): the models load, rig and stay small; inside until lit; out looking (three, at
  the Wrack, on dry shingle, off the spit path); back at work after the horn. 355 tests + smoke + launch pass.
  Checkpoint `wrack_lit` re-shot (the lookers now stand in it).

Screenshots: `docs/screenshots/2026-10-18-pm-the-yard-comes-out.png`, `docs/screenshots/2026-10-18-pm-the-yard-back-at-work.png`.

**Decisions**
- **Two states, keyed to the horn, not the light alone.** People standing looking forever would read as broken on
  the next visit. The horn ("a horn answered is a lane promised") is the island's own word that the light is to be
  trusted, so it is the right moment for the yard to pick its tools back up. No new flag needed.
- **Unnamed props, not NPCs.** The yard's story is Wenna's and Jory's; giving the folk dialogue would dilute
  "Tidewrights don't shout at a lighting". They can become NPCs later if a quest needs a yard voice.
- **Three, not a crowd.** Re-using a model side by side reads as clones at this distance; three distinct figures
  give the yard a population without that.
- Lore gets a short "yard folk, seen" note (appearance and the two states) — no new story canon.

**Problems / notes**
- The caulker's mallet and iron are small at play distance; they read in close-ups. The lad stands near the jetty
  head's slope; his collider is small (0.5 m) so the jetty stays easy to reach.

**Next run should**
1. **Content (due by Day 53; last content Day 49):** ROADMAP *Next up* #1 — the lane on from Wrackholm, Dunstan's
   walk back, or the old Keepers' road north. Add a checkpoint. Next polish/debt pass due by Day 56.
   Fetch before trusting `origin/main`.

## 2026-10-18 09:00 UTC — Day 49: The fifth (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again with a stale
  `origin/main`; fetched and reset local `main` to Day 48's `72d43f4`. Baseline green (345 tests).
- **Content (due by Day 51; last content Day 47):** ROADMAP *Next up* #1, **Hob and the ladder** — the Day 27 hook
  ("the Lamp will leave the ladder stood and tell him the truth if he comes"), open since the salt-row burn shipped:
  - **New quest *The Fifth*** (`the_fifth`, flag `thornwold_hob_ladder`: '' / going / up / gone / stayed), only on the
    salt-row path (Hob still keeps the four). From Hob on the tally-house step: "You keep looking up at the ridge." The
    player knows what the Lamp said and doesn't say it — it's the Lamp's to tell. Asked up, Hob leans his rake on the
    bench and goes on ahead; **Pell** (if on Thornwold and keeping it) gives back his count-stick — "Finders keep FOR."
  - **On the ridge** (arrival event `hob_up_the_ladder`): the Lamp tells him the four went north, the ladder put down
    after Ottie — "You're the fifth, Hob." With the stick he finishes the half notch ("That's what I was counting").
    Named, the hood is back and Hob sees a face. The road being the beacon's now, the Lamp **lights a cold lantern off
    the Ridge Light** and gives him what the four came up for.
  - **The player's word**, at Hob by the ladder's head: **go after them** (or **"it's yours to choose"** — he goes: "They
    didn't wait to be told") → he walks up the old road, cuts a fifth notch, the Lamp **hangs a lantern on the second
    mark**, his rake stays on Bram's bench; or **stay** → a Keepers' **cairn with the lantern by the tally-house step**
    and **four notches on the bare SALT pegs**, "for coming down". Bram (who doesn't know him), Pell, the Lamp and the
    tally board follow either way.
- **Art (folded in):** `build_characters.py hob_lantern` (Hob standing, no rake, the lit lantern held out, head up);
  `build_thornwold.py clamp_rake` (the rake leaned on the bench). The ridge's second bare waymark gets a lit variant;
  the landing reuses `waymark_lit` for Hob's mark.
- **Tests:** `test_the_fifth.gd` (6): salt-row only / from the step / not today; going with and without Pell's stick;
  the Lamp's telling (named and not; once); go; his to choose; stay. Two older tests loosened where they pinned the
  old state (Hob's camp placement now has more terms; `waymark_lit` may stand on the landing once Hob stayed).
  351 tests + smoke + launch pass. Checkpoint `the_fifth`.

Screenshots: `docs/screenshots/2026-10-18-the-mark-at-the-bottom-of-the-road.png`; `docs/checkpoints/the_fifth.png`.

**Decisions**
- **Pays off an open thread instead of opening one:** the salt-row burn left Hob looking up the stair with nothing to
  find; the Lamp had promised to tell him. The new open question (what's up the old road north) was already open —
  the four went there on Day 25.
- **Only on the salt-row path.** On the boots path there is no fifth, as the Lamp wished; giving that path a scene would
  undo the cost of the burn. A branch-only quest is the point of the burn choice.
- **The Lamp gives the lantern, the player gives the word.** The lantern is the payoff for "I hadn't enough"; the
  choice is whether Hob follows. "It's yours to choose" is a third answer that lands on `gone` — refusing to decide for
  him is itself an answer, and he takes it the way the four did.
- **The coal stays kept for the four**; the lantern is lit off the beacon (the road is the beacon's), so Day 27 canon holds.
- The arrival event needs a one-time bool (`thornwold_hob_told_fifth`) because its state flag is many-valued (TECH).
- No smoke-walk extension: the walk burns the boots, so it can never meet the fifth.

**Problems / notes**
- The rake is thin and sits in the porch's shadow in the Compatibility renderer; it reads up close. Hob's lantern is
  small at the checkpoint's distance.

**Next run should**
1. **Art-led session** (overdue; ROADMAP *Next up* #1). Next content due by Day 53; next polish/debt pass by Day 56.
   Fetch before trusting `origin/main`.

## 2026-10-17 21:00 UTC — Day 48: Polish/debt pass six

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again with a stale
  `origin/main`; fetched and reset local `main` to Day 47's `3031883`. Baseline green (342 tests).
- **Polish/debt (due by Day 52; last Day 44):** ROADMAP *Next up* #1.
  - **No prop drowned.** The Day 42 known issue (some of the Teeth's road rocks sit under the water) became a test
    over every region: a model prop whose top (mesh bounds × `scale`, placed as `Region.place` does) is below
    `water_level` fails. It found **twelve**, not five:
    - five of the ten rocks along the reef road were snapped to the sea floor beside it (up to 0.5 m under). All nine
      ground-snapped ones now sit on the road's shoulder, 1.6–1.9 m off its line, a hand proud of the sea; the tenth,
      beside a gully where the shoulder drops away, is an awash slab like those off the white.
    - the "awash" `ridge_outcrop_low`s — three off Wrackholm, two off the stack on the Teeth — were 3–13 cm under, so
      only the swell showed them; raised to break the surface by 4–7 cm. Two more off Wrackholm's shore (snapped,
      with colliders) were 0.2–0.5 m under the sea; now awash rocks.
    - four reed clumps — three in the fen's pools, one at Shingle Point — stood on the bottom in 1.6 m of water, so not
      a stalk showed. Moved ~2 m into the shallows at the pools' edges.
  - **The smoke walk carries the Lamp's name home** (the Day 47 gap): after the fen lane, back through the bramble wall
    and up the Keepers' ladder by their own choices, the name said outright to the Lamp (*Paid Twice* done, *The East
    Stair* begun), down by the exits, Oda's lane home to Saltmarrow, Aldous asked "for Wynn's sake", the brazier seen
    raked then laid. Passed first time — the east stair now runs live end to end.
  - **The title's name follows the text size:** a `GAME_TITLE` theme variation (64 px at 1.0) instead of a fixed
    override on the label.
- **Tests:** `test_polish_six.gd` (3): no drowned prop anywhere, the road rocks on the shoulder, the title's name
  scales. 345 tests + smoke + launch pass.

Screenshot: `docs/screenshots/2026-10-17-the-teeth-road-rocks.png` (low water; the road's edges now broken by rocks).

**Decisions**
- **A test, not a validator check:** the check needs every model's bounds, and the validator runs at each debug
  start; loading ~100 .glb files there would slow every launch. The test takes ~0.6 s.
- **Move, not drop:** the rocks and reeds were placed for a reason (breaking the road's line; a reedy fen), so
  they moved to where that reason holds instead of being deleted.
- The smoke walk takes one path through the new scene ("for Wynn's sake"); the other stays unit-tested.
- No checkpoint: nothing new in the story.

**Problems / notes**
- None blocking. The Heron's landing collider and the Teeth's gullies stay on the known-issues list (judge with
  the Vulkan pass).

**Next run should**
1. **Content (due by Day 51):** ROADMAP *Next up* #1 — the lane on from Wrackholm (towards Cindermoor), Hob and the
   ladder, or Dunstan's walk back. Keep mystery #2 shut. Add a checkpoint.
2. An art-led session is overdue (last Day 43): Wrackholm's follow-ups or the Saltmarrow dressing follow-ups —
   fold one in. Next polish/debt pass due by Day 56. Fetch before trusting `origin/main`.

## 2026-10-17 09:00 UTC — Day 47: The east stair (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again with a stale
  `origin/main`; fetched and reset local `main` to Day 46's `f5fd84f`. Baseline green.
- **Content (due by Day 49; last content Day 45, systems Day 46):** ROADMAP *Next up* #1, *Aldous and the novice*:
  - **New quest *The East Stair*** (`the_east_stair`), started where the Lamp, told its name, says the door-warden of
    the east stair "saw every face go by". Oda's lane runs Thornwold → Saltmarrow already. Saves that said the name
    before today start and finish it at Aldous.
  - **On the bench** ("Wynn Sallow kept a coal."): the bottle stops halfway. Aldous had counted Wynn among the dead
    (full) or thought himself the only Keeper who ran and lived (grudging — he corks the bottle). He names **six novices**
    who held lights on the landings the last midwinter, counts on his fingers, starts again — **the seventh, on the east
    landing, has no face**. The ember knocks once (new one-shot `ember_knock`). "Thirty-one years, and I never lost a face
    off that stair. The fog's had one."
    - **"Wynn would want to know who it was."** (`saltmarrow_aldous_novice=lamp`): he sends the door-warden's sorry.
    - **"Could it have been me?"** (`self`): "I don't know. That's the worst thing I could say to you." He can't find the
      player's face anywhere, on the stair or off it; "I told you you came too soon. I'm less sure, now, that it's soon at
      all." From then on he looks at your face when you come up, and *Do you know me?* is answered honestly.
    - Either way: **the novices' roll** in the warden's niche at the foot of the east stair (a Cindermoor hook) — and he
      gets up off the bench and **lays the Wrens' brazier** for whoever comes down the stair. Not lit.
  - **The Keepers weigh the lanes' oath** for the first time (a roadmap ask): sworn → "Tidewright business… I don't
    care"; declined → "My brothers would like that in you."
  - **Wynn hears it** on the ridge (`thornwold_lamp_heard_seventh`): "Seven. I'd not have said seven." — answers the sorry
    ("a door-warden isn't the door") or weighs the player who asked if it was them ("you're not a Keeper. Or not now.").
  - The Wrens' door describes the laid fire.
- **Art (folded in):** `build_village.py` — the brazier's contents split out of `house_wren` into three exclusive props
  at the house's origin: `brazier_ash` (as before), `brazier_raked` (**Day 16 canon finally shown**: raked after a full
  confession), `brazier_laid` (three driftwood sticks crossed on raked ash over a twist of wrack).
- **Tests:** `test_east_stair.gd` (9): the Lamp starts it, `left` never does; asked for Wynn; "could it have been me?";
  the single knock; a grudging Wren; the oath weighed; old saves; the brazier's three states and the door; Wynn told.
  `test_aftermath.gd` counts the brazier among Saltmarrow's conditional props. 342 tests + smoke + launch pass.
  Checkpoint `east_stair`.

Screenshots: `docs/screenshots/2026-10-17-the-brazier-laid.png`; `docs/checkpoints/east_stair.png`.

**Decisions**
- **Mystery #2 moves a notch, not an answer.** The novice gets a count (the seventh of seven) and a place to look (the
  roll on Cindermoor), and the one man who remembers every face can't find the player's — never "it was you". LORE
  marks the seventh name on the roll as the player's, undecided whether the roll survives.
- **The quest completes at Aldous**; telling Wynn is an optional coda, not a stage — no new thread left hanging.
- **The fire is laid, not lit:** Aldous still has no ember. Lighting it is a choice for a later scene (the player's
  ember? Wynn's coal, if the lanes ever carry one?).
- Six invented novices' names are canon now (LORE); Fennick is "he" in Aldous's line.
- No smoke-walk extension: the walk never sails back to Saltmarrow; the scene is fully unit-tested (noted for pass six).

**Problems / notes**
- The tinder twist under the sticks hides inside the bowl; the raked ash's furrows barely read at the bowl's depth in
  the Compatibility renderer. Fine at play distance.

**Next run should**
1. **Polish/debt pass six** (due by Day 52) — ROADMAP *Next up* #1.
2. Next content due by Day 51: the lane on from Wrackholm, Hob and the ladder, or Dunstan's walk back. Fetch before
   trusting `origin/main`.

## 2026-10-16 21:00 UTC — Day 46: Audio hooks v1 (systems)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again with a stale
  `origin/main` (Day 38's); fetched and reset local `main` to Day 45's `b6d3a30`. Baseline green.
- **Systems (last systems session Day 41; content was Day 45, polish Day 44):** ROADMAP *Next up* #5, audio hooks.
  The game was silent; it now has a whole placeholder soundscape, with no audio files committed:
  - **`SoundSynth`** renders small JSON recipes (`data/audio.json`, 36 sounds) into 16-bit mono WAV streams: noise
    (white/pink/brown, filtered, sea swell, wind gusts), fire crackle, tones (harmonics, slide, vibrato, breath),
    scattered chirps (gulls, birds, frogs), chimes, mixes. Loops crossfade their tail into their head; renders are
    seeded by id, so a sound is the same every run. **`SoundBank`** caches them and renders off the main thread.
  - **`AudioDirector`** (child of main) plays through the Day 19 buses: **ambience layers per region** (`ambience`
    with `if`), crossfaded on arrival and live when the story changes — **the burns are audible**: gulls come back
    over Saltmarrow and Shingle Point when the Gull's Beacon burns (the headland's wind drops), birds into Thornwold,
    frogs into the fen, gulls over Wrackholm and the Teeth. **Positional `fire`** at all six lit beacons and
    `embers` at the three charcoal clamps (prop `sound` → `SoundEmitter`).
  - **Footsteps** in step with the walk (`CharacterRig.footfall`, twice a cycle): a region surface (shingle,
    grass, needles, stone, mud), `boards` on piers and anything built above the ground (the Teeth's slabs say
    `stone`), `wade` in the shallows.
  - **Voices**: every NPC has a `voice` ({sound, pitch} — five timbres: soft, reed, gruff, bright, hollow; Pell
    high and bright, the Lamp and the Unmoored hollow); a line blips once per three words; the narrator is silent.
  - **Story sounds**: a dialogue step's `sound` — the ferry's horn (arrival, and Oda's on the fen sailing), the
    answering horn on Wrackholm, and each of the four beacons catching (`kindle`).
  - **Cues**: quest started/updated/done chimes, an item gained, a tick on any button press and focus move.
  - **The Greying** (a Greying v2 piece): the Ambience bus closes to 500 Hz with depth, the ember's heartbeat comes
    up under it, and being turned back has its own fall.
  - Validator: every recipe (kind, bus, numbers, ≤ 20 s, colours, mix parts) and every sound named anywhere; layers
    and prop sounds must loop, dialogue sounds mustn't; warns on a sound never played.
  - `tools/debug/export_sounds.gd` writes every sound as .wav for listening.
- **Tests:** `test_audio.gd` (11): every kind renders deterministically and normalised, loops wrap without a click,
  the bank's threaded renders, every game sound renders (~3 s, 8 MB) and ambience loops ≥ 6 s, config refs, the
  validator's catches, the world after each burn, beacons and clamps, footsteps on the ground/dock/shallows/Teeth,
  blips, story sounds. **Smoke run**: Shingle Point's surf and wind play (no gulls yet), Pell's line blips,
  footsteps on the ramp and boards on the dock, the Greying muffles and the heart beats, the turn-back sounds,
  gulls back and fire crackling at the lit Gull's Beacon. 333 tests + smoke + launch pass.

**Decisions**
- **Procedural placeholders, not files.** Recording or licensing sound isn't possible from here, and generated
  audio keeps the repo small and the IP clean; each recipe can later be swapped for `"file"` without touching
  code. The cost is ~3 s of CPU for everything, so renders go to `WorkerThreadPool` and a region warms only what
  it uses.
- **Ambience is region-wide layers, not placed sources** (simple, data-driven, crossfades for free); placed
  sources are for things you walk up to (fires). Surf at the actual shoreline is a follow-up.
- **Voice blips, not babble:** a soft pitched blip per few words reads as "someone talking" without competing with
  the text; per-NPC pitch does the characterisation.
- **Quit goes through `AudioDirector.quit_game`:** a sound playing at the instant the process ends is reported as
  leaked objects; stopping players three frames before quitting avoids it (menus and the smoke run).
- No checkpoint or screenshots: nothing new to see. Unheard by any human ear yet — levels are guesses.

**Problems / notes**
- Levels and timbres are untested by ear (no audio device in the sandbox; checked by RMS/zero-crossing stats
  only). Added to ROADMAP as an owner listening pass.
- A bare `--quit-after` launch still prints the leak warning (benign).
- Music bus is still silent.

**Next run should**
1. **Content (due by Day 49):** ROADMAP *Next up* #1 — Aldous and the novice on the east stair, the lane on from
   Wrackholm, or Hob and the ladder. Give its big moment a dialogue `sound`. Add a checkpoint.
2. Next polish/debt pass due by Day 52. Fetch before trusting `origin/main`.

## 2026-10-16 09:00 UTC — Day 45: The Lamp's name carried home (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; fetched and reset local
  `main` to `origin/main` (Day 44's `7dd1a5f`). Baseline green.
- **Content (due by Day 47; last content Day 43):** ROADMAP *Next up* #1, *The Lamp's name carried home*:
  - **New quest *Paid Twice*** (`paid_twice`), started where Wenna reads the Lamp's page in the lane-house Book
    (WYNN SALLOW, keeper, for the Ridge Light. Paid twice.). The lanes back west already existed (Wrackholm → fen →
    Thornwold); the quest text points the way.
  - **At the bench** ("I read your name. In the Tidewrights' Book, on Wrackholm."): the Lamp knows where it put it —
    thirty winters back it wrote it in the Book for the crossing, and when the fog came it went out of its head and
    stayed on the page ("Somewhere safe"). A sworn friend of the lanes is heard in how they stand.
    - **Say it outright** (`thornwold_lamp_name=told`): the Lamp puts its hood back for the first time anyone has seen —
      a long weathered face, soot in every line, white Keeper's crop grown ragged — and finishes a sentence ("Listen:
      that one had an end."). The name brings back **the last midwinter: a novice on the east stair landing, a light
      cupped in their hands, who said "Keep one back this year, Keeper Sallow"** — a name nobody on the stair ever used.
      The ember leans. "The door-warden on the east stair might know" (a thread to Aldous). After: "I'll be Wynn, at the
      bench", greeted as Wynn, "I answer to both now".
    - **Ask first** (`left`): "A Keeper pays what's asked, and doesn't go round after for the change" — and the four,
      coming back along the ridge, should find the Lamp, "not some stranger with a name they never heard". The hood
      stays up; "The Book's keeping it."
    - Old saves that read the name before the quest existed complete it all the same.
  - **Oda weighs it** once at Thornwold landing (`lanes_oda_weighed_name`): sworn and told — "The Book doesn't mind
    being read. It minds being emptied. Don't make a habit of carrying fares back, friend of the lanes"; told
    otherwise — "She'd mind if you were sworn"; left — "Tidewright manners".
- **Art (folded in):** `build_characters.py` `lamp_named` (`build_lamp(hood_down=True)`): the hood in a roll on the
  shoulders, white crop, soot brow and cheek, the head lifted; a second Lamp placement at the bench swaps to it.
- **Tests:** `test_lamps_name.gd` (6): only once read, said outright (model, lines, quest, greeting), asked first,
  the sworn line, Oda once per outcome, old saves; `test_wrack_burning.gd` checks the Book starts *Paid Twice*.
  322 tests + smoke + launch pass. Checkpoint `lamp_named`.

Screenshots (`docs/screenshots/2026-10-16-*.png`): `the-lamp-named` (at the bench under the lit Ridge Light),
`lamp-hood-back` (lineup); `docs/checkpoints/lamp_named.png`.

**Decisions**
- **The player chooses how, the Lamp chooses whether** — but only if asked. Saying it outright always lands; asking
  hands the Lamp the right to forget (the fen's theme) and it takes it. Both are final: no blurting it later.
- **The name pays out a mystery #2 hint, not an answer:** a novice who knew a name only the Book held, telling a
  Keeper to keep a coal back the midwinter before the Snuffing. Recorded in LORE as the Wakebearer (planned), never
  said in play. The door-warden thread points to Aldous for a later scene.
- **The friend-of-the-lanes oath is weighed by a Tidewright, not the Keepers yet:** the roadmap wanted the Keepers'
  first approach to weigh it; that's still open, but the oath now has its first consequence.
- No smoke-walk extension: the walk ends at Wrackholm, and sailing two legs back and climbing the ridge would add a
  minute to every check for six lines of dialogue already unit-tested.

**Problems / notes**
- The named Lamp faces the bench (its back to the ladder), so you see the white crop before the face unless you talk
  to it (it turns to you). Fine; noted.
- Lineup lighting tints the face green; in the ridge's light it reads as weathered skin.

**Next run should**
1. Next content due by Day 49; polish/debt pass due by Day 52. ROADMAP *Next up* #1 — the lane on from Wrackholm, or
   Aldous asked about the novice on the east stair (the door-warden thread), or Hob and the ladder.
2. Fetch before trusting `origin/main` (detached HEAD every run).

## 2026-10-15 21:00 UTC — Day 44: Polish/debt pass five

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again, and this time the
  clone's `origin/main` ref was stale (Day 38's `ae72592`): `git fetch origin main` then fast-forward to Day 43's
  `e5ce474`. Baseline green (308 tests + smoke + launch). **Next run: fetch before trusting `origin/main`.**
- **Polish/debt (due by Day 46; last Day 38):** ROADMAP *Next up* #1.
  - **String flags list their values.** All 21 string flags in `flags.json` now carry `"values"` (default first,
    generated from every `set` in the content, then checked by hand). `ContentDatabase.flag_values` /
    `flag_value_error`; the validator errors on a string flag without a list, a default outside it, and any
    dialogue/pickup/event `set`, `flag:x=v` condition or scenario flag using a value the flag never takes. Every
    existing value was already consistent (the scan found no typos).
  - **`joint_witness` is exact for listed flags** (tries exactly their values instead of guessing an "other"),
    which closes the Day 38 note about the letting post pair.
  - **Prop variants on one spot are proved exclusive:** two model props of one family (first word of the file
    name) within 0.6 m must never both show; overlays of another family may stack. Some two dozen pairs in the
    game today, all clean.
  - **Wenna without her brass:** `wenna_nobrass` (Blender; the cord's knot bare, her right hand drawn in off her
    knee toward where it hung). Three exclusive placements on her coil of hawser: the brass; given (in your
    satchel); burned in the Wrack. Given back → the brass again.
  - **The Gannet's names in chalk:** `gannet_hulk_named` (three chalk lines on the black, read from outside the
    transom) once `wrackholm_board_read`, until the board is prised off (bare) and again if it goes back.
  - **The Teeth:** the ten dead-end slabs standing in the water get one surf ring each (`wading`), so they read
    as teeth in broken water instead of flat stones; wet, weed-dark gullies painted across the reef road at its
    six bends.
- **Tests:** `test_polish_five.gd` (8): every string flag lists its values; the validator catches a misspelt set,
  condition and flags.json entry; scenarios checked; joint_witness exact with lists; prop variants (two Gannets
  caught, an overlay allowed); Wenna's three placements; the Gannet's three states; the Teeth's surf and gullies.
  `test_wrack_burning.gd` now expects the named Gannet after the board was read. 316 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-15-pm-*.png`): `wenna-without-her-brass`, `the-gannets-names-in-chalk`,
`the-teeth-in-surf`.

**Decisions**
- **Values are declared, not inferred at runtime.** A list in `flags.json` is the one place a new outcome must be
  added, which turns "a condition that can never hold" from a silent bug into a validator error. True/false
  flags stay unlisted.
- **Variant = same model family.** Position alone would flag deliberate overlays (the gold streak on the lit
  Heron, Dunstan's cord on the sill); naming a variant after its base is already the kit's habit.
- **Wenna's placements key on the item and the burn**, not a new flag: holding `wennas_answer` or
  `wrackholm_beacon_burned=answer` is exactly "the brass is away".
- No new checkpoint: nothing new to reach (the existing `wrack_lit` and `the_teeth` show the changes).

**Problems / notes**
- The gullies barely read under the Teeth's Greying layer in the Compatibility renderer (verified by colour
  probe that the paint is applied); left for the Vulkan colour pass.
- Some of the Day 42 `teeth_rock`s beside the road sit below the water (ground-relative y on sea floor) and are
  invisible; logged in *Known issues*. The smoke walk still burns only Wenna's answer; the Heron's landing collider
  is still open.

**Next run should**
1. **Content (due by Day 47):** ROADMAP *Next up* #1, *The Lamp's name carried home* (or the lane on from
   Wrackholm). Add a checkpoint for it.
2. Next polish/debt pass due by Day 52.

## 2026-10-15 09:00 UTC — Day 43: The Wrack's burning (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; local `main` reset to
  `origin/main` (Day 42's `e18c5b3`). Baseline green (298 tests + smoke + launch).
- **Content (due by Day 46):** ROADMAP *Next up* #1, *Wrackholm, part three — the Wrack's burning*:
  - **What Wrackholm holds.** At `feed_the_wrack`, "The Wrack wants something somebody here holds." — **Wenna** weighs
    her answer and, given leave, blows her brass mouthpiece bare out over the Teeth until the fog keeps the note
    (`wennas_answer`); as the yard she gives leave for **the Gannet's crew board** (`wrackholm_board_leave`), prised off
    the transom at the `gannet_board` inspectable (`gannets_crew_board`, `wrackholm_board_taken`; can go back on its
    nails); **Jory** gives **Hale's white-lead pot** (`white_lead_pot`, his one day on the Teeth behind Ruan) — never if
    told the Keepers put the Spire out ("Not a thing of mine goes in a Keeper's fire"), and if he has gone up to Wenna
    the two of them give together (`feed_together`: "We'll each give, and the Wakebearer will weigh it").
  - **The burning** in the Wrack's cradle: weigh, refuse or burn each (`wrackholm_beacon_burned` answer / board /
    white); the kindling (tags bright as coins, the fog leaning back off the white, the yard folk on the shingle not
    shouting); per-burn aftermath for Wenna, Jory and Oda (an off-islander, who keeps what was burned). The quest
    completes (no longer `future`). The unburned Remnants go back to Wenna, the transom and Jory.
  - **Lit:** the dark Wrack swaps for `wrack_light_lit` (light + halo) on the Teeth and seen from the hard; every
    greying area in both regions has a thinner, lower lit twin; fog and light overrides warm both regions.
  - **The horn unlashed and sounded** ("The Wrack's lit. Answer it."): Wenna cuts the lashing; it takes two — Jory
    under the bell if he came up, else you; long and long, an answer to a light; the Slow Mercy answers from the jetty
    (`wrackholm_horn_sounded`, the horn model swaps to `answering_horn_open`).
  - **The Book** in the lane-house: the Lamp's page if it was asked for — **WYNN SALLOW, keeper, for the Ridge Light.
    Paid twice.** (`wrackholm_lamp_name_read`) — and **the last line**, the night of the Snuffing, a name the fog has had,
    written when nobody came in; the ember leans to it and you shut the Book without deciding to
    (`wrackholm_book_opened`, a mystery #2 hook).
  - **Friend of the lanes:** a palm in the iron hand-scale; swear, decline or wait (`wrackholm_sworn`).
- **Art (folded in):** `build_wrackholm.py` — `wrack_light_lit` (gold horn panes, a fire in the cradle),
  `answering_horn_open` (bung out, lashing cut and hung off the post), `gannet_hulk_bare` (the board's scar).
- **Tests:** `test_wrack_burning.gd` (10): who gives what and when, Jory and the Keepers, the two together, the board
  off and back, each burn's aftermath and the lit regions, the answer burned with Jory up, the horn (two ways), the
  Book (page or not; the last line), the oath, the kit. **Smoke walk** burns Wenna's answer live (`_burn_the_wrack`),
  sounds the horn, opens the Book, swears. 308 tests + smoke + launch pass. Checkpoint `wrack_lit`.

Screenshots (`docs/screenshots/2026-10-15-*.png`): `the-wrack-lit-over-the-teeth`, `the-horn-unlashed`,
`the-gannets-bare-transom`; `docs/checkpoints/wrack_lit.png`.

**Decisions**
- **Three Remnants, three givers**, as the roadmap planned, but the board is the *yard's* to give (Wenna's leave as
  warden) rather than Jory's: salvage law already says what nobody comes for goes out to the Wrack, and it keeps Jory's
  choice his own (the pot). "Jory won't give to a Keeper's fire" is absolute — he never relents in this act.
- **The Lamp's name is revealed now** (WYNN SALLOW): the Book was set up on Day 40 to hold it, and a name the player
  can carry back to the ridge is a cheap, strong payoff for a later session. The name stays the Book's ("a fare's a
  fare") — what the Lamp does with it is next content's question.
- **The Book's last line** plants mystery #2 without saying anything: a name written the night of the Snuffing that
  nobody saw written, and the ember's lean. LORE records the planned answer (the Wakebearer's own hand) and leaves the
  *how* open.
- **The horn's note is long and long** — an answer to a light, distinct from the boat call (long and two short), so
  Oda's reply reads as the lane answering back.

**Problems / notes**
- Wenna's model still wears the brass after she gives it; the Gannet's board model shows blank slate even after the
  chalk came back. Both logged for the polish pass.
- The smoke walk always burns Wenna's answer (first offered); the other paths are unit-tested only.

**Next run should**
1. **Polish/debt pass five** (due by Day 46) — ROADMAP *Next up* #1.
2. Content next is due by Day 47: *The Lamp's name carried home* (or the lane on from Wrackholm).

## 2026-10-14 21:00 UTC — Day 42: The Teeth (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; local `main` fast-forwarded
  to `origin/main` (Day 41's `d5da0f8`). Baseline green (291 tests + smoke + launch).
- **Content (due by Day 44; last content Day 40):** ROADMAP *Next up* #1, *Wrackholm, part two — the Teeth*:
  - **Who remembers where to put your feet: nobody.** Wenna's "About the Teeth." now remembers she never knew — you put
    your feet **on the white**, the lampwardens' white-lead marks, a hand on every rock that will bear you, renewed every
    spring (Hale Corbet's hand lately; she can't name him until the crew's names are back). The fog will have had them;
    "you've a light that gives things back." New stage `the_marks`; she sends you to wait the springs down at the spit.
  - **The tide:** `wrackholm_tide` ('' / `low`). At the spit's end (`teeth_spit`) "Wait for the ebb." passes the
    evening (the firelight in the shutters going gold, somebody looking out) and the Teeth stand up; three slabs show
    off the spit. "Hold the ember to the rock." brings the white back, rock after rock out into the fog
    (`wrackholm_teeth_marks`); the slabs swap to marked ones and **the exit "Cross the Teeth on the white" opens**.
  - **New region `wrack_teeth` (The Teeth):** the drowned end of the spit, a winding reef road west through moderate
    fog (0.6; deep fog north and south), marked slabs every few strides pointing on, dead-end teeth and old wreck ribs
    in the water, the Wrack's stack with a ramp up its flank to the door. Arrival scene `teeth_crossing` (once).
  - **The Wrack's lantern room** (`wrack_door` → `wrack_light`): framed in **timbers off boats that never came home, each
    with the yard's lead tag** (a year and a tide, then the Wrack); **a new empty bracket** (the Gannet's — Hale fitted it
    the spring before); the cold cradle won't burn what nobody holds → stage **`feed_the_wrack`**; the lashed horn's bell
    turned toward it across the water. Wenna, told: "what we owe them, what they owe us … I'll sit with that a while."
  - **Back before the flood** (`teeth_way_back`): sets the tide in and lands mid-yard. **Jory goes up:** if he was told
    it was Wenna's answer, the next landing after a crossing plays `jory_goes_up` — the Gannet's copper off, he stands
    by her at the horn and she takes his sleeve ("Copper's off." "So it is."); a second Jory placement by the horn
    (`wrackholm_jory_up`, exact negation). Jory, asked about Ruan and the Teeth: "I remember the white. I don't
    remember where it was."
- **Art (folded in):** `build_wrackholm.py` `teeth_rock` (low black reef slab, wrack-weed skirt) and `teeth_mark` (the
  same with a white-lead daub and four finger-strokes), and lead tags on each of the Wrack's eight timbers.
- **Tests:** `test_the_teeth.gd` (7): Wenna on the white (with and without the names), the spit and the tide (the exit's
  gate, the off-spit slabs bare/marked, the wait again without a second ember), the crossing / the room / the way back
  (spawn clear of fog), the layout (marks on the road in order, flush, in thin fog; the Wrack's door meets the ramp's
  top), Jory going up only on `wenna` and only once, Jory's memory gated, the kit. **Smoke walk** sails east-about a
  second time and crosses (`_cross_the_teeth`), and `_check_gates` now returns the walk to where it started (the new
  gate sorted last and the walk began on Wrackholm). 298 tests + smoke + launch pass. Checkpoint `the_teeth`.

Screenshots (`docs/screenshots/2026-10-14-pm-*.png`): `the-white-off-the-spit`, `the-teeth-at-low-water`,
`the-wracks-door`, `jory-went-up`; `docs/checkpoints/the_teeth.png`.

**Decisions**
- **The way across is the white, and nobody remembers it** — the ember gives back what the fog took from a thing (the
  board, now the marks), so the island's knowledge was always in the rocks, not in a guide. It keeps the Wakebearer the
  one who can cross without inventing a pilot, and gives the marks a hand (Hale's) that pays into the burning.
- **Tide as a story flag, not a system.** Day/night and tides are a Milestone 2 system; until then `wrackholm_tide` is
  waited down in dialogue and flooded back on the way back. A system later should drive the same values.
- **A second region behind a gated exit**, not a conditional walkway (`land` can't be conditional; a pier-like deck
  would float at high water). The exit also keeps the smoke walk's generic region pass from wandering onto the Teeth.
- **The burning waits for next content session.** This session sets `feed_the_wrack` and plants the candidates (Wenna's
  answer, the Gannet's names and bracket, Jory's Ruan) without offering them; the Wrack is the Tidewrights' payoff and
  deserves its own session.

**Problems / notes**
- The first reef road broke into steep islands (2 m wide, ragged 1.0); widened to 3 m with feature `ragged` 0.35.
- Adding a gated exit on Wrackholm made the smoke walk start its passes on Wrackholm (the gate check left it there):
  `_check_gates` now goes back home.
- The reef reads as one smooth causeway from above; foam lines in the gullies would help (logged in *Known issues*).

**Next run should**
1. **Wrackholm, part three — the Wrack's burning** (content, due by Day 46) — ROADMAP *Next up* #1.
2. The next polish/debt pass is due by Day 46 too (Day 38 was the last) — if the burning doesn't fit, do the pass first.

## 2026-10-14 09:00 UTC — Day 41: The title screen (systems)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; local `main` matched
  `origin/main` (Day 40's `da98085`). Baseline green (287 tests + smoke + launch).
- **Systems (due; last systems-led session Day 37):** ROADMAP *Next up* #1, *Title screen*:
  - **`TitleScreen`** (`scripts/ui/title_screen.gd`): a plain launch opens on it over the live start region — the
    world has been reset by `GameState.new_game()`, the waking narration waits, the HUD hides, input is held, the
    tree keeps running (the sea moves) and the camera drifts slowly round the Wakebearer. The game's name and a
    tagline (`data/game.json` `tagline`: "What is worth keeping, when you cannot keep everything?"), then
    **Continue — <region> (<slot>)** when there is a save, **New game**, **Load game** (greyed with no saves),
    **Chapter select (dev)** in debug builds, **Settings**, **Quit**. Region arrival events wait for it to close.
  - **Continue** loads `SaveSystem.latest_slot()` — the newest `saved_at` across the quicksave and the three slots
    (file time breaks a same-second tie; unreadable saves skipped). A save that won't load keeps the title up and
    says so.
  - **Return to title** on the pause menu (between Settings and Quit) and on the **Act I end card** (beside "Keep
    exploring"): both ask for a second press (unsaved progress), then `main.return_to_title()` resets the world,
    rebuilds the start region and opens the title — deferred, so the closing menu's deferred input unlock can't
    land after it and free the player behind the title.
  - **`MenuScreen`** (`scripts/ui/menu_screen.gd`): the pause menu's panel, page switching, Load, Chapter select,
    Settings and Controls pages (sliders, key capture, saving per change) moved into a base class; `PauseMenu`
    (now ~90 lines) and `TitleScreen` extend it and add only their main pages (and the pause menu's Save page).
    The scroll-box fitting now measures whatever a subclass puts in the panel.
  - **Launch rules** (`main.wants_title`): a plain launch and `--smoke-test` open on the title; any debug arg that
    asks for a state or screen (`--scenario`, `--region`, `--flags`, `--quest`, `--act-end`, `--pause-menu`,
    `--screenshot`) goes straight into play as before (checkpoints and screenshots unchanged); `--title` forces it.
- **Tests:** `test_title_screen.gd` (4): which launches open on the title; Continue = latest save (quicksave counts,
  newest stamp not slot order, unreadable skipped); the title's pages (no-save layout, the name only on the main page,
  shared Settings/Controls/Load, Esc page by page and staying put on the main page); Return to title asking twice on
  the pause menu (a page change disarms it) and the act card. `test_settings.gd` uses `MenuScreen.Page`. **The smoke
  run now starts from the title** (it's up over the start region, HUD hidden, camera drifting, no waking until New
  game) and near its end saves slot 2, returns to the title from the pause menu (twice), checks the world is back at
  the start and that Continue names slot 2, and Continues back into the saved state. 291 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-14-*.png`): `title-screen`, `act-end-return-to-title`.

**Decisions**
- **A base class rather than a `SettingsPages` control** (the roadmap's suggestion): the pages share the panel, the
  button list, the note line, the Esc ladder and the confirm-twice pattern, not just the settings rows, so one
  `MenuScreen` with per-menu main pages removed the most duplication (Load and Chapter select came along free).
- **The title sits over the real start region**, not a separate scene: no change to `run/main_scene`, the checkpoint
  and screenshot tooling, or the smoke harness, and the beach is the title art. The world behind it is already a
  fresh game, so New game just rebuilds it and plays the waking.
- **New game never asks twice**: it doesn't touch any save. Return to title does (it drops unsaved progress).
- **No pause behind the title**: input is locked instead, so the water, smoke and boats keep moving.

**Problems / notes**
- First screenshot had the title's list scrolling with Quit cut off: an autowrapped Label reports a tall minimum
  height before it has a width, and the scroll fitting read it. The one-line tagline doesn't wrap now.
- The panel hides the Wakebearer on the beach behind it; logged as a title follow-up (with the fixed-size name, no
  music, no autosave) in *Known issues*.

**Next run should**
1. **Wrackholm, part two — the Teeth** (content, due by Day 44) — ROADMAP *Next up* #1 (tides first).
2. The next polish/debt pass is due by Day 46; art is due soon too (last art-led session Day 39).

## 2026-10-13 21:00 UTC — Day 40: The lane to Wrackholm (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; local `main` reset to
  `origin/main` (Day 39's `4f44547`). Baseline green (278 tests + smoke + launch).
- **Content (due by Day 41; last content Day 37):** ROADMAP *Next up* #1, *The lane to Wrackholm*:
  - **The east lane.** At the lit fen, Oda's "Where does the lane go from here?" now sets `fen_oda_lane_asked`; with
    Dunstan found she says you're "done here, near enough" and offers **"Sail east-about to Wrackholm."** The first
    sailing honours what was carried to Dunstan (`fen_dunstan_mara`, all five values) and the rule (`fen_dunstan_rule`)
    — both flags stop being `future` — then **nobody answers her horn**, and she comes in by soundings past **the
    Teeth**. Wrackholm runs back to the fen only; later sailings are one line.
  - **New region `wrackholm` (Wrackholm Hard):** the jetty, the salvage yard on the shingle (the *Gannet* hauled up,
    an old hulk down to her ribs, timber sorted with lead tags, the come-home pile of glass floats), the lane-house on
    its rise with the answering horn lashed by its door, a spit running out into the Teeth's deep fog, and the Wrack
    Light dark on its stack out of reach; thin fog over the yard's west end. Arrival event → *A Light for Wrackholm*.
  - **Wenna Garrow** (lane-warden, swore Oda): **"A horn answered is a lane promised"** — nobody answers while the Wrack
    is dark. The Snuffing night she answered the *Gannet* as the Wrack went out; the Teeth had her (Hale and Annis Corbet,
    Ruan Pask). **The Gannet's Crew** (completable): the ember brings the chalk back on the blank crew board; Wenna says
    the names into the lashed horn ("That's what a horn's for, in the end: saying who's come in") and owns it: "It was my
    answer brought them in." Also: the Wrack at the bottom of a spring tide (stage `the_teeth` — waits on tides), the
    deed weighed (`saltmarrow_ferry_deed`) and **the friend-of-the-lanes offer**, **Keepers pay twice — the second fare is
    their name in the lane-house Book** (with the sleeve-ember; Oda's word if she saw it), and **the Lamp's lost name may
    be in the Book** (page once the Wrack is lit).
  - **Jory Pask** (salvager, Ruan's brother) strips the Gannet's copper; given his brother's name he keeps saying it, and
    once Wenna has spoken he asks who called them in: **Wenna** (the truth), **the Keepers** (only if Aldous confessed:
    the Spire was put out) or **the dark** (`wrackholm_who_answered`, for the Wrack's burning).
  - **Pell's pouch paid:** Jory gives a glass float off the come-home pile ("past its year and a tide. It's nobody's. So
    it's theirs"); Pell (stayed) sets it on top of the lost-things crate (the crate's dialogue shows it).
- **Art (folded in):** `tools/blender/build_wrackholm.py` — `lane_house` (black stone courses, pale quoins, turf roof
  roped down with weighted hawsers, firelight in the shutters, smoke), `answering_horn` (lashed: bung, crossed tarred
  line, the mouthpiece bound), `gannet_hulk` (stove in, copper half stripped, the blank crew board at `GANNET_BOARD`),
  `salvage_stack`, `float_pile`, `wrack_light` (black tower on a rock stack, ships'-timber lantern room, green copper
  roof, an iron anchor vane); characters `wenna` (seated on a hawser coil) and `jory` (pry bar, leather apron).
- **Tests:** `test_wrackholm.gd` (9): the lane's gating and sailing, the sailing's lines per Mara/rule, **Oda and the
  ferry in exactly one region for every `lanes_ferry_at`**, the layout (reach, the yard's fog, Wenna by horn and door,
  the Wrack out of reach, the board's glint on the hulk's transom, the arrival once), the kit, Wenna, the Wrack/deed/
  Book, Jory three ways, the float to Pell. `test_dressing.gd` allows the lane-house's length and the Wrack's height.
  **Smoke walk** sails to Wrackholm after finding Dunstan (`_sail_to_wrackholm`: board, Wenna, Jory, Oda back).
  287 tests + smoke + launch pass. Checkpoint `wrackholm`.

Screenshots (`docs/screenshots/2026-10-13-pm-*.png`): `lane-house-and-wenna`, `the-answering-horn-lashed`,
`the-gannet-and-her-crew-board`, `wenna-jory-oda`; `docs/checkpoints/wrackholm.png`.

**Decisions**
- **Why Wrackholm went silent is a law, not a mystery:** Tidewrights answer horns ("that's not like us") — so the
  silence is them keeping their oldest law, at a cost. It makes the island's theme *what's owed* and gives a guilt to
  weigh (Wenna's answer) without touching the Keepers' secrets; Jory's "keepers" answer only exists if Aldous told you.
- **The ember restores the crew board** (a thing the fog greyed, not a burned memory), in line with Hesper's "your
  light puts the coat back on". It never restores a burn.
- **The Wrack Light waits on tides** (stage `the_teeth`): the next Wrackholm session needs a tide value or a low-water
  region; written into ROADMAP *Next up* #2 rather than faked with a dialogue gate now.
- **The Book (Keepers' second fare)** is new canon: it gives "Keepers pay twice" a concrete meaning and a place for the
  Lamp's lost name to be found later, without naming it now.
- **Gating "done here" on `fen_dunstan_met`**, not on every fen thread, so nobody is stuck: Dunstan is always findable
  once the Heron is lit.

**Problems / notes**
- The island reads pale in the Compatibility renderer (black stone and turf wash to light grey); left for the Vulkan
  pass rather than darkening blind. Art follow-ups logged in *Known issues*.
- The spit into the Teeth is walkable into deep fog and leads nowhere yet (by design: the way across is the next part).

**Next run should**
1. **Title screen** (systems; ROADMAP *Next up* #1) — systems are due (last systems-led session: Day 37's NPC `names`).
2. Then **Wrackholm, part two — the Teeth** (content, due by Day 44); the next polish/debt pass is due by Day 46.

## 2026-10-13 09:00 UTC — Day 39: Fen art follow-ups (the white light, the landing, the ladder, Mara's cord)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Local `main` matched `origin/main`
  (Day 38's `ae72592`) this time. Baseline green (274 tests + smoke + launch).
- **Art (overdue by the cadence; last art Day 36):** ROADMAP *Next up* #1, *Fen art follow-ups*, all four parts:
  - **The fen's flat white light** (both `glasswater_fen` and `heron_mere`): fog, ambient and sky horizon a
    neutral white `#CBCCC9` (silverfog's blue read lavender over the water); the ground bleached sedge
    `#7B8A6C` (was moss-mint); **a pale mud band** at the shore `#BDB6A6` (0.22 m; was dark pine); the
    fog-coloured ground of Stillhithe and the Foot whiter `#D0CEC6`; **peat water** — shallow `#3E4239`, deep
    `#202323`, sheen `#D8D8D3`, and a peat seabed `#3A3A32` instead of abyss blue showing through the shallows.
    The mere's cold sky is the fog's white too; lit, it still opens blue (`tide`) — that's the burn's payoff.
  - **The stage meets the ladder:** the keepers' stage stopped ~0.3 m short of the rails. Both near Heron models
    now carry a two-board landing on a bearer and two stub piles (slimed at the waterline), flush with the
    stage's deck and stopping just short of the rails, and **a cleat** on the leg's outer face with a few turns
    of line and a hanging end, for the punt's painter.
  - **"Shadow acne" on the Heron's legs** turned out to be the rungs' real shadows striping the ladder leg under
    the high (-62°) sun: raising `shadow_bias`/`normal_bias` and shortening the shadow distance changed
    nothing; switching shadows off cleared it. Fixed in the model — the ladder is **lashed tight** to the leg
    (0.19 m from its axis, was 0.25), so each rung's shadow falls just behind it. Atmosphere untouched.
  - **Mara's red cord round the sill gull's neck** (`gull_cord`, 9 KB): a loop knotted twice under the beak, the
    ends hanging, drawn a size fat so a fleck of red reads through the lit horn. Its own prop built in the
    Heron's frame and placed at the Heron's position, `if` lit and `fen_dunstan_word=mara` — matching the
    climb's line — rather than a second lit Heron model (the near lit model is at its 16 draw-call budget;
    the landing reuses the model's own materials for the same reason).
- **Tests:** `test_fen_art.gd` (4): no blue in the fen's water, fog, ambient, horizon or seabed, the shore band
  paler than the ground, the sedge less saturated than moss (lit sky still `tide`); the ladder 0.19 out on all
  four Heron models with nothing where it used to stand; the landing between the stage's end (derived from the
  region's pier and the Heron's position) and the rails, flush with the deck, not under the rails, a cleat, and
  not in the distance model; the cord round the gull's neck, placed with the Heron, shown only lit + Mara's word.
  `test_fen_dressed.gd`'s "peat-dark water" no longer pins `ink` (blue-black): dark and not blue. The **smoke
  walk** expects the cord when its run left Mara's word on the post. 278 tests + smoke + launch pass.
  Checkpoints `glasswater_fen`, `heron_mere`, `heron_lit`, `dunstan_found` re-shot.

Screenshots (`docs/screenshots/2026-10-13-*.png`): `fen-white-light`, `ladder-before-striped-leg` /
`ladder-lashed-tight`, `landing-and-cleat`, `red-cord-on-the-sill-gull`.

**Decisions**
- **Hex tones over new palette names** for the fen: GAME_DESIGN allows tonal shades, region colours already take
  `#hex`, and adding palette entries would ripple into every palette check. Recorded in TECH *Rendering notes*.
- **The landing is art only**: the stage's pier rect still ends at z -3, so the player stops at the stage's end;
  the climb is dialogue. Logged in *Known issues*.
- **The cord is conditioned exactly like the climb's line** (`fen_dunstan_word=mara`), lit only; before the burn
  the things are heaped in the cradle out of sight.

**Problems / notes**
- The Compatibility renderer makes the white fen very pale from far overviews; judge it with the Vulkan colour
  pass (ROADMAP *Next up* #3).

**Next run should**
1. **The lane to Wrackholm** (content, due by Day 41) — ROADMAP *Next up* #1.
2. Then a systems item (the title screen is next in line).

## 2026-10-12 21:00 UTC — Day 38: Polish/debt pass four (placements proved exclusive; Dunstan's boots in the mere)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again, and `origin/main` was
  force-updated again (to Day 37's `78b40e9`); reset local `main` to it. Baseline green (269 tests + smoke + launch).
- **Polish/debt (due by Day 39; last Day 31)** — ROADMAP *Known issues* candidates:
  - **The validator proves an NPC's placements exclusive.** Until now it only required every placement of a
    many-placed NPC to have an `if` ("keep them exact negations" was a note). New `Conditions.joint_witness`
    searches the combinations of the values a set of conditions mention (flags at their default, each named
    value, true/false and one unnamed value; quests inactive/done/active at each named stage or another; item
    counts) for a state where all hold; the validator runs it on every pair of an NPC's placements and reports the
    witness. **It found one:** Pell could stand on Shingle Point and on Thornwold at once if
    `thornwold_pell_landed` were ever set without `saltmarrow_ferry_arrived` — the beach placement now negates both.
  - **Dunstan's boots in the mere.** He sat on the spine of the long walk's end hummock with his boots on the
    mud. Now off its west side, still facing the lit Heron and in talking reach of the last board: the tussock in
    the shallows (`position` y 0.15 — the data offset over the ground — so it stands ~0.15 deep, not 0.55),
    his boots over open water. The halo on the last board moved with his lantern. Checkpoint `dunstan_found` re-shot.
  - **Walking past Hesper** (never asked to cup the ember): every `fen_ember` line in Corran's, Dunstan's, Hesper's
    and the glimpse's dialogue has a sensible reading when it's unset (Dunstan's "bare light" is `!cupped` — true);
    tested on Corran's first talk.
  - **The lantern for after** is seen from Corran's landing (where the punt brings you back), Stillhithe and the walk;
    the note that said "from the staithe" is corrected (the reed houses hide it there; the arrival text holds).
- **Tests:** `test_polish_four.gd` (5): the witness search (negations, two values, a value and its exclusion, a value
  nobody named, done quests have no stage, item counts), every placed NPC exclusive (and Pell's beach negation), the
  validator catching a double Dunstan, the boots in the mere (seat in the shallows, ground under the boots lower,
  by the walk's end, facing the Heron), walking past Hesper. 274 tests + smoke + launch pass.

Screenshot: `docs/screenshots/2026-10-12-pm-dunstan-boots-in-the-mere.png`; `docs/checkpoints/dunstan_found.png`.

**Decisions**
- **A brute-force witness, not a solver**: conditions are a handful of AND-ed terms, so a pair's search is a few
  hundred states. It over-approximates (tries values the story never sets), which is the safe side for a
  validator: the fix is always to write exact negations.
- **Not extended to prop variants yet**: a scan of same-spot conditional props found only the letting post pair,
  overlapping only for `fen_dunstan_word=true` (never set). An exact check wants declared flag `values` — logged.
- **Smoke walk left on Mara's 'well' path** and its Thornwold-Oda helper as is: both are covered (unit tests,
  `_sail_the_fen_lane`), and more passes would cost smoke time for nothing new.
- **The Heron's stage/leg overlap** folded into *Fen art follow-ups* (it's a model fix).

**Problems / notes**
- Day 31 was already "polish pass three"; this is four (`test_polish_four.gd`).
- The art cadence (every other session) slipped: Day 37 content, Day 38 polish, last art Day 36.

**Next run should**
1. **Fen art follow-ups** (art, overdue by the cadence) — ROADMAP *Next up* #1.
2. Then **the lane to Wrackholm** (content, due by Day 41).

## 2026-10-12 09:00 UTC — Day 37: After the Heron — Dunstan found (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; `origin/main` had been
  force-updated to Day 36's `523cadf` (local `main` still pointed elsewhere) — worked from `origin/main`. Baseline green.
- **Content (due by Day 39; last content Day 35):** ROADMAP *Next up* #1, *After the Heron*:
  - **The lantern for after:** a fen arrival event once the Heron is lit (any way in — in practice poled back by the
    light): the lantern lit at the fog's foot sits at the end of the long walk; Corran: "Nobody walks that far out with
    a light." Starts **For After** (one stage).
  - **Dunstan Tollen found** (new NPC + `story/dunstan.json`): on a tussock at the end of the long walk, boots toward the
    mere, whittling, the lantern lit beside him, facing the lit Heron (`faces_player: false`). His first talk honours
    the ember (cupped/bare), the glimpse (called/watched/nameless), the letting-post word (mara: the red cord at his
    belt; own: "I cut it off the hook. Then I went back for it"; none: "the best of it"), the burn (Hesper kept his name
    and lost her own / Corran's seventy years). Then Mara: her word in person (or "it was me tied it on") → he laughs
    and whittles **a gull for the stool, facing the door** ("not a promise"); after the gull burn the player can tell him
    she says Tollens end with her and sets out two cups ("…backward. Tollens always did go backward") or spare him.
    The hub: the lantern ("for after" — to walk back by when he's done; then his name from Hesper), the rule (asked:
    "I don't know. That's how you know it went" / kept), the Heron's climber (his gull on the rim; **he didn't carry the
    put-down things up — more each time, "I don't know whose"**; the keeper's coat untouched).
  - **Mara** takes the gull and sets it on the stool, beak to the door ("If he comes."); the stool shows it (beside the
    older gull facing north, if that came home).
  - **Oda** at the lit fen: "Three lit."; the trip out (bell hung/kept, big man called/watched/nameless); "I found
    Dunstan." / "…the big man from the rowboat." (gull burn) → "Is he laughing?"; **the lane on: east-about to
    Wrackholm**, the Tidewrights' yards and lane-house, dark, nobody answering horns — not sailed yet. Her Saltmarrow
    `route` line no longer implies Cindermoor is one lane past Thornwold.
  - **Hesper** hears he's found: keeps his name till he sends ("I couldn't keep my own, and I've still got his").
- **Engine:** NPC **`names`** (`[{if, name}]`) — conditional display names for the speaker label, the "Talk to…"
  prompt and the head label, refreshed live on flag changes (validated). Dunstan is "The big man" until he says it, and
  always after the gull burn.
- **Art (small):** `build_characters.py` `dunstan_seated` / `dunstan_seated_cord` (shared `_dunstan(seated, cord)`):
  seated on a tussock, forearms on the knees, a knife and a thumb-sized gull, the ship's lantern lit on the tussock's
  shoulder, Mara's red cord at the belt in the `_cord` variant. The lantern glows with a **halo** on the last board of
  the walk, not a real light (the light budget).
- **Tests:** `test_after_the_heron.gd` (10): the arrival scene once, placements by word (same spot, cord variant, the
  halo beside him), the big man → Dunstan (speaker names; gull burn), first talk by earlier choices, every Mara path,
  the lantern/rule/climber, Mara and the stool, Oda (three lit, Wrackholm, the trip, Dunstan, the route line), Hesper,
  the `names` validator. **Smoke walk** finds Dunstan after lighting the Heron (`_find_dunstan`: the scene, the
  prompt before/after his name, the halo, the 'well' path). 269 tests + smoke + launch pass. Checkpoint
  `dunstan_found`.

Screenshots: `docs/checkpoints/dunstan_found.png`, `docs/screenshots/2026-10-12-dunstan-at-the-end-of-the-walk.png`,
`…-lantern-from-stillhithe.png`.

**Decisions**
- **Dunstan met, not brought home.** Mystery #5 is half paid: alive, Unmoored, chose it. He doesn't know what he put
  down (the rule makes that the only honest answer) — so the "why" never needs inventing — and he isn't done, so his
  walk back for his name stays a later payoff.
- **The carrier stays open:** Dunstan sits up with the put-down things and owns the gull, but someone else keeps
  carrying them up.
- **The next island is named (Wrackholm, the Tidewrights')** so the lane on has a pull, but not sailed — that's its own
  content session (Act II's "+2 islands": this is one, the Tidewrights' home, which the faction table needs).
- **Halo, not light,** for his lantern: TECH's budget is ember/ferry/beacon only.
- **`names` over a second NPC id:** one Dunstan with conditional names keeps every flag and dialogue in one place.

**Problems / notes**
- The lantern can't be seen from the staithe itself (Stillhithe's reed houses stand in the way), though the arrival
  text says you see it "back on the fen"; it reads from Stillhithe and along the walk. Left as is.
- A one-line lambda with a trailing `and` in the smoke test broke its parse; tests and import still passed, but every
  `--scenario` screenshot hung (main.gd preloads SmokeTest). Rewritten as a loop; `run_checks.sh` would have caught it.

**Next run should**
1. **Polish/debt pass** (due by Day 39; last Day 31) — ROADMAP *Known issues* has the candidates.
2. Then **the lane to Wrackholm** (content, by Day 41). Art is due ~Day 40 (*Fen art follow-ups*).

## 2026-10-11 21:00 UTC — Day 36: The Heron lit, dressed (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; reset local `main`
  to `origin/main` (Day 35's `2424020`). Baseline green (250 tests + smoke + launch).
- **Art (due today; last art Day 34):** ROADMAP *Next up* #1, *The Heron lit, dressed*:
  - **The put-down things on the sill** (`build_fen.py` `_put_down_things`, in `heron_light_near_lit` only):
    the dialogue's list laid in a row inside the lantern room's front sill — a child's shoe on its side, a
    ribbon in loose loops, a spoon, a key, a comb, a button on its thread, letters folded small and smaller,
    and **the whittled gull at the end** — grey and cold, seen through the lit horn from the Foot. **The
    keeper's coat** folded small and square on the boards beside the plate, the stitched ember on top. Built
    from the model's own materials (merged by material: 16 draw calls max). The distance model doesn't
    carry them (invisible from the staithe).
  - **`corran_nocord`** (`build_characters.py`): Corran with a bare belt and his left hand drawn in to where
    the cord hung. Both Corran placements (landing and the Foot) are now pairs on the same spot, by
    `fen_corran_cord_away` (given and burned, or given and not yet back; a returned cord dresses him again).
  - **Live swap mid-talk:** the cord is given inside a conversation, so the placement swaps while he's
    talking. `Region.refresh_conditional` now removes before building and hands the old actor's turn to the
    player and body yaw to the new one (`NpcActor.take_over`).
  - **The gold on the mere** (`gold_streak`): a broken streak of emissive, see-through slivers, narrow at the
    legs, widest a third out, breaking up at the far end. In the fen (scale 2.8) from the Heron toward the
    staithe; at the legs out over the open water west of the stage (toward the Foot it would lie under the
    mud). New prop flag **`over_water`** draws a model after the transparent sea (the first try showed the
    slivers dark, drawn under the water); validated.
- **Tests:** `test_heron_dressed.gd` (9): the row along the sill (something in every fifth, all lying low),
  the coat, none of it in the cold or distance models, the dialogue still says so, Corran without the cord,
  his placements by flag (one shown per state, same spot and facing), burned vs returned, the hand-over, the
  streak (flat and long, lit-only, `over_water`, just over the swell, from the legs, > 60 % on open water in
  both regions), `over_water` render priority (the shared material untouched), the validator. **Smoke walk**:
  Corran is `corran_nocord` after giving the cord; the lit mere shows 4 conditional props (+ the gold).
  259 tests + smoke + launch pass. Checkpoint `heron_lit` regenerated.

Screenshots (`docs/screenshots/2026-10-11-pm-*.png`): `heron-sill` (the row and the coat through the horn),
`gold-on-the-mere` (from the Foot), `gold-from-above` (the fen overview), `corran-nocord`.

**Decisions**
- **The things inside the room, not on the platform**: the text says "along the sill"; the lit horn is
  see-through (alpha 0.3), so the row reads from the stage and the Foot without a new ledge.
- **No red cord on the sill gull**: a few millimetres behind horn at 6 m; it'd need a variant model for nothing
  visible. Logged under *Fen art follow-ups* for when there's a closer look.
- **Placement pairs rather than a model-by-condition field on NPCs**: the engine already did conditional
  multi-placement; only the mid-talk hand-over was missing.
- **Skipped "tussocks under the fen's Unmoored"**: checked — all three stand on dry ground (0.1–0.24 m above the
  water), so there's nothing to fix; removed from the follow-ups.

**Problems / notes**
- Re-exporting `corran.glb` from an unchanged script gives different bytes (same size); left the committed one.

**Next run should**
1. **After the Heron** (content, due by Day 39 — ROADMAP *Next up* #1).
2. Polish/debt is due by Day 39 too (last Day 31): if Day 37 does the content, Day 38 is the polish pass.

## 2026-10-11 09:00 UTC — Day 35: The Heron Light, part two — Glasswater's burning (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again, and this time the
  local `main` was **stale (Day 24)** — fast-forwarded it to `origin/main` (Day 34's `ad93d06`) before working.
  Baseline green (240 tests + smoke + launch).
- **Content (due by Day 37; last content Day 33):** ROADMAP *Next up* #1, *The Heron Light, part two*:
  - **The reason:** a new Hesper option once you've been out ("I've been out to the Heron."): she answers the
    bell (hung/kept), the big man (called/watched/nameless) and the ladder, then tells of **a small light that
    goes up the Heron's ladder some nights and comes down again** — stage `up_the_ladder`.
  - **The dry day:** at the ladder Corran comes along the stage, calls it dry enough, holds the foot. **Climb.**
  - **The lantern room** (`heron_ladder.json` `climb`): the cradle heaped with **cold put-down things**, a
    **whittled gull** in Dunstan's hand on its rim (name slides off after the `gull` burn; **Mara's red cord round
    its neck** if her word was left), **the keeper's coat folded** on the boards. The cradle leans to the ember and
    gives up: it won't burn what nobody holds. Stage `feed_the_heron`.
  - **Two new Remnants, both given freely:** **Hesper's name** (`hespers_name` — she says it out over the pool till
    it doesn't come back; she keeps Dunstan's: "not mine to give") and **Corran's channels** (`corrans_knot_cord`,
    asked at the legs or the landing). Burn at the cradle (weigh → confirm, the cold things set on the sill
    first): `fen_beacon_burned` = `name` / `channels`. Kindle: gold on the mere, fog leaning back (not over
    Stillhithe), the keeper's bell rings once (bow or satchel), **a lantern lit out at the fog's foot and carried
    away — "for after"**. Aftermath: Hesper nameless / Corran can't find the way out any more (poles back once by
    the light; "Pole me out again" → `no_channels`); the unburned Remnant goes back to its owner.
  - **Art:** `build_fen.py` `_heron_light(near, lit)` — `heron_light_lit` and `heron_light_near_lit` (glowing
    horn panes, coals/tongues/heart in the cradle, as the Ridge Light's). Lit models swap in on
    `quest:a_light_for_glasswater=done` in both regions (halo 14 m with bloom from the staithe; halo + a kindle
    light at the legs); fog/light overrides; the deep Greying rects duplicated at 0.45/0.5.
  - The quest completes (no longer `future`); `fen_skiff_bell`, `fen_dunstan_glimpsed`, `fen_heron_ladder_seen`
    are now read (not `future`). Checkpoint **`heron_lit`** (name burned, bell hung). LORE canon, TECH, ROADMAP.
- **Tests:** `test_heron_burning.gd` (10): Hesper's light (one-time, by bell/glimpse, not before the trip), the dry
  day and climb, the gull honouring the gull burn and Mara's word, both Remnants (asked at the legs: back to the
  mere's hub), burning the name (bell on the bow, lantern, nameless Hesper, cord returned, Corran still poles),
  burning the channels (poled back by the light, no more trips, name returned), a kept bell rings in the satchel,
  lit/cold models and fog in both regions, Stillhithe keeps its fog, the checkpoint. **Smoke walk** now lights the
  Heron live on the second fen trip (`_light_the_heron`) and checks the lit model's light and props. 250 tests +
  smoke + launch pass.

Screenshots: `docs/checkpoints/heron_lit.png` (the Foot, the Heron lit over the punt), 
`docs/screenshots/2026-10-11-heron-lit-room.png` (the fire through the horn), `…-heron-lit-from-fen.png` (from
the staithe: the lit Heron's halo over Stillhithe).

**Decisions**
- **The climber stays half-open.** The gull says Dunstan has been up; the put-down things (more than one man's)
  and the folded coat leave room for the keeper and others. Nobody explains why they carry them up.
- **"Won't burn what nobody holds"** makes the fen's choice fit its theme: the Unmoored have put everything down,
  so only the two who refused to (Hesper's one kept thing, Corran's whole fen) can pay. Both offer freely — the
  right to forget includes giving away.
- **Stillhithe keeps its fog** after the burn: the Unmoored live in it on purpose; the beacon doesn't take that.
- **Dunstan still unmet**: the lit lantern pays off "it's for after" without a meeting; finding him is next.
- **Burn in dialogue, no lantern-room region** (like the Ridge Light's cradle) — the platform isn't walkable.

**Problems / notes**
- Corran's model keeps the knot-cord after he gives it away (art follow-up, ROADMAP *Next up* #1).
- The smoke walk always takes the channels path; the name path is unit-tested.

**Next run should**
1. **Art (due Day 36)** — ROADMAP *Next up* #1: the Heron lit, dressed (the things on the sill, Corran without his
   cord, gold on the mere), or the *Fen art follow-ups*.
2. Then *After the Heron* (content, by Day 39). Polish/debt is due by Day 39 too (last Day 31) — if both fall
   due together, do the polish pass first.

## 2026-10-10 21:00 UTC — Day 34: The Heron up close (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; checked out
  `main` (at `origin/main`, Day 33's `b9d89dd`). Baseline green (234 tests + smoke + launch).
- **Art (due today; last art Day 32):** ROADMAP *Next up* #1, the Heron up close:
  - **The keeper's skiff** (`build_fen.py`, new `keeper_skiff` + `keeper_skiff_bell`): a real hull (the
    rowboat's lofted stations, narrower), pale clinker boards with one dark strake, the bone gunwale that
    reads through the fog, two thwarts, **half full of water** (a flat dark sheet lying level with the
    mere), the oar across her with its blade over the side, **her lantern on its side in the stern** (cold
    horn, iron caps and ribs, a ring), a stem-post at the bow with **the hole worn in it**, and the
    **painter run to the Heron's back-right leg**. The `_bell` variant hangs the little brass bell, green at
    the lip, from the stem-post. Placed in `heron_mere` at the mud bar's end, low in the water; the bell
    variant shows only when `fen_skiff_bell=hung` (before the choice the bell is in the trap/satchel).
  - **`heron_light_near`**: the Heron without the block skiff, for the Heron's Legs; the fen keeps the
    distance model (the pale block reads from a mile off, Day 30).
  - **The ladder's rungs scraped pale** (both models): the lowest four stay slime-green; from the fifth up
    each rung has a pale worn middle, "where boots go" — the dialogue has said so since Day 33.
  - **Sedge tussocks** (`tussock`): a peat mound with a ring of sedge, flattened and greyed on one side, its
    middle low enough to stand in; under the big man and the three Unmoored further in.
  - **Corran's knot-cord** (`build_characters.py`): a tarred cord at the front of his left hip with five pale
    knots — the cord he counts the channels back on (dialogue since Day 33).
- **Tests:** `test_heron_close.gd` (6): the near model at the mere / distance model in the fen (bounds), the
  rungs (one slime surface low, one pale surface above it, middles only, to the top), the skiff by bell
  state (conditions for undecided/kept/hung; a brass bell at the bow only in the `_bell` model), **the
  painter lands on the leg** (the builder's `PAINTER_TO` through the placement, < leg radius off the leg's
  axis), the water in her level with the mere, a tussock under every figure, the knot-cord on Corran's
  torso. `test_heron_light`/`test_dressing` follow the near model; the smoke walk counts the skiff among
  the mere's conditional props. 240 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-10-pm-*.png`): `skiff` (from the mud bar), `skiff-bell` (the bow,
the bell hung, the painter to the leg), `ladder` (the worn rungs from the stage), `tussocks` (the big man
and an Unmoored on sedge), `corran-cord`; checkpoint `heron_mere` regenerated.

**Decisions**
- **Two skiff models, not a bell prop.** The bell is a few centimetres at the bow; a separate prop would need
  placing to the centimetre against a rotated hull. Two variants by condition (the Day 32 loft pattern).
- **The painter ends inside the leg** rather than with a modelled round turn: a collar at the right height
  on a slanted leg looked like a floating disc at the first try. The test pins `PAINTER_TO` to the leg so a
  later move of the skiff or the Heron breaks loudly.
- **Knot-cord always on**, not only out in the punt: he counts it back every trip; a cord with knots in it
  is what he'd leave on.

**Problems / notes**
- Shadow acne on the Heron's legs behind the ladder (zig-zag bands) in the Compatibility renderer;
  pre-existing, logged under *Fen art follow-ups*.
- `docs/checkpoints/heron_mere.png.import` was left uncommitted on Day 33; committed now with the others.

**Next run should**
1. **The Heron Light, part two** (content, due by Day 37 — ROADMAP *Next up* #1).
2. Polish/debt is next due by Day 39 (last Day 31); art ~Day 38 (*Fen art follow-ups*).

## 2026-10-10 09:00 UTC — Day 33: The Heron Light, part one (content)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; checked out
  `main` (at `origin/main`, Day 32's `be1030a`).
- **Content (due today; last content Day 29):** ROADMAP *Next up* #1, *The Heron Light, part one*:
  - **What tips Corran:** a new hub option, "Will you take me out to the Heron now?", gets an errand — his
    **far trap** at the end of the long walk, in the Deeps' fog, set the week the Unmoored started going in
    ("I don't walk where they walk"). The trap is a pickup there once asked (`fen_corran_trap_asked`; stage
    `the_far_trap`). Brought back, it holds no eels and **the keeper's skiff bell** — her skiff is half a mile
    away and the fen's water doesn't move: "So who brought it?" He decides (bare/cupped lines), gives you
    the bell (`heron_skiff_bell`), stage `out_to_the_heron`.
  - **The punt:** "Pole me out to the Heron." — the channels, Corran's knot-cord, the Unmoored further in
    (one turns from a bare ember), the hole in the fog round the legs — a `travel` to a new region,
    **the Heron's Legs** (`heron_mere`, stage `at_the_legs`). Corran waits by the punt there with his own talk
    (why the fog stands off, the ones further in, the big man) and poles you back to a new `from_punt`
    spawn at his landing; later trips are one line.
  - **The Heron's Legs:** the Heron Light (the Day 29 model) over a mud hummock, **the Foot**, with a plank
    stage to the ladder leg and a mud bar to the skiff; four Greying walls leave the legs in a clear hole;
    three Unmoored on tussocks inside the fog; dead alders, reeds. Three things to look at:
    **the keeper's skiff** (her lantern full of oil; tied up to come back to; hang the bell back on her bow
    or keep it — `fen_skiff_bell`), **the ladder** (scraped pale by boots above the slime, lately;
    `fen_heron_ladder_seen`), and **the big man** at the fog's foot — call his name (he stops, doesn't turn,
    goes), watch him go, or, after the `gull` burn, find his name isn't there (`fen_dunstan_glimpsed`).
    If Mara's word was tied on the letting post, a red cord flicks at his belt as he goes.
  - **Art:** a new Blender character **`dunstan`** (big, a fisher's knit gone grey, oilskins, sea boots, dark
    curls and beard, an unlit ship's lantern in his left hand, head down to the water), placed as a figure
    prop with the `breathe` idle; gone once glimpsed.
  - Checkpoint **`heron_mere`**; LORE (canon above), TECH (the punt's two-way travel), ROADMAP updated.
- **Tests:** `test_heron_light.gd` (10): the errand, the trap's place in the Deeps, the bell and the decision
  (bare/cupped/never-asked), poling out and back, where Corran and his punt are, the mere's layout (clear Foot,
  reachable look-ats, the stage to the ladder, figures out of reach, the big man at the fog's foot), the
  glimpse three ways + the red cord, the skiff bell, the ladder, the checkpoint. **Smoke walk** follows
  Corran out on the second fen trip (`_walk_the_heron`), walks the Foot, comes back and has Oda sail it back.
  234 tests + smoke + launch pass.

Screenshots: `docs/checkpoints/heron_mere.png` (the Foot, Corran by the punt, the Heron dark in its hole in the
fog, the Unmoored further in), `docs/screenshots/2026-10-10-heron-glimpse.png` (from the Foot's edge: the big man
at the fog's foot, the stage to the ladder), `…-heron-skiff.png` (at the end of the mud bar by the skiff).

**Decisions**
- **An errand, not the ember, tips Corran.** The roadmap asked which; the ember answer already colours what he
  says (and he likes a bare one), but making it the gate would punish the player for honouring Hesper's
  request. The errand makes them walk where he won't, and the trap brings a new question (the bell) rather
  than just a yes.
- **Its own region, reached only by punt.** The Heron sits in the fen's Deeps, which the validator rightly
  keeps out of walking reach. A small region with no exits keeps the fen's ember budget intact and makes the
  punt the only way, as LORE says ("you poled out to it").
- **The fog stands off the legs** (a clear hole): playable without draining the ember, and a quiet mystery
  that rhymes with the Unmoored turning away. Corran guesses; nobody explains.
- **Dunstan glimpsed, not met:** he never turns. The red cord pays off the letting post's Mara choice
  without saying anything; `fen_dunstan_glimpsed` and `fen_skiff_bell` are `future` flags for part two.
- **Kept open:** what happened to the keeper (her full lantern, the neat hitch), who climbs the ladder, who
  carried the bell; the four colliers and the Lamp's coal.

**Problems / notes**
- The Heron's stage overlaps the ladder leg a touch (the model has no collider; it reads as the stage built up
  to the leg). Validator wants piers on the ground grid — the stage is a whole-metre rect.
- The heron light model is the distance model; up close the skiff is a plain box. Next art run.

**Next run should**
1. **Art (due Day 34)** — ROADMAP *Next up* #1: the Heron up close (a keeper's skiff prop with lantern and bell
   states, scraped rungs, tussocks), or the fen's white light.
2. Then *The Heron Light, part two* (content, by Day 37).

## 2026-10-09 21:00 UTC — Day 32: Aldous's bench and the gate lofts (art track)

**Did**
- Tooling: `tools/setup.sh` worked first try (Godot 4.7.2 + bpy 5.2.2). Detached HEAD again; checked out
  `main` (at `origin/main`, Day 31's `253386b`).
- **Art (due today; last art Day 30):** ROADMAP *Next up* #1, both parts:
  - **Aldous sits on his bench** (LORE has said so since Day 1; he stood for 31 days). New Blender
    character **`aldous_seated`** (`build_characters._aldous(seated)` shares everything with the standing
    model): the robe's skirt over his knees with a frayed hem, the green bottle corked on his left thigh,
    the right hand on his knee, a deeper stoop. New Blender dressing **`plank_bench`** (`build_village.py`):
    one salt-silvered plank on two piles of slate, seat top 0.44 m like `log_bench`, worn dark in the
    middle, and **an empty bottle lying under it**. Placed with Day 28's placement poses (the NPC's
    Saltmarrow placement takes `model`/`idle`; the NPC itself still stands).
  - **The `bottle` idle** (`CharacterRig`): breathing, the bottle turning in his hand, the other hand
    rubbing his knee, and once every 14 s a **swig** — the bottle comes up and in to his mouth, his head
    goes back, it goes down slower than it came up. `bottle_swig(t)` is static for tests.
  - **Saltmarrow's gate lofts:** the two by the boardwalk gate were the whole `net_loft` tinted grey. Now
    **`net_loft_broken`** (Gull's Head's ruin) until the Gull is lit, and after the burn a new
    **`net_loft_mended`**: the broken loft's frame and footprint with the village at it again — pale new
    boards in the floor and back-wall gaps, a square of sailcloth lashed over the roof hole on new battens,
    the snapped rail lifted back and splinted with rope, a new net hung square, the fallen one folded,
    two new rungs, and a stack of new boards waiting under the floor. Half-mended: work in progress.
- **Tests:** `test_aldous_bench.gd` (4): Aldous on the bench (same spot/facing, seat height, by the Wrens'
  house, the NPC still standing), the swig curve and the real model's pose (bottle hand up and in, head
  back, legs put), the gate lofts by burn state (one per spot, same footprint/collider), the mended loft no
  bigger than the broken one. `test_aftermath` counts the lofts' conditional shapes; `test_village` wants
  the broken/mended lofts instead of `net_loft` in Saltmarrow. 224 tests + smoke + launch pass.

Screenshots (`docs/screenshots/2026-10-09-pm-*.png`): `aldous-bench` vs `aldous-before` (seated on the
plank by the Wrens' steps, brazier and ember-hook behind); `lofts-broken` (before the burn) vs
`lofts-mended` (after) vs `lofts-before` (the old grey whole lofts).

**Decisions**
- **A plank bench, not the `log_bench`.** Saltmarrow is driftwood and slate; a split pine log is Thornwold.
- **A swig, not the `sit` doze.** Hob dozes because he hasn't slept; Aldous drinks (LORE: "drinks too
  much"). Every 14 s is often enough to be seen during a conversation, rare enough not to be comic.
  It plays whatever the confession state — he doesn't stop drinking because he told you.
- **Broken before the burn, half-mended after** — not a whole loft. The Gull's light pushed the fog back
  only days ago; a finished loft would say too much time has passed. The stack of boards says "going on".
- **Standing `aldous.glb` unchanged** (rebuilt byte-different only in material order; restored).

**Problems / notes**
- None blocking. The bench's ember-hook/brazier sit just behind him; from the walkway camera the bench
  is half hidden by his robe — reads as "sitting on something", which is enough.

**Next run should**
1. **The Heron Light, part one** (content, due Day 33 — ROADMAP *Next up* #1).
2. Art next due Day 34 (*Next up* #2).

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
