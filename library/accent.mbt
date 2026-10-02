// Port of `typst-library/src/math/accent.rs` (the `AccentElem` element is
// generated).

///|
/// An accent character.
pub(all) struct Accent(Char) derive(Eq, Hash, Debug)

///|
/// Tries to select the appropriate combining accent for a string, falling
/// back to the string's lone character if there is no corresponding one.
///
/// Returns `None` if there isn't one and the string has more than one
/// character.
pub fn Accent::normalize(s : String) -> Accent? {
  match Accent::combining(s) {
    Some(accent) => Some(accent)
    None => single_char(s).map(c => Accent(c))
  }
}

///|
/// Tries to select a well-known combining accent that matches for the value.
pub fn Accent::combining(value : String) -> Accent? {
  let c = single_char(value)
  for entry in accents {
    let (accent, names) = entry
    if Some(accent) == c || names.contains(value) {
      return Some(Accent(accent))
    }
  }
  None
}

///|
/// Gets the accent function corresponding to a symbol value, if any.
pub fn get_accent_func(value : String) -> Func? {
  Accent::combining(value).map(accent => {
    Func::native(accent_funcs().get(accent.0).unwrap())
  })
}

// Keep it synced with the documenting table above and the
// `math-accent-sym-call` test.`

///|
/// A list of accents, each with a list of alternative names.
let accents : Array[(Char, Array[String])] = [
  // Note: Symbols that can have a text presentation must explicitly have that
  // alternative listed here.
  ('\u{0300}', ["`"]),
  ('\u{0301}', ["´"]),
  ('\u{0302}', ["^", "ˆ"]),
  ('\u{0303}', ["~", "∼", "˜"]),
  ('\u{0304}', ["¯"]),
  ('\u{0305}', ["-", "–", "‾", "−"]),
  ('\u{0306}', ["˘"]),
  ('\u{0307}', [".", "˙", "⋅"]),
  ('\u{0308}', ["¨"]),
  ('\u{20db}', []),
  ('\u{20dc}', []),
  ('\u{030a}', ["∘", "○"]),
  ('\u{030b}', ["˝"]),
  ('\u{030c}', ["ˇ"]),
  ('\u{20d6}', ["←"]),
  ('\u{20d7}', ["→", "⟶"]),
  ('\u{20e1}', ["↔", "↔\u{fe0e}", "⟷"]),
  ('\u{20d0}', ["↼"]),
  ('\u{20d1}', ["⇀"]),
]

///|
let accent_funcs_cell : Ref[Map[Char, NativeFuncData]?] = { val: None, }

///|
/// Lazily created accent functions.
fn accent_funcs() -> Map[Char, NativeFuncData] {
  match accent_funcs_cell.val {
    Some(m) => m
    None => {
      let m : Map[Char, NativeFuncData] = Map([])
      for entry in accents {
        m[entry.0] = create_accent_func_data(entry.0)
      }
      accent_funcs_cell.val = Some(m)
      m
    }
  }
}

///|
/// Creates metadata for an accent wrapper function.
fn create_accent_func_data(accent : Char) -> NativeFuncData {
  NativeFuncData::new(
    name="(..) => ..",
    title="Accent (\{accent})",
    docs="Adds the accent \{accent} on an expression.",
    params=create_accent_param_info(),
    returns=() => Type(Type::content()),
    (_engine, _context, args) => {
      let base : Content = args.expect("base")
      let size : Rel[Length]? = args.named("size")
      let dotless : Bool? = args.named("dotless")
      let mut elem = Content::new(accent_elem(), [
        (accent_elem_base, Content(base)),
        (accent_elem_accent, IntoValue::into_value(Accent(accent))),
      ])
      if size is Some(size) {
        elem = elem.with_field(accent_elem_size, IntoValue::into_value(size))
      }
      if dotless is Some(dotless) {
        elem = elem.with_field(accent_elem_dotless, Bool(dotless))
      }
      Content(elem)
    },
  )
}

///|
/// Creates parameter signature metadata for an accent function.
fn create_accent_param_info() -> Array[ParamInfo] {
  [
    {
      name: "base",
      docs: "The base to which the accent is applied.",
      input: () => input_of((Ty::new() : Ty[Content])),
      default: None,
      positional: true,
      named: false,
      variadic: false,
      required: true,
      settable: false,
    },
    {
      name: "size",
      docs: "The size of the accent, relative to the width of the base.",
      input: () => input_of((Ty::new() : Ty[Rel[Length]])),
      default: None,
      positional: false,
      named: true,
      variadic: false,
      required: false,
      settable: false,
    },
    {
      name: "dotless",
      docs: "Whether to remove the dot on top of lowercase i and j when adding a top accent.",
      input: () => input_of((Ty::new() : Ty[Bool])),
      default: None,
      positional: false,
      named: true,
      variadic: false,
      required: false,
      settable: false,
    },
  ]
}

///|
pub impl Reflect for Accent with fn input() {
  input_of((Ty::new() : Ty[String])).union_with(
    input_of((Ty::new() : Ty[Content])),
  )
}

///|
pub impl Reflect for Accent with fn output() {
  // `char` casts to a string.
  Type(Type::str())
}

///|
pub impl Reflect for Accent with fn castable(v) {
  reflect_castable((Ty::new() : Ty[String]), v) ||
  reflect_castable((Ty::new() : Ty[Content]), v)
}

///|
pub impl IntoValue for Accent with fn into_value(self) {
  Str(self.0.to_string())
}

///|
pub impl FromValue for Accent with fn from_value(v) {
  // The string cast handles
  // - strings: `accent(a, "↔")`
  // - symbol values: `accent(a, <->)`
  // - shorthands: `accent(a, arrow.l.r)`
  if reflect_castable((Ty::new() : Ty[String]), v) {
    let s : String = v.cast()
    match Accent::normalize(s) {
      Some(accent) => return accent
      None => bail("expected exactly one character")
    }
  }
  // The content cast is for accent uses like `accent(a, ↔)`
  if reflect_castable((Ty::new() : Ty[Content]), v) {
    let content : Content = v.cast()
    if content.elem() == symbol_elem() &&
      content.field_raw(symbol_elem_text) is Some(Str(text)) &&
      Accent::normalize(text) is Some(accent) {
      return accent
    }
    bail("expected a single-codepoint symbol")
  }
  raise HintedError(Accent::input().error(v))
}

///|
/// How much the accent can be shorter than the base (upstream
/// `ACCENT_SHORT_FALL`).
pub let accent_short_fall : Em = Em::new(0.5)

///|
/// Whether this accent is a bottom accent or not.
pub fn Accent::is_bottom(self : Accent) -> Bool {
  if self.0 is ('⏟' | '⎵' | '⏝' | '⏡') {
    return true
  }
  // `CanonicalCombiningClass::Below`.
  @unicode.canonical_combining_class(self.0.to_int()) == 220
}
