// Port of `syntect/src/parsing/parser.rs`.
//
// See upstream for the long introduction to how Sublime Text syntax
// definitions work and how loops with non-consuming push/pop are prevented.

///|
/// Errors that can occur while parsing.
pub(all) suberror ParsingError {
  /// Somehow main context was popped from the stack
  MissingMainContext
  /// A context is missing. Usually caused by a syntax referencing a another
  /// syntax that is not known to syntect. See e.g.
  /// <https://github.com/trishume/syntect/issues/421>
  MissingContext(ContextId)
  /// A bad index to match_at
  BadMatchIndex(Int)
  /// Tried to use a ContextReference that has not bee resolved yet
  UnresolvedContextReference(ContextReference)
}

///|
pub impl Show for ParsingError with fn output(self, logger) {
  match self {
    MissingMainContext =>
      logger.write_string("Somehow main context was popped from the stack")
    MissingContext(id) =>
      logger.write_string(
        "Missing context with ID 'ContextId { syntax_index: \{id.syntax_index}, context_index: \{id.context_index} }'",
      )
    BadMatchIndex(i) => logger.write_string("Bad index to match_at: \{i}")
    UnresolvedContextReference(r) =>
      logger.write_string(
        "Tried to use a ContextReference that has not bee resolved yet: \{r}",
      )
  }
}

///|
/// Keeps the current parser state (the internal syntax interpreter stack)
/// between lines of parsing.
///
/// If you are parsing an entire file you create one of these at the start
/// and use it all the way to the end.
pub struct ParseState {
  priv stack : Array[StateLevel]
  priv mut first_line : Bool
  // See issue #101. Contains indices of frames pushed by `with_prototype`s.
  // Doesn't look at `with_prototype`s below top of stack.
  priv proto_starts : Array[Int]
}

///|
priv struct StateLevel {
  context : ContextId
  prototypes : Array[ContextId]
  captures : (Region, ByteIndex)?
}

///|
priv struct RegexMatch {
  regions : Region
  context : Context
  pat_index : Int
  from_with_prototype : Bool
  would_loop : Bool
}

///|
/// Create a state from a syntax, keeps its own reference counted pointer to
/// the main context of the syntax.
pub fn ParseState::new(syntax : SyntaxReference) -> ParseState {
  let start_state : StateLevel = {
    context: syntax.context_ids()["__start"],
    prototypes: [],
    captures: None,
  }
  { stack: [start_state], first_line: true, proto_starts: [] }
}

///|
/// Parses a single line of the file. Because of the way regex engines work
/// you unfortunately have to pass in a single line contiguous in memory.
/// This can be bad for really long lines. Sublime Text avoids this by just
/// not highlighting lines that are too long (thousands of characters).
///
/// Returns the changes to the scope stack (with UTF-8 offsets into the
/// line).
pub fn ParseState::parse_line(
  self : ParseState,
  line : String,
  syntax_set : SyntaxSet,
) -> Array[(Int, ScopeStackOp)] raise ParsingError {
  self.parse_line_indexed(ByteIndex::new(line), syntax_set)
}

///|
/// Like `parse_line`, for a line whose byte index is already computed.
pub fn ParseState::parse_line_indexed(
  self : ParseState,
  line : ByteIndex,
  syntax_set : SyntaxSet,
) -> Array[(Int, ScopeStackOp)] raise ParsingError {
  if self.stack.is_empty() {
    raise MissingMainContext
  }
  let match_start = Ref::new(0)
  let res = []
  if self.first_line {
    let cur_level = self.stack[self.stack.length() - 1]
    let context = syntax_set.get_context(cur_level.context)
    if !context.meta_content_scope.is_empty() {
      res.push((0, ScopeStackOp::Push(context.meta_content_scope[0])))
    }
    self.first_line = false
  }
  let regions = Region::new()
  let search_cache : Map[Int, Region?] = Map::new(capacity=128)
  // Used for detecting loops with push/pop, see long comment above.
  let non_consuming_push_at = Ref::new((0, 0))
  let text = SearchText::new(line)
  while self.parse_next_token(
      text, syntax_set, match_start, search_cache, regions, non_consuming_push_at,
      res,
    ) {

  }
  res
}

