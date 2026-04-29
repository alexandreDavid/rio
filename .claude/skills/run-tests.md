---
description: Lance run_tests.sh, parse la sortie, retourne un résumé pass/fail concis.
---

# /run-tests

Run `./run_tests.sh` from the project root and report the result concisely.

## Steps

1. Execute `./run_tests.sh` via Bash. Capture stdout+stderr.
2. Parse the output:
   - Look for the `===== END SELF-CHECK =====` line.
   - Look for the final summary `<N> passés · <M> échecs`.
   - If `M > 0`, also extract the names of failing tests (typically lines starting with `[FAIL]` or `✗`).
3. Reply in **2-4 lines max**:
   - One line with `<N>/<N> passants` or `<N> passants, <M> échecs`.
   - If failures: list each failing test on its own line with the assertion that broke.
   - If everything passes: just confirm + total count, nothing else.

## Examples

Pass:
```
712/712 passants. RAS.
```

Fail:
```
710/712 passants, 2 échecs :
  • [test_quest_milho_01_chain] expected money=520, got 480
  • [test_npc_routing_padre] knot 'padre_invitation' missing
```

## Hard rules

- **No verbose output** — the user runs this often, terseness wins.
- **Don't suggest fixes** unless asked — just report.
- **Cache miss is fine** — even if you've run tests recently, always re-run when the user invokes /run-tests.
