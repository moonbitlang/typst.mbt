Reviewed `review-loop-1-click..review-loop-2-select`, stat first. No builds or files changed; the appendix and generated page code were excluded from review.

1. **BLOCKER — The long-item fallback attributes other spans to the first origin.**  
   [review_select.mbt:116](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_select.mbt:116)

   On a sufficiently wide page with hyphenation disabled, render `Seq([Keyed("A", "a".repeat(40000)), Keyed("B", "b".repeat(40000))])`. The identical styles allow one text item; glyph ranges eventually saturate. The fallback assigns its entire text and every glyph’s word number to A. Clicking a B glyph therefore produces feedback naming A and omitting B.

   The documented one-word limit is acceptable; losing origins whose spans remain available is not. **Fix:** retain all contributing spans/origins in the coarse selection, without assigning another origin’s glyphs to the first origin.

2. **BLOCKER — A selection can include completely invisible text and its origin.**  
   [review_html.mbt:282](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:282)

   Render `Par(Seq(["before ", Scale("hidden", x=Pct(0), y=Pct(100)), " after"]))`. Group traversal still appends `"hidden"` to the word table, although its transformed layer cannot be hit. Selecting from “before” to “after” includes the invisible text and the `Scale` argument’s origin. Completely clipped text has the same problem.

   **Fix:** apply visibility filtering when collecting selectable words, including singular transforms and wholly clipped content. SVG clipping alone does not filter the numerical selection range.

3. **MAJOR — Frame boundaries insert spaces into continuous text.**  
   [review_html.mbt:232](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:232)

   `Par(Seq(["a", Box("b"), "c"]))` renders “abc”, but extraction produces `"a b c"` and `find("abc")` fails. `Box` supplies a hard frame; entering its group starts a new `before`, and returning leaves the parent’s `before` cleared.

   **Fix:** carry continuation information across group traversal, comparing endpoints and baselines in a common coordinate system. Group membership itself should not introduce whitespace.

4. **MAJOR — Clusters split across text items are emitted twice.**  
   [review_select.mbt:145](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_select.mbt:145)

   A concrete existing fixture is Arabic `مرحبًا` in Noto Sans Arabic. The [upstream golden:20](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/tests/golden/paged/text/copy-paste.txt:20) contains a zero-advance mark item with text `"بً"` followed by an item containing `"مرحبً"` with the same cluster contribution. `item_words` independently emits both, so feedback repeats `"بً"`.

   This duplication is separate from the accepted visual ordering of items. **Fix:** recognize shared cluster contributions across adjacent positioned runs, emitting their text once while preserving their glyph boxes and provenance.

5. **MAJOR — Unicode whitespace becomes selectable word content.**  
   [review_select.mbt:28](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_select.mbt:28)

   `Par("alpha\u{2009}beta")` treats the thin space as part of one word. Clicking “alpha” selects both words, clicking the gap selects text, and `find("alpha beta")` fails. NBSP and other Unicode whitespace have the same issue.

   **Fix:** use the existing `@unicode.is_whitespace` consistently for word splitting, seams, and search normalization.

6. **MAJOR — Accepted stored records can throw outside the storage guard.**  
   [page.js:140](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:140)

   This stored entry passes validation:
   ```json
   {"format":"typst.mbt review feedback 1","document":"Test","comment":"old","selected_text":"x","pages":[1],"origins":[{}]}
   ```
   `renderList` then throws at `o.start[0]`, before creating that entry’s Remove button. Missing `document` also passes validation and makes `Core.toText` throw. I confirmed both accepted malformed shapes with Node.

   **Fix:** validate the complete consumed record shape, including nested origins, or discard individual records whose validation/rendering fails.

7. **MAJOR — `find` has quadratic worst-case work.**  
   [review_select.mbt:270](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_select.mbt:270)

   Each candidate position compares the whole needle through `ArrayView` equality. For an unwrapped item containing 200,000 `"a"` characters, searching for `"a".repeat(99999) + "b"` performs approximately ten billion character comparisons before returning `None`.

   **Fix:** use a linear substring algorithm over the normalized stream, retaining the character-to-word mapping. This does not require a persistent search index.

The tests meaningfully cover ordinary selections, origin grouping, pieces, keyed content, and text formatting. The JavaScript checker genuinely compares records and text, but both implementations consume the same extracted words, so it cannot detect the extraction defects above. The hyphen-box assertion at [review_test.mbt:637](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_test.mbt:637) only checks for *any* gap box; ordinary spaces satisfy it. Important missing cases include multiple spans in an oversized item, shared clusters across items, text crossing groups/clips, Unicode whitespace, malformed storage, and non-BMP shortening boundaries.

I found no Core/library mismatch for valid shared word data: joining, gap markers, optional fields, key order, and code-point shortening align. The new data script escapes `<`, and dynamic UI content uses `textContent`/`value`. I found no normal-export mutation or new HTML/script injection path.

VERDICT: REQUEST CHANGES


---

## Triage (by the author of the slice; the review above is unchanged)

One review round was run on commit `325faea`. The findings were handled
in the commit that adds this file; the verdict is advisory.

| Finding | Decision |
|---|---|
| 1 the long-item fallback gives other spans to the first origin | Fixed. There is no whole-item fallback any more: a glyph whose range says nothing still has its span, and such glyphs form words of their own piece with the text `…`. Test: one text item of 80,000 bytes from two keyed strings (three words, origins A and B). |
| 2 invisible text is selectable | Fixed for a group that draws nothing (a transform without an inverse): the layer skips it, like `origin_at`, so its text is no word. Not addressed: text that a clip hides completely is still among the words (stated as a limit; deciding it needs the geometry of every clip). |
| 3 frame boundaries insert spaces | Fixed. Text goes on through a group that only places its content (identity transform): the end of the pen is carried in and out. Test: `Seq(["a", Box("b"), "c d"])` reads `abc d`. Groups with another transform still separate words. |
| 4 a cluster split over two text items is emitted twice | Not addressed in this slice: the engine puts the cluster's text into both items, and telling the copies apart needs the cluster model of a later slice. Stated as a limit; the origins of such a selection are right. |
| 5 Unicode white space is word content | Fixed: `@unicode.is_whitespace` for splitting, seams and the search. Test: a thin space and a no-break space. |
| 6 stored records of another shape can throw | Fixed: a stored record is kept only if the list can show it and turn it into text (checked inside a `try`). Checked in a browser with the two records of the review. |
| 7 `find` is quadratic in the worst case | Fixed: Knuth-Morris-Pratt. Test: a long repetitive needle. |
| tests: the hyphen assertion matches any gap | Fixed: the test now checks that the engine's hyphen is not in the page's words. |
| tests: non-BMP shortening boundaries | Not addressed: both sides shorten by code points (`for c in text` and `Array.from`), which the review confirmed by reading; no test was added. |

Also added after the coordinator's browser check: the page's self-test
verifies that nothing covers a page and that no effect (filter, blend
mode, opacity, `will-change`) is on a page, its artwork or its layer.
