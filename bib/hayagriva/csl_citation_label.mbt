// Port of `hayagriva/src/csl/citation_label.rs`: alphanumeric labels for
// citations.

///|
/// Citation labels in the form of numbers.
///
/// For example, the output could be Rass97 or MKG+21. Corresponds to
/// LaTeX's `alphabetical` style.
pub(all) struct Alphanumerical {
  /// Defines how many letters are allowed to describe an entry.
  letters : Int
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Alphanumerical with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Alphanumerical with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Alphanumerical with @debug.Debug::{to_repr}

///|
/// Create a new instance.
pub fn Alphanumerical::new() -> Alphanumerical {
  { letters: 3, }
}

///|
/// The first `n` graphemes of a string.
fn take_graphemes(s : String, n : Int) -> String {
  let out = StringBuilder()
  for i, g in @unicode.graphemes(s) {
    if i >= n {
      break
    }
    out.write_string(g.to_owned())
  }
  out.to_string()
}

///|
fn Alphanumerical::creators(self : Alphanumerical, entry : Entry) -> String {
  let creators = get_creators(entry)
  match creators.length() {
    0 => {
      let pseudo_creator = match entry.organization() {
        Some(org) => org.to_string()
        None =>
          match entry.get_full().title() {
            Some(title) => title.value.to_string()
            None => {
              let b = StringBuilder()
              for c in entry.key {
                if @unscanny.is_alphabetic(c) {
                  b.write_char(c)
                }
              }
              b.to_string()
            }
          }
      }
      take_graphemes(pseudo_creator, self.letters)
    }
    1 => take_graphemes(creators[0].name, self.letters)
    2 | 3 => {
      let b = StringBuilder()
      for person in creators {
        if @unicode.graphemes(person.name).get(0) is Some(g) {
          b.write_string(g.to_owned())
        }
      }
      b.to_string()
    }
    _ => take_graphemes(creators[0].name, self.letters) + "+"
  }
}

///|
fn Alphanumerical::year(entry : Entry) -> String? {
  let date = match entry.date_any() {
    Some(d) => Some(d)
    None =>
      match entry.url_any() {
        Some(u) => u.visit_date
        None => None
      }
  }
  date.map(date => {
    let mut year = (date.year % 100).abs()
    if date.year <= 0 {
      year += 1
    }
    int_zero_pad(year.to_int64(), 2)
  })
}

///|
/// The label for an entry.
pub fn Alphanumerical::citation(self : Alphanumerical, entry : Entry) -> String {
  let full_entry = entry.get_full()
  let creators = self.creators(full_entry)
  match Alphanumerical::year(full_entry) {
    Some(year) => creators + year
    None => creators
  }
}

///|
/// Get the creator of an entry.
fn get_creators(entry : Entry) -> Array[Person] {
  if entry.authors() is Some(authors) {
    authors
  } else if entry.editors() is Some(eds) {
    eds
  } else if entry.entry_type == Video {
    let tv_series = sel_anc(
      Attr(sel_ty(Video), ["issue", "volume"]),
      sel_bind("p", sel_ty(Video)),
    )
    match tv_series.apply(entry) {
      Some(bindings) => {
        let affs = entry.affiliated_with_role(Director)
        affs.append(entry.affiliated_with_role(Writer))
        if !affs.is_empty() {
          affs
        } else {
          let parent = bindings.get("p").unwrap()
          parent.affiliated_with_role(ExecutiveProducer)
        }
      }
      None => {
        let dir = entry.affiliated_with_role(Director)
        if !dir.is_empty() {
          dir
        } else {
          entry.affiliated_with_role(ExecutiveProducer)
        }
      }
    }
  } else {
    let compilers = entry.affiliated_with_role(Compiler)
    if !compilers.is_empty() {
      return compilers
    }
    entry.affiliated_with_role(Translator)
  }
}
