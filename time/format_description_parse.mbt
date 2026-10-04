// Port of `time/src/format_description/parse/{mod,lexer_ast,format_item}.rs`
// (the version 2 code paths only).
//
// All locations are UTF-8 byte offsets into the input, as upstream.

///|
/// Parse a sequence of items from the format description (version 2).
///
/// Port of `format_description::parse_borrowed::<2>`. Optional and `first`
/// items are not supported by this function.
pub fn parse_borrowed_v2(
  s : String,
) -> Array[FormatItem] raise InvalidFormatDescription {
  let lexer = Lexer::new(s, owned=false)
  let items = []
  while !lexer.is_empty() {
    items.push(lexer.parse_next_item())
  }
  items
}

///|
/// Parse a sequence of items from the format description (version 2) into a
/// single owned item.
///
/// Port of `format_description::parse_owned::<2>`.
pub fn parse_owned_v2(s : String) -> FormatItem raise InvalidFormatDescription {
  let lexer = Lexer::new(s, owned=true)
  let items = []
  while !lexer.is_empty() {
    items.push(lexer.parse_next_item())
  }
  items_to_owned_format_item(items)
}

///|
fn items_to_owned_format_item(items : Array[FormatItem]) -> FormatItem {
  match items {
    [item] => item
    items => Compound(items)
  }
}

///|
/// A slice of the input with its location (`Spanned<&str>`).
priv struct Token {
  value : String
  /// The byte offset of the start of the token.
  start : Int
}

///|
priv struct Modifier {
  key : String
  /// The byte offset of the key.
  key_location : Int
  value : String
}

///|
/// `Modifier::value_span().start`.
fn Modifier::value_start(self : Modifier) -> Int {
  self.key_location + utf8_len(self.key) + 1
}

///|
priv struct Modifiers {
  modifiers : Array[Modifier]
  trailing_whitespace : Token?
}

///|
priv struct NestedFormatDescription {
  mut leading_whitespace : Token?
  opening_bracket : Int
  items : Array[FormatItem]
}

///|
priv enum NextModifier {
  Modifier(Modifier)
  TrailingWhitespace(Token)
  NoModifier
}

///|
priv struct Lexer {
  /// The input characters.
  chars : Array[Char]
  /// `offsets[i]` is the byte offset of `chars[i]`; the last entry is the
  /// total byte length.
  offsets : Array[Int]
  /// The index of the next character.
  mut pos : Int
  /// The nesting depth (a `u8` upstream).
  mut depth : Int
  /// Whether the output is owned (`parse_owned`) or borrowed
  /// (`parse_borrowed`).
  owned : Bool
}

///|
fn utf8_char_len(c : Char) -> Int {
  let c = c.to_int()
  if c < 0x80 {
    1
  } else if c < 0x800 {
    2
  } else if c < 0x10000 {
    3
  } else {
    4
  }
}

///|
fn utf8_len(s : String) -> Int {
  let mut len = 0
  for c in s {
    len += utf8_char_len(c)
  }
  len
}

///|
fn Lexer::new(s : String, owned~ : Bool) -> Lexer {
  let chars = s.to_array()
  let offsets = []
  let mut off = 0
  for c in chars {
    offsets.push(off)
    off += utf8_char_len(c)
  }
  offsets.push(off)
  { chars, offsets, pos: 0, depth: 0, owned, }
}

///|
fn Lexer::is_empty(self : Lexer) -> Bool {
  self.pos >= self.chars.length()
}

///|
/// The byte position of the lexer.
fn Lexer::byte_pos(self : Lexer) -> Int {
  self.offsets[self.pos]
}

///|
fn Lexer::peek(self : Lexer, ahead : Int) -> Char? {
  self.chars.get(self.pos + ahead)
}

///|
fn Lexer::slice(self : Lexer, start : Int, end : Int) -> String {
  String::from_array(self.chars[start:end])
}

///|
fn Lexer::is_literal_context(self : Lexer) -> Bool {
  self.depth % 2 == 0
}

