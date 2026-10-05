Reviewed `review-loop-2-select..review-loop-3-source`, stat first. No MoonBit build or tests were run. I exercised the existing JavaScript Core with synthetic data.

1. **BLOCKER — Deep nesting can abort the source reader.**  
   [review_source.mbt:142](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_source.mbt:142) recursively scans every nested group. [strip:376](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_source.mbt:376) then repeats that scan after removing each enclosing pair: O(n) stack depth and O(n²) work.

   Concrete input: 100,000 opening parentheses, `"x"`, then 100,000 closing parentheses. This can reach the reader through a different provider file without requiring the compiler to accept deep nesting: compile a literal containing `x` plus 200,000 spaces, then have the provider substitute that equally long parenthesized expression at its location. Source-range validation succeeds; scanning exhausts the stack instead of falling back to tier 2.

   **Fix:** scan delimiters iteratively and reuse matching endpoints when stripping parentheses; alternatively reject excessive depth before recursing. Cover deeply nested and truncated provider input.

2. **MINOR — Trailing comments make supported literals disappear.**  
   [review_source.mbt:366](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_source.mbt:366) removes leading comments but only trailing whitespace. Consequently:

   ```moonbit
   @doc.Seq([
     "alpha",
     "beta" // explanation
   ])
   ```

   retains only `alpha` as literal text. The last element fails the exact-end check, becomes a hole, and the unchanged document falls back to tier 2. The reader’s “comments around it” description and its tests overstate coverage.

   **Fix:** accept trailing trivia through token-aware scanning after a literal or enclosing group. Keep method calls and operators rejected.

3. **MAJOR — Selecting across repeated copies drops source highlights.**  
   [review_feedback.mbt:408](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_feedback.mbt:408) and [page.js:153](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:153) discard any range starting before the preceding range’s end.

   With `Document([Outline(), Heading("alpha beta")])`, select from the first copy’s `beta` through the second copy’s `beta`. The whole-text comparison correctly passes. Its source ranges are `beta`, followed by `alpha beta`; the second range is discarded by both mark renderers. Only `beta` is highlighted, although `alpha` was selected too.

   I reproduced this using the actual Core: ranges `16–20` and `10–20` produced only four carets at column 16. The page/library equality check cannot catch a bug shared by both implementations.

   **Fix:** sort and union ranges per line for marking. Preserve the original reading-order ranges in the feedback record.

4. **MINOR — Tabs misalign the copied caret marks.**  
   [review_feedback.mbt:409](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_feedback.mbt:409) replaces every skipped source code point with one space; Core does the same. For a source line containing an actual tab before `Par("hello")`, the excerpt preserves the tab while the underline substitutes one space. In a normal tab-expanding display, the carets point at different characters. The panel’s substring highlighting is correct.

   **Fix:** preserve tabs in unmarked prefixes, or consistently expand tabs in both displayed source and caret lines, without changing reported source columns.

5. **MINOR — Missing source lines are reported as omitted excerpt lines.**  
   [review_locate.mbt:297](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_locate.mbt:297) stops at unavailable lines but computes `more` from the entire requested range.

   For an origin on line 10 and a provider returning `"one line"`, the record has `excerpt: []` and `excerpt_more: 1`; its text claims “1 more lines” even though that line does not exist. Core reproduces this. The short-file test checks only that the excerpt is empty.

   **Fix:** distinguish unavailable lines from existing lines omitted by the six-line cap, and test `excerpt_more` for shortened files.

6. **BLOCKER — `@system.sources` can read outside its root.**  
   [system.mbt:103](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/system/system.mbt:103) validates spelling, then opens the path normally. If `/project/link` points to `/outside`, `sources(root="/project")("link/example.mbt", "m")` reads `/outside/example.mbt`. Nothing in the name triggers the guard. Those contents can subsequently be embedded in the preview.

   Windows drive-qualified names such as `C:/outside/example.mbt` also pass with the default root.

   **Fix:** enforce filesystem containment when opening the file, accounting for symlinks and directory boundaries; reject drive-qualified absolute paths too. Add provider-specific containment tests.

