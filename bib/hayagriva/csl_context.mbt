// Port of `hayagriva/src/csl/mod.rs` (continued): `Context` and the
// variable resolution of `InstanceContext` (from `csl/taxonomy.rs`).

///|
priv enum NumberVariableResult {
  Regular(MaybeTyped[Numeric])
  Transparent(Int)
}

///|
priv enum NumberOrPageVariableResult {
  Number(NumberVariableResult)
  Page(MaybeTyped[PageRanges])
}

///|
fn NumberVariableResult::csl_cmp(
  self : NumberVariableResult,
  other : NumberVariableResult,
) -> Int {
  match (self, other) {
    (Regular(a), Regular(b)) => MaybeTyped::numeric_csl_cmp(a, b)
    (Regular(_), Transparent(_)) => -1
    (Transparent(_), Regular(_)) => 1
    (Transparent(a), Transparent(b)) => compare_int(a, b)
  }
}

///|
fn InstanceContext::resolve_number_variable(
  self : InstanceContext,
  variable : @citationberg.NumberVariable,
) -> NumberVariableResult? {
  match variable {
    CitationNumber =>
      Some(
        Regular(
          Typed(Numeric::new(self.cite_props.speculative.citation_number + 1)),
        ),
      )
    FirstReferenceNoteNumber =>
      self.cite_props.certain.first_note_number.map(n => {
        NumberVariableResult::Regular(Typed(Numeric::new(n)))
      })
    Locator => {
      guard self.cite_props.speculative.locator
        is Some(SpecificLocator(_, payload)) else {
        return None
      }
      match payload {
        Str(l) =>
          Some(
            Regular(
              match Numeric::from_str(l) {
                Ok(n) => Typed(n)
                Err(_) => String(l)
              },
            ),
          )
        Transparent(_) => Some(Transparent(self.cite_props.certain.initial_idx))
      }
    }
    _ => self.entry.resolve_number_variable(variable).map(r => Regular(r))
  }
}

///|
fn InstanceContext::resolve_page_variable(
  self : InstanceContext,
  variable : @citationberg.PageVariable,
) -> MaybeTyped[PageRanges]? {
  self.entry.resolve_page_variable(variable)
}

///|
// Number variables are standard variables.
fn InstanceContext::resolve_standard_variable(
  self : InstanceContext,
  form : @citationberg.LongShortForm,
  variable : @citationberg.StandardVariable,
) -> ChunkedString? {
  match variable {
    YearSuffix =>
      if self.cite_props.speculative.disambiguation is YearSuffix(s) {
        Some(ChunkedString::from_chunk(StringChunk::normal(letter(s))))
      } else {
        None
      }
    _ => self.entry.resolve_standard_variable(form, variable)
  }
}

///|
/// Push a format on top of the stack if it is not empty.
fn Context::push_format(
  self : Context,
  format : @citationberg.Formatting,
) -> Int {
  self.writing.push_format(format)
}

///|
/// Pop a format from the stack if it is not empty.
fn Context::pop_format(self : Context, pos : Int) -> Unit {
  self.writing.pop_format(pos)
}

///|
/// Add another subtree to the children element. This must be done to
/// include a new element or to check that the subtree is empty.
fn Context::push_elem(
  self : Context,
  format : @citationberg.Formatting,
) -> DisplayLoc {
  self.writing.push_elem(format)
}

///|
/// Remove the last subtree and discard it.
fn Context::discard_elem(self : Context, loc : DisplayLoc) -> Unit {
  self.writing.discard_elem(loc)
}

///|
/// Nest the last subtree into its ancestor.
fn Context::commit_elem(
  self : Context,
  loc : DisplayLoc,
  display : @citationberg.Display?,
  meta : ElemMeta?,
) -> Unit {
  self.writing.commit_elem(loc, display, meta)
}

///|
/// Ensure that the buffer is either empty or the last character is a space.
fn Context::ensure_space(self : Context) -> Unit {
  self.writing.ensure_space()
}

///|
/// Add the appropriate opening quotation marks.
fn Context::push_quotes(self : Context) -> Unit {
  let mark = self.term(
    Other(if self.writing.inner_quotes { OpenInnerQuote } else { OpenQuote }),
    Long,
    false,
  )
  if mark is Some(mark) {
    self.push_str(mark)
  }
  self.writing.inner_quotes = !self.writing.inner_quotes
}