///|
/// `u8::is_ascii_whitespace`.
fn is_ascii_whitespace(c : Char) -> Bool {
  c is (' ' | '\t' | '\n' | '\u{0C}' | '\r')
}

///|
fn Lexer::consume_whitespace(self : Lexer) -> Token? {
  let start = self.pos
  let mut end = start
  while end < self.chars.length() && is_ascii_whitespace(self.chars[end]) {
    end += 1
  }
  if end == start {
    return None
  }
  let token = { value: self.slice(start, end), start: self.offsets[start], }
  self.pos = end
  Some(token)
}

///|
fn Lexer::consume_component_part(self : Lexer) -> Token? {
  let start = self.pos
  let mut end = start
  while end < self.chars.length() &&
        !is_ascii_whitespace(self.chars[end]) &&
        !(self.chars[end] is ('\\' | '[' | ']')) {
    end += 1
  }
  if end == start {
    return None
  }
  let token = { value: self.slice(start, end), start: self.offsets[start], }
  self.pos = end
  Some(token)
}

///|
fn Lexer::consume_closing_bracket(self : Lexer) -> Int? {
  if self.peek(0) != Some(']') {
    return None
  }
  self.depth = (self.depth - 1) & 0xFF
  let location = self.byte_pos()
  self.pos += 1
  Some(location)
}

///|
fn Lexer::consume_component_name(
  self : Lexer,
  opening_bracket : Int,
) -> Token raise InvalidFormatDescription {
  let leading_whitespace = self.consume_whitespace() is Some(_)
  guard self.consume_component_part() is Some(name) else {
    let location = if leading_whitespace {
      opening_bracket + 1
    } else {
      opening_bracket
    }
    raise MissingComponentName(index=location)
  }
  name
}

///|
fn Lexer::consume_modifier(
  self : Lexer,
) -> NextModifier raise InvalidFormatDescription {
  guard self.consume_whitespace() is Some(whitespace) else { return NoModifier }
  guard self.consume_component_part() is Some(token) else {
    return TrailingWhitespace(whitespace)
  }
  Modifier(modifier_from_token(token))
}

///|
fn Lexer::parse_modifiers(
  self : Lexer,
) -> Modifiers raise InvalidFormatDescription {
  let modifiers = []
  for ;; {
    match self.consume_modifier() {
      Modifier(modifier) => modifiers.push(modifier)
      TrailingWhitespace(whitespace) =>
        return { modifiers, trailing_whitespace: Some(whitespace), }
      NoModifier => return { modifiers, trailing_whitespace: None, }
    }
  }
}

///|
fn Lexer::consume_component(
  self : Lexer,
  opening_bracket : Int,
) -> FormatItem raise InvalidFormatDescription {
  if self.depth + 1 > 255 {
    raise NotSupported(
      what="highly-nested format description",
      context="",
      index=opening_bracket,
    )
  }
  self.depth += 1
  // consume the opening bracket, which was checked prior to calling this method
  self.pos += 1
  let name = self.consume_component_name(opening_bracket)
  let modifiers = self.parse_modifiers()
  let nested_format_descriptions : Array[NestedFormatDescription] = []
  while self.is_nested_description_start() {
    let description = self.consume_nested() catch { _ => break }
    nested_format_descriptions.push(description)
  }
  if modifiers.trailing_whitespace is Some(_) &&
    nested_format_descriptions.get(0) is Some(first_nested) {
    first_nested.leading_whitespace = modifiers.trailing_whitespace
  }
  if modifiers.trailing_whitespace is None ||
    !nested_format_descriptions.is_empty() {
    ignore(self.consume_whitespace())
  }
  guard self.consume_closing_bracket() is Some(closing_bracket) else {
    raise UnclosedOpeningBracket(index=opening_bracket)
  }
  if nested_format_descriptions.get(0) is Some(first_nested_fd) &&
    first_nested_fd.leading_whitespace is None {
    raise Expected(
      what="whitespace before nested format description",
      index=first_nested_fd.opening_bracket,
    )
  }
  if ident_eq(name.value, "optional") {
    let format = parse_optional_format_modifier(modifiers.modifiers)
    let nested_format_description = match nested_format_descriptions {
      [nested_format_description] => nested_format_description
      [second_fd, ..] =>
        raise NotSupported(
          what="more than one nested format description",
          context="`optional` components",
          index=second_fd.opening_bracket,
        )
      [] =>
        raise Expected(what="nested format description", index=closing_bracket)
    }
    return self.optional(
      nested_format_description.items,
      format,
      opening_bracket,
    )
  }
  if ident_eq(name.value, "first") {
    if modifiers.modifiers.get(0) is Some(modifier) {
      raise InvalidModifier(value=modifier.key, index=modifier.key_location)
    }
    let items = nested_format_descriptions.map(d => d.items)
    return self.first(items, opening_bracket)
  }
  if !nested_format_descriptions.is_empty() {
    raise NotSupported(
      what="nested format descriptions",
      context="on this component",
      index=opening_bracket,
    )
  }
  Component(component_from_ast(name, modifiers.modifiers))
}

