# Emberwake — Dev Log

Newest entries first. Each entry: what was done, decisions & why, problems, next steps.

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