///|
/// Add the appropriate closing quotation marks.
fn Context::pop_quotes(self : Context) -> Unit {
  self.writing.inner_quotes = !self.writing.inner_quotes
  let mark = self.term(
    Other(if self.writing.inner_quotes { CloseInnerQuote } else { CloseQuote }),
    Long,
    false,
  )
  if mark is Some(mark) {
    self.push_str(mark)
  }
}

///|
/// Recursively iterates over `child`. If we reach text, we return its
/// content. If we reach an element with one child, we recursively call the
/// funtion with this child. Otherwise, we return [None].
fn get_last_text(child : ElemChild) -> Formatted? {
  match child {
    Text(formatted) => Some(formatted)
    Elem(e) if e.children.0.length() == 1 => get_last_text(e.children.0[0])
    _ => None
  }
}

///|
/// A mutable view on a string slot (upstream `&mut String`).
priv struct StrSlot {
  get : () -> String
  set : (String) -> Unit
}

///|
fn StrSlot::of_buf(buf : CaseFolder) -> StrSlot {
  { get: () => buf.buf_string(), set: v => buf.set_buf_string(v), }
}

///|
fn StrSlot::of_text(t : Formatted) -> StrSlot {
  { get: () => t.text, set: v => t.text = v, }
}

///|
/// Pull punctuation into a quote if applicable
fn Context::do_pull_punctuation(self : Context, s : String) -> String {
  let mut s = s
  if self.writing.pull_punctuation &&
    (match @unscanny.first_char(s) {
      Some('.' | ',' | ';' | '!' | '?') => true
      _ => false
    }) {
    let close_quote = self.term(Other(CloseQuote), Long, false)
    let close_inner_quote = self.term(Other(CloseInnerQuote), Long, false)
    let mut used_buf = false
    let buf = if self.writing.buf.is_empty() {
      let t = match self.writing.elem_stack.last_predicate(p => !p.is_empty()) {
        Some(p) =>
          match p.0.last() {
            Some(c) => get_last_text(c)
            None => None
          }
        None => None
      }
      match t {
        Some(t) => StrSlot::of_text(t)
        None => {
          used_buf = true
          StrSlot::of_buf(self.writing.buf)
        }
      }
    } else {
      used_buf = true
      StrSlot::of_buf(self.writing.buf)
    }
    for quote in [close_quote, close_inner_quote] {
      guard quote is Some(quote) else { continue }
      // Check if buf ends with a close quote.
      // If it does, replace it with the punctuation.
      let cur = (buf.get)()
      if cur.has_suffix(quote) {
        let head = cur[:cur.length() - quote.length()].to_owned()
        let punctuation = @unscanny.first_char(s).unwrap()
        s = s[punctuation.utf16_len():].to_owned()
        (buf.set)(head + punctuation.to_string() + quote)
        if used_buf {
          self.writing.buf.mark_changed()
        }
        break
      }
    }
  }
  s
}

///|
fn last_buffer(ctx : WritingContext) -> StrSlot? {
  let last = match ctx.elem_stack.last_predicate(s => !s.is_empty()) {
    Some(e) => e.last_text()
    None => None
  }
  if !ctx.buf.is_empty() {
    Some(StrSlot::of_buf(ctx.buf))
  } else if last is Some(last) {
    Some(StrSlot::of_text(last))
  } else {
    None
  }
}