///|
/// `ParseTarget::optional`.
fn Lexer::optional(
  self : Lexer,
  value : Array[FormatItem],
  format : Bool,
  span_start : Int,
) -> FormatItem raise InvalidFormatDescription {
  if !self.owned {
    raise NotSupported(
      what="optional item",
      context="runtime-parsed format descriptions",
      index=span_start,
    )
  }
  if !format {
    raise NotSupported(
      what="optional item with `format:false`",
      context="v1 and v2 format descriptions",
      index=span_start,
    )
  }
  Optional(items_to_owned_format_item(value))
}

///|
/// `ParseTarget::first`.
fn Lexer::first(
  self : Lexer,
  value : Array[Array[FormatItem]],
  span_start : Int,
) -> FormatItem raise InvalidFormatDescription {
  if !self.owned {
    raise NotSupported(
      what="'first' item",
      context="runtime-parsed format descriptions",
      index=span_start,
    )
  }
  First(value.map(items_to_owned_format_item))
}

///|
fn Lexer::consume_nested(
  self : Lexer,
) -> NestedFormatDescription raise InvalidFormatDescription {
  let leading_whitespace = self.consume_whitespace()
  if self.depth + 1 > 255 {
    // The location is that of the end of the last modifier upstream; this
    // error is always swallowed by `consume_component`.
    raise NotSupported(
      what="highly-nested format description",
      context="",
      index=-1,
    )
  }
  self.depth += 1
  let opening_bracket = self.byte_pos()
  self.pos += 1
  let items = []
  while !self.is_empty() {
    // If we're in a literal context and the next byte is a closing bracket, stop so that we
    // can consume it.
    if self.is_literal_context() && self.peek(0) == Some(']') {
      break
    }
    items.push(self.parse_next_item())
  }
  guard self.consume_closing_bracket() is Some(_) else {
    // The opening bracket consumed above incremented `self.depth` but was never matched by
    // a closing bracket. `consume_component` swallows this error and then re-derives the
    // outer "unclosed bracket" error itself, so we must leave `depth` (and therefore
    // `context()`) exactly as it was on entry.
    self.depth = (self.depth - 1) & 0xFF
    raise UnclosedOpeningBracket(index=opening_bracket)
  }
  { leading_whitespace, opening_bracket, items, }
}

///|
fn modifier_from_token(
  token : Token,
) -> Modifier raise InvalidFormatDescription {
  guard token.value.find(":") is Some(colon) else {
    raise InvalidModifier(value=token.value, index=token.start)
  }
  let key = token.value.view(end_offset=colon).to_owned()
  let value = token.value.view(start_offset=colon + 1).to_owned()
  if key == "" {
    raise InvalidModifier(value="", index=token.start)
  }
  if value == "" {
    raise InvalidModifier(value="", index=token.start + utf8_len(key))
  }
  { key, key_location: token.start, value, }
}

///|
fn Lexer::is_nested_description_start(self : Lexer) -> Bool {
  let mut i = self.pos
  while i < self.chars.length() && is_ascii_whitespace(self.chars[i]) {
    i += 1
  }
  i < self.chars.length() && self.chars[i] == '['
}

