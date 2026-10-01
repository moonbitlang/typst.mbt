// Parts of `typst-html/src/mathml.rs`: the equation stylesheet and its
// constants.
//
// TODO: The conversion of resolved math into MathML nodes
// (`convert_math_to_nodes`) is not ported yet; it needs the math IR
// (`typst_library::math::ir`).

// CSS classes.

///|
let multiline_equation_class : String = "multiline-equation"

///|
let aligned_class : String = "aligned"

///|
let left_align_class : String = "left-align"

///|
let right_align_class : String = "right-align"

///|
let cases_class : String = "cases"

///|
let flushed_class : String = "flushed"

///|
let left_flush_class : String = "left-flush"

///|
let right_flush_class : String = "right-flush"

// CSS values.

///|
let equation_row_gap : @library.Em = @library.Em::new(0.5)

///|
let frac_padding : @library.Em = @library.Em::new(0.1)

///|
/// The CSS styles for equations, added to the `<head>` of documents with
/// equations (upstream `EQUATION_CSS_STYLES`).
let equation_css_styles : String = {
  let row_gap = @library.to_css(equation_row_gap)
  let frac_padding = @library.to_css(frac_padding)
  let css =
    $|/* Alignment */
    $|mtable.\{right_align_class} > mtr > mtd,
    $|mtable > mtr > mtd.\{right_align_class},
    $|mtable.\{left_align_class} > mtr > mtd.\{right_align_class},
    $|mtable.\{aligned_class} > mtr > mtd:nth-child(odd) {
    $|  justify-items: end;
    $|  text-align: right;
    $|}
    $|mtable.\{cases_class} > mtr > mtd,
    $|mtable.\{left_align_class} > mtr > mtd,
    $|mtable > mtr > mtd.\{left_align_class},
    $|mtable.\{aligned_class} > mtr > mtd:nth-child(even),
    $|math:is(:not([display])) > mtable.\{multiline_equation_class} > mtr > mtd {
    $|  justify-items: start;
    $|  text-align: left;
    $|}
    $|mtable.\{cases_class} > mtr > mtd,
    $|mtable.\{aligned_class} > mtr > mtd,
    $|mtable > mtr > mtd.\{flushed_class},
    $|mtable > mtr > mtd.\{left_flush_class} {
    $|  padding-left: 0;
    $|}
    $|mtable.\{cases_class} > mtr > mtd,
    $|mtable.\{aligned_class} > mtr > mtd,
    $|mtable > mtr > mtd.\{flushed_class},
    $|mtable > mtr > mtd.\{right_flush_class} {
    $|  padding-right: 0;
    $|}
    $|
    $|/* Tables */
    $|mtable {
    $|  math-style: inherit;
    $|}
    $|mtd {
    $|  math-depth: auto-add;
    $|  math-style: compact;
    $|  math-shift: compact;
    $|}
    $|
    $|/* Equations */
    $|mtable.\{multiline_equation_class} > mtr > mtd {
    $|  math-depth: inherit;
    $|  math-style: inherit;
    $|  math-shift: inherit;
    $|  padding: 0;
    $|}
    $|math > mtable.\{multiline_equation_class} > mtr:not(:last-child) > mtd {
    $|  padding-bottom: \{row_gap};
    $|}
    $|
    $|/* Fractions */
    $|mfrac {
    $|  padding-inline: 0;
    $|  margin-inline: \{frac_padding};
    $|}
    $|
    $|/* Accents */
    $|mover[accent="true" i] > :first-child {
    $|  font-feature-settings: "dtls";
    $|}
    $|mover.dotted[accent="true" i] > :first-child {
    $|  font-feature-settings: "dtls" 0;
    $|}
    $|
    $|/* Other rules for scriptlevel, displaystyle and math-shift */
    $|munder > :nth-child(2),
    $|munderover > :nth-child(2) {
    $|  math-shift: compact
    $|}
    $|munder[accentunder="true" i] > :not(:first-child),
    $|mover[accent="true" i] > :not(:first-child) {
    $|  math-depth: inherit;
    $|  math-style: inherit;
    $|  math-shift: inherit;
    $|}
  css
}
