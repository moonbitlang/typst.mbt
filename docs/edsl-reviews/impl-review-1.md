I found four MAJOR and four MINOR issues. Counterexamples below are verified by tracing the code; no files were modified.

1. **MAJOR — Host collection includes query execution, not just its result.** [library/introspector.mbt:531](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/library/introspector.mbt:531)

   Recording collects hosts only from `hash128(output)`, but validation wraps the entire replay. `ElementIntrospector::query` also hashes its selector at line 668.

   For a heading carrying host numbering function `h`, querying `Select::heading(numbering=h)` records `[h]` from the result. Replay collects `[h, h]`: once from the selector, once from the result. Validation rejects even the unchanged introspector.

   **Fix:** Evaluate the replayed query before opening the collector, then collect only while fingerprinting its result. Add a real-backend test asserting successful validation; checking compilation warnings alone does not establish convergence because `analyze` suppresses warnings for equal histories.

2. **MAJOR — Label-valued expressions do not follow their functional Typst twins.** [doc/lower.mbt:103](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:103)

   `NValue` and `NCall` immediately call `display()`. For `Label`, that produces raw text. In contrast, `eval/markup.mbt:47` attaches a label-valued expression to the preceding eligible content.

   For example, a numbered heading followed by `Value::label("h")` and `Ref("h")` fails to resolve the reference; the twin using `#label("h")` succeeds. `Call("label", ...)` has the same problem, violating §13’s expression-twin contract.

   **Fix:** Preserve label values until sequence lowering can apply the evaluator’s attachment and warning rules.

3. **MAJOR — Reused callbacks misattribute keyed occurrences.** [doc/session.mbt:111](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/session.mbt:111)

   The cached host closure captures the first lowering’s `span`, while every invocation starts with `keys: []`.

   With `c = Context() <| _ => { "x" }`, compiling `Document([Keyed("a", c), Keyed("b", c)])` attributes both returned strings to occurrence `"a"`. If the callback returns `Par("x")`, that newly registered origin loses the enclosing key entirely.

   **Fix:** Retain one `HostFunc` per description, but derive the occurrence span and key path per invocation and carry them into result lowering and callback diagnostics.

4. **MAJOR — The generator removes genuinely settable optional bodies.** [scripts/docgen.py:660](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/scripts/docgen.py:660)

   Filtering every field named `body` removes optional positional bodies from set rules and from their positional `extra` mappings.

   Consequently, `SetRect(extra=[("body", Value::content("x"))])` passes `body` as a named argument and fails with `unexpected argument: body`, whereas `#set rect([#"x"])` is valid. `SetTitle` is omitted altogether despite `title.body` being settable. This contradicts §§6.1 and 8.

   **Fix:** Determine eligibility from field metadata and constructor overrides, retaining optional positional bodies. Regenerate the setters and test inherited bodies plus explicit `none`/`auto`.

5. **MINOR — `Keyed` does not affect plain strings’ fallback origins.** [doc/lower.mbt:81](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:81)

   `NKeyed` changes `Lower.keys` but passes the original fallback span unchanged. A plain string has no site and uses that span directly.

   Thus `Document([Keyed("a", "alpha"), Keyed("b", "beta")])` resolves both texts to the unkeyed document argument.

   **Fix:** Register a keyed version of the fallback origin, preserving its argument location, when lowering locationless content.

6. **MINOR — Origin deduplication has deterministic key-path collisions.** [doc/origin.mbt:122](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/origin.mbt:122)

   Joining unrestricted keys with `"\u{1}"` makes `["a\u{1}b"]` and `["a", "b"]` identical. Reusing one `Lit` description under those two paths returns the first occurrence’s origin for both.

   **Fix:** Use a structural key or length-prefixed encoding, and test separator-containing keys.

7. **MINOR — Long strings through `Value` retain unreliable offsets.** [doc/lower.mbt:291](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/doc/lower.mbt:291)

   Only `NText` marks long text. `Document([Value::str("word ".repeat(14000))])` lowers a known 70,000-byte string without marking its origin, so `resolve_glyph` returns `Some(offset)` contrary to §12.4. `Raw` string arguments also bypass the marking.

   **Fix:** Apply long-string marking to value-string lowering and other applicable text-display paths; extend the existing long-text test to these cases.

8. **MINOR — The required milestone PNG comparison is missing.** [tests/runner/edsl_stage.mbt:302](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a343352cbf9234c25/tests/runner/edsl_stage.mbt:302)

   The twin runner compares frames, SVG and PDF, but never PNG pixmaps. The example test merely checks PNG page count. Neither implements §16.2’s milestone pixel-equivalence gate.

   **Fix:** Render both showcase twins with identical resolved options and compare dimensions and pixel buffers.

Checked and found correct:

- `compile_with` preserves the existing compilation flow; recipe checks remain shared with evaluation.
- Sequence nesting, set-rule tail scoping/liftability, view re-emission, creation-rule rejection and stale-handle checks follow the inspected design paths.
- Generated element mappings and the storage-exception audit passed; inspected resource paths remain root-relative and system access is separated.
- Existing binaries passed all **14 twins**, **20 `doc` tests**, and **2 example tests**.

VERDICT: REQUEST CHANGES