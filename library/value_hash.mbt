// Structural identity hashing ([Fingerprint]) of values, content and styles,
// following upstream's `Hash` impls (`foundations/value.rs`,
// `foundations/content/raw.rs`, `foundations/styles.rs`, ...).
//
// Note that this differs from Typst equality: `0` and `0.0` differ, and
// content hashes include the span, label, location and lifecycle in
// addition to all stored fields (also synthesized and internal ones).

///|
pub impl Fingerprint for @syntax.Span with fn fingerprint(self, state) {
  state.write_u64(self.0)
}

///|
pub impl Fingerprint for @syntax.VirtualPath with fn fingerprint(self, state) {
  state.write_str(self.get_with_slash())
}

///|
pub impl Fingerprint for Label with fn fingerprint(self, state) {
  state.write_str(self.0)
}

///|
pub impl Fingerprint for Element with fn fingerprint(self, state) {
  // Elements are compared by identity; their keys are unique (their names
  // are not: `grid.cell` and `table.cell` are both `cell`).
  state.write_str(self.0.key)
}

///|
pub impl Fingerprint for NonZeroUSize with fn fingerprint(self, state) {
  state.write_i64(self.0)
}

///|
pub impl Fingerprint for HintedString with fn fingerprint(self, state) {
  state.write_str(self.message)
  state.write(self.hints)
}

///|
pub impl Fingerprint for SourceDiagnostic with fn fingerprint(self, state) {
  state.write_leaf(self.message, self)
  for hint in self.hints {
    state.write_str(hint.v)
  }
}

///|
pub impl Fingerprint for Length with fn fingerprint(self, state) {
  state.write_f64(self.abs.to_raw())
  state.write_f64(self.em.get())
}

///|
pub impl Fingerprint for Value with fn fingerprint(self, state) {
  match self {
    None => state.write_discriminant(0)
    Auto => state.write_discriminant(1)
    Bool(v) => {
      state.write_discriminant(2)
      state.write_bool(v)
    }
    Int(v) => {
      state.write_discriminant(3)
      state.write_i64(v)
    }
    Float(v) => {
      state.write_discriminant(4)
      state.write_f64(v)
    }
    Length(v) => {
      state.write_discriminant(5)
      state.write(v)
    }
    Angle(v) => {
      state.write_discriminant(6)
      state.write_f64(v.to_raw())
    }
    Ratio(v) => {
      state.write_discriminant(7)
      state.write_f64(v.get())
    }
    Relative(v) => {
      state.write_discriminant(8)
      state.write_f64(v.rel.get())
      state.write(v.abs)
    }
    Fraction(v) => {
      state.write_discriminant(9)
      state.write_f64(v.get())
    }
    Color(v) => {
      state.write_discriminant(10)
      state.write(v)
    }
    Gradient(v) => {
      state.write_discriminant(11)
      state.write(v)
    }
    Tiling(v) => {
      state.write_discriminant(12)
      state.write(v)
    }
    Symbol(v) => {
      state.write_discriminant(13)
      state.write(v)
    }
    Version(v) => {
      state.write_discriminant(14)
      state.write(v.0)
    }
    Str(v) => {
      state.write_discriminant(15)
      state.write_str(v)
    }
    Bytes(v) => {
      state.write_discriminant(16)
      state.write_usize(v.0.length())
      state.write_bytes(v.0)
    }
    Label(v) => {
      state.write_discriminant(17)
      state.write(v)
    }
    Datetime(v) => {
      state.write_discriminant(18)
      state.write_leaf(v.repr(), v)
    }
    Decimal(v) => {
      state.write_discriminant(19)
      state.write_leaf(v.repr(), v)
    }
    Duration(v) => {
      state.write_discriminant(20)
      // Upstream derives `Hash` over `time::Duration`: seconds and
      // nanoseconds (the repr only shows whole seconds).
      state.write_i64(v.0.whole_seconds())
      state.write_usize(v.0.subsec_nanoseconds())
    }
    Content(v) => {
      state.write_discriminant(21)
      state.write(v)
    }
    Styles(v) => {
      state.write_discriminant(22)
      state.write(v)
    }
    Array(v) => {
      state.write_discriminant(23)
      state.write(v.items)
    }
    Dict(v) => {
      state.write_discriminant(24)
      state.write(v)
    }
    Func(v) => {
      state.write_discriminant(25)
      state.write(v)
    }
    Args(v) => {
      state.write_discriminant(26)
      state.write(v)
    }
    Type(v) => {
      state.write_discriminant(27)
      state.write(v)
    }
    Module(v) => {
      state.write_discriminant(28)
      state.write(v)
    }
    Dyn(v) => {
      state.write_discriminant(29)
      state.write(v)
    }
  }
}

