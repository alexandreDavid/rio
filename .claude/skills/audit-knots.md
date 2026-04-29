---
description: Audit rapide des knots de dialogue — broken refs et orphans en moins de 30s.
---

# /audit-knots

Quick consistency check on dialogue knots across the project. For deep audits with quest cross-refs, use the `dialogue-validator` agent instead.

## Steps

1. Build the **defined set** :
```bash
grep -E '^\s+"[a-z_0-9]+":\s*\{' /Users/alexandredavid/dev/game/rio/scripts/quests/DialogueBridge.gd | \
  sed -E 's/.*"([a-z_0-9]+)".*/\1/' | sort -u
```

2. Build the **referenced set** from NPC scripts :
```bash
grep -hE '"[a-z_0-9]+_intro"|"[a-z_0-9]+_remind"|"[a-z_0-9]+_offer"|"[a-z_0-9]+_done"|"[a-z_0-9]+_thanks"|"[a-z_0-9]+_farewell"|"[a-z_0-9]+_active"|knot\s*=\s*"[a-z_0-9]+"' \
  /Users/alexandredavid/dev/game/rio/scripts/npcs/*.gd | \
  grep -oE '"[a-z_0-9]+"' | sort -u
```

3. Also check NPCData `ink_knot` defaults :
```bash
grep -h "^ink_knot = " /Users/alexandredavid/dev/game/rio/resources/npcs/*.tres | \
  sed -E 's/^ink_knot = "([^"]+)"/\1/' | sort -u
```

4. Diff sets:
   - **Broken refs** : referenced minus defined → these are crashes waiting to happen.
   - **Orphans** : defined minus referenced → dead code (low priority).

5. Report in this format:

```
=== Audit knots ===
🚨 BROKEN (N) :
  • <knot> — referenced in <file:line>
  
💤 ORPHANS (M) :
  • <knot> in DialogueBridge.gd:<line>

✓ <DEFINED>/<REFERENCED> knots aligned.
```

## Hard rules

- **Be fast** : ~10 seconds. If you start grepping for context on each knot, switch to the `dialogue-validator` agent.
- **Skip `next` chains and `accept_quest` cross-refs** — those are the validator's job.
- **Suggest fixes inline** for broken refs (typo distance match : `padeiro_intro` vs `padaria_intro`).
