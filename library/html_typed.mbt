// Port of `typst-html/src/typed.rs`: the typed HTML element API (e.g.
// `html.div`).
//
// The typed API is backed by generated data derived from the HTML
// specification (`typst_assets::html`, generated into the `html_assets`
// package by `oracle/src/bin/gen_html.rs`).

///|
/// Hook up all typed HTML definitions (upstream `typed::define`, called by
/// `HtmlFormat`'s `#[defs]`).
fn defs_html_format(scope : Scope) -> Unit {
  for data in html_typed_funcs() {
    scope.define_func(data) |> ignore
  }
}

///|
let html_typed_funcs_cell : Ref[Array[NativeFuncData]?] = { val: None, }

///|
/// Lazily created functions for all typed HTML constructors (upstream
/// `FUNCS`).
fn html_typed_funcs() -> Array[NativeFuncData] {
  match html_typed_funcs_cell.val {
    Some(funcs) => funcs
    None => {
      let funcs = @html_assets.elems().map(html_typed_create_func_data)
      html_typed_funcs_cell.val = Some(funcs)
      funcs
    }
  }
}

///|
/// Creates metadata for a native HTML element constructor function.
fn html_typed_create_func_data(
  element : @html_assets.ElemInfo,
) -> NativeFuncData {
  let name = element.name
  let title = name.substring(end=1).to_upper() + name.substring(start=1)
  NativeFuncData::new(
    name~,
    title~,
    docs=element.docs,
    keywords=["typed-html"],
    contextual=false,
    params=html_typed_create_param_info(element),
    returns=() => Type(Type::content()),
    (_engine, _context, args) => html_typed_construct(element, args),
  )
}

///|
/// Creates parameter signature metadata for an element.
fn html_typed_create_param_info(
  element : @html_assets.ElemInfo,
) -> Array[ParamInfo] {
  let params : Array[ParamInfo] = []
  for attr in element.attributes() {
    let ty = attr.ty
    params.push({
      name: attr.name,
      docs: attr.docs,
      input: () => AttrType::convert(ty).input(),
      default: None,
      positional: false,
      named: true,
      variadic: false,
      required: false,
      settable: false,
    })
  }
  let tag = HtmlTag::constant(element.name)
  if !tag.is_void() {
    let raw = tag.is_raw()
    params.push({
      name: "body",
      docs: if raw {
        "The text content of the HTML element."
      } else {
        "The contents of the HTML element."
      },
      input: () => Type(if raw { Type::str() } else { Type::content() }),
      default: None,
      positional: true,
      named: false,
      variadic: false,
      required: false,
      settable: false,
    })
  }
  params
}

///|
/// The native constructor function shared by all HTML elements.
fn html_typed_construct(
  element : @html_assets.ElemInfo,
  args : Args,
) -> Value raise SourceError {
  let attrs = HtmlAttrs::new()
  let errors = []
  let kept = []
  for item in args.items {
    let attr = match item.name {
      Some(name) => element.get_attr(name)
      None => None
    }
    guard attr is Some(attr) else {
      kept.push(item)
      continue
    }
    let span = item.value.span
    let value = item.value.v
    let ty = AttrType::convert(attr.ty)
    try ty.cast(value) catch {
      HintedError(err) => errors.push(err.into_error_at(span))
    } noraise {
      Some(string) => attrs.push(HtmlAttr::constant(attr.name), string)
      None => ()
    }
  }
  args.items.clear()
  args.items.append(kept)
  if !errors.is_empty() {
    raise SourceError(errors)
  }
  let tag = HtmlTag::constant(element.name)
  let mut elem = HtmlElem::new(tag)
  if !attrs.is_empty() {
    elem = elem.with_attrs(attrs)
  }
  if !tag.is_void() {
    let body = if tag.is_raw() {
      let str : @syntax.Spanned[String]? = args.eat_spanned_cast()
      str.map(s => TextElem::packed(s.v).spanned(s.span))
    } else {
      args.eat()
    }
    elem = elem.with_body(body)
  }
  Content(elem.pack())
}

