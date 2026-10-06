// The kit: elements that are not one Typst element (docs/edsl-ports.md,
// section 4). What the first element, `Cards`, settled for the ones that
// follow:
//
// 1. An element is an expansion. It is defined by the constructors of
//    `doc` that it expands to, and its documentation says which. It has no
//    behaviour of its own in the engine: what a `set` or `show` rule of the
//    document does to the element's primitives, it does to the element.
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
//    item's index, so that the parts are distinct occurrences.
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
//
// 5. Invalid arguments. Constructors do not raise. An argument that the
//    element cannot accept is `site.invalid(message, arg=i)`: an error at
//    that argument when the document is compiled. What the engine rejects
//    (a value of the wrong kind) is the engine's error, at the argument.
//    The caller's arrays are copied: a description does not change with
//    them.
//
// 6. Twin. An element has a functional Typst twin: a Typst function with
//    the same expansion (`doc/twins/kit.mbt`), and documents that use both
//    are pairs of the `edsl` stage (structure, frames with memoization on
//    and off, SVG, PDF, PNG). The function passes on only the arguments
//    that it was given, as the element does.
//
// 7. Tests (`<element>_test.mbt`): the expansion (the lowered content is
//    that of the primitives written out); the property the element exists
//    for, from the frames; provenance through the review loop (a string of
//    the caller, a description of the caller, what the element generates,
//    an error in every forwarded argument at that argument's index, keys);
//    for a measuring element the creation rule, an unbounded region, a
//    page break, and that nothing leaves the page.