///|
fn ParseState::parse_next_token(
  self : ParseState,
  line : SearchText,
  syntax_set : SyntaxSet,
  start : Ref[Int],
  search_cache : Map[Int, Region?],
  regions : Region,
  non_consuming_push_at : Ref[(Int, Int)],
  ops : Array[(Int, ScopeStackOp)],
) -> Bool raise ParsingError {
  let check_pop_loop = {
    let (pos, stack_depth) = non_consuming_push_at.val
    pos == start.val && stack_depth == self.stack.length()
  }

  // Trim proto_starts that are no longer valid
  while self.proto_starts.last() is Some(s) && s >= self.stack.length() {
    self.proto_starts.pop() |> ignore
  }
  let best_match = self.find_best_match(
    line,
    start.val,
    syntax_set,
    search_cache,
    regions,
    check_pop_loop,
  )
  guard best_match is Some(reg_match) else { return false }
  if reg_match.would_loop {
    // A push that doesn't consume anything (a regex that resulted in an
    // empty match at the current position) can not be followed by a
    // non-consuming pop. Otherwise we're back where we started and would
    // try the same sequence of matches again, resulting in an infinite
    // loop. In this case, Sublime Text advances one character and tries
    // again, thus preventing the loop.
    match line.next_char_offset(start.val) {
      Some(next) => {
        start.val = next
        return true
      }
      // End of line, no character to advance and no point trying any more
      // patterns.
      None => return false
    }
  }
  let match_end = reg_match.regions.pos(0).unwrap().1
  let consuming = match_end > start.val
  if !consuming {
    // The match doesn't consume any characters. If this is a "push",
    // remember the position and stack size so that we can check the next
    // "pop" for loops. Otherwise leave the state, e.g. non-consuming "set"
    // could also result in a loop.
    let context = reg_match.context
    let match_pattern = context.match_at(reg_match.pat_index)
    if match_pattern.operation is Push(_) {
      non_consuming_push_at.val = (match_end, self.stack.length() + 1)
    }
  }
  start.val = match_end

  // ignore `with_prototype`s below this if a context is pushed
  if reg_match.from_with_prototype {
    // use current height, since we're before the actual push
    self.proto_starts.push(self.stack.length())
  }
  let level_context = {
    let id = self.stack[self.stack.length() - 1].context
    syntax_set.get_context(id)
  }
  self.exec_pattern(line, reg_match, level_context, syntax_set, ops) |> ignore
  true
}

///|
fn ParseState::find_best_match(
  self : ParseState,
  line : SearchText,
  start : Int,
  syntax_set : SyntaxSet,
  search_cache : Map[Int, Region?],
  regions : Region,
  check_pop_loop : Bool,
) -> RegexMatch? raise ParsingError {
  let cur_level = self.stack[self.stack.length() - 1]
  let context = syntax_set.get_context(cur_level.context)
  let prototype = context.prototype

  // Build the contexts we want to visit in order
  let context_chain : Array[(Bool, ContextId, (Region, ByteIndex)?)] = []
  let proto_start = self.proto_starts.last().unwrap_or(0)
  // Sublime applies with_prototypes from bottom to top
  for i in proto_start..<self.stack.length() {
    let lvl = self.stack[i]
    for ctx in lvl.prototypes {
      context_chain.push((true, ctx, lvl.captures))
    }
  }
  if prototype is Some(ctx) {
    context_chain.push((false, ctx, None))
  }
  context_chain.push((false, cur_level.context, cur_level.captures))
  let mut min_start = @int.max_value
  let mut best_match : RegexMatch? = None
  let mut pop_would_loop = false
  for entry in context_chain {
    let (from_with_proto, ctx, captures) = entry
    let iter = context_iter(syntax_set, syntax_set.get_context(ctx))
    while iter.next() is Some((pat_context, pat_index)) {
      let match_pat = pat_context.match_at(pat_index)
      if self.search(line, start, match_pat, captures, search_cache, regions)
        is Some(match_region) {
        let (match_start, match_end) = match_region.pos(0).unwrap()
        if match_start < min_start ||
          (match_start == min_start && pop_would_loop) {
          // New match is earlier in text than old match, or old match was a
          // looping pop at the same position.
          min_start = match_start
          let consuming = match_end > start
          pop_would_loop = check_pop_loop &&
            !consuming &&
            match_pat.operation is Pop
          let push_too_deep = match_pat.operation is Push(_) &&
            self.stack.length() >= 100
          if push_too_deep {
            return None
          }
          best_match = Some({
            regions: match_region,
            context: pat_context,
            pat_index,
            from_with_prototype: from_with_proto,
            would_loop: pop_would_loop,
          })
          if match_start == start && !pop_would_loop {
            // We're not gonna find a better match after this, so as an
            // optimization we can stop matching now.
            return best_match
          }
        }
      }
    }
  }
  best_match
}

