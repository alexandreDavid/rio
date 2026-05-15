---
description: Audit rapide des knots de dialogue — broken refs et orphans en moins de 30s.
---

# /audit-knots

Quick consistency check des knots de dialogue. Pour des audits profonds avec cross-refs quêtes, utiliser l'agent `dialogue-validator`.

## Steps

1. Build le **defined set** :
```bash
grep -E '^\s+"[a-z_0-9]+":\s*\{' /Users/alexandredavid/dev/game/rio/scripts/quests/DialogueBridge.gd | \
  sed -E 's/.*"([a-z_0-9]+)".*/\1/' | sort -u
```

2. Build le **referenced set** depuis NPC scripts :
```bash
grep -hE '"[a-z_0-9]+_(intro|remind|offer|done|thanks|farewell|active|default|chat_warm|chat_familiar)"|knot\s*=\s*"[a-z_0-9]+"|return\s+"[a-z_0-9]+"' \
  /Users/alexandredavid/dev/game/rio/scripts/npcs/*.gd | \
  grep -oE '"[a-z_0-9]+"' | sort -u
```

3. Check NPCData `ink_knot` defaults :
```bash
grep -h "^ink_knot = " /Users/alexandredavid/dev/game/rio/resources/npcs/*.tres | \
  sed -E 's/^ink_knot = "([^"]+)"/\1/' | sort -u
```

4. Diff sets :
   - **Broken refs** : referenced minus defined → crashes waiting to happen.
   - **Orphans** : defined minus referenced → dead code (low priority).

5. **Filtrer les orphans intentionnels** avant report :
   - `conquista_*` (entrées Crônica de l'AchievementSystem, marquées read par `mark_read`)
   - `*_chat_warm`, `*_chat_familiar`, `*_chat_morning`, `*_chat_afternoon`, `*_chat_evening` (NPCAffinity helper)
   - `*_with_<flag>` (variantes routées par `CampaignManager.has_flag`)

6. Report dans ce format :

```
=== Audit knots ===
🚨 BROKEN (N) :
  • <knot> — referenced in <file:line>

💤 ORPHANS (M, filtrés des conquista_/chat_/with_) :
  • <knot> in DialogueBridge.gd:<line>

✓ <DEFINED>/<REFERENCED> knots aligned.
```

## Hard rules

- **Be fast** : ~10 secondes. Si tu commences à grep pour du contexte sur chaque knot, switch sur l'agent `dialogue-validator`.
- **Skip `next` chains et `accept_quest` cross-refs** — c'est le job du validator.
- **Suggest fixes inline** pour broken refs (typo distance : `padeiro_intro` vs `padaria_intro`).
- **Ne pas flagger** : `conquista_*`, `*_chat_*`, `*_with_*` — intentionnellement non-référencés directement.
