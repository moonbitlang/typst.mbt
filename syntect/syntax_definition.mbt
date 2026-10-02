// Port of `syntect/src/parsing/syntax_definition.rs`.
//
// Data structures for representing syntax definitions

///|
pub type CaptureMapping = Array[(Int, Array[Scope])]

///|
/// An opaque ID for a [`Context`].
pub(all) struct ContextId {
  /// Index into [`SyntaxSet::syntaxes`]
  syntax_index : Int
  /// Index into the contexts of the [`Self::syntax_index`] syntax
  context_index : Int
} derive(Eq, Hash, Debug)

///|
/// The main data structure representing a syntax definition loaded from a
/// `.sublime-syntax` file
///
/// You'll probably only need these as references to be passed around to
/// parsing code.
pub(all) struct SyntaxDefinition {
  name : String
  file_extensions : Array[String]
  scope : Scope
  first_line_match : String?
  hidden : Bool
  variables : Map[String, String]
  contexts : Map[String, Context]
}

///|
pub(all) struct Context {
  mut meta_scope : Array[Scope]
  mut meta_content_scope : Array[Scope]
  /// This being set false in the syntax file implies this field being set
  /// false, but it can also be set falso for contexts that don't include the
  /// prototype for other reasons
  mut meta_include_prototype : Bool
  mut clear_scopes : ClearAmount?
  /// This is filled in by the linker at link time for contexts that have
  /// `meta_include_prototype==true` and are not included from the prototype.
  mut prototype : ContextId?
  mut uses_backrefs : Bool
  patterns : Array[Pattern]
}

///|
pub fn Context::new(meta_include_prototype : Bool) -> Context {
  {
    meta_scope: [],
    meta_content_scope: [],
    meta_include_prototype,
    clear_scopes: None,
    uses_backrefs: false,
    patterns: [],
    prototype: None,
  }
}

///|
pub(all) enum Pattern {
  Match(MatchPattern)
  Include(ContextReference)
}

///|
pub struct MatchPattern {
  /// A unique id, standing in for upstream's use of the pattern's address as
  /// the key of the parser's search cache.
  priv id : Int
  has_captures : Bool
  regex : Regex
  scope : Array[Scope]
  captures : CaptureMapping?
  operation : MatchOperation
  with_prototype : ContextReference?
}

///|
pub(all) enum ContextReference {
  Named(String)
  ByScope(
    scope~ : Scope,
    sub_context~ : String?,
    /// `true` if this reference by scope is part of an `embed` for which
    /// there is an `escape`. In other words a reference for a context for
    /// which there "always is a way out". Enables falling back to `Plain
    /// Text` syntax in case the referenced scope is missing.
    with_escape~ : Bool
  )
  File(name~ : String, sub_context~ : String?, with_escape~ : Bool)
  Inline(String)
  Direct(ContextId)
} derive(Eq)

///|
/// Upstream's `Debug` (used by error messages).
pub impl Show for ContextReference with fn output(self, logger) {
  match self {
    Named(s) => logger.write_string("Named(\{rust_debug_str(s)})")
    ByScope(scope~, sub_context~, with_escape~) =>
      logger.write_string(
        "ByScope { scope: \{scope.debug()}, sub_context: \{debug_opt_str(sub_context)}, with_escape: \{with_escape} }",
      )
    File(name~, sub_context~, with_escape~) =>
      logger.write_string(
        "File { name: \{rust_debug_str(name)}, sub_context: \{debug_opt_str(sub_context)}, with_escape: \{with_escape} }",
      )
    Inline(s) => logger.write_string("Inline(\{rust_debug_str(s)})")
    Direct(id) =>
      logger.write_string(
        "Direct(ContextId { syntax_index: \{id.syntax_index}, context_index: \{id.context_index} })",
      )
  }
}

///|
fn debug_opt_str(s : String?) -> String {
  match s {
    None => "None"
    Some(s) => "Some(\{rust_debug_str(s)})"
  }
}

///|
pub(all) enum MatchOperation {
  Push(Array[ContextReference])
  Set(Array[ContextReference])
  Pop
  None
}

///|
/// Used to iterate over all the match patterns in a context
///
/// Basically walks the tree of patterns and include directives in the
/// correct order.
pub struct MatchIter {
  priv syntax_set : SyntaxSet
  priv ctx_stack : Array[Context]
  priv index_stack : Array[Int]
}

