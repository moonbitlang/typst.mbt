1. **Keyed label values — RESOLVED.** Nested `Keyed` wrappers preserve their key context during evaluation, and resulting labels attach within the enclosing sequence using the evaluator’s attachment and warning rules. See [doc/lower.mbt:226](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:226) and [doc/lower.mbt:155](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:155).

2. **Call-produced long strings — RESOLVED.** Displayed results and `VCall` results, including arguments, now mark their origins when strings exceed 65,535 UTF-8 bytes. See [doc/lower.mbt:189](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:189), [doc/lower.mbt:244](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:244), and [doc/lower.mbt:447](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:447).

**New findings:** None verified in commit `5bd0184` or its effects.

Prebuilt debug binaries passed **15 differential twins, 23 `doc` tests, and 2 example tests**, including both updated regression cases. No files were modified.

VERDICT: APPROVE