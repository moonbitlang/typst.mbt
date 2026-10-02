// Port of `hayagriva/src/csl/rendering/names.rs`.

///|
priv enum DisambiguatedNameForm {
  /// Count the names.
  Count
  /// Print only the family name. Initialization is available.
  ShortInitialized
  /// Print only the family name. Initialization is unavailable.
  ShortFull
  /// Print the name with a first name initial.
  LongInitialized
  /// Print the full name.
  LongFull
} derive(Eq, Compare, Hash, Debug)

///|
fn DisambiguatedNameForm::from_options(
  option : @citationberg.NameOptions,
) -> DisambiguatedNameForm {
  let form = option.form
  if option.initialize_with is Some(_) && option.initialize {
    if form == Short {
      ShortInitialized
    } else {
      LongInitialized
    }
  } else if form == Short {
    ShortFull
  } else if form == Count {
    Count
  } else {
    LongFull
  }
}

///|
fn DisambiguatedNameForm::disambiguate(
  self : DisambiguatedNameForm,
  allow_full_first_name : Bool,
) -> DisambiguatedNameForm? {
  match self {
    ShortInitialized => Some(LongInitialized)
    LongInitialized if allow_full_first_name => Some(LongFull)
    LongInitialized => None
    ShortFull if allow_full_first_name => Some(LongFull)
    ShortFull => None
    LongFull => None
    Count => None
  }
}

///|
fn DisambiguatedNameForm::is_long(self : DisambiguatedNameForm) -> Bool {
  self is (LongFull | LongInitialized)
}

///|
priv struct NameDisambiguationProperties {
  /// For each variable that this term renders, there is a list of persons.
  /// This list contains the current form of the name for each person or
  /// `None` if it was suppressed.
  name_forms : Array[Array[DisambiguatedNameForm?]]
  mut default_name_form : DisambiguatedNameForm
  variables : Array[@citationberg.NameVariable]
} derive(Eq, Hash, Debug)

///|
fn NameDisambiguationProperties::copy(
  self : NameDisambiguationProperties,
) -> NameDisambiguationProperties {
  {
    name_forms: self.name_forms.map(l => l.copy()),
    default_name_form: self.default_name_form,
    variables: self.variables.copy(),
  }
}

///|
/// Adds the first `num` names (i.e., makes their name forms visible).
fn NameDisambiguationProperties::add_name(
  self : NameDisambiguationProperties,
  num : Int,
) -> Bool {
  for lst in self.name_forms {
    if lst.length() >= num {
      for i in 0..<num {
        if lst[i] is None {
          lst[i] = Some(self.default_name_form)
        }
      }
      return true
    }
  }
  false
}

///|
/// Return the more disambiguated form of the name.
fn NameDisambiguationProperties::max(
  self : NameDisambiguationProperties,
  other : NameDisambiguationProperties,
) -> NameDisambiguationProperties {
  let count_some = (x : NameDisambiguationProperties) => {
    let mut n = 0
    for l in x.name_forms {
      for c in l {
        if c is Some(_) {
          n += 1
        }
      }
    }
    n
  }
  let flat = (x : NameDisambiguationProperties) => {
    let out = []
    for l in x.name_forms {
      out.append(l)
    }
    out
  }
  let mut ord = compare_int(count_some(self), count_some(other))
  if ord == 0 {
    let a = flat(self)
    let b = flat(other)
    let n = if a.length() < b.length() { a.length() } else { b.length() }
    for i in 0..<n {
      let c = a[i].compare(b[i])
      if c != 0 {
        ord = c
        break
      }
    }
    if ord == 0 {
      ord = compare_int(a.length(), b.length())
    }
  }
  if ord > 0 {
    self
  } else {
    other
  }
}

///|
/// Gets the `idx`-th name form or the default name form if it does not yet
/// exist (upstream `get_form_mut`, split into a getter and a setter).
fn NameDisambiguationProperties::get_form(
  self : NameDisambiguationProperties,
  idx : Int,
) -> DisambiguatedNameForm? {
  match self.locate_form(idx) {
    Some((i, j)) => self.name_forms[i][j]
    None => Some(self.default_name_form)
  }
}