///|
/// Upstream derives `Hash` for `Symbol`: a single value, a list of variants
/// or a list with applied modifiers, including the variants that the
/// modifiers have ruled out (which the repr does not show).
pub impl Fingerprint for Symbol with fn fingerprint(self, state) {
  match self.inner {
    Single(value) => {
      state.write_discriminant(0)
      state.write_str(value)
    }
    Complex(variants) => {
      state.write_discriminant(1)
      fingerprint_symbol_variants(state, variants)
    }
    Modified({ list, modifiers, deprecated, }) => {
      state.write_discriminant(2)
      match list {
        Static(variants) => {
          state.write_discriminant(0)
          fingerprint_symbol_variants(state, variants)
        }
        Runtime(variants) => {
          state.write_discriminant(1)
          fingerprint_symbol_variants(state, variants)
        }
      }
      state.write_str(modifiers.as_str())
      state.write_bool(deprecated)
    }
  }
}

///|
/// `[(ModifierSet<S>, S, Option<S>)]`: modifiers, value and deprecation
/// message of each variant.
fn fingerprint_symbol_variants(
  state : SipHasher128,
  variants : Array[SymbolVariantData],
) -> Unit {
  state.write_usize(variants.length())
  for variant in variants {
    state.write_str(variant.0.as_str())
    state.write_str(variant.1)
    state.write(variant.2)
  }
}

///|
pub impl Fingerprint for Dict with fn fingerprint(self, state) {
  state.write_usize(self.map.length())
  for key, value in self.map {
    state.write_str(key)
    state.write(value)
  }
}

///|
pub impl Fingerprint for Args with fn fingerprint(self, state) {
  state.write(self.span)
  state.write_usize(self.items.length())
  for item in self.items {
    state.write(item.span)
    state.write(item.name)
    state.write(item.value.v)
    state.write(item.value.span)
  }
}

///|
pub impl Fingerprint for Type with fn fingerprint(self, state) {
  state.write_str(self.0.long_name)
}

///|
/// Upstream derives `Hash` for `Module`: the name and the shared inner data
/// (scope, content, file). The inner data is hashed once per module (not
/// upstream; see [LazyFingerprint]).
pub impl Fingerprint for Module with fn fingerprint(self, state) {
  // Modules compare by the identity of their inner data.
  fingerprint_flags.val = fingerprint_flags.val | fingerprint_identity
  state.write(self.name)
  let inner = self.inner
  if inner.hash.write_cached(state) {
    return
  }
  inner.hash.write(state, state => {
    state.write(inner.scope)
    state.write(inner.content)
    match inner.file_id {
      Some(id) => {
        state.write_discriminant(1)
        state.write_u32(id.into_raw().to_uint())
      }
      None => state.write_discriminant(0)
    }
  })
}

///|
/// Upstream `Hash for Scope`: the bindings in order, then `deduplicate` and
/// `category`.
pub impl Fingerprint for Scope with fn fingerprint(self, state) {
  state.write_usize(self.map.length())
  for name, binding in self.map {
    state.write_str(name)
    state.write(binding)
  }
  state.write_bool(self.deduplicate)
  state.write(self.category)
}

