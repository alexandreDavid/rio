---
description: Lance run_tests.sh, parse la sortie, retourne un résumé pass/fail concis.
---

# /run-tests

Run `./run_tests.sh` from the project root and report the result concisely.

## Steps

1. Execute `./run_tests.sh` via Bash. Capture stdout+stderr.
2. Parse the output :
   - Look for the `===== END SELF-CHECK =====` line.
   - Look for the final summary `<N> passés · <M> échecs`.
   - Si `M > 0`, also extract the names of failing tests (typically lines starting with `[FAIL]`, `ÉCHECS`, ou `✗`).
3. Reply in **2-4 lines max** :
   - Une ligne avec `<N>/<N> passants` ou `<N> passants, <M> échecs`.
   - Si échecs : list each failing test on its own line with l'assertion qui a cassé.
   - Si tout passe : just confirm + total count, rien d'autre.

## Examples

Pass :
```
2300/2300 passants. RAS.
```

Fail :
```
2298/2300 passants, 2 échecs :
  • [test_quest_milho_01_chain] expected money=520, got 480
  • [test_npc_routing_padre] knot 'padre_invitation' missing
```

## Hard rules

- **Pas de verbose output** — l'utilisateur le run souvent, terseness wins.
- **Don't suggest fixes** unless asked — just report.
- **Cache miss is fine** — même si tu viens de run, rejoue à chaque invocation.
- Le compteur actuel tourne autour de **2300+** assertions selon l'état du projet ; pas la peine de mémoriser un chiffre exact.
