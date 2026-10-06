// Port of the castable value types of `typst-library/src/layout/page.rs`
// (`Margin`, `Binding`, `PageRanges`, `PageRange`, `Parity`, `Paper`) and
// the `PageElem` field hooks.

// PageElem hooks

///|
fn page_elem_init(e : Element) -> Unit {
  // The page constructor is special: It doesn't create a page element.
  // Instead, it just ensures that the passed content lives in a separate
  // page and styles it. Because no element node is produced, `show` rules
  // can't match `page`; use `set` rules instead.
  e.hooks().construct = Some((engine, args) => {
    let styles = e.set_fields(engine, args)
    let body : Content = args.expect("body")
    Content::sequence([
      pagebreak_shared_weak(),
      // We put an effectless, invisible non-tag element on the page. This has
      // two desirable consequences:
      // - The page is kept even if the body is empty
      // - The page doesn't inherit shared styles from the body
      Content::new(flush_elem(), []),
      body,
      pagebreak_shared_boundary(),
    ]).styled_with_map(styles)
  })
}

///|
/// A weak page break (upstream `PagebreakElem::shared_weak`).
fn pagebreak_shared_weak() -> Content {
  Content::new(pagebreak_elem(), []).with_field(pagebreak_elem_weak, Bool(true))
}

///|
/// A weak boundary page break (upstream `PagebreakElem::shared_boundary`).
fn pagebreak_shared_boundary() -> Content {
  pagebreak_shared_weak().with_field(pagebreak_elem_boundary, Bool(true))
}

///|
/// Get the globally shared weak pagebreak element.
pub fn PagebreakElem::shared_weak() -> Content {
  pagebreak_shared_weak()
}

///|
/// Get the globally shared boundary pagebreak element.
pub fn PagebreakElem::shared_boundary() -> Content {
  pagebreak_shared_boundary()
}

///|
fn page_elem_paper_default() -> Value {
  Paper::a4().into_value()
}

///|
fn page_elem_width_default() -> Value {
  (Custom(Length::from_abs(Paper::a4().width())) : Smart[Length]).into_value()
}

///|
fn page_elem_height_default() -> Value {
  (Custom(Length::from_abs(Paper::a4().height())) : Smart[Length]).into_value()
}

///|
fn page_elem_width_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let paper : Paper? = args.named_or_find("paper")
  locals.set("paper", paper.map(paper => paper.into_value()))
  let width : Smart[Length]? = args.named("width")
  match width {
    Some(width) => Some(width.into_value())
    None =>
      paper.map(paper => {
        let width : Smart[Length] = Custom(Length::from_abs(paper.width()))
        width.into_value()
      })
  }
}

///|
fn page_elem_height_parse(
  _engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  let height : Smart[Length]? = args.named("height")
  match height {
    Some(height) => Some(height.into_value())
    None =>
      match locals.get("paper") {
        Some(Str(name)) =>
          Paper::from_name(name).map(paper => {
            let height : Smart[Length] = Custom(
              Length::from_abs(paper.height()),
            )
            height.into_value()
          })
        _ => None
      }
  }
}

///|
fn page_elem_margin_fold(inner : Value, outer : Value) -> Value {
  fold_with((Ty::new() : Ty[Smart[Margin[Smart[Rel[Length]]]]]), inner, outer)
}

///|
fn page_elem_bleed_default() -> Value {
  (Margin::splat(None) : Margin[Rel[Length]]).into_value()
}

// Margin

///|
/// Specification of the page's margins.
pub(all) struct Margin[T] {
  /// The margins for each side.
  sides : Sides[T?]
  /// Whether to swap `left` and `right` to make them `inside` and `outside`
  /// (when to swap depends on the binding).
  two_sided : Bool?
} derive(Eq, Hash, Debug)

///|
/// Create an instance with four equal components.
pub fn[T] Margin::splat(value : T?) -> Margin[T] {
  { sides: Sides::splat(value), two_sided: None, }
}

///|
pub impl[T : Fold] Fold for Margin[T] with fn fold(self, outer) {
  {
    sides: self.sides.fold(outer.sides),
    two_sided: Fold::fold(self.two_sided, outer.two_sided),
  }
}

///|
pub impl[T : Reflect] Reflect for Margin[T] with fn input() {
  T::input().union_with(Type(Type::dict()))
}

