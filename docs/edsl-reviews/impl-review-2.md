Six findings are **RESOLVED**; findings **2 and 7 are PARTIAL**.

| # | Status | Justification |
|---|---|---|
| 1 | **RESOLVED** | Replay collects hosts only while hashing the completed result, excluding selector hashing. [library/utils_hash.mbt:312](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/library/utils_hash.mbt:312) |
| 2 | **PARTIAL** | Direct `NCall`/`NValue` children now use the evaluator’s attachment and warning rules, but `Keyed` wrappers bypass that handling. [doc/lower.mbt:152](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:152) |
| 3 | **RESOLVED** | Each invocation recovers its occurrence span and keys from `args.span`, while preserving one host function per description. [doc/session.mbt:122](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/session.mbt:122) |
| 4 | **RESOLVED** | Setter generation retains optional positional bodies, including their positional `extra` handling. [scripts/docgen.py:661](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/scripts/docgen.py:661) |
| 5 | **RESOLVED** | Locationless strings receive a keyed fallback span preserving the enclosing argument’s location. [doc/origin.mbt:278](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/origin.mbt:278) |
| 6 | **RESOLVED** | Length-prefixed keys distinguish paths containing separators. [doc/origin.mbt:150](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/origin.mbt:150) |
| 7 | **PARTIAL** | `VStr` now marks long strings, covering `Value::str` and `Raw`; strings returned by calls still bypass marking. [doc/lower.mbt:340](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:340) |
| 8 | **RESOLVED** | Every twin compares pixmap dimensions, pixel buffers, and the report’s exported PNG bytes. [tests/runner/edsl_stage.mbt:342](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/tests/runner/edsl_stage.mbt:342) |

The remaining cases are verified by tracing the code:

1. **MAJOR — `Keyed` prevents label attachment to preceding content.** [doc/lower.mbt:61](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:61), [doc/lower.mbt:89](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:89)

   ```moonbit
   Document([
     Heading("x", numbering=Numbering("1.")),
     Keyed("k", Value::label("h")),
     Ref("h"),
   ])
   ```

   The parent sequence sends `NKeyed` through `content`; its inner `NValue` becomes a separate one-item sequence. That sequence warns that `<h>` is unattached, leaving the heading unlabelled and the reference unresolved. Removing `Keyed` succeeds, violating its content-preserving contract. `Keyed` around `Call("label", ...)` has the same problem.

   **Fix:** Evaluate keyed inserted expressions with their key context, then process their resulting labels against the enclosing sequence. Add twins for both forms.

2. **MINOR — Call-produced long strings retain unreliable offsets.** [doc/lower.mbt:395](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:395), [doc/lower.mbt:193](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:193)

   `Document([Value::call("lorem", positional=[Value::int(65536)])])` produces a string exceeding 65,535 UTF-8 bytes without visiting `VStr`. The result is displayed without marking its origin, so `resolve_glyph` returns `Some(offset)`. Direct `Call("lorem", ...)` behaves identically.

   **Fix:** Check lowered engine `Str` results, including call results, for long-text marking; add a generated-string regression test.

Existing binaries passed **15 twins, 23 `doc` tests, 2 example tests, and 4 host-validation tests**. Direct binaries were used because `moon run` attempted a dependency-lock write forbidden by the read-only sandbox. No files were modified.

VERDICT: REQUEST CHANGES