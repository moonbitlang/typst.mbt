// Port of `syntect/src/parsing/syntax_set.rs`.

///|
/// A syntax set holds multiple syntaxes that have been linked together.
///
/// Use a [`SyntaxSetBuilder`] to load syntax definitions and build a syntax
/// set.
// `path_syntaxes` is only read by `find_syntax_by_path`, `into_builder` and
// `Clone` (syntect 5.3.0 parsing/syntax_set.rs:233, :313, :111), none of
// which is ported; it is always empty here.
#warnings("-unused_field")
pub struct SyntaxSet {
  priv syntaxes : Array[SyntaxReference]
  /// Stores the syntax index for every path that was loaded
  priv path_syntaxes : Array[(String, Int)]
  priv mut first_line_cache : FirstLineCache?
}

///|
/// A linked version of a [`SyntaxDefinition`] that is only useful as part of
/// the [`SyntaxSet`] that contains it.
pub struct SyntaxReference {
  name : String
  file_extensions : Array[String]
  scope : Scope
  first_line_match : String?
  hidden : Bool
  variables : Map[String, String]
  priv mut lazy_contexts : LazyContexts?
  /// Decodes the contexts on first use (upstream deserializes
  /// `serialized_lazy_contexts`).
  priv loader : (() -> LazyContexts)?
}

///|
/// The lazy-loaded parts of a [`SyntaxReference`].
pub(all) struct LazyContexts {
  context_ids : Map[String, ContextId]
  contexts : Array[Context]
}

///|
/// A syntax set builder is used for loading syntax definitions from the file
/// system or by adding [`SyntaxDefinition`] objects.
///
/// Once all the syntaxes have been added, call [`build`] to turn the builder
/// into a [`SyntaxSet`] that can be used for parsing or highlighting.
pub struct SyntaxSetBuilder {
  priv syntaxes : Array[SyntaxDefinition]
  priv path_syntaxes : Array[(String, Int)]
}

///|
pub fn SyntaxSet::new() -> SyntaxSet {
  { syntaxes: [], path_syntaxes: [], first_line_cache: None, }
}

///|
/// Creates a syntax set from syntaxes whose contexts are loaded lazily (the
/// equivalent of deserializing a dump).
pub fn SyntaxSet::from_lazy_syntaxes(
  syntaxes : Array[SyntaxReference],
) -> SyntaxSet {
  { syntaxes, path_syntaxes: [], first_line_cache: None, }
}

///|
/// A syntax whose contexts are produced by `loader` on first use.
pub fn SyntaxReference::new_lazy(
  name~ : String,
  file_extensions~ : Array[String],
  scope~ : Scope,
  first_line_match~ : String?,
  hidden~ : Bool,
  variables~ : Map[String, String],
  loader~ : () -> LazyContexts,
) -> SyntaxReference {
  {
    name,
    file_extensions,
    scope,
    first_line_match,
    hidden,
    variables,
    lazy_contexts: None,
    loader: Some(loader),
  }
}

///|
/// The list of syntaxes in the set
pub fn SyntaxSet::syntaxes(self : SyntaxSet) -> Array[SyntaxReference] {
  self.syntaxes
}

///|
/// Finds a syntax by its default scope, for example `source.regexp` finds
/// the regex syntax.
pub fn SyntaxSet::find_syntax_by_scope(
  self : SyntaxSet,
  scope : Scope,
) -> SyntaxReference? {
  self.syntaxes.rev_iter().find_first(s => s.scope == scope)
}

///|
pub fn SyntaxSet::find_syntax_by_name(
  self : SyntaxSet,
  name : String,
) -> SyntaxReference? {
  self.syntaxes.rev_iter().find_first(s => name == s.name)
}

///|
pub fn SyntaxSet::find_syntax_by_extension(
  self : SyntaxSet,
  extension : String,
) -> SyntaxReference? {
  self.syntaxes
  .rev_iter()
  .find_first(s => {
    s.file_extensions.iter().any(e => eq_ignore_ascii_case(e, extension))
  })
}

///|
/// Searches for a syntax first by extension and then by case-insensitive
/// name
///
/// This is useful for things like Github-flavoured-markdown code block
/// highlighting where all you have to go on is a short token given by the
/// user
pub fn SyntaxSet::find_syntax_by_token(
  self : SyntaxSet,
  s : String,
) -> SyntaxReference? {
  let ext_res = self.find_syntax_by_extension(s)
  if ext_res is Some(_) {
    return ext_res
  }
  self.syntaxes
  .rev_iter()
  .find_first(syntax => eq_ignore_ascii_case(syntax.name, s))
}

///|
/// Try to find the syntax for a file based on its first line
///
/// This uses regexes that come with some sublime syntax grammars for
/// matching things like shebangs and mode lines like `-*- Mode: C -*-`
pub fn SyntaxSet::find_syntax_by_first_line(
  self : SyntaxSet,
  s : String,
) -> SyntaxReference? {
  let s = if s.has_prefix("\u{feff}") {
    s.unsafe_substring(start=1, end=s.length())
  } else {
    s
  } // Strip UTF-8 BOM
  let cache = self.first_line_cache()
  let text = ByteIndex::new(s)
  for entry in cache.regexes.rev_iter() {
    let (reg, i) = entry
    if reg.search(text, 0, text.len(), None) {
      return Some(self.syntaxes[i])
    }
  }
  None
}

///|
/// Finds a syntax for plain text, which usually has no highlighting rules.
pub fn SyntaxSet::find_syntax_plain_text(self : SyntaxSet) -> SyntaxReference {
  match self.find_syntax_by_name("Plain Text") {
    Some(s) => s
    None => abort("All syntax sets ought to have a plain text syntax")
  }
}

///|
pub fn SyntaxSet::get_context(
  self : SyntaxSet,
  context_id : ContextId,
) -> Context raise ParsingError {
  guard self.syntaxes.get(context_id.syntax_index) is Some(syntax) else {
    raise MissingContext(context_id)
  }
  guard syntax.contexts().get(context_id.context_index) is Some(context) else {
    raise MissingContext(context_id)
  }
  context
}

///|
fn SyntaxSet::first_line_cache(self : SyntaxSet) -> FirstLineCache {
  match self.first_line_cache {
    Some(cache) => cache
    None => {
      let cache = FirstLineCache::new(self.syntaxes)
      self.first_line_cache = Some(cache)
      cache
    }
  }
}

///|
pub fn SyntaxReference::context_ids(
  self : SyntaxReference,
) -> Map[String, ContextId] {
  self.get_lazy_contexts().context_ids
}

///|
fn SyntaxReference::contexts(self : SyntaxReference) -> Array[Context] {
  self.get_lazy_contexts().contexts
}

///|
fn SyntaxReference::get_lazy_contexts(self : SyntaxReference) -> LazyContexts {
  match self.lazy_contexts {
    Some(l) => l
    None => {
      let l = match self.loader {
        Some(loader) => loader()
        None => abort("data is not corrupt or out of sync with the code")
      }
      self.lazy_contexts = Some(l)
      l
    }
  }
}

///|
pub fn SyntaxSetBuilder::new() -> SyntaxSetBuilder {
  { syntaxes: [], path_syntaxes: [], }
}

///|
/// Add a syntax to the set.
pub fn SyntaxSetBuilder::add(
  self : SyntaxSetBuilder,
  syntax : SyntaxDefinition,
) -> Unit {
  self.syntaxes.push(syntax)
}

///|
/// The list of syntaxes added so far.
pub fn SyntaxSetBuilder::syntaxes(
  self : SyntaxSetBuilder,
) -> Array[SyntaxDefinition] {
  self.syntaxes
}

///|
/// Build a [`SyntaxSet`] from the syntaxes that have been added to this
/// builder.
///
/// ### Linking
///
/// The contexts in syntaxes can reference other contexts in the same syntax
/// or even other syntaxes. For example, a HTML syntax can reference a CSS
/// syntax so that CSS blocks in HTML work as expected.
///
/// Those references work in various ways and involve one or two lookups. To
/// avoid having to do these lookups during parsing/highlighting, the
/// references are changed to directly reference contexts via index. That's
/// called linking.
///
/// Linking is done in this build step. So in order to get the best
/// performance, you should try to avoid calling this too much. Ideally,
/// create a [`SyntaxSet`] once and then use it many times.
pub fn SyntaxSetBuilder::build(self : SyntaxSetBuilder) -> SyntaxSet {
  let syntax_definitions = self.syntaxes
  let path_syntaxes = self.path_syntaxes
  let syntaxes : Array[SyntaxReference] = []
  let all_context_ids : Array[Map[String, ContextId]] = []
  let all_contexts : Array[Array[Context]] = Array::makei(
    syntax_definitions.length(),
    _ => [],
  )
  for syntax_index, syntax_definition in syntax_definitions {
    let context_ids = Map([])
    let contexts = syntax_definition.contexts.to_array()
    // Sort the values of the HashMap so that the contexts in the resulting
    // SyntaxSet have a deterministic order for serializing. Because we're
    // sorting by the keys which are unique, we can use an unstable sort.
    contexts.sort_by((a, b) => compare_str(a.0, b.0))
    for entry in contexts {
      let (name, context) = entry
      let context_index = all_contexts[syntax_index].length()
      context_ids[name] = { syntax_index, context_index, }
      all_contexts[syntax_index].push(context)
    }
    let syntax : SyntaxReference = {
      name: syntax_definition.name,
      file_extensions: syntax_definition.file_extensions,
      scope: syntax_definition.scope,
      first_line_match: syntax_definition.first_line_match,
      hidden: syntax_definition.hidden,
      variables: syntax_definition.variables,
      lazy_contexts: None,
      loader: None,
    }
    syntaxes.push(syntax)
    all_context_ids.push(context_ids)
  }
  let mut found_more_backref_includes = true
  for syntax_index in 0..<syntaxes.length() {
    let no_prototype : Set[ContextId] = Set([])
    let prototype = all_context_ids[syntax_index].get("prototype")
    if prototype is Some(prototype_id) {
      recursively_mark_no_prototype(
        prototype_id,
        all_context_ids[syntax_index],
        all_contexts,
        no_prototype,
      )
    }
    for _, context_id in all_context_ids[syntax_index] {
      let context = all_contexts[context_id.syntax_index][context_id.context_index]
      if prototype is Some(prototype_id) {
        if context.meta_include_prototype && !no_prototype.contains(context_id) {
          context.prototype = Some(prototype_id)
        }
      }
      link_context(context, syntax_index, all_context_ids, syntaxes)
      if context.uses_backrefs {
        found_more_backref_includes = true
      }
    }
  }

  // We need to recursively mark contexts that include contexts which use
  // backreferences as using backreferences.
  while found_more_backref_includes {
    found_more_backref_includes = false
    // find any contexts which include a context which uses backrefs and mark
    // those as using backrefs - to support nested includes
    for syntax_index in 0..<syntaxes.length() {
      for context_index in 0..<all_contexts[syntax_index].length() {
        let context = all_contexts[syntax_index][context_index]
        if !context.uses_backrefs &&
          context.patterns
          .iter()
          .any(pattern => {
            pattern is Include(Direct(id)) &&
            all_contexts[id.syntax_index][id.context_index].uses_backrefs
          }) {
          context.uses_backrefs = true
          // look for contexts including this context
          found_more_backref_includes = true
        }
      }
    }
  }
  for i, syntax in syntaxes {
    syntax.lazy_contexts = Some({
      context_ids: all_context_ids[i],
      contexts: all_contexts[i],
    })
  }
  { syntaxes, path_syntaxes, first_line_cache: None, }
}

///|
fn recursively_mark_no_prototype(
  context_id : ContextId,
  syntax_context_ids : Map[String, ContextId],
  all_contexts : Array[Array[Context]],
  no_prototype : Set[ContextId],
) -> Unit {
  let first_time = !no_prototype.contains(context_id)
  no_prototype.add(context_id)
  if !first_time {
    return
  }
  for
    pattern in all_contexts[context_id.syntax_index][context_id.context_index].patterns {
    match pattern {
      // Apparently inline blocks also don't include the prototype when
      // within the prototype. This is really weird, but necessary to run the
      // YAML syntax.
      Match(match_pat) => {
        let maybe_context_refs = match match_pat.operation {
          Push(context_refs) | Set(context_refs) => Some(context_refs)
          Pop | None => None
        }
        if maybe_context_refs is Some(context_refs) {
          for context_ref in context_refs {
            match context_ref {
              Inline(s) | Named(s) =>
                if syntax_context_ids.get(s) is Some(i) {
                  recursively_mark_no_prototype(
                    i, syntax_context_ids, all_contexts, no_prototype,
                  )
                }
              Direct(id) =>
                recursively_mark_no_prototype(
                  id, syntax_context_ids, all_contexts, no_prototype,
                )
              _ => ()
            }
          }
        }
      }
      Include(reference) =>
        match reference {
          Named(s) =>
            if syntax_context_ids.get(s) is Some(id) {
              recursively_mark_no_prototype(
                id, syntax_context_ids, all_contexts, no_prototype,
              )
            }
          Direct(id) =>
            recursively_mark_no_prototype(
              id, syntax_context_ids, all_contexts, no_prototype,
            )
          _ => ()
        }
    }
  }
}

///|
fn link_context(
  context : Context,
  syntax_index : Int,
  all_context_ids : Array[Map[String, ContextId]],
  syntaxes : Array[SyntaxReference],
) -> Unit {
  for i, pattern in context.patterns {
    context.patterns[i] = match pattern {
      Match(match_pat) =>
        Match(
          link_match_pat(match_pat, syntax_index, all_context_ids, syntaxes),
        )
      Include(context_ref) =>
        Include(link_ref(context_ref, syntax_index, all_context_ids, syntaxes))
    }
  }
}