///|
/// A dynamic representation of an attribute's type.
///
/// See the documentation of [@html_assets.Type] for more details on
/// variants.
priv enum AttrType {
  Presence
  Native(NativeAttrType)
  Strings(StringsType)
  Union(UnionType)
  List(ListType)
}

///|
/// Converts the type definition into a representation suitable for casting
/// and reflection.
fn AttrType::convert(ty : @html_assets.Type) -> AttrType {
  match ty {
    Presence => Presence
    None_ =>
      Native(native_attr_type(none_value_input, v => v is None, _ => "none"))
    NoneEmpty =>
      Native(native_attr_type(none_value_input, v => v is None, _ => ""))
    NoneUndefined =>
      Native(
        native_attr_type(none_value_input, v => v is None, _ => "undefined"),
      )
    Auto =>
      Native(
        native_attr_type(() => Type(Type::auto()), v => v is Auto, _ => "auto"),
      )
    TrueFalse =>
      Native(
        native_attr_of((Ty::new() : Ty[Bool]), b => {
          if b {
            "true"
          } else {
            "false"
          }
        }),
      )
    YesNo =>
      Native(
        native_attr_of((Ty::new() : Ty[Bool]), b => if b { "yes" } else { "no" }),
      )
    OnOff =>
      Native(
        native_attr_of((Ty::new() : Ty[Bool]), b => if b { "on" } else { "off" }),
      )
    Int => Native(native_attr_of((Ty::new() : Ty[Int64]), i => i.to_string()))
    NonNegativeInt =>
      Native(native_attr_of((Ty::new() : Ty[U64]), i => i.0.to_string()))
    PositiveInt =>
      Native(native_attr_of((Ty::new() : Ty[NonZeroU64]), i => i.0.to_string()))
    Float => Native(native_attr_of((Ty::new() : Ty[Double]), f64_into_attr))
    PositiveFloat =>
      Native(
        native_attr_of((Ty::new() : Ty[PositiveF64]), f => {
          f64_into_attr(f.get())
        }),
      )
    Str => Native(native_attr_of((Ty::new() : Ty[String]), s => s))
    Char => Native(native_attr_of((Ty::new() : Ty[Char]), c => c.to_string()))
    Datetime =>
      Native(native_attr_of((Ty::new() : Ty[Datetime]), datetime_into_attr))
    Duration =>
      Native(native_attr_of((Ty::new() : Ty[Duration]), duration_into_attr))
    Color => Native(color_attr_type())
    HorizontalDir => {
      let base = native_attr_of((Ty::new() : Ty[Dir]), dir_into_attr)
      Native({ ..base, cast: v => Some(horizontal_dir_cast(v)), })
    }
    IconSize =>
      Native(
        native_attr_of((Ty::new() : Ty[Axes[U64]]), v => "\{v.x.0}x\{v.y.0}"),
      )
    ImageCandidate =>
      Native({
        input: () => Type(Type::dict()),
        castable: v => v is Dict(_),
        cast: v => Some(image_candidate_cast(v)),
      })
    SourceSize =>
      Native({
        input: () => Type(Type::dict()),
        castable: v => v is Dict(_),
        cast: v => Some(source_size_cast(v)),
      })
    Strings(start, end) => Strings({ start, end, })
    Union(variants) => Union(UnionType(variants))
    List(inner, separator, shorthand) => List({ inner, separator, shorthand, })
  }
}

///|
/// See [Reflect::input].
fn AttrType::input(self : AttrType) -> CastInfo {
  match self {
    Presence => input_of((Ty::new() : Ty[Bool]))
    Native(ty) => (ty.input)()
    Union(ty) => ty.input()
    Strings(ty) => ty.input()
    List(ty) => ty.input()
  }
}

