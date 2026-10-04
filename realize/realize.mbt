// Port of `typst-realize/src/lib.rs`: Typst's realization subsystem.
//
// *Realization* is the process of recursively applying styling and, in
// particular, show rules to produce well-known elements that can be processed
// further.
//
// Deviations from upstream:
// - There are no arenas: content and styles are shared, immutable values.
//   Where upstream lifetime-extends a `StyleChain` in an arena (which gives it
//   a new address and thus a distinct identity for `StyleChain`'s pointer
//   equality), we use `StyleChain::fresh`.
// - Content is immutable, so preparation returns the prepared element.

///|
/// Realize content into a flat list of well-known, styled items.
///
/// Has the signature of `Routines::realize`.
pub fn realize(
  kind : @library.RealizationKind,
  engine : Engine,
  locator : @library.SplitLocator,
  content : Content,
  styles : StyleChain,
) -> Array[Pair] raise SourceError {
  let s : State = {
    kind,
    engine,
    locator,
    rules: match kind {
      Bundle => bundle_rules
      Document(..) => flow_rules
      Fragment(..) => flow_rules
      Par => par_rules
      Math => math_rules
    },
    sink: [],
    groupings: [],
    outside: kind is Document(..),
    may_attach: false,
    saw_parbreak: false,
  }
  visit(s, content, styles)
  finish(s)
  s.sink
}

///|
/// Mutable state for realization.
priv struct State {
  /// Defines what kind of realization we are performing.
  kind : @library.RealizationKind
  /// The engine.
  engine : Engine
  /// Assigns unique locations to elements.
  locator : @library.SplitLocator
  /// The output elements of well-known types.
  sink : Array[Pair]
  /// Grouping rules used for realization.
  rules : ReadOnlyArray[GroupingRule]
  /// Currently active groupings.
  groupings : Array[Grouping]
  /// Whether we are currently not within any container or show rule output.
  /// This is used to determine page styles during layout.
  mut outside : Bool
  /// Whether now following attach spacing can survive.
  mut may_attach : Bool
  /// Whether we visited any paragraph breaks.
  mut saw_parbreak : Bool
}

///|
/// Defines a rule for how certain elements shall be grouped during
/// realization.
priv struct GroupingRule {
  /// Identifies the rule (upstream compares rules by address).
  kind : RuleKind
  /// When an element is visited that matches a rule with higher priority
  /// than one that is currently grouped, we start a nested group.
  priority : Int
  /// Whether the grouping handles tags itself. If this is set to `false`,
  /// realization will transparently take care of tags and they will not
  /// be visible to `finish`.
  tags : Bool
  /// Defines how the element relates to this kind of grouping.
  effect : (Content) -> GroupingEffect
  /// Defines whether styles for this kind of element interrupt the grouping.
  interrupt : (Element) -> Bool
}

///|
/// The grouping rules.
priv enum RuleKind {
  Textual
  Par
  Cites
  List
  Enum
  Terms
}

///|
/// Should convert the accumulated elements in `s.sink[start..]` into the
/// grouped element (upstream `GroupingRule::finish`).
fn GroupingRule::finish(
  self : GroupingRule,
  grouped : Grouped,
) -> Unit raise SourceError {
  match self.kind {
    Textual => finish_textual(grouped)
    Par => finish_par(grouped)
    Cites => finish_cites(grouped)
    List => finish_list(grouped)
    Enum => finish_enum(grouped)
    Terms => finish_terms(grouped)
  }
}

///|
/// Defines the effect of an element on a grouping.
priv enum GroupingEffect {
  /// The element will trigger this kind of grouping.
  Trigger
  /// Defines elements that may appear in the interior of the grouping, but
  /// not at the edges. In particular, those elements also don't trigger the
  /// grouping.
  Inner
  /// Defines elements that may appear intertwined with group elements without
  /// triggering finishing of the grouping. Once finishing is otherwise
  /// triggered, the neutral elements are segmented away and runs of other
  /// grouping elements are finished separately.
  ///
  /// The purpose of neutral elements is to allow for mixed flows of inline
  /// and blocky HTML elements (which is common in HTML).
  Neutral
  /// The element will stop this kind of grouping.
  Interrupt
} derive(Eq)

///|
/// A started grouping of some elements.
priv struct Grouping {
  /// The position in `s.sink` where the group starts.
  start : Int
  /// Only applies to `PAR` grouping: Whether this paragraph group is
  /// interrupted, but not yet finished because it may be ignored due to being
  /// fully inline.
  mut interrupted : Bool
  /// Whether the group contains neutral elements.
  mut contains_neutral : Bool
  /// The rule used for this grouping.
  rule : GroupingRule
}

///|
/// The result of grouping.
priv struct Grouped {
  /// The realization state.
  s : State
  /// The position in `s.sink` where the group starts.
  start : Int
}

///|
/// What to do with an element when encountering it during realization.
priv struct Verdict {
  /// Whether the element is already prepared (i.e. things that should only
  /// happen once have happened).
  prepared : Bool
  /// A map of styles to apply to the element.
  map : Styles
  /// An optional show rule transformation to apply to the element.
  step : ShowStep?
}

///|
/// A show rule transformation to apply to the element.
priv enum ShowStep {
  /// A user-defined transformational show rule.
  Recipe(Recipe, Int)
  /// The built-in show rule.
  Builtin(@library.NativeShowRule)
}

///|
/// A match of a regex show rule.
priv struct RegexMatch {
  /// The offset in the string that matched (in UTF-8 bytes).
  offset : Int
  /// The text that matched.
  text : String
  /// The style chain of the matching grouping.
  styles : StyleChain
  /// The index of the recipe that matched.
  id : Int
  /// The recipe that matched.
  recipe : Recipe
}

///|
/// Accesses the grouped elements.
fn Grouped::get(self : Grouped) -> ArrayView[Pair] {
  self.s.sink[self.start:]
}

///|
/// Removes the grouped elements from the sink and retrieves back the state
/// with which resulting elements can be visited.
fn Grouped::end(self : Grouped) -> State {
  self.s.sink.truncate(self.start)
  self.s
}