///|
/// Add a string to the buffer.
fn Context::push_str(self : Context, s : String) -> Unit {
  let s = self.do_pull_punctuation(s)
  self.writing.reconfigure()
  let ends_with_space = match last_buffer(self.writing) {
    Some(slot) =>
      match @unscanny.last_char((slot.get)()) {
        Some(c) => @unscanny.is_whitespace(c)
        None => false
      }
    None => false
  }

  // Punctuation eats spaces. Whitespace should be trimmed.
  if ends_with_space &&
    (match @unscanny.first_char(s) {
      Some(c) =>
        @unscanny.is_whitespace(c) ||
        c == '.' ||
        c == ',' ||
        c == ']' ||
        c == ')'
      None => false
    }) &&
    last_buffer(self.writing) is Some(slot) {
    (slot.set)(@unscanny.trim_end((slot.get)()))
  }

  // Do not print duplicate affixes.
  if s.iter().all(c => !@unscanny.is_alphabetic(c)) {
    let trimmed = @unscanny.trim_end(s)
    if last_buffer(self.writing) is Some(slot) {
      let last = (slot.get)()
      if last.has_suffix(trimmed) {
        (slot.set)(last[:last.length() - trimmed.length()].to_owned())
      }
    }
  }
  if self.writing.strip_periods {
    // Replicate citeproc.js behavior: remove a period if the
    // preceding character in the original string is not a period.
    let mut last_period = false
    for c in s {
      let is_period = c == '.'
      if !is_period || last_period {
        self.writing.buf.push(c)
      }
      last_period = is_period
    }
  } else {
    self.writing.buf.push_str(s)
  }
  self.writing.pull_punctuation = false
}

///|
impl FmtWrite for Context with fn write_str(self, s) {
  self.push_str(s)
}

///|
impl FmtWrite for Context with fn write_char(self, c) {
  self.push_str(c.to_string())
}

///|
/// Push a chunked string to the buffer.
fn Context::push_chunked(self : Context, chunked : ChunkedString) -> Unit {
  for chunk in chunked.0 {
    match chunk.kind {
      Normal => self.push_str(chunk.value)
      Verbatim => {
        self.writing.buf.push_verbatim(chunk.value)
        self.writing.pull_punctuation = false
      }
      Math => {
        self.writing.buf.prevent_trimming()
        self.writing.save_to_block()
        self.writing.elem_stack.last.0.push(Markup(chunk.value))
        self.writing.reconfigure()
        self.writing.buf.prevent_trimming()
      }
    }
  }
}

///|
/// Push a link into the buffer.
fn Context::push_link(
  self : Context,
  chunked : ChunkedString,
  url : String,
) -> Unit {
  let format = self.writing.formatting()
  self.writing.save_to_block()
  self.writing.elem_stack.last.0.push(
    Link(text=format.add_text(chunked.to_str()), url~),
  )
}

///|
/// Push a transparent element child into the buffer.
fn Context::push_transparent(self : Context, idx : Int) -> Unit {
  let format = self.writing.formatting()
  self.writing.save_to_block()
  self.writing.elem_stack.last.0.push(Transparent(cite_idx=idx, format~))
}

///|
/// Folds all remaining elements into the first element and returns it.
fn Context::flush(self : Context) -> ElemChildren {
  self.writing.flush()
}

///|
/// Get a term from the style.
fn Context::term(
  self : Context,
  term : @citationberg.Term,
  form : @citationberg.TermForm,
  plural : Bool,
) -> String? {
  let mut term = term
  if term == NumberVariable(Locator) &&
    self.instance.cite_props.speculative.locator
    is Some(SpecificLocator(locator, _)) {
    term = Locator(locator)
  }
  let term = term
  let mut form = Some(form)
  while form is Some(current_form) {
    if self.style.lookup_locale(l => {
        match l.term(term, current_form) {
          Some(term) =>
            Some(if plural { term.multiple() } else { term.single() })
          None => None
        }
      })
      is Some(localization) {
      return localization
    }
    form = current_form.fallback()
  }
  None
}

///|
/// Get the gender of a term.
fn Context::gender(
  self : Context,
  term : @citationberg.Term,
) -> @citationberg.GrammarGender? {
  match self.style.lookup_locale(l => l.term(term, Long)) {
    Some(localization) => localization.gender
    None => None
  }
}

///|
/// Get a localized date format.
fn Context::localized_date(
  self : Context,
  form : @citationberg.DateForm,
) -> @citationberg.Date? {
  self.style.lookup_locale(l => {
    for d in l.date {
      if d.form == Some(form) {
        return Some(d)
      }
    }
    None
  })
}

///|
/// Get the ordinal lookup object.
fn Context::ordinal_lookup(self : Context) -> @citationberg.OrdinalLookup {
  match self.style.lookup_locale(l => l.ordinals()) {
    Some(o) => o
    None => @citationberg.OrdinalLookup::empty()
  }
}