///|
/// See [Reflect::castable].
fn AttrType::castable(self : AttrType, value : Value) -> Bool {
  match self {
    Presence => value is Bool(_)
    Native(ty) => (ty.castable)(value)
    Union(ty) => ty.castable(value)
    Strings(ty) => ty.castable(value)
    List(ty) => ty.castable(value)
  }
}

///|
/// Tries to cast the value into this attribute's type and serialize it into
/// an HTML attribute string.
fn AttrType::cast(self : AttrType, value : Value) -> String? raise HintedError {
  match self {
    Presence => {
      let b : Bool = value.cast()
      if b {
        Some("")
      } else {
        None
      }
    }
    Native(ty) => (ty.cast)(value)
    Union(ty) => ty.cast(value)
    Strings(ty) => ty.cast(value)
    List(ty) => ty.cast(value)
  }
}

///|
/// An enumeration with generated string variants.
///
/// `start` and `end` are used to index into `@html_assets.attr_strings()`.
priv struct StringsType {
  start : Int
  end : Int
}

///|
fn StringsType::input(self : StringsType) -> CastInfo {
  CastInfo::Union(
    self.strings().map(pair => CastInfo::Value(Str(pair.0), pair.1)),
  )
}

///|
fn StringsType::castable(self : StringsType, value : Value) -> Bool {
  match value {
    Str(s) => self.strings().iter().any(pair => pair.0 == s)
    _ => false
  }
}

///|
fn StringsType::cast(
  self : StringsType,
  value : Value,
) -> String? raise HintedError {
  if self.castable(value) {
    Some(value.cast())
  } else {
    raise HintedError(self.input().error(value))
  }
}

///|
fn StringsType::strings(self : StringsType) -> ArrayView[(String, String)] {
  @html_assets.attr_strings()[self.start:self.end]
}

///|
/// A type that accepts any of the contained types.
priv struct UnionType(Array[@html_assets.Type])

///|
fn UnionType::input(self : UnionType) -> CastInfo {
  CastInfo::Union(self.iter().map(ty => ty.input()))
}

///|
fn UnionType::castable(self : UnionType, value : Value) -> Bool {
  self.iter().iter().any(ty => ty.castable(value))
}

///|
fn UnionType::cast(
  self : UnionType,
  value : Value,
) -> String? raise HintedError {
  for item in self.iter() {
    if item.castable(value) {
      return item.cast(value)
    }
  }
  raise HintedError(self.input().error(value))
}

///|
fn UnionType::iter(self : UnionType) -> Array[AttrType] {
  self.0.map(AttrType::convert)
}

///|
/// A list of items separated by a specific separator char.
///
/// - <https://html.spec.whatwg.org/#space-separated-tokens>
/// - <https://html.spec.whatwg.org/#comma-separated-tokens>
priv struct ListType {
  inner : @html_assets.Type
  separator : Char
  shorthand : Bool
}

///|
fn ListType::input(self : ListType) -> CastInfo {
  if self.shorthand {
    input_of((Ty::new() : Ty[Arr])).union_with(self.inner().input())
  } else {
    input_of((Ty::new() : Ty[Arr]))
  }
}

///|
fn ListType::castable(self : ListType, value : Value) -> Bool {
  value is Array(_) || (self.shorthand && self.inner().castable(value))
}

///|
fn ListType::cast(self : ListType, value : Value) -> String? raise HintedError {
  let ty = self.inner()
  if value is Array(_) {
    let array : Arr = value.cast()
    let out = StringBuilder()
    for i, item in array.iter().to_array() {
      let item = ty.cast(item).unwrap()
      if item.contains_char(self.separator) {
        let name = match self.separator {
          ' ' => "space"
          ',' => "comma"
          _ => "'\{self.separator}'"
        }
        bail_hinted("array item may not contain a \{name}", [
          "the array attribute will be encoded as a \{name}-separated string",
        ])
      }
      if i > 0 {
        out.write_char(self.separator)
        if self.separator == ',' {
          out.write_char(' ')
        }
      }
      out.write_string(item)
    }
    Some(out.to_string())
  } else if self.shorthand && ty.castable(value) {
    let item = ty.cast(value).unwrap()
    Some(item)
  } else {
    raise HintedError(self.input().error(value))
  }
}

