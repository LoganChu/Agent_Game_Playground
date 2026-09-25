# Emberwake — World & Story Bible (CANON)

> This file is canon. Content (dialogue, items, regions) must not contradict it. When new canon
> is added in content, record it here in the same commit. Sections marked **[SECRET]** are
> truths the player does not yet know; they are payoffs for later chapters — do not reveal
> them early in dialogue, but you may foreshadow.

## The world: the Lanternreach
An archipelago of cold, green islands in a grey northern sea, bound by ferries, causeways and
old custom. For nine hundred years the **Hearthspire** — a lighthouse-tower on the central
isle of **Cindermoor** — burned with the **Firstflame**. Its light did more than guide ships: it
held back the **Greying**, a silver sea-fog that makes things *forgotten*.

### The Greying
- Where the fog lies, memory thins. People forget names, then faces, then why they are standing
  where they are. Objects left in it lose their "meaning" (a key forgets its lock; a road
  forgets where it goes — paths literally fade).
- It is not hostile, not a monster, and does not kill directly. Its victims are called
  **the Hushed**: gentle, unfocused people who drift and hum.
- Light pushes it back. Ordinary fire barely helps; only **embers of the Firstflame** truly do.
- Three months before the game begins, on the night called **the Snuffing**, the Hearthspire
  went dark. Nobody knows why. The fog has been creeping inland ever since.

### Beacons and Remnants
- Each island has an old **Beacon** — a small stone lantern-tower once lit from the Hearthspire
  each midwinter. Relighting a beacon clears the Greying from that island.
- A beacon cannot be lit with ember alone: it must be *fed a memory*. **Remnants** are memories
  that have condensed into physical objects in the fog (a warm pebble that hums a lullaby, a
  rope that remembers a knot). Whichever Remnant feeds the beacon is *burned*: the island
  remembers everything else, but that one memory is gone for good. This is the core moral
  mechanic.

### Wakebearers
Folk legend: when the flame fails, it "wakes" someone — puts an ember in a living hand.
Wakebearers are said to be able to walk the fog without forgetting, as long as their ember
burns. The last recorded Wakebearer was **Isolde Vane**, 300 years ago.

## Factions
| Faction | Who | Want | Attitude to player |
|---|---|---|---|
| **The Keepers of the Spire** | Robed order that tended the Hearthspire. Now scattered, ashamed, secretive. | Relight the Hearthspire the "proper" way — by their rites. | Want to control the Wakebearer. |
| **The Tidewrights** | Guild of ferrymen, net-makers and salvagers. Practical, clannish. | Keep the sea lanes and trade alive. | Transactional; respect deeds. |
| **The Unmoored** | People who have *chosen* to walk into the fog to forget grief or guilt. | To be left alone; some want the fog to spread. | Wary; the player's ember hurts them. |
| **The Hollow Choir** *(rumor)* | Said to be singers in the deep fog. | Unknown. | Unknown. |

## Starting regions
### 1. Saltmarrow (starting island — *Vertical Slice*)
A fishing village on stilts around a tidal harbor, half-swallowed by fog at the northern end.
Smell of tar and smoked fish. Its beacon, **the Gull's Beacon**, sits on a headland past the
greyed net-lofts.
- **Mara Tollen** — harbormaster, fifties, blunt, practical, the one keeping the village fed.
  Her brother **Dunstan** walked into the fog two weeks ago. Signature color: Coal red.
- **Pell** — orphaned net-mender kid (~12), fast-talking, knows every plank. Collects "lost
  things" the fog spits out. Signature color: Kindle.
- **Brother Aldous Wren** — a Keeper who fled the Hearthspire the night of the Snuffing. Kind,
  evasive, drinks too much. Knows more than he says. Signature color: Silverfog/Ember.
