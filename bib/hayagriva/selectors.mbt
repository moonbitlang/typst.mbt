// Port of `hayagriva/src/selectors/mod.rs`: filtering bibliographies by
// structural selection. (The textual selector parser is not ported; the
// selectors used internally are constructed directly.)

///|
/// A selector used to filter bibliographies and match on entries.
pub(all) enum Selector {
  /// A wildcard selector: `*`.
  Wildcard
  /// An entry type literal: `report`.
  Entry(EntryType)
  /// A negation: `!x`.
  Neg(Selector)
  /// A binding: `x:misc`.
  Binding(String, Selector)
  /// An attribute filtering: `abc[att1, attr2]`.
  Attr(Selector, Array[String])
  /// An alternate selector: `a | b`.
  Alt(Array[Selector])
  /// A multi-parent selector: `a & b`.
  Multi(Array[Selector])
  /// An ancestrage selector: `a > b`.
  Ancestrage(Selector, Selector)
} derive(Eq, Debug)

///|
/// Checks if the selector matches the provided [`Entry`].
pub fn Selector::matches(self : Selector, entry : Entry) -> Bool {
  self.apply(entry) is Some(_)
}

///|
/// Applies the selector and returns the bound element if there was a match.
pub fn Selector::bound(self : Selector, entry : Entry, bound : String) -> Entry? {
  match self.apply(entry) {
    Some(hm) => hm.get(bound)
    None => None
  }
}

///|
/// Applies the selector to an [`Entry`] and returns the bound variables in
/// a hash map if there was a match.
pub fn Selector::apply(self : Selector, entry : Entry) -> Map[String, Entry]? {
  match self {
    Wildcard => Some(Map([]))
    Entry(entry_type) =>
      if entry.entry_type == entry_type {
        Some(Map([]))
      } else {
        None
      }
    Neg(expr) => if expr.apply(entry) is Some(_) { None } else { Some(Map([])) }
    Binding(binding, expr) =>
      match expr.apply(entry) {
        Some(bound) => {
          bound.set(binding, entry)
          Some(bound)
        }
        None => None
      }
    Attr(expr, attributes) =>
      match expr.apply(entry) {
        Some(bound) =>
          if attributes.iter().all(arg => entry.has(arg)) {
            Some(bound)
          } else {
            None
          }
        None => None
      }
    Alt(exprs) => {
      for expr in exprs {
        let applied = expr.apply(entry)
        if applied is Some(_) {
          return applied
        }
      }
      None
    }
    Multi(_) => None
    Ancestrage(lhs, rhs) =>
      match lhs.apply(entry) {
        Some(bound) =>
          match rhs.apply_any(entry.parents) {
            Some((other, _)) => {
              for k, v in other {
                bound.set(k, v)
              }
              Some(bound)
            }
            None => None
          }
        None => None
      }
  }
}

///|
fn Selector::apply_any(
  self : Selector,
  entries : Array[Entry],
) -> (Map[String, Entry], Array[Entry])? {
  match self {
    Wildcard =>
      if !entries.is_empty() {
        Some((Map([]), entries.copy()))
      } else {
        None
      }
    Entry(_) | Ancestrage(_, _) => {
      for e in entries {
        if self.apply(e) is Some(r) {
          return Some((r, [e]))
        }
      }
      None
    }
    Neg(expr) =>
      if expr.apply_any(entries) is Some(_) {
        None
      } else {
        Some((Map([]), []))
      }
    Binding(binding, expr) =>
      match expr.apply_any(entries) {
        Some((bound, es)) => {
          if es.get(0) is Some(first) {
            bound.set(binding, first)
          }
          Some((bound, []))
        }
        None => None
      }
    Attr(expr, attributes) =>
      match expr.apply_any(entries) {
        Some((bound, es)) =>
          if !es.is_empty() {
            if es
              .iter()
              .any(e => attributes.iter().all(arg => e.has(arg))) {
              Some((bound, es))
            } else {
              None
            }
          } else {
            Some((bound, es))
          }
        None => None
      }
    Alt(exprs) => {
      for expr in exprs {
        let applied = expr.apply_any(entries)
        if applied is Some(_) {
          return applied
        }
      }
      None
    }
    Multi(exprs) => {
      let consumed : Array[Int] = []
      let res : Map[String, Entry] = Map([])
      for spec in exprs {
        let mut item = None
        for i, e in entries {
          if consumed.contains(i) {
            continue
          }
          item = spec.apply(e).map(v => (i, v))
          if item is Some(_) {
            break
          }
        }
        match item {
          Some((index, bound)) => {
            for k, v in bound {
              res.set(k, v)
            }
            consumed.push(index)
          }
          None => return None
        }
      }
      Some((res, consumed.map(i => entries[i])))
    }
  }
}