///|
pub impl[T : Reflect] Reflect for Margin[T] with fn output() {
  T::input().union_with(Type(Type::dict()))
}

///|
pub impl[T : Reflect] Reflect for Margin[T] with fn castable(value) {
  T::castable(value) || value is Dict(_)
}

///|
pub impl[T : IntoValue + Eq] IntoValue for Margin[T] with fn into_value(self) {
  let two_sided = self.two_sided.unwrap_or(false)
  if !two_sided && self.sides.is_uniform() && self.sides.left is Some(left) {
    return IntoValue::into_value(left)
  }
  let dict = Dict::new()
  let handle = (key : String, component : T?) => {
    if component is Some(c) {
      dict.insert(key, IntoValue::into_value(c))
    }
  }
  handle("top", self.sides.top)
  handle("bottom", self.sides.bottom)
  if two_sided {
    handle("inside", self.sides.left)
    handle("outside", self.sides.right)
  } else {
    handle("left", self.sides.left)
    handle("right", self.sides.right)
  }
  Dict(dict)
}

///|
pub impl[T : FromValue] FromValue for Margin[T] with fn from_value(value) {
  if castable_of((Ty::new() : Ty[T]), value) {
    let v = T::from_value(value)
    return Margin::splat(Some(v))
  }
  if value is Dict(dict) {
    let dict = dict.copy()
    let take : (String) -> T? raise HintedError = key => {
      dict_take_cast(dict, key)
    }
    let rest = take("rest")
    let x = take("x") |> opt_or(rest)
    let y = take("y") |> opt_or(rest)
    let top = take("top") |> opt_or(y)
    let bottom = take("bottom") |> opt_or(y)
    let outside = take("outside")
    let inside = take("inside")
    let left = take("left")
    let right = take("right")
    let implicitly_two_sided = outside is Some(_) || inside is Some(_)
    let implicitly_not_two_sided = left is Some(_) || right is Some(_)
    if implicitly_two_sided && implicitly_not_two_sided {
      bail(
        "`inside` and `outside` are mutually exclusive with `left` and `right`",
      )
    }

    // - If 'implicitly_two_sided' is false here, then
    //   'implicitly_not_two_sided' will be guaranteed to be true
    //    due to the previous two 'if' conditions.
    // - If both are false, this means that this margin change does not
    //   affect lateral margins, and thus shouldn't make a difference on
    //   the 'two_sided' attribute of this margin.
    let two_sided = if implicitly_two_sided || implicitly_not_two_sided {
      Some(implicitly_two_sided)
    } else {
      None
    }
    dict.finish([
      "left", "top", "right", "bottom", "outside", "inside", "x", "y", "rest",
    ])
    return {
      sides: {
        left: inside |> opt_or(left) |> opt_or(x),
        top,
        right: outside |> opt_or(right) |> opt_or(x),
        bottom,
      },
      two_sided,
    }
  }
  raise HintedError(
    input_of((Ty::new() : Ty[T])).union_with(Type(Type::dict())).error(value),
  )
}

// Binding

///|
/// Specification of the page's binding (upstream `Binding`).
pub(all) enum PageBinding {
  /// Bound on the left, as customary in LTR languages.
  Left
  /// Bound on the right, as customary in RTL languages.
  Right
} derive(Eq, Hash, Debug)

///|
/// Whether to swap left and right margin for the page with this number.
pub fn PageBinding::swap(self : PageBinding, number : Int) -> Bool {
  match self {
    // Left-bound must swap on even pages
    // (because it is correct on the first page).
    Left => number % 2 == 0
    // Right-bound must swap on odd pages
    // (because it is wrong on the first page).
    Right => number % 2 == 1
  }
}

///|
pub impl Reflect for PageBinding with fn input() {
  Type(Type::alignment())
}

///|
pub impl Reflect for PageBinding with fn output() {
  Type(Type::alignment())
}

///|
pub impl Reflect for PageBinding with fn castable(v) {
  v is Dyn(Alignment(_))
}

///|
pub impl IntoValue for PageBinding with fn into_value(self) {
  match self {
    Left => Dyn(Alignment(alignment_left))
    Right => Dyn(Alignment(alignment_right))
  }
}