///|
fn Lexer::consume_literal(self : Lexer) -> String {
  let start = self.pos
  let mut end = start
  while end < self.chars.length() && !(self.chars[end] is ('[' | ']' | '\\')) {
    end += 1
  }
  self.pos = end
  self.slice(start, end)
}

///|
fn Lexer::consume_backslash_escape_sequence(
  self : Lexer,
  location : Int,
) -> String raise InvalidFormatDescription {
  match self.peek(1) {
    Some('\\' | '[' | ']' as c) => {
      // The escaped character is emitted as-is.
      self.pos += 2
      c.to_string()
    }
    Some(_) =>
      raise Expected(what="valid escape sequence", index=self.byte_pos() + 1)
    None => raise Expected(what="valid escape sequence", index=location)
  }
}

///|
fn Lexer::parse_next_item(
  self : Lexer,
) -> FormatItem raise InvalidFormatDescription {
  let location = self.byte_pos()
  match self.chars[self.pos] {
    '[' => self.consume_component(location)
    ']' => {
      self.pos += 1
      StringLiteral("]")
    }
    '\\' => StringLiteral(self.consume_backslash_escape_sequence(location))
    _ => StringLiteral(self.consume_literal())
  }
}

// ---------------------------------------------------------------------------
// format_item.rs

///|
/// `ident_eq::<2>`: ASCII-case-insensitive comparison of the provided
/// identifier against the expected (lowercase) one.
fn ident_eq(provided : String, expected : String) -> Bool {
  if provided.length() != expected.length() {
    return false
  }
  for i in 0..<provided.length() {
    let p = provided[i]
    let p = if p >= 'A' && p <= 'Z' { p + 32 } else { p }
    if p != expected[i] {
      return false
    }
  }
  true
}

///|
/// The parsed value of a modifier: either the index of the matching variant
/// or (for `[ignore count:_]`) the parsed number.
priv enum ModifierValue {
  Variant(Int)
  Number(Int)
}

///|
/// A modifier definition: its key and its permitted values (in declaration
/// order). An empty variant list denotes a `NonZero<u16>` parsed with
/// `FromStr`.
priv struct ModifierDef {
  key : String
  variants : ReadOnlyArray[String]
}

///|
fn from_modifier_value(
  def : ModifierDef,
  modifier : Modifier,
) -> ModifierValue raise InvalidFormatDescription {
  if def.variants.is_empty() {
    guard parse_nonzero_u16(modifier.value) is Some(n) else {
      raise InvalidModifier(value=modifier.value, index=modifier.value_start())
    }
    return Number(n)
  }
  for i, variant in def.variants[:] {
    if ident_eq(modifier.value, variant) {
      return Variant(i)
    }
  }
  raise InvalidModifier(value=modifier.value, index=modifier.value_start())
}

///|
/// `<NonZero<u16> as FromStr>::from_str`.
fn parse_nonzero_u16(s : String) -> Int? {
  let digits = if s.has_prefix("+") { s.view(start_offset=1) } else { s.view() }
  if digits.length() == 0 {
    return None
  }
  let mut n = 0
  for c in digits {
    guard c >= '0' && c <= '9' else { return None }
    n = n * 10 + (c.to_int() - '0'.to_int())
    if n > 65535 {
      return None
    }
  }
  if n == 0 {
    None
  } else {
    Some(n)
  }
}

///|
/// Parse the modifiers of a component (`with_modifiers::<2>`), returning the
/// parsed value of each defined modifier (`None` if absent). Later
/// duplicates override earlier ones.
fn parse_modifier_values(
  defs : Array[ModifierDef],
  modifiers : Array[Modifier],
) -> Array[ModifierValue?] raise InvalidFormatDescription {
  let values : Array[ModifierValue?] = Array::make(defs.length(), None)
  for modifier in modifiers {
    let mut found = false
    for i, def in defs {
      if ident_eq(modifier.key, def.key) {
        values[i] = Some(from_modifier_value(def, modifier))
        found = true
        break
      }
    }
    if !found {
      raise InvalidModifier(value=modifier.key, index=modifier.key_location)
    }
  }
  values
}

