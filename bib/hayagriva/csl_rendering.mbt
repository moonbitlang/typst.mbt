// Port of `hayagriva/src/csl/rendering/mod.rs`.

///|
/// All rendering elements implement this trait. It allows you to format an
/// [`Entry`] with them.
priv trait RenderCsl {
  /// Render the element given the context's Entry into the context's buffer.
  fn render(Self, Context) -> Unit
  /// Check whether the element will render a given variable.
  fn will_render(Self, Context, @citationberg.Variable) -> Bool
  /// Check whether the element will print something and what.
  fn will_have_info(Self, Context) -> (Bool, UsageInfo)
}

///|
fn render_layout(layout : @citationberg.Layout, ctx : Context) -> Unit {
  RenderCsl::render(layout, ctx)
}

///|
fn will_render_layout(
  layout : @citationberg.Layout,
  ctx : Context,
  var_ : @citationberg.Variable,
) -> Bool {
  RenderCsl::will_render(layout, ctx, var_)
}

///|
/// Gets the url prefix for a given StandardVariable if one exists.
///
/// These are those prefixes in the Appendix IV of the CSL 1.0.2 spec.
fn get_url_prefix(var_ : @citationberg.StandardVariable) -> String? {
  match var_ {
    DOI => Some("https://doi.org/")
    PMID => Some("https://www.ncbi.nlm.nih.gov/pubmed/")
    PMCID => Some("https://www.ncbi.nlm.nih.gov/pmc/articles/")
    _ => None
  }
}

///|
impl RenderCsl for @citationberg.Text with fn render(self, ctx) {
  guard ResolvedTextTarget::compute(self, ctx) is Some(target) else { return }
  let depth = ctx.push_elem(self.formatting)

  // Only print affixes if this macro is not used out of its original context.
  let print_affixes = match ctx.instance.kind {
    Some(VarOnly(_)) if self.target is Macro(..) => false
    _ => true
  }

  // Check if a URL prefix exists for the target and if so, if the CSL
  // specifies the URL prefix as the affix. If this is the case, we want to
  // make sure the URL prefix is a part of the link (and therefore not printed
  // here, but later).
  let affix_is_url_prefix = match target {
    StandardVariable(var_, _) =>
      match get_url_prefix(var_) {
        Some(prefix) => self.affixes.prefix == Some(prefix)
        None => false
      }
    _ => false
  }
  let affix_loc = if print_affixes && !affix_is_url_prefix {
    Some(ctx.apply_prefix(self.affixes))
  } else {
    None
  }
  if self.quotes {
    ctx.push_quotes()
  }
  ctx.may_strip_periods(self.strip_periods)
  let cidx = ctx.push_case(self.text_case)
  let mut should_render = true
  match target {
    StandardVariable(var_, val) =>
      if get_url_prefix(var_) is Some(url_prefix) {
        // For link variables, create the full URL for the destination of
        // the link.
        let full_url = url_prefix + val.to_str()
        let (display, destination) = if affix_is_url_prefix {
          // If the affix in the CSL was the URL prefix, then use the full
          // URL as both the link displayed and its destination.
          (full_url, full_url)
        } else {
          // Otherwise, display the value (e.g. the DOI) with the full URL
          // as its destination.
          (val.to_str(), full_url)
        }
        ctx.push_link(ChunkedString::from_string(display), destination)
      } else if var_ == URL {
        ctx.push_link(val, val.to_str())
      } else {
        ctx.push_chunked(val)
      }
    NumberVariable(_, n) =>
      match n {
        Regular(Typed(num)) if num.will_transform() =>
          render_typed_num(num, Numeric, None, ctx)
        Regular(n) => ctx.push_str(numeric_maybe_to_string(n))
        Transparent(n) => ctx.push_transparent(n)
      }
    PageVariable(p) =>
      match p {
        Typed(r) => render_page_range(r, ctx)
        String(s) => ctx.push_str(s.replace_all(old="-", new="–"))
      }
    Macro(mac) => {
      // Treat macros as groups: don't render if all variables are empty.
      let info = RenderCsl::will_have_info(self, ctx).1
      should_render = info.should_render_group()
      if should_render {
        // Delimiters from ancestor delimiting elements are NOT applied
        // within.
        let idx = ctx.writing.push_delimiter(None)
        for child in mac.children {
          RenderCsl::render(child, ctx)
        }
        ctx.writing.pop_delimiter(idx)
      }
    }
    Term(s) => ctx.push_str(s)
    Value(val) => ctx.push_str(val)
  }
  ctx.pop_case(cidx)
  ctx.stop_stripping_periods()
  if self.quotes {
    ctx.pop_quotes()
    ctx.may_pull_punctuation()
  }
  if affix_loc is Some(affix_loc) {
    ctx.apply_suffix(self.affixes, affix_loc)
  }
  if should_render {
    ctx.commit_elem(
      depth,
      self.display,
      match self.target {
        Variable(var_~, ..) if var_ == Number(CitationNumber) =>
          Some(CitationNumber)
        Variable(var_~, ..) if var_ == Standard(CitationLabel) =>
          Some(CitationLabel)
        Variable(..) => Some(Text)
        _ => None
      },
    )
  } else {
    ctx.discard_elem(depth)
  }
}

///|
impl RenderCsl for @citationberg.Text with fn will_render(self, ctx, var_) {
  guard ResolvedTextTarget::compute(self, ctx) is Some(target) else {
    return false
  }
  match target {
    StandardVariable(s, _) => var_ == Standard(s)
    NumberVariable(n, _) => var_ == Number(n)
    PageVariable(_) => var_ == Page(Page)
    Macro(mac) =>
      mac.children.iter().any(c => RenderCsl::will_render(c, ctx, var_))
    Term(_) => false
    Value(_) => false
  }
}

///|
impl RenderCsl for @citationberg.Text with fn will_have_info(self, ctx) {
  // If suppress_queried_variables is set to true, we need to perform a
  // silent lookup, otherwise we need to perform a regular lookup.
  let suppressing = ctx.writing.suppress_queried_variables
  ctx.writing.stop_suppressing_queried_variables()
  let lookup_result = ResolvedTextTarget::compute(self, ctx)
  if suppressing {
    ctx.writing.start_suppressing_queried_variables()
  }
  let targets_variable = match self.target {
    // Year suffix is not counted as a variable
    Variable(var_=Standard(YearSuffix), ..) => false
    Variable(..) => true
    _ => false
  }
  guard lookup_result is Some(target) else {
    return (false, { ..UsageInfo::default(), has_vars: targets_variable, })
  }
  match target {
    StandardVariable(_, s) if s.is_empty() =>
      (false, { ..UsageInfo::default(), has_vars: true, })
    StandardVariable(_, _) | NumberVariable(_, _) | PageVariable(_) =>
      (
        true,
        { ..UsageInfo::default(), has_vars: true, has_non_empty_vars: true, },
      )
    Macro(mac) => {
      let mut will_print = false
      let mut info = UsageInfo::default()
      for child in mac.children {
        let (print, child_info) = RenderCsl::will_have_info(child, ctx)
        will_print = will_print || print
        info = info.merge_child(child_info)
      }

      // Treat macro as group: don't render if all variables are empty.
      will_print = will_print && info.should_render_group()
      (will_print, { ..info, has_used_macros: will_print, })
    }
    Term(_) => (true, UsageInfo::default())
    Value(v) => (!v.is_empty(), UsageInfo::default())
  }
}

///|
priv enum ResolvedTextTarget {
  StandardVariable(@citationberg.StandardVariable, ChunkedString)
  NumberVariable(@citationberg.NumberVariable, NumberVariableResult)
  PageVariable(MaybeTyped[PageRanges])
  Macro(@citationberg.CslMacro)
  Term(String)
  Value(String)
}

///|
fn ResolvedTextTarget::compute(
  text : @citationberg.Text,
  ctx : Context,
) -> ResolvedTextTarget? {
  let is_macro = text.target is Macro(..)
  match ctx.instance.kind {
    // If we are supposed to print a variable we need to return if this is
    // neither a macro nor that variable.
    Some(VarOnly(v)) if !is_macro =>
      match text.target {
        Variable(var_~, ..) if var_ == v => ()
        _ => return None
      }
    Some(OnlyFirstDate | OnlyYearSuffix) if !is_macro &&
      !(text.target is Variable(var_=Standard(YearSuffix) | Number(Locator), ..)) =>
      return None
    _ => ()
  }
  match text.target {
    Variable(var_=Standard(var_), form~) =>
      ctx
      .resolve_standard_variable(form, var_)
      .map(s => StandardVariable(var_, s))
    Variable(var_=Number(var_), ..) =>
      ctx.resolve_number_variable(var_).map(n => NumberVariable(var_, n))
    Variable(var_=Page(pv), ..) =>
      ctx.resolve_page_variable(pv).map(p => PageVariable(p))
    Variable(..) => None
    Macro(name~) => ctx.style.get_macro(name).map(m => Macro(m))
    Term(term~, form~, plural~) =>
      ctx.term(term, form, plural).map(t => ResolvedTextTarget::Term(t))
    Value(val~) => Some(Value(val))
  }
}

///|
impl RenderCsl for @citationberg.Number with fn render(self, ctx) {
  if !RenderCsl::will_render(self, ctx, self.variable.to_variable()) {
    return
  }
  let value = ctx.resolve_number_or_page_variable(self.variable)
  if ctx.instance.sorting is Some(_) {
    match value {
      Some(Number(Regular(Typed(n)))) => {
        n.fmt_value(ctx, true)
        return
      }
      Some(Page(Typed(p))) => {
        p.fmt(ctx)
        return
      }
      _ => ()
    }
  }
  let depth = ctx.push_elem(self.formatting)
  let affix_loc = ctx.apply_prefix(self.affixes)
  let cidx = ctx.push_case(self.text_case)
  let gender = ctx.gender(self.variable.to_term())
  match value {
    Some(Number(Regular(Typed(num)))) if num.will_transform() =>
      render_typed_num(num, self.form, gender, ctx)
    Some(Number(Regular(Typed(num)))) => num.fmt(ctx)
    Some(Number(Regular(String(s)))) => ctx.push_str(s)
    Some(Number(Transparent(n))) => ctx.push_transparent(n)
    Some(Page(Typed(p))) => render_page_range(p, ctx)
    Some(Page(String(s))) => ctx.push_str(s)
    None => ()
  }
  ctx.pop_case(cidx)
  ctx.apply_suffix(self.affixes, affix_loc)
  ctx.commit_elem(
    depth,
    self.display,
    Some(
      if self.variable == Number(CitationNumber) {
        CitationNumber
      } else {
        Number
      },
    ),
  )
}

///|
impl RenderCsl for @citationberg.Number with fn will_render(self, ctx, var_) {
  match ctx.instance.kind {
    Some(VarOnly(Number(n))) if self.variable != Number(n) => return false
    Some(OnlyFirstDate | OnlyYearSuffix) =>
      return self.variable is Number(Locator)
    Some(VarOnly(_)) => return false
    _ => ()
  }
  var_ == self.variable.to_variable()
}

///|
impl RenderCsl for @citationberg.Number with fn will_have_info(self, ctx) {
  if RenderCsl::will_render(self, ctx, self.variable.to_variable()) {
    // If suppress_queried_variables is set to true, we need to perform a
    // silent lookup, otherwise we need to perform a regular lookup.
    let suppressing = ctx.writing.suppress_queried_variables
    ctx.writing.stop_suppressing_queried_variables()
    let lookup_result = ctx.resolve_number_or_page_variable(self.variable)
    if suppressing {
      ctx.writing.start_suppressing_queried_variables()
    }
    (
      lookup_result is Some(_),
      {
        ..UsageInfo::default(),
        has_vars: true,
        has_non_empty_vars: lookup_result is Some(_),
      },
    )
  } else {
    (false, { ..UsageInfo::default(), has_vars: true, })
  }
}

///|
fn render_typed_num(
  num : Numeric,
  form : @citationberg.NumberForm,
  gender : @citationberg.GrammarGender?,
  ctx : Context,
) -> Unit {
  num.with_form(ctx, form, gender, ctx.ordinal_lookup())
}

///|
fn render_page_range(range : PageRanges, ctx : Context) -> Unit {
  let format = ctx.style.csl.settings.page_range_format.unwrap_or(
    @citationberg.PageRangeFormat::default(),
  )
  let delim = match ctx.term(Other(PageRangeDelimiter), Long, false) {
    Some(d) => Some(d)
    None => Some("–")
  }
  let write = (s : String) => ctx.push_str(s)
  for r in range.ranges {
    match r {
      Ampersand => ctx.push_str(" & ")
      Comma => ctx.push_str(", ")
      EscapedRange(start, end) =>
        @citationberg.PageRangeFormat::Expanded.format(
          write,
          start.to_string(),
          end.to_string(),
          delim,
        )
      SinglePage(page) => ctx.push_str(page.to_string())
      Range(start, end) =>
        format.format(write, start.to_string(), end.to_string(), delim)
    }
  }
}

///|
fn label_pluralization(
  label : @citationberg.Label,
  variable : NumberVariableResult,
) -> Bool {
  match label.label.plural {
    Always => true
    Never => false
    Contextual =>
      match variable {
        Regular(String(_)) => false
        Regular(Typed(n)) =>
          if label.variable is Number(v) {
            n.is_plural(v.is_number_of_variable())
          } else {
            abort("Incompatible variable types")
          }
        Transparent(_) => false
      }
  }
}

///|
impl RenderCsl for @citationberg.Label with fn render(self, ctx) {
  if !RenderCsl::will_have_info(self, ctx).0 {
    return
  }
  match self.variable {
    Number(n) => {
      guard ctx.resolve_number_variable(n) is Some(variable) else { return }
      let depth = ctx.push_elem(@citationberg.Formatting::default())
      let plural = label_pluralization(self, variable)
      let content = ctx
        .term(self.variable.to_term(), self.label.form, plural)
        .unwrap_or("")
      render_label_with_var(self.label, ctx, content)
      ctx.commit_elem(depth, None, Some(Label))
    }
    Page(pv) => {
      guard ctx.resolve_page_variable(pv) is Some(p) else { return }
      let depth = ctx.push_elem(@citationberg.Formatting::default())
      let plural = match p.as_typed() {
        Some(p) => p.is_plural()
        None => false
      }
      let content = ctx
        .term(
          @citationberg.NumberOrPageVariable::Page(pv).to_term(),
          self.label.form,
          plural,
        )
        .unwrap_or("")
      render_label_with_var(self.label, ctx, content)
      ctx.commit_elem(depth, None, Some(Label))
    }
  }
}

///|
impl RenderCsl for @citationberg.Label with fn will_render(_self, _ctx, _var) {
  false
}

///|
impl RenderCsl for @citationberg.Label with fn will_have_info(self, ctx) {
  match ctx.instance.kind {
    Some(VarOnly(Number(n))) if self.variable != Number(n) =>
      return (false, UsageInfo::default())
    Some(VarOnly(_) | OnlyFirstDate | OnlyYearSuffix) if self.variable !=
      Number(Locator) => return (true, UsageInfo::default())
    _ => ()
  }

  // Never yield a label if the locator is set to custom.
  if self.variable == Number(Locator) &&
    ctx.instance.cite_props.speculative.locator
    is Some(SpecificLocator(Custom, _)) {
    return (false, UsageInfo::default())
  }
  match self.variable {
    Number(n) =>
      if ctx.resolve_number_variable(n) is Some(num) {
        let plural = label_pluralization(self, num)
        (
          ctx.term(self.variable.to_term(), self.label.form, plural) is Some(_),
          UsageInfo::default(),
        )
      } else {
        (false, UsageInfo::default())
      }
    Page(pv) =>
      if ctx.resolve_page_variable(pv) is Some(p) {
        let plural = match p.as_typed() {
          Some(p) => p.is_plural()
          None => false
        }
        (
          ctx.term(
            @citationberg.NumberOrPageVariable::Page(pv).to_term(),
            self.label.form,
            plural,
          )
          is Some(_),
          UsageInfo::default(),
        )
      } else {
        (false, UsageInfo::default())
      }
  }
}

///|
fn render_label_with_var(
  label : @citationberg.VariablelessLabel,
  ctx : Context,
  content : String,
) -> Unit {
  if content.is_empty() {
    return
  }
  let idx = ctx.push_format(label.formatting)
  let affixes = label.affixes
  let affix_loc = ctx.apply_prefix(affixes)
  ctx.may_strip_periods(label.strip_periods)
  let cidx = ctx.push_case(label.text_case)
  ctx.push_str(content)
  ctx.pop_case(cidx)
  ctx.stop_stripping_periods()
  ctx.apply_suffix(affixes, affix_loc)
  ctx.pop_format(idx)
}

///|
impl RenderCsl for @citationberg.Date with fn render(self, ctx) {
  guard self.variable is Some(variable) else { return }
  if !RenderCsl::will_render(self, ctx, Date(variable)) {
    return
  }
  guard ctx.resolve_date_variable(variable) is Some(date) else { return }
  if ctx.instance.sorting is Some(sorting) {
    let mut year = false
    let mut month = false
    let mut day = false
    if self.is_localized() {
      match self.parts {
        Some(Year) => year = true
        Some(YearMonth) => {
          year = true
          month = true
        }
        Some(YearMonthDay) | None => {
          year = true
          month = true
          day = true
        }
      }
    } else if sorting == Variable {
      // According to the CSL 1.0.2 spec (section "Sorting"):
      //
      // "Number variables rendered within the macro with cs:number and date
      // variables are treated the same as when they are called via
      // variable. The only exception is that the complete date is returned
      // if a date variable is called via the variable attribute. In
      // contrast, macros return only those date-parts that would otherwise
      // be rendered (...)."
      year = true
      month = true
      day = true
    } else {
      year = self.date_part.iter().any(i => i.name == Year)
      month = self.date_part.iter().any(i => i.name == Month)
      day = self.date_part.iter().any(i => i.name == Day)
    }
    if year {
      // Smart hack taken from citeproc: This prints negative (BC) dates as
      // N(999,999,999 + y) and positive (AD) dates as Py so they sort
      // properly. (Use i32::MAX to avoid problems with large dates.)
      let (prefix, yr) = if date.year < 0 {
        ("N", 2147483647 + date.year)
      } else {
        ("P", date.year)
      }
      ctx.push_str(prefix)
      fmt_int_zero_pad(ctx, yr.to_int64(), 9)
      render_year_suffix_implicitly(ctx)
    }
    if month {
      fmt_int_zero_pad(
        ctx,
        (match date.month {
          Some(m) => m + 1
          None => 0
        }).to_int64(),
        2,
      )
    }
    if day {
      fmt_int_zero_pad(
        ctx,
        (match date.day {
          Some(d) => d + 1
          None => 0
        }).to_int64(),
        2,
      )
    }
    return
  }
  let base = match self.form {
    Some(form) =>
      // Localized date formats can fail to print anything at all,
      // especially if no locale is set.
      match ctx.localized_date(form) {
        Some(base) => Some(base)
        None => return
      }
    None => None
  }
  let first = ctx.is_first_date()
  let formatting = match base {
    Some(b) => self.formatting.apply(b.formatting)
    None => self.formatting
  }
  let depth = ctx.push_elem(formatting)
  let affix_loc = ctx.apply_prefix(self.affixes)
  let cidx = ctx.push_case(
    match self.text_case {
      Some(c) => Some(c)
      None =>
        match base {
          Some(b) => b.text_case
          None => None
        }
    },
  )
  let parts = match self.parts {
    Some(p) => p
    None =>
      match base {
        Some({ parts: Some(p), .. }) => p
        _ => @citationberg.DateParts::default()
      }
  }

