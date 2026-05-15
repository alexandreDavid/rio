---
description: Affiche le graphe des dépendances d'une quête (giver, knots, objectifs, rewards, références, chaîne prereqs).
---

# /quest-graph

Show the full dependency graph of a quest given its `id`. Use to onboard yourself before editing.

## Steps

1. L'utilisateur invoque avec un quest id, e.g. `/quest-graph baia_pacto`.
2. Read `resources/quests/<id>.tres` et extract :
   - `display_name`, `description`, `journal_text`
   - `giver_npc_id`
   - `ink_knot` (offer)
   - `objectives[]` (id + description + optional)
   - `money_reward`, `reputation_rewards`, `required_act`, `required_reputation`
   - `quest_type` (0 = SIDE par défaut, 1 = MAIN)
   - `prerequisite_quest_ids` (chaîne amont)
3. Find downstream chain (quêtes qui ont ce quest_id dans leurs prerequisite_quest_ids) :
   ```bash
   grep -l '<id>' /Users/.../resources/quests/*.tres
   ```
4. Find le giver script dans `scripts/npcs/<Name>.gd` et report all knots qu'il route pour cette quête (incl. variantes `_with_<flag>` si présentes).
5. Grep `scripts/quests/DialogueBridge.gd` pour chaque knot lié :
   - List speaker + first 60 chars of text.
   - List chaque `on_choose` action qui mentionne la quête (`accept_quest`, `finish_quest`) + side effects (set_flag, pay_debt, rep).
6. Check `scripts/main/MainBoot.gd` et `scripts/tests/IntegrationTest.gd` pour confirmer registration. Check `SCRIPT_COMPLETED_OBJECTIVES` si la quête a un objectif script-completed.
7. Check `scripts/core/NarrativeJournal.gd` pour journal entries liées (`<id>_*` knots dans JOURNAL_ENTRIES).
8. Check `scripts/ui/HUD.gd` pour MAIN_NEXT_HINT entry (si MAIN).
9. Check `scripts/core/AchievementSystem.gd` pour conquista liée.

## Output

```
=== Quest : baia_pacto ===
Display : Pacto da Baía
Type : SIDE (quest_type=0)
Giver : don_vincenzo (Don Vincenzo)
Offer knot : vincenzo_pacto_offer

Chain :
  Amont : baia_silence_press (must be completed first)
  Aval  : (aucune)

Objectives :
  • seal_pacto_baia (Sceller le Pacto da Baía avec Don Vincenzo)

Reward : R$ 2000, REP {2:+6, 1:-3, 4:+4}, pay_debt 3000, set_flag baia_pacto_sealed
Gating : required_act=1

Routing (DonVincenzo.gd) :
  • is_completed(baia_pacto) → vincenzo_after_pacto
  • is_active(baia_pacto) → vincenzo_pacto_seal
  • is_available(baia_pacto) → vincenzo_pacto_offer

Knots in DialogueBridge :
  • vincenzo_pacto_offer       — "*deux tasses de café, deux verres d'eau..."  → next: vincenzo_pacto_seal
  • vincenzo_pacto_seal        — "*signe un papier, te le pousse*..."          → finish_quest + pay_debt + set_flag
  • vincenzo_pacto_refused     — "*se lève, sans serrer la main*..." (choix 1 du offer)
  • vincenzo_after_pacto       — "*lève sa tasse vers toi*..."

Journal : (aucune entry — SIDE non-trame)
MAIN_NEXT_HINT : N/A
Conquista : conquista_baia_pacto manquante (ajouter si jalon mérité)

Registered :
  ✓ MainBoot.gd:NN
  ✓ IntegrationTest.gd:NN
  ✓ baia_pacto.tres exists
```

## Hard rules

- **Be visual** — ASCII tree or bullet structure.
- **Don't propose changes** unless asked.
- **Show chain context** : amont et aval, pas que la quête.
- **Si quête n'existe pas** : report clearly + grep similar names (`Did you mean : <suggestions> ?`).
- **Keep it under ~40 lines** d'output.
