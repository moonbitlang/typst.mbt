// Port of the high-level intermediate representation of `regex-syntax`
// (`hir/mod.rs`, `hir/translate.rs`, `unicode.rs`), reduced to Unicode
// scalar value classes (the `regex` crate always requires valid UTF-8, so
// byte classes are restricted to ASCII).

///|
/// A look-around assertion.
priv enum Look {
  Start
  End
  StartLF
  EndLF
  StartCRLF
  EndCRLF
  WordAscii
  WordAsciiNegate
  WordUnicode
  WordUnicodeNegate
  WordStartAscii
  WordEndAscii
  WordStartUnicode
  WordEndUnicode
  WordStartHalfAscii
  WordEndHalfAscii
  WordStartHalfUnicode
  WordEndHalfUnicode
}

///|
/// A set of Unicode scalar values as sorted, non-overlapping, non-adjacent
/// inclusive ranges.
priv struct Class {
  ranges : Array[(Int, Int)]
}

///|
fn Class::new(ranges : Array[(Int, Int)]) -> Class {
  let c = { ranges: ranges.copy(), }
  c.canonicalize()
  c
}

///|
fn Class::canonicalize(self : Class) -> Unit {
  self.ranges.sort_by((a, b) => {
    if a.0 != b.0 {
      a.0.compare(b.0)
    } else {
      a.1.compare(b.1)
    }
  })
  let out : Array[(Int, Int)] = []
  for r in self.ranges {
    match out.last() {
      Some((a, b)) if r.0 <= b + 1 =>
        out[out.length() - 1] = (a, if r.1 > b { r.1 } else { b })
      _ => out.push(r)
    }
  }
  self.ranges.clear()
  self.ranges.append(out)
}

///|
fn Class::union(self : Class, other : Class) -> Unit {
  self.ranges.append(other.ranges)
  self.canonicalize()
}

///|
fn Class::negate(self : Class) -> Unit {
  let out = []
  let mut next = 0
  for r in self.ranges {
    if r.0 > next {
      out.push((next, r.0 - 1))
    }
    next = r.1 + 1
  }
  if next <= 0x10FFFF {
    out.push((next, 0x10FFFF))
  }
  self.ranges.clear()
  self.ranges.append(out)
}

///|
fn Class::intersect(self : Class, other : Class) -> Unit {
  let out = []
  let (a, b) = (self.ranges, other.ranges)
  let mut i = 0
  let mut j = 0
  while i < a.length() && j < b.length() {
    let lo = if a[i].0 > b[j].0 { a[i].0 } else { b[j].0 }
    let hi = if a[i].1 < b[j].1 { a[i].1 } else { b[j].1 }
    if lo <= hi {
      out.push((lo, hi))
    }
    if a[i].1 < b[j].1 {
      i += 1
    } else {
      j += 1
    }
  }
  self.ranges.clear()
  self.ranges.append(out)
}

///|
fn Class::difference(self : Class, other : Class) -> Unit {
  let neg = { ranges: other.ranges.copy(), }
  neg.negate()
  self.intersect(neg)
}

///|
fn Class::symmetric_difference(self : Class, other : Class) -> Unit {
  let inter = { ranges: self.ranges.copy(), }
  inter.intersect(other)
  self.union(other)
  self.difference(inter)
}

///|
/// Add the simple case folding of all chars (upstream `case_fold_simple`).
fn Class::case_fold_simple(self : Class) -> Unit {
  let extra = []
  for r in self.ranges {
    for c in @unicode.chars_with_case_variants(r.0, r.1) {
      let mut x = @unicode.simple_fold_next(c).unwrap()
      while x != c {
        extra.push((x, x))
        x = @unicode.simple_fold_next(x).unwrap()
      }
    }
  }
  self.ranges.append(extra)
  self.canonicalize()
}