///|
fn NameDisambiguationProperties::locate_form(
  self : NameDisambiguationProperties,
  idx : Int,
) -> (Int, Int)? {
  let mut k = 0
  for i, l in self.name_forms {
    for j, f in l {
      if k == idx {
        return if f is Some(_) { Some((i, j)) } else { None }
      }
      k += 1
    }
  }
  None
}

///|
fn NameDisambiguationProperties::set_form(
  self : NameDisambiguationProperties,
  idx : Int,
  form : DisambiguatedNameForm,
) -> Unit {
  match self.locate_form(idx) {
    Some((i, j)) => self.name_forms[i][j] = Some(form)
    None => self.default_name_form = form
  }
}

///|
fn renders_given_special_form(
  names : @citationberg.Names,
  ctx : Context,
  is_empty : Bool,
) -> Bool {
  match ctx.instance.kind {
    Some(VarOnly(Name(var_))) => {
      // Skip if none of the variables are the author and the supplement
      // does not contain the author either.
      let contains_v = names.variable.iter().any(v => var_ == v)
      let substitute_will_render_v = is_empty &&
        (match names.substitute() {
          Some(s) =>
            s.children
            .iter()
            .any(c => {
              match c {
                Names(n) => n.variable.iter().any(v => var_ == v)
                _ => false
              }
            })
          None => false
        })
      if !contains_v && !substitute_will_render_v {
        return false
      }
    }
    Some(VarOnly(_) | OnlyFirstDate | OnlyYearSuffix) => return false
    Some(SuppressAuthor) =>
      if RenderCsl::will_render(names, ctx, Name(Author)) {
        return false
      }
    None => ()
  }
  true
}

///|
impl RenderCsl for @citationberg.Names with fn render(self, ctx) {
  // The editor and translator variables need to be merged if they are both
  // present and identical.
  let people : Array[(Array[Person], @citationberg.NameVariable)] = if self.variable.length() ==
    2 &&
    self.variable.contains(Editor) &&
    self.variable.contains(Translator) &&
    ctx.term(NameVariable(EditorTranslator), Long, false) is Some(_) {
    let editors = ctx.resolve_name_variable(Editor)
    let translators = ctx.resolve_name_variable(Translator)
    let res = []
    if !editors.is_empty() && editors == translators {
      res.push((editors, @citationberg.NameVariable::EditorTranslator))
    } else {
      if !editors.is_empty() {
        res.push((editors, Editor))
      }
      if !translators.is_empty() {
        res.push((translators, Translator))
      }
    }
    res
  } else {
    self.variable.map(v => (ctx.resolve_name_variable(v), v))
  }

  // Push to the name options stack.
  ctx.writing.push_name_options(self.options())

  // Write the substitute if all variables are empty.
  let is_empty = people.iter().all(p => p.0.is_empty())
  // Suppress this variable if we are in a special form.
  if !renders_given_special_form(self, ctx, is_empty) {
    ctx.writing.pop_name_options()
    return
  }
  let meta_people = people.map(p => (p.0.copy(), p.1))
  if is_empty {
    if self.substitute() is Some(substitute) {
      ctx.writing.start_suppressing_queried_variables()
      let depth = ctx.push_elem(self.to_formatting())
      for child in substitute.children {
        let len = ctx.writing.len()
        if child is Names(names_child) {
          RenderCsl::render(self.from_names_substitute(names_child), ctx)
        } else {
          RenderCsl::render(child, ctx)
        }
        if len < ctx.writing.len() {
          break
        }
      }
      ctx.commit_elem(depth, self.display, Some(Names(meta_people)))
      ctx.writing.stop_suppressing_queried_variables()
    }
    ctx.writing.pop_name_options()
    return
  }
  let depth = ctx.push_elem(self.to_formatting())
  let affix_loc = ctx.apply_prefix(self.to_affixes())
  let cs_name = self.name().unwrap_or(@citationberg.Name::default())
  let options = cs_name.options(ctx.writing.name_options.last)
  let default_form = DisambiguatedNameForm::from_options(options)

