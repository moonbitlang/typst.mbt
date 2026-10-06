// Port of `typst-library/src/foundations/symbol.rs` (the `Symbol` type;
// `SymbolElem` lives in `foundations_elems.mbt`).

///|
/// A Unicode symbol.
///
/// Typst defines common symbols so that they can easily be written with
/// standard keyboards. The symbols are defined in modules, from which they
/// can be accessed using field access notation:
///
/// - General symbols are defined in the `sym` module and are accessible
///   without the `sym.` prefix in math mode.
/// - Emoji are defined in the `emoji` module.
///
/// Moreover, you can define custom symbols with this type's constructor
/// function.
pub struct Symbol {
  priv inner : SymbolInner
} derive(Eq, Hash)

///|
/// The internal representation of a [Symbol].
priv enum SymbolInner {
  /// A native symbol that has no named variant.
  Single(String)
  /// A native symbol with multiple named variants.
  Complex(Array[SymbolVariantData])
  /// A symbol that has modifiers applied.
  Modified(Modified)
} derive(Eq, Hash)

///|
/// A symbol with multiple named variants, where some modifiers may have been
/// applied. Also used for symbols defined at runtime by the user with no
/// modifier applied.
priv struct Modified {
  /// The full list of variants.
  list : SymbolList
  /// The modifiers that are already applied.
  modifiers : ModifierSet
  /// Whether we already emitted a deprecation warning for the currently
  /// applied modifiers.
  deprecated : Bool
} derive(Eq, Hash)

///|
/// A collection of symbols (upstream `List`).
priv enum SymbolList {
  Static(Array[SymbolVariantData])
  Runtime(Array[SymbolVariantData])
} derive(Eq, Hash)

///|
/// The characters that are covered by this list.
fn SymbolList::variants(self : SymbolList) -> Array[SymbolVariantData] {
  match self {
    Static(list) => list
    Runtime(list) => list
  }
}

///|
/// Create a new symbol from a single value.
pub fn Symbol::single(value : String) -> Symbol {
  { inner: Single(value), }
}

///|
/// Create a symbol with a static variant list.
pub fn Symbol::list(list : Array[SymbolVariantData]) -> Symbol {
  // Upstream: `debug_assert!(!list.is_empty())` (symbol.rs:98).
  guard! !list.is_empty()
  { inner: Complex(list), }
}

///|
/// Create a symbol from a runtime char.
pub fn Symbol::runtime_char(c : Char) -> Symbol {
  Symbol::runtime([(ModifierSet::default(), c.to_string(), None)])
}

///|
/// Create a symbol with a runtime variant list.
pub fn Symbol::runtime(list : Array[SymbolVariantData]) -> Symbol {
  // Upstream: `debug_assert!(!list.is_empty())` (symbol.rs:110).
  guard! !list.is_empty()
  {
    inner: Modified({
      list: Runtime(list),
      modifiers: ModifierSet::default(),
      deprecated: false,
    }),
  }
}

///|
/// Get the symbol's value.
pub fn Symbol::get(self : Symbol) -> String {
  match self.inner {
    Single(value) => value
    Complex(_) =>
      ModifierSet::default()
      .best_match_in(self.variants().iter().map(v => (v.0, v.1)))
      .unwrap()
    Modified(m) =>
      m.modifiers
      .best_match_in(self.variants().iter().map(v => (v.0, v.1)))
      .unwrap()
  }
}

///|
/// Try to get the function associated with the symbol, if any.
///
/// Fails with upstream's `Uncallable` error otherwise.
pub fn Symbol::func(self : Symbol) -> Func raise HintedError {
  let value = self.get()
  match get_accent_func(value) {
    Some(func) => func
    None =>
      match get_lr_wrapper_func(value) {
        Some(func) => func
        None => bail("symbol \{value} is not callable")
      }
  }
}