///|
/// Upstream derives `Hash` for `Binding`: value, kind, span, `check_access`
/// and the out-of-band info.
pub impl Fingerprint for Binding with fn fingerprint(self, state) {
  state.write(self.value)
  match self.kind {
    Normal => state.write_discriminant(0)
    Captured(capturer) => {
      state.write_discriminant(1)
      state.write_discriminant(
        match capturer {
          Function => 0
          Context => 1
        },
      )
    }
  }
  state.write(self.span)
  state.write_bool(self.check_access)
  match self.info {
    None => state.write_discriminant(0)
    Some(info) => {
      state.write_discriminant(1)
      if !info.hash.write_cached(state) {
        info.hash.write(state, state => info.fingerprint_fields(state))
      }
    }
  }
}

///|
/// Upstream derives `Hash` for `BindingInfo`: category, feature, deprecation
/// and documentation.
fn BindingInfo::fingerprint_fields(
  self : BindingInfo,
  state : SipHasher128,
) -> Unit {
  state.write(self.category)
  match self.feature {
    None => state.write_discriminant(0)
    Some(feature) => {
      state.write_discriminant(1)
      state.write_discriminant(
        match feature {
          Html => 0
          Bundle => 1
          A11yExtras => 2
        },
      )
    }
  }
  match self.deprecation {
    None => state.write_discriminant(0)
    Some(deprecation) => {
      state.write_discriminant(1)
      state.write_str(deprecation.message)
      state.write(deprecation.until)
    }
  }
  match self.documentation {
    None => state.write_discriminant(0)
    Some(documentation) => {
      state.write_discriminant(1)
      state.write_str(documentation.name)
      state.write_str(documentation.title)
      state.write_str(documentation.docs)
    }
  }
}

///|
pub impl Fingerprint for Category with fn fingerprint(self, state) {
  state.write_discriminant(
    match self {
      Foundations => 0
      Introspection => 1
      Layout => 2
      DataLoading => 3
      Math => 4
      Model => 5
      Symbols => 6
      Text => 7
      Visualize => 8
      Format => 9
      Pdf => 10
      Html => 11
      Svg => 12
      Png => 13
      Bundle => 14
    },
  )
}

///|
pub impl Fingerprint for Func with fn fingerprint(self, state) {
  match self.inner {
    Native(data) => {
      state.write_discriminant(0)
      state.write_str(data.name)
      state.write_str(data.title)
      state.write_str(data.docs)
    }
    Element(elem) => {
      state.write_discriminant(1)
      state.write(elem)
    }
    Closure(closure) => {
      // Closures compare by identity.
      fingerprint_flags.val = fingerprint_flags.val | fingerprint_identity
      state.write_discriminant(2)
      // Upstream `Arc<LazyHash<Closure>>`: the derived `Hash for Closure`
      // (syntax node, defaults, captured scope with its bindings, number
      // of positional parameters), computed once per closure.
      if !closure.hash.write_cached(state) {
        closure.hash.write(state, state => {
          match closure.node {
            Closure(node) => {
              state.write_discriminant(0)
              node.hash_into(state)
            }
            Context(node) => {
              state.write_discriminant(1)
              node.hash_into(state)
            }
          }
          state.write(closure.defaults)
          state.write(closure.captured)
          state.write_usize(closure.num_pos_params)
        })
      }
    }
    Plugin(func) => {
      state.write_discriminant(3)
      state.write(func)
    }
    With(func, args) => {
      state.write_discriminant(4)
      state.write(func)
      state.write(args)
    }
    Host(host) => {
      // Host closures compare by identity; the key identifies them. A
      // collector (see `fingerprint_hosts_in`) also receives the closure
      // itself.
      fingerprint_flags.val = fingerprint_flags.val |
        fingerprint_identity |
        fingerprint_host
      if fingerprint_hosts.val is Some(hosts) {
        hosts.push(host)
      }
      state.write_discriminant(5)
      state.write(host.key)
    }
  }
  state.write(self.span)
}

