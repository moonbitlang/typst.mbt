# Codex review of docs/edsl-ports.md, revision 3 (gpt-6-astra, xhigh, 2026-10-06)

One required change remains: **Composite’s caller-argument attribution**.

| Second-review requirement | Revision 3 |
|---|---|
| 1. Colour contract | Resolved: “lowered to the engine’s `Ratio`”; explicit colour-weight pairs and constructor-valued spaces; “`Auto` is upstream’s default”; no CSS equivalence. These match the native wrappers and colour implementation. [§3.4](/Users/dii/git/typst.mbt/docs/edsl-ports.md:194) |
| 2. Fixed Canvas | Resolved: “an unbreakable `Block` of that size”; the fixed-height statement explicitly exempts Canvas. [Expansion](/Users/dii/git/typst.mbt/docs/edsl-ports.md:257), [exception](/Users/dii/git/typst.mbt/docs/edsl-ports.md:340). |
| 3. Lints | Resolved: L2 uses “that glyph’s span”; L3 permits “the page only”; L4 counts positions “before lowering” and excludes callback results. The narrowed L4 is implementable from descriptions without counting layout invocations. [§6](/Users/dii/git/typst.mbt/docs/edsl-ports.md:328) |
| 4. Placeholders | Resolved: a placeholder inside code or a link target “is a located error”. This can use deferred invalid-description handling without changing the engine or making constructors raise. [§5](/Users/dii/git/typst.mbt/docs/edsl-ports.md:294) |
| 5. Kit provenance | **Incomplete:** the dynamic scope supplies ownership, but the stated hook does not supply caller-argument mapping. Details below. [§4](/Users/dii/git/typst.mbt/docs/edsl-ports.md:234) |
| 6. Sticky blocks | Resolved: “consecutive sticky blocks form a group” and the paragraph must be sticky too. [§2.4](/Users/dii/git/typst.mbt/docs/edsl-ports.md:110) |

**VERDICT: REQUEST CHANGES**

Required changes:

1. **Complete Composite’s argument mapping before implementing Cards.** Constructors currently create `Site` metadata; registration happens during lowering, so an eager construction scope can record composite ownership without an engine change. However, primitive arguments carry their own parameter indices ([ArgNode](/Users/dii/git/typst.mbt/doc/content.mbt:89)), which lowering indexes directly into the registered site’s argument ranges ([Lower::args](/Users/dii/git/typst.mbt/doc/lower.mbt:674)).

   For example, the proposed `Cards` has `gutter` at index **2** and `fill` at index **3**, whereas generated `Grid` assigns `gutter` index **3** ([Grid](/Users/dii/git/typst.mbt/doc/elements_gen.mbt:8190)). Substituting the Cards site therefore attributes Grid’s gutter to the caller’s fill argument. Suppressing internal argument locations instead avoids that incorrect attribution but loses the promised argument precision. Plain strings cannot restore it: they become `NText(..., None)` ([String conversion](/Users/dii/git/typst.mbt/doc/content.mbt:162)).

   Give kit code a way to associate forwarded arguments and locationless bodies with the appropriate composite parameter; generated values can fall back to the composite call. Preserve independently constructed children’s sites.

   The callback aspect itself needs no redesign: eagerly running `build` before compilation creates valid callback serials; rebuilding ordinary descriptions inside its callback remains valid. Newly created **callback descriptions** there must still fail the existing creation check ([Session::host](/Users/dii/git/typst.mbt/doc/session.mbt:97)). Keep that distinction when implementing the hook.

Optional changes: none.
