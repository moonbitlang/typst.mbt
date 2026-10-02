// Port of `hayagriva/src/csl/mod.rs`: the CSL processor.

///|
/// This struct formats a set of citations according to a style.
pub struct BibliographyDriver {
  /// The citations we have seen so far.
  priv citations : Array[CitationRequest]
  /// Offset to apply to the citation number (for numeric styles).
  priv mut citation_number_offset : Int
}

///|
/// Create a new bibliography driver.
pub fn BibliographyDriver::new() -> BibliographyDriver {
  { citations: [], citation_number_offset: 0, }
}

///|
/// Adds a citation number offset to the driver.
pub fn BibliographyDriver::with_citation_number_offset(
  self : BibliographyDriver,
  offset : Int,
) -> BibliographyDriver {
  self.citation_number_offset = offset
  self
}

///|
/// Create a new citation with the given items.
pub fn BibliographyDriver::citation(
  self : BibliographyDriver,
  req : CitationRequest,
) -> Unit {
  for i, item in req.items {
    item.initial_idx = i
  }
  self.citations.push(req)
}

///|
priv struct SpeculativeItemRender {
  mut rendered : ElemChildren
  entry : Entry
  cite_props : CiteProperties
  checked_disambiguate : Bool
  first_name : NameDisambiguationProperties?
  mut delim_override : String?
  mut group_idx : Int?
  locator : SpecificLocator?
  mut hidden : Bool
  locale : @citationberg.LocaleCode?
  purpose : CitePurpose?
  mut collapse_verdict : CollapseVerdict?
}

///|
priv struct SpeculativeCiteRender {
  items : Array[SpeculativeItemRender]
  request : CitationRequest
}

///|
/// Remove duplicates by structural equality, keeping the first occurrence
/// (upstream `IndexSet<&T>`).
fn dedup_entries(entries : Array[Entry]) -> Array[Entry] {
  let out = []
  for e in entries {
    if !out.iter().any(x => x == e) {
      out.push(e)
    }
  }
  out
}

///|
/// Render the bibliography.
pub fn BibliographyDriver::finish(
  self : BibliographyDriver,
  request : BibliographyRequest,
) -> Rendered {
  // 1.  Assign citation numbers by bibliography ordering or by citation
  //     order and render them a first time without their locators.
  let bib_style = request.style_context()

  // Only remember each entry once, even if it is cited multiple times.
  let entry_list = []
  for req in self.citations {
    for item in req.items {
      entry_list.push(item.entry)
    }
  }
  let entries = dedup_entries(entry_list).map(e => CitationItem::with_entry(e))
  bib_style.sort(
    entries,
    match bib_style.csl.bibliography {
      Some(b) => b.sort
      None => None
    },
    request.locale,
    _ => 0,
  )
  let citation_number = (item : Entry) => {
    let mut pos = -1
    for i, e in entries {
      if e.entry == item {
        pos = i
        break
      }
    }
    if pos < 0 {
      abort("entry not found")
    }
    self.citation_number_offset + pos
  }
  let seen : Array[Entry] = []
  let res : Array[SpeculativeCiteRender] = []
  let mut last_cite : CitationItem? = None
  for citation in self.citations {
    let style = citation.style_context()
    style.sort(
      citation.items,
      style.csl.citation.sort,
      citation.locale,
      citation_number,
    )
    let items = citation.items
    let renders : Array[SpeculativeItemRender] = []
    for item in items {
      let entry = item.entry
      let is_near_note = match citation.note_number {
        Some(_) => {
          let mut found = false
          let mut taken = 0
          let mut k = res.length() - 1
          while k >= 0 && taken < style.csl.citation.near_note_distance {
            let cite = res[k]
            if cite.request.note_number is Some(_) &&
              cite.items.iter().any(item => item.entry == entry) {
              found = true
              break
            }
            taken += 1
            k -= 1
          }
          found
        }
        None => false
      }
      let first_note_number = citation.note_number.map(n => {
        let mut out = None
        for cite in res {
          if cite.request.note_number is Some(nn) &&
            cite.items.iter().any(item => item.entry == entry) {
            out = Some(nn)
            break
          }
        }
        out.unwrap_or(n)
      })
      let is_first = !seen.iter().any(e => physical_equal(e, entry))
      if is_first {
        seen.push(entry)
      }
      let cite_props = CiteProperties::{
        certain: {
          note_number: citation.note_number,
          first_note_number,
          is_near_note,
          is_first,
          initial_idx: item.initial_idx,
        },
        speculative: SpeculativeCiteProperties::speculate(
          None,
          citation_number(entry),
          IbidState::with_last(item, last_cite),
        ),
      }
      let ctx = style.do_citation(
        entry,
        cite_props.copy(),
        item.locale,
        citation.locale,
        item.purpose,
        None,
      )

      // Copy the identifier usage from the context. Assume it does not
      // change throughout disambiguation.
      cite_props.speculative.identifier_usage = ctx.instance.identifier_usage
      ctx.instance.identifier_usage = NoneUsage
      renders.push({
        entry,
        cite_props,
        checked_disambiguate: ctx.writing.checked_disambiguate,
        first_name: ctx.writing.first_name,
        delim_override: None,
        group_idx: None,
        locator: item.locator,
        rendered: ctx.flush(),
        hidden: item.hidden,
        locale: item.locale,
        purpose: item.purpose,
        collapse_verdict: None,
      })
      last_cite = Some(item)
    }
    res.push({ items: renders, request: citation, })
  }

  // 2.  Disambiguate the citations.
  //
  // If we have set the disambiguation state for an item, we need to set the
  // same state for all entries referencing that item.
  for _ in 0..<3 {
    let ambiguous = find_ambiguous_sets(res)
    if ambiguous.is_empty() {
      break
    }
    let rerender : Array[(Entry, DisambiguateState)] = []
    let mark = (entry : Entry, state : DisambiguateState) => {
      for i, pair in rerender {
        if physical_equal(pair.0, entry) {
          rerender[i] = (entry, pair.1.max(state))
          return
        }
      }
      rerender.push((entry, state))
    }
    for group in ambiguous {
      // 2a. Name Disambiguation loop
      disambiguate_names(res, group, mark)

      // Do not try other methods if the previous method succeeded.
      if !rerender.is_empty() {
        continue
      }

      // 2b. Disambiguate by allowing `cs:choose` disambiguation.
      disambiguate_with_choose(res, group, mark)
      if !rerender.is_empty() {
        continue
      }

      // 2c. Disambiguate by year-suffix.
      disambiguate_year_suffix(res, group, mark)
    }
    if rerender.is_empty() {
      break
    }
    for cite in res {
      let style_ctx = cite.request.style_context()
      for item in cite.items {
        for pair in rerender {
          if physical_equal(pair.0, item.entry) {
            item.cite_props.speculative.disambiguation = pair.1
            item.rendered = do_rerender(style_ctx, item, cite.request)
            break
          }
        }
      }
    }
  }

  // 3. Group adjacent citations.
  for cite in res {
    // This map contains the last index of each entry with this names elem.
    let map : Map[String, Int] = Map([])
    let mut group_idx = 0
    for i in 0..<cite.items.length() {
      let citation = cite.request.style.citation
      let delim = match citation.cite_group_delimiter {
        Some(d) => Some(d)
        None =>
          match citation.layout.delimiter {
            Some(d) if citation.collapse is Some(_) => Some(d)
            _ => None
          }
      }
      guard delim is Some(delim) else { continue }
      guard cite.items[i].rendered.find_names() is Some(name_elem) else {
        continue
      }
      let name_elem = @debug.to_string(name_elem)
      let mut prev = None
      let target = match map.get(name_elem) {
        Some(t) => {
          prev = Some(t)
          map.set(name_elem, t + 1)
          t
        }
        None => {
          group_idx += 1
          map.set(name_elem, i)
          i
        }
      }
      let mut pos = i
      while target < pos {
        let tmp = cite.items[pos]
        cite.items[pos] = cite.items[pos - 1]
        cite.items[pos - 1] = tmp
        pos -= 1
      }
      cite.items[target].delim_override = Some(delim)
      cite.items[target].group_idx = Some(group_idx)
      if prev is Some(prev) {
        cite.items[prev].delim_override = None
      }
    }
  }

  // 4. Render citations with locator.
  // 4a. Make final calls on all [`SpeculativeCiteProperties`].
  //     - Re-check for ibid.
  for i in 0..<res.length() {
    for j in 0..<res[i].items.length() {
      // TODO filter is not hidden
      let last_render = if j == 0 && i == 0 {
        None
      } else if j == 0 {
        res[i - 1].items.last()
      } else {
        Some(res[i].items[j - 1])
      }
      let last = last_render.map(l => {
        CitationItem::with_locator(l.entry, l.locator)
      })
      let it = res[i].items[j]
      it.cite_props.speculative.ibid = IbidState::with_last(
        CitationItem::with_locator(it.entry, it.locator),
        last,
      )

      //     - Add final locator
      it.cite_props.speculative.locator = it.locator
    }
  }

  //     - Determine final citation number if bibliography does not sort.
  let bib_sort = match bib_style.csl.bibliography {
    Some(b) => b.sort
    None => None
  }
  if bib_sort is None {
    let seen_nums : Array[(Entry, Int)] = []
    let mut start = self.citation_number_offset
    for cite in res {
      for item in cite.items {
        let mut num = -1
        for pair in seen_nums {
          if physical_equal(pair.0, item.entry) {
            num = pair.1
            break
          }
        }
        if num < 0 {
          num = start
          start += 1
          seen_nums.push((item.entry, num))
        }
        item.cite_props.speculative.citation_number = num
      }
    }
  }

  // Rerender.
  let final_citations : Array[RenderedCitation] = []
  for cite in res {
    let style_ctx = cite.request.style_context()
    // 5. Collapse grouped citations.
    if cite.request.items.iter().all(c => c.purpose is None) {
      collapse_items(cite)
    }
    for item in cite.items {
      item.rendered = last_purpose_render(style_ctx, item, cite.request)
    }

    // 6. Add affixes.
    let formatting = Formatting::default().apply(
      cite.request.style.citation.layout.to_formatting(),
    )
    final_citations.push({
      note_number: cite.request.note_number,
      citation: if cite.items.iter().all(i => i.hidden) {
        ElemChildren::new()
      } else {
        let elem_children : Array[ElemChild] = []
        if cite.request.prefix() is Some(prefix) {
          elem_children.push(Text({ text: prefix, formatting, }))
        }
        for i, item in cite.items {
          if item.hidden {
            continue
          }
          if i != 0 {
            let delim = match item.delim_override {
              Some(d) => Some(d)
              None => cite.request.style.citation.layout.delimiter
            }
            if delim is Some(delim) {
              elem_children.push(Text({ text: delim, formatting, }))
            }
          }
          elem_children.push(
            Elem({
              children: item.rendered.copy(),
              display: None,
              meta: Some(Entry(item.cite_props.certain.initial_idx)),
            }),
          )
        }
        if cite.request.suffix() is Some(suffix) {
          let print = match last_text_child(elem_children) {
            None => true
            Some(t) => !t.text.has_suffix(suffix)
          }
          if print {
            elem_children.push(Text({ text: suffix, formatting, }))
          }
        }
        simplify_children(ElemChildren(elem_children))
      },
    })
  }
  let bib_render = match request.style.bibliography {
    Some(bibliography) => {
      let items : Array[(ElemChildren, String)] = []
      for entry in entries {
        let mut cited_item = None
        for cite in res {
          for item in cite.items {
            if item.entry == entry.entry {
              cited_item = Some(item)
              break
            }
          }
          if cited_item is Some(_) {
            break
          }
        }
        let cited_item = cited_item.unwrap()
        items.push(
          (
            simplify_children(
              bib_style
              .bibliography(
                entry.entry,
                {
                  certain: cited_item.cite_props.certain,
                  speculative: cited_item.cite_props.speculative.for_bibliography(),
                },
                cited_item.locale,
                request.locale,
              )
              .unwrap(),
            ),
            entry.entry.key,
          ),
        )
      }
      substitute_subsequent_authors(
        bibliography.subsequent_author_substitute,
        bibliography.subsequent_author_substitute_rule,
        items,
      )
      Some({
        hanging_indent: bibliography.hanging_indent,
        second_field_align: bibliography.second_field_align,
        line_spacing: bibliography.line_spacing,
        entry_spacing: bibliography.entry_spacing,
        items: items.map(pair => {
          let (i, key) = pair
          if bibliography.second_field_align is Some(_) {
            let first = i.remove_any_meta()
            BibliographyItem::{ key, first_field: first, content: i, }
          } else {
            BibliographyItem::{ key, first_field: None, content: i, }
          }
        }),
      })
    }
    None => None
  }
  { bibliography: bib_render, citations: final_citations, }
}