///|
/// Upstream `Hash for RawContent`: the element, the metadata (label,
/// location, lifecycle), all stored fields and the span.
pub impl Fingerprint for Content with fn fingerprint(self, state) {
  state.write(self.elem)
  // Meta.
  state.write(self.label)
  state.write(self.location)
  let lifecycle = self.lifecycle.copy()
  lifecycle.sort()
  state.write(lifecycle)
  // Data (hashed once and cached, like upstream).
  let cached = match self.data_hash.val {
    // A collector of host closures must visit the fields that hold some.
    Some((_, flags)) if fingerprint_hosts.val is Some(_) &&
      (flags & fingerprint_host) != 0 => Option::None
    cached => cached
  }
  let data = match cached {
    Some((h, flags)) => {
      mark_fingerprint_flags(flags)
      h
    }
    None => {
      let inner = SipHasher128::new()
      let flags = fingerprint_flags_in(() => {
        inner.write_usize(self.fields.length())
        for field in self.fields {
          inner.write(field)
        }
      })
      let h = inner.finish128()
      self.data_hash.val = Some((h, flags))
      h
    }
  }
  state.write_u128(data)
  state.write(self.span)
}

///|
pub impl Fingerprint for Styles with fn fingerprint(self, state) {
  state.write(self.items)
}

///|
pub impl Fingerprint for Style with fn fingerprint(self, state) {
  match self {
    Property(p) => {
      state.write_discriminant(0)
      state.write(p.elem)
      state.write_usize(p.id)
      state.write(p.value)
      state.write(p.span)
      state.write_bool(p.liftable)
      state.write_bool(p.outside)
    }
    Recipe(r) => {
      state.write_discriminant(1)
      state.write(r.selector)
      state.write(r.transform)
      state.write(r.span)
      state.write_bool(r.outside)
    }
    Revocation(index) => {
      state.write_discriminant(2)
      state.write_usize(index)
    }
  }
}

///|
pub impl Fingerprint for Transformation with fn fingerprint(self, state) {
  match self {
    Content(c) => {
      state.write_discriminant(0)
      state.write(c)
    }
    Func(f) => {
      state.write_discriminant(1)
      state.write(f)
    }
    Style(s) => {
      state.write_discriminant(2)
      state.write(s)
    }
  }
}

///|
pub impl Fingerprint for Selector with fn fingerprint(self, state) {
  match self {
    Elem(elem, fields) => {
      state.write_discriminant(0)
      state.write(elem)
      state.write(fields)
    }
    Location(loc) => {
      state.write_discriminant(1)
      state.write(loc)
    }
    Label(label) => {
      state.write_discriminant(2)
      state.write(label)
    }
    Regex(regex) => {
      state.write_discriminant(3)
      state.write_str(regex.as_str())
    }
    Can(cap) => {
      state.write_discriminant(4)
      state.write_str(cap)
    }
    Or(selectors) => {
      state.write_discriminant(5)
      state.write(selectors)
    }
    And(selectors) => {
      state.write_discriminant(6)
      state.write(selectors)
    }
    Before(selector~, end~, inclusive~) => {
      state.write_discriminant(7)
      state.write(selector)
      state.write(end)
      state.write_bool(inclusive)
    }
    After(selector~, start~, inclusive~) => {
      state.write_discriminant(8)
      state.write(selector)
      state.write(start)
      state.write_bool(inclusive)
    }
    Within(selector~, ancestor~) => {
      state.write_discriminant(9)
      state.write(selector)
      state.write(ancestor)
    }
  }
}

///|
pub impl Fingerprint for Numbering with fn fingerprint(self, state) {
  match self {
    Pattern(pattern) => {
      state.write_discriminant(0)
      state.write(pattern.into_value())
    }
    Func(func) => {
      state.write_discriminant(1)
      state.write(func)
    }
  }
}

