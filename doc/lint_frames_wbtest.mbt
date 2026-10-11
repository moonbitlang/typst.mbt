// What the lints of the pages (`lint_frames.mbt`) rest on, and their
// parts.

///|
test "L2: no character of an embedded font is its glyph 0" {
  // Glyph 0 in the frames means a missing character only if no font uses
  // it for a character. The character maps of the embedded fonts: the
  // code points that they give glyph 0 are U+0000, and U+FFFF, which the
  // segment that ends a map of format 4 maps to the missing glyph without
  // listing it. Neither is a character of a text, and a text that has one
  // shows the missing glyph, which is what the lint says.
  let mut faces = 0
  let mut mapped = 0
  let zero : Map[String, Unit] = Map([])
  for data in @assets_fonts.fonts() {
    for font in @library.Font::iter(data) {
      guard font.ttf() is Some(face) && face.tables().cmap is Some(cmap) else {
        continue
      }
      faces += 1
      for subtable in cmap.subtables.iter() {
        guard subtable.is_unicode() else { continue }
        subtable.codepoints(n => {
          guard subtable.glyph_index(n) is Some(id) else { return }
          mapped += 1
          if id.0 == 0 {
            zero[code_point(Int::unsafe_to_char(n.reinterpret_as_int()))] = ()
          }
        })
      }
      if face.glyph_index('\u{FFFF}') is Some(id) && id.0 == 0 {
        zero["U+FFFF"] = ()
      }
    }
  }
  inspect(
    "\{faces} faces, \{mapped} characters",
    content=(
      #|17 faces, 208924 characters
    ),
  )
  inspect(
    zero.keys().collect().join(" "),
    content=(
      #|U+FFFF U+0000
    ),
  )
}

///|
test "L2: the characters of a glyph, and how a message names them" {
  let text = ItemText::new("a\u{4e2d}\u{1F600}b")
  let of = (from : Int, to : Int) => {
    match text.range(from, to) {
      Some(chars) => String::from_array(chars.to_owned())
      None => "-"
    }
  }
  inspect(of(0, 1), content="a")
  inspect(of(1, 4), content="中")
  inspect(of(4, 8), content="😀")
  inspect(of(1, 8), content="中😀")
  inspect(of(8, 9), content="b")
  // Not at characters, empty, or past the end.
  inspect(of(2, 4), content="-")
  inspect(of(1, 3), content="-")
  inspect(of(4, 4), content="-")
  inspect(of(8, 12), content="-")
  inspect(of(65535, 65535), content="-")
  inspect(
    [
      glyph_subject(['中']),
      glyph_subject(['\u{1F468}', '\u{200D}', '\u{1F469}']),
      glyph_subject(['\u{1}']),
      glyph_subject(['\u{a0}']),
      glyph_subject(['\u{10FFFF}']),
    ].join("\n"),
    content=(
      #|"中" (U+4E2D)
      #|"👨👩" (U+1F468 U+200D U+1F469)
      #|U+0001
      #|U+00A0
      #|"􏿿" (U+10FFFF)
    ),
  )
}

///|
/// How `leaves` reports the box `x0..x1`, `y0..y1` against a box of 100
/// by 50 at the origin.
fn leaving(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x~ : Bool = true,
  y~ : Bool = true,
  slack~ : (Double, Double) = (0.0, 0.0),
) -> String {
  let (amount, side) = leaves(
    @kurbo.Rect::new(x0, y0, x1, y1),
    @kurbo.Rect::new(0.0, 0.0, 100.0, 50.0),
    x,
    y,
    slack~,
  )
  if amount > LINT_TOLERANCE {
    "\{side_names[side]} \{points(amount)}"
  } else {
    "inside"
  }
}

///|
test "L3: how far a box leaves another" {
  inspect(leaving(10, 10, 90, 40), content="inside")
  inspect(leaving(-0.9, -1, 101, 50.5), content="inside")
  inspect(leaving(-3, 10, 90, 40), content="left 3pt")
  inspect(leaving(10, -2.25, 90, 40), content="top 2.3pt")
  inspect(leaving(10, 10, 112.5, 40), content="right 12.5pt")
  inspect(leaving(10, 10, 90, 70), content="bottom 20pt")
  // The farthest side.
  inspect(leaving(-3, 10, 90, 70), content="bottom 20pt")
  // Only the sides of an axis that counts.
  inspect(leaving(-3, 10, 90, 70, y=false), content="left 3pt")
  inspect(leaving(10, 10, 90, 70, y=false), content="inside")
  inspect(leaving(-3, 10, 90, 40, x=false), content="inside")
  // What a glyph may hang over the end of its line.
  inspect(leaving(10, 10, 104, 40, slack=(3.5, 0.0)), content="inside")
  inspect(leaving(10, 10, 106, 40, slack=(3.5, 0.0)), content="right 2.5pt")
  inspect(leaving(10, 10, 90, 54, slack=(3.5, 0.0)), content="bottom 4pt")
  // A length in a message.
  inspect(
    [points(0.0), points(0.04), points(12.0), points(12.34), points(-0.5)].join(
      " ",
    ),
    content="0pt 0pt 12pt 12.3pt -0.5pt",
  )
}