///|
/// Pull the next punctuation character into the preceding quoted content
/// if appropriate for the locale.
fn Context::may_pull_punctuation(self : Context) -> Unit {
  self.writing.pull_punctuation = self.writing.pull_punctuation ||
    self.style.punctuation_in_quotes()
}

///|
/// Set whether to strip periods.
fn Context::may_strip_periods(self : Context, strip : Bool) -> Unit {
  self.writing.may_strip_periods(strip)
}

///|
/// Stop stripping periods.
fn Context::stop_stripping_periods(self : Context) -> Unit {
  self.writing.stop_stripping_periods()
}

///|
/// Set the case of the next text.
fn Context::push_case(self : Context, case_ : @citationberg.TextCase?) -> Int {
  let independent = match case_ {
    None => true
    Some(c) => c.is_language_independent()
  }
  let english = () => {
    let r = opt_or(self.instance.entry.is_english(), () => {
      opt_or(self.instance.locale.map(l => l.is_english()), () => {
        opt_or(self.instance.term_locale.map(l => l.is_english()), () => {
          self.style.csl.default_locale.map(l => l.is_english())
        })
      })
    })
    r.unwrap_or(true)
  }
  if independent || english() {
    self.writing.push_case(case_)
  } else {
    self.writing.push_case(None)
  }
}

///|
/// Clear the case of the next text.
fn Context::pop_case(self : Context, idx : Int) -> Unit {
  self.writing.pop_case(idx)
}

///|
/// Resolve a number variable.
///
/// Honors suppressions.
fn Context::resolve_number_variable(
  self : Context,
  variable : @citationberg.NumberVariable,
) -> NumberVariableResult? {
  // Replace the citation label with citation number if necessary.
  if variable == CitationNumber {
    if self.bibliography {
      if self.instance.identifier_usage == OnlyCitationLabel {
        return self.instance
          .resolve_standard_variable(Long, CitationLabel)
          .map(c => Regular(String(c.to_str())))
      }
    } else {
      self.instance.identifier_usage = self.instance.identifier_usage.number()
    }
  }
  guard self.writing.prepare_variable_query(Number(variable)) is Some(_) else {
    return None
  }
  self.instance.resolve_number_variable(variable)
}

///|
fn Context::resolve_page_variable(
  self : Context,
  variable : @citationberg.PageVariable,
) -> MaybeTyped[PageRanges]? {
  guard self.writing.prepare_variable_query(Page(variable)) is Some(_) else {
    return None
  }
  self.instance.resolve_page_variable(variable)
}

///|
fn Context::resolve_number_or_page_variable(
  self : Context,
  variable : @citationberg.NumberOrPageVariable,
) -> NumberOrPageVariableResult? {
  match variable {
    Page(p) => self.resolve_page_variable(p).map(r => Page(r))
    Number(n) => self.resolve_number_variable(n).map(r => Number(r))
  }
}

///|
/// Resolve a name variable.
///
/// Honors suppressions.
fn Context::resolve_standard_variable(
  self : Context,
  form : @citationberg.LongShortForm,
  variable : @citationberg.StandardVariable,
) -> ChunkedString? {
  // Replace the citation label with citation number if necessary.
  if variable == CitationLabel {
    if self.bibliography {
      if self.instance.identifier_usage == OnlyCitationNumber {
        return self.instance
          .resolve_number_variable(CitationNumber)
          .map(n => {
            match n {
              Regular(n) =>
                ChunkedString::from_string(numeric_maybe_to_string(n))
              Transparent(_) => abort("unexpected transparent")
            }
          })
      }
    } else {
      self.instance.identifier_usage = self.instance.identifier_usage.label()
    }
  }
  guard self.writing.prepare_variable_query(Standard(variable)) is Some(_) else {
    return None
  }
  self.instance.resolve_standard_variable(form, variable)
}

///|
/// `MaybeTyped<Numeric>::to_string()`.
fn numeric_maybe_to_string(n : MaybeTyped[Numeric]) -> String {
  match n {
    Typed(n) => fmt_to_string(b => n.fmt(b))
    String(s) => s
  }
}