///|
/// Handles an arbitrary piece of content during realization.
fn visit(
  s : State,
  content : Content,
  styles : StyleChain,
) -> Unit raise SourceError {
  // Tags can always simply be pushed.
  if content.is_(@library.tag_elem()) {
    s.sink.push((content, styles))
    return
  }

  // Transformations for content based on the realization kind. Needs
  // to happen before show rules.
  if visit_kind_rules(s, content, styles) {
    return
  }

  // Apply show rules and preparation.
  if visit_show_rules(s, content, styles) {
    return
  }

  // Recurse into sequences. Styled elements and sequences can currently also
  // have labels, so this needs to happen before they are handled.
  if content.to_sequence() is Some(children) {
    for elem in children {
      visit(s, elem, styles)
    }
    return
  }

  // Recurse into styled elements.
  if content.is_(@library.styled_elem()) {
    visit_styled(
      s,
      @library.StyledElem::child(content),
      @library.StyledElem::styles(content),
      styles,
    )
    return
  }

  // Apply grouping --- where multiple elements are collected and then
  // processed together (typically being transformed into one).
  if visit_grouping_rules(s, content, styles) {
    return
  }

  // Some elements are skipped based on specific circumstances.
  if visit_filter_rules(s, content, styles) {
    return
  }

  // No further transformations to apply, so we can finally just push it to
  // the output!
  s.sink.push((content, styles))
}

///|
/// Handles transformations based on the realization kind.
fn visit_kind_rules(
  s : State,
  content : Content,
  styles : StyleChain,
) -> Bool raise SourceError {
  if s.kind is Math {
    // Transparently recurse into equations nested in math, so that things
    // like this work:
    // ```
    // #let my = $pi$
    // $ my r^2 $
    // ```
    if @library.EquationElem::of(content) is Some(elem) {
      visit(s, elem.body(), styles)
      return true
    }

    // In normal realization, we apply regex show rules to consecutive
    // textual elements via `TEXTUAL` grouping. However, in math, this is
    // not desirable, so we just do it on a per-element basis.
    if @library.SymbolElem::of(content) is Some(elem) {
      if find_regex_match_in_str(elem.text(), styles) is Some(m) {
        visit_regex_match(s, [(content, styles)], m)
        return true
      }
    } else if @library.TextElem::of(content) is Some(elem) &&
      find_regex_match_in_str(elem.text(), styles) is Some(m) {
      visit_regex_match(s, [(content, styles)], m)
      return true
    }
  } else {
    // Transparently wrap mathy content into equations.
    if content.can("Mathy") && !content.is_(@library.equation_elem()) {
      let eq = @library.EquationElem::new(content)
        .pack()
        .spanned(content.span())
      visit(s, eq, styles)
      return true
    }

    // Symbols in non-math content transparently convert to `TextElem` so we
    // don't have to handle them in non-math layout.
    if @library.SymbolElem::of(content) is Some(elem) {
      let mut text = @library.TextElem::packed(elem.text()).spanned(
        content.span(),
      )
      if content.label() is Some(label) {
        text = text.labelled(label)
      }
      visit(s, text, styles)
      return true
    }
  }
  false
}

///|
/// Tries to apply show rules to or prepare content. Returns `true` if the
/// element was handled.
fn visit_show_rules(
  s : State,
  content : Content,
  styles : StyleChain,
) -> Bool raise SourceError {
  // Determines whether and how to proceed with show rule application.
  guard verdict(s.engine, content, styles) is Some({ prepared, map, step, }) else {
    return false
  }

  // Create a fresh copy that we can mutate.
  let mut output = content

  // If the element isn't yet prepared (we're seeing it for the first time),
  // prepare it.
  let mut tags = None
  if !prepared {
    let (prepared_elem, prepared_tags) = prepare(
      s.engine,
      s.locator,
      output,
      map,
      styles,
    )
    output = prepared_elem
    tags = prepared_tags
  }

  // Apply a show rule step, if there is one.
  if step is Some(step) {
    let chained = styles.chain(map)
    let elem = output
    let result = () => {
      match step {
        // Apply a user-defined show rule.
        Recipe(recipe, guard_) => {
          let context = @library.Context::new(
            location?=elem.location(),
            styles=chained,
          )
          recipe.apply(s.engine, context, elem.guarded(guard_))
        }
        // Apply a built-in show rule.
        Builtin(rule) =>
          rule.apply(elem, s.engine, chained).spanned(elem.span())
      }
    }

    // Errors in show rules don't terminate compilation immediately. We just
    // continue with empty content for them and show all errors together, if
    // they remain by the end of the introspection loop.
    //
    // This way, we can ignore errors that only occur in earlier iterations
    // and also show more useful errors at once.
    output = s.engine.delay(result, Content::empty())
  }
  let realized = output

  // Push start tag.
  if tags is Some((start, _)) {
    visit(s, @library.TagElem::packed(start), styles)
  }
  let prev_outside = s.outside
  s.outside = s.outside && content.is_(@library.context_elem())
  s.engine.route.increase()
  @library.at(content.span(), () => s.engine.route.check_show_depth())
  visit_styled(s, realized, map, styles)
  s.outside = prev_outside
  s.engine.route.decrease()

  // Push end tag.
  if tags is Some((_, end)) {
    visit(s, @library.TagElem::packed(end), styles)
  }
  true
}