///|
/// Add ASCII case folding (upstream `ClassBytes::case_fold_simple`).
fn Class::case_fold_ascii(self : Class) -> Unit {
  let extra = []
  for r in self.ranges {
    let lo = if r.0 > 'a' { r.0 } else { 'a' }
    let hi = if r.1 < 'z' { r.1 } else { 'z' }
    if lo <= hi {
      extra.push((lo - 32, hi - 32))
    }
    let lo = if r.0 > 'A' { r.0 } else { 'A' }
    let hi = if r.1 < 'Z' { r.1 } else { 'Z' }
    if lo <= hi {
      extra.push((lo + 32, hi + 32))
    }
  }
  self.ranges.append(extra)
  self.canonicalize()
}

///|
fn Class::is_ascii(self : Class) -> Bool {
  self.ranges.is_empty() || self.ranges[self.ranges.length() - 1].1 <= 0x7F
}

///|
/// The high-level intermediate representation of a regular expression.
priv enum Hir {
  Empty
  Literal(Array[Int])
  Class(Class)
  Look(Look)
  Repetition(min~ : Int, max~ : Int?, greedy~ : Bool, sub~ : Hir)
  Capture(index~ : Int, sub~ : Hir)
  Concat(Array[Hir])
  Alternation(Array[Hir])
}

///|
/// The minimum length (in chars) of a match, or `None` if the expression
/// can never match.
fn Hir::minimum_len(self : Hir) -> Int? {
  match self {
    Empty | Look(_) => Some(0)
    Literal(cs) => Some(cs.length())
    Class(c) => if c.ranges.is_empty() { None } else { Some(1) }
    Repetition(min~, sub~, ..) =>
      if min == 0 {
        Some(0)
      } else {
        sub.minimum_len().map(n => n * min)
      }
    Capture(sub~, ..) => sub.minimum_len()
    Concat(subs) => {
      let mut total = 0
      for s in subs {
        match s.minimum_len() {
          Some(n) => total += n
          None => return None
        }
      }
      Some(total)
    }
    Alternation(subs) => {
      let mut best : Int? = None
      for s in subs {
        if s.minimum_len() is Some(n) {
          best = Some(
            match best {
              Some(b) => if n < b { n } else { b }
              None => n
            },
          )
        }
      }
      best
    }
  }
}

///|
/// The translation flags (upstream `Flags`).
priv struct HirFlags {
  case_insensitive : Bool?
  multi_line : Bool?
  dot_matches_new_line : Bool?
  swap_greed : Bool?
  unicode : Bool?
  crlf : Bool?
}

///|
fn HirFlags::from_ast(ast : Flags) -> HirFlags {
  let mut f : HirFlags = {
    case_insensitive: None,
    multi_line: None,
    dot_matches_new_line: None,
    swap_greed: None,
    unicode: None,
    crlf: None,
  }
  let mut enable = true
  for item in ast.items {
    match item.kind {
      Negation => enable = false
      Flag('i') => f = { ..f, case_insensitive: Some(enable), }
      Flag('m') => f = { ..f, multi_line: Some(enable), }
      Flag('s') => f = { ..f, dot_matches_new_line: Some(enable), }
      Flag('U') => f = { ..f, swap_greed: Some(enable), }
      Flag('u') => f = { ..f, unicode: Some(enable), }
      Flag('R') => f = { ..f, crlf: Some(enable), }
      Flag(_) => ()
    }
  }
  f
}

///|
fn[T] or_opt(a : T?, b : T?) -> T? {
  match a {
    Some(_) => a
    None => b
  }
}

///|
/// Fill unset flags from `prev`.
fn HirFlags::merge(self : HirFlags, prev : HirFlags) -> HirFlags {
  {
    case_insensitive: or_opt(self.case_insensitive, prev.case_insensitive),
    multi_line: or_opt(self.multi_line, prev.multi_line),
    dot_matches_new_line: or_opt(
      self.dot_matches_new_line,
      prev.dot_matches_new_line,
    ),
    swap_greed: or_opt(self.swap_greed, prev.swap_greed),
    unicode: or_opt(self.unicode, prev.unicode),
    crlf: or_opt(self.crlf, prev.crlf),
  }
}