///|
/// Apply a modifier to the symbol.
pub fn Symbol::modified(
  self : Symbol,
  guard_ : BindingGuard,
  modifier : String,
) -> Symbol raise HintedError {
  let modified : Modified? = match self.inner {
    Single(_) => None
    Complex(list) =>
      Some({
        list: Static(list),
        modifiers: ModifierSet::default(),
        deprecated: false,
      })
    Modified(m) => Some(m)
  }
  if modified is Some(modified) {
    let modifiers = modified.modifiers.insert_raw(modifier)
    if modifiers.best_match_in(
        modified.list.variants().iter().map(v => (v.0, v.2)),
      )
      is Some(deprecation) {
      // If we already emitted a deprecation warning during a previous
      // modification of the symbol, do not emit another one.
      let mut deprecated = modified.deprecated
      if !deprecated && deprecation is Some(message) {
        deprecated = true
        (guard_.emit)(HintedString::new(message))
      }
      return {
        inner: Modified({ list: modified.list, modifiers, deprecated, }),
      }
    }
  }
  bail("unknown symbol modifier")
}

///|
/// The characters that are covered by this symbol.
pub fn Symbol::variants(self : Symbol) -> Array[SymbolVariantData] {
  match self.inner {
    Single(value) => [(ModifierSet::default(), value, None)]
    Complex(list) => list
    Modified(m) => m.list.variants()
  }
}

///|
/// Possible modifiers.
pub fn Symbol::modifiers(self : Symbol) -> Array[String] {
  let modifiers = match self.inner {
    Modified(m) => m.modifiers
    _ => ModifierSet::default()
  }
  let out : Array[String] = []
  for variant in self.variants() {
    for modifier in variant.0.iter() {
      if !modifier.is_empty() && !modifiers.contains(modifier) {
        out.push(modifier)
      }
    }
  }
  out.sort_by(compare_str)
  out.dedup()
  out
}

///|
/// Create a custom symbol with modifiers.
fn impl_symbol_construct(
  span : @syntax.Span,
  variants : Array[@syntax.Spanned[SymbolVariant]],
) -> Symbol raise SourceError {
  if variants.is_empty() {
    bail_at(span, "expected at least one variant")
  }

  // Maps from canonicalized modifier lists to indices of variants we've seen
  // before.
  let seen : Map[String, Int] = Map([])
  let errors : Array[SourceDiagnostic] = []

  // Validate the variants.
  for i, spanned in variants {
    let { v, span, } = spanned
    let modifiers : Array[String] = []
    if v.1.is_empty() || @unicode.graphemes(v.1).length() > 1 {
      errors.push(
        SourceDiagnostic::error_at(
          span,
          "invalid variant value: \{repr_str(v.1)}",
        ).with_hint("variant value must be exactly one grapheme cluster"),
      )
    }
    if !v.0.is_empty() {
      // Collect all modifiers.
      let mut invalid = false
      for modifier in v.0.split(".") {
        let modifier = modifier.to_owned()
        if !@syntax.is_ident(modifier) {
          errors.push(
            SourceDiagnostic::error_at(
              span,
              "invalid symbol modifier: \{repr_str(modifier)}",
            ),
          )
          invalid = true
          break
        }
        modifiers.push(modifier)
      }
      if invalid {
        continue
      }
    }

    // Canonicalize the modifier order.
    modifiers.sort_by(compare_str)

    // Ensure that there are no duplicate modifiers.
    let mut duplicate : String? = None
    for j in 1..<modifiers.length() {
      if modifiers[j - 1] == modifiers[j] {
        duplicate = Some(modifiers[j])
        break
      }
    }
    if duplicate is Some(m) {
      errors.push(
        SourceDiagnostic::error_at(
          span,
          "duplicate modifier within variant: \{repr_str(m)}",
        ).with_hint(
          "modifiers are not ordered, so each one may appear only once",
        ),
      )
      continue
    }

    // Check whether we had this set of modifiers before.
    let key = modifiers.join(".")
    if seen.get(key) is Some(j) {
      errors.push(
        if v.0.is_empty() {
          SourceDiagnostic::error_at(span, "duplicate default variant")
        } else if v.0 == variants[j].v.0 {
          SourceDiagnostic::error_at(
            span,
            "duplicate variant: \{repr_str(v.0)}",
          )
        } else {
          SourceDiagnostic::error_at(
            span,
            "duplicate variant: \{repr_str(v.0)}",
          ).with_hint(
            "variants with the same modifiers are identical, regardless of their order",
          )
        },
      )
      continue
    }
    seen[key] = i
  }
  if !errors.is_empty() {
    raise SourceError(errors)
  }
  let list : Array[SymbolVariantData] = variants.map(s => {
    (ModifierSet::from_raw_dotted(s.v.0), s.v.1, None)
  })
  Symbol::runtime(list)
}