///|
/// Inspects an element and the current styles and determines how to proceed
/// with the styling.
fn verdict(engine : Engine, elem : Content, styles : StyleChain) -> Verdict? {
  let prepared = elem.is_prepared()
  let map = Styles::new()
  let mut step : ShowStep? = None

  // Do pre-synthesis on a cloned element to be able to match on synthesized
  // fields before real synthesis runs (during preparation). It's really
  // unfortunate that we have to do this, but otherwise
  // `show figure.where(kind: table)` won't work :(
  let mut elem = elem
  if !prepared && elem.can("Synthesize") {
    if elem.elem().hooks().synthesize is Some(synthesize) {
      elem = synthesize(engine, elem, styles) catch { _ => elem }
    }
  }

  // Lazily computes the total number of recipes in the style chain. We need
  // it to determine whether a particular show rule was already applied to the
  // `elem` previously. For this purpose, show rules are indexed from the
  // top of the chain as the chain might grow to the bottom.
  let mut depth : Int? = None
  let mut r = 0
  for recipe in styles.recipes() {
    let i = r
    r += 1

    // We're not interested in recipes that don't match.
    guard recipe.selector is Some(selector) &&
      selector.matches(elem, Some(styles)) else {
      continue
    }

    // Special handling for show-set rules.
    if recipe.transform is Style(transform) {
      if !prepared {
        map.apply(transform.copy())
      }
      continue
    }

    // If we already have a show step, don't look for one.
    if step is Some(_) {
      continue
    }

    // Check whether this show rule was already applied to the element.
    let total = match depth {
      Some(d) => d
      None => {
        let d = styles.recipes().count()
        depth = Some(d)
        d
      }
    }
    let index = total - i
    if elem.is_guarded(index) {
      continue
    }

    // We'll apply this recipe.
    step = Some(Recipe(recipe, index))

    // If we found a show rule and are already prepared, there is nothing
    // else to do, so we can just break. If we are not yet prepared,
    // continue searching for potential show-set styles.
    if prepared {
      break
    }
  }

  // If we found no user-defined rule, also consider the built-in show rule.
  if step is None {
    let target = @library.TargetElem::target_in(styles)
    if engine.library.rules.get(target, elem) is Some(rule) {
      step = Some(Builtin(rule))
    }
  }

  // If there's no nothing to do, there is also no verdict.
  if step is None &&
    map.is_empty() &&
    (
      prepared ||
      (
        elem.label() is None &&
        elem.location() is None &&
        !elem.can("ShowSet") &&
        !elem.elem().is_locatable() &&
        !elem.elem().is_tagged() &&
        !elem.can("Synthesize")
      )
    ) {
    return None
  }
  Some({ prepared, map, step, })
}

///|
/// This is only executed the first time an element is visited. Returns the
/// prepared element and its start and end tags.
fn prepare(
  engine : Engine,
  locator : @library.SplitLocator,
  elem : Content,
  map : Styles,
  styles : StyleChain,
) -> (Content, (@library.Tag, @library.Tag)?) raise SourceError {
  let mut elem = elem

  // Generate a location for the element, which uniquely identifies it in
  // the document. This has some overhead, so we only do it for elements
  // that are explicitly marked as locatable and labelled elements.
  //
  // The element could already have a location even if it is not prepared
  // when it stems from a query.
  let key = @library.hash128(elem)
  let flags : @library.TagFlags = {
    introspectable: elem.elem().is_locatable() ||
    elem.label() is Some(_) ||
    elem.location() is Some(_),
    tagged: elem.elem().is_tagged(),
  }
  if elem.location() is None && flags.any() {
    let loc = locator.next_location(engine, key, elem.span())
    elem = elem.located(loc)
  }

  // Apply built-in show-set rules. User-defined show-set rules are already
  // considered in the map built while determining the verdict.
  if elem.can("ShowSet") && elem.elem().hooks().show_set is Some(show_set) {
    map.apply(show_set(elem, styles))
  }

  // If necessary, generated "synthesized" fields (which are derived from
  // other fields or queries). Do this after show-set so that show-set styles
  // are respected.
  if elem.can("Synthesize") &&
    elem.elem().hooks().synthesize is Some(synthesize) {
    elem = synthesize(engine, elem, styles.chain(map))
  }

  // Copy style chain fields into the element itself, so that they are
  // available in rules.
  elem = elem.materialize(styles.chain(map))

  // If the element is locatable, create start and end tags to be able to find
  // the element in the frames after layout. Do this after synthesis and
  // materialization, so that it includes the synthesized fields. Do it before
  // marking as prepared so that show-set rules will apply to this element
  // when queried.
  let tags = elem
    .location()
    .map(loc => {
      (@library.Tag::Start(elem, flags), @library.Tag::End(loc, key, flags))
    })

  // Ensure that this preparation only runs once by marking the element as
  // prepared.
  (elem.mark_prepared(), tags)
}

///|
/// Handles a styled element.
fn visit_styled(
  s : State,
  content : Content,
  local_ : Styles,
  outer : StyleChain,
) -> Unit raise SourceError {
  // Nothing to do if the styles are actually empty.
  if local_.is_empty() {
    return visit(s, content, outer)
  }

  // Check for document and page styles.
  let mut pagebreak = false
  let mut populated_document_info = false
  let mut populated_format_options = false
  let full = outer.chain(local_)
  for style in local_.iter() {
    guard style.element() is Some(elem) else { continue }
    if elem == @library.document_elem() {
      if s.kind is Document(info~, ..) {
        if !populated_document_info {
          info.populate(full)
          populated_document_info = true
        }
      } else if !(s.kind is Bundle) {
        @library.bail_at(
          style.span(),
          "document set rules are not allowed inside of containers",
        )
      }
      if local_.has(@library.document_elem(), @library.document_elem_format) &&
        !(s.kind is Bundle) {
        @library.bail_at(
          style.span(),
          "setting the document format is only supported in the bundle target",
        )
      }
    } else if elem == @library.text_elem() {
      // Infer the document locale from the first toplevel set rule.
      if s.kind is Document(info~, ..) {
        info.populate_locale(full)
      }
    } else if elem == @library.page_elem() {
      match s.kind {
        Bundle => ()
        Document(..) =>
          match @library.TargetElem::target_in(outer) {
            Paged => {
              // When there are page styles, we "break free" from our show
              // rule cage.
              pagebreak = true
              s.outside = true
            }
            Html =>
              s.engine.sink.warn(
                @library.SourceDiagnostic::warning_at(
                  style.span(),
                  "page set rule was ignored during HTML export",
                ),
              )
            Bundle => ()
          }
        _ =>
          @library.bail_at(
            style.span(),
            "page configuration is not allowed inside of containers",
          )
      }
    } else if s.engine.library.formats.iter().any(f => f.elem == elem) {
      if s.kind is Document(options~, ..) {
        if !populated_format_options {
          options.populate(full, style.span())
          populated_format_options = true
        }
      } else if !(s.kind is Bundle) {
        @library.bail_at(
          style.span(),
          "format set rules are not allowed inside of containers",
        )
      }
    }
  }

  // If we are not within a container or show rule, mark the styles as
  // "outside". This will allow them to be lifted to the page level.
  let local_ = if s.outside { local_.outside() } else { local_ }

  // Lifetime-extend the styles if necessary.
  let outer_ = outer.fresh()

  // Generate a weak pagebreak if there is a page interruption. For the
  // starting pagebreak we only want the styles before and including the
  // interruptions, not trailing styles that happen to be in the same `Styles`
  // list, so we trim the local styles.
  if pagebreak {
    let items = local_.iter().collect()
    let mut end = items.length()
    while end > 0 && items[end - 1].element() != Some(@library.page_elem()) {
      end -= 1
    }
    let relevant = if end == items.length() {
      local_
    } else {
      Styles::from_array(items[:end].to_owned())
    }
    visit(s, @library.PagebreakElem::shared_weak(), outer_.chain(relevant))
  }
  finish_interrupted(s, local_)
  visit(s, content, outer_.chain(local_))
  finish_interrupted(s, local_)

  // Generate a weak "boundary" pagebreak at the end. In comparison to a
  // normal weak pagebreak, the styles of this are ignored during layout, so
  // it doesn't really matter what we use here.
  if pagebreak {
    visit(s, @library.PagebreakElem::shared_boundary(), outer)
  }
}