///|
/// Create a new citation with the given items. Bibliography-wide
/// disambiguation and some other features will not be applied.
pub fn standalone_citation(req : CitationRequest) -> ElemChildren {
  let style = req.style_context()
  style.sort(req.items, style.csl.citation.sort, req.locale, _ => 0)
  let res = []
  let mut all_hidden = true
  for item in req.items {
    if item.hidden {
      continue
    } else {
      all_hidden = false
    }
    res.push(
      if item.purpose is Some(Year) {
        date_replacement(
          style,
          item.entry,
          CiteProperties::for_sorting(item.locator, 0),
          req.locale,
          item.locale,
        )
      } else {
        style.citation(
          item.entry,
          CiteProperties::for_sorting(item.locator, 0),
          item.locale,
          req.locale,
          item.purpose,
          None,
        )
      },
    )
  }
  let non_empty = res.filter(c => c.has_content())
  let formatting = Formatting::default().apply(
    style.csl.citation.layout.to_formatting(),
  )
  if !non_empty.is_empty() && !all_hidden {
    let res = match style.csl.citation.layout.prefix {
      Some(prefix) => ElemChildren([Text({ text: prefix, formatting, })])
      None => ElemChildren::new()
    }
    for i, elem_children in non_empty {
      let first = i == 0
      if !first {
        res.0.push(
          Text({
            text: style.csl.citation.layout.delimiter.unwrap_or(
              @citationberg.citation_default_cite_group_delimiter,
            ),
            formatting,
          }),
        )
      }
      res.0.append(elem_children.0)
    }
    if style.csl.citation.layout.suffix is Some(suffix) {
      let print = match res.last_text() {
        None => true
        Some(t) => !t.text.has_suffix(suffix)
      }
      if print {
        res.0.push(Text({ text: suffix, formatting, }))
      }
    }
    simplify_children(res)
  } else {
    ElemChildren::new()
  }
}

///|
fn do_rerender(
  ctx : StyleContext,
  item : SpeculativeItemRender,
  request : CitationRequest,
) -> ElemChildren {
  ctx.citation(
    item.entry,
    item.cite_props.copy(),
    item.locale,
    request.locale,
    item.purpose,
    item.collapse_verdict,
  )
}

///|
fn date_replacement(
  ctx : StyleContext,
  entry : Entry,
  cite_props : CiteProperties,
  term_locale : @citationberg.LocaleCode?,
  locale : @citationberg.LocaleCode?,
) -> ElemChildren {
  let date = entry.resolve_date_variable(Issued)
  let date = opt_or(date, () => entry.resolve_date_variable(EventDate))
  let date = opt_or(date, () => entry.resolve_date_variable(Submitted))
  let date = opt_or(date, () => entry.resolve_date_variable(OriginalDate))
  let text = match date {
    Some(date) => {
      let s = StrBuf::new()
      let c = ctx.ctx(entry, cite_props.copy(), locale, term_locale, false)
      let ad = c.term(Other(Ad), Long, false).unwrap_or(" AD")
      let bc = c.term(Other(Bc), Long, false).unwrap_or(" BC")
      write_year(date.year, false, s, ad, bc)
      s.to_string()
    }
    None =>
      match
        ctx
        .ctx(entry, cite_props.copy(), locale, term_locale, false)
        .term(Other(NoDate), Long, false) {
        Some(no_date) => no_date
        None => "n.d."
      }
  }
  ElemChildren([Text({ text, formatting: Formatting::default(), })])
}

///|
/// Write a year with the AD/BC terms.
pub fn[W : FmtWrite] write_year(
  year : Int,
  short : Bool,
  w : W,
  ad : String,
  bc : String,
) -> Unit {
  if short && year >= 1000 {
    fmt_int_zero_pad(w, (year % 100).to_int64(), 2)
    return
  }
  fmt_int(w, (if year > 0 { year } else { year.abs() + 1 }).to_int64())
  w.write_str(
    if year < 1000 {
      if year <= 0 {
        bc
      } else {
        // AD is used as a postfix, see
        // https://docs.citationstyles.org/en/stable/specification.html?#ad-and-bc
        ad
      }
    } else {
      ""
    },
  )
}

///|
fn last_purpose_render(
  ctx : StyleContext,
  item : SpeculativeItemRender,
  request : CitationRequest,
) -> ElemChildren {
  if item.purpose is Some(Year) {
    date_replacement(
      ctx,
      item.entry,
      item.cite_props,
      request.locale,
      item.locale,
    )
  } else {
    do_rerender(ctx, item, request)
  }
}

///|
/// Get all names in `children`.
///
/// **NOTE**: These not just the rendered names, but all names where the
/// corresponding variable occurs.
fn get_names(children : ElemChildren) -> Array[Person] {
  fn helper(children : ElemChildren, persons : Array[Person]) -> Unit {
    for c in children.0 {
      if c is Elem(e) {
        if e.meta is Some(Names(ns)) {
          for pair in ns {
            persons.append(pair.0)
          }
        }
        helper(e.children, persons)
      }
    }
  }

  let res = []
  helper(children, res)
  res
}

///|
/// A state used for disambiguation.
priv struct DisambData {
  /// The citation index of the item.
  cite_id : Int
  /// The item index.
  item_id : Int
  /// Names occurring in this citation item.
  names : Array[Person]
  /// The related speculative render
  item : SpeculativeItemRender
}

///|
fn DisambData::same(self : DisambData, other : DisambData) -> Bool {
  self.cite_id == other.cite_id && self.item_id == other.item_id
}

///|
/// Returns true iff the item `x` is fully disambiguated w.r.t. `xs` where
/// the first `et_al_min` are added and the `rule` is applied.
fn is_disambiguated(
  et_al_min : Int,
  xs : Array[DisambData],
  x : DisambData,
  rule : @citationberg.DisambiguationRule?,
) -> Bool {
  fn name_parts(
    names : Array[Person],
    rule : @citationberg.DisambiguationRule?,
  ) -> Array[Person] {
    match rule {
      Some(AllNames | ByCite) => names
      Some(AllNamesWithInitials) =>
        names.map(n => {
          let given = StrBuf::new()
          n.initials(given, None, false)
          { ..n, given_name: Some(given.to_string()), }
        })
      Some(PrimaryName) =>
        names.mapi((i, n) => if i == 0 { n } else { { ..n, given_name: None, } })
      Some(PrimaryNameWithInitials) =>
        names.mapi((i, n) => {
          if i == 0 {
            let given = StrBuf::new()
            n.initials(given, None, false)
            { ..n, given_name: Some(given.to_string()), }
          } else {
            { ..n, given_name: None, }
          }
        })
      None => names.map(n => { ..n, given_name: None, })
    }
  }

  let disamb_name = (x : DisambData) => {
    let taken = if x.names.length() > et_al_min {
      x.names[0:et_al_min].to_owned()
    } else {
      x.names
    }
    name_parts(taken, rule)
  }
  let disamb_x = disamb_name(x)
  xs.iter().all(y => x.same(y) || disamb_name(y) != disamb_x)
}

///|
/// Adds a given name (potentially only the initial) to the name `x` if it
/// disambiguates w.r.t. `xs`. Returns the new form if it changed.
///
/// **Note**: This is only used to disambiguate a citation. Disambiguation of
/// names needs to be handled differently.
fn disamb_cite_add_given_name(
  x : Person,
  xs : Array[Person],
  form : DisambiguatedNameForm,
) -> (Bool, DisambiguatedNameForm) {
  if form == Count {
    // Cannot disambiguate
    return (false, form)
  }
  if form == LongFull {
    // Cannot expand full name
    return (false, form)
  }
  let mut form = form
  let mut changed = false
  for p in xs {
    if physical_equal(x, p) || x == p || x.name != p.name {
      continue
    }
    let xi = StrBuf::new()
    x.initials(xi, None, false)
    let pi = StrBuf::new()
    p.initials(pi, None, false)
    if xi.to_string() == pi.to_string() {
      return (true, LongFull)
    }
    if form != LongInitialized {
      form = LongInitialized
      changed = true
    }
  }
  (changed, form)
}

///|
/// Progressively transform names to disambiguate them.
fn disambiguate_names(
  renders : Array[SpeculativeCiteRender],
  group : Array[(Int, Int)],
  mark : (Entry, DisambiguateState) -> Unit,
) -> Unit {
  let group = group.map(pair => {
    let (cite_id, item_id) = pair
    let item = renders[cite_id].items[item_id]
    DisambData::{ cite_id, item_id, names: get_names(item.rendered), item, }
  })

  // How many names can we add at most? If we are not allowed to add names,
  // it is only one.
  let max_names = if renders[0].request.style.citation.disambiguate_add_names {
    let mut m = 0
    for d in group {
      if d.names.length() > m {
        m = d.names.length()
      }
    }
    m
  } else {
    1
  }

  // Tracks changes to the disambiguation state
  let changed_states : Array[((Int, Int), DisambiguateState)] = []
  let get_changed = (key : (Int, Int)) => {
    for pair in changed_states {
      if pair.0 == key {
        return Some(pair.1)
      }
    }
    None
  }
  let set_changed = (key : (Int, Int), state : DisambiguateState) => {
    for i, pair in changed_states {
      if pair.0 == key {
        changed_states[i] = (key, state)
        return
      }
    }
    changed_states.push((key, state))
  }
  // Tracks already disambiguated items
  let disambiguated : Array[(Int, Int)] = []
  let insert_disambiguated = (key : (Int, Int)) => {
    if !disambiguated.contains(key) {
      disambiguated.push(key)
    }
  }
  let name_props_slot = (d : DisambData) => {
    match get_changed((d.cite_id, d.item_id)) {
      Some(NameDisambiguation(ndp)) => Some(ndp)
      _ =>
        match d.item.cite_props.speculative.disambiguation {
          NameDisambiguation(n) => Some(n)
          _ => d.item.first_name
        }
    }
  }

  // Successively add names
  for i in 1..<=max_names {
    let disamb_len = disambiguated.length()
    if disamb_len == group.length() {
      // Already fully disambiguated
      break
    }
    for d in group {
      if disambiguated.contains((d.cite_id, d.item_id)) {
        // Already done
        continue
      }
      let style = renders[d.cite_id].request.style
      // We only apply the rule if we are allowed to.
      let rule = if style.citation.disambiguate_add_givenname {
        Some(style.citation.givenname_disambiguation_rule)
      } else {
        None
      }
      if !d.item.cite_props.speculative.disambiguation.may_disambiguate_names() {
        continue
      }
      if is_disambiguated(i, group, d, rule) {
        // Adding a name would disambiguate, so lets add it
        insert_disambiguated((d.cite_id, d.item_id))

        // Only add given names here for "by-cite"; all other cases must take
        // all names into account and must be handled elsewhere
        if rule == Some(ByCite) {
          if name_props_slot(d) is Some(props) {
            let props = props.copy()
            if props.get_form(i - 1) is Some(form) {
              // Try to add a given name
              let others = []
              for o in group {
                if o.cite_id != d.cite_id || o.item_id != d.item_id {
                  others.append(o.names)
                }
              }
              let (changed, new_form) = disamb_cite_add_given_name(
                d.names[i - 1],
                others,
                form,
              )
              props.set_form(i - 1, new_form)
              if changed {
                set_changed((d.cite_id, d.item_id), NameDisambiguation(props))
                insert_disambiguated((d.cite_id, d.item_id))
              }
            }
          }
        }
      }
    }
    if disambiguated.length() > disamb_len {
      for d in group {
        if name_props_slot(d) is Some(state) {
          let state = state.copy()
          state.add_name(i) |> ignore
          set_changed((d.cite_id, d.item_id), NameDisambiguation(state))
        }
      }
    }
  }

  // Mark all changed states
  for pair in changed_states {
    let ((cite_id, item_id), s) = pair
    let entry = renders[cite_id].items[item_id].entry
    mark(entry, s)
  }
}

///|
/// Mark qualifying entries for disambiguation with `cs:choose`.
fn disambiguate_with_choose(
  renders : Array[SpeculativeCiteRender],
  group : Array[(Int, Int)],
  mark : (Entry, DisambiguateState) -> Unit,
) -> Unit {
  if group
    .iter()
    .any(pair => {
      let item = renders[pair.0].items[pair.1]
      item.checked_disambiguate &&
      item.cite_props.speculative.disambiguation.may_disambiguate_with_choose()
    }) {
    // Do not set this for the first qualifying entry.
    let mut armed = false
    for pair in group {
      let item = renders[pair.0].items[pair.1]
      if item.checked_disambiguate {
        if armed {
          mark(item.entry, Choose)
        } else {
          armed = true
        }
      }
    }
  }
}

///|
/// Mark qualifying entries for disambiguation with year suffixes.
fn disambiguate_year_suffix(
  renders : Array[SpeculativeCiteRender],
  group : Array[(Int, Int)],
  mark : (Entry, DisambiguateState) -> Unit,
) -> Unit {
  let any_date = renders
    .iter()
    .any(r => {
      r.items
      .iter()
      .any(i => {
        let e = i.entry
        let entry_has_date = e.resolve_date_variable(Issued) is Some(_) ||
          e.resolve_date_variable(Accessed) is Some(_) ||
          e.resolve_date_variable(AvailableDate) is Some(_) ||
          e.resolve_date_variable(EventDate) is Some(_) ||
          e.resolve_date_variable(Submitted) is Some(_) ||
          e.resolve_date_variable(OriginalDate) is Some(_)
        i.rendered.find_elem_by(e => {
          // The citation label will contain the date if there is one.
          e.meta == Some(Date) ||
          (entry_has_date && e.meta == Some(CitationLabel))
        })
        is Some(_)
      })
    })
  if any_date &&
    group
    .iter()
    .any(pair => {
      renders[pair.0].request.style.citation.disambiguate_add_year_suffix &&
      renders[pair.0].items[pair.1].cite_props.speculative.disambiguation.may_disambiguate_with_year_suffix()
    }) {
    let entries : Array[Entry] = []
    for pair in group {
      let item = renders[pair.0].items[pair.1]
      if item.cite_props.speculative.disambiguation.may_disambiguate_with_year_suffix() &&
        !entries.iter().any(e => e == item.entry) {
        entries.push(item.entry)
      }
    }

    // Assign year suffixes.
    for i, entry in entries {
      mark(entry, YearSuffix(i % 256))
    }
  }
}

///|
/// Return a vector that contains every group of mutually ambiguous items
/// with cite and item index.
fn find_ambiguous_sets(
  cites : Array[SpeculativeCiteRender],
) -> Array[Array[(Int, Int)]] {
  // `Ok(pos)`: a single item produced this string; `Err(idx)`: there were
  // multiple matches (the index in the result vector).
  let map : Map[String, Result[(Int, Int), Int]] = Map([])
  let res : Array[Array[(Int, Int)]] = []
  for i, cite in cites {
    for j, item in cite.items {
      if !item.cite_props.speculative.disambiguation.may_disambiguate_with_year_suffix() {
        // There is nothing we can do.
        continue
      }
      let buf = item.rendered.to_string()
      match map.get(buf) {
        Some(Ok(pos)) => {
          map.set(buf, Err(res.length()))
          res.push([pos, (i, j)])
        }
        Some(Err(idx)) => res[idx].push((i, j))
        None => map.set(buf, Ok((i, j)))
      }
    }
  }

  // Only return items if not every item points to the same entry.
  res.filter(e => {
    guard e.get(0) is Some((c0, i0)) else { return false }
    let first_entry = cites[c0].items[i0].entry
    e.iter().any(pair => cites[pair.0].items[pair.1].entry != first_entry)
  })
}

///|
fn collapse_items(cite : SpeculativeCiteRender) -> Unit {
  let style = cite.request.style
  let after_collapse_delim = match style.citation.after_collapse_delimiter {
    Some(d) => Some(d)
    None => style.citation.layout.delimiter
  }
  let group_delimiter = style.citation.cite_group_delimiter
  let year_suffix_delimiter = match style.citation.year_suffix_delimiter {
    Some(d) => Some(d)
    None => style.citation.cite_group_delimiter
  }
  match style.citation.collapse {
    Some(CitationNumber) => {
      // Option with the start and end of the range.
      let mut range_start : (Int, Int)? = None
      let mut just_collapsed = false
      let items = cite.items
      let end_range = () => {
        let use_after_collapse_delim = just_collapsed
        just_collapsed = false
        if range_start is Some((start, end)) {
          // If the previous citation range was collapsed, use the
          // after-collapse delimiter before the next item.
          if use_after_collapse_delim {
            items[start].delim_override = after_collapse_delim
          }

          // There should be at least three items in the range to collapse.
          if start + 1 < end {
            items[end].delim_override = Some("–")
            for k in (start + 1)..<end {
              items[k].hidden = true
            }
            just_collapsed = true
          }
        }
        range_start = None
      }
      for i in 0..<items.length() {
        let item = items[i]
        if item.hidden || item.rendered.find_meta(CitationNumber) is None {
          end_range()
          continue
        }
        let citation_number = item.cite_props.speculative.citation_number
        let prev_citation_number = match range_start {
          Some((_, end)) =>
            Some(items[end].cite_props.speculative.citation_number)
          None => None
        }
        match (range_start, prev_citation_number) {
          (Some((start, end)), Some(prev)) if end + 1 == i &&
            prev + 1 == citation_number =>
            // Extend the range.
            range_start = Some((start, i))
          _ => {
            end_range()
            range_start = Some((i, i))
          }
        }
      }
      end_range()
    }
    Some(Year as c) | Some(YearSuffix as c) | Some(YearSuffixRanged as c) => {
      // Index of where the current group started and the group we are
      // currently in.
      let mut group_idx : (Int, Int)? = None
      for i in 0..<cite.items.length() {
        let item = cite.items[i]
        match group_idx {
          // This is our group.
          Some((_, idx)) if Some(idx) == item.group_idx => {
            if c == YearSuffix &&
              item.cite_props.speculative.disambiguation is YearSuffix(s) &&
              s > 0 {
              // We want to collapse the years up to the suffix and the
              // current item has a year suffix greater than zero, which
              // means it follows another item with the same year. In this
              // case, we collapse the year suffix.
              item.delim_override = year_suffix_delimiter
              item.collapse_verdict = Some(CollapseYearSuffix)
              continue
            }
            // FIXME: Retains delimiter in names.
            item.delim_override = group_delimiter
            item.collapse_verdict = Some(First)
          }
          // This is a different group.
          Some((start, _)) if start + 1 < i => {
            item.delim_override = after_collapse_delim
            group_idx = item.group_idx.map(idx => (i, idx))
          }
          // We are at the beginning.
          _ => group_idx = item.group_idx.map(idx => (i, idx))
        }
      }
      // TODO: Year ranged.
    }
    None => ()
  }
}

///|
fn substitute_subsequent_authors(
  subs : String?,
  rule : @citationberg.SubsequentAuthorSubstituteRule,
  items : Array[(ElemChildren, String)],
) -> Unit {
  guard subs is Some(subs) else { return }
  let mut rule = rule
  let subs = Formatting::default().add_text(subs)
  fn copy_subs(subs : Formatted) -> ElemChild {
    Text({ text: subs.text, formatting: subs.formatting, })
  }

  fn remove_name(child : Elem) -> ElemChild? {
    if child.meta is Some(Name(_, _)) {
      return None
    }
    let children = []
    for e in child.children.0 {
      match e {
        Elem(e) => if remove_name(e) is Some(c) { children.push(c) }
        _ => children.push(e)
      }
    }
    child.children = ElemChildren(children)
    Some(Elem(child))
  }

  fn replace_all(names : Elem, is_empty : Bool, subs : Formatted) -> Unit {
    let old_children = names.children
    names.children = ElemChildren([copy_subs(subs)])
    if !is_empty {
      for child in old_children.0 {
        match child {
          Elem(e) => if remove_name(e) is Some(c) { names.children.0.push(c) }
          _ => names.children.0.push(child)
        }
      }
    }
  }

  fn replace_name(e : Elem, subs : Formatted) -> (ElemChild, Bool) {
    if e.meta is Some(Name(_, _)) {
      return (
        Elem({
          children: ElemChildren([copy_subs(subs)]),
          display: e.display,
          meta: e.meta,
        }),
        true,
      )
    }
    let children = []
    let mut changed = false
    let mut k = 0
    while k < e.children.0.length() {
      let c = e.children.0[k]
      k += 1
      match c {
        Elem(ec) => {
          let (nc, ch) = replace_name(ec, subs)
          children.push(nc)
          if ch {
            changed = true
            break
          }
        }
        _ => children.push(c)
      }
    }
    while k < e.children.0.length() {
      children.push(e.children.0[k])
      k += 1
    }
    (
      Elem({
        display: e.display,
        meta: e.meta,
        children: ElemChildren(children),
      }),
      changed,
    )
  }

  fn replace_each(names : Elem, subs : Formatted) -> Unit {
    let old_children = names.children
    names.children = ElemChildren([copy_subs(subs)])
    for child in old_children.0 {
      match child {
        Elem(e) => names.children.0.push(replace_name(e, subs).0)
        _ => names.children.0.push(child)
      }
    }
  }

  fn get_names_(elem : Elem, names : Array[Elem]) -> Unit {
    if elem.meta is Some(Name(_, _)) {
      names.push(elem.copy())
    } else {
      for c in elem.children.0 {
        if c is Elem(e) {
          get_names_(e, names)
        }
      }
    }
  }

  fn replace_first_n(num : Int, names : Elem, subs : Formatted) -> Unit {
    let mut num = num
    let old_children = names.children
    names.children = ElemChildren([copy_subs(subs)])
    for child in old_children.0 {
      if num == 0 {
        break
      }
      match child {
        Elem(e) => {
          let (c, changed) = replace_name(e, subs)
          names.children.0.push(c)
          if changed {
            num -= 1
          }
        }
        _ => names.children.0.push(child)
      }
    }
  }

  fn num_of_matches(ns1 : Array[Elem], ns2 : Array[Elem]) -> Int {
    let mut n = 0
    while n < ns1.length() && n < ns2.length() && ns1[n] == ns2[n] {
      n += 1
    }
    n
  }

  let mut last_names : (Elem, Array[Elem])? = None
  for item in items {
    let ec = item.0
    guard ec.find_names() is Some(names_elem) else { continue }
    let xnames = []
    get_names_(names_elem, xnames)
    guard last_names is Some((lnames_elem, lnames)) else {
      // No previous name; nothing to replace. Save and skip
      last_names = Some((names_elem.copy(), xnames))
      continue
    }
    if xnames.is_empty() {
      rule = CompleteAll
    }
    match rule {
      CompleteAll =>
        if lnames == xnames && (!xnames.is_empty() || names_elem == lnames_elem) {
          let names = ec.find_names_mut().unwrap()
          replace_all(names, xnames.is_empty(), subs)
        } else {
          last_names = Some((names_elem.copy(), xnames))
        }
      CompleteEach =>
        if lnames == xnames {
          let names = ec.find_names_mut().unwrap()
          replace_each(names, subs)
        } else {
          last_names = Some((names_elem.copy(), xnames))
        }
      PartialEach => {
        let nom = num_of_matches(xnames, lnames)
        if nom > 0 {
          let names = ec.find_names_mut().unwrap()
          replace_first_n(nom, names, subs)
        } else {
          last_names = Some((names_elem.copy(), xnames))
        }
      }
      PartialFirst => {
        let nom = num_of_matches(xnames, lnames)
        if nom > 0 {
          let names = ec.find_names_mut().unwrap()
          replace_first_n(1, names, subs)
        } else {
          last_names = Some((names_elem.copy(), xnames))
        }
      }
    }
  }
}

///|
/// What we have decided for rerendering this item.
priv enum CollapseVerdict {
  /// Only the first date should be printed.
  First
  /// Only the year suffix should be printed.
  CollapseYearSuffix
} derive(Eq)

///|
/// The result of [`BibliographyDriver::finish`].
pub(all) struct Rendered {
  /// The bibliography items.
  bibliography : RenderedBibliography?
  /// The citation items.
  citations : Array[RenderedCitation]
} derive(Debug)

///|
/// A fully rendered bibliography.
pub(all) struct RenderedBibliography {
  /// Render the bibliography in a hanging indent.
  hanging_indent : Bool
  /// When set, the second field is aligned.
  second_field_align : @citationberg.SecondFieldAlign?
  /// The line spacing within the bibliography as a multiple of regular line
  /// spacing.
  line_spacing : Int
  /// Extra space between entries as a multiple of line height.
  entry_spacing : Int
  /// The bibliography items. The first item may be some if
  /// `second_field_align` is set. Then, it is the first field that must be
  /// treated specially.
  items : Array[BibliographyItem]
} derive(Debug)

///|
/// A fully rendered bibliography item.
pub(all) struct BibliographyItem {
  /// The item's key as specified in the bibliography.
  key : String
  /// The item's first field. Only available when required by the
  /// `second-field-align` CSL property.
  first_field : ElemChild?
  /// The rendered item.
  content : ElemChildren
} derive(Debug)

///|
/// A fully rendered citation.
pub(all) struct RenderedCitation {
  /// The footnote number for this citation.
  note_number : Int?
  /// The citation.
  citation : ElemChildren
} derive(Debug)

///|
priv enum Sorting {
  Variable
  Macro
} derive(Eq)

///|
/// A context that contains all information related to rendering a single
/// entry.
priv struct InstanceContext {
  /// The current entry.
  entry : Entry
  /// The position of this citation in the list of citations.
  cite_props : CiteProperties
  /// Whether we are sorting or formatting right now and if we are sorting
  /// with a variable or macro sort key.
  sorting : Sorting?
  /// The locale for the content in the entry.
  locale : @citationberg.LocaleCode?
  /// The locale for the terms.
  term_locale : @citationberg.LocaleCode?
  /// Whether this citation should respect a special form.
  mut kind : SpecialForm?
  /// Which labels were written.
  mut identifier_usage : IdentifierUsage
}

///|
fn InstanceContext::new(
  entry : Entry,
  cite_props : CiteProperties,
  sorting : Sorting?,
  locale : @citationberg.LocaleCode?,
  term_locale : @citationberg.LocaleCode?,
  kind : SpecialForm?,
) -> InstanceContext {
  {
    entry,
    sorting,
    locale,
    term_locale,
    kind,
    identifier_usage: cite_props.speculative.identifier_usage,
    cite_props,
  }
}

///|
fn InstanceContext::variable_sort_instance(
  item : CitationItem,
  idx : Int,
) -> InstanceContext {
  InstanceContext::new(
    item.entry,
    CiteProperties::for_sorting(item.locator, idx),
    Some(Variable),
    None,
    None,
    None,
  )
}

///|
/// A context that contains information about the style we are using to
/// render.
priv struct StyleContext {
  /// The settings of the style.
  csl : @citationberg.IndependentStyle
  /// A list of locales defined in their respective locale file.
  locale_files : Array[@citationberg.Locale]
  /// Which locale we're using.
  locale_override : @citationberg.LocaleCode?
}

///|
fn StyleContext::new(
  style : @citationberg.IndependentStyle,
  locale : @citationberg.LocaleCode?,
  locale_files : Array[@citationberg.Locale],
) -> StyleContext {
  { csl: style, locale_files, locale_override: locale, }
}

///|
fn StyleContext::ctx(
  self : StyleContext,
  entry : Entry,
  cite_props : CiteProperties,
  locale : @citationberg.LocaleCode?,
  term_locale : @citationberg.LocaleCode?,
  bibliography : Bool,
) -> Context {
  {
    instance: InstanceContext::new(
      entry,
      cite_props,
      None,
      locale,
      term_locale,
      None,
    ),
    style: self,
    writing: WritingContext::new(self.csl.settings.options),
    bibliography,
  }
}

///|
fn StyleContext::macro_sorting_ctx(
  self : StyleContext,
  item : CitationItem,
  idx : Int,
  locale : @citationberg.LocaleCode?,
  term_locale : @citationberg.LocaleCode?,
  bibliography : Bool,
) -> Context {
  {
    instance: InstanceContext::new(
      item.entry,
      CiteProperties::for_sorting(item.locator, idx),
      Some(Macro),
      locale,
      term_locale,
      None,
    ),
    style: self,
    writing: WritingContext::new(self.csl.settings.options),
    bibliography,
  }
}

///|
/// Render the given item within a citation.
fn StyleContext::citation(
  self : StyleContext,
  entry : Entry,
  props : CiteProperties,
  locale : @citationberg.LocaleCode?,
  term_locale : @citationberg.LocaleCode?,
  kind : CitePurpose?,
  collapse_verdict : CollapseVerdict?,
) -> ElemChildren {
  let ctx = self.do_citation(
    entry, props, locale, term_locale, kind, collapse_verdict,
  )
  ctx.flush()
}

///|
/// Render the given item within a bibliography.
fn StyleContext::bibliography(
  self : StyleContext,
  entry : Entry,
  props : CiteProperties,
  locale : @citationberg.LocaleCode?,
  term_locale : @citationberg.LocaleCode?,
) -> ElemChildren? {
  self
  .do_bibliography(entry, props, locale, term_locale)
  .map(ctx => ctx.flush())
}

///|
/// Render the given item within a citation.
fn StyleContext::do_citation(
  self : StyleContext,
  entry : Entry,
  props : CiteProperties,
  locale : @citationberg.LocaleCode?,
  term_locale : @citationberg.LocaleCode?,
  kind : CitePurpose?,
  collapse_verdict : CollapseVerdict?,
) -> Context {
  let ctx = self.ctx(entry, props, locale, term_locale, false)
  let do_regular = (ctx : Context) => {
    let reset = if ctx.instance.kind is None {
      match collapse_verdict {
        Some(First) => {
          ctx.set_special_form(Some(OnlyFirstDate))
          true
        }
        Some(CollapseYearSuffix) => {
          ctx.set_special_form(Some(OnlyYearSuffix))
          true
        }
        None => false
      }
    } else {
      false
    }
    ctx.writing.push_name_options(self.csl.citation.name_options)
    render_layout(self.csl.citation.layout, ctx)
    ctx.writing.pop_name_options()
    if reset {
      ctx.set_special_form(None)
    }
  }
  let do_author = (ctx : Context) => {
    let author_var = @citationberg.Variable::Name(
      if entry.resolve_name_variable(Author).is_empty() &&
        !entry.resolve_name_variable(Editor).is_empty() {
        Editor
      } else {
        Author
      },
    )
    if will_render_layout(self.csl.citation.layout, ctx, author_var) {
      // Render name from citation.
      ctx.set_special_form(Some(VarOnly(author_var)))
      do_regular(ctx)
    } else {
      let mut needs_bibliography = true

      // Render name from citation with ibid forced to Different.
      if ctx.instance.cite_props.speculative.ibid != Different {
        let prev_ibid = ctx.instance.cite_props.speculative.ibid
        ctx.instance.cite_props.speculative.ibid = Different
        if will_render_layout(self.csl.citation.layout, ctx, author_var) {
          ctx.set_special_form(Some(VarOnly(author_var)))
          do_regular(ctx)
          needs_bibliography = false
        }
        ctx.instance.cite_props.speculative.ibid = prev_ibid
      }
      if needs_bibliography {
        // Render name from bibliography.
        ctx.set_special_form(Some(VarOnly(author_var)))
        let needs_synthesis = match self.csl.bibliography {
          Some(bibliography) =>
            if will_render_layout(bibliography.layout, ctx, author_var) {
              ctx.writing.push_name_options(bibliography.name_options)
              render_layout(bibliography.layout, ctx)
              ctx.writing.pop_name_options()
              false
            } else {
              true
            }
          None => true
        }
        if needs_synthesis {
          // We build our own name and render it with the citation's
          // properties.
          let layout = @citationberg.Layout::new(
            [Names(@citationberg.Names::with_variables([Author]))],
            self.csl.citation.layout.to_formatting(),
            None,
            None,
          )
          ctx.writing.push_name_options(self.csl.citation.name_options)
          render_layout(layout, ctx)
          ctx.writing.pop_name_options()
        }
      }
    }
    ctx.set_special_form(None)
  }
  match (kind, self.csl.bibliography) {
    (Some(Author), _) => do_author(ctx)
    (Some(Full), Some(bib)) => {
      ctx.writing.push_name_options(bib.name_options)
      render_layout(bib.layout, ctx)
      ctx.writing.pop_name_options()
      if bib.second_field_align is Some(_) &&
        ctx.writing.elem_stack.first().remove_any_meta() is Some(t) {
        match t {
          Text(t) => t.text = t.text + " "
          Elem(e) =>
            if e.children.last_text() is Some(t) {
              t.text = t.text + " "
            }
          _ => ()
        }
        ctx.writing.elem_stack.first().0.insert(0, t)
      }
    }
    (Some(Prose), _) => {
      do_author(ctx)
      let prefix_starts_ws = match self.csl.citation.layout.prefix {
        Some(f) =>
          match @unscanny.first_char(f) {
            Some(c) => @unscanny.is_whitespace(c)
            None => false
          }
        None => false
      }
      if !prefix_starts_ws {
        ctx.ensure_space()
      }
      if self.csl.info.category
        .iter()
        .any(c => c is CitationFormat(Label | Numeric)) {
        // Print the label.
        if self.csl.citation.layout.prefix is Some(prefix) {
          ctx.push_str(prefix)
        }
        do_regular(ctx)
        if self.csl.citation.layout.suffix is Some(suffix) {
          ctx.push_str(suffix)
        }
      } else {
        // Print the citation surrounded by parentheses and suppress the
        // author.
        ctx.push_str(self.csl.citation.layout.prefix.unwrap_or("("))
        ctx.set_special_form(Some(SuppressAuthor))
        do_regular(ctx)
        ctx.set_special_form(None)
        ctx.push_str(self.csl.citation.layout.suffix.unwrap_or(")"))
      }
    }
    (Some(Year), _) | (Some(Full), _) | (None, _) => do_regular(ctx)
  }
  ctx
}