///|
pub fn MatchIter::next(self : MatchIter) -> (Context, Int)? {
  while true {
    if self.ctx_stack.is_empty() {
      return None
    }
    let last_index = self.ctx_stack.length() - 1
    let context = self.ctx_stack[last_index]
    let index = self.index_stack[last_index]
    self.index_stack[last_index] = index + 1
    if index < context.patterns.length() {
      match context.patterns[index] {
        Match(_) => return Some((context, index))
        Include(ctx_ref) => {
          let ctx_ptr = match ctx_ref {
            Direct(context_id) =>
              self.syntax_set.get_context(context_id) catch {
                _ => abort("unwrap on missing context")
              }
            _ => continue // skip this and move onto the next one
          }
          self.ctx_stack.push(ctx_ptr)
          self.index_stack.push(0)
        }
      }
    } else {
      self.ctx_stack.pop() |> ignore
      self.index_stack.pop() |> ignore
    }
  }
  None
}

///|
/// Returns an iterator over all the match patterns in this context.
///
/// It recursively follows include directives. Can only be run on contexts
/// that have already been linked up.
pub fn context_iter(syntax_set : SyntaxSet, context : Context) -> MatchIter {
  { syntax_set, ctx_stack: [context], index_stack: [0], }
}

///|
/// Returns the match pattern at an index
pub fn Context::match_at(
  self : Context,
  index : Int,
) -> MatchPattern raise ParsingError {
  match self.patterns[index] {
    Match(match_pat) => match_pat
    _ => raise BadMatchIndex(index)
  }
}

///|
/// find the pointed to context
pub fn ContextReference::resolve(
  self : ContextReference,
  syntax_set : SyntaxSet,
) -> Context raise ParsingError {
  match self {
    Direct(context_id) => syntax_set.get_context(context_id)
    _ => raise UnresolvedContextReference(self)
  }
}

///|
/// get the context ID this reference points to
pub fn ContextReference::id(
  self : ContextReference,
) -> ContextId raise ParsingError {
  match self {
    Direct(context_id) => context_id
    _ => raise UnresolvedContextReference(self)
  }
}

///|
pub fn substitute_backrefs_in_regex(
  regex_str : String,
  substituter : (Int) -> String?,
) -> String {
  let reg_str = StringBuilder()
  let mut last_was_escape = false
  for c in regex_str {
    if last_was_escape && c >= '0' && c <= '9' {
      let val = c.to_int() - '0'.to_int()
      if substituter(val) is Some(sub) {
        reg_str.write_string(sub)
      }
    } else if last_was_escape {
      reg_str.write_char('\\')
      reg_str.write_char(c)
    } else if c != '\\' {
      reg_str.write_char(c)
    }
    last_was_escape = c == '\\' && !last_was_escape
  }
  if last_was_escape {
    reg_str.write_char('\\')
  }
  reg_str.to_string()
}

///|
let match_pattern_counter : Ref[Int] = Ref::new(0)

///|
pub fn MatchPattern::new(
  has_captures : Bool,
  regex_str : String,
  scope : Array[Scope],
  captures : CaptureMapping?,
  operation : MatchOperation,
  with_prototype : ContextReference?,
) -> MatchPattern {
  match_pattern_counter.val += 1
  {
    id: match_pattern_counter.val,
    has_captures,
    regex: Regex::new(regex_str),
    scope,
    captures,
    operation,
    with_prototype,
  }
}

///|
/// Used by the parser to compile a regex which needs to reference regions
/// from another matched pattern.
pub fn MatchPattern::regex_with_refs(
  self : MatchPattern,
  region : Region,
  text : ByteIndex,
) -> Regex {
  let new_regex = substitute_backrefs_in_regex(self.regex.regex_str(), i => {
    region.pos(i).map(p => regex_syntax_escape(text.slice(p.0, p.1)))
  })
  Regex::new(new_regex)
}

///|
pub fn MatchPattern::regex(self : MatchPattern) -> Regex {
  self.regex
}

///|
/// `regex_syntax::is_meta_character`.
fn is_meta_character(c : Char) -> Bool {
  c
  is ('\\'
  | '.'
  | '+'
  | '*'
  | '?'
  | '('
  | ')'
  | '|'
  | '['
  | ']'
  | '{'
  | '}'
  | '^'
  | '$'
  | '#'
  | '&'
  | '-'
  | '~')
}

///|
/// `regex_syntax::escape`: escapes all regular expression meta characters.
pub fn regex_syntax_escape(text : StringView) -> String {
  let buf = StringBuilder()
  regex_syntax_escape_into(text, buf)
  buf.to_string()
}

///|
/// `regex_syntax::escape_into`.
pub fn regex_syntax_escape_into(text : StringView, buf : StringBuilder) -> Unit {
  for c in text {
    if is_meta_character(c) {
      buf.write_char('\\')
    }
    buf.write_char(c)
  }
}

///|
/// Rust's `{:?}` of a `str`.
pub fn rust_debug_str(s : StringView) -> String {
  @unicode.rust_debug_str(s)
}