///|
fn ListType::inner(self : ListType) -> AttrType {
  AttrType::convert(self.inner)
}

///|
/// A dynamic representation of attribute backed by a native type
/// implementing the standard `Reflect` and `FromValue` traits for casting
/// from a value and a conversion into an attribute string (upstream
/// `NativeType` with `IntoAttr`).
priv struct NativeAttrType {
  input : () -> CastInfo
  cast : (Value) -> String? raise HintedError
  castable : (Value) -> Bool
}

///|
/// Creates a dynamic native type from a native type and its `IntoAttr`
/// conversion.
fn[T : FromValue] native_attr_of(
  ty : Ty[T],
  into_attr : (T) -> String,
) -> NativeAttrType {
  {
    input: () => input_of(ty),
    castable: v => html_castable_of(ty, v),
    cast: value => {
      let this : T = T::from_value(value)
      Some(into_attr(this))
    },
  }
}

///|
/// `T::castable(value)`.
fn[T : Reflect] html_castable_of(_ty : Ty[T], value : Value) -> Bool {
  T::castable(value)
}

///|
/// A native type given by its cast info and castability check (for types
/// without a MoonBit type like `NoneValue` and `AutoValue`).
fn native_attr_type(
  input : () -> CastInfo,
  castable : (Value) -> Bool,
  into_attr : (Value) -> String,
) -> NativeAttrType {
  {
    input,
    castable,
    cast: value => {
      if castable(value) {
        Some(into_attr(value))
      } else {
        raise HintedError(input().error(value))
      }
    },
  }
}

///|
/// The input of `NoneValue`.
fn none_value_input() -> CastInfo {
  Type(Type::none())
}

///|
/// `IntoAttr for f64`: HTML float literal allows all the things that Rust's
/// float `Display` impl produces.
fn f64_into_attr(f : Double) -> String {
  rust_display_f64(f)
}

///|
/// `IntoAttr for Color`.
fn color_attr_type() -> NativeAttrType {
  {
    input: () => Type(Type::color()),
    castable: v => v is Color(_),
    cast: v => {
      match v {
        // TODO: `self.to_css(())` (warnings are ignored) once
        // `visualize/color.rs` and `ToCss for Color` are ported.
        Color(_) => bail("`color` attributes are not yet ported")
        _ => raise HintedError(CastInfo::Type(Type::color()).error(v))
      }
    },
  }
}

///|
/// `IntoAttr for Duration`.
fn duration_into_attr(duration : Duration) -> String {
  // https://html.spec.whatwg.org/#valid-duration-string
  let out = StringBuilder()
  let part = (s : String) => {
    if !out.is_empty() {
      out.write_char(' ')
    }
    out.write_string(s)
  }
  let parts = duration.decompose()
  let weeks = parts[0]
  let days = parts[1]
  let hours = parts[2]
  let minutes = parts[3]
  let seconds = parts[4]
  if weeks > 0L {
    part("\{weeks}w")
  }
  if days > 0L {
    part("\{days}d")
  }
  if hours > 0L {
    part("\{hours}h")
  }
  if minutes > 0L {
    part("\{minutes}m")
  }
  if seconds > 0L || out.is_empty() {
    part("\{seconds}s")
  }
  out.to_string()
}

///|
/// `IntoAttr for Datetime`.
fn datetime_into_attr(datetime : Datetime) -> String {
  let f = StringBuilder()
  match datetime {
    Date(date) => html_datetime_date(f, date)
    Time(time) => html_datetime_time(f, time)
    Datetime(datetime) => {
      // https://html.spec.whatwg.org/#valid-global-date-and-time-string
      html_datetime_date(f, datetime.date())
      f.write_char('T')
      html_datetime_time(f, datetime.time())
    }
  }
  f.to_string()
}