///|
/// Tries to group the content in an active group or start a new one if any
/// grouping rule matches. Returns `true` if the element was grouped.
fn visit_grouping_rules(
  s : State,
  content : Content,
  styles : StyleChain,
) -> Bool raise SourceError {
  let matching = s.rules
    .iter()
    .find_first(rule => (rule.effect)(content) is Trigger)

  // Try to continue or finish an existing grouping.
  let mut i = 0
  while s.groupings.last() is Some(active) {
    // Start a nested group if a rule with higher priority matches.
    if matching is Some(rule) && rule.priority > active.rule.priority {
      break
    }

    // If the element can be added to the active grouping, do it.
    let effect = (active.rule.effect)(content)
    if !active.interrupted && effect != Interrupt {
      active.contains_neutral = active.contains_neutral || effect == Neutral
      s.sink.push((content, styles))
      return true
    }
    finish_innermost_grouping(s)
    i += 1
    if i > 512 {
      // It seems like this case is only hit when there is a cycle between
      // a show rule and a grouping rule. The show rule produces content
      // that is matched by a grouping rule, which is then again processed
      // by the show rule, and so on. The two must be at an equilibrium,
      // otherwise either the "maximum show rule depth" or "maximum
      // grouping depth" errors are triggered.
      @library.bail_at(content.span(), "maximum grouping depth exceeded")
    }
  }

  // Start a new grouping.
  if matching is Some(rule) {
    let start = s.sink.length()
    s.groupings.push({
      start,
      rule,
      interrupted: false,
      contains_neutral: false,
    })
    s.sink.push((content, styles))
    return true
  }
  false
}

///|
/// Some elements don't make it to the sink depending on the realization kind
/// and current state.
fn visit_filter_rules(
  s : State,
  content : Content,
  styles : StyleChain,
) -> Bool {
  if s.kind is (Par | Math) {
    return false
  }
  if content.is_(@library.space_elem()) {
    // Outside of maths and paragraph realization, spaces that were not
    // collected by the paragraph grouper don't interest us.
    return true
  } else if content.is_(@library.parbreak_elem()) {
    // Paragraph breaks are only a boundary for paragraph grouping, we don't
    // need to store them.
    s.may_attach = false
    s.saw_parbreak = true
    return true
  } else if !s.may_attach &&
    @library.VElem::of(content) is Some(elem) &&
    elem.attach(styles) {
    // Attach spacing collapses if not immediately following a paragraph.
    return true
  }

  // Remember whether following attach spacing can survive.
  s.may_attach = content.is_(@library.par_elem())
  false
}

///|
/// Finishes all grouping.
fn finish(s : State) -> Unit raise SourceError {
  finish_grouping_while(s, s => {
    // If this is a fragment realization and all we've got is inline and
    // neutral content, don't turn it into a paragraph.
    if is_fully_inline_or_neutral(s) {
      if s.kind is Fragment(kind~) {
        kind.val = Inline
      }
      s.groupings.pop() |> ignore
      collapse_spaces(s.sink, 0)
      false
    } else {
      !s.groupings.is_empty()
    }
  })

  // In paragraph and math realization, spaces are top-level.
  if s.kind is (Par | Math) {
    collapse_spaces(s.sink, 0)
  }
}

///|
/// Finishes groupings while any active group is interrupted by the styles.
fn finish_interrupted(s : State, local_ : Styles) -> Unit raise SourceError {
  let mut last : Element? = None
  for style in local_.iter() {
    guard style.element() is Some(elem) else { continue }
    if last == Some(elem) {
      continue
    }
    finish_grouping_while(s, s => {
      s.groupings.iter().any(grouping => (grouping.rule.interrupt)(elem)) &&
      (if is_fully_inline_or_neutral(s) {
        s.groupings[0].interrupted = true
        false
      } else {
        true
      })
    })
    last = Some(elem)
  }
}

///|
/// Finishes groupings while `f` returns `true`.
fn finish_grouping_while(
  s : State,
  f : (State) -> Bool,
) -> Unit raise SourceError {
  // Finishing of a group may result in new content and new grouping. This
  // can, in theory, go on for a bit. To prevent it from becoming an infinite
  // loop, we keep track of the iteration count.
  let mut i = 0
  while f(s) {
    finish_innermost_grouping(s)
    i += 1
    if i > 512 {
      @library.bail_at(
        @syntax.Span::detached(),
        "maximum grouping depth exceeded",
      )
    }
  }
}