- The player wakes on **Shingle Point**, the beach south of the village.
- **Established in play (Day 1):**
  - The **humming pebble** — a Remnant found on Shingle Point — hums the old Saltmarrow
    lullaby Mara used to sing; nobody can remember its ending anymore. The player either
    gives it to Pell or keeps it (flag `saltmarrow_pebble_fate`).
  - Mara gives the player her **Harbormaster's Token** (brass, stamped with a gull), which
    lets them past the men guarding the greyed net-lofts on the way to the headland.
  - Aldous sits on a bench on the west side near "the Wrens' old house" (his family's).
    He wears a faded ember stitched on his sleeve (the Keepers' mark) and reacted to the
    player with "Not yet. It's too soon" — foreshadowing mystery #2.
  - Aldous has told the player how beacons work (fed a Remnant; that memory is lost for
    good) and, if treated gently, that the Hearthspire "did not go out by accident."
  - Folk already use the word **Wakebearer** for someone carrying a living ember.

- **Established in play (Day 3):**
  - A driftwood **boardwalk** runs north from the village to the greyed **net-lofts** and on
    to the headland, together called **Gull's Head**. **Tam Hollis**, a young Tidewright
    net-hand (Hesk's apprentice once), guards the boardwalk gate on Mara's orders and lets
    only the Token's bearer pass.
  - **Old Hesk**, Saltmarrow's oldest netmender, refused to leave the lofts and is Hushed:
    she mends the same net forever, humming "over, under, round the gull".
  - Hesk saw **Dunstan** go north with a lantern, *laughing*, saying he'd "come back for his
    name when he was done with it" (flag `saltmarrow_hesk_saw_dunstan`). If told, Mara now
    knows he went willingly (`saltmarrow_mara_knows_dunstan_chose`) — foreshadows mystery #5.
  - The **Remembering Knot** — a Remnant found in the lofts: tarred cord that ties itself
    into Saltmarrow's **founding knot**, with which the first village net was tied. No living
    hand remembers it. Burning it would take the village's founding craft (the "founding"
    option of the Act I burn choice).
  - The **Gull's Beacon** is a stub of grey stone with an iron gull on its roof; inside the
    lantern room is an **iron cradle** where the fed Remnant burns, holding pale ash of old
    midwinters. Ember alone does nothing; the cradle "leans toward" the ember, waiting.

- **Established in play (Day 4 — the Burning):**
  - The Gull's Beacon is relit by the player feeding its cradle one Remnant
    (flag `saltmarrow_beacon_burned`). The three Act I options:
    - **`pebble`** — the lullaby. Nobody on Saltmarrow can hum it again, not even wrongly;
      Mara forgets she ever sang. If Pell had it, Pell had to agree to give it up (and
      afterwards only knows a pocket feels empty).
    - **`knot`** — the founding knot. Nets still get made, but nobody knows where a net
      *begins*; Hesk stops humming "over, under, round the gull" and forgets what she mends.
    - **`gull`** — Mara's memory of Dunstan. Mara held **Dunstan's whittled gull** (he carved
      it for her when she was six) in the fog at the boardwalk gate until it became a
      Remnant. Afterwards she believes "Tollens end with me", yet keeps setting out two cups.
  - **New rule:** a Remnant need not be found. A loved object held in the Greying long enough
    takes the holder's memory into itself — *a Remnant made on purpose*. Aldous admits "We
    Keepers knew that trick. We knew it far too well" (foreshadows mystery #1; do not make it
    explicit yet).
  - Relighting the beacon does not banish the fog; it *leans back* off the headland, the
    boardwalk and past the harbor wall (all three Saltmarrow regions thin). The burned memory
    is gone for everyone, including the Wakebearer (who hears the lullaby's ending once, as it
    burns, and then cannot recall it).
  - Unburned Remnants that were lent (the pebble, the gull) can be handed back afterwards.
  - Aldous felt the beacon catch "like a hand on the back of my neck" and promises the rest
    of his story; he has not told it yet.

### 2. Thornwold (planned — Alpha)
A forest island of pines and bramble-walls whose paths the fog keeps rearranging. Home of
charcoal-burners and a Tidewright lumber camp. Theme: trust and misdirection.

### 3. Glasswater Fen (planned — Alpha)
A marsh of reed-houses and mirror-still pools where the Unmoored gather. Theme: the right to
forget. The fog is thickest and strangest here.

### Later: Cindermoor & the Hearthspire (Beta/Early Access finale)

## Main story arc (outline)
- **Act I — The Wake (Saltmarrow):** player wakes, learns the rules of the Greying, helps
  Saltmarrow, relights the Gull's Beacon, and must choose which memory to burn (e.g. Mara's
  memory of Dunstan vs. the village's founding song vs. Pell's memory of their parents).
  Brother Aldous reveals the Hearthspire was not extinguished by accident.
- **Act II — The Drift (Thornwold, Glasswater Fen, +2 islands):** each island's beacon demands
  a burn. The Keepers, Tidewrights and Unmoored court the player. Clues point to someone inside
  the Spire. The player's own memories start surfacing as Remnants.
- **Act III — The Spire (Cindermoor):** confront what put out the Firstflame and decide what
  the Lanternreach should remember — or whether it should forget.

## Long-term mysteries (payoff over months)
1. **Who snuffed the Hearthspire, and why?** *[SECRET]* The High Keeper, **Oriel Sayre**, did —
   deliberately — because the Firstflame is fueled by *stolen* memories: nine centuries of the
   Keepers quietly feeding it the memories of the Hushed. Oriel could not continue it.
2. **Who is the player?** *[SECRET]* The player is not a stranger. They were a Keeper novice who
   helped Oriel at the Snuffing and fed their own memories to the last ember to carry it out of
   the Spire. The ember in their hand holds their past.
3. **What is the Greying?** *[SECRET]* The fog is the world's forgotten memories returning —
   everything the Firstflame burned for 900 years, drifting home. The Hushed are overwhelmed by
   other people's memories, not emptied.
4. **What happened to Isolde Vane?** *[SECRET]* She was the first to discover the truth and was
   "burned" by the Keepers; the Hollow Choir sings her memory.
5. **Where did Dunstan Tollen go?** He is alive in the fog, among the Unmoored, and chose to go.

## Story flags (canon registry)
All world-state flags are declared in `data/flags.json` with a description. Content may only
set/read declared flags (enforced by tests). Flag names use `region_topic_detail` snake_case.

## Timeline
- ~900 years ago: Hearthspire first lit (the "Kindling").
- ~300 years ago: Isolde Vane, last Wakebearer, disappears.
- 3 months ago: **The Snuffing.**
- 2 weeks ago: Dunstan Tollen walks into the fog from Saltmarrow.
- Day 0: the player wakes on Shingle Point.