///|
/// Render the given item within a bibliography.
fn StyleContext::do_bibliography(
  self : StyleContext,
  entry : Entry,
  props : CiteProperties,
  locale : @citationberg.LocaleCode?,
  term_locale : @citationberg.LocaleCode?,
) -> Context? {
  let ctx = self.ctx(entry, props, locale, term_locale, true)
  guard self.csl.bibliography is Some(bibliography) else { return None }
  ctx.writing.push_name_options(bibliography.name_options)
  let layout = bibliography.layout
  let affixes = layout.to_affixes()
  let affix_loc = ctx.apply_prefix(affixes)
  render_layout(layout, ctx)
  ctx.apply_suffix(affixes, affix_loc)
  Some(ctx)
}

///|
/// Return the locale to use for this style.
fn StyleContext::locale(self : StyleContext) -> @citationberg.LocaleCode {
  match self.locale_override {
    Some(l) => l
    None => self.csl.default_locale.unwrap_or(@citationberg.LocaleCode::en_us())
  }
}

///|
/// A citation request. A citation can contain references to multiple items.
pub struct CitationRequest {
  /// The items to format.
  items : Array[CitationItem]
  /// Which style to use for the citation.
  priv style : @citationberg.IndependentStyle
  /// The requested locale for the style's terms.
  locale : @citationberg.LocaleCode?
  /// The files used to retrieve locale settings and terms if the style does
  /// not define all necessary items.
  locale_files : Array[@citationberg.Locale]
  /// The number to use for `first-reference-note-number`.
  priv note_number : Int?
}

///|
/// Create a new citation request.
pub fn CitationRequest::new(
  items : Array[CitationItem],
  style : @citationberg.IndependentStyle,
  locale : @citationberg.LocaleCode?,
  locale_files : Array[@citationberg.Locale],
  note_number : Int?,
) -> CitationRequest {
  {
    items,
    style,
    locale,
    locale_files,
    note_number: if style.settings.class == Note {
      note_number
    } else {
      None
    },
  }
}

///|
/// Create a new citation request without a note number.
pub fn CitationRequest::from_items(
  items : Array[CitationItem],
  style : @citationberg.IndependentStyle,
  locale_files : Array[@citationberg.Locale],
) -> CitationRequest {
  CitationRequest::new(items, style, None, locale_files, None)
}

///|
fn CitationRequest::style_context(self : CitationRequest) -> StyleContext {
  StyleContext::new(self.style, self.locale, self.locale_files)
}

///|
fn CitationRequest::shall_affix(self : CitationRequest) -> Bool {
  self.items.iter().all(p => p.purpose is None)
}

///|
fn CitationRequest::prefix(self : CitationRequest) -> String? {
  if self.shall_affix() {
    self.style.citation.layout.prefix
  } else {
    None
  }
}

///|
fn CitationRequest::suffix(self : CitationRequest) -> String? {
  if self.shall_affix() {
    self.style.citation.layout.suffix
  } else {
    None
  }
}

///|
/// A request to render a bibliography. Use with
/// [`BibliographyDriver::finish`].
pub(all) struct BibliographyRequest {
  /// Which style to use for the bibliography. Some styles do not have a
  /// bibliography, in which case the field of the [`Rendered`] will be
  /// `None`.
  style : @citationberg.IndependentStyle
  /// The requested locale for the style's terms.
  locale : @citationberg.LocaleCode?
  /// The files used to retrieve locale settings and terms if the style does
  /// not define all necessary items.
  locale_files : Array[@citationberg.Locale]
}

///|
fn BibliographyRequest::style_context(
  self : BibliographyRequest,
) -> StyleContext {
  StyleContext::new(self.style, self.locale, self.locale_files)
}

///|
/// A reference to an [`Entry`] within a [`CitationRequest`].
pub struct CitationItem {
  /// The entry to format.
  entry : Entry
  /// The locator that specifies where in the entry the item is found.
  locator : SpecificLocator?
  /// A locale code that overrides the assumed locale of the entry.
  locale : @citationberg.LocaleCode?
  /// Whether this item will be included in the output.
  hidden : Bool
  /// Format the item in a special way.
  purpose : CitePurpose?
  /// The initial index of this item in the list of items.
  priv mut initial_idx : Int
}

///|
/// Create a new citation item for the given entry.
pub fn CitationItem::with_entry(entry : Entry) -> CitationItem {
  {
    entry,
    locator: None,
    locale: None,
    hidden: false,
    purpose: None,
    initial_idx: 0,
  }
}

///|
/// Create a new citation item with a locator for the given entry.
pub fn CitationItem::with_locator(
  entry : Entry,
  locator : SpecificLocator?,
) -> CitationItem {
  {
    entry,
    locator,
    locale: None,
    hidden: false,
    purpose: None,
    initial_idx: 0,
  }
}

///|
/// Create a new citation with all fields set.
pub fn CitationItem::new(
  entry : Entry,
  locator : SpecificLocator?,
  locale : @citationberg.LocaleCode?,
  hidden : Bool,
  purpose : CitePurpose?,
) -> CitationItem {
  { entry, locator, locale, hidden, purpose, initial_idx: 0, }
}

///|
/// Retrieve a macro.
fn StyleContext::get_macro(
  self : StyleContext,
  name : String,
) -> @citationberg.CslMacro? {
  for m in self.csl.macros {
    if m.name == name {
      return Some(m)
    }
  }
  None
}

///|
/// Get the locale for the given language in the style.
fn[R] StyleContext::lookup_locale(
  self : StyleContext,
  f : (@citationberg.Locale) -> R?,
) -> R? {
  let lookup = (
    file : Array[@citationberg.Locale],
    lang : @citationberg.LocaleCode?,
  ) => {
    for l in file {
      if l.lang == lang {
        return f(l)
      }
    }
    None
  }
  let locale = self.locale()
  let en_us = @citationberg.LocaleCode::en_us()
  let resources = [self.csl.locale, self.locale_files]
  for i, resource in resources {
    let fallback = if i == 0 {
      match locale.parse_base() {
        Some(Iso639_1(lang)) => Some(@citationberg.LocaleCode(lang))
        Some(Iana(lang)) => Some(@citationberg.LocaleCode(lang))
        _ => None
      }
    } else {
      locale.fallback()
    }
    if lookup(resource, Some(locale)) is Some(output) {
      return Some(output)
    }
    if fallback is Some(_) && lookup(resource, fallback) is Some(output) {
      return Some(output)
    }
    if i == 0 {
      if lookup(resource, None) is Some(output) {
        return Some(output)
      }
    } else if lookup(resource, Some(en_us)) is Some(output) {
      return Some(output)
    }
  }
  None
}

///|
/// Check whether to do punctuation in quotes.
fn StyleContext::punctuation_in_quotes(self : StyleContext) -> Bool {
  self
  .lookup_locale(f => {
    match f.style_options {
      Some(o) => o.punctuation_in_quote
      None => None
    }
  })
  .unwrap_or(false)
}

///|
/// This struct contains all information needed to render a single entry.
/// It contains buffers and is mutable.
priv struct WritingContext {
  /// Whether to watch out for punctuation that should be pulled inside the
  /// preceding quoted content.
  mut pull_punctuation : Bool
  /// Whether we should be using inner quotes.
  mut inner_quotes : Bool
  /// Whether to strip periods.
  mut strip_periods : Bool
  /// Whether to add queried variables to the suppression list.
  mut suppress_queried_variables : Bool
  /// Suppressed variables that must not be rendered.
  suppressed_variables : Array[@citationberg.Variable]
  /// Whether this render has checked for `disambiguate` in `cs:choose`.
  mut checked_disambiguate : Bool
  /// Check whether this is the first date.
  mut first_date : Bool
  /// The disambiguation-relevant properties of the first `cs:name` element.
  /// This is `None` if no `cs:name` elements were rendered.
  mut first_name : NameDisambiguationProperties?
  /// A stack of formatting.
  format_stack : NonEmptyStack[Formatting]
  /// Text cases.
  cases : NonEmptyStack[@citationberg.TextCase?]
  /// Inheritable name options.
  name_options : NonEmptyStack[@citationberg.InheritableNameOptions]
  /// Delimiters from ancestor delimiting elements (e.g., `cs:group`).
  delimiters : NonEmptyStack[String?]
  /// The buffer we're writing to.
  mut buf : CaseFolder
  /// A list of in-progress subtrees.
  elem_stack : NonEmptyStack[ElemChildren]
}