  // TODO: Date ranges
  let mut last_was_empty = true

  // Localized (base) delimiter takes precedence over the cs:date element's
  // delimiter attribute, which should be ignored if a locale's date form is
  // used, according to the CSL 1.0.2 spec (under "Style Behavior"):
  //
  // "Delimiter
  //
  // The delimiter attribute, whose value delimits non-empty pieces of
  // output, may be set on cs:date (delimiting the date-parts; delimiter is
  // not allowed when cs:date calls a localized date format)"
  let chosen_delim = match base {
    Some(base) => base.delimiter
    None => self.delimiter
  }
  let source = match base {
    Some(b) => b
    None => self
  }
  for part in source.date_part {
    match part.name {
      Month if !parts.has_month() && date.season is None => continue
      Day if !parts.has_day() => continue
      _ => ()
    }
    let cursor = ctx.writing.len()
    if !last_was_empty && chosen_delim is Some(delim) {
      ctx.push_str(delim)
    }
    let over_ride = if base is Some(_) {
      let mut found = None
      for p in self.date_part {
        if p.name == part.name {
          found = Some(p)
          break
        }
      }
      found
    } else {
      None
    }
    render_date_part(part, date, ctx, over_ride, first)
    last_was_empty = cursor == ctx.writing.len()
  }
  ctx.pop_case(cidx)
  ctx.apply_suffix(self.affixes, affix_loc)
  ctx.commit_elem(depth, self.display, Some(Date))
}

///|
impl RenderCsl for @citationberg.Date with fn will_render(self, ctx, var_) {
  match ctx.instance.kind {
    Some(VarOnly(Date(d))) if self.variable != Some(d) => return false
    Some(OnlyFirstDate | OnlyYearSuffix) => return ctx.peek_is_first_date()
    Some(VarOnly(_)) => return false
    _ => ()
  }
  Some(var_) == self.variable.map(v => @citationberg.Variable::Date(v))
}

///|
impl RenderCsl for @citationberg.Date with fn will_have_info(self, ctx) {
  let suppressing = ctx.writing.suppress_queried_variables
  ctx.writing.stop_suppressing_queried_variables()
  guard self.variable is Some(variable) else {
    return (false, { ..UsageInfo::default(), has_vars: true, })
  }
  if suppressing {
    ctx.writing.start_suppressing_queried_variables()
  }
  if !RenderCsl::will_render(self, ctx, Date(variable)) {
    (false, UsageInfo::default())
  } else {
    let has_non_empty_vars = ctx.resolve_date_variable(variable) is Some(_)
    (
      has_non_empty_vars,
      { ..UsageInfo::default(), has_vars: true, has_non_empty_vars, },
    )
  }
}