///|
pub impl FromValue for PageBinding with fn from_value(v) {
  match v {
    Dyn(Alignment(H(Left))) => Left
    Dyn(Alignment(H(Right))) => Right
    Dyn(Alignment(_)) => bail("must be `left` or `right`")
    v => raise HintedError(PageBinding::input().error(v))
  }
}

// PageRanges

///|
/// A list of page ranges to be exported.
pub(all) struct PageRanges(Array[PageRange]) derive(Eq, Hash, Debug)

///|
pub impl Reflect for PageRanges with fn input() {
  PageRange::input().union_with(Type(Type::array()))
}

///|
pub impl Reflect for PageRanges with fn output() {
  PageRanges::input()
}

///|
pub impl Reflect for PageRanges with fn castable(v) {
  PageRange::castable(v) || v is Array(_)
}

///|
pub impl IntoValue for PageRanges with fn into_value(self) {
  Array(Arr::from_array(self.0.map(range => range.into_value())))
}

///|
pub impl FromValue for PageRanges with fn from_value(v) {
  if PageRange::castable(v) {
    return PageRanges([PageRange::from_value(v)])
  }
  match v {
    Array(array) => PageRanges(array.items.map(v => PageRange::from_value(v)))
    v => raise HintedError(PageRanges::input().error(v))
  }
}

///|
/// Check if a page, given its number, should be included when exporting
/// the document while restricting the exported pages to these page ranges.
pub fn PageRanges::includes_page(self : PageRanges, page : Int) -> Bool {
  self.0
  .iter()
  .any(range => {
    match (range.start, range.end) {
      (Some(start), Some(end)) => start <= page && page <= end
      (Some(start), None) => start <= page
      (None, Some(end)) => page <= end
      (None, None) => true
    }
  })
}

///|
/// A range of pages to export.
///
/// The range is one-indexed. For example, `1..=3` indicates the first,
/// second and third pages should be exported.
pub(all) struct PageRange {
  start : Int?
  end : Int?
} derive(Eq, Hash, Debug)

///|
pub impl Reflect for PageRange with fn input() {
  CastInfo::Type(Type::int()).union_with(Type(Type::dict()))
}

///|
pub impl Reflect for PageRange with fn output() {
  PageRange::input()
}

///|
pub impl Reflect for PageRange with fn castable(v) {
  v is (Int(_) | Dict(_))
}

///|
pub impl IntoValue for PageRange with fn into_value(self) {
  let nr = (n : Int?) => {
    match n {
      Some(n) => Value::Int(n.to_int64())
      None => Value::None
    }
  }
  Dict(Dict::from_pairs([("from", nr(self.start)), ("to", nr(self.end))]))
}

///|
pub impl FromValue for PageRange with fn from_value(v) {
  match v {
    Int(nr) => {
      let nr = parse_page_number(nr)
      { start: Some(nr), end: Some(nr), }
    }
    Dict(dict) => {
      let dict = dict.copy()
      let parse_nr : (String) -> Int? raise HintedError = key => {
        if dict.contains(key) {
          let nr : Int64 = FromValue::from_value(dict.take(key))
          Some(parse_page_number(nr))
        } else {
          None
        }
      }
      let start = parse_nr("from")
      let end = parse_nr("to")
      dict.finish(["from", "to"])
      if start is None && end is None {
        bail("page range must not be empty")
      }
      if start is Some(s) && end is Some(e) && s > e {
        bail("start of page range cannot be larger than end")
      }
      { start, end, }
    }
    v => raise HintedError(PageRange::input().error(v))
  }
}

///|
fn parse_page_number(nr : Int64) -> Int raise HintedError {
  if nr < 1L {
    bail("page numbers start at one")
  }
  if nr > 0x7FFFFFFFL {
    bail("not a valid page number")
  }
  nr.to_int()
}

// Parity

///|
/// Whether something should be even or odd.
pub(all) enum Parity {
  /// Next page will be an even page.
  Even
  /// Next page will be an odd page.
  Odd
} derive(Eq, Hash, Debug)

///|
let parity_names : ReadOnlyArray[String] = ["even", "odd"]

///|
pub impl Reflect for Parity with fn input() {
  str_names_input(parity_names)
}

///|
pub impl Reflect for Parity with fn output() {
  Parity::input()
}

///|
pub impl Reflect for Parity with fn castable(v) {
  str_names_find(parity_names, v) is Some(_)
}

