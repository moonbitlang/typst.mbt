// Port of the functions in `typst-library/src/math/lr.rs` (the `LrElem` and
// `MidElem` elements are generated).

///|
/// Floors an expression.
fn impl_math_floor(
  size : Rel[Length]?,
  body : Content,
) -> Content raise HintedError {
  delimited(body, '⌊', '⌋', size)
}

///|
/// Ceils an expression.
fn impl_math_ceil(
  size : Rel[Length]?,
  body : Content,
) -> Content raise HintedError {
  delimited(body, '⌈', '⌉', size)
}

///|
/// Rounds an expression.
fn impl_math_round(
  size : Rel[Length]?,
  body : Content,
) -> Content raise HintedError {
  delimited(body, '⌊', '⌉', size)
}

///|
/// Takes the absolute value of an expression.
fn impl_math_abs(
  size : Rel[Length]?,
  body : Content,
) -> Content raise HintedError {
  delimited(body, '|', '|', size)
}

///|
/// Takes the norm of an expression.
fn impl_math_norm(
  size : Rel[Length]?,
  body : Content,
) -> Content raise HintedError {
  delimited(body, '‖', '‖', size)
}

///|
/// Gets the Left/Right wrapper function corresponding to a symbol value, if
/// any.
pub fn get_lr_wrapper_func(value : String) -> Func? {
  guard single_char(value) is Some(left) else { return None }
  match left {
    // Unlike `round`, `abs`, and `norm`, `floor` and `ceil` are of type
    // `symbol` and cast to a function like other L/R symbols. We could thus
    // rely on autogeneration for these as well, but since they are
    // specifically called out in the documentation on the L/R page (via the
    // group mechanism), it's nice for them to have a bit of extra
    // documentation.
    '⌈' => Some(Func::native(native_math_ceil()))
    '⌊' => Some(Func::native(native_math_floor()))
    l => lr_funcs().get(l).map(Func::native)
  }
}

///|
/// Upstream `str::parse::<char>`: the string's only character, if it has
/// exactly one.
fn single_char(value : String) -> Char? {
  let mut found : Char? = None
  for c in value {
    if found is Some(_) {
      return None
    }
    found = Some(c)
  }
  found
}

///|
/// The delimiter pairings supported for use as callable symbols.
let lr_delims : ReadOnlyArray[(Char, Char)] = [
  // The `ceil` and `floor` pairs are omitted here because they are handled
  // manually.
  ('(', ')'),
  ('⟮', '⟯'),
  ('⦇', '⦈'),
  ('⦅', '⦆'),
  ('⦓', '⦔'),
  ('⦕', '⦖'),
  ('{', '}'),
  ('⦃', '⦄'),
  ('[', ']'),
  ('⦍', '⦐'),
  ('⦏', '⦎'),
  ('⟦', '⟧'),
  ('⦋', '⦌'),
  ('❲', '❳'),
  ('⟬', '⟭'),
  ('⦗', '⦘'),
  ('⟅', '⟆'),
  ('⎰', '⎱'),
  ('⎱', '⎰'),
  ('⧘', '⧙'),
  ('⧚', '⧛'),
  ('⟨', '⟩'),
  ('⧼', '⧽'),
  ('⦑', '⦒'),
  ('⦉', '⦊'),
  ('⟪', '⟫'),
  ('⌜', '⌝'),
  ('⌞', '⌟'),
  // Fences.
  ('|', '|'),
  ('‖', '‖'),
  ('⦀', '⦀'),
  ('⦙', '⦙'),
  ('⦚', '⦚'),
]

///|
let lr_funcs_cell : Ref[Map[Char, NativeFuncData]?] = { val: None, }

///|
/// Lazily created left/right wrapper functions.
fn lr_funcs() -> Map[Char, NativeFuncData] {
  match lr_funcs_cell.val {
    Some(m) => m
    None => {
      let m : Map[Char, NativeFuncData] = Map([])
      for pair in lr_delims[:] {
        let (l, r) = pair
        m[l] = create_lr_func_data(l, r)
      }
      lr_funcs_cell.val = Some(m)
      m
    }
  }
}

///|
/// Creates metadata for an L/R wrapper function.
fn create_lr_func_data(left : Char, right : Char) -> NativeFuncData {
  NativeFuncData::new(
    name="(..) => ..",
    title="\{left}\{right} Left/Right",
    docs="Wraps an expression in \{left}\{right}.",
    params=create_lr_param_info(),
    returns=() => Type(Type::content()),
    (_engine, _context, args) => {
      let size : Rel[Length]? = args.named("size")
      let body : Content = args.expect("body")
      Content(delimited(body, left, right, size))
    },
  )
}

///|
/// Creates parameter signature metadata for an L/R function.
fn create_lr_param_info() -> Array[ParamInfo] {
  [
    {
      name: "size",
      docs: "The size of the brackets, relative to the height of the wrapped content.\n\nDefault: The current value of [`lr.size`]($math.lr.size).",
      input: () => input_of((Ty::new() : Ty[Rel[Length]])),
      default: None,
      positional: false,
      named: true,
      variadic: false,
      required: false,
      settable: false,
    },
    {
      name: "body",
      docs: "The expression to wrap.",
      input: () => input_of((Ty::new() : Ty[Content])),
      default: None,
      positional: true,
      named: false,
      variadic: false,
      required: true,
      settable: false,
    },
  ]
}

///|
/// Creates an L/R element with the given delimiters.
fn delimited(
  body : Content,
  left : Char,
  right : Char,
  size : Rel[Length]?,
) -> Content {
  let span = body.span()
  let mut elem = Content::new(lr_elem(), [
    (
      lr_elem_body,
      Content(
        Content::sequence([
          SymbolElem::packed(left.to_string()),
          body,
          SymbolElem::packed(right.to_string()),
        ]),
      ),
    ),
  ])
  // Push size only if size is provided
  if size is Some(size) {
    elem = elem.with_field(lr_elem_size, IntoValue::into_value(size))
  }
  elem.spanned(span)
}

///|
/// Custom parsing of `LrElem.body`: all positional content arguments, joined
/// by commas.
fn lr_elem_body_parse(
  _engine : Engine,
  args : Args,
  _locals : ParseLocals,
) -> Value? raise SourceError {
  let arguments : Array[Content] = args.all()
  let mut body = arguments.get(0).unwrap_or(Content::empty())
  for i in 1..<arguments.length() {
    body = body.add(SymbolElem::packed(",").add(arguments[i]))
  }
  Some(Content(body))
}

///|
/// How much less high scaled delimiters can be than what they wrap (upstream
/// `DELIM_SHORT_FALL`).
pub let delim_short_fall : Em = Em::new(0.1)