///|
/// The translator (upstream `TranslatorI`).
priv struct Translator {
  pattern : String
  mut flags : HirFlags
  /// The names of the capture groups, by index.
  names : Array[String?]
}

///|
fn[T] Translator::error(
  self : Translator,
  span : Span,
  kind : HirErrorKind,
) -> T raise RegexError {
  syntax_error(self.pattern, span, None, kind.message())
}

///|
fn Translator::unicode(self : Translator) -> Bool {
  self.flags.unicode.unwrap_or(true)
}

///|
fn Translator::case_insensitive(self : Translator) -> Bool {
  self.flags.case_insensitive.unwrap_or(false)
}

///|
fn Translator::set_flags(self : Translator, ast : Flags) -> HirFlags {
  let old = self.flags
  self.flags = HirFlags::from_ast(ast).merge(old)
  old
}

///|
/// Translate an AST into a HIR.
fn Translator::translate(self : Translator, ast : Ast) -> Hir raise RegexError {
  match ast {
    Empty(_) => Empty
    SetFlags(_, flags) => {
      self.set_flags(flags) |> ignore
      Empty
    }
    Literal(lit) => {
      let c = self.literal_to_scalar(lit)
      match self.case_fold_char(c) {
        Some(h) => h
        None => Literal([c])
      }
    }
    Dot(span) => self.hir_dot(span)
    Assertion(_, kind) => Look(self.hir_assertion(kind))
    ClassPerl(x) =>
      if self.unicode() {
        Class(self.hir_perl_unicode_class(x))
      } else {
        Class(self.hir_perl_byte_class(x))
      }
    ClassUnicode(x) => Class(self.hir_unicode_class(x))
    ClassBracketed(x) => {
      let cls = self.class_set(x.kind)
      self.fold_and_negate(x.span, x.negated, cls)
      Class(cls)
    }
    Repetition(_, kind, greedy, sub) => {
      let sub = self.translate(sub)
      let (min, max) = match kind {
        ZeroOrOne => (0, Some(1))
        ZeroOrMore => (0, None)
        OneOrMore => (1, None)
        Exactly(m) => (m, Some(m))
        AtLeast(m) => (m, None)
        Bounded(m, n) => (m, Some(n))
      }
      let greedy = if self.flags.swap_greed.unwrap_or(false) {
        !greedy
      } else {
        greedy
      }
      if min == 0 && max == Some(0) {
        Empty
      } else if min == 1 && max == Some(1) {
        sub
      } else {
        Repetition(min~, max~, greedy~, sub~)
      }
    }
    Group(g) => {
      let old = match g.kind {
        NonCapturing(flags) => self.set_flags(flags)
        _ => self.flags
      }
      let sub = self.translate(g.ast)
      self.flags = old
      match g.kind {
        CaptureIndex(index) => Capture(index~, sub~)
        CaptureName(name, index) => {
          while self.names.length() <= index {
            self.names.push(None)
          }
          self.names[index] = Some(name)
          Capture(index~, sub~)
        }
        NonCapturing(_) => sub
      }
    }
    Concat(_, asts) => {
      let out = []
      for a in asts {
        match self.translate(a) {
          Empty => ()
          h => out.push(h)
        }
      }
      match out.length() {
        0 => Empty
        1 => out[0]
        _ => Concat(out)
      }
    }
    Alternation(_, asts) => {
      let out = []
      for a in asts {
        out.push(self.translate(a))
      }
      Alternation(out)
    }
  }
}

///|
fn Translator::literal_to_scalar(
  self : Translator,
  lit : Literal,
) -> Int raise RegexError {
  if self.unicode() || !lit.hex_x || lit.c <= 0x7F {
    return lit.c
  }
  // A byte above 0x7F can match invalid UTF-8.
  self.error(lit.span, InvalidUtf8)
}