///|
/// Finishes the currently innermost grouping.
fn finish_innermost_grouping(s : State) -> Unit raise SourceError {
  // The grouping we are interrupting.
  let { start, rule, contains_neutral, .. } = s.groupings.pop().unwrap()
  if contains_neutral {
    // If the grouping collected neutral elements, we segment them out and
    // then finish the individual subgroups separately.
    let elems = s.sink[start:].to_owned()
    s.sink.truncate(start)
    let is_neutral = (pair : Pair) => (rule.effect)(pair.0) is Neutral
    for slice in group_by_key(elems, is_neutral) {
      if is_neutral(slice[0]) {
        for pair in slice {
          visit(s, pair.0, pair.1)
        }
      } else {
        // Trim and revisit leading non-trigger elements.
        // `finish_grouping` only takes care of trimming trailing
        // elements as usually a grouping cannot start without a trigger
        // element.
        let mut split = 0
        while split < slice.length() &&
              !((rule.effect)(slice[split].0) is Trigger) {
          split += 1
        }
        for pair in slice[:split] {
          visit(s, pair.0, pair.1)
        }

        // If we only had inner elements and tags, don't finish the
        // group at all.
        if split < slice.length() {
          let start = s.sink.length()
          s.sink.append(slice[split:])
          finish_grouping(s, rule, start)
        }
      }
    }
  } else {
    finish_grouping(s, rule, start)
  }
}

///|
/// Splits `items` into runs of consecutive elements with the same key
/// (upstream `SliceExt::group_by_key`).
fn[K : Eq] group_by_key(
  items : ArrayView[Pair],
  key : (Pair) -> K,
) -> Array[ArrayView[Pair]] {
  let out = []
  let mut i = 0
  while i < items.length() {
    let k = key(items[i])
    let mut j = i + 1
    while j < items.length() && key(items[j]) == k {
      j += 1
    }
    out.push(items[i:j])
    i = j
  }
  out
}

///|
/// Finishes a grouping with the given `rule` that starts at a given position in
/// the sink.
fn finish_grouping(
  s : State,
  rule : GroupingRule,
  start : Int,
) -> Unit raise SourceError {
  let mut start = start

  // Trim trailing non-trigger elements. At the start, they are already not
  // included precisely because they are not triggers.
  let mut end = s.sink.length()
  while end > start && !((rule.effect)(s.sink[end - 1].0) is Trigger) {
    end -= 1
  }

  // Tags that are opened within or at the start boundary of the grouping
  // should have their closing tag included if it is at the end boundary.
  // Similarly, tags that are closed within or at the end boundary should have
  // their opening tag included if it is at the start boundary. Finally, tags
  // that are sandwiched between an opening tag with a matching closing tag
  // should also be included.
  if rule.tags {
    // The trailing part of the sink can contain a mix of inner elements and
    // tags. If there is a closing tag with a matching start tag, but there
    // is an inner element in between, that's in principle a situation with
    // overlapping tags. However, if the inner element would immediately be
    // destructed anyways, there isn't really a problem. So we try to
    // anticipate that and destruct it eagerly.
    if rule.kind is Par {
      let kept = s.sink[end:]
        .iter()
        .filter(p => !p.0.is_(@library.space_elem()))
        .collect()
      s.sink.truncate(end)
      s.sink.append(kept)
    }

    // Find tags before, within, and after the grouping range.
    let before = @hashset.HashSet([])
    for k = start - 1; k >= 0; k = k - 1 {
      guard to_tag(s.sink[k]) is Some(tag) else { break }
      before.add(tag.location())
    }
    let within = @hashset.HashSet([])
    for k in start..<end {
      if to_tag(s.sink[k]) is Some(tag) {
        within.add(tag.location())
      }
    }
    let after = @hashset.HashSet([])
    for k in end..<s.sink.length() {
      guard to_tag(s.sink[k]) is Some(tag) else { break }
      after.add(tag.location())
    }

    // Include all tags at the start that are closed within or after.
    for k = start - 1; k >= 0; k = k - 1 {
      guard to_tag(s.sink[k]) is Some(tag) else { break }
      let key = tag.location()
      if within.contains(key) || after.contains(key) {
        start = k
      }
    }

    // Include all tags at the end that are opened within or before.
    for k in end..<s.sink.length() {
      guard to_tag(s.sink[k]) is Some(tag) else { break }
      let key = tag.location()
      if within.contains(key) || before.contains(key) {
        end = k + 1
      }
    }
  }
  let tail = s.sink[end:].to_owned()
  s.sink.truncate(end)

  // If the grouping is not interested in tags, remove and collect them.
  let tags = []
  if !rule.tags {
    let mut k = start
    for i in start..<end {
      if s.sink[i].0.is_(@library.tag_elem()) {
        tags.push(s.sink[i])
        continue
      }
      if k < i {
        s.sink[k] = s.sink[i]
      }
      k += 1
    }
    s.sink.truncate(k)
  }

  // Execute the grouping's finisher rule.
  rule.finish({ s, start, })

  // Visit the tags and staged elements again.
  for pair in tags {
    visit(s, pair.0, pair.1)
  }
  for pair in tail {
    visit(s, pair.0, pair.1)
  }
}

///|
/// Tries to convert a pair to a tag.
fn to_tag(pair : Pair) -> @library.Tag? {
  @library.TagElem::of(pair.0).map(elem => elem.tag())
}

///|
/// Grouping rules used in bundle realization.
let bundle_rules : ReadOnlyArray[GroupingRule] = []

///|
/// Grouping rules used in normal realization.
let flow_rules : ReadOnlyArray[GroupingRule] = [
  textual, par, cites, list, enum_, terms,
]

///|
/// Grouping rules used in paragraph realization.
let par_rules : ReadOnlyArray[GroupingRule] = [
  textual, cites, list, enum_, terms,
]

///|
/// Grouping rules used in math realization.
let math_rules : ReadOnlyArray[GroupingRule] = [cites, list, enum_, terms]