7. **MAJOR — Source feedback has avoidable quadratic processing.**  
   [page.js:55](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:55) converts the entire source line with `Array.from` for **each run**.

   A literal containing `x\u{ad}` repeated 8,000 times passes comparison but produces 8,000 separate runs: filtered soft hyphens leave gaps in `at`. Its source line is approximately 56,000 characters. Using that synthetic run data, actual `Core.feedback` took approximately 347 ms at 4,000 repetitions and 1,326 ms at 8,000. This work repeats during selection.

   Separately, [review_locate.mbt:290](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_locate.mbt:290) and Core’s `wanted.includes` perform quadratic deduplication when one origin spans many source lines, despite displaying only six.

   **Fix:** convert each source line to code points once per operation or cache it; use a set for line membership while retaining first-seen order.

The tests meaningfully cover ordinary literals, escape widths, interpolation holes, multiline boundaries, changed source, and missing providers. Two claims need qualification:

- The [repeated-heading test](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/examples/review/review_wbtest.mbt:342) checks occurrences separately, so it misses selections crossing copies.
- The [hidden-content test](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/examples/review/review_wbtest.mbt:400) selects `seen` and asserts tier 3. Hidden/scaled text belongs to other origins; this does not test rejection when only part of **one origin’s literal** survives.

Important missing cases include non-BMP column positions, CRLF, tabs, trailing comments, character literals in arrays, six-line truncation, and `k` complete copies plus a partial copy. Add independent expected ranges and marks alongside parity tests.

I found no additional successful-comparison mapping error or source-data script injection: code-point slicing, gaps across literal boundaries, `<` escaping, and DOM text insertion are consistent with the stated approach.

VERDICT: REQUEST CHANGES


---

## Triage (by the author of the slice; the review above is unchanged)

One review round was run on commit `fb02fd2`. The findings were handled
in the commit that adds this file; the verdict is advisory.

| Finding | Decision |
|---|---|
| 1 deep nesting can exhaust the stack of the reader | Fixed: brackets are followed 64 levels deep (`GROUP_DEPTH`), also when enclosing parentheses are removed; a deeper argument is "an expression". Test: 5,000 nested parentheses, and an unclosed nest inside an array. |
| 2 a comment behind a literal makes it disappear | Fixed: white space and comments behind a literal are accepted (a method call behind it is still no literal). Tests: a comment behind a string and behind the last element of an array. |
| 3 a selection across two copies loses marks | Fixed in the library and in the page: the marks of a line are the sorted union of the runs on it; the record keeps the runs in reading order. Test: from the first copy's last word to the second copy of a heading (runs `title`, `Repeated title`; fourteen carets). |
| 4 tabs misalign the line of marks | Fixed: a tab of the source line is a tab in the line of marks. Test with a provider in memory. |
| 5 missing lines are counted as lines left out | Fixed: only lines that the file has are counted. Test: `more` is 0 for a file that is too short. |
| 6 `@system.sources` can read outside its root through a link | Partly. Drive-qualified names are refused now. Links are not resolved: the names are the source locations that the compiler recorded for the program's own files, not input of a document, and following a project's links is what reading its sources means. The documentation of the provider and guarantee 4 of the design no longer say "refuses names that leave its root"; they say what is checked. |
| 7 quadratic work per feedback | Fixed: the page cuts a source line into code points once per record, and both sides collect excerpt lines with a set. |
| tests: the hidden-content test does not test a part of one origin | The comment of that test now says what it tests; a provider test was added for a literal of which only a part is on the page (tier 2). |
| tests: non-BMP columns, CRLF, six-line cap | Added: a character outside the basic plane in the reader test, a file with CRLF in the provider test, a prose block of eight lines (six shown, two more). |
| tests: character literals in arrays, `k` copies plus a partial copy | Not addressed: an array argument of content has no character literals, and a partial copy needs a document that shows part of one string, for which there is no small construction; the rule itself (`at % count == 0`) is covered by the partial-literal test. |
