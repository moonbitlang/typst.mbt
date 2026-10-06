// The kit: elements that are not one Typst element (docs/edsl-ports.md,
// section 4). What the first element, `Cards`, settled for the ones that
// follow, with what `Chip` and `DataTable` added (marked "step 4"):
//
// 1. An element is an expansion. It is defined by the constructors of
//    `doc` that it expands to, and its documentation says which. It has no
//    behaviour of its own in the engine: what a `set` or `show` rule of the
//    document does to the element's primitives, it does to the element.
//    (Step 4.) The expansion can hold a rule of its own, scoped to it: a
//    `Seq` of the rule and the primitive (`DataTable`'s cells are
//    unbreakable by a `SetTableCell`, since a table has no parameter for
//    it). It is not wrapped in a block for that, which would be a second
//    box around the primitive's own. What reads descriptions in `doc` (the
//    lint of adjacent text, `Para`) takes rules and then one block for
//    that block.
//
// 2. Names and parameters. An element is a type with a constructor of its
//    name (`Cards(..)`), like the elements of `doc`, and it is content
//    (`IntoContent`, interpolation into `Prose`, `Debug`). Its parameters
//    have the names, the types and the defaults of the parameters of the
//    primitives that they are passed to (`columns`, `gutter`, `fill`,
//    `stroke`, `inset`, `radius`), in the type of the primitive that draws
//    them. A default differs from the primitive's only where the default
//    is the reason the element exists, and the documentation says so. An
//    element has no parameter for a fixed height, no `extra` and no
//    `label` (`Labelled(element, ..)` labels what it expands to).
//    (Step 4.)
//    - A parameter can be a part of a primitive's parameter, in the type
//      of that part, where the element supplies the rest: `DataTable`'s
//      `stroke` is one `Stroke`, the bottom side of its cells' strokes
//      (the other sides are none, which is the element's reason) and the
//      outline of its frame.
//    - What a primitive has per cell (`inset`, `align`, `fill` of a
//      table) stays per cell (`Cells[..]`): the caller gives a value, one
//      per column, or a function of its own. The element adds no
//      parameter for one look of one row.
//    - No parameter for the style of text. Text is styled by a `Text`
//      around the element (`Chip`) or by rules of the document
//      (`DataTable`: a show-set rule on the cells of a row or of a
//      column), and the documentation says which rule reaches which
//      part. A parameter of the primitive that the element neither has
//      nor sets itself is set by a set rule before it (`SetTable(..)`
//      for the gutters); what the element sets itself is its contract,
//      and the documentation says what is not reachable (in a
//      `DataTable`: cells with a position, lines and a footer among the
//      rows, a header of several rows, a frame in another stroke than the
//      rules).
//    - A description is opaque: an element cannot tell a string from
//      other content. One that treats a string differently takes a
//      `String`, and has a second constructor, `of`, for content
//      (`Chip(text, ..)`, `Chip::of(body, ..)`).
//    - An element that takes the caller's data by items that the review
//      loop has to tell apart can take `key`, a function from the index
//      of an item to its key.
//
// 3. Provenance: `@doc.Composite`. The constructor takes `loc~` and
//    `args_loc~` (`#callsite(autofill(loc, args_loc))`) and builds
//    everything inside the hook's `build`, so that the element is one call
//    site. Every argument of the caller that is passed on to a constructor
//    is marked where it is passed, `site.arg(i, v)`, with `i` the index of
//    the parameter in the element's declaration: text of the caller
//    resolves to its argument, an error in a value is reported at its
//    argument, and what the element generates is the call. A part that is
//    built per item of the caller's data is wrapped in `Keyed` with the
//    item's index (step 4: or with the key that `key` gives for it), so
//    that the parts are distinct occurrences. (Step 4.) What an element has
//    to know about a description that it is given, it asks `doc`
//    (`@doc.Content::table_cell_spans` for the columns that a cell takes).
//
// 4. Measuring. An element measures only where the engine cannot do the
//    work (`Cards` without a radius does not: the grid makes the cells of
//    a row equally high). One that does creates a callback (`Layout`) in
//    `build`, so it cannot be constructed inside a callback (a show rule, a
//    `Cells` function, a `Context` or `Layout`); it is built before and
//    captured. Its documentation says "Measures", and says what happens in
//    an unbounded region and at a page break. In the callback:
//    - the caller's content was converted in `build` (`Content(item)`),
//      once;
//    - what is measured and what is placed are the same descriptions under
//      the same keys, built by one function;
//    - sizes are not computed by hand: a row is measured as a row of the
//      grid that places it, at the width that `Layout` gives, so tracks
//      and gutters are resolved by the engine in both;
//    - what is measured must be laid out under the same styles and
//      properties as what is placed: a property of a primitive that only
//      places (the inset of the grid's cells) is given explicitly, so
//      that a rule of the document cannot make the two differ.
//    (Step 4.) An element does not create a callback where a value of the
//    primitive does the work (an alignment per column, one stroke for all
//    cells, a line without a stroke that takes away the rule under the
//    last row): one without a callback can be built anywhere, and its
//    documentation says so. A callback in an argument (a `Cells` function)
//    is the caller's, created where the caller creates it. An element
//    that does not measure still says what it does at a page break.
//
// 5. Invalid arguments. Constructors do not raise. An argument that the
//    element cannot accept is `site.invalid(message, arg=i)`: an error at
//    that argument when the document is compiled. What the engine rejects
//    (a value of the wrong kind) is the engine's error, at the argument.
//    The caller's arrays are copied: a description does not change with
//    them. (Step 4.) What is wrong with one item of the caller's data is
//    `Keyed(key, site.invalid(..))`: at the argument, under the key of the
//    item, with a message that names the item (`rows[3]`). A key of the
//    caller's that `Keyed` does not take is an error at `key`.
//
// 6. Twin. An element has a functional Typst twin: a Typst function with
//    the same expansion (`doc/twins/kit.mbt`), and documents that use both
//    are pairs of the `edsl` stage (structure, frames with memoization on
//    and off, SVG, PDF, PNG). The function passes on only the arguments
//    that it was given, as the element does (and gives the element's own
//    defaults, as the element does). (Step 4.) It checks what the element
//    checks, with the element's messages after the `assertion failed: ` of
//    Typst's `assert`, and a test gives both the same rejected input
//    (`doc/twins/kit_wbtest.mbt`).
//
// 7. Tests (`<element>_test.mbt`): the expansion (the lowered content is
//    that of the primitives written out); the property the element exists
//    for, from the frames; provenance through the review loop (a string of
//    the caller, a description of the caller, what the element generates,
//    an error in every forwarded argument at that argument's index, keys);
//    for a measuring element the creation rule, an unbounded region, a
//    page break, and that nothing leaves the page. (Step 4.) For an
//    element without a callback: that it can be built inside one, what it
//    does at a page break, and what can leave the page or its place (a
//    row higher than a page, a label wider than its column), as the
//    engine's fact.