///|
pub impl IntoValue for Parity with fn into_value(self) {
  match self {
    Even => Str("even")
    Odd => Str("odd")
  }
}

///|
pub impl FromValue for Parity with fn from_value(v) {
  match str_names_find(parity_names, v) {
    Some(0) => Even
    Some(_) => Odd
    None => raise HintedError(Parity::input().error(v))
  }
}

///|
/// Whether the given number matches the parity.
pub fn Parity::matches(self : Parity, number : Int) -> Bool {
  match self {
    Even => number % 2 == 0
    Odd => number % 2 == 1
  }
}

// Paper

///|
/// Specification of a paper.
pub(all) struct Paper {
  /// The name of the paper.
  name : String
  /// The width of the paper in millimeters.
  width : Double
  /// The height of the paper in millimeters.
  height : Double
} derive(Eq, Hash, Debug)

///|
/// The width of the paper.
pub fn Paper::width(self : Paper) -> Abs {
  Abs::mm(self.width)
}

///|
/// The height of the paper.
pub fn Paper::height(self : Paper) -> Abs {
  Abs::mm(self.height)
}

///|
/// The A4 paper.
pub fn Paper::a4() -> Paper {
  { name: "a4", width: 210.0, height: 297.0, }
}

///|
/// The paper with the given name (as matched by the cast).
pub fn Paper::from_name(name : String) -> Paper? {
  for p in papers[:] {
    if p.0 == name {
      return Some({ name: p.0, width: p.1, height: p.2, })
    }
  }
  None
}

///|
pub impl Reflect for Paper with fn input() {
  str_names_input(papers.map(p => p.0))
}

///|
pub impl Reflect for Paper with fn output() {
  Paper::input()
}

///|
pub impl Reflect for Paper with fn castable(v) {
  v is Str(name) && Paper::from_name(name) is Some(_)
}

///|
pub impl IntoValue for Paper with fn into_value(self) {
  Str(self.name)
}

///|
pub impl FromValue for Paper with fn from_value(v) {
  if v is Str(name) && Paper::from_name(name) is Some(paper) {
    return paper
  }
  raise HintedError(Paper::input().error(v))
}

