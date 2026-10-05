Reviewed `main..review-loop-1-click` at `3da6898`, excluding the later-slice appendix and generated page code. No builds or tests were run.

1. **BLOCKER — Open filled paths give different answers in the page and library.**  
   [review_html.mbt:261](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:261) emits the original open path with fill hit testing. SVG implicitly closes open subpaths for filling. [SVG specification](https://www.w3.org/TR/SVG2/painting.html#FillProperty)

   The existing [open-path test](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_test.mbt:182) supplies `M0,0 L10,0 L10,10`, filled black: the library returns `None` at local `(8,2)`, but the page selects `Curve`. Conversely, the library’s unclosed winding can hit points to the right of the triangle that SVG excludes. This path starts with a move, so the stated limit does not cover it.

   **Fix:** Generate fill-hit geometry matching the library’s winding semantics instead of emitting open fill paths directly. Exercise this existing fixture in the browser parity test.

2. **BLOCKER — Zero-scale content remains clickable in the library.**  
   [review_click.mbt:174](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_click.mbt:174) assumes `invert()` rejects singular transforms. However, [Transform::invert](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/library/transform.mbt:199) returns an inverse translation when either scale is zero.

   Concrete input: `Scale(Rect(width=Pt(20), height=Pt(20), fill=Black), x=Pct(0), y=Pct(100), origin=Both(Top, Left))`. A click inside the original rectangle returns its origin, although the SVG layer has collapsed horizontally and cannot hit that area.

   **Fix:** Reject singular transforms explicitly in the review lookup. Preserve the strict upstream API if required, documenting the additional review-mode rule; no engine change is necessary.

3. **BLOCKER — Merging text runs loses valid glyph hit regions with negative advances.**  
   [review_html.mbt:218](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:218) treats the interval from the initial pen position to the final pen position as the union of glyph boxes. That requires nonnegative advances.

   Concrete input: `Text("iiW", font=["Libertinus Serif"], size=Pt(10), tracking=Pt(-4), kerning=false, ligatures=false)`. The embedded font’s metrics give advances `-1.29, -1.29, 9.51` points. The final glyph’s library hit interval is `[-2.58, 6.93]`, relative to the text item, while the layer emits only `[0, 6.93]`. At local x = −1, halfway up the text box, the library finds `Text` and the page misses it.

   **Fix:** Union the actual nonnegative-width glyph boxes, merging only compatible intervals. Preserve the library’s forward glyph priority when different origins overlap.

4. **BLOCKER — Four-decimal matrix rounding can remove an entire hit target.**  
   [review_html.mbt:11](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:11) rounds numbers before [serializing group matrices](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:210).

   Wrap a filled 20pt rectangle in a top-left scale of `0.001%`, then a top-left scale of `10000000%`. Their product is 1: the document and library retain a normal-sized rectangle. The layer rounds the inner coefficient `0.00001` to zero, making its target disappear.

   **Fix:** Serialize transform coefficients with round-trip precision. Add a nested reciprocal-scale parity case.

5. **BLOCKER — Selecting a rectangle changes subsequent click answers.**  
   [page.css:119](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.css:119) adds a 0.75-unit stroke to the selected text/image rectangle. Those rectangles retain the default `visiblePainted` pointer behavior, which includes a painted stroke. [SVG pointer-event rules](https://www.w3.org/TR/SVG2/interact.html#PointerEventsProperty)

   For a rectangle spanning x = 10–20, select it and then click x = 9.75 halfway down its side. The page still selects that origin; the library’s rectangle test excludes the point. The startup self-test cannot catch this because it runs before highlighting.

   **Fix:** Give text/image hit rectangles explicit `pointer-events: fill`, or draw highlighting separately with pointer events disabled. Test parity after selection too.

6. **BLOCKER — A short, densely dashed line can exhaust time and memory during preview export.**  
   [review_click.mbt:81](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_click.mbt:81) expands the entire dashed stroke for each tested point. [review_html.mbt:128](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:128) unconditionally performs 768 lookups per page.

   Concrete valid input through `Markup`: `#line(length: 100pt, stroke: (thickness: 1pt, dash: (0.000000001pt, 0.000000001pt)))`. This requires roughly 50 billion painted dashes per expansion. The [dash iterator](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/kurbo/stroke.mbt:860) enumerates transitions, and stroke expansion retains the resulting outline. Even a probe far from the line triggers this work.

   **Fix:** Avoid complete dash expansion for point containment, using bounds and local dash evaluation. Bound unavoidable review-geometry expansion and report a controlled export failure. Caching alone does not fix the first expansion.

7. **MAJOR — Embedded document links can navigate outside the self-contained preview.**  
   [review_html.mbt:343](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_html.mbt:343) embeds live SVG anchors, and [page.js:86](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/review_page/page.js:86) does not cancel their activation.

   With `Link(Url("https://example.org/"), body="linked words")`, keyboard focus can reach the underlying SVG link; Enter navigates away and makes an external request. The pointer overlay does not remove keyboard focusability. [SVG focus rules](https://www.w3.org/TR/SVG2/interact.html#Focus)

   **Fix:** Make the artwork subtree inert within the review wrapper, or disable anchor activation and focus there, while retaining the normal exporter’s bytes.

The tests substantiate the sampled library cases, showcase source positions, and inclusion of unchanged SVG strings. They do **not** establish general browser parity: the HTML tests inspect substrings, and the showcase grid misses the cases above. Additionally, [spot()](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/doc/examples/review/review_wbtest.mbt:101) silently accepts `jump_from_click == None`; it checks equality only when a source jump already exists. The [winding square test](/Users/dii/git/typst.mbt/.claude/worktrees/agent-a0b3c7078aa2f2b40/kurbo/winding_test.mbt:28) accepts either sign despite claiming a particular orientation convention. Escaping coverage also lacks hostile origin metadata such as `</script>` and U+2028.

I found no normal-output mutation or concrete HTML/JSON escaping defect. The finite-coordinate winding arithmetic follows the upstream implementation closely.

VERDICT: REQUEST CHANGES


---

## Triage (by the author of the slice; the review above is unchanged)

One review round was run on commit `3da6898`. The findings were handled
in the commit that adds this file; the verdict is advisory.

| Finding | Decision |
|---|---|
| 1 open filled paths: page and library differ | Fixed. `origin_at` tests a filled curve and a clip as they are painted (open subpaths closed), like the layer; `jump_from_click` keeps upstream's test. Test: the open triangle in both lookups. |
| 2 a scale of zero stays clickable | Fixed for `origin_at` (a group whose transform has no inverse is skipped); `jump_from_click` keeps upstream's `invert`. Test added. |
| 3 merged text boxes with negative advances | Fixed. The layer writes the boxes of the glyphs that have one, merged only while the pen moves forward, in reverse order so that the first glyph is on top. Test: `iiW` with tracking of -4pt. |
| 4 four-decimal rounding of matrices | Fixed. Transform coefficients are written unrounded. Test: two nested scales whose product is one. Coordinates stay rounded to four decimals of a point (stated as a limit). |
| 5 the outline of the clicked box takes the pointer | Fixed. Boxes take the pointer in their interior only (`pointer-events: fill`); the self-test runs a second time with every shape marked. |
| 6 a densely dashed line exhausts time and memory | Fixed for the export and `origin_at`: they test the undashed stroke, which is also what the layer does, so the work no longer depends on the number of dashes. Not addressed for `jump_from_click`: it expands dashes like upstream and is as expensive as upstream for such a line (stated as a limit). The probe grid is bounded at about 4,000 points per document. |
| 7 links of the document can be followed by keyboard | Fixed. The exporter's SVG is inside an inert wrapper; its bytes are unchanged. |
| tests: `spot()` accepts a missing jump | Fixed: only a link may stand in for the source jump. |
| tests: the winding test accepts either sign | Fixed: the sign is asserted. |
| tests: no hostile metadata | Added: a `Keyed` key and a title with `</script>` and U+2028. |
| tests do not establish general browser parity | Not addressed beyond the above: the unit tests check the layer's markup and the library; parity is checked by the self-test of a generated page in a browser (the showcase: 3,072 points, twice), which is not part of `moon test`. |