///|
fn WritingContext::new(
  options : @citationberg.InheritableNameOptions,
) -> WritingContext {
  {
    pull_punctuation: false,
    inner_quotes: false,
    strip_periods: false,
    suppress_queried_variables: false,
    suppressed_variables: [],
    checked_disambiguate: false,
    first_date: true,
    first_name: None,
    format_stack: NonEmptyStack::new(Formatting::default()),
    cases: NonEmptyStack::new(None),
    name_options: NonEmptyStack::new(options),
    delimiters: NonEmptyStack::new(None),
    buf: CaseFolder::new(),
    elem_stack: NonEmptyStack::new(ElemChildren::new()),
  }
}

///|
/// Retrieve the current formatting.
fn WritingContext::formatting(self : WritingContext) -> Formatting {
  self.format_stack.last
}

///|
/// Push a format on top of the stack if it is not empty.
fn WritingContext::push_format(
  self : WritingContext,
  format : @citationberg.Formatting,
) -> Int {
  if format.is_empty() {
    return self.format_stack.len()
  }
  self.save_to_block()
  let pos = self.format_stack.len()
  self.format_stack.push(self.formatting().apply(format))
  pos
}

///|
/// Pop a format from the stack if it is not empty.
fn WritingContext::pop_format(self : WritingContext, pos : Int) -> Unit {
  if pos == self.format_stack.len() {
    return
  }
  self.save_to_block()
  self.format_stack.drain(pos)
}

///|
/// Take the buffer, leaving a default one in its place.
fn WritingContext::take_buf(self : WritingContext) -> String {
  let b = self.buf
  self.buf = CaseFolder::new()
  b.finish()
}

///|
/// Saves the current buffer to the last element in the finished list.
fn WritingContext::save_to_block(self : WritingContext) -> Unit {
  if self.buf.is_empty() {
    return
  }
  let format = self.formatting()

  // Append to last child if formats match.
  if self.elem_stack.last.0.last() is Some(Text(child)) &&
    format == child.formatting {
    child.text = child.text + self.take_buf()
    return
  }
  let formatted = format.add_text(self.take_buf())
  self.elem_stack.last.0.push(Text(formatted))
}

///|
/// A location in the element stack (upstream `DisplayLoc`).
priv struct DisplayLoc {
  pos : Int
  format_idx : Int
}

///|
/// Add another subtree to the children element.
fn WritingContext::push_elem(
  self : WritingContext,
  format : @citationberg.Formatting,
) -> DisplayLoc {
  self.save_to_block()
  let pos = self.elem_stack.len()
  self.elem_stack.push(ElemChildren::new())
  { pos, format_idx: self.push_format(format), }
}

///|
/// Remove the last subtree and discard it.
fn WritingContext::discard_elem(
  self : WritingContext,
  loc : DisplayLoc,
) -> Unit {
  if self.elem_stack.len() != loc.pos + 1 {
    abort("stack location does not match")
  }
  self.pop_format(loc.format_idx)
  self.save_to_block()
  self.elem_stack.drain(loc.pos)
}

///|
fn WritingContext::has_content_since(
  self : WritingContext,
  loc : (DisplayLoc, Int),
) -> Bool {
  self.save_to_block()
  let children = self.elem_stack.last
  let has_content = match children.0.get(0) {
    Some(Text(t)) if loc.1 < t.text.length() =>
      t.text[loc.1:].iter().any(c => !@unscanny.is_whitespace(c))
    Some(Text(_)) => false
    Some(Elem(e)) => e.has_content()
    Some(Markup(_) | Link(..) | Transparent(..)) => true
    None => false
  }
  has_content || children.0.iter().drop(1).any(c => c.has_content())
}

///|
/// Apply a prefix, but return a tuple that allows us to undo it if it
/// wasn't followed by anything.
fn WritingContext::apply_prefix(
  self : WritingContext,
  affixes : @citationberg.Affixes,
) -> (DisplayLoc, Int) {
  let pos = self.push_elem(@citationberg.Formatting::default())
  if affixes.prefix is Some(prefix) {
    self.buf.push_str(prefix)
  }
  (pos, affixes.prefix.map(p => p.length()).unwrap_or(0))
}

///|
/// Nest the last subtree into its ancestor.
fn WritingContext::commit_elem(
  self : WritingContext,
  loc : DisplayLoc,
  display : @citationberg.Display?,
  meta : ElemMeta?,
) -> Unit {
  if self.elem_stack.len() != loc.pos + 1 {
    abort("stack location does not match")
  }
  self.pop_format(loc.format_idx)
  self.save_to_block()
  let children = self.elem_stack.pop().unwrap()
  if display is Some(_) || meta is Some(_) {
    self.elem_stack.last.0.push(Elem({ children, display, meta, }))
  } else {
    self.elem_stack.last.0.append(children.0)
  }
}

///|
/// Push an item on the name options stack.
fn WritingContext::push_name_options(
  self : WritingContext,
  options : @citationberg.InheritableNameOptions,
) -> Unit {
  self.name_options.push(self.name_options.last.apply(options))
}

///|
/// Pop an item from the name options stack.
fn WritingContext::pop_name_options(self : WritingContext) -> Unit {
  self.name_options.pop() |> ignore
}

///|
/// Ensure that the buffer is either empty or the last character is a
/// space.
fn WritingContext::ensure_space(self : WritingContext) -> Unit {
  if !self.buf.is_empty() {
    if !self.buf.ends_with(' ') && !self.buf.ends_with('\u{a0}') {
      self.buf.push(' ')
    }
  } else if self.elem_stack.last.last_text() is Some(l) &&
    !l.text.has_suffix(" ") &&
    !l.text.has_suffix("\u{a0}") {
    l.text = l.text + " "
  }
}

///|
/// Folds all remaining elements into the first element and returns it.
fn WritingContext::flush(self : WritingContext) -> ElemChildren {
  self.save_to_block()
  if self.format_stack.len() != 1 {
    abort("formatting stack is not one but \{self.format_stack.len()}")
  }
  self.elem_stack.finish()
}

///|
/// Set whether to strip periods.
fn WritingContext::may_strip_periods(
  self : WritingContext,
  strip : Bool,
) -> Unit {
  self.strip_periods = strip
}

///|
/// Stop stripping periods.
fn WritingContext::stop_stripping_periods(self : WritingContext) -> Unit {
  self.strip_periods = false
}

///|
/// Start suppressing the queried variables.
fn WritingContext::start_suppressing_queried_variables(
  self : WritingContext,
) -> Unit {
  self.suppress_queried_variables = true
}

///|
/// Stop suppressing the queried variables.
fn WritingContext::stop_suppressing_queried_variables(
  self : WritingContext,
) -> Unit {
  self.suppress_queried_variables = false
}

///|
/// Set the case of the next text.
fn WritingContext::push_case(
  self : WritingContext,
  case_ : @citationberg.TextCase?,
) -> Int {
  let idx = self.cases.len()
  self.cases.push(case_)
  idx
}

///|
/// Clear the case of the next text.
fn WritingContext::pop_case(self : WritingContext, idx : Int) -> Unit {
  if idx == self.cases.len() {
    return
  }
  self.cases.drain(idx)
}

///|
/// Reconfigures the case folder's case to the current
fn WritingContext::reconfigure(self : WritingContext) -> Unit {
  self.buf.reconfigure(
    match self.cases.last {
      Some(c) => Case::from_text_case(c)
      None => NoTransform
    },
  )
}

///|
/// Set the delimiter of the children of a group or layout.
fn WritingContext::push_delimiter(
  self : WritingContext,
  delimiter : String?,
) -> Int {
  let idx = self.delimiters.len()
  self.delimiters.push(delimiter)
  idx
}

///|
/// Clear the delimiter after a group or layout.
fn WritingContext::pop_delimiter(self : WritingContext, idx : Int) -> Unit {
  if idx == self.delimiters.len() {
    return
  }
  self.delimiters.drain(idx)
}

///|
/// Push a new suppressed variable if we are suppressing queried variables.
fn WritingContext::maybe_suppress(
  self : WritingContext,
  variable : @citationberg.Variable,
) -> Unit {
  if self.suppress_queried_variables {
    self.suppressed_variables.push(variable)
  }
}

///|
fn WritingContext::prepare_variable_query(
  self : WritingContext,
  general : @citationberg.Variable,
) -> @citationberg.Variable? {
  if self.suppressed_variables.contains(general) {
    return None
  }
  self.maybe_suppress(general)
  Some(general)
}