///|
// All paper sizes in mm.
//
// Resources:
// - https://papersizes.io/
// - https://en.wikipedia.org/wiki/Paper_size
// - https://www.theedkins.co.uk/jo/units/oldunits/print.htm
// - https://vintagepaper.co/blogs/news/traditional-paper-sizes
let papers : ReadOnlyArray[(String, Double, Double)] = [
  // ISO 216 A Series
  ("a0", 841.0, 1189.0),
  ("a1", 594.0, 841.0),
  ("a2", 420.0, 594.0),
  ("a3", 297.0, 420.0),
  ("a4", 210.0, 297.0),
  ("a5", 148.0, 210.0),
  ("a6", 105.0, 148.0),
  ("a7", 74.0, 105.0),
  ("a8", 52.0, 74.0),
  ("a9", 37.0, 52.0),
  ("a10", 26.0, 37.0),
  ("a11", 18.0, 26.0),
  // ISO 216 B Series
  ("iso-b1", 707.0, 1000.0),
  ("iso-b2", 500.0, 707.0),
  ("iso-b3", 353.0, 500.0),
  ("iso-b4", 250.0, 353.0),
  ("iso-b5", 176.0, 250.0),
  ("iso-b6", 125.0, 176.0),
  ("iso-b7", 88.0, 125.0),
  ("iso-b8", 62.0, 88.0),
  // ISO 216 C Series
  ("iso-c3", 324.0, 458.0),
  ("iso-c4", 229.0, 324.0),
  ("iso-c5", 162.0, 229.0),
  ("iso-c6", 114.0, 162.0),
  ("iso-c7", 81.0, 114.0),
  ("iso-c8", 57.0, 81.0),
  // DIN D Series (extension to ISO)
  ("din-d3", 272.0, 385.0),
  ("din-d4", 192.0, 272.0),
  ("din-d5", 136.0, 192.0),
  ("din-d6", 96.0, 136.0),
  ("din-d7", 68.0, 96.0),
  ("din-d8", 48.0, 68.0),
  // SIS (used in academia)
  ("sis-g5", 169.0, 239.0),
  ("sis-e5", 115.0, 220.0),
  // ANSI Extensions
  ("ansi-a", 216.0, 279.0),
  ("ansi-b", 279.0, 432.0),
  ("ansi-c", 432.0, 559.0),
  ("ansi-d", 559.0, 864.0),
  ("ansi-e", 864.0, 1118.0),
  // ANSI Architectural Paper
  ("arch-a", 229.0, 305.0),
  ("arch-b", 305.0, 457.0),
  ("arch-c", 457.0, 610.0),
  ("arch-d", 610.0, 914.0),
  ("arch-e1", 762.0, 1067.0),
  ("arch-e", 914.0, 1219.0),
  // JIS B Series
  ("jis-b0", 1030.0, 1456.0),
  ("jis-b1", 728.0, 1030.0),
  ("jis-b2", 515.0, 728.0),
  ("jis-b3", 364.0, 515.0),
  ("jis-b4", 257.0, 364.0),
  ("jis-b5", 182.0, 257.0),
  ("jis-b6", 128.0, 182.0),
  ("jis-b7", 91.0, 128.0),
  ("jis-b8", 64.0, 91.0),
  ("jis-b9", 45.0, 64.0),
  ("jis-b10", 32.0, 45.0),
  ("jis-b11", 22.0, 32.0),
  // SAC D Series
  ("sac-d0", 764.0, 1064.0),
  ("sac-d1", 532.0, 760.0),
  ("sac-d2", 380.0, 528.0),
  ("sac-d3", 264.0, 376.0),
  ("sac-d4", 188.0, 260.0),
  ("sac-d5", 130.0, 184.0),
  ("sac-d6", 92.0, 126.0),
  // ISO 7810 ID
  ("iso-id-1", 85.6, 53.98),
  ("iso-id-2", 74.0, 105.0),
  ("iso-id-3", 88.0, 125.0),
  // Asia
  ("asia-f4", 210.0, 330.0),
  // Japan
  ("jp-shiroku-ban-4", 264.0, 379.0),
  ("jp-shiroku-ban-5", 189.0, 262.0),
  ("jp-shiroku-ban-6", 127.0, 188.0),
  ("jp-kiku-4", 227.0, 306.0),
  ("jp-kiku-5", 151.0, 227.0),
  ("jp-business-card", 91.0, 55.0),
  // China
  ("cn-business-card", 90.0, 54.0),
  // Europe
  ("eu-business-card", 85.0, 55.0),
  // French Traditional (AFNOR)
  ("fr-tellière", 340.0, 440.0),
  ("fr-couronne-écriture", 360.0, 460.0),
  ("fr-couronne-édition", 370.0, 470.0),
  ("fr-raisin", 500.0, 650.0),
  ("fr-carré", 450.0, 560.0),
  ("fr-jésus", 560.0, 760.0),
  // United Kingdom Imperial
  ("uk-brief", 406.4, 342.9),
  ("uk-draft", 254.0, 406.4),
  ("uk-foolscap", 203.2, 330.2),
  ("uk-quarto", 203.2, 254.0),
  ("uk-crown", 508.0, 381.0),
  ("uk-book-a", 111.0, 178.0),
  ("uk-book-b", 129.0, 198.0),
  // Unites States
  ("us-letter", 215.9, 279.4),
  ("us-legal", 215.9, 355.6),
  ("us-tabloid", 279.4, 431.8),
  ("us-executive", 184.15, 266.7),
  ("us-foolscap-folio", 215.9, 342.9),
  ("us-statement", 139.7, 215.9),
  ("us-ledger", 431.8, 279.4),
  ("us-oficio", 215.9, 340.36),
  ("us-gov-letter", 203.2, 266.7),
  ("us-gov-legal", 215.9, 330.2),
  ("us-business-card", 88.9, 50.8),
  ("us-digest", 139.7, 215.9),
  ("us-trade", 152.4, 228.6),
  // Other
  ("newspaper-compact", 280.0, 430.0),
  ("newspaper-berliner", 315.0, 470.0),
  ("newspaper-broadsheet", 381.0, 578.0),
  ("presentation-16-9", 297.0, 167.0625),
  ("presentation-4-3", 280.0, 210.0),
]

///|
/// Upstream `LocalName for PageElem`.
fn page_elem_local_name_key() -> String {
  "page"
}
