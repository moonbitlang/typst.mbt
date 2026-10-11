// Port of `typst-library/src/foundations/content/{element,field,vtable}.rs`.
//
// Deviation from upstream (see docs/p2-architecture.md): element fields are
// stored as `Value`s in [Content]. Each field carries the cast functions of
// its upstream type, so arguments are validated and normalized exactly like
// upstream, and typed views cast back on access.

///|
/// The kind of storage of an element field (upstream's field vtable kinds).
pub(all) enum FieldKind {
  /// A `#[required]` field.
  Required
  /// A `#[synthesized]` field.
  Synthesized
  /// A settable field stored in the element (`Settable`).
  Settable
  /// A `#[ghost]` settable property without storage in the element.
  Ghost
  /// An `#[external]` field (documentation only).
  External
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FieldKind with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FieldKind with @debug.Debug::{to_repr}

///|
/// Metadata about an element field (upstream `FieldVtable`).
pub struct FieldInfo {
  /// The field's index.
  id : Int
  /// The field's name (kebab case).
  name : String
  /// Documentation.
  docs : String
  /// The storage kind.
  kind : FieldKind
  /// Whether the field is positional (as opposed to named).
  positional : Bool
  /// Whether the field is required.
  required : Bool
  /// Whether the field is variadic.
  variadic : Bool
  /// Whether the field is excluded from name lookup and reflection.
  internal : Bool
  /// What values the field accepts (for variadic fields: the item type).
  input : () -> CastInfo
  /// Whether a value is castable to the field type (item type if variadic).
  castable : (Value) -> Bool
  /// Casts and normalizes a value into the field type (item type if
  /// variadic). Errors are upstream's cast errors.
  cast : (Value) -> Value raise HintedError
  /// The default value (settable and external fields).
  default : (() -> Value)?
  /// For `#[fold]` fields: `fold(inner, outer)`.
  fold : ((Value, Value) -> Value)?
  /// For fields with a `#[parse]` attribute: custom argument parsing. Returns
  /// `None` if the argument was not given.
  parse : ((Engine, Args, ParseLocals) -> Value? raise SourceError)?
  /// Converts a stored value into the value shown to users, for field types
  /// whose stored form must keep more information than their upstream
  /// `IntoValue` (e.g. which `Costs` entries were set, so that folding
  /// works). Upstream stores typed values and converts on access.
  output : ((Value) -> Value)?
  /// Equality of two stored values, for field types whose `PartialEq` is
  /// not the equality of their stored form (upstream compares the typed
  /// fields; `None`: the equality of values).
  eq : ((Value, Value) -> Bool)?
}

///|
/// Hooks for element capabilities that need custom behavior.
pub struct ElementHooks {
  /// Custom `Construct` implementation.
  mut construct : ((Engine, Args) -> Content raise SourceError)?
  /// Custom `Set` implementation.
  mut set : ((Engine, Args) -> Styles raise SourceError)?
  /// Custom `Repr` implementation.
  mut repr : ((Content) -> String)?
  /// Custom `PartialEq` implementation.
  mut eq : ((Content, Content) -> Bool)?
  /// Local name in a language/region (upstream `LocalName`).
  mut local_name : ((String, String?) -> String)?
  /// `Synthesize` capability.
  mut synthesize : ((Engine, Content, StyleChain) -> Content raise SourceError)?
  /// `ShowSet` capability.
  mut show_set : ((Content, StyleChain) -> Styles)?
  /// `PlainText` capability.
  mut plain_text : ((Content, StringBuilder) -> Unit)?
  /// Builds the element's scope.
  mut scope : () -> Scope
}

///|
/// Static data describing an element (upstream `ContentVtable`).
pub struct ElementData {
  /// The element's normal name (e.g. `heading`).
  name : String
  /// A name that is unique among all elements (not upstream, where an
  /// element is identified by its vtable): names are not, e.g. `cell` is
  /// both `grid.cell` and `table.cell`. It is the element's fingerprint.
  key : String
  /// The element's title case name (e.g. `Heading`).
  title : String
  /// The version of Typst the element was introduced in.
  since : Since?
  /// Documentation.
  docs : String
  /// Search keywords.
  keywords : Array[String]
  /// Capabilities (upstream capability traits by name).
  capabilities : Array[String]
  /// All fields, internal ones last. The index is the field id.
  fields : Array[FieldInfo]
  /// Custom behavior.
  hooks : ElementHooks
  /// The lazily built scope.
  priv mut scope : Scope?
  /// The lazily built parameter infos.
  priv mut params : Array[ParamInfo]?
}

///|
/// A Typst element (upstream `Element`); compared by identity.
pub struct Element(ElementData)

///|
pub impl Eq for Element with fn equal(self, other) {
  physical_equal(self.0, other.0)
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Element with Eq::{not_equal, equal}

///|
pub impl Hash for Element with fn hash_combine(self, hasher) {
  hasher.combine_string(self.0.name)
}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Element with Hash::{hash, hash_combine}

///|
/// Order by name (upstream `Ord for Element`).
pub impl Compare for Element with fn compare(self, other) {
  compare_str(self.0.name, other.0.name)
}

///|
#deprecated("call as `Compare::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Element with Compare::{op_lt, op_le, op_ge, compare, op_gt}

///|
/// Create an element descriptor.
pub fn Element::new(
  name~ : String,
  title~ : String,
  key~ : String = name,
  since? : Since,
  docs~ : String = "",
  keywords~ : Array[String] = [],
  capabilities~ : Array[String] = [],
  fields~ : Array[FieldInfo],
) -> Element {
  Element({
    name,
    key,
    title,
    since,
    docs,
    keywords,
    capabilities,
    fields,
    hooks: {
      construct: None,
      set: None,
      repr: None,
      eq: None,
      local_name: None,
      synthesize: None,
      show_set: None,
      plain_text: None,
      scope: Scope::new,
    },
    scope: None,
    params: None,
  })
}

///|
/// The element's normal name (e.g. `align`).
pub fn Element::name(self : Element) -> String {
  self.0.name
}

///|
/// The element's title case name (e.g. `Align`).
pub fn Element::title(self : Element) -> String {
  self.0.title
}

///|
/// The version of Typst the element was introduced in.
pub fn Element::since(self : Element) -> Since? {
  self.0.since
}

///|
/// Documentation for the element.
pub fn Element::docs(self : Element) -> String {
  self.0.docs
}

///|
/// Search keywords for the element.
pub fn Element::keywords(self : Element) -> ArrayView[String] {
  self.0.keywords[:]
}

///|
/// The element's hooks, for registering custom behavior.
pub fn Element::hooks(self : Element) -> ElementHooks {
  self.0.hooks
}

///|
/// All fields of the element.
pub fn Element::fields(self : Element) -> Array[FieldInfo] {
  self.0.fields
}

///|
/// Whether the element has the given capability.
pub fn Element::can(self : Element, capability : String) -> Bool {
  self.0.capabilities.contains(capability)
}

///|
/// Whether the element is locatable.
pub fn Element::is_locatable(self : Element) -> Bool {
  self.can("Locatable")
}

///|
/// Whether the element is unqueriable.
pub fn Element::is_unqueriable(self : Element) -> Bool {
  self.can("Unqueriable")
}

///|
/// Whether the element is tagged.
pub fn Element::is_tagged(self : Element) -> Bool {
  self.can("Tagged")
}

///|
/// The id of the field with the given name (`255` for `label`). Internal and
/// external fields are not found.
pub fn Element::field_id(self : Element, name : String) -> Int? {
  if name == "label" {
    return Some(255)
  }
  for f in self.0.fields {
    if f.name == name && !f.internal && f.kind != External {
      return Some(f.id)
    }
  }
  None
}

///|
/// The name of the field with the given id.
pub fn Element::field_name(self : Element, id : Int) -> String? {
  if id == 255 {
    return Some("label")
  }
  self.0.fields.get(id).map(f => f.name)
}

///|
/// The field info with the given id (non-internal fields only, like
/// upstream's vtable lookup).
pub fn Element::field(self : Element, id : Int) -> FieldInfo? {
  match self.0.fields.get(id) {
    Some(f) if !f.internal => Some(f)
    _ => None
  }
}

///|
/// The element's associated scope of sub-definitions.
pub fn Element::scope(self : Element) -> Scope {
  match self.0.scope {
    Some(s) => s
    None => {
      let s = (self.0.hooks.scope)()
      self.0.scope = Some(s)
      s
    }
  }
}

///|
/// Details about the element's fields as function parameters.
pub fn Element::params(self : Element) -> Array[ParamInfo] {
  match self.0.params {
    Some(p) => p
    None => {
      let params = self.0.fields
        .filter(f => !f.internal && f.kind != Synthesized)
        .map(f => {
          name: f.name,
          docs: f.docs,
          input: f.input,
          default: f.default,
          positional: f.positional,
          named: !f.positional,
          variadic: f.variadic,
          required: f.required,
          settable: f.kind is (Settable | Ghost),
        })
      self.0.params = Some(params)
      params
    }
  }
}

///|
/// Upstream `Repr for Element`.
pub fn Element::repr(self : Element) -> String {
  self.0.name
}

///|
/// Fields relevant for the generated `Construct` impl.
fn FieldInfo::is_construct_field(self : FieldInfo) -> Bool {
  self.kind != External &&
  (self.parse is Some(_) || (self.kind != Synthesized && !self.internal))
}

///|
/// Parse one field from the arguments like upstream's generated code.
fn FieldInfo::parse_arg(
  self : FieldInfo,
  engine : Engine,
  args : Args,
  locals : ParseLocals,
) -> Value? raise SourceError {
  if self.parse is Some(parse) {
    return parse(engine, args, locals)
  }
  if self.variadic {
    let items = args.all_with(self.cast)
    Some(Array(Arr::from_array(items)))
  } else if self.required {
    Some(args.expect_with(self.name, self.cast))
  } else if self.positional {
    args.find_with(self.castable, self.cast)
  } else {
    args.named_with(self.name, self.cast)
  }
}

///|
/// Construct the element from arguments (upstream `Element::construct`).
pub fn Element::construct(
  self : Element,
  engine : Engine,
  args : Args,
) -> Content raise SourceError {
  if self.0.hooks.construct is Some(f) {
    return f(engine, args)
  }
  let values = FixedArray::make(self.0.fields.length(), (None : Value?))
  let locals = ParseLocals::new()
  for f in self.0.fields {
    if f.is_construct_field() {
      values[f.id] = f.parse_arg(engine, args, locals)
    }
  }
  Content::from_fields(self, values)
}

///|
/// Execute the set rule for the element and return the resulting style map.
pub fn Element::set(
  self : Element,
  engine : Engine,
  args : Args,
) -> Styles raise SourceError {
  let styles = self.set_fields(engine, args)
  args.finish()
  styles
}

///|
/// Parse the settable fields from the arguments without checking for
/// leftover arguments (upstream `Set::set`).
pub fn Element::set_fields(
  self : Element,
  engine : Engine,
  args : Args,
) -> Styles raise SourceError {
  match self.0.hooks.set {
    Some(f) => f(engine, args)
    None => {
      let styles = Styles::new()
      let locals = ParseLocals::new()
      for f in self.0.fields {
        if f.is_construct_field() && !f.required {
          if f.parse_arg(engine, args, locals) is Some(value) {
            styles.set(self, f.id, value)
          }
        }
      }
      styles
    }
  }
}

///|
/// The element's local name in a language and region.
pub fn Element::local_name(
  self : Element,
  lang : String,
  region : String?,
) -> String? {
  self.0.hooks.local_name.map(f => f(lang, region))
}

///|
/// Create a selector for this element.
pub fn Element::select(self : Element) -> Selector {
  Elem(self, None)
}

///|
/// Create a selector for this element, filtering for those that fields
/// match the given argument.
pub fn Element::where_(
  self : Element,
  fields : Array[(Int, Value)],
) -> Selector {
  Elem(self, Some(fields))
}

// Argument helpers with dynamic cast functions.

///|
/// [Args::all] with an explicit cast function.
pub fn Args::all_with(
  self : Args,
  cast : (Value) -> Value raise HintedError,
) -> Array[Value] raise SourceError {
  let list = []
  let errors = []
  let kept = []
  for item in self.items {
    if item.name is Some(_) {
      kept.push(item)
      continue
    }
    let span = item.value.span
    try cast(item.value.v) catch {
      HintedError(err) => errors.push(err.into_error_at(span))
    } noraise {
      val => list.push(val)
    }
  }
  self.items.clear()
  self.items.append(kept)
  if !errors.is_empty() {
    raise SourceError(errors)
  }
  list
}

///|
/// [Args::expect] with an explicit cast function.
pub fn Args::expect_with(
  self : Args,
  what : String,
  cast : (Value) -> Value raise HintedError,
) -> Value raise SourceError {
  match self.eat_spanned() {
    Some(value) => at(value.span, () => cast(value.v))
    None => raise SourceError([self.missing_argument(what)])
  }
}

///|
/// [Args::find] with explicit cast functions.
pub fn Args::find_with(
  self : Args,
  castable : (Value) -> Bool,
  cast : (Value) -> Value raise HintedError,
) -> Value? raise SourceError {
  for i, slot in self.items {
    if slot.name is None && castable(slot.value.v) {
      let value = self.items.remove(i).value
      return Some(at(value.span, () => cast(value.v)))
    }
  }
  None
}

///|
/// [Args::named] with an explicit cast function.
pub fn Args::named_with(
  self : Args,
  name : String,
  cast : (Value) -> Value raise HintedError,
) -> Value? raise SourceError {
  let mut i = 0
  let mut found : Value? = None
  while i < self.items.length() {
    if self.items[i].name == Some(name) {
      let value = self.items.remove(i).value
      found = Some(at(value.span, () => cast(value.v)))
    } else {
      i += 1
    }
  }
  found
}

///|
/// Build a field info whose type is `T` (via its cast traits).
pub fn[T : FromValue + IntoValue] field_of(
  ty : Ty[T],
  id~ : Int,
  name~ : String,
  docs~ : String = "",
  kind~ : FieldKind,
  positional~ : Bool = false,
  required~ : Bool = false,
  variadic~ : Bool = false,
  internal~ : Bool = false,
  default? : () -> Value,
  fold? : (Value, Value) -> Value,
  parse? : (Engine, Args, ParseLocals) -> Value? raise SourceError,
  output? : (Value) -> Value,
  eq? : (Value, Value) -> Bool,
) -> FieldInfo {
  {
    id,
    name,
    docs,
    kind,
    positional: positional || required,
    required: required || variadic,
    variadic,
    internal,
    input: () => input_of(ty),
    castable: v => castable_of(ty, v),
    cast: v => IntoValue::into_value((FromValue::from_value(v) : T)),
    default,
    fold,
    parse,
    output,
    eq,
  }
}

///|
/// Whether two stored values of the field are equal (see [FieldInfo::eq]).
pub fn FieldInfo::values_equal(self : FieldInfo, a : Value, b : Value) -> Bool {
  match self.eq {
    Some(f) => f(a, b)
    None => a == b
  }
}

///|
/// The value of a field as shown to users (see [FieldInfo::output]).
pub fn FieldInfo::to_output(self : FieldInfo, value : Value) -> Value {
  match self.output {
    Some(f) => f(value)
    None => value
  }
}

///|
/// An accessor for the given settable field's value in a style chain
/// (upstream `Element::settable_field_accessor`).
pub fn Element::settable_field_accessor(
  self : Element,
  name : String,
) -> ((StyleChain) -> Value)? {
  for f in self.0.fields {
    if f.name == name && !f.internal && f.kind is (Settable | Ghost) {
      // The value is the style chain's own (or a default that all chains
      // share): upstream converts the resolved field into a new value
      // (`IntoValue`), so it is handed out as shared, like a field of
      // content (`Content::field_by_name`).
      return Some(styles => {
        f.to_output(styles.get_value_with_local(self, f, None)).shared()
      })
    }
  }
  None
}

///|
/// Local variables shared between the `#[parse]` hooks of one element
/// construction or set rule (upstream's macro emits all field parsers into
/// one function, so a parser can bind a `let` used by later fields, e.g.
/// `gutter` for `column-gutter` and `row-gutter`).
pub(all) struct ParseLocals(Map[String, Value?])

///|
pub fn ParseLocals::new() -> ParseLocals {
  ParseLocals({})
}

///|
/// Bind a local.
pub fn ParseLocals::set(self : ParseLocals, name : String, v : Value?) -> Unit {
  self.0[name] = v
}

///|
/// Read a local bound by an earlier field's parser (`None` if unbound or
/// bound to `None`).
pub fn ParseLocals::get(self : ParseLocals, name : String) -> Value? {
  match self.0.get(name) {
    Some(v) => v
    None => None
  }
}

// cast! {
//     Element,
//     self => Value::Func(self.into()),
//     v: Func => v.to_element().ok_or("expected element")?,
// }

///|
pub impl Reflect for Element with fn input() {
  Type(Type::func())
}

///|
pub impl Reflect for Element with fn output() {
  Type(Type::func())
}

///|
pub impl Reflect for Element with fn castable(v) {
  Func::castable(v)
}

///|
pub extend Element with Reflect::{output, input, castable}

///|
pub impl IntoValue for Element with fn into_value(self) {
  Func(Func::element(self))
}

///|
pub extend Element with IntoValue::{into_value}

///|
pub impl FromValue for Element with fn from_value(v) {
  match Func::from_value(v).to_element() {
    Some(elem) => elem
    None => bail("expected element")
  }
}

///|
pub extend Element with FromValue::{from_value}

///|
/// A Typst element that is defined by a native type (upstream
/// `NativeElement`): implemented by the generated typed views
/// (`elem_views_gen.mbt`), which wrap content of the element (upstream
/// `Packed<T>`).
pub(open) trait NativeElement {
  /// The element (upstream `NativeElement::ELEM`).
  fn elem() -> Element
  /// Wraps content of this element without checking its element (upstream:
  /// `Packed<T>` is a transparent wrapper around `Content`).
  fn from_content_unchecked(Content) -> Self
  /// The wrapped content (upstream `Packed::pack`).
  fn into_content(Self) -> Content
}

///|
/// View content as the element `T` if it is one (upstream
/// `Content::to_packed`).
pub fn[T : NativeElement] Content::to_packed(self : Content) -> T? {
  if self.elem == T::elem() {
    Some(T::from_content_unchecked(self))
  } else {
    None
  }
}