///|
pub impl Fingerprint for Counter with fn fingerprint(self, state) {
  state.write(self.0)
}

///|
pub impl Fingerprint for CounterKey with fn fingerprint(self, state) {
  match self {
    Page => state.write_discriminant(0)
    Selector(selector) => {
      state.write_discriminant(1)
      state.write(selector)
    }
    Str(s) => {
      state.write_discriminant(2)
      state.write_str(s)
    }
  }
}

///|
pub impl Fingerprint for CounterState with fn fingerprint(self, state) {
  state.write(self.0)
}

///|
pub impl Fingerprint for CounterUpdate with fn fingerprint(self, state) {
  match self {
    Set(s) => {
      state.write_discriminant(0)
      state.write(s)
    }
    Step(level) => {
      state.write_discriminant(1)
      state.write(level)
    }
    Func(func) => {
      state.write_discriminant(2)
      state.write(func)
    }
  }
}

///|
pub impl Fingerprint for State with fn fingerprint(self, state) {
  state.write_str(self.key)
  state.write(self.init)
}

///|
pub impl Fingerprint for StateUpdate with fn fingerprint(self, state) {
  match self {
    Set(value) => {
      state.write_discriminant(0)
      state.write(value)
    }
    Func(func) => {
      state.write_discriminant(1)
      state.write(func)
    }
  }
}

///|
pub impl Fingerprint for DynValue with fn fingerprint(self, state) {
  // Also hash the type since dynamic values with different types but equal
  // data should be different.
  state.write_str(self.ty().0.long_name)
  match self {
    Counter(v) => state.write(v)
    State(v) => state.write(v)
    Location(v) => state.write(v)
    Selector(v) => state.write(v)
    CounterUpdate(v) => {
      state.write_discriminant(1)
      state.write(v)
    }
    StateUpdate(v) => {
      state.write_discriminant(2)
      state.write(v)
    }
    Tag(v) => {
      state.write_discriminant(3)
      state.write(v)
    }
    CellGrid(v) => {
      state.write_discriminant(4)
      state.write(v)
    }
    InlineCallback(v) => {
      state.write_discriminant(5)
      state.write(v.captured())
    }
    BlockSingleCallback(v) => {
      state.write_discriminant(6)
      state.write(v.captured())
    }
    BlockMultiCallback(v) => {
      state.write_discriminant(7)
      state.write(v.captured())
    }
    Decoration(v) => {
      state.write_discriminant(8)
      state.write(v)
    }
    Loaded(v) => {
      state.write_discriminant(9)
      state.write(v)
    }
    // Upstream `#[derive(Hash)]` of `RawContent`: the lines with their
    // spans. (`Text` is stored as a string value.)
    RawContent(v) => {
      state.write_discriminant(10)
      match v {
        Text(text) => {
          state.write_discriminant(0)
          state.write_str(text)
        }
        Lines(lines) => {
          state.write_discriminant(1)
          state.write_usize(lines.length())
          for line in lines {
            state.write_str(line.0)
            state.write(line.1)
          }
        }
      }
    }
    Regex(v) => state.write_str(v.as_str())
    Alignment(v) => state.write_leaf(v.repr(), v)
    Dir(v) => state.write_leaf(v.repr(), v)
    SpotColorant(v) => state.write(v)
    Stroke(v) => state.write(v)
    RootedPath(v) => {
      match v.root() {
        Project => state.write_discriminant(0)
        Package(spec) => {
          state.write_discriminant(1)
          state.write_str(spec.namespace)
          state.write_str(spec.name)
          state.write_u32(spec.version.major)
          state.write_u32(spec.version.minor)
          state.write_u32(spec.version.patch)
        }
      }
      state.write(v.vpath())
    }
    HtmlCss(v) => {
      state.write_usize(v.length())
      for property in v.iter() {
        state.write_str(property.name)
        state.write_str(property.value)
      }
    }
  }
}