  // Return here if we should only count the names.
  if default_form == Count {
    // Per the CSL spec on the `form` names option, only actually rendered
    // names should be counted.
    let mut total = 0
    for pair in people {
      let p = pair.0
      for i in 0..<p.length() {
        if !options.is_suppressed(
            i,
            p.length(),
            !ctx.instance.cite_props.certain.is_first,
          ) {
          total += 1
        }
      }
    }
    fmt_int(ctx, total.to_int64())
    ctx.apply_suffix(self.to_affixes(), affix_loc)
    ctx.commit_elem(depth, self.display, Some(Names(meta_people)))
    ctx.writing.pop_name_options()
    return
  }

  // If we disambiguate, we need to copy the name forms and otherwise
  // compute them using the options.
  let existing = match ctx.instance.cite_props.speculative.disambiguation {
    NameDisambiguation(props) =>
      if props.variables == people.map(p => p.1) {
        Some(props.copy())
      } else {
        None
      }
    _ => None
  }
  let props = match existing {
    Some(p) => p
    None =>
      NameDisambiguationProperties::{
        default_name_form: default_form,
        variables: self.variable.copy(),
        name_forms: people.map(pair => {
          let p = pair.0
          Array::makei(p.length(), i => {
            if options.is_suppressed(
                i,
                p.length(),
                !ctx.instance.cite_props.certain.is_first,
              ) {
              None
            } else {
              Some(default_form)
            }
          })
        }),
      }
  }
  let mut i = 0
  let n = if people.length() < props.name_forms.length() {
    people.length()
  } else {
    props.name_forms.length()
  }
  for k in 0..<n {
    let (persons, variable) = people[k]
    let forms = props.name_forms[k]
    if persons.is_empty() {
      continue
    }
    let plural = persons.length() != 1
    let label = self.label()
    let do_label = (
      requested_pos : @citationberg.NameLabelPosition,
      ctx : Context,
    ) => {
      if ctx.instance.sorting is None &&
        label is Some((label, pos)) &&
        pos == requested_pos {
        render_label_with_var(
          label,
          ctx,
          ctx.term(NameVariable(variable), label.form, plural).unwrap_or(""),
        )
      }
    }
    if i > 0 {
      let delim = self.delimiter(ctx.writing.name_options.last)
      if !delim.is_empty() {
        ctx.push_str(delim)
      }
    }
    do_label(BeforeName, ctx)
    let idx = ctx.push_format(cs_name.formatting)
    add_names(self, ctx, persons, cs_name, forms, variable)
    ctx.pop_format(idx)
    do_label(AfterName, ctx)
    i += 1
  }

  // TODO Compare each elem with a name meta and run
  // [`NameDisambiguationProperties::disambiguate_list`] on the identical
  // pairs. Rerender if necessary.

  ctx.apply_suffix(self.to_affixes(), affix_loc)
  ctx.commit_elem(depth, self.display, Some(Names(meta_people)))
  ctx.writing.pop_name_options()
  ctx.writing.first_name_properties(() => props) |> ignore
}

///|
impl RenderCsl for @citationberg.Names with fn will_render(self, ctx, var_) {
  if self.variable.iter().any(v => @citationberg.Variable::Name(v) == var_) {
    return true
  }
  if self.variable.iter().all(v => ctx.resolve_name_variable(v).is_empty()) &&
    self.substitute() is Some(substitute) {
    return substitute.children
      .iter()
      .any(c => RenderCsl::will_render(c, ctx, var_))
  }
  false
}

///|
impl RenderCsl for @citationberg.Names with fn will_have_info(self, ctx) {
  let suppressing = ctx.writing.suppress_queried_variables
  ctx.writing.stop_suppressing_queried_variables()
  let mut is_empty = self.variable
    .iter()
    .all(v => ctx.resolve_name_variable(v).is_empty())
  if !renders_given_special_form(self, ctx, is_empty) {
    return (false, UsageInfo::default())
  }
  let mut substitute_info = (false, UsageInfo::default())
  if self.substitute() is Some(s) {
    for c in s.children {
      let (c_, d) = RenderCsl::will_have_info(c, ctx)
      substitute_info = (
        substitute_info.0 || c_,
        substitute_info.1.merge_child(d),
      )
    }
  }
  let names_opts = self.options()

