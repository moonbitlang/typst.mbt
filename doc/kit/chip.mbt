// `Chip` (docs/edsl-ports.md, section 4; finding H4): a label in a box
// that sits in a line of text.

///|
/// A chip (a pill, a tag, a badge): a short label in a box, in a line of
/// text, in a table cell, in a heading.
///
/// ```mbt nocheck
/// Text(Chip("needs review", fill=amber_soft, radius=Corners(all=Pt(8))),
///   size=Pt(7), weight=SemiBold, fill=amber)
/// ```
///
/// It is `Box(text, inset=Sides(x=Em(0.6)), outset=Sides(y=Em(0.3)), ..)`
/// with the spaces of `text` as no-break spaces (U+00A0). The two things a
/// box in a line does not do by itself:
///
/// - **The line keeps its height and the label its baseline.** The padding
///   to the left and to the right is the box's inset. The padding above
///   and below is its outset: it is drawn around the box and takes no
///   room, so the label stands on the baseline of the line and the line is
///   as high as without the chip. (A vertical inset makes the line higher
///   by the padding; a `baseline` shift moves the label off the line.)
///   What is drawn above and below the line needs the room there: the
///   leading of a paragraph, the inset of a table cell.
/// - **It is not broken at a space.** A box is laid out in the width of
///   the line that it is in, and a label of several words in a narrow
///   column is broken inside its box. With no-break spaces it is one line.
///   A chip that is wider than its line then runs out of it, and its box,
///   which is never wider than the line, ends before its text: give the
///   column the room (an `Auto` column is as wide as its chips). The
///   no-break spaces are the text: what a reader copies out of the PDF has
///   them. Only spaces are changed: a label can still be broken where text
///   breaks without one (after a hyphen, at a line break in the string).
///
/// It does not measure and creates no callback: it can be built anywhere,
/// also in the cell of a table and inside a callback.
///
/// Parameters, with the names and types of `Box`:
///
/// - `fill`, `stroke`, `radius`: the box's; none by default.
/// - `inset`: the box's. The default, `Sides(x=Em(0.6))`, is the
///   element's own: the horizontal padding. An inset with a vertical part
///   is a vertical inset of the box, and makes the line higher.
/// - `outset`: the box's. The default, `Sides(y=Em(0.3))`, is the
///   element's own: the vertical padding.
///
/// The paddings are in `em` of the text around the box, so they follow the
/// size that a `Text` around the chip gives its label.
///
/// The label's own style (size, weight, colour, font) is not a parameter:
/// a `Text` around the chip sets it, as above. A chip has no width, height
/// or `baseline` (convention 2 of the kit; they are what moves the label
/// off the line).
///
/// `Chip::of(body, ..)` is the same box around content that is not a
/// string (a word in `Strong`, a formula, an icon). The element cannot
/// change the spaces of content, so that body can be broken in a narrow
/// column, like the body of any box.
///
/// Provenance: the call. The label resolves to the `text` argument, and
/// with the source at hand to the characters of its literal (also where a
/// space of the literal is a no-break space on the page). An error in
/// `fill` is at `fill`.
///
/// Twin: the function `chip` of `doc/twins/kit.mbt`, a `box`.
pub struct Chip {
  priv composite : @doc.Composite
}

///|
/// The box of a chip around `body`. The parameters by their index in the
/// declarations of `Chip::Chip` and `Chip::of`, for `site.arg`: the body 0,
/// fill 1, stroke 2, radius 3, inset 4, outset 5.
fn chip_box(
  site : @doc.CompositeSite,
  body : &@doc.IntoContent,
  fill : @doc.Paint?,
  stroke : @doc.Sides[@doc.Stroke]?,
  radius : @doc.Corners[@doc.Length]?,
  inset : @doc.Sides[@doc.Length]?,
  outset : @doc.Sides[@doc.Length]?,
) -> @doc.Box {
  // The paddings of a chip: to the sides in the box, above and below
  // around it.
  let inset = match inset {
    Some(inset) => inset
    None => @doc.Sides(x=Em(0.6))
  }
  let outset = match outset {
    Some(outset) => outset
    None => @doc.Sides(y=Em(0.3))
  }
  @doc.Box(
    site.arg(0, body),
    fill?=site.arg(1, fill),
    stroke?=site.arg(2, stroke),
    radius?=site.arg(3, radius),
    inset=site.arg(4, inset),
    outset=site.arg(5, outset),
  )
}

///|
#callsite(autofill(loc, args_loc))
pub fn Chip::Chip(
  text : String,
  fill? : @doc.Paint,
  stroke? : @doc.Sides[@doc.Stroke],
  radius? : @doc.Corners[@doc.Length],
  inset? : @doc.Sides[@doc.Length],
  outset? : @doc.Sides[@doc.Length],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Chip {
  // A label is not broken at a space.
  let label = text.replace_all(old=" ", new="\u{00A0}")
  {
    composite: @doc.Composite("Chip", loc, args_loc, site => {
      chip_box(site, label, fill, stroke, radius, inset, outset)
    }),
  }
}

///|
/// A chip around content that is not a string: see [Chip]. The body can be
/// broken in a narrow column.
#callsite(autofill(loc, args_loc))
pub fn Chip::of(
  body : &@doc.IntoContent,
  fill? : @doc.Paint,
  stroke? : @doc.Sides[@doc.Stroke],
  radius? : @doc.Corners[@doc.Length],
  inset? : @doc.Sides[@doc.Length],
  outset? : @doc.Sides[@doc.Length],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> Chip {
  {
    composite: @doc.Composite("Chip", loc, args_loc, site => {
      chip_box(site, body, fill, stroke, radius, inset, outset)
    }),
  }
}

///|
pub impl @doc.IntoContent for Chip with fn into_content(self) {
  @doc.IntoContent::into_content(self.composite)
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Chip with @doc.IntoContent::{into_content}

///|
/// Interpolation into the text of `Prose`.
pub impl Show for Chip with fn output(self, logger) {
  Show::output(self.composite, logger)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Chip with Show::{to_string, output}

///|
pub impl @debug.Debug for Chip with fn to_repr(self) {
  @debug.Debug::to_repr(self.composite)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Chip with @debug.Debug::{to_repr}
