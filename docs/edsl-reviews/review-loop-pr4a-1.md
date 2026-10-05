Reviewed `main..fb316f9`, with `--stat` first. No MoonBit builds were run. I exercised the actual JavaScript functions with in-memory fixtures and verified that the generated page matches its sources.

1. **BLOCKER — Stroke bounds can exclude painted geometry.**  
   [review_positions.mbt:145](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_positions.mbt:145) expands geometry by only half the stroke thickness, ignoring caps and joins.

   Concrete input: `@doc.Line(end_=(Pt(20), Pt(20)), stroke=@doc.Stroke(thickness=Pt(2), cap="square"))`. Relative to its position, the returned bounds are `[-1, 21]` on both axes; the square caps extend to approximately `[-1.414, 21.414]`. Acute miter joins likewise extend beyond the returned rectangle. The page outlines those portions, but `positions` excludes them.

   **Fix:** Compute bounds from the stroke outline, or use a conservative expansion that accounts for cap, join and miter limit.

2. **BLOCKER — “Show” restores the wrong occurrence of a shape.**  
   [page.js:505](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:505) uses `querySelector` with only the origin number on the saved page.

   Concrete document: construct one rectangle as `let r = @doc.Rect(...)`, then render `[r, r]` on one page. Comment on the second rectangle and press “Show”: it selects the first. This fails without recompilation. Furthermore, after recompilation the validation compares only file and start position; an origin number reassigned to a different `Keyed` occurrence at that location also passes.

   **Fix:** Store the particular layer occurrence and validate its complete origin identity when restoring it. Reject ambiguous or changed occurrences. This needs no engine changes.

3. **BLOCKER — An accepted stored comment can throw on “Show”.**  
   [page.js:276](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:276) accepts an object comment whose record has `origins: []`: both `.every(...)` and `Core.toText` succeed. With a valid current `origin: 0, page: 1`, [page.js:508](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:508) then reads `want.file` from `undefined`.

   I reproduced the `TypeError` using an otherwise valid feedback record with its origins array emptied.

   **Fix:** Validate object-comment records as requiring an origin, and guard the lookup again in `show`.

4. **BLOCKER — The storage change silently discards existing comments.**  
   [page.js:278](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:278) now requires `{record, ...selection}`, while main stores bare feedback records under the same storage key. Every existing comment fails `usable` and disappears. Adding a new comment then overwrites storage with the filtered list, permanently removing the old comments.

   The page instead says “None yet” and says the list is kept in the browser; it gives no migration warning.

   **Fix:** Preserve and migrate bare records. They can remain readable and copyable with “Show” unavailable because their selection indices were never stored.

5. **MAJOR — A failed “Show” leaves an unrelated selection active.**  
   [page.js:498](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:498) changes selection state only on success.

   Reproduce by selecting a current word, then showing a stored comment whose indexed word has changed or disappeared. The failure message appears, but the previous highlight, panel and copyable feedback remain active. I reproduced the unchanged `from`/`to` state. This contradicts the stated behavior that failure selects nothing.

   **Fix:** Clear the selection on restoration failure before displaying the message.

6. **MAJOR — Equal-range origins cause quadratic work, repeated during export.**  
   [review_positions.mbt:200](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_positions.mbt:200) compares every coarse candidate with every candidate. Equal ranges never terminate that search early. The JavaScript implementation does the same; `positions` additionally performs linear `whole.contains` searches per box.

   Concrete document: render 10,000 small rectangles from one constructor location under distinct existing `Keyed` keys. All are valid, equal-range candidates. Actual `Core.findLine` took approximately **0.20 seconds for 5,000 origins and 0.75 seconds for 10,000**, before DOM outlining. [review_html.mbt:595](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:595) can repeat the identical source-line query 40 times—four billion candidate comparisons at 10,000 origins.

   **Fix:** Group equal ranges and compute containment without all-pairs scanning; use a set for whole-origin membership; deduplicate or cache sampled `(file, line)` queries.

7. **MINOR — The midpoint guarantee is stronger than bounding boxes permit.**  
   [edsl-review.md:483](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/docs/edsl-review.md:483) promises that looking up every returned box’s middle leads back to its origin. A rectangle with a stroke and no fill already disproves this: its bounding-box center is empty. An overlapping object can instead make the center resolve to another origin.

   **Fix:** State the guarantee as provenance membership: the recorded box belongs to an origin containing the requested source position. Keep midpoint checks as checks of selected fixtures, without promising them generally.

The central selection rule looks correct: nested candidates, equal ranges under different keys, ranges sharing either edge, and mixed tier-3/coarse candidates follow the stated rule. `words` is sorted for binary search. Matrix composition matches the layer’s `translate`/`matrix` nesting and the click lookup’s inverse order. I found no new injection path, empty-input bounds failure, or change to normal compilation/export behavior.

The new tests verify useful basic cases, but overstate their coverage. [review_test.mbt:887](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_test.mbt:887) checks only returned boxes, so it cannot establish completeness. The showcase test mostly checks constructor kinds; its prose case does not check every box’s source line. The embedded comparisons check word/origin IDs, not geometry or comment restoration.

Important missing tests are: restoring the second of two same-origin shapes; old stored comments; malformed/stale restoration; square caps and miter joins; nested nonidentity transforms on text; equal-range keys and shared-edge containment; end-exclusive column boundaries; and words with multiple boxes.

VERDICT: REQUEST CHANGES


---

## Triage (by the author of the slice; the review above is unchanged)

One review round was run on commit `fb316f9`. The findings were handled
in the commit that adds this file; the verdict is advisory.

| Finding | Decision |
|---|---|
| 1 the box of a stroked shape can leave out caps and joins | Fixed: the box is widened by half the thickness times the square root of two (a square cap in any direction) or, for a pointed join, times the miter limit. It is a bounding box with room, not the outline. Test: a diagonal line with square caps. |
| 2 "Show" restores the first shape of an origin, not the commented one | Fixed: a comment on a shape or an image keeps which of its origin's shapes on the page it is, and "Show" requires the origin to be the same call in all that the record says of it (file, module, constructor, parameter, keys, start, end). Checked in a browser: the third of nineteen rules of the showcase's table. |
| 3 an accepted stored comment can throw on "Show" | Fixed: a comment on a shape needs a record with one origin, and "Show" compares through the record's own fields. Checked in a browser with the record of the review. |
| 4 the storage change discards existing comments | Fixed: a record that an earlier version stored alone is kept, without a selection; "Show" says that it can be copied, not shown. Checked in a browser. |
| 5 a failed "Show" leaves another selection active | Fixed: the selection is cleared first; the message says that nothing is selected. Checked in a browser. |
| 6 equal locations cause quadratic work | Fixed in the library and in the page: each distinct location is compared once, whole-origin membership is a set, and the embedded sample lines are distinct. Test: forty keyed squares from one call site. |
| 7 the midpoint guarantee is stronger than bounding boxes permit | Fixed in the text: the guarantee is that a box belongs to an origin whose location has the line; the midpoint look-ups are checks of the test documents. |
| tests: completeness of the boxes, the source line of every prose box, geometry in the embedded comparisons | Not addressed: the embedded comparisons are about which words and origins a line gives (the page marks its own shapes and needs no geometry); the unit tests check boxes of known size and the other direction for returned boxes. |
| tests: nested non-identity transforms on text, words with several boxes | Not addressed in this slice: the map is the composition that the layer writes as nested groups, which the page's self-test checks against the click lookup at 3,072 points; a text-specific case was not added. |
| tests: end-exclusive columns | Added. |
