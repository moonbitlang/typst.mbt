// Unit tests of the `typst-frame-v1` encoder on synthetic documents that
// exercise every record type and nested value encoding.

///|
/// A fake OpenType backend (the contract of `library/font.mbt`).
priv struct FakeFace {
  upem : Double
}

///|
impl @library.FontFace for FakeFace with fn family(_) {
  "Fake Serif"
}

///|
impl @library.FontFace for FakeFace with fn post_script_name(_) {
  Some("FakeSerif-Regular")
}

///|
impl @library.FontFace for FakeFace with fn instantiate(self, _) {
  self
}

///|
impl @library.FontInstanceFace for FakeFace with fn units_per_em(self) {
  self.upem
}

///|
impl @library.FontInstanceFace for FakeFace with fn glyph_hor_advance(_, glyph) {
  Some(glyph.to_int() * 10)
}

///|
impl @library.FontInstanceFace for FakeFace with fn glyph_ver_advance(_, _) {
  None
}

///|
impl @library.FontInstanceFace for FakeFace with fn glyph_bounding_box(_, _) {
  Some({ x_min: 0, y_min: -200, x_max: 500, y_max: 700, })
}

///|
fn pt(v : Double) -> @library.Abs {
  @library.Abs::pt(v)
}

///|
fn size(x : Double, y : Double) -> @library.Axes[@library.Abs] {
  @library.Axes::new(pt(x), pt(y))
}

///|
fn pos(x : Double, y : Double) -> @library.Point {
  @library.Point::new(pt(x), pt(y))
}

///|
fn rgb(r : Float, g : Float, b : Float) -> @library.Color {
  Process(Rgb({ red: r, green: g, blue: b, alpha: 1.0, }))
}

///|
fn span_null(_ : @syntax.Span) -> String {
  "null"
}

///|
fn encode_doc(doc : @layout.PagedDocument) -> String {
  let enc = FrameEncoder::new(span_null)
  enc.header("rev", "sha", "synthetic")
  enc.diagnostics("ok", ["warning - \"hi\""])
  enc.document(doc)
  enc.end()
  enc.out.to_string()
}

///|
fn page(frame : @library.Frame) -> @layout.Page {
  {
    frame,
    bleed: { left: pt(0.0), top: pt(0.0), right: pt(0.0), bottom: pt(0.0), },
    fill: Auto,
    numbering: None,
    supplement: @library.Content::empty(),
    number: 1,
  }
}

///|
test "primitives" {
  inspect(f64_hex(1.0), content="\"f64:3ff0000000000000\"")
  inspect(f64_hex(-0.0), content="\"f64:8000000000000000\"")
  // One point is 127 raw units.
  inspect(abs_enc(pt(1.0)), content="\"f64:405fc00000000000\"")
  inspect(f32_hex(0.5), content="\"f32:3f000000\"")
  inspect(
    json_str("a\"b\\c\n\t\u{1}é😀"),
    content=(
      #|"a\"b\\c\n\t\u0001é😀"
    ),
  )
  inspect(is_paged("paged"), content="true")
  inspect(is_paged("pdftags large"), content="true")
  inspect(is_paged("html features(html)"), content="false")
}

