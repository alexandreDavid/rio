---
description: Affiche le graphe des dépendances d'une quête (giver, knots, objectifs, rewards, références).
---

# /quest-graph

Show the full dependency graph of a quest given its `id`. Use to onboard yourself before editing.

## Steps

1. The user invokes with a quest id, e.g. `/quest-graph escort_contessa`.
2. Read `resources/quests/<id>.tres` and extract:
   - `display_name`, `description`, `journal_text`
   - `giver_npc_id`
   - `ink_knot` (offer)
   - `objectives[]` (id + description + optional)
   - `money_reward`, `reputation_rewards`, `required_act`, `required_reputation`
3. Find the giver script in `scripts/npcs/<Name>.gd` and report all knots it routes to for this quest.
4. Grep `scripts/quests/DialogueBridge.gd` for every knot starting with `<id>` (or related, e.g. `escort_contessa_*`):
   - List each knot's speaker + first 60 chars of text.
   - List each `on_choose` action that mentions the quest (`accept_quest`, `finish_quest`).
5. Check `scripts/main/MainBoot.gd` and `scripts/tests/IntegrationTest.gd` to confirm the quest is registered.
6. Check `scripts/core/NarrativeJournal.gd` for related journal entries.

## Output

```
=== Quest: escort_contessa ===
Display: Escort Contessa Bianchi
Giver: contessa (Contessa Bianchi)
Offer knot: contessa_act1_offer

Objectives:
  • escort_to_bar (Accompagner la Contessa au bar)
  • escort_back_to_palace (La ramener au palace)

Reward: R$ 200, REP {3:+3, 4:+1}
Gating: required_act=0, no rep gate

Routing (Contessa.gd):
  • is_active(escort_contessa) + obj escort_to_bar=true, _back=false → contessa_back_at_palace
  • is_active(escort_contessa) + obj escort_to_bar=false → contessa_waiting

Knots in DialogueBridge:
  • contessa_act1_offer        — "Mio carioca, j'aimerais sortir au bar..."
  • contessa_waiting           — "Tu sais où m'emmener ?"
  • contessa_back_at_palace    — "*sourit* Bonsoir, sobrinho." → finish_quest
  • contessa_farewell          — "*chambre Palace ouverte pour toi*"

Journal:
  ✓ Not tracked (consider adding to NarrativeJournal if narratively pivotal)

Registered:
  ✓ MainBoot.gd:32
  ✓ IntegrationTest.gd:30
```

## Hard rules

- **Be visual** — use ASCII tree or bullet structure.
- **Don't propose changes** unless the user asks.
- **If quest doesn't exist** : report it clearly + grep for similar names (`Did you mean : <suggestions> ?`).
- **Keep it under ~30 lines** of output.