///|
fn parse_optional_format_modifier(
  modifiers : Array[Modifier],
) -> Bool raise InvalidFormatDescription {
  let values = parse_modifier_values(
    [{ key: "format", variants: ["false", "true"], }],
    modifiers,
  )
  bool_or_true(values[0])
}

///|
fn variant_or(value : ModifierValue?, default : Int) -> Int {
  match value {
    Some(Variant(i)) => i
    _ => default
  }
}

///|
/// `false`/`true` modifiers, defaulting to `true`.
fn bool_or_true(value : ModifierValue?) -> Bool {
  variant_or(value, 1) == 1
}

///|
/// `padding` modifiers: `space`, `zero` (default), `none`.
fn padding_or_default(value : ModifierValue?) -> Padding {
  match variant_or(value, 1) {
    0 => Space
    1 => Zero
    _ => None_
  }
}

///|
/// `sign` modifiers: `automatic` (default), `mandatory`.
fn sign_is_mandatory(value : ModifierValue?) -> Bool {
  variant_or(value, 0) == 1
}

///|
let padding_def : ModifierDef = {
  key: "padding",
  variants: ["space", "zero", "none"],
}

///|
let bool_variants : ReadOnlyArray[String] = ["false", "true"]

///|
let sign_def : ModifierDef = {
  key: "sign",
  variants: ["automatic", "mandatory"],
}