  // If `et-al-use-first` is set to zero and the et al. is rendered
  // (meaning, the number of names exceeds `et-al-min`), it is considered
  // empty. If all children are empty, we do not render.
  let children_will_render = self.children.is_empty() ||
    self.children
    .iter()
    .any(n => {
      match n {
        Name(name) => {
          let opts = name.options(names_opts)
          guard opts.et_al_min is Some(et_al_min) else { return true }
          guard opts.et_al_use_first is Some(et_al_use_first) else {
            return true
          }
          et_al_use_first != 0 ||
          !self.variable
          .iter()
          .all(v => ctx.resolve_name_variable(v).length() >= et_al_min)
        }
        _ => false
      }
    })
  is_empty = is_empty || !children_will_render
  if suppressing {
    ctx.writing.start_suppressing_queried_variables()
  }
  let visible = !is_empty || substitute_info.0
  (
    visible,
    if is_empty {
      substitute_info.1
    } else {
      { ..UsageInfo::default(), has_vars: true, has_non_empty_vars: !is_empty, }
    },
  )
}

///|
priv enum EndDelim {
  Delim
  And(@citationberg.NameAnd)
  DelimAnd(@citationberg.NameAnd)
}

///|
fn add_names(
  names : @citationberg.Names,
  ctx : Context,
  persons : Array[Person],
  cs_name : @citationberg.Name,
  forms : Array[DisambiguatedNameForm?],
  variable : @citationberg.NameVariable,
) -> Unit {
  let has_et_al = forms.iter().any(f => f is None)
  let take = {
    let mut pos = persons.length()
    for i, f in forms {
      if f is None {
        pos = i
        break
      }
    }
    pos
  }
  let names_opts = ctx.writing.name_options.last
  let name_opts = cs_name.options(names_opts)
  let et_al_use_last = if name_opts.et_al_use_last && has_et_al {
    match forms.last() {
      Some(f) => f
      None => None
    }
  } else {
    None
  }
  let mut last_inverted = false
  let demote_non_dropping = match
    ctx.style.csl.settings.demote_non_dropping_particle {
    Never => false
    SortOnly => ctx.instance.sorting is Some(_)
    DisplayAndSort => true
  }
  let mut first = true
  let n = if take < forms.length() { take } else { forms.length() }
  let n = if n < persons.length() { n } else { persons.length() }
  for i in 0..<n {
    let name = persons[i]
    guard forms[i] is Some(form) else { abort("form is none") }
    let last = i + 1 == take
    if !first {
      let mut delim = EndDelim::Delim
      if last && !has_et_al && name_opts.and_ is Some(d) {
        delim = match name_opts.delimiter_precedes_last {
          Contextual if i >= 2 => DelimAnd(d)
          AfterInvertedName if last_inverted => DelimAnd(d)
          Always => DelimAnd(d)
          _ => And(d)
        }
      }
      match delim {
        Delim => ctx.push_str(name_opts.delimiter)
        And(and_) => {
          ctx.push_str(" ")
          ctx.push_str(
            match and_ {
              Text => ctx.term(Other(And), Long, false).unwrap_or("")
              Symbol => "&"
            },
          )
          ctx.ensure_space()
        }
        DelimAnd(and_) => {
          ctx.push_str(name_opts.delimiter)
          ctx.push_str(
            match and_ {
              Text => ctx.term(Other(And), Long, false).unwrap_or("")
              Symbol => "&"
            },
          )
          ctx.ensure_space()
        }
      }
    }
    let reverse = match name_opts.name_as_sort_order {
      Some(First) if i == 0 => true
      Some(All) => true
      _ => false
    }
    write_name(
      name, ctx, form, reverse, demote_non_dropping, cs_name, name_opts, variable,
      i,
    )
    last_inverted = reverse
    first = false
  }
  if et_al_use_last is Some(form) {
    if persons.last() is Some(name) {
      ctx.push_str(name_opts.delimiter)
      ctx.push_str("… ")
      write_name(
        name,
        ctx,
        form,
        name_opts.name_as_sort_order is Some(All),
        demote_non_dropping,
        cs_name,
        name_opts,
        variable,
        persons.length() - 1,
      )
    }
  } else if ctx.instance.sorting is None && has_et_al {
    let cs_et_al = names
      .et_al()
      .unwrap_or({
        term: EtAl,
        formatting: @citationberg.Formatting::default(),
      })
    if ctx.term(cs_et_al.term.to_term(), Long, false) is Some(term) {
      let delim = match name_opts.delimiter_precedes_et_al {
        Always => true
        Contextual if take >= 2 => true
        AfterInvertedName if last_inverted => true
        _ => false
      }
      if delim {
        ctx.push_str(name_opts.delimiter)
      }
      let idx = ctx.push_format(cs_et_al.formatting)
      ctx.ensure_space()
      ctx.push_str(term)
      ctx.pop_format(idx)
    }
  }
}