///|
fn Translator::case_fold_char(self : Translator, c : Int) -> Hir? {
  if !self.case_insensitive() {
    return None
  }
  if self.unicode() {
    if @unicode.simple_fold_next(c) is None {
      return None
    }
    let cls = Class::new([(c, c)])
    cls.case_fold_simple()
    Some(Class(cls))
  } else {
    if !((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')) {
      return None
    }
    let cls = Class::new([(c, c)])
    cls.case_fold_ascii()
    Some(Class(cls))
  }
}

///|
fn Translator::hir_dot(self : Translator, span : Span) -> Hir raise RegexError {
  if !self.unicode() {
    self.error(span, InvalidUtf8)
  }
  if self.flags.dot_matches_new_line.unwrap_or(false) {
    Class(Class::new([(0, 0x10FFFF)]))
  } else if self.flags.crlf.unwrap_or(false) {
    Class(
      Class::new([(0, '\n' - 1), ('\n' + 1, '\r' - 1), ('\r' + 1, 0x10FFFF)]),
    )
  } else {
    Class(Class::new([(0, '\n' - 1), ('\n' + 1, 0x10FFFF)]))
  }
}

///|
fn Translator::hir_assertion(self : Translator, kind : AssertionKind) -> Look {
  let unicode = self.unicode()
  let multi_line = self.flags.multi_line.unwrap_or(false)
  let crlf = self.flags.crlf.unwrap_or(false)
  match kind {
    StartLine =>
      if !multi_line {
        Start
      } else if crlf {
        StartCRLF
      } else {
        StartLF
      }
    EndLine => if !multi_line { End } else if crlf { EndCRLF } else { EndLF }
    StartText => Start
    EndText => End
    WordBoundary => if unicode { WordUnicode } else { WordAscii }
    NotWordBoundary => if unicode { WordUnicodeNegate } else { WordAsciiNegate }
    WordBoundaryStart | WordBoundaryStartAngle =>
      if unicode {
        WordStartUnicode
      } else {
        WordStartAscii
      }
    WordBoundaryEnd | WordBoundaryEndAngle =>
      if unicode {
        WordEndUnicode
      } else {
        WordEndAscii
      }
    WordBoundaryStartHalf =>
      if unicode {
        WordStartHalfUnicode
      } else {
        WordStartHalfAscii
      }
    WordBoundaryEndHalf =>
      if unicode {
        WordEndHalfUnicode
      } else {
        WordEndHalfAscii
      }
  }
}

///|
/// Apply case folding (before!) negation; byte classes must stay ASCII.
fn Translator::fold_and_negate(
  self : Translator,
  span : Span,
  negated : Bool,
  cls : Class,
) -> Unit raise RegexError {
  if self.unicode() {
    if self.case_insensitive() {
      cls.case_fold_simple()
    }
    if negated {
      cls.negate()
    }
  } else {
    if self.case_insensitive() {
      cls.case_fold_ascii()
    }
    if negated {
      // Negate within the byte range.
      cls.negate()
      cls.intersect(Class::new([(0, 0xFF)]))
    }
    if !cls.is_ascii() {
      self.error(span, InvalidUtf8)
    }
  }
}

///|
fn Translator::hir_perl_unicode_class(
  self : Translator,
  x : ClassPerl,
) -> Class {
  ignore(self)
  let cls = Class::new(
    match x.kind {
      Digit => @unicode.perl_digit_ranges()
      Space => @unicode.perl_space_ranges()
      Word => @unicode.perl_word_ranges()
    },
  )
  // The Perl Unicode classes are already closed under simple case folding.
  if x.negated {
    cls.negate()
  }
  cls
}

///|
fn Translator::hir_perl_byte_class(
  self : Translator,
  x : ClassPerl,
) -> Class raise RegexError {
  let name = match x.kind {
    Digit => "digit"
    Space => "space"
    Word => "word"
  }
  let cls = Class::new(ascii_class_ranges(name).unwrap())
  if x.negated {
    cls.negate()
    cls.intersect(Class::new([(0, 0xFF)]))
  }
  if !cls.is_ascii() {
    self.error(x.span, InvalidUtf8)
  }
  cls
}

///|
fn Translator::hir_unicode_class(
  self : Translator,
  x : ClassUnicode,
) -> Class raise RegexError {
  if !self.unicode() {
    self.error(x.span, UnicodeNotAllowed)
  }
  let result = match x.kind {
    OneLetter(c) => unicode_class_binary(c.to_string())
    Named(name) => unicode_class_binary(name)
    NamedValue(name~, value~, ..) => unicode_class_by_value(name, value)
  }
  match result {
    Ok(cls) => {
      self.fold_and_negate(x.span, x.is_negated(), cls)
      cls
    }
    Err(kind) => self.error(x.span, kind)
  }
}

///|
/// Translate a class set (the contents of a bracketed class).
fn Translator::class_set(
  self : Translator,
  set : ClassSet,
) -> Class raise RegexError {
  match set {
    Item(item) => self.class_set_item(item)
    BinaryOp(_, kind, lhs, rhs) => {
      let lhs = self.class_set(lhs)
      let rhs = self.class_set(rhs)
      if self.case_insensitive() {
        if self.unicode() {
          rhs.case_fold_simple()
          lhs.case_fold_simple()
        } else {
          rhs.case_fold_ascii()
          lhs.case_fold_ascii()
        }
      }
      match kind {
        Intersection => lhs.intersect(rhs)
        Difference => lhs.difference(rhs)
        SymmetricDifference => lhs.symmetric_difference(rhs)
      }
      lhs
    }
  }
}

///|
fn Translator::class_set_item(
  self : Translator,
  item : ClassSetItem,
) -> Class raise RegexError {
  match item {
    Empty(_) => Class::new([])
    Literal(lit) => {
      let c = self.class_literal(lit)
      Class::new([(c, c)])
    }
    Range(_, start, end) => {
      let s = self.class_literal(start)
      let e = self.class_literal(end)
      Class::new([(s, e)])
    }
    Ascii(x) => {
      let cls = Class::new(ascii_class_ranges(x.kind).unwrap())
      self.fold_and_negate(x.span, x.negated, cls)
      cls
    }
    Unicode(x) => self.hir_unicode_class(x)
    Perl(x) =>
      if self.unicode() {
        self.hir_perl_unicode_class(x)
      } else {
        self.hir_perl_byte_class(x)
      }
    Bracketed(x) => {
      let cls = self.class_set(x.kind)
      self.fold_and_negate(x.span, x.negated, cls)
      cls
    }
    Union(_, items) => {
      let cls = Class::new([])
      for i in items {
        cls.union(self.class_set_item(i))
      }
      cls
    }
  }
}

///|
fn Translator::class_literal(
  self : Translator,
  lit : Literal,
) -> Int raise RegexError {
  let c = self.literal_to_scalar(lit)
  if !self.unicode() && c > 0x7F {
    // Byte classes don't support Unicode.
    self.error(lit.span, UnicodeNotAllowed)
  }
  c
}

// Unicode property classes (upstream `unicode.rs`).

///|
/// Normalize a symbolic property name (upstream `symbolic_name_normalize`).
fn symbolic_name_normalize(name : String) -> String {
  let mut start = 0
  let mut starts_with_is = false
  if name.length() >= 2 {
    let a = name.code_unit_at(0).to_int()
    let b = name.code_unit_at(1).to_int()
    starts_with_is = (a == 'i' || a == 'I') && (b == 's' || b == 'S')
    if starts_with_is {
      start = 2
    }
  }
  let out = StringBuilder()
  let mut n = 0
  for i in start..<name.length() {
    let b = name.code_unit_at(i).to_int()
    if b == ' ' || b == '_' || b == '-' {
      continue
    } else if b >= 'A' && b <= 'Z' {
      out.write_char((b + 32).unsafe_to_char())
      n += 1
    } else if b <= 0x7F {
      out.write_char(b.unsafe_to_char())
      n += 1
    }
  }
  let s = out.to_string()
  // Special case: `isc` is an alias for the `Other` general category.
  if starts_with_is && n == 1 && s == "c" {
    "isc"
  } else {
    s
  }
}

///|
fn gencat_class(canonical : String) -> Result[Class, HirErrorKind] {
  match canonical {
    "ASCII" => Ok(Class::new([(0, 0x7F)]))
    "Any" => Ok(Class::new([(0, 0x10FFFF)]))
    "Assigned" =>
      match gencat_class("Unassigned") {
        Ok(cls) => {
          cls.negate()
          Ok(cls)
        }
        err => err
      }
    name =>
      match @unicode.general_category_ranges(name) {
        Some(r) => Ok(Class::new(r))
        None => Err(UnicodePropertyValueNotFound)
      }
  }
}

///|
fn canonical_gencat(normalized : String) -> String? {
  match normalized {
    "any" => Some("Any")
    "assigned" => Some("Assigned")
    "ascii" => Some("ASCII")
    _ => @unicode.canonical_general_category(normalized)
  }
}

///|
fn script_class(canonical : String) -> Result[Class, HirErrorKind] {
  match @unicode.script_ranges(canonical) {
    Some(r) => Ok(Class::new(r))
    None => Err(UnicodePropertyValueNotFound)
  }
}

///|
fn bool_property_class(canonical : String) -> Result[Class, HirErrorKind] {
  match canonical {
    "Decimal_Number" => Ok(Class::new(@unicode.perl_digit_ranges()))
    "White_Space" => Ok(Class::new(@unicode.perl_space_ranges()))
    name =>
      match @unicode.bool_property_ranges(name) {
        Some(r) => Ok(Class::new(r))
        None => Err(UnicodePropertyNotFound)
      }
  }
}

///|
/// A binary query: `\pL`, `\p{Greek}`, `\p{Alphabetic}`.
fn unicode_class_binary(name : String) -> Result[Class, HirErrorKind] {
  let norm = symbolic_name_normalize(name)
  // `cf`, `sc` and `lc` are general categories, not properties.
  if norm != "cf" && norm != "sc" && norm != "lc" {
    if @unicode.canonical_property_name(norm) is Some(canon) {
      return bool_property_class(canon)
    }
  }
  if canonical_gencat(norm) is Some(canon) {
    return gencat_class(canon)
  }
  if @unicode.canonical_script(norm) is Some(canon) {
    return script_class(canon)
  }
  Err(UnicodePropertyNotFound)
}

///|
/// A query by value: `\p{gc=Lu}`, `\p{Script=Greek}`.
fn unicode_class_by_value(
  name : String,
  value : String,
) -> Result[Class, HirErrorKind] {
  let name = symbolic_name_normalize(name)
  let value = symbolic_name_normalize(value)
  let canon_name = match @unicode.canonical_property_name(name) {
    Some(c) => c
    None => return Err(UnicodePropertyNotFound)
  }
  match canon_name {
    "General_Category" =>
      match canonical_gencat(value) {
        Some(canon) => gencat_class(canon)
        None => Err(UnicodePropertyValueNotFound)
      }
    "Script" =>
      match @unicode.canonical_script(value) {
        Some(canon) => script_class(canon)
        None => Err(UnicodePropertyValueNotFound)
      }
    "Script_Extensions" =>
      match @unicode.canonical_script(value) {
        Some(canon) =>
          match @unicode.script_extension_ranges(canon) {
            Some(r) => Ok(Class::new(r))
            None => Err(UnicodePropertyValueNotFound)
          }
        None => Err(UnicodePropertyValueNotFound)
      }
    // Not ported: Age and the segmentation properties.
    _ => Err(UnicodePropertyNotFound)
  }
}