///|
fn render_date_part(
  date_part : @citationberg.DatePart,
  date : Date,
  ctx : Context,
  over_ride : @citationberg.DatePart?,
  first : Bool,
) -> Unit {
  let val = match date_part.name {
    Day => date.day.map(i => i + 1)
    Month =>
      // Fallback for month is the season
      match date.month {
        Some(i) => Some(i + 1)
        None => date.season.map(s => s.to_csl_number())
      }
    Year => Some(date.year)
  }
  guard val is Some(val) else { return }
  let is_only_suffix = ctx.instance.kind == Some(OnlyYearSuffix)
  let form = match over_ride {
    Some(o) => o.form()
    None => date_part.form()
  }
  let formatting = match over_ride {
    Some(p) => p.formatting.apply(date_part.formatting)
    None => date_part.formatting
  }
  let idx = ctx.push_format(formatting)
  let affixes = date_part.affixes
  let affix_loc = if !is_only_suffix {
    Some(ctx.apply_prefix(affixes))
  } else {
    None
  }
  if date_part.name == Month {
    ctx.may_strip_periods(date_part.strip_periods)
  }
  let cidx = ctx.push_case(
    match over_ride {
      Some({ text_case: Some(c), .. }) => Some(c)
      _ => date_part.text_case
    },
  )
  if !is_only_suffix {
    match form {
      Month(_) if date.month is None => {
        guard date.season is Some(season) else { return }
        let season_term = @citationberg.OtherTerm::season(season)
        guard ctx.term(Other(season_term), Short, false) is Some(season) else {
          return
        }
        ctx.push_str(season)
      }
      Day(NumericLeadingZeros) | Month(NumericLeadingZeros) =>
        fmt_int_zero_pad(ctx, val.to_int64(), 2)
      Day(Ordinal) if val == 1 ||
        !ctx.style
        .lookup_locale(l => {
          Some(
            match l.style_options {
              Some(o) => o.limit_day_ordinals_to_day_1.unwrap_or(false)
              None => false
            },
          )
        })
        .unwrap_or(false) => {
        let gender = match date.month {
          Some(m) =>
            match @citationberg.OtherTerm::month(m) {
              Some(m) => ctx.gender(Other(m))
              None => None
            }
          None => None
        }
        fmt_int(ctx, val.to_int64())
        ctx.push_str(ctx.ordinal_lookup().lookup(val, gender).unwrap_or(""))
      }
      Day(Numeric | Ordinal) | Month(Numeric) => fmt_int(ctx, val.to_int64())
      Month(Long) =>
        match
          @citationberg.OtherTerm::month((val - 1) & 0xff).bind(m => {
            ctx.term(Other(m), Long, false)
          }) {
          Some(month) => ctx.push_str(month)
          None => fmt_int(ctx, val.to_int64())
        }
      Month(Short) =>
        match
          @citationberg.OtherTerm::month((val - 1) & 0xff).bind(m => {
            ctx.term(Other(m), Short, false)
          }) {
          Some(month) => ctx.push_str(month)
          None => fmt_int(ctx, val.to_int64())
        }
      Year(brevity) => {
        let ad = ctx.term(Other(Ad), Long, false).unwrap_or(" AD")
        let bc = ctx.term(Other(Bc), Long, false).unwrap_or(" BC")
        write_year(val, brevity == Short, ctx, ad, bc)
      }
    }
  }
  if form is Year(_) && first {
    render_year_suffix_implicitly(ctx)
  }
  if affix_loc is Some(affix_loc) {
    ctx.apply_suffix(affixes, affix_loc)
  }
  ctx.stop_stripping_periods()
  ctx.pop_case(cidx)
  ctx.pop_format(idx)
}

///|
/// Render the year suffix if it is set and the style will not render it
/// explicitly.
fn render_year_suffix_implicitly(ctx : Context) -> Unit {
  if ctx.renders_year_suffix_implicitly() &&
    ctx.resolve_standard_variable(Long, YearSuffix) is Some(year_suffix) {
    ctx.push_chunked(year_suffix)
  }
}

///|
fn[R] choose_children(
  choose : @citationberg.Choose,
  ctx : Context,
  f : (Array[@citationberg.LayoutRenderingElement], Context) -> R,
) -> R? {
  let suppressed = ctx.writing.suppress_queried_variables
  ctx.writing.stop_suppressing_queried_variables()
  let mut branch = None
  for b in choose.branches() {
    if b.match_.test_(BranchConditionIter::from_branch(b, ctx).iter()) {
      branch = Some(b)
      break
    }
  }
  ctx.writing.suppress_queried_variables = suppressed
  let children = match branch {
    Some(b) => Some(b.children)
    None => choose.otherwise.map(f => f.children)
  }
  children.map(children => f(children, ctx))
}

///|
impl RenderCsl for @citationberg.Choose with fn render(self, ctx) {
  choose_children(self, ctx, (children, ctx) => {
    // Propagate parent group's delimiter to 'choose' output, as required by
    // CSL, by not pushing a delimiter to the stack.
    render_with_delimiter(children, ctx)
  })
  |> ignore
}

///|
impl RenderCsl for @citationberg.Choose with fn will_render(self, ctx, var_) {
  choose_children(self, ctx, (children, ctx) => {
    children.iter().any(c => RenderCsl::will_render(c, ctx, var_))
  }).unwrap_or(false)
}

///|
impl RenderCsl for @citationberg.Choose with fn will_have_info(self, ctx) {
  choose_children(self, ctx, (children, ctx) => {
    let mut info = UsageInfo::default()
    let mut will_print = false
    for child in children {
      let (print, child_info) = RenderCsl::will_have_info(child, ctx)
      will_print = will_print || print
      info = info.merge_child(child_info)
    }
    (will_print, info)
  }).unwrap_or((false, UsageInfo::default()))
}