///|
fn ParseState::search(
  self : ParseState,
  line : SearchText,
  start : Int,
  match_pat : MatchPattern,
  captures : (Region, ByteIndex)?,
  search_cache : Map[Int, Region?],
  regions : Region,
) -> Region? {
  let match_ptr = match_pat.id
  if search_cache.get(match_ptr) is Some(maybe_region) {
    match maybe_region {
      Some(region) => {
        let match_start = region.pos(0).unwrap().0
        if match_start >= start {
          // Cached match is valid, return it. Otherwise do another search
          // below.
          return Some(region.clone())
        }
      }
      // Didn't find a match earlier, so no point trying to match it again
      None => return None
    }
  }
  let (regex, can_cache) = match (match_pat.has_captures, captures) {
    (true, Some(captures)) => {
      let (region, s) = captures
      (match_pat.regex_with_refs(region, s), false)
    }
    _ => (match_pat.regex(), true)
  }
  let matched = regex.search_text(line, start, line.len(), Some(regions))
  if matched {
    let (match_start, match_end) = regions.pos(0).unwrap()
    // this is necessary to avoid infinite looping on dumb patterns
    let does_something = match match_pat.operation {
      None => match_start != match_end
      Push(_) => self.stack.length() < 100
      _ => true
    }
    if can_cache && does_something {
      search_cache[match_ptr] = Some(regions.clone())
    }
    if does_something {
      return Some(regions.clone())
    }
  } else if can_cache {
    search_cache[match_ptr] = None
  }
  None
}

///|
/// Returns true if the stack was changed
fn ParseState::exec_pattern(
  self : ParseState,
  line : SearchText,
  reg_match : RegexMatch,
  level_context : Context,
  syntax_set : SyntaxSet,
  ops : Array[(Int, ScopeStackOp)],
) -> Bool raise ParsingError {
  let (match_start, match_end) = reg_match.regions.pos(0).unwrap()
  let context = reg_match.context
  let pat = context.match_at(reg_match.pat_index)
  self.push_meta_ops(
    true,
    match_start,
    level_context,
    pat.operation,
    syntax_set,
    ops,
  )
  for s in pat.scope {
    ops.push((match_start, ScopeStackOp::Push(s)))
  }
  if pat.captures is Some(capture_map) {
    // captures could appear in an arbitrary order, have to produce ops in
    // right order ex: ((bob)|(hi))* could match hibob in wrong order, and
    // outer has to push first we don't have to handle a capture matching
    // multiple times, Sublime doesn't
    let map : Array[((Int, Int), ScopeStackOp)] = []
    for entry in capture_map {
      let (cap_index, scopes) = entry
      if reg_match.regions.pos(cap_index) is Some((cap_start, cap_end)) {
        // marking up empty captures causes pops to be sorted wrong
        if cap_start == cap_end {
          continue
        }
        for scope in scopes {
          map.push(((cap_start, -(cap_end - cap_start)), ScopeStackOp::Push(scope)))
        }
        map.push(((cap_end, @int.min_value), ScopeStackOp::Pop(scopes.length())))
      }
    }
    let map = stable_sort_by(map, (a, b) => a.0.compare(b.0))
    for entry in map {
      let ((index, _), op) = entry
      ops.push((index, op))
    }
  }
  if !pat.scope.is_empty() {
    ops.push((match_end, ScopeStackOp::Pop(pat.scope.length())))
  }
  self.push_meta_ops(
    false,
    match_end,
    level_context,
    pat.operation,
    syntax_set,
    ops,
  )
  self.perform_op(line, reg_match.regions, pat, syntax_set)
}