///|
/// https://html.spec.whatwg.org/#valid-date-string
fn html_datetime_date(f : StringBuilder, date : @time.Date) -> Unit {
  f.write_string(rust_zero_pad(date.year(), 4))
  f.write_char('-')
  f.write_string(rust_zero_pad(date.month().number(), 2))
  f.write_char('-')
  f.write_string(rust_zero_pad(date.day(), 2))
}

///|
/// https://html.spec.whatwg.org/#valid-time-string
fn html_datetime_time(f : StringBuilder, time : @time.Time) -> Unit {
  f.write_string(rust_zero_pad(time.hour(), 2))
  f.write_char(':')
  f.write_string(rust_zero_pad(time.minute(), 2))
  if time.second() > 0 {
    f.write_char(':')
    f.write_string(rust_zero_pad(time.second(), 2))
  }
}

///|
/// Rust's `format!("{:0width$}", n)`: zero padding after the sign, the sign
/// counting towards the width.
fn rust_zero_pad(n : Int, width : Int) -> String {
  let digits = n.abs().to_string()
  let sign = if n < 0 { "-" } else { "" }
  let pad = width - sign.length() - digits.length()
  sign + (if pad > 0 { "0".repeat(pad) } else { "" }) + digits
}

///|
/// A direction on the X axis: `ltr` or `rtl` (upstream `HorizontalDir`).
fn horizontal_dir_cast(v : Value) -> String raise HintedError {
  let dir : Dir = v.cast()
  if dir.axis() == Y {
    bail("direction must be horizontal")
  }
  dir_into_attr(dir)
}

///|
/// `IntoAttr for Dir`.
fn dir_into_attr(dir : Dir) -> String {
  match dir {
    LTR => "ltr"
    RTL => "rtl"
    TTB => "ttb"
    BTT => "btt"
  }
}

///|
/// <https://html.spec.whatwg.org/#image-candidate-string> (upstream
/// `ImageCandidate`).
fn image_candidate_cast(v : Value) -> String raise HintedError {
  let v : Dict = v.cast()
  let v = v.copy()
  let src : String = v.take("src").cast()
  let width : NonZeroU64? = match (try? v.take("width")) {
    Ok(value) => Some(value.cast())
    Err(_) => None
  }
  let density : PositiveF64? = match (try? v.take("density")) {
    Ok(value) => Some(value.cast())
    Err(_) => None
  }
  v.finish(["src", "width", "density"])
  if src.is_empty() {
    bail("`src` must not be empty")
  } else if src.has_prefix(",") || src.has_suffix(",") {
    bail("`src` must not start or end with a comma")
  }
  let out = StringBuilder()
  out.write_string(src)
  match (width, density) {
    (None, None) => ()
    (Some(width), None) => out.write_string(" \{width.0}w")
    (None, Some(density)) =>
      out.write_string(" \{rust_display_f64(density.get())}d")
    (Some(_), Some(_)) => bail("cannot specify both `width` and `density`")
  }
  out.to_string()
}

///|
/// <https://html.spec.whatwg.org/multipage/images.html#valid-source-size-list>
/// (upstream `SourceSize`).
fn source_size_cast(v : Value) -> String raise HintedError {
  let v : Dict = v.cast()
  let v = v.copy()
  let condition : String = v.take("condition").cast()
  let size : Length = v.take("size").cast() catch {
      HintedError(err) => {
        err.hint(
          "CSS lengths that are not expressible as Typst lengths are not yet supported",
        )
        err.hint("you can use `html.elem` to create a raw attribute")
        raise HintedError(err)
      }
    }
  "(\{condition}) \{to_css(size)}"
}