///|
/// Resolve a date variable.
///
/// Honors suppressions.
fn Context::resolve_date_variable(
  self : Context,
  variable : @citationberg.DateVariable,
) -> Date? {
  guard self.writing.prepare_variable_query(Date(variable)) is Some(_) else {
    return None
  }
  self.instance.entry.resolve_date_variable(variable)
}

///|
/// Resolve a name variable.
///
/// Honors suppressions.
fn Context::resolve_name_variable(
  self : Context,
  variable : @citationberg.NameVariable,
) -> Array[Person] {
  if self.writing.prepare_variable_query(Name(variable)) is None {
    return []
  }
  self.instance.entry.resolve_name_variable(variable)
}

///|
/// Apply a prefix, but return a tuple that allows us to undo it if it
/// wasn't followed by anything.
fn Context::apply_prefix(
  self : Context,
  affixes : @citationberg.Affixes,
) -> (DisplayLoc, Int) {
  self.writing.apply_prefix(affixes)
}

///|
/// Apply a suffix, but only if the location was followed by something.
/// Delete any prefix if not.
fn Context::apply_suffix(
  self : Context,
  affixes : @citationberg.Affixes,
  loc : (DisplayLoc, Int),
) -> Unit {
  if !self.writing.has_content_since(loc) {
    self.discard_elem(loc.0)
  } else {
    if affixes.suffix is Some(suffix) {
      let do_suffix = if !self.writing.buf.is_empty() {
        !self.writing.buf.buf_string().has_suffix(suffix)
      } else if self.writing.elem_stack.last.last_text() is Some(l) {
        !l.text.has_suffix(suffix)
      } else {
        true
      }
      if do_suffix {
        self.push_str(suffix)
      }
    }
    self.commit_elem(loc.0, None, None)
  }
}

///|
/// Test whether this entry should disambiguate via `cs:choose`.
fn Context::should_disambiguate(self : Context) -> Bool {
  self.writing.checked_disambiguate = true
  self.instance.cite_props.speculative.disambiguation == Choose
}

///|
/// Check whether this is the first date and set the first date flag.
fn Context::is_first_date(self : Context) -> Bool {
  let res = self.writing.first_date
  self.writing.first_date = false
  res
}

///|
/// Check whether this is the first date.
fn Context::peek_is_first_date(self : Context) -> Bool {
  self.writing.first_date
}

///|
/// Checks that neither the bibliography nor the citation layout render the
/// year suffix.
fn Context::renders_year_suffix_implicitly(self : Context) -> Bool {
  !will_render_layout(
    self.style.csl.citation.layout,
    self,
    Standard(YearSuffix),
  ) &&
  !(match self.style.csl.bibliography {
    Some(b) => will_render_layout(b.layout, self, Standard(YearSuffix))
    None => false
  })
}

///|
priv struct UsageInfo {
  has_vars : Bool
  has_non_empty_vars : Bool
  has_used_macros : Bool
  has_non_empty_group : Bool
}

///|
fn UsageInfo::default() -> UsageInfo {
  {
    has_vars: false,
    has_non_empty_vars: false,
    has_used_macros: false,
    has_non_empty_group: false,
  }
}

///|
/// Merge usage info with the info of a child.
fn UsageInfo::merge_child(self : UsageInfo, child : UsageInfo) -> UsageInfo {
  {
    has_vars: self.has_vars || child.has_vars,
    has_non_empty_vars: self.has_non_empty_vars || child.has_non_empty_vars,
    has_used_macros: self.has_used_macros || child.has_used_macros,
    has_non_empty_group: self.has_non_empty_group || child.has_non_empty_group,
  }
}

///|
/// Whether a group with this usage info should be rendered.
fn UsageInfo::should_render_group(self : UsageInfo) -> Bool {
  !self.has_vars ||
  self.has_non_empty_vars ||
  self.has_used_macros ||
  self.has_non_empty_group
}

///|
/// Get the according left bracket.
pub fn Brackets::left(self : Brackets) -> Char? {
  match self {
    Round => Some('(')
    Square => Some('[')
    None_ => None
  }
}

///|
/// Get the according right bracket.
pub fn Brackets::right(self : Brackets) -> Char? {
  match self {
    Round => Some(')')
    Square => Some(']')
    None_ => None
  }
}
