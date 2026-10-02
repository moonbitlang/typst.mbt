// Port of `hayagriva/src/csl/sort.rs`.

///|
/// `impl CollationOrd for str`.
fn str_collation_cmp(
  a : String,
  b : String,
  locale : @citationberg.LocaleCode,
) -> Int {
  if icu_locale_parses(locale.0) {
    root_collation_compare(a, b)
  } else {
    @unscanny.compare_str(a, b)
  }
}

///|
/// `impl<T: CollationOrd> CollationOrd for Option<T>`.
fn opt_collation_cmp(
  a : String?,
  b : String?,
  locale : @citationberg.LocaleCode,
) -> Int {
  match (a, b) {
    (Some(a), Some(b)) => str_collation_cmp(a, b, locale)
    (Some(_), None) => 1
    (None, Some(_)) => -1
    (None, None) => 0
  }
}

///|
/// Whether `s` parses as an ICU locale (BCP-47 language identifier with
/// optional extensions; `_` is accepted as a separator).
fn icu_locale_parses(s : String) -> Bool {
  let subtags = @unscanny.split_by(s, c => c == '-' || c == '_')
  guard subtags.get(0) is Some(lang) else { return false }
  let alpha = (t : String) => t.iter().all(c => c.is_ascii_alphabetic())
  let alnum = (t : String) => {
    t.iter().all(c => c.is_ascii_alphabetic() || c.is_ascii_digit())
  }
  let lang_len = lang.length()
  if !(alpha(lang) &&
    (lang_len == 2 || lang_len == 3 || (lang_len >= 5 && lang_len <= 8))) &&
    !(lang == "root" || lang == "und") {
    return false
  }
  for i in 1..<subtags.length() {
    let t = subtags[i]
    if t.length() < 1 || t.length() > 8 || !alnum(t) {
      return false
    }
  }
  true
}

///|
/// Retrieve the ordering of two entries according to the given sort key.
fn StyleContext::cmp_entries(
  self : StyleContext,
  a : CitationItem,
  a_idx : Int,
  b : CitationItem,
  b_idx : Int,
  key : @citationberg.SortKey,
  term_locale : @citationberg.LocaleCode?,
) -> Int {
  let (ordering, empty_value) = match key {
    Variable(variable=Standard(s), ..) => {
      let a = InstanceContext::variable_sort_instance(a, a_idx)
        .resolve_standard_variable(Long, s)
        .map(s => @unscanny.to_lowercase(s.to_str()))
      let b = InstanceContext::variable_sort_instance(b, b_idx)
        .resolve_standard_variable(Long, s)
        .map(s => @unscanny.to_lowercase(s.to_str()))
      (opt_collation_cmp(a, b, self.locale()), a is None || b is None)
    }
    Variable(variable=Date(d), ..) => {
      let a = a.entry.resolve_date_variable(d)
      let b = b.entry.resolve_date_variable(d)
      match (a, b) {
        (Some(a), Some(b)) => (a.csl_cmp(b), false)
        (Some(_), None) => (1, true)
        (None, Some(_)) => (-1, true)
        (None, None) => (0, true)
      }
    }
    Variable(variable=Name(n), ..) => {
      let a = a.entry.resolve_name_variable(n)
      let b = b.entry.resolve_name_variable(n)
      let len = if a.length() < b.length() { a.length() } else { b.length() }
      for i in 0..<len {
        let ord = a[i].csl_cmp(
          b[i],
          Long,
          self.csl.settings.demote_non_dropping_particle != Never,
        )
        if ord != 0 {
          return ord
        }
      }
      (compare_int(a.length(), b.length()), false)
    }
    Variable(variable=Number(n), ..) => {
      let a = InstanceContext::variable_sort_instance(a, a_idx).resolve_number_variable(
        n,
      )
      let b = InstanceContext::variable_sort_instance(b, b_idx).resolve_number_variable(
        n,
      )
      match (a, b) {
        (Some(a), Some(b)) => (a.csl_cmp(b), false)
        (Some(_), None) => (1, true)
        (None, Some(_)) => (-1, true)
        (None, None) => (0, true)
      }
    }
    Variable(variable=Page(pv), ..) => {
      let a = InstanceContext::variable_sort_instance(a, a_idx).resolve_page_variable(
        pv,
      )
      let b = InstanceContext::variable_sort_instance(b, b_idx).resolve_page_variable(
        pv,
      )
      match (a, b) {
        (Some(a), Some(b)) => (MaybeTyped::page_ranges_csl_cmp(a, b), false)
        (Some(_), None) => (1, true)
        (None, Some(_)) => (-1, true)
        (None, None) => (0, true)
      }
    }
    MacroName(name~, names_min~, names_use_first~, names_use_last~, ..) => {
      let render = (entry : CitationItem, idx : Int) => {
        let ctx = self.macro_sorting_ctx(
          entry,
          idx,
          entry.locale,
          term_locale,
          false,
        )
        ctx.writing.name_options.push({
          ..@citationberg.InheritableNameOptions::default(),
          et_al_min: names_min,
          et_al_subsequent_min: names_min,
          et_al_use_first: names_use_first,
          et_al_subsequent_use_first: names_use_first,
          et_al_use_last: names_use_last,
        })
        self
        .get_macro(name)
        .map(m => {
          for child in m.children {
            RenderCsl::render(child, ctx)
          }
          let mut s = ""
          for f in ctx.flush().0 {
            s = s + fmt_to_string(b => f.write_buf(b, Plain))
            s = @unscanny.to_lowercase(s)
          }
          s
        })
      }
      let a_rendered = render(a, a_idx)
      let b_rendered = render(b, b_idx)
      (opt_collation_cmp(a_rendered, b_rendered, self.locale()), false)
    }
  }

  // Per CSL 1.0.2 spec
  // (https://docs.citationstyles.org/en/v1.0.2/specification.html):
  // Entries with empty values are always displayed at the end, even with
  // reversed order. So we always reverse the order if either entry is
  // empty.
  if empty_value || key.sort_direction() == Descending {
    -ordering
  } else {
    ordering
  }
}