///|
/// Groups adjacent textual elements for text show rule application.
let textual : GroupingRule = {
  kind: Textual,
  priority: 3,
  tags: true,
  effect: content => {
    let elem = content.elem()
    // Note that `SymbolElem` converts into `TextElem` before textual show
    // rules run, and we apply textual rules to elements manually during
    // math realization, so we don't check for it here.
    if elem == @library.text_elem() ||
      elem == @library.linebreak_elem() ||
      elem == @library.smart_quote_elem() {
      Trigger
    } else if elem == @library.space_elem() {
      Inner
    } else {
      Interrupt
    }
  },
  // Any kind of style interrupts this kind of grouping since regex show
  // rules cannot match over style changes anyway.
  interrupt: _ => true,
}

///|
/// Collects inline-level elements into a `ParElem`.
let par : GroupingRule = {
  kind: Par,
  priority: 1,
  tags: true,
  effect: content => {
    let elem = content.elem()
    if elem == @library.text_elem() ||
      elem == @library.h_elem() ||
      elem == @library.linebreak_elem() ||
      elem == @library.smart_quote_elem() ||
      elem == @library.inline_elem() ||
      elem == @library.box_elem() {
      Trigger
    } else if elem == @library.space_elem() {
      Inner
    } else if @library.HtmlElem::of(content) is Some(elem) {
      if elem.tag().should_group_into_pars() {
        Trigger
      } else {
        Neutral
      }
    } else {
      Interrupt
    }
  },
  interrupt: elem => {
    elem == @library.par_elem() || elem == @library.align_elem()
  },
}

///|
/// Collects `CiteElem`s into `CiteGroup`s.
let cites : GroupingRule = {
  kind: Cites,
  priority: 2,
  tags: false,
  effect: content => {
    let elem = content.elem()
    if elem == @library.cite_elem() {
      Trigger
    } else if elem == @library.space_elem() {
      Inner
    } else {
      Interrupt
    }
  },
  interrupt: elem => {
    elem == @library.cite_group_elem() ||
    elem == @library.par_elem() ||
    elem == @library.align_elem()
  },
}

///|
/// Builds a `ListElem` from grouped `ListItems`s.
let list : GroupingRule = list_like_grouping(
  @library.list_elem(),
  @library.list_item_elem(),
  List,
)

///|
/// Builds an `EnumElem` from grouped `EnumItem`s.
let enum_ : GroupingRule = list_like_grouping(
  @library.enum_elem(),
  @library.enum_item_elem(),
  Enum,
)

///|
/// Builds a `TermsElem` from grouped `TermItem`s.
let terms : GroupingRule = list_like_grouping(
  @library.terms_elem(),
  @library.term_item_elem(),
  Terms,
)

///|
/// Collects `ListItemLike` elements into a `ListLike` element.
fn list_like_grouping(
  list : Element,
  item : Element,
  kind : RuleKind,
) -> GroupingRule {
  {
    kind,
    priority: 2,
    tags: false,
    effect: content => {
      let elem = content.elem()
      if elem == item {
        Trigger
      } else if elem == @library.space_elem() ||
        elem == @library.parbreak_elem() {
        Inner
      } else {
        Interrupt
      }
    },
    interrupt: elem => elem == list || elem == @library.align_elem(),
  }
}

///|
/// Processes grouped textual elements.
///
/// Specifically, it searches for regex matches in grouped textual elements and
/// - if there was a match, visits the results recursively,
/// - if there was no match, tries to simply implicitly use the grouped elements
///   as part of a paragraph grouping,
/// - if that's not possible because another grouping is active, temporarily
///   disables textual grouping and revisits the elements.
fn finish_textual(grouped : Grouped) -> Unit raise SourceError {
  let { s, start, } = grouped
  let mut start = start

  // Try to find a regex match in the grouped textual elements. Returns early
  // if there is one.
  if visit_textual(s, start) {
    return
  }

  // There was no regex match, so we need to collect the text into a paragraph
  // grouping. To do that, we first terminate all non-paragraph groupings.
  if in_non_par_grouping(s) {
    let elems = s.sink[start:].to_owned()
    s.sink.truncate(start)
    finish_grouping_while(s, in_non_par_grouping)
    start = s.sink.length()
    s.sink.append(elems)
  }

  // Now, there are only two options:
  // 1. We are already in a paragraph group. In this case, the elements just
  //    transparently become part of it.
  // 2. There is no group at all. In this case, we create one.
  if s.groupings.is_empty() && s.rules.iter().any(rule => rule.kind is Par) {
    s.groupings.push({
      start,
      rule: par,
      interrupted: false,
      contains_neutral: false,
    })
  }
}

///|
/// Whether there is an active grouping, but it is not a `PAR` grouping.
fn in_non_par_grouping(s : State) -> Bool {
  s.groupings.last() is Some(grouping) &&
  (!(grouping.rule.kind is Par) || grouping.interrupted)
}

///|
/// Whether there is exactly one active grouping, it is a `PAR` grouping, and it
/// spans the whole sink (with the exception of leading tags and neutral
/// elements).
fn is_fully_inline_or_neutral(s : State) -> Bool {
  s.kind is Fragment(..) &&
  !s.saw_parbreak &&
  s.groupings is [grouping] &&
  grouping.rule.kind is Par &&
  s.sink[:grouping.start]
  .iter()
  .all(pair => {
    pair.0.is_(@library.tag_elem()) || (grouping.rule.effect)(pair.0) is Neutral
  })
}

///|
/// Builds the `ParElem` from inline-level elements.
fn finish_par(grouped : Grouped) -> Unit raise SourceError {
  // Collapse unsupported spaces in-place.
  collapse_spaces(grouped.s.sink, grouped.start)

  // Collect the children.
  let elems = grouped.get()
  let span = select_span(elems)
  let (body, trunk) = repack(elems)

  // Create and visit the paragraph.
  let s = grouped.end()
  let elem = @library.ParElem::new(body).pack().spanned(span)
  visit(s, elem, trunk)
}

///|
/// Builds the `CiteGroup` from `CiteElem`s.
fn finish_cites(grouped : Grouped) -> Unit raise SourceError {
  // Collect the children.
  let elems = grouped.get()
  let span = select_span(elems)
  let trunk = elems[0].1
  let children = elems.iter().map(pair => pair.0).collect()

  // Create and visit the citation group.
  let s = grouped.end()
  let elem = @library.CiteGroup::new(children).pack().spanned(span)
  visit(s, elem, trunk)
}

