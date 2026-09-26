# Emberwake — Game Design Document

> Living document. Changes to vision or pillars must be justified in `docs/DEVLOG.md`.

## Elevator pitch
The great lighthouse-flame that kept the **Greying** at bay has gone out. A slow, silver fog
now drifts in from the sea, and whatever it touches *forgets* — names, roads, songs, grudges,
whole villages. You wake on a shingle beach with a live ember sealed in the palm of your hand
and no memory of how it got there. You are a **Wakebearer**: the only person who can carry
light into the fog and bring back what was lost.

*Emberwake* is a stylized low-poly 3D narrative exploration RPG about remembering: walk a
fading archipelago, listen to the people still holding on, and decide what is worth keeping
when you cannot keep everything.

## Design pillars
1. **Every choice leaves an ember.** Decisions are recorded as world-state flags and come back
   later — sometimes chapters later. Characters remember what you did (even if the world
   forgets). No choice is purely cosmetic; few are purely good.
2. **A world worth remembering.** Hand-written characters, specific places, layered lore.
   Every region has a secret, every major NPC has a want, a fear and a contradiction.
3. **Gentle wandering.** Exploration and conversation are the core verbs. No twitch combat;
   tension comes from the fog, scarcity of light, and moral weight — never from reflexes.
   Playable by people who do not usually play games.
4. **Readable, warm low-poly.** Flat-shaded shapes, a small palette, strong silhouettes and
   light as the storytelling tool. The ember is always the warmest thing on screen.

## Core loop
```
explore a region ──► meet characters ──► learn what the fog took / what they want
      ▲                                              │
      │                                              ▼
world changes (flags, relit beacons, ◄── make choices (dialogue, who to help,
new paths, NPC fates, fog recedes)       what to rekindle with limited light)
```
- **Macro loop (region):** arrive in a greyed region → find its *Beacon* → gather the
  *Remnants* (memory fragments) and people's help needed to relight it → choose how to relight
  it (whose memory fuels the flame) → region is restored in a way shaped by that choice.
- **Micro loop (minute-to-minute):** walk, look, talk, pick up, remember.

## Key systems (planned)
| System | Purpose | Status |
|---|---|---|
| Data-driven content (regions, NPCs, items, quests) | Add content without code | Day 1 |
| Branching dialogue (JSON, see TECH.md) | Conversations, choices, flags | Day 1 |
| World-state flags | Choices persist & gate content | Day 1 |
| Save / load | JSON saves in `user://` | Day 1 (stub) |
| Quest journal | Track active/done quests | Roadmap |
| Inventory & Remnants | Items, memory fragments | Roadmap |
| Ember light meter | Your light is a resource in the fog | Roadmap |
| Fog (Greying) volume | Visual + gameplay: forgotten areas | Roadmap |
| Day/night & tides | Mood, NPC schedules | Roadmap |
| Accessibility | Remappable input, text size, colorblind-safe palette, no timing gates | Ongoing |

## Tone
Melancholic but warm. Quiet coastal folk-tale, not grimdark. Humor lives in people, not in
winks at the player. Dialogue is short, specific and concrete: people talk about nets,
bread, debts and siblings — not about "the darkness". Grief is allowed; despair is not the
point. Reference feelings (not IP): tidal villages, lantern festivals, half-remembered songs.

## Art direction
- **Style:** low-poly, flat shading (no textures beyond a palette atlas), chunky silhouettes,
  slight exaggeration of scale for landmarks (beacons, cliffs, trees).
- **Lighting:** one warm key light (ember/sun), cool fog-tinted ambient. The Greying desaturates
  and flattens; relit areas regain saturation.
- **Characters:** stylized proportions (large heads/hands), readable at distance by silhouette
  and one signature color each.
  Costumes may use tonal shades (lighter/darker) of palette colors, never new hues.
- **Palette** ("Ember & Tide"):

| Role | Name | Hex |
|---|---|---|
| Ember / accent | Ember | `#F2A541` |
| Warm highlight | Kindle | `#F4D58D` |
| Danger / hearth | Coal red | `#B5452F` |
| Foliage | Moss | `#5E8C61` |
| Deep foliage | Pine | `#2F5D50` |
| Sea / water | Tide | `#3D7EA6` |
| Deep water | Abyss | `#1F3A5F` |
| Stone | Slate | `#6B7280` |
| Sand / wood | Driftwood | `#C9B28F` |
| The Greying (fog) | Silverfog | `#C7CCD4` |
| Night / UI dark | Ink | `#1B1B2F` |
| UI light | Bone | `#EDE6D6` |

## Target platforms
Windows, macOS and Linux via Steam first (Steam Deck verified as a stretch goal). Controller
and keyboard/mouse. Target 60 fps on integrated GPUs (low-poly + Forward+ / Mobile renderer
fallback). Consoles later, if ever.

## Scope guardrails
- No combat system in the vertical slice. If conflict mechanics arrive later they must serve
  pillar 3 (non-reflex).
- Each region should be completable in 45–90 minutes.
- Voice acting: none planned; text with character "voice blips" (audio hooks) instead.