///|
/// Sorts the given citation items by the style's sort keys.
fn StyleContext::sort(
  self : StyleContext,
  cites : Array[CitationItem],
  sort : @citationberg.Sort?,
  term_locale : @citationberg.LocaleCode?,
  citation_number : (Entry) -> Int,
) -> Unit {
  guard sort is Some(sort) else { return }
  stable_sort_by(cites, (a, b) => {
    let mut ordering = 0
    for key in sort.keys {
      ordering = self.cmp_entries(
        a,
        citation_number(a.entry),
        b,
        citation_number(b.entry),
        key,
        term_locale,
      )
      if ordering != 0 {
        break
      }
    }
    ordering
  })
}

///|
/// A stable merge sort (Rust's `slice::sort_by` is stable).
fn[T] stable_sort_by(xs : Array[T], cmp : (T, T) -> Int) -> Unit {
  let n = xs.length()
  if n < 2 {
    return
  }
  // Insertion sort for small inputs, merge sort otherwise.
  if n <= 20 {
    for i in 1..<n {
      let x = xs[i]
      let mut j = i
      while j > 0 && cmp(xs[j - 1], x) > 0 {
        xs[j] = xs[j - 1]
        j -= 1
      }
      xs[j] = x
    }
    return
  }
  let mid = n / 2
  let left = xs[0:mid].to_owned()
  let right = xs[mid:].to_owned()
  stable_sort_by(left, cmp)
  stable_sort_by(right, cmp)
  let mut i = 0
  let mut j = 0
  let mut k = 0
  while i < left.length() && j < right.length() {
    if cmp(right[j], left[i]) < 0 {
      xs[k] = right[j]
      j += 1
    } else {
      xs[k] = left[i]
      i += 1
    }
    k += 1
  }
  while i < left.length() {
    xs[k] = left[i]
    i += 1
    k += 1
  }
  while j < right.length() {
    xs[k] = right[j]
    j += 1
    k += 1
  }
}