///|
/// Builds the `ListElem` from `ListItem`s.
fn finish_list(grouped : Grouped) -> Unit raise SourceError {
  finish_list_like(
    grouped,
    @library.list_item_elem(),
    (item, local_) => {
      let item = @library.ListItem::of(item).unwrap()
      item.with_body(item.body().styled_with_map(local_)).pack()
    },
    (children, tight) => {
      @library.ListElem::new(
        children.map(c => @library.ListItem::of(c).unwrap()),
      )
      .with_tight(tight)
      .pack()
    },
  )
}

///|
/// Builds the `EnumElem` from `EnumItem`s.
fn finish_enum(grouped : Grouped) -> Unit raise SourceError {
  finish_list_like(
    grouped,
    @library.enum_item_elem(),
    (item, local_) => {
      let item = @library.EnumItem::of(item).unwrap()
      item.with_body(item.body().styled_with_map(local_)).pack()
    },
    (children, tight) => {
      @library.EnumElem::new(
        children.map(c => @library.EnumItem::of(c).unwrap()),
      )
      .with_tight(tight)
      .pack()
    },
  )
}

///|
/// Builds the `TermsElem` from `TermItem`s.
fn finish_terms(grouped : Grouped) -> Unit raise SourceError {
  finish_list_like(
    grouped,
    @library.term_item_elem(),
    (item, local_) => {
      let item = @library.TermItem::of(item).unwrap()
      item
      .with_term(item.term().styled_with_map(local_))
      .with_description(item.description().styled_with_map(local_))
      .pack()
    },
    (children, tight) => {
      @library.TermsElem::new(
        children.map(c => @library.TermItem::of(c).unwrap()),
      )
      .with_tight(tight)
      .pack()
    },
  )
}

///|
/// Builds the `ListLike` element from `ListItemLike` elements.
fn finish_list_like(
  grouped : Grouped,
  item_elem : Element,
  styled : (Content, Styles) -> Content,
  create : (Array[Content], Bool) -> Content,
) -> Unit raise SourceError {
  // Collect the children.
  let elems = grouped.get()
  let span = select_span(elems)
  let tight = !elems.iter().any(pair => pair.0.is_(@library.parbreak_elem()))
  let styles = elems
    .iter()
    .filter(pair => pair.0.is_(item_elem))
    .map(pair => pair.1)
  let trunk = StyleChain::trunk(styles).unwrap()
  let trunk_depth = trunk.depth()
  let children = []
  for pair in elems {
    let (c, s) = pair
    if !c.is_(item_elem) {
      continue
    }
    let local_ = s.suffix(trunk_depth)
    children.push(styled(c, local_))
  }

  // Create and visit the list.
  let s = grouped.end()
  let elem = create(children, tight).spanned(span)
  visit(s, elem, trunk)
}

///|
/// Visit textual elements in `s.sink[start..]` and apply regex show rules to
/// them.
fn visit_textual(s : State, start : Int) -> Bool raise SourceError {
  // Try to find a regex match in the grouped textual elements.
  if find_regex_match_in_elems(s.sink[start:]) is Some(m) {
    collapse_spaces(s.sink, start)
    let elems = s.sink[start:].to_owned()
    s.sink.truncate(start)
    visit_regex_match(s, elems, m)
    return true
  }
  false
}

///|
/// Finds the leftmost regex match for this style chain in the given textual
/// elements.
///
/// This merging also takes into account space collapsing so that we don't need
/// to call `collapse_spaces` on every textual group, performing yet another
/// linear pass. We only collapse the space elements on the cold path when there
/// is an actual match.
fn find_regex_match_in_elems(elems : ArrayView[Pair]) -> RegexMatch? {
  // The merged text, as a list of pieces (to support popping a discarded
  // space), and its length in UTF-8 bytes.
  let buf : Array[String] = []
  let mut buf_len = 0
  let mut base = 0
  let mut leftmost : RegexMatch? = None
  let mut current = StyleChain::empty()
  let mut state = SpaceState::Destructive
  for pair in elems {
    let (content, styles) = pair
    let (action, next, text) = collapse_transition_textual(
      state, content, styles,
    )
    state = next
    match action {
      Invisible => continue
      Skip => continue
      Discard =>
        // The discarded space is always the last piece.
        match buf.pop() {
          Some(piece) => buf_len -= @syntax.utf8_len(piece)
          None => ()
        }
      Keep => ()
    }

    // If styles differ, we search _before_ adding the new element's text.
    if styles != current && buf_len > 0 {
      leftmost = find_regex_match_in_str(buf.join(""), current)
      if leftmost is Some(_) {
        break
      }
      base += buf_len
      buf.clear()
      buf_len = 0
    }
    current = styles
    buf.push(text)
    buf_len += @syntax.utf8_len(text)
  }
  if leftmost is None {
    leftmost = find_regex_match_in_str(buf.join(""), current)
  }
  leftmost.map(m => { ..m, offset: base + m.offset, })
}

///|
/// Finds the leftmost regex match for this style chain in the given text.
fn find_regex_match_in_str(text : String, styles : StyleChain) -> RegexMatch? {
  let mut r = 0
  let revoked = @hashset.HashSet([])
  let mut leftmost : (@regex.Match, Int, Recipe)? = None
  let mut depth : Int? = None
  for entry in styles.entries() {
    let recipe = match entry {
      Recipe(recipe) => recipe
      Property(_) => continue
      Revocation(index) => {
        revoked.add(index)
        continue
      }
    }
    r += 1
    guard recipe.selector is Some(Regex(regex)) else { continue }
    guard regex.inner.find(text) is Some(m) else { continue }

    // Make sure we don't get any empty matches.
    if m.start == m.end {
      continue
    }

    // If we already have a match that is equally or more to the left, we're
    // not interested in this new match.
    if leftmost is Some((p, _, _)) && p.start <= m.start {
      continue
    }

    // Check whether the rule is already revoked. Do it only now to not
    // compute the depth unnecessarily. We subtract 1 from r because we
    // already incremented it.
    let total = match depth {
      Some(d) => d
      None => {
        let d = styles.recipes().count()
        depth = Some(d)
        d
      }
    }
    let index = total - (r - 1)
    if revoked.contains(index) {
      continue
    }
    leftmost = Some((m, index, recipe))
  }
  leftmost.map(found => {
    let (m, id, recipe) = found
    { offset: m.start, text: m.text, id, recipe, styles, }
  })
}

