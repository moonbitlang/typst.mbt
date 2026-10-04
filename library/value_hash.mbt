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
  // Elements are compared by identity and their names are unique.
  state.write_str(self.name())
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
      state.write_leaf(v.repr(), v)
    }
    Gradient(v) => {
      state.write_discriminant(11)
      state.write_str(v.repr())
      // The repr rounds numbers.
      mark_fingerprint_lossy()
    }
    Tiling(v) => {
      state.write_discriminant(12)
      // Upstream hashes the laid out frame; frames have no fingerprint, so
      // only its size and item count are written.
      state.write_str(v.repr())
      state.write_usize(v.frame.items().length())
      mark_fingerprint_lossy()
    }
    Symbol(v) => {
      state.write_discriminant(13)
      state.write_leaf(v.repr(), v)
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
      state.write_leaf(v.repr(), v)
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
      v.fingerprint_with_depth(state, 0)
    }
    Dyn(v) => {
      state.write_discriminant(29)
      state.write(v)
    }
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
/// Modules can (indirectly) contain themselves (e.g. `std`), so nested
/// modules are only hashed by name and file.
fn Module::fingerprint_with_depth(
  self : Module,
  state : SipHasher128,
  depth : Int,
) -> Unit {
  state.write(self.name)
  match self.inner.file_id {
    Some(id) => {
      state.write_discriminant(1)
      state.write_u32(id.into_raw().to_uint())
    }
    None => state.write_discriminant(0)
  }
  if depth == 0 {
    state.write(self.inner.content)
    self.inner.scope.fingerprint_with_depth(state, depth + 1)
  }
}

///|
fn Scope::fingerprint_with_depth(
  self : Scope,
  state : SipHasher128,
  depth : Int,
) -> Unit {
  state.write_usize(self.map.length())
  for name, binding in self.map {
    state.write_str(name)
    match binding.value {
      Module(m) => {
        state.write_discriminant(28)
        m.fingerprint_with_depth(state, depth)
      }
      value => state.write(value)
    }
  }
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
      let node = match closure.node {
        Closure(node) => {
          state.write_discriminant(0)
          node
        }
        Context(node) => {
          state.write_discriminant(1)
          node
        }
      }
      state.write(node.span())
      state.write_str(node.full_text())
      state.write(closure.defaults)
      closure.captured.fingerprint_with_depth(state, 1)
      state.write_usize(closure.num_pos_params)
    }
    With(func, args) => {
      state.write_discriminant(3)
      state.write(func)
      state.write(args)
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
  let data = match self.data_hash.val {
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
    Regex(v) => state.write_str(v.as_str())
    Alignment(v) => state.write_leaf(v.repr(), v)
    Dir(v) => state.write_leaf(v.repr(), v)
    other => {
      state.write_str(other.repr())
      // The repr may round numbers or abbreviate (e.g. strokes with
      // tilings).
      mark_fingerprint_lossy()
    }
  }
}
