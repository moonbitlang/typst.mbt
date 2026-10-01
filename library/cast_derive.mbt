// Helpers for hand-ported `#[derive(Cast)]` enums and `cast!` string
// patterns (upstream `typst-macros/src/cast.rs`).
//
// A derived enum casts from and to the kebab-case names of its variants:
// its input is the union of `CastInfo::Value(name)` (a single info if there
// is only one), it is castable from a `Value::Str` with one of the names,
// and failing casts report `Self::input().error(value)`.

///|
/// The input cast info of string patterns (upstream: the sum of
/// `CastInfo::Value(name.into_value(), docs)`).
fn str_names_input(names : ArrayView[String]) -> CastInfo {
  let mut info : CastInfo? = None
  for name in names {
    let next = CastInfo::Value(Str(name), "")
    info = Some(
      match info {
        None => next
        Some(info) => info.union_with(next)
      },
    )
  }
  info.unwrap_or(Union([]))
}

///|
/// The index of the string pattern that matches the value, if any.
fn str_names_find(names : ArrayView[String], value : Value) -> Int? {
  match value {
    Str(s) => {
      for i, name in names {
        if name == s {
          return Some(i)
        }
      }
      None
    }
    _ => None
  }
}

///|
/// Run `f`, appending `hint` to its error (upstream `.hint(..)` on a
/// `HintedStrResult`).
fn[T] with_err_hint(
  f : () -> T raise HintedError,
  hint : String,
) -> T raise HintedError {
  f() catch {
    HintedError(err) => {
      err.hint(hint)
      raise HintedError(err)
    }
  }
}

///|
/// Take a key from a dictionary and cast it, if present (upstream
/// `dict.take(key).ok().map(|v| v.cast()).transpose()`).
fn[T : FromValue] dict_take_cast(
  dict : Dict,
  key : String,
) -> T? raise HintedError {
  if dict.contains(key) {
    Some(T::from_value(dict.take(key)))
  } else {
    None
  }
}
