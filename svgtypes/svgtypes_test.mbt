// Ports of upstream unit tests that use the (crate-private) `Stream` or
// iterator state directly.

///|
test "stream parse_number errors (number.rs)" {
  for text in ["q", "", "-", "+", "-q", ".", "99999999e99999999"] {
    let s = @svgtypes.Stream::from(text)
    try s.parse_number() catch {
      e => assert_eq(e.to_string(), "invalid number at position 1")
    } noraise {
      _ => fail("expected an error for \{text}")
    }
  }
}

///|
test "stream parse_length (length.rs)" {
  let s = @svgtypes.Stream::from("1q")
  assert_eq(s.parse_length(), @svgtypes.Length::new(1.0, None))
  try s.parse_length() catch {
    e => assert_eq(e.to_string(), "invalid number at position 2")
  } noraise {
    _ => fail("expected an error")
  }
  for text in ["1,", "1 ,", "1 1"] {
    let s = @svgtypes.Stream::from(text)
    assert_eq(s.parse_length(), @svgtypes.Length::new_number(1.0))
  }
}

///|
test "stream parse_angle (angle.rs)" {
  let s = @svgtypes.Stream::from("1q")
  assert_eq(s.parse_angle(), @svgtypes.Angle::new(1.0, Degrees))
  try s.parse_angle() catch {
    e => assert_eq(e.to_string(), "invalid number at position 2")
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "stream iri (funciri.rs)" {
  assert_eq(@svgtypes.Stream::from("   #id   text").parse_iri(), "id")
  assert_eq(@svgtypes.Stream::from("url(#id) qwe").parse_func_iri(), "id")
}

///|
test "stream directional position (directional_position.rs)" {
  for text in ["left,", "left ,", "left center"] {
    assert_eq(@svgtypes.Stream::from(text).parse_directional_position(), Left)
  }
  try @svgtypes.Stream::from("something").parse_directional_position() catch {
    e =>
      assert_eq(
        e.to_string(),
        "expected 'left', 'right', 'top', 'bottom', 'center' not 'something' at position 1",
      )
  } noraise {
    _ => fail("expected an error")
  }
}

///|
test "transform list parser (transform.rs)" {
  let ts = @svgtypes.TransformListParser::from("scale(2) text")
  assert_true(ts.next() is Some(Ok(Scale(sx=2.0, sy=2.0))))
  match ts.next() {
    Some(Err(e)) => assert_eq(e.to_string(), "unexpected end of stream")
    _ => fail("expected an error")
  }
  assert_true(ts.next() is None)
  assert_true(@svgtypes.TransformListParser::from(" ").next() is None)
  assert_true(
    @svgtypes.TransformListParser::from("\u{1}").next() is Some(Err(_)),
  )
}

///|
test "path segment helpers (path.rs)" {
  let segs = @svgtypes.PathParser::from("M10-20l30.1.5.1-20z")
    .iter()
    .map(r => r.unwrap())
    .collect()
  assert_eq(segs.map(s => s.is_abs()), [true, false, false, false])
  assert_eq(segs.map(s => s.command()), [b'M', b'l', b'l', b'z'])
}

///|
test "simplifying arc (path.rs)" {
  let s = @svgtypes.SimplifyingPathParser::from(
    "M 30 40 A 40 30 20 1 1 150 100",
  )
  assert_true(s.next() is Some(Ok(MoveTo(x=30.0, y=40.0))))
  guard s.next() is Some(Ok(CurveTo(x1~, y1~, x2~, y2~, x~, y~))) else {
    fail("expected a curve")
  }
  assert_eq([x1, y1, x2, y2, x, y].map(v => v.round()), [
    45.0, 16.0, 84.0, 10.0, 117.0, 27.0,
  ])
  guard s.next() is Some(Ok(CurveTo(x1~, y1~, x2~, y2~, x~, y~))) else {
    fail("expected a curve")
  }
  assert_eq([x1, y1, x2, y2, x, y].map(v => v.round()), [
    150.0, 43.0, 165.0, 76.0, 150.0, 100.0,
  ])
  assert_true(s.next() is None)
}

///|
test "font shorthand errors (font.rs)" {
  let cases : Array[(String, @svgtypes.SvgTypesError)] = [
    ("", UnexpectedEndOfStream),
    ("Noto Sans", UnexpectedData(0)),
    ("12pt  ", UnexpectedEndOfStream),
    ("something 12pt 'Noto Sans'", UnexpectedData(0)),
    ("'Noto Sans' 13pt", UnexpectedData(0)),
    (
      "small-caps normal normal normal italic xx-large Times",
      UnexpectedData(32),
    ),
  ]
  for case in cases {
    let (text, expected) = case
    try @svgtypes.FontShorthand::from_str(text) catch {
      e => assert_eq(e, expected)
    } noraise {
      _ => fail("expected an error for \{text}")
    }
  }
}

///|
test "display (error.rs, font.rs, viewbox.rs, transform_origin.rs)" {
  assert_eq(
    @svgtypes.SvgTypesError::InvalidChar([b'\xE4', b')', b','], 3).to_string(),
    "expected ')', ',' not 'ä' at position 3",
  )
  assert_eq(@svgtypes.FontFamily::Named("A B").to_string(), "\"A B\"")
  assert_eq(@svgtypes.FontFamily::SansSerif.to_string(), "sans-serif")
  assert_eq(
    @svgtypes.ViewBoxError::InvalidSize.to_string(),
    "viewBox has a negative or zero size",
  )
  assert_eq(
    @svgtypes.TransformOriginError::ZIndexIsPercentage.to_string(),
    "z-index cannot be a percentage",
  )
}