///|
/// Visit a regular expression match and any surrounding textual elements.
///
/// This will visit the following in order:
/// - Elements that come fully before the match: `elem <match>`
/// - Text that was interrupted by the start of the match: `te<match>`
/// - The matched text itself, sliced off as a new element: `<match>`
/// - Tag elements that come between parts of the match: `mat<tag>ch`
/// - Text that was interrupted by the end of the match: `<match>xt`
/// - Elements that come fully after the match: `<match> elem`
///
/// The matched text element will always be a `TextElem` or `SymbolElem` so that
/// user code can rely on the element having a `.text` field to access the
/// underlying string. If the regex matched only one existing text or symbol
/// element, then the new element will be derived from that one, otherwise it
/// will be built fresh with the span of the first matching element.
fn visit_regex_match(
  s : State,
  elems : ArrayView[Pair],
  m : RegexMatch,
) -> Unit raise SourceError {
  let match_start = m.offset
  let match_end = m.offset + @syntax.utf8_len(m.text)
  let mut cursor = 0
  let mut m : RegexMatch? = Some(m)
  for pair in elems {
    let (content, styles) = pair

    // Just forward tags. If a tag is between elements of the match, it will
    // be visited immediately after the match.
    if content.is_(@library.tag_elem()) {
      visit(s, content, styles)
      continue
    }

    // At this point, we can have a `TextElem`, `SymbolElem`, `SpaceElem`,
    // `LinebreakElem`, or `SmartQuoteElem`. We now determine the range of
    // the element.
    let len = if @library.TextElem::of(content) is Some(elem) {
      @syntax.utf8_len(elem.text())
    } else if @library.SymbolElem::of(content) is Some(elem) {
      @syntax.utf8_len(elem.text())
    } else {
      1 // The rest are Ascii, so just one byte.
    }
    let elem_start = cursor
    let elem_end = cursor + len
    cursor = elem_end
    if elem_end <= match_start || match_end <= elem_start {
      // This element is entirely outside the matched range, visit it
      // without slicing.
      visit(s, content, styles)
      continue
    }
    if elem_start < match_start {
      // This element's text begins before the start of the match, visit
      // that initial part.
      let end = match_start - elem_start
      visit(s, slice_textual(content, 0, end), styles)
    }

    // We visit the matched text itself when at the first element of the
    // match. Note that we will effectively ignore the elements which
    // compose the match.
    if m is Some({ text, styles, id, recipe, .. }) {
      m = None
      let matched_text = if match_end <= elem_end &&
        (
          content.is_(@library.text_elem()) ||
          content.is_(@library.symbol_elem())
        ) {
        // If the match is fully contained within one sliceable element,
        // we slice it to retain its element type and span/label.
        slice_textual(content, match_start - elem_start, match_end - elem_start)
      } else {
        // Otherwise we need to create a fresh text element and can only
        // retain the span of the first matching element.
        //
        // Creating a text element instead of propagating the
        // space/linebreak/smartquote ensures we always provide an
        // element with a `.text` field, so that users can rely on that
        // field being accessible.
        @library.TextElem::packed(text).spanned(content.span())
      }

      // Apply the show rule and visit the show rule's output element.
      let context = @library.Context::new(styles~)
      let output = recipe.apply(s.engine, context, matched_text)
      let revocation = Styles::from_array([Revocation(id)])
      let chained = styles.fresh().chain(revocation)
      visit(s, output, chained)
    }
    if elem_end > match_end {
      // This element's text finishes after the end of the match, visit
      // that final part.
      let start = match_end - elem_start
      visit(s, slice_textual(content, start, len), styles)
    }
  }
}

///|
/// Takes a text or symbol element and returns an appropriate sliced output
/// element. The range is in UTF-8 bytes.
fn slice_textual(elem : Content, start : Int, end : Int) -> Content {
  if @library.TextElem::of(elem) is Some(text) {
    // Unfortunately, we can't apply a `TextElem::span_offset` for more
    // precise tracking here because it creates a user-visible styled
    // element, nesting the text element, and obscuring the `.text` field.
    text.with_text(@syntax.utf8_slice(text.text(), start, end)).pack()
  } else if @library.SymbolElem::of(elem) is Some(symbol) {
    // Symbols are also sliced despite being a single grapheme cluster for
    // consistency with text. We may want to more generally avoid slicing
    // grapheme clusters in the future.
    // See also: <https://github.com/typst/typst/issues/8058>
    symbol.with_text(@syntax.utf8_slice(symbol.text(), start, end)).pack()
  } else {
    abort("can only slice text and symbols")
  }
}

///|
/// Finds the first non-detached span in the list.
fn select_span(children : ArrayView[Pair]) -> @syntax.Span {
  for pair in children {
    if !pair.0.span().is_detached() {
      return pair.0.span()
    }
  }
  @syntax.Span::detached()
}

///|
/// Turn realized content with styles back into owned content and a trunk style
/// chain.
fn repack(buf : ArrayView[Pair]) -> (Content, StyleChain) {
  let trunk = StyleChain::trunk_from_pairs(buf).unwrap_or(StyleChain::empty())
  let depth = trunk.depth()
  let seq = []
  for group in group_by_key(buf, pair => pair.1) {
    let chain = group[0].1
    let suffix = chain.suffix(depth)
    if suffix.is_empty() {
      for pair in group {
        seq.push(pair.0)
      }
    } else if group is [(element, _)] {
      seq.push(element.styled_with_map(suffix))
    } else {
      seq.push(
        Content::sequence(group.iter().map(pair => pair.0).collect()).styled_with_map(
          suffix,
        ),
      )
    }
  }
  (Content::sequence(seq), trunk)
}