///|
fn write_name(
  name : Person,
  ctx : Context,
  form : DisambiguatedNameForm,
  reverse : Bool,
  demote_non_dropping : Bool,
  cs_name : @citationberg.Name,
  name_opts : @citationberg.NameOptions,
  variable : @citationberg.NameVariable,
  name_idx : Int,
) -> Unit {
  let hyphen_init = ctx.style.csl.settings.initialize_with_hyphen
  let sort_sep = name_opts.sort_separator
  let first_part = cs_name.name_part_given()
  let family_part = cs_name.name_part_family()
  let first_format = match first_part {
    Some(p) => p.formatting
    None => @citationberg.Formatting::default()
  }
  let first_case = match first_part {
    Some(p) => p.text_case
    None => None
  }
  let first_affixes = [
    first_part.bind(p => p.affixes.prefix),
    first_part.bind(p => p.affixes.suffix),
  ]
  let family_format = match family_part {
    Some(p) => p.formatting
    None => @citationberg.Formatting::default()
  }
  let family_case = match family_part {
    Some(p) => p.text_case
    None => None
  }
  let family_affixes = [
    family_part.bind(p => p.affixes.prefix),
    family_part.bind(p => p.affixes.suffix),
  ]
  let comma_suffix = name.comma_suffix
  let first_name = (ctx : Context) => {
    if name.given_name is Some(first) {
      if name_opts.initialize_with is Some(initialize_with) {
        if form == LongInitialized {
          name.initials(ctx, Some(initialize_with), hyphen_init)
        } else {
          name.first_name_with_delimiter(ctx, Some(initialize_with))
        }
      } else {
        ctx.push_str(first)
      }
      true
    } else {
      false
    }
  }
  let simple = (ctx : Context) => {
    let idx = ctx.push_format(family_format)
    let cidx = ctx.push_case(family_case)
    if family_affixes[0] is Some(prefix) {
      ctx.push_str(prefix)
    }
    ctx.push_str(name.name)
    ctx.pop_case(cidx)
    ctx.pop_format(idx)
    if family_affixes[1] is Some(suffix) {
      ctx.push_str(suffix)
    }
  }
  let reverse_keep_particle = (ctx : Context) => {
    let idx = ctx.push_format(family_format)
    let cidx = ctx.push_case(family_case)
    if family_affixes[0] is Some(prefix) {
      ctx.push_str(prefix)
    }
    ctx.push_str(name.name)
    ctx.pop_case(cidx)
    ctx.pop_format(idx)
    if family_affixes[1] is Some(suffix) {
      ctx.push_str(suffix)
    }
    if name.given_name is Some(_) {
      ctx.push_str(sort_sep)
      let idx = ctx.push_format(first_format)
      let cidx = ctx.push_case(first_case)
      if first_affixes[0] is Some(prefix) {
        ctx.push_str(prefix)
      }
      first_name(ctx) |> ignore
      if name.prefix is Some(prefix) {
        ctx.ensure_space()
        ctx.push_str(prefix)
      }
      ctx.pop_case(cidx)
      ctx.pop_format(idx)
      if first_affixes[1] is Some(suffix) {
        ctx.push_str(suffix)
      }
    }
    if name.suffix is Some(suffix) {
      ctx.push_str(sort_sep)
      ctx.push_str(suffix)
    }
  }
  let reverse_demote_particle = (ctx : Context) => {
    let idx = ctx.push_format(family_format)
    let cidx = ctx.push_case(family_case)
    if family_affixes[0] is Some(prefix) {
      ctx.push_str(prefix)
    }
    ctx.push_str(name.name_without_particle())
    ctx.pop_case(cidx)
    ctx.pop_format(idx)
    if family_affixes[1] is Some(suffix) {
      ctx.push_str(suffix)
    }
    if name.given_name is Some(_) {
      ctx.push_str(sort_sep)
      let idx = ctx.push_format(first_format)
      let cidx = ctx.push_case(first_case)
      if first_affixes[0] is Some(prefix) {
        ctx.push_str(prefix)
      }
      first_name(ctx) |> ignore
      if name.prefix is Some(prefix) {
        ctx.ensure_space()
        ctx.push_str(prefix)
      }
      ctx.pop_case(cidx)
      ctx.pop_format(idx)
      if name.name_particle() is Some(particle) {
        ctx.ensure_space()
        ctx.push_str(particle)
      }
      if first_affixes[1] is Some(suffix) {
        ctx.push_str(suffix)
      }
    }
    if name.suffix is Some(suffix) {
      ctx.push_str(sort_sep)
      ctx.push_str(suffix)
    }
  }
  let elem_idx = ctx.push_elem(@citationberg.Formatting::default())
  let sorting = ctx.instance.sorting is Some(_)
  if name.is_institutional() && sorting {
    let idx = ctx.push_format(family_format)
    let cidx = ctx.push_case(family_case)
    // TODO make locale aware
    ctx.push_str(name.name_without_article())
    ctx.pop_case(cidx)
    ctx.pop_format(idx)
  } else if name.is_institutional() {
    simple(ctx)
  } else {
    match (form.is_long(), reverse, demote_non_dropping) {
      (true, _, _) if name.is_cjk() => {
        let idx = ctx.push_format(family_format)
        if family_affixes[0] is Some(prefix) {
          ctx.push_str(prefix)
        }
        ctx.push_str(name.name)
        ctx.pop_format(idx)
        if family_affixes[1] is Some(suffix) {
          ctx.push_str(suffix)
        }
        if name.given_name is Some(given) {
          let idx = ctx.push_format(first_format)
          if first_affixes[0] is Some(prefix) {
            ctx.push_str(prefix)
          }
          ctx.push_str(given)
          ctx.pop_format(idx)
          if first_affixes[1] is Some(suffix) {
            ctx.push_str(suffix)
          }
        }
      }
      // Always reverse when sorting.
      (true, _, false) if sorting => reverse_keep_particle(ctx)
      (true, _, true) if sorting => reverse_demote_particle(ctx)
      (true, true, false) => reverse_keep_particle(ctx)
      (true, true, true) => reverse_demote_particle(ctx)
      (true, false, _) => {
        let idx = ctx.push_format(first_format)
        let cidx = ctx.push_case(first_case)
        if first_affixes[0] is Some(prefix) {
          ctx.push_str(prefix)
        }
        first_name(ctx) |> ignore
        if name.prefix is Some(prefix) {
          ctx.ensure_space()
          ctx.push_str(prefix)
        }
        ctx.pop_format(idx)
        ctx.pop_case(cidx)
        if first_affixes[1] is Some(suffix) {
          ctx.push_str(suffix)
        }
        ctx.ensure_space()
        let idx = ctx.push_format(family_format)
        let cidx = ctx.push_case(family_case)
        if family_affixes[0] is Some(prefix) {
          ctx.push_str(prefix)
        }
        ctx.push_str(name.name)
        ctx.pop_case(cidx)
        ctx.pop_format(idx)
        if name.suffix is Some(suffix) {
          if comma_suffix {
            ctx.push_str(sort_sep)
          }
          ctx.ensure_space()
          ctx.push_str(suffix)
        }
        if family_affixes[1] is Some(suffix) {
          ctx.push_str(suffix)
        }
      }
      (false, _, _) => simple(ctx)
    }
  }
  ctx.commit_elem(elem_idx, None, Some(Name(variable, name_idx)))
}