///|
/// Render `children` with the delimiter in `ctx` between them.
fn render_with_delimiter(
  children : Array[@citationberg.LayoutRenderingElement],
  ctx : Context,
) -> Unit {
  let delimiter = ctx.writing.delimiters.last
  let mut first = true
  let mut loc = None
  for child in children {
    // Do not render the child if it will not print anything.
    if !RenderCsl::will_have_info(child, ctx).0 {
      continue
    }
    if !first && delimiter is Some(delim) {
      let prev_loc = loc
      loc = None
      if prev_loc is Some(prev_loc) {
        ctx.commit_elem(prev_loc, None, None)
      }
      loc = Some(ctx.push_elem(@citationberg.Formatting::default()))
      ctx.push_str(delim)
    }
    first = false
    let pos = ctx.push_elem(@citationberg.Formatting::default())
    RenderCsl::render(child, ctx)
    ctx.commit_elem(pos, None, None)
  }
  if loc is Some(loc) {
    ctx.commit_elem(loc, None, None)
  }
}

///|
priv enum BranchConditionPos {
  Disambiguate
  IsNumeric
  IsUncertainDate
  Locator
  Position
  Type
  Variable
}

///|
fn BranchConditionPos::advance(self : BranchConditionPos) -> BranchConditionPos {
  match self {
    Disambiguate => IsNumeric
    IsNumeric => IsUncertainDate
    IsUncertainDate => Locator
    Locator => Position
    Position => Type
    Type => Variable
    Variable => Variable
  }
}

///|
priv struct BranchConditionIter {
  cond : @citationberg.ChooseBranch
  ctx : Context
  mut pos : BranchConditionPos
  mut idx : Int
}

///|
fn BranchConditionIter::from_branch(
  cond : @citationberg.ChooseBranch,
  ctx : Context,
) -> BranchConditionIter {
  { cond, ctx, pos: Disambiguate, idx: 0, }
}

///|
fn BranchConditionIter::next_case(self : BranchConditionIter) -> Unit {
  self.pos = self.pos.advance()
  self.idx = 0
}

///|
fn BranchConditionIter::iter(self : BranchConditionIter) -> Iter[Bool] {
  Iter::new(() => self.next())
}

///|
fn BranchConditionIter::next(self : BranchConditionIter) -> Bool? {
  let ctx = self.ctx
  match self.pos {
    Disambiguate => {
      self.pos = self.pos.advance()
      if self.cond.disambiguate is Some(d) {
        Some(d == ctx.should_disambiguate())
      } else {
        self.next()
      }
    }
    IsNumeric =>
      if self.cond.is_numeric is Some(vars) {
        if self.idx >= vars.length() {
          self.next_case()
          return self.next()
        }
        let var_ = vars[self.idx]
        self.idx += 1
        Some(
          match var_ {
            Standard(var_) =>
              match ctx.resolve_standard_variable(Long, var_) {
                Some(v) => Numeric::from_str(v.to_str()) is Ok(_)
                None => false
              }
            Number(var_) =>
              ctx.resolve_number_variable(var_) is Some(Regular(Typed(_)))
            Page(var_) => ctx.resolve_page_variable(var_) is Some(Typed(_))
            _ => false
          },
        )
      } else {
        self.next_case()
        self.next()
      }
    IsUncertainDate =>
      if self.cond.is_uncertain_date is Some(vars) {
        if self.idx >= vars.length() {
          self.next_case()
          return self.next()
        }
        let var_ = vars[self.idx]
        self.idx += 1
        Some(
          match ctx.resolve_date_variable(var_) {
            Some(d) => d.approximate
            None => false
          },
        )
      } else {
        self.next_case()
        self.next()
      }
    Locator =>
      if self.cond.locator is Some(locs) {
        if self.idx >= locs.length() {
          self.next_case()
          return self.next()
        }
        let loc = locs[self.idx]
        self.idx += 1
        Some(
          match ctx.instance.cite_props.speculative.locator {
            Some(SpecificLocator(l, _)) => l == loc
            None => false
          },
        )
      } else {
        self.next_case()
        self.next()
      }
    Position =>
      if self.cond.position is Some(pos) {
        // CSL 1.0.2 spec ("Choose" > "position"): "When called within the
        // scope of cs:bibliography, position tests 'false'."
        if ctx.bibliography || self.idx >= pos.length() {
          self.next_case()
          return self.next()
        }
        let spec_pos = pos[self.idx]
        self.idx += 1
        let props = ctx.instance.cite_props
        Some(
          match spec_pos {
            First => props.certain.is_first
            Subsequent => !props.certain.is_first
            Ibid => props.speculative.ibid is (Ibid | IbidWithLocator)
            IbidWithLocator => props.speculative.ibid is IbidWithLocator
            NearNote => props.certain.is_near_note
          },
        )
      } else {
        self.next_case()
        self.next()
      }
    Type =>
      if self.cond.type_ is Some(kind) {
        if self.idx >= kind.length() {
          self.next_case()
          return self.next()
        }
        let kind = kind[self.idx]
        self.idx += 1
        Some(ctx.instance.entry.matches_entry_type(kind))
      } else {
        self.next_case()
        self.next()
      }
    Variable =>
      if self.cond.variable is Some(vars) {
        if self.idx >= vars.length() {
          return None
        }
        let var_ = vars[self.idx]
        self.idx += 1
        Some(
          match var_ {
            Standard(s) => {
              let val = ctx.resolve_standard_variable(Long, s)
              match val {
                Some(s) =>
                  !s.to_str().iter().all(c => @unscanny.is_whitespace(c))
                None => false
              }
            }
            Number(n) => {
              let val = ctx.resolve_number_variable(n)
              val is Some(_)
            }
            Date(d) => ctx.resolve_date_variable(d) is Some(_)
            Name(n) => !ctx.resolve_name_variable(n).is_empty()
            Page(pv) => ctx.resolve_page_variable(pv) is Some(_)
          },
        )
      } else {
        None
      }
  }
}