///|
/// Upstream `Display for Symbol`.
pub impl Show for Symbol with fn output(self, logger) {
  logger.write_string(self.get())
}

///|
/// Upstream `Repr for Symbol`.
pub fn Symbol::repr(self : Symbol) -> String {
  match self.inner {
    Single(value) => "symbol(" + repr_str(value) + ")"
    Complex(variants) =>
      "symbol" + repr_variants(variants, ModifierSet::default())
    Modified({ list, modifiers, .. }) =>
      if modifiers.is_empty() {
        "symbol" + repr_variants(list.variants(), ModifierSet::default())
      } else {
        "symbol" + repr_variants(list.variants(), modifiers)
      }
  }
}

///|
fn repr_variants(
  variants : Array[SymbolVariantData],
  applied_modifiers : ModifierSet,
) -> String {
  let applied = applied_modifiers.iter()
  let parts = []
  for variant in variants {
    let (modifiers, value, _) = variant
    // Only keep variants that can still be accessed, i.e., variants that
    // contain all applied modifiers.
    if !applied.iter().all(am => modifiers.contains(am)) {
      continue
    }
    let trimmed_modifiers = modifiers
      .iter()
      .filter(m => !applied_modifiers.contains(m))
    if trimmed_modifiers.iter().all(m => m.is_empty()) {
      parts.push(repr_str(value))
    } else {
      let trimmed_modifiers = trimmed_modifiers.join(".")
      parts.push("(\{repr_str(trimmed_modifiers)}, \{repr_str(value)})")
    }
  }
  pretty_array_like(parts, false)
}

///|
/// A value that can be cast to a symbol.
pub(all) struct SymbolVariant(String, String)

///|
pub impl Reflect for SymbolVariant with fn input() {
  input_of((Ty::new() : Ty[String])).union_with(input_of((Ty::new() : Ty[Arr])))
}

///|
pub impl Reflect for SymbolVariant with fn output() {
  output_of((Ty::new() : Ty[String])).union_with(
    output_of((Ty::new() : Ty[Arr])),
  )
}

///|
pub impl Reflect for SymbolVariant with fn castable(v) {
  reflect_castable((Ty::new() : Ty[String]), v) ||
  reflect_castable((Ty::new() : Ty[Arr]), v)
}

///|
pub extend SymbolVariant with Reflect::{output, input, castable}

///|
/// Whether the value can be cast to `T` (upstream `T::castable`).
fn[T : Reflect] reflect_castable(_ : Ty[T], v : Value) -> Bool {
  T::castable(v)
}

///|
pub impl FromValue for SymbolVariant with fn from_value(v) {
  if reflect_castable((Ty::new() : Ty[String]), v) {
    let s : String = v.cast()
    return SymbolVariant("", s)
  }
  if reflect_castable((Ty::new() : Ty[Arr]), v) {
    let array : Arr = v.cast()
    let items = array.items
    if items.length() == 2 {
      return SymbolVariant(items[0].cast(), items[1].cast())
    }
    bail("variant array must contain exactly two entries")
  }
  raise HintedError(SymbolVariant::input().error(v))
}

///|
pub impl Reflect for Symbol with fn input() {
  Type(Type::symbol())
}

///|
pub impl Reflect for Symbol with fn output() {
  Type(Type::symbol())
}

///|
pub impl Reflect for Symbol with fn castable(v) {
  v is Symbol(_)
}

///|
pub impl IntoValue for Symbol with fn into_value(self) {
  Symbol(self)
}

///|
pub impl FromValue for Symbol with fn from_value(v) {
  match v {
    Symbol(s) => s
    v => cast_fail_with(Type(Type::symbol()), v)
  }
}
