// The `render` stage (see `oracle/src/render.rs`): compile every paged test
// (same selection as the `paged` stage) and render it like the upstream test
// harness does (`tests/src/output.rs`, `fn render`): `render_merged` at 1
// pixel per point with a 1pt black gap between pages, plus translucent boxes
// for links.
//
// # Comparison
//
// The goldens hold the size and the SHA-256 of the premultiplied RGBA data
// of upstream's pixmap (byte-exact parity). Additionally, like the upstream
// harness (`run.rs`, `check_file_ref`), the pixmap is compared against the
// reference PNG in `tests/ref/render/<name>.png` with a per-byte tolerance
// (`tolerance(n)` attribute, default 1).

///|
let render_ref_dir = ".repos/typst/tests/ref/render"

///|
/// Counters of the comparison against the reference PNGs:
/// (refs compared, matching within tolerance, missing refs for rendered
/// documents).
let render_ref_stats : Ref[(Int, Int, Int)] = Ref::new((0, 0, 0))

///|
/// Names of the tests whose rendering differs from the reference PNG.
let render_ref_failures : Array[String] = []

///|
/// Optional directory to write the raw premultiplied RGBA data of every
/// rendered test to (`--raw=<dir>`), for comparison with the oracle's
/// `ORACLE_RENDER_RAW` output.
let render_raw_dir : Ref[String?] = Ref::new(None)

///|
/// Compile a single test case, render it and compare with the reference.
fn render_report(rel : String, tc : TestCase) -> String {
  let source = TestWorld::main_source("tests/suite/" + rel, tc.body)
  let library = test_library()
  let library = match parse_features(tc.attrs) {
    Some(f) => { ..library, features: f, }
    None => library
  }
  let world : TestWorld = { main: source, library, }
  let warned : @library.Warned[
    Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
  ] = @typst.compile(world)
  match warned.output {
    Ok(doc) => {
      guard harness_render(doc, 1.0) is Some(pixmap) else { return "<panic>\n" }
      if render_raw_dir.val is Some(dir) {
        let out = "\{dir}/\{tc.name}.rgba"
        ensure_parent_dir(out)
        @fs.write_bytes_to_file(out, pixmap.data()) catch {
          _ => ()
        }
      }
      compare_render_ref(tc, pixmap)
      "\{pixmap.width()}x\{pixmap.height()} \{sha256_hex(pixmap.data()[:])}\n"
    }
    Err(_) => "<error>\n"
  }
}

///|
/// Compares the pixmap with the reference PNG like `Render::matches`.
fn compare_render_ref(tc : TestCase, pixmap : @skia.Pixmap) -> Unit {
  let path = "\{render_ref_dir}/\{tc.name}.png"
  let data = @fs.read_file_to_bytes(path) catch {
    _ => {
      let (n, ok, missing) = render_ref_stats.val
      render_ref_stats.val = (n, ok, missing + 1)
      return
    }
  }
  let tolerance = render_tolerance(tc.attrs)
  let ok = match (try? @skia.Pixmap::decode_png(data[:])) {
    Ok(old) => approx_equal(old, pixmap, tolerance)
    Err(_) => false
  }
  let (n, oks, missing) = render_ref_stats.val
  render_ref_stats.val = (n + 1, if ok { oks + 1 } else { oks }, missing)
  if !ok {
    render_ref_failures.push(tc.name)
  }
}

///|
/// The `tolerance(n)` attribute of a test (default 1).
fn render_tolerance(attrs : String) -> Int {
  for a in attrs.split(" ") {
    if a.has_prefix("tolerance(") && a.has_suffix(")") {
      let s = a.to_string()
      let v = s.substring(start=10, end=s.length() - 1)
      return @string.parse_int(v) catch { _ => 1 }
    }
  }
  1
}

///|
/// Whether two pixel images are approximately equal.
fn approx_equal(a : @skia.Pixmap, b : @skia.Pixmap, tolerance : Int) -> Bool {
  if a.width() != b.width() || a.height() != b.height() {
    return false
  }
  let pa = a.pixels()
  let pb = b.pixels()
  for i in 0..<pa.length() {
    let x = pa[i]
    let y = pb[i]
    if x != y {
      for k in 0..<4 {
        let c0 = ((x >> (8 * k)) & 0xFF).reinterpret_as_int()
        let c1 = ((y >> (8 * k)) & 0xFF).reinterpret_as_int()
        if (c0 - c1).abs() > tolerance {
          return false
        }
      }
    }
  }
  true
}

///|
/// Draw all frames into one image with padding in between (upstream
/// `tests/src/output.rs`, `fn render`). Returns `None` for an overlarge frame
/// (upstream panics).
fn harness_render(
  document : @layout.PagedDocument,
  pixel_per_pt : Float,
) -> @skia.Pixmap? {
  for page in document.pages() {
    let limit = @library.Abs::cm(100.0)
    if page.frame.width() > limit || page.frame.height() > limit {
      return None
    }
  }
  let gap = @library.Abs::pt(1.0)
  let ppi = pixel_per_pt * 72.0
  let opts : @render.RenderOptions = {
    format: { ppi: Some(ppi.to_double()) },
    render_bleed: false,
  }
  let pixmap = @render.render_merged(document, opts, gap, Some(@library.color_black))
  let gap = @skpath.roundf(pixel_per_pt * gap.to_pt().to_float())
  let mut y : Float = 0.0
  for page in document.pages() {
    let ts = @skpath.Transform::from_scale(pixel_per_pt, pixel_per_pt).post_translate(
      0.0, y,
    )
    render_links(pixmap, ts, page.frame)
    y += @skpath.fmax(
      @skpath.roundf(pixel_per_pt * page.frame.height().to_pt().to_float()),
      1.0,
    ) +
      gap
  }
  Some(pixmap)
}

///|
/// Draw extra boxes for links so we can see whether they are there.
fn render_links(
  canvas : @skia.Pixmap,
  ts : @skpath.Transform,
  frame : @library.Frame,
) -> Unit {
  for entry in frame.items() {
    let (pos, item) = entry
    let ts = ts.pre_translate(pos.x.to_pt().to_float(), pos.y.to_pt().to_float())
    match item {
      Group(group) => {
        let ts = ts.pre_concat(harness_sk_transform(group.transform))
        render_links(canvas, ts, group.frame)
      }
      Link(_, size) => {
        let w = size.x.to_pt().to_float()
        let h = size.y.to_pt().to_float()
        let rect = @skpath.Rect::from_xywh(0.0, 0.0, w, h).unwrap()
        let paint = @skia.Paint::default()
        paint.set_color_rgba8(40, 54, 99, 40)
        canvas.fill_rect(rect, paint, ts, None)
      }
      _ => ()
    }
  }
}

///|
/// Convert a Typst transform to a tiny-skia transform.
fn harness_sk_transform(transform : @library.Transform) -> @skpath.Transform {
  @skpath.Transform::from_row(
    transform.sx.get().to_float(),
    transform.ky.get().to_float(),
    transform.kx.get().to_float(),
    transform.sy.get().to_float(),
    transform.tx.to_pt().to_float(),
    transform.ty.to_pt().to_float(),
  )
}

///|
/// Prints the comparison with the reference PNGs.
fn report_render_refs(verbose : Bool) -> Unit {
  let (n, ok, missing) = render_ref_stats.val
  if verbose {
    for name in render_ref_failures {
      println("REF-FAIL \{name}")
    }
  }
  println(
    "render: \{ok}/\{n} match the reference PNGs (\{missing} rendered without reference)",
  )
}