///|
fn component_from_ast(
  name : Token,
  modifiers : Array[Modifier],
) -> Component raise InvalidFormatDescription {
  let n = name.value
  if ident_eq(n, "day") {
    let v = parse_modifier_values([padding_def], modifiers)
    Day(padding=padding_or_default(v[0]))
  } else if ident_eq(n, "end") {
    let v = parse_modifier_values(
      [{ key: "trailing_input", variants: ["prohibit", "discard"], }],
      modifiers,
    )
    End(
      trailing_input=if variant_or(v[0], 0) == 0 { Prohibit } else { Discard },
    )
  } else if ident_eq(n, "hour") {
    let v = parse_modifier_values(
      [padding_def, { key: "repr", variants: ["12", "24"], }],
      modifiers,
    )
    let padding = padding_or_default(v[0])
    if variant_or(v[1], 1) == 0 {
      Hour12(padding~)
    } else {
      Hour24(padding~)
    }
  } else if ident_eq(n, "ignore") {
    let v = parse_modifier_values([{ key: "count", variants: [], }], modifiers)
    match v[0] {
      Some(Number(count)) => Ignore(count~)
      _ => raise MissingRequiredModifier(name="count", index=name.start)
    }
  } else if ident_eq(n, "minute") {
    let v = parse_modifier_values([padding_def], modifiers)
    Minute(padding=padding_or_default(v[0]))
  } else if ident_eq(n, "month") {
    let v = parse_modifier_values(
      [
        padding_def,
        { key: "repr", variants: ["numerical", "long", "short"], },
        { key: "case_sensitive", variants: bool_variants, },
      ],
      modifiers,
    )
    match variant_or(v[1], 0) {
      0 => MonthNumerical(padding=padding_or_default(v[0]))
      1 => MonthLong(case_sensitive=bool_or_true(v[2]))
      _ => MonthShort(case_sensitive=bool_or_true(v[2]))
    }
  } else if ident_eq(n, "offset_hour") {
    let v = parse_modifier_values([sign_def, padding_def], modifiers)
    OffsetHour(
      sign_is_mandatory=sign_is_mandatory(v[0]),
      padding=padding_or_default(v[1]),
    )
  } else if ident_eq(n, "offset_minute") {
    let v = parse_modifier_values([padding_def], modifiers)
    OffsetMinute(padding=padding_or_default(v[0]))
  } else if ident_eq(n, "offset_second") {
    let v = parse_modifier_values([padding_def], modifiers)
    OffsetSecond(padding=padding_or_default(v[0]))
  } else if ident_eq(n, "ordinal") {
    let v = parse_modifier_values([padding_def], modifiers)
    Ordinal(padding=padding_or_default(v[0]))
  } else if ident_eq(n, "period") {
    let v = parse_modifier_values(
      [
        { key: "case", variants: ["lower", "upper"], },
        { key: "case_sensitive", variants: bool_variants, },
      ],
      modifiers,
    )
    Period(
      is_uppercase=variant_or(v[0], 1) == 1,
      case_sensitive=bool_or_true(v[1]),
    )
  } else if ident_eq(n, "second") {
    let v = parse_modifier_values([padding_def], modifiers)
    Second(padding=padding_or_default(v[0]))
  } else if ident_eq(n, "subsecond") {
    let v = parse_modifier_values(
      [
        {
          key: "digits",
          variants: ["1", "2", "3", "4", "5", "6", "7", "8", "9", "1+"],
        },
      ],
      modifiers,
    )
    let digits = match variant_or(v[0], 9) {
      0 => One
      1 => Two
      2 => Three
      3 => Four
      4 => Five
      5 => Six
      6 => Seven
      7 => Eight
      8 => Nine
      _ => OneOrMore
    }
    Subsecond(digits~)
  } else if ident_eq(n, "unix_timestamp") {
    let v = parse_modifier_values(
      [
        {
          key: "precision",
          variants: ["second", "millisecond", "microsecond", "nanosecond"],
        },
        sign_def,
      ],
      modifiers,
    )
    let sign_is_mandatory = sign_is_mandatory(v[1])
    match variant_or(v[0], 0) {
      0 => UnixTimestampSecond(sign_is_mandatory~)
      1 => UnixTimestampMillisecond(sign_is_mandatory~)
      2 => UnixTimestampMicrosecond(sign_is_mandatory~)
      _ => UnixTimestampNanosecond(sign_is_mandatory~)
    }
  } else if ident_eq(n, "weekday") {
    let v = parse_modifier_values(
      [
        { key: "repr", variants: ["short", "long", "sunday", "monday"], },
        { key: "one_indexed", variants: bool_variants, },
        { key: "case_sensitive", variants: bool_variants, },
      ],
      modifiers,
    )
    match variant_or(v[0], 1) {
      0 => WeekdayShort(case_sensitive=bool_or_true(v[2]))
      1 => WeekdayLong(case_sensitive=bool_or_true(v[2]))
      2 => WeekdaySunday(one_indexed=bool_or_true(v[1]))
      _ => WeekdayMonday(one_indexed=bool_or_true(v[1]))
    }
  } else if ident_eq(n, "week_number") {
    let v = parse_modifier_values(
      [padding_def, { key: "repr", variants: ["iso", "sunday", "monday"], }],
      modifiers,
    )
    let padding = padding_or_default(v[0])
    match variant_or(v[1], 0) {
      0 => WeekNumberIso(padding~)
      1 => WeekNumberSunday(padding~)
      _ => WeekNumberMonday(padding~)
    }
  } else if ident_eq(n, "year") {
    let v = parse_modifier_values(
      [
        padding_def,
        { key: "repr", variants: ["full", "century", "last_two"], },
        { key: "range", variants: ["standard", "extended"], },
        { key: "base", variants: ["calendar", "iso_week"], },
        sign_def,
      ],
      modifiers,
    )
    let padding = padding_or_default(v[0])
    let sign_is_mandatory = sign_is_mandatory(v[4])
    let iso_week = variant_or(v[3], 0) == 1
    // Without the `large-dates` feature, the extended range variants are
    // never produced.
    match (iso_week, variant_or(v[1], 0)) {
      (false, 0) => CalendarYearFullStandardRange(padding~, sign_is_mandatory~)
      (false, 1) =>
        CalendarYearCenturyStandardRange(padding~, sign_is_mandatory~)
      (true, 0) => IsoYearFullStandardRange(padding~, sign_is_mandatory~)
      (true, 1) => IsoYearCenturyStandardRange(padding~, sign_is_mandatory~)
      (false, _) => CalendarYearLastTwo(padding~)
      (true, _) => IsoYearLastTwo(padding~)
    }
  } else {
    raise InvalidComponentName(name=n, index=name.start)
  }
}