///|
fn link_ref(
  context_ref : ContextReference,
  syntax_index : Int,
  all_context_ids : Array[Map[String, ContextId]],
  syntaxes : Array[SyntaxReference],
) -> ContextReference {
  let linked_context_id = match context_ref {
    Named(s) | Inline(s) =>
      // This isn't actually correct, but it is better than nothing/crashing.
      // This is being phased out anyhow, see
      // https://github.com/sublimehq/Packages/issues/73
      // Fixes issue #30
      if s == "$top_level_main" {
        all_context_ids[syntax_index].get("main")
      } else {
        all_context_ids[syntax_index].get(s)
      }
    ByScope(scope~, sub_context~, with_escape~) =>
      with_plain_text_fallback(
        all_context_ids,
        syntaxes,
        with_escape,
        find_id(sub_context, all_context_ids, syntaxes, s => s.scope == scope),
      )
    File(name~, sub_context~, with_escape~) =>
      with_plain_text_fallback(
        all_context_ids,
        syntaxes,
        with_escape,
        find_id(sub_context, all_context_ids, syntaxes, s => s.name == name),
      )
    Direct(_) => None
  }
  match linked_context_id {
    Some(context_id) => Direct(context_id)
    None => context_ref
  }
}

///|
fn with_plain_text_fallback(
  all_context_ids : Array[Map[String, ContextId]],
  syntaxes : Array[SyntaxReference],
  with_escape : Bool,
  context_id : ContextId?,
) -> ContextId? {
  match context_id {
    Some(_) => context_id
    None =>
      if with_escape {
        // If we keep this reference unresolved, syntect will crash when it
        // encounters the reference. Rather than crashing, we instead fall
        // back to "Plain Text". This seems to be how Sublime Text behaves.
        // It should be a safe thing to do since `embed`s always includes an
        // `escape` to get out of the `embed`.
        find_id(None, all_context_ids, syntaxes, s => s.name == "Plain Text")
      } else {
        None
      }
  }
}

///|
fn find_id(
  sub_context : String?,
  all_context_ids : Array[Map[String, ContextId]],
  syntaxes : Array[SyntaxReference],
  predicate : (SyntaxReference) -> Bool,
) -> ContextId? {
  let context_name = match sub_context {
    Some(x) => x
    None => "main"
  }
  for i = syntaxes.length() - 1; i >= 0; i = i - 1 {
    if predicate(syntaxes[i]) {
      return all_context_ids[i].get(context_name)
    }
  }
  None
}

///|
fn link_match_pat(
  match_pat : MatchPattern,
  syntax_index : Int,
  all_context_ids : Array[Map[String, ContextId]],
  syntaxes : Array[SyntaxReference],
) -> MatchPattern {
  let link = r => link_ref(r, syntax_index, all_context_ids, syntaxes)
  let operation : MatchOperation = match match_pat.operation {
    Push(context_refs) => Push(context_refs.map(link))
    Set(context_refs) => Set(context_refs.map(link))
    op => op
  }
  let with_prototype = match_pat.with_prototype.map(link)
  { ..match_pat, operation, with_prototype, }
}

///|
priv struct FirstLineCache {
  /// (first line regex, syntax index) pairs for all syntaxes with a first
  /// line regex
  regexes : Array[(Regex, Int)]
}

///|
fn FirstLineCache::new(syntaxes : Array[SyntaxReference]) -> FirstLineCache {
  let regexes = []
  for i, syntax in syntaxes {
    if syntax.first_line_match is Some(reg_str) {
      let reg = Regex::new(reg_str)
      regexes.push((reg, i))
    }
  }
  { regexes, }
}

///|
/// Rust's `str::eq_ignore_ascii_case`.
pub fn eq_ignore_ascii_case(a : StringView, b : StringView) -> Bool {
  if a.length() != b.length() {
    return false
  }
  for i in 0..<a.length() {
    if ascii_lower(a.code_unit_at(i).to_int()) !=
      ascii_lower(b.code_unit_at(i).to_int()) {
      return false
    }
  }
  true
}

///|
fn ascii_lower(c : Int) -> Int {
  if c >= 'A' && c <= 'Z' {
    c + 32
  } else {
    c
  }
}

///|
/// Rust `str` ordering (by code points).
pub fn compare_str(a : StringView, b : StringView) -> Int {
  let mut i = 0
  let mut j = 0
  while i < a.length() && j < b.length() {
    let { cp: ca, idx: ni, } = @unicode.decode_at(a, i)
    let { cp: cb, idx: nj, } = @unicode.decode_at(b, j)
    if ca != cb {
      return ca.compare(cb)
    }
    i = ni
    j = nj
  }
  (a.length() - i).compare(b.length() - j)
}
