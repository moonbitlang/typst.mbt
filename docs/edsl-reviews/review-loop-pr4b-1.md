Reviewed exactly `review-loop-4-rest..6d6ec64`. This is a static review; no builds or tests were run.

1. **BLOCKER — Nested values can allocate the same keyed span twice.**  
   [doc/lower.mbt:113](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/lower.mbt:113)

   Concrete input:

   ```moonbit
   @doc.Document([
     @doc.Keyed(
       "a",
       @doc.Value::call("strong", positional=[
         @doc.Value::content(@doc.Keyed("b", "same")),
       ]),
     ),
     @doc.Keyed("a", @doc.Keyed("b", "same")),
   ])
   ```

   Let `P` be the document argument’s `Pieces`. The first branch creates `P.keyed["a"]`, then stores the counter for `["a", "b"]` in **that child’s map**. The second branch stores its counter for `["a", "b"]` directly in **P’s map**.

   These are separate counters starting at zero, but [Registry::keyed_span](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/origin.mbt:298) maps both bases to the same document argument token under `["a", "b"]`. Both `"same"` text nodes therefore receive exactly the same span. The review merges them into one piece. Replacing the `strong` call with `Value::content(Keyed("b", "same"))` also produces equal plain text nodes including their spans.

   This violates the slice’s central distinctness guarantee. Independently advancing these counters also repeats collisions in the U+FDD2 overflow occurrences.

   **Fix:** Share one path-to-counter table across all locationless descendants of the enclosing argument. Separate the current counter from that shared owner; reset the owner only at the existing argument/site boundaries. Add the mixed-nesting example above, including an overflow case, as a regression test.

2. **MINOR — The compatibility test does not check span compatibility.**  
   [doc/review_test.mbt:1057](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_test.mbt:1057)

   The test claiming that a once-used key retains its old span checks only `(kind, keys, param)`. Every sub-range—and every overflow occurrence—resolves to those same values. An implementation incorrectly starting at piece 1 would pass.

   **Fix:** Assert the actual lowered text span equals the argument’s full token in the keyed occurrence, matching the old `keyed_span(fallback, keys)` behavior. Include a first keyed body reached after unkeyed pieces have crossed an overflow boundary.

3. **MINOR — The callback tier table contradicts the added test.**  
   [docs/edsl-review.md:578](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/docs/edsl-review.md:578)

   The callback rows promise “3 if literal, else 2,” but the new show callback returns `Lit("added ")`, explicitly asserted as **tier 1** in [doc/review_test.mbt:1103](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_test.mbt:1103). Providing source files cannot promote it: call-level origins have no parameter and remain tier 1.

   **Fix:** Describe callback content as following the usual origin rules: tier 3 for verified literal arguments, tier 2 for other argument origins, and tier 1 for call origins.

I found no additional defect in first-use token selection, counter lifetime, path encoding, or the showcase changes.

VERDICT: REQUEST CHANGES


---

## Triage (by the author of the slice; the review above is unchanged)

One review round was run on commit `6d6ec64`. The findings were handled
in the commit that adds this file; the verdict is advisory.

| Finding | Decision |
|---|---|
| 1 a path of keys reached in two nestings has two counters, so two bodies get one span | Fixed: the counters of an argument's key paths are in one table of that argument, which the counters themselves share, so `["a", "b"]` is one counter wherever it is spelled. Test: the review's document, extended to sixty-one texts under that path (more than the token has pieces), all with distinct spans. |
| 2 the compatibility test does not check the span | Fixed: the test compares the span of the keyed text with the whole token of the argument in the listing line of the origin under the key, for a key used once and for a keyed body after two hundred pieces without a key. |
| 3 the callback rows of the table promise tier 3 or 2 where a test asserts tier 1 | Fixed in the text: callback content follows the usual rules (3 for a literal argument that is the text, 2 for another argument, 1 for content whose location is a call). |