///|
fn ParseState::push_meta_ops(
  _self : ParseState,
  initial : Bool,
  index : Int,
  cur_context : Context,
  match_op : MatchOperation,
  syntax_set : SyntaxSet,
  ops : Array[(Int, ScopeStackOp)],
) -> Unit raise ParsingError {
  match match_op {
    Pop => {
      let v = if initial {
        cur_context.meta_content_scope
      } else {
        cur_context.meta_scope
      }
      if !v.is_empty() {
        ops.push((index, ScopeStackOp::Pop(v.length())))
      }

      // cleared scopes are restored after the scopes from match pattern that
      // invoked the pop are applied
      if !initial && cur_context.clear_scopes is Some(_) {
        ops.push((index, ScopeStackOp::Restore))
      }
    }
    // for some reason the ST3 behaviour of set is convoluted and is
    // inconsistent with the docs and other ops
    // - the meta_content_scope of the current context is applied to the
    //   matched thing, unlike pop
    // - the clear_scopes are applied after the matched token, unlike push
    // - the interaction with meta scopes means that the token has the meta
    //   scopes of both the current scope and the new scope.
    Push(context_refs) | Set(context_refs) => {
      let is_set = match_op is Set(_)
      // a match pattern that "set"s keeps the meta_content_scope and
      // meta_scope from the previous context
      if initial {
        if is_set && cur_context.clear_scopes is Some(_) {
          // cleared scopes from the old context are restored immediately
          ops.push((index, ScopeStackOp::Restore))
        }
        // add each context's meta scope
        for r in context_refs {
          let ctx = r.resolve(syntax_set)
          if !is_set {
            if ctx.clear_scopes is Some(clear_amount) {
              ops.push((index, ScopeStackOp::Clear(clear_amount)))
            }
          }
          for scope in ctx.meta_scope {
            ops.push((index, ScopeStackOp::Push(scope)))
          }
        }
      } else {
        let repush = (is_set &&
          (
            !cur_context.meta_scope.is_empty() ||
            !cur_context.meta_content_scope.is_empty()
          )) ||
          context_refs
          .iter()
          .any(r => {
            let ctx = r.resolve(syntax_set) catch {
              _ => abort("unwrap on unresolved context reference")
            }
            !ctx.meta_content_scope.is_empty() ||
            (ctx.clear_scopes is Some(_) && is_set)
          })
        if repush {
          // remove previously pushed meta scopes, so that meta content
          // scopes will be applied in the correct order
          let mut num_to_pop = 0
          for r in context_refs {
            let ctx = r.resolve(syntax_set) catch {
              _ => abort("unwrap on unresolved context reference")
            }
            num_to_pop += ctx.meta_scope.length()
          }

          // also pop off the original context's meta scopes
          if is_set {
            num_to_pop += cur_context.meta_content_scope.length() +
              cur_context.meta_scope.length()
          }

          // do all the popping as one operation
          if num_to_pop > 0 {
            ops.push((index, ScopeStackOp::Pop(num_to_pop)))
          }

          // now we push meta scope and meta context scope for each context
          // pushed
          for r in context_refs {
            let ctx = r.resolve(syntax_set)

            // for some reason, contrary to my reading of the docs, set does
            // this after the token
            if is_set {
              if ctx.clear_scopes is Some(clear_amount) {
                ops.push((index, ScopeStackOp::Clear(clear_amount)))
              }
            }
            for scope in ctx.meta_scope {
              ops.push((index, ScopeStackOp::Push(scope)))
            }
            for scope in ctx.meta_content_scope {
              ops.push((index, ScopeStackOp::Push(scope)))
            }
          }
        }
      }
    }
    None => ()
  }
}

///|
/// Returns true if the stack was changed
fn ParseState::perform_op(
  self : ParseState,
  line : SearchText,
  regions : Region,
  pat : MatchPattern,
  syntax_set : SyntaxSet,
) -> Bool raise ParsingError {
  let (ctx_refs, old_proto_ids) : (Array[ContextReference], Array[ContextId]?) = match
    pat.operation {
    Push(ctx_refs) => (ctx_refs, None)
    Set(ctx_refs) =>
      // a `with_prototype` stays active when the context is `set` until the
      // context layer in the stack (where the `with_prototype` was initially
      // applied) is popped off.
      (ctx_refs, self.stack.pop().map(s => s.prototypes))
    Pop => {
      self.stack.pop() |> ignore
      return true
    }
    None => return false
  }
  for i, r in ctx_refs {
    let proto_ids = if i == 0 {
      // it is only necessary to preserve the old prototypes at the first
      // stack frame pushed
      match old_proto_ids {
        Some(ids) => ids.copy()
        None => []
      }
    } else {
      []
    }
    if i == ctx_refs.length() - 1 {
      // if a with_prototype was specified, and multiple contexts were
      // pushed, then the with_prototype applies only to the last context
      // pushed, i.e. top most on the stack after all the contexts are
      // pushed - this is also referred to as the "target" of the push by
      // sublimehq - see https://forum.sublimetext.com/t/dev-build-3111/19240/17
      // for more info
      if pat.with_prototype is Some(p) {
        proto_ids.push(p.id())
      }
    }
    let context_id = r.id()
    let context = syntax_set.get_context(context_id)
    let captures = {
      let mut uses_backrefs = context.uses_backrefs
      if !proto_ids.is_empty() {
        uses_backrefs = uses_backrefs ||
          proto_ids
          .iter()
          .any(id => {
            let ctx = syntax_set.get_context(id) catch {
              _ => abort("unwrap on missing context")
            }
            ctx.uses_backrefs
          })
      }
      if uses_backrefs {
        Some((regions.clone(), line.text()))
      } else {
        None
      }
    }
    self.stack.push({ context: context_id, prototypes: proto_ids, captures })
  }
  true
}