///|
test "frame records" {
  let face = FakeFace::{ upem: 1000.0, }
  let font = @library.Font::new(b"fake font data", 0, face)
  let wght : @library.FontVariations = [
    (@library.OpenTypeTag("wght"), @library.AxisValue(700.0)),
  ]
  let inst = font.instantiate_with(wght)
  let glyph = (id : UInt16, start : UInt16, end : UInt16) => @library.Glyph::{
    id,
    x_advance: inst.x_advance(id).unwrap(),
    x_offset: @library.Em::zero(),
    y_advance: @library.Em::zero(),
    y_offset: @library.Em::new(0.25),
    range_start: start,
    range_end: end,
    span: (@syntax.Span::detached(), 0),
  }
  let linear : @library.Paint = Gradient(
    Linear({
      stops: [
        (rgb(1.0, 0.0, 0.0), @library.Ratio::zero()),
        (rgb(0.0, 0.0, 1.0), @library.Ratio::one()),
      ],
      angle: @library.Angle::deg(90.0),
      space: Process(Oklab),
      relative: Auto,
      anti_alias: true,
    }),
  )
  let text : @library.TextItem = {
    font: inst,
    size: pt(10.0),
    fill: linear,
    stroke: Some({
      ..@library.FixedStroke::from_pair(Solid(@library.color_black), pt(0.5)),
      dash: Some({ array: [pt(1.0), pt(2.0)], phase: pt(0.5), }),
      cap: Round,
      join: Bevel,
    }),
    lang: @library.Lang("de"),
    region: Some(@library.Region("CH")),
    text: "fié",
    glyphs: [glyph(1, 0, 1), glyph(2, 1, 4)],
  }
  let loc = @library.Location::new({ hi: 1, lo: 2, })
  let heading = @library.HeadingElem::new(@library.TextElem::packed("Hi"))
    .pack()
    .located(loc)
  let flags : @library.TagFlags = { introspectable: true, tagged: false, }
  let inner = @library.Frame::soft(size(20.0, 10.0))
  inner.set_baseline(pt(8.0))
  inner.push(pos(0.0, 8.0), Text(text))
  let group = @library.GroupItem::new(inner)
  group.transform = @library.Transform::translate(pt(1.0), pt(2.0))
  group.clip = Some(@library.Curve::rect(size(20.0, 10.0)))
  group.label = @library.Label::new("lbl")
  group.parent = Some(@library.FrameParent::new(loc, Yes))
  let raster = @library.Image::new(
    Raster(
      @library.RasterImage::new(
        b"png bytes",
        Exchange(Png),
        width=4,
        height=2,
        dpi=Some(144.0),
      ),
    ),
    Some("alt text"),
    Custom(Pixelated),
  )
  let svg = @library.Image::plain(
    Svg(@library.SvgImage::new(b"<svg/>", @library.Axes::new(16.0, 8.0))),
  )
  let pdf = @library.Image::plain(
    Pdf(
      @library.PdfImage::new(
        @library.PdfDocument::new(b"%PDF", num_pages=2),
        1,
        width=Float::from_double(595.0),
        height=Float::from_double(842.0),
      ),
    ),
  )
  let spot : @library.Color = Spot({
    colorant: {
      name: Some(Custom("PANTONE 1")),
      fallback: Cmyk({ c: 0.1, m: 0.2, y: 0.3, k: 0.4, }),
    },
    tint: @library.Ratio::new(0.5),
  })
  let frame = @library.Frame::hard(size(100.0, 50.0))
  frame.push(pos(0.0, 0.0), Tag(Start(heading, flags)))
  frame.push(pos(5.0, 5.0), Group(group))
  frame.push(
    pos(0.0, 20.0),
    Shape(
      @library.Geometry::Line(pos(30.0, 0.0)).stroked(
        @library.FixedStroke::from_pair(Solid(spot), pt(1.0)),
      ),
      @syntax.Span::detached(),
    ),
  )
  frame.push(
    pos(0.0, 0.0),
    Shape(
      {
        ..@library.Geometry::Rect(size(10.0, 5.0)).filled(
          Solid(@library.color_white),
        ),
        fill_rule: EvenOdd,
      },
      @syntax.Span::detached(),
    ),
  )
  frame.push(
    pos(40.0, 0.0),
    Shape(
      @library.Geometry::Curve(@library.Curve::ellipse(size(4.0, 2.0))).filled_and_stroked(
        Gradient(
          Radial({
            stops: [
              (@library.color_red, @library.Ratio::zero()),
              (@library.color_green, @library.Ratio::one()),
            ],
            center: @library.Axes::splat(@library.Ratio::new(0.5)),
            radius: @library.Ratio::new(0.5),
            focal_center: @library.Axes::splat(@library.Ratio::new(0.5)),
            focal_radius: @library.Ratio::zero(),
            space: Spot({
              name: Some(All),
              fallback: Luma({ luma: 0.0, alpha: 1.0, }),
            }),
            relative: Custom(Self_),
            anti_alias: false,
          }),
        ),
        @library.FixedStroke::from_pair(
          Gradient(
            Conic({
              stops: [
                (@library.color_red, @library.Ratio::zero()),
                (@library.color_green, @library.Ratio::one()),
              ],
              angle: @library.Angle::zero(),
              center: @library.Axes::splat(@library.Ratio::new(0.5)),
              space: Process(Hsv),
              relative: Custom(Parent),
              anti_alias: true,
            }),
          ),
          pt(1.0),
        ),
      ),
      @syntax.Span::detached(),
    ),
  )
  frame.push(
    pos(0.0, 30.0),
    Image(raster, size(8.0, 4.0), @syntax.Span::detached()),
  )
  frame.push(
    pos(10.0, 30.0),
    Image(raster, size(4.0, 2.0), @syntax.Span::detached()),
  )
  frame.push(
    pos(20.0, 30.0),
    Image(svg, size(16.0, 8.0), @syntax.Span::detached()),
  )
  frame.push(
    pos(40.0, 30.0),
    Image(pdf, size(5.0, 7.0), @syntax.Span::detached()),
  )
  frame.push(
    pos(0.0, 40.0),
    Link(Url(@library.Url("https://typst.app")), size(10.0, 2.0)),
  )
  frame.push(
    pos(0.0, 42.0),
    Link(
      Position({ page: @library.NonZeroUSize(2), point: pos(1.0, 2.0), }),
      size(10.0, 2.0),
    ),
  )
  frame.push(pos(0.0, 44.0), Link(Location(loc), size(10.0, 2.0)))
  frame.push(pos(0.0, 50.0), Tag(End(loc, { hi: 0, lo: 42, }, flags)))
  let second : @layout.Page = {
    ..page(@library.Frame::soft(size(10.0, 10.0))),
    bleed: { left: pt(1.0), top: pt(2.0), right: pt(3.0), bottom: pt(4.0), },
    fill: Custom(None),
    numbering: Some(Pattern(@library.NumberingPattern::from_str("1 / 1"))),
    supplement: @library.TextElem::packed("Seite"),
    number: 7,
  }
  let third : @layout.Page = {
    ..page(@library.Frame::soft(size(10.0, 10.0))),
    fill: Custom(Some(Solid(rgb(0.0, 0.5, 1.0)))),
    number: 8,
  }
  let info = @library.DocumentInfo::new()
  info.title = Some("Title")
  info.author = ["A", "B"]
  let doc = @layout.PagedDocument::new(
    [page(frame), second, third],
    info,
    @library.DocumentFormatOptions::new(),
  )
  inspect(
    encode_doc(doc),
    content=(
      #|["header","typst-frame-v1","rev","sha","synthetic"]
      #|["diagnostics","ok",["warning - \"hi\""]]
      #|["document",["Title",["A","B"],null,[],"auto","auto"],[["html",[["pretty","false",null]]],["pdf",[["pages","none",null],["standard","(\"1.7\",)",null],["tagged","auto",null],["pretty","false",null]]],["svg",[["pretty","false",null]]],["png",[["ppi","144.0",null]]],["bundle",[]]],3]
      #|["content",0,"[]"]
      #|["page",0,1,["f64:0000000000000000","f64:0000000000000000","f64:0000000000000000","f64:0000000000000000"],"auto",null,0]
      #|["frame","p0",["f64:40c8ce0000000000","f64:40b8ce0000000000"],null,"hard",13]
      #|["content",1,"heading(body: text(text: \"Hi\")) #0"]
      #|["tag-start","p0",0,["f64:0000000000000000","f64:0000000000000000"],0,1,true,false]
      #|["group","p0",1,["f64:4083d80000000000","f64:4083d80000000000"],"p0/1",["f64:3ff0000000000000","f64:0000000000000000","f64:0000000000000000","f64:3ff0000000000000","f64:405fc00000000000","f64:406fc00000000000"],[["M",["f64:0000000000000000","f64:0000000000000000"]],["L",["f64:40a3d80000000000","f64:0000000000000000"]],["L",["f64:40a3d80000000000","f64:4093d80000000000"]],["L",["f64:0000000000000000","f64:4093d80000000000"]],["Z"]],"lbl",[0,true]]
      #|["frame","p0/1",["f64:40a3d80000000000","f64:4093d80000000000"],"f64:408fc00000000000","soft",1]
      #|["font",0,"4c20a303b49a80101a677187038dbe626d979976ee22f9e0ec41b1f40469ba40",0,[["wght","f32:442f0000"]],"Fake Serif","FakeSerif-Regular","f64:408f400000000000"]
      #|["text","p0/1",0,["f64:0000000000000000","f64:408fc00000000000"],0,"f64:4093d80000000000",["linear",[[["Rgb","f32:3f800000","f32:00000000","f32:00000000","f32:3f800000"],"f64:0000000000000000"],[["Rgb","f32:00000000","f32:00000000","f32:3f800000","f32:3f800000"],"f64:3ff0000000000000"]],"f64:3ff921fb54442d18","Oklab","auto",true],[["solid",["Luma","f32:00000000","f32:3f800000"]],"f64:404fc00000000000","round","bevel",[["f64:405fc00000000000","f64:406fc00000000000"],"f64:404fc00000000000"],"f64:4010000000000000"],"de","CH","fié",[[1,"f64:3f847ae147ae147b","f64:0000000000000000","f64:0000000000000000","f64:3fd0000000000000",0,1,null,0],[2,"f64:3f947ae147ae147b","f64:0000000000000000","f64:0000000000000000","f64:3fd0000000000000",1,4,null,0]]]
      #|["shape","p0",2,["f64:0000000000000000","f64:40a3d80000000000"],["line",["f64:40adc40000000000","f64:0000000000000000"]],null,"non-zero",[["solid",["Spot",[["Custom","PANTONE 1"],["Cmyk","f32:3dcccccd","f32:3e4ccccd","f32:3e99999a","f32:3ecccccd"]],"f64:3fe0000000000000"]],"f64:405fc00000000000","butt","miter",null,"f64:4010000000000000"],null]
      #|["shape","p0",3,["f64:0000000000000000","f64:0000000000000000"],["rect",["f64:4093d80000000000","f64:4083d80000000000"]],["solid",["Luma","f32:3f800000","f32:3f800000"]],"even-odd",null,null]
      #|["shape","p0",4,["f64:40b3d80000000000","f64:0000000000000000"],["curve",[["M",["f64:0000000000000000","f64:405fc00000000000"]],["C",["f64:0000000000000000","f64:404c763305100a38"],["f64:405c763305100a38","f64:0000000000000000"],["f64:406fc00000000000","f64:0000000000000000"]],["C",["f64:4078a2733ebbfd72","f64:0000000000000000"],["f64:407fc00000000000","f64:404c763305100a38"],["f64:407fc00000000000","f64:405fc00000000000"]],["C",["f64:407fc00000000000","f64:4068a2733ebbfd72"],["f64:4078a2733ebbfd72","f64:406fc00000000000"],["f64:406fc00000000000","f64:406fc00000000000"]],["C",["f64:405c763305100a38","f64:406fc00000000000"],["f64:0000000000000000","f64:4068a2733ebbfd72"],["f64:0000000000000000","f64:405fc00000000000"]]]],["radial",[[["Rgb","f32:3f800000","f32:3e828284","f32:3e58d8ed","f32:3f800000"],"f64:0000000000000000"],[["Rgb","f32:3e38b8bc","f32:3f4ccccd","f32:3e808081","f32:3f800000"],"f64:3ff0000000000000"]],["f64:3fe0000000000000","f64:3fe0000000000000"],"f64:3fe0000000000000",["f64:3fe0000000000000","f64:3fe0000000000000"],"f64:0000000000000000",["Spot",[["All"],["Luma","f32:00000000","f32:3f800000"]]],"self",false],"non-zero",[["conic",[[["Rgb","f32:3f800000","f32:3e828284","f32:3e58d8ed","f32:3f800000"],"f64:0000000000000000"],[["Rgb","f32:3e38b8bc","f32:3f4ccccd","f32:3e808081","f32:3f800000"],"f64:3ff0000000000000"]],"f64:0000000000000000",["f64:3fe0000000000000","f64:3fe0000000000000"],"Hsv","parent",true],"f64:405fc00000000000","butt","miter",null,"f64:4010000000000000"],null]
      #|["image-resource",0,"png","d013614dc14a37ee20fe92005737ab7d3427e7e93580ad56ef8a42205e7f7a4e",null,["f64:4010000000000000","f64:4000000000000000"],"f64:4062000000000000",null,null,null]
      #|["image","p0",5,["f64:0000000000000000","f64:40adc40000000000"],0,["f64:408fc00000000000","f64:407fc00000000000"],"alt text","pixelated",null]
      #|["image","p0",6,["f64:4093d80000000000","f64:40adc40000000000"],0,["f64:407fc00000000000","f64:406fc00000000000"],"alt text","pixelated",null]
      #|["image-resource",1,"svg","d4dc56669143034f31aa309635d4113d9ad76a02b1739da22c965ed2049be9e6",null,["f64:4030000000000000","f64:4020000000000000"],"f64:4058000000000000",null,null,null]
      #|["image","p0",7,["f64:40a3d80000000000","f64:40adc40000000000"],1,["f64:409fc00000000000","f64:408fc00000000000"],null,"auto",null]
      #|["image-resource",2,"pdf","315d429b7714cedb6ad04ac31240145257692630457f3c88253c5beceac76027",1,["f64:4082980000000000","f64:408a500000000000"],"f64:4052000000000000",null,null,null]
      #|["image","p0",8,["f64:40b3d80000000000","f64:40adc40000000000"],2,["f64:4083d80000000000","f64:408bc80000000000"],null,"auto",null]
      #|["link","p0",9,["f64:0000000000000000","f64:40b3d80000000000"],["f64:4093d80000000000","f64:406fc00000000000"],["url","https://typst.app"]]
      #|["link","p0",10,["f64:0000000000000000","f64:40b4d60000000000"],["f64:4093d80000000000","f64:406fc00000000000"],["position",2,["f64:405fc00000000000","f64:406fc00000000000"]]]
      #|["link","p0",11,["f64:0000000000000000","f64:40b5d40000000000"],["f64:4093d80000000000","f64:406fc00000000000"],["location",0]]
      #|["tag-end","p0",12,["f64:0000000000000000","f64:40b8ce0000000000"],0,0,true,false]
      #|["content",2,"text(text: \"Seite\")"]
      #|["page",1,7,["f64:405fc00000000000","f64:406fc00000000000","f64:4077d00000000000","f64:407fc00000000000"],null,"\"1 / 1\"",2]
      #|["frame","p1",["f64:4093d80000000000","f64:4093d80000000000"],null,"soft",0]
      #|["page",2,8,["f64:0000000000000000","f64:0000000000000000","f64:0000000000000000","f64:0000000000000000"],["solid",["Rgb","f32:00000000","f32:3f000000","f32:3f800000","f32:3f800000"]],null,0]
      #|["frame","p2",["f64:4093d80000000000","f64:4093d80000000000"],null,"soft",0]
      #|["end"]
      #|
    ),
  )
}