///|
impl RenderCsl for @citationberg.Group with fn render(self, ctx) {
  let idx = ctx.push_elem(self.to_formatting())
  let affixes = self.to_affixes()
  let affix_loc = ctx.apply_prefix(affixes)
  let info = RenderCsl::will_have_info(self, ctx).1
  let delim_idx = ctx.writing.push_delimiter(self.delimiter)
  render_with_delimiter(self.children, ctx)
  ctx.writing.pop_delimiter(delim_idx)
  ctx.apply_suffix(affixes, affix_loc)
  if info.should_render_group() {
    ctx.commit_elem(idx, self.display, None)
  } else {
    ctx.discard_elem(idx)
  }
}

///|
impl RenderCsl for @citationberg.Group with fn will_render(self, ctx, var_) {
  self.children.iter().any(e => RenderCsl::will_render(e, ctx, var_))
}

///|
impl RenderCsl for @citationberg.Group with fn will_have_info(self, ctx) {
  let mut info = UsageInfo::default()
  let mut will_print = false
  for child in self.children {
    let (print, child_info) = RenderCsl::will_have_info(child, ctx)
    will_print = will_print || print
    info = info.merge_child(child_info)
    match child {
      Group(_) if print => info = { ..info, has_non_empty_group: true, }
      _ => ()
    }
  }
  will_print = will_print && info.should_render_group()
  (will_print, info)
}

///|
impl RenderCsl for @citationberg.LayoutRenderingElement with fn render(
  self,
  ctx,
) {
  match self {
    Text(text) => RenderCsl::render(text, ctx)
    Number(num) => RenderCsl::render(num, ctx)
    Label(label) => RenderCsl::render(label, ctx)
    Date(date) => RenderCsl::render(date, ctx)
    Names(names) => RenderCsl::render(names, ctx)
    Choose(choose) => RenderCsl::render(choose, ctx)
    Group(group) => RenderCsl::render(group, ctx)
  }
}

///|
impl RenderCsl for @citationberg.LayoutRenderingElement with fn will_render(
  self,
  ctx,
  var_,
) {
  match self {
    Text(text) => RenderCsl::will_render(text, ctx, var_)
    Number(num) => RenderCsl::will_render(num, ctx, var_)
    Label(label) => RenderCsl::will_render(label, ctx, var_)
    Date(date) => RenderCsl::will_render(date, ctx, var_)
    Names(names) => RenderCsl::will_render(names, ctx, var_)
    Choose(choose) => RenderCsl::will_render(choose, ctx, var_)
    Group(group) => RenderCsl::will_render(group, ctx, var_)
  }
}

///|
impl RenderCsl for @citationberg.LayoutRenderingElement with fn will_have_info(
  self,
  ctx,
) {
  match self {
    Text(text) => RenderCsl::will_have_info(text, ctx)
    Number(num) => RenderCsl::will_have_info(num, ctx)
    Label(label) => RenderCsl::will_have_info(label, ctx)
    Date(date) => RenderCsl::will_have_info(date, ctx)
    Names(names) => RenderCsl::will_have_info(names, ctx)
    Choose(choose) => RenderCsl::will_have_info(choose, ctx)
    Group(group) => RenderCsl::will_have_info(group, ctx)
  }
}

///|
impl RenderCsl for @citationberg.Layout with fn render(self, ctx) {
  let format_idx = ctx.push_format(self.to_formatting())
  let delim_idx = ctx.writing.push_delimiter(self.delimiter)
  for e in self.elements {
    RenderCsl::render(e, ctx)
  }
  ctx.writing.pop_delimiter(delim_idx)
  ctx.pop_format(format_idx)
}

///|
impl RenderCsl for @citationberg.Layout with fn will_render(self, ctx, var_) {
  self.elements.iter().any(e => RenderCsl::will_render(e, ctx, var_))
}

///|
impl RenderCsl for @citationberg.Layout with fn will_have_info(self, ctx) {
  let mut info = UsageInfo::default()
  let mut will_print = false
  for child in self.elements {
    let (print, child_info) = RenderCsl::will_have_info(child, ctx)
    will_print = will_print || print
    info = info.merge_child(child_info)
  }
  (will_print, info)
}