///|
/// Return the sum of the lengths of strings in the finished elements. This
/// may not monotonically increase.
fn WritingContext::len(self : WritingContext) -> Int {
  let mut n = self.buf.len()
  for e in self.elem_stack.items() {
    for c in e.0 {
      n += c.str_len()
    }
  }
  n
}

///|
/// Write the [`NameDisambiguationProperties`] that the first `cs:name`
/// element used. Do not change if this is not the first `cs:name` element.
/// Returns whether this was the first `cs:name` element.
fn WritingContext::first_name_properties(
  self : WritingContext,
  f : () -> NameDisambiguationProperties,
) -> Bool {
  if self.first_name is None {
    self.first_name = Some(f())
    true
  } else {
    false
  }
}

///|
priv struct Context {
  instance : InstanceContext
  style : StyleContext
  writing : WritingContext
  bibliography : Bool
}

///|
priv struct CiteProperties {
  mut certain : CertainCiteProperties
  mut speculative : SpeculativeCiteProperties
}

///|
fn CiteProperties::copy(self : CiteProperties) -> CiteProperties {
  { certain: self.certain, speculative: self.speculative.copy(), }
}

///|
fn CiteProperties::for_sorting(
  locator : SpecificLocator?,
  citation_number : Int,
) -> CiteProperties {
  {
    certain: CertainCiteProperties::new(),
    speculative: SpeculativeCiteProperties::speculate(
      locator,
      citation_number,
      Different,
    ),
  }
}

///|
/// Item properties that can be determined before the first render of a
/// citation or bibliography entry.
priv struct CertainCiteProperties {
  /// The number of the footnote this citation appears in.
  note_number : Int?
  /// The number of the first footnote this citation appears in.
  first_note_number : Int?
  /// Whether the item is within `near-note-distance` to the previous
  /// citation of the same item.
  is_near_note : Bool
  /// Whether this citation is the first citation of the entry.
  is_first : Bool
  /// The index of the item in the original citation request.
  initial_idx : Int
}

///|
fn CertainCiteProperties::new() -> CertainCiteProperties {
  {
    note_number: None,
    first_note_number: None,
    is_near_note: false,
    is_first: false,
    initial_idx: 0,
  }
}

///|
/// Item properties that can only be determined after one or multiple
/// renders. These require validation.
priv struct SpeculativeCiteProperties {
  /// Locator with its type.
  mut locator : SpecificLocator?
  /// The position the item appears at in the bibliography.
  mut citation_number : Int
  /// Whether this citation is exactly the same as the previous citation.
  mut ibid : IbidState
  /// Whether this citation is a disambiguation.
  mut disambiguation : DisambiguateState
  /// Whether this citation includes an identifier.
  mut identifier_usage : IdentifierUsage
}

///|
fn SpeculativeCiteProperties::copy(
  self : SpeculativeCiteProperties,
) -> SpeculativeCiteProperties {
  {
    locator: self.locator,
    citation_number: self.citation_number,
    ibid: self.ibid,
    disambiguation: self.disambiguation,
    identifier_usage: self.identifier_usage,
  }
}

///|
/// We can guess about the [`IbidState`] under the assumption that neither
/// this item nor its predecessors will be subject to cite grouping.
fn SpeculativeCiteProperties::speculate(
  locator : SpecificLocator?,
  citation_number : Int,
  ibid : IbidState,
) -> SpeculativeCiteProperties {
  {
    locator,
    citation_number,
    ibid,
    disambiguation: None_,
    identifier_usage: NoneUsage,
  }
}

///|
/// Get the speculative cite properties for a bibliography entry.
fn SpeculativeCiteProperties::for_bibliography(
  self : SpeculativeCiteProperties,
) -> SpeculativeCiteProperties {
  {
    locator: None,
    citation_number: self.citation_number,
    ibid: self.ibid,
    disambiguation: self.disambiguation,
    identifier_usage: self.identifier_usage,
  }
}

///|
/// Which type of citation label was used when this entry was cited.
priv enum IdentifierUsage {
  /// No label was used.
  NoneUsage
  /// Only the alphanumeric citation label was used.
  OnlyCitationLabel
  /// Only the citation number was used.
  OnlyCitationNumber
  /// Both the alphanumeric citation label and the citation number were
  /// used.
  Mixed
} derive(Eq)

///|
/// Return the identifier usage given that a label was used.
fn IdentifierUsage::label(self : IdentifierUsage) -> IdentifierUsage {
  match self {
    NoneUsage | OnlyCitationLabel => OnlyCitationLabel
    OnlyCitationNumber | Mixed => Mixed
  }
}

///|
/// Return the identifier usage given that a number was used.
fn IdentifierUsage::number(self : IdentifierUsage) -> IdentifierUsage {
  match self {
    NoneUsage | OnlyCitationNumber => OnlyCitationNumber
    OnlyCitationLabel | Mixed => Mixed
  }
}

///|
priv enum DisambiguateState {
  None_
  NameDisambiguation(NameDisambiguationProperties)
  Choose
  YearSuffix(Int)
} derive(Eq)

///|
/// Name disambiguation can be iterated upon, so we can stay here.
fn DisambiguateState::may_disambiguate_names(self : DisambiguateState) -> Bool {
  self is (None_ | NameDisambiguation(_))
}

///|
/// We can only disambiguate with choose once.
fn DisambiguateState::may_disambiguate_with_choose(
  self : DisambiguateState,
) -> Bool {
  self is (None_ | NameDisambiguation(_))
}

///|
/// We can only disambiguate with year suffix once.
fn DisambiguateState::may_disambiguate_with_year_suffix(
  self : DisambiguateState,
) -> Bool {
  self is (None_ | NameDisambiguation(_) | Choose)
}

///|
/// Return the more advanced disambiguation state between the two.
fn DisambiguateState::max(
  self : DisambiguateState,
  other : DisambiguateState,
) -> DisambiguateState {
  match (self, other) {
    (None_, other) => other
    (self_, None_) => self_
    (NameDisambiguation(a), NameDisambiguation(b)) =>
      NameDisambiguation(a.max(b))
    (NameDisambiguation(_), other) => other
    (self_, NameDisambiguation(_)) => self_
    (Choose, other) => other
    (self_, Choose) => self_
    (YearSuffix(a), YearSuffix(b)) => YearSuffix(if a > b { a } else { b })
  }
}

///|
priv enum IbidState {
  /// The previous cite referenced another entry, or this cite has no
  /// locator when the previous one did.
  Different
  /// The previous cite referenced the same entry, but with a different
  /// locator.
  IbidWithLocator
  /// The previous cite referenced the same entry with the same locator.
  Ibid
} derive(Eq)

///|
fn IbidState::with_last(this : CitationItem, last : CitationItem?) -> IbidState {
  match last {
    Some(last) =>
      if last.entry == this.entry && !last.hidden {
        if last.locator == this.locator {
          Ibid
        } else if this.locator is None {
          // Per CSL spec: "Preceding cite does have a locator: (...) If the
          // current cite lacks a locator its only position is
          // 'subsequent'."
          Different
        } else {
          // - Both have locators, but they differ
          // - Previous one has no locator, this one does
          IbidWithLocator
        }
      } else {
        Different
      }
    None => Different
  }
}

///|
/// This struct allows to add context to where the information in a cite is
/// found in the source.
pub(all) struct SpecificLocator(@citationberg.Locator, LocatorPayload) derive(Eq)

///|
/// The type of content a `cs:text` element should yield for a locator.
pub(all) enum LocatorPayload {
  /// Just print the string.
  Str(String)
  /// An element with the original index of the locator will be yielded.
  /// The consumer can then recognize this and replace it with their own
  /// content.
  Transparent(TransparentLocator)
} derive(Eq)

///|
/// Wraps an object that is used to determine whether two locators are the
/// same. (Upstream compares arbitrary payloads with `dyn Any`; here, the
/// consumer provides a comparison key.)
pub(all) struct TransparentLocator(String) derive(Eq)

///|
/// Creates a new [`TransparentLocator`] with the given comparison key.
pub fn TransparentLocator::new(key : String) -> TransparentLocator {
  TransparentLocator(key)
}

///|
/// Set the [`SpecialForm`]
fn Context::set_special_form(self : Context, form : SpecialForm?) -> Unit {
  self.instance.kind = form
}

///|
/// Describes the bracket preference of a citation style.
pub(all) enum Brackets {
  /// "(...)" Parentheses.
  Round
  /// "[...]" Brackets.
  Square
  /// No brackets.
  None_
} derive(Eq, Debug)

///|
/// For what purpose to generate a citation.
pub(all) enum CitePurpose {
  /// The citation will only contain the name of the author.
  Author
  /// The citation will only contain the year. Year Affixes will not be
  /// included.
  Year
  /// The citation will equate to the bibliography entry of the item.
  Full
  /// The citation will be well-suited for inclusion in prose.
  Prose
} derive(Eq, Hash, Debug)

///|
/// A special citation form to use for the [`CitationItem`].
priv enum SpecialForm {
  /// Only output the author.
  VarOnly(@citationberg.Variable)
  /// Only print the first date.
  OnlyFirstDate
  /// Only print the year suffix.
  OnlyYearSuffix
  /// Output everything but the author.
  SuppressAuthor
} derive(Eq)
