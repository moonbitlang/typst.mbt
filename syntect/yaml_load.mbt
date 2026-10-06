// Port of `syntect/src/parsing/yaml_load.rs` (`.sublime-syntax` loading),
// on top of the port of `yaml-rust` 0.4.5 in `data/yaml_rust`.

///|
/// An error that occurred while parsing a syntax.
pub(all) suberror ParseSyntaxError {
  /// Invalid YAML file syntax, or at least something yaml_rust can't handle
  InvalidYaml(@yaml_rust.ScanError)
  /// The file must contain at least one YAML document
  EmptyFile
  /// Some keys are required for something to be a valid `.sublime-syntax`
  MissingMandatoryKey(String)
  /// Invalid regex (the regex and the error's message)
  RegexCompileError(String, String)
  /// A scope that syntect's scope implementation can't handle
  InvalidScope(ParseScopeError)
  /// A reference to another file that is invalid
  BadFileRef
  /// Syntaxes must have a context named "main"
  MainMissing
  /// Some part of the YAML file is the wrong type (e.g a string but should be
  /// a list) Sorry this doesn't give you any way to narrow down where this
  /// is. Maybe use Sublime Text to figure it out.
  TypeMismatch
}

///|
pub impl Show for ParseSyntaxError with fn output(self, logger) {
  match self {
    InvalidYaml(e) => logger.write_string("Invalid YAML file syntax: \{e}")
    EmptyFile =>
      logger.write_string("The file must contain at least one YAML document")
    MissingMandatoryKey(key) =>
      logger.write_string("Missing mandatory key in YAML file: \{key}")
    RegexCompileError(regex, error) =>
      logger.write_string("Error while compiling regex '\{regex}': \{error}")
    InvalidScope(e) => logger.write_string("Invalid scope: \{e}")
    BadFileRef => logger.write_string("Invalid file reference")
    MainMissing => logger.write_string("Context 'main' is missing")
    TypeMismatch => logger.write_string("Type mismatch")
  }
}

///|
fn[R] get_key(
  map : @yaml_rust.LinkedHashMap[@yaml_rust.Yaml, @yaml_rust.Yaml],
  key : String,
  f : (@yaml_rust.Yaml) -> R?,
) -> R raise ParseSyntaxError {
  match map.get(@yaml_rust.Yaml::String(key)) {
    None => raise MissingMandatoryKey(key)
    Some(x) =>
      match f(x) {
        Some(r) => r
        None => raise TypeMismatch
      }
  }
}

///|
/// `get_key(..).ok()`.
fn[R] try_key(
  map : @yaml_rust.LinkedHashMap[@yaml_rust.Yaml, @yaml_rust.Yaml],
  key : String,
  f : (@yaml_rust.Yaml) -> R?,
) -> R? {
  match map.get(@yaml_rust.Yaml::String(key)) {
    None => None
    Some(x) => f(x)
  }
}

///|
fn str_to_scopes(
  s : StringView,
  repo : ScopeRepository,
) -> Array[Scope] raise ParseSyntaxError {
  let out = []
  for scope in split_whitespace(s) {
    out.push(repo.build(scope) catch { e => raise InvalidScope(e) })
  }
  out
}

///|
priv struct ParserState {
  scope_repo : ScopeRepository
  variables : Map[String, String]
  variable_regex : Regex
  backref_regex : Regex
  lines_include_newline : Bool
}

///|
/// `__start` must not include prototypes from the actual syntax definition,
/// otherwise it's possible that a prototype makes us pop out of `__start`.
let start_context : String =
  #|
  #|__start:
  #|    - meta_include_prototype: false
  #|    - match: ''
  #|      push: __main
  #|__main:
  #|    - include: main
  #|

///|
/// In case you want to create your own SyntaxDefinition's in memory from
/// strings.
///
/// Generally you should use a [`SyntaxSet`].
///
/// `fallback_name` is an optional name to use when the YAML doesn't provide
/// a `name` key.
pub fn SyntaxDefinition::load_from_str(
  s : String,
  lines_include_newline : Bool,
  fallback_name : String?,
) -> SyntaxDefinition raise ParseSyntaxError {
  let docs = @yaml_rust.YamlLoader::load_from_str(s) catch {
    e => raise InvalidYaml(e)
  }
  if docs.is_empty() {
    raise EmptyFile
  }
  let doc = docs[0]
  parse_top_level(doc, scope_repo, lines_include_newline, fallback_name)
}

///|
fn parse_top_level(
  doc : @yaml_rust.Yaml,
  scope_repo : ScopeRepository,
  lines_include_newline : Bool,
  fallback_name : String?,
) -> SyntaxDefinition raise ParseSyntaxError {
  guard doc.as_hash() is Some(h) else { raise TypeMismatch }
  let variables = Map([])
  if try_key(h, "variables", x => x.as_hash()) is Some(map) {
    for entry in map.iter() {
      let (key, value) = entry
      if (key.as_str(), value.as_str()) is (Some(key_str), Some(val_str)) {
        variables[key_str] = val_str
      }
    }
  }
  let contexts_hash = get_key(h, "contexts", x => x.as_hash())
  let top_level_scope_str = get_key(h, "scope", x => x.as_str())
  let top_level_scope = scope_repo.build(top_level_scope_str) catch {
    e => raise InvalidScope(e)
  }
  let state : ParserState = {
    scope_repo,
    variables,
    variable_regex: Regex::new("\\{\\{([A-Za-z0-9_]+)\\}\\}"),
    backref_regex: Regex::new("\\\\\\d"),
    lines_include_newline,
  }
  let contexts = parse_contexts(contexts_hash, state)
  if !contexts.contains("main") {
    raise MainMissing
  }
  add_initial_contexts(contexts, state, top_level_scope)
  let file_extensions = []
  for extension_key in ["file_extensions", "hidden_file_extensions"] {
    if try_key(h, extension_key, x => x.as_vec()) is Some(v) {
      for y in v {
        if y.as_str() is Some(s) {
          file_extensions.push(s)
        }
      }
    }
  }
  {
    name: try_key(h, "name", x => x.as_str()).unwrap_or(
      fallback_name.unwrap_or("Unnamed"),
    ),
    scope: top_level_scope,
    file_extensions,
    first_line_match: try_key(h, "first_line_match", x => x.as_str()),
    hidden: try_key(h, "hidden", x => x.as_bool()).unwrap_or(false),
    variables: state.variables,
    contexts,
  }
}

///|
fn parse_contexts(
  map : @yaml_rust.LinkedHashMap[@yaml_rust.Yaml, @yaml_rust.Yaml],
  state : ParserState,
) -> Map[String, Context] raise ParseSyntaxError {
  let contexts = Map([])
  for entry in map.iter() {
    let (key, value) = entry
    if (key.as_str(), value.as_vec()) is (Some(name), Some(val_vec)) {
      let is_prototype = name == "prototype"
      let namer = ContextNamer::new(name)
      parse_context(val_vec, state, contexts, is_prototype, namer) |> ignore
    }
  }
  contexts
}

///|
fn parse_context(
  vec : Array[@yaml_rust.Yaml],
  state : ParserState,
  contexts : Map[String, Context],
  is_prototype : Bool,
  namer : ContextNamer,
) -> String raise ParseSyntaxError {
  let context = Context::new(!is_prototype)
  let name = namer.next()
  for y in vec {
    guard y.as_hash() is Some(map) else { raise TypeMismatch }
    let mut is_special = false
    if try_key(map, "meta_scope", x => x.as_str()) is Some(x) {
      context.meta_scope = str_to_scopes(x, state.scope_repo)
      is_special = true
    }
    if try_key(map, "meta_content_scope", x => x.as_str()) is Some(x) {
      context.meta_content_scope = str_to_scopes(x, state.scope_repo)
      is_special = true
    }
    if try_key(map, "meta_include_prototype", x => x.as_bool()) is Some(x) {
      context.meta_include_prototype = x
      is_special = true
    }
    if try_key(map, "clear_scopes", x => x.as_bool()) is Some(true) {
      context.clear_scopes = Some(All)
      is_special = true
    }
    if try_key(map, "clear_scopes", x => x.as_i64()) is Some(x) {
      context.clear_scopes = Some(TopN(x.to_int()))
      is_special = true
    }
    if !is_special {
      if try_key(map, "include", x => Some(x)) is Some(x) {
        let reference = parse_reference(x, state, contexts, namer, false)
        context.patterns.push(Include(reference))
      } else {
        let pattern = parse_match_pattern(map, state, contexts, namer)
        if pattern.has_captures {
          context.uses_backrefs = true
        }
        context.patterns.push(Match(pattern))
      }
    }
  }
  contexts[name] = context
  name
}

///|
fn parse_reference(
  y : @yaml_rust.Yaml,
  state : ParserState,
  contexts : Map[String, Context],
  namer : ContextNamer,
  with_escape : Bool,
) -> ContextReference raise ParseSyntaxError {
  if y.as_str() is Some(s) {
    let parts = s.split("#").map(p => p.to_owned()).collect()
    let sub_context = if parts.length() > 1 { Some(parts[1]) } else { None }
    if parts[0].has_prefix("scope:") {
      let scope = state.scope_repo.build(
        parts[0].unsafe_substring(start=6, end=parts[0].length()),
      ) catch {
        e => raise InvalidScope(e)
      }
      ByScope(scope~, sub_context~, with_escape~)
    } else if parts[0].has_suffix(".sublime-syntax") {
      guard file_stem(parts[0]) is Some(stem) else { raise BadFileRef }
      File(name=stem, sub_context~, with_escape~)
    } else {
      Named(parts[0])
    }
  } else if y.as_vec() is Some(v) {
    let subname = parse_context(v, state, contexts, false, namer)
    Inline(subname)
  } else {
    raise TypeMismatch
  }
}

///|
/// `Path::new(s).file_stem()`.
fn file_stem(path : String) -> String? {
  // The file name: the last non-empty component.
  let components = path
    .split("/")
    .filter(c => !c.is_empty() && c != ".")
    .map(c => c.to_owned())
    .collect()
  guard components.last() is Some(name) else { return None }
  if name == ".." {
    return None
  }
  // `file_stem` of `.foo` is `.foo`; otherwise strip the last extension.
  match name.rev_find(".") {
    Some(0) | None => Some(name)
    Some(i) => Some(name.unsafe_substring(start=0, end=i))
  }
}

///|
fn parse_match_pattern(
  map : @yaml_rust.LinkedHashMap[@yaml_rust.Yaml, @yaml_rust.Yaml],
  state : ParserState,
  contexts : Map[String, Context],
  namer : ContextNamer,
) -> MatchPattern raise ParseSyntaxError {
  let raw_regex = get_key(map, "match", x => x.as_str())
  let regex_str = parse_regex(raw_regex, state)
  let scope = match try_key(map, "scope", x => x.as_str()) {
    Some(s) => str_to_scopes(s, state.scope_repo)
    None => []
  }
  let captures = if try_key(map, "captures", x => x.as_hash()) is Some(map) {
    Some(parse_captures(map, regex_str, state))
  } else {
    None
  }
  let mut has_captures = false
  let operation : MatchOperation = if try_key(map, "pop", x => Some(x))
    is Some(_) {
    // Thanks @wbond for letting me know this is the correct way to check for
    // captures
    let text = ByteIndex::new(regex_str)
    has_captures = state.backref_regex.search(text, 0, text.len(), None)
    Pop
  } else if try_key(map, "push", x => Some(x)) is Some(y) {
    Push(parse_pushargs(y, state, contexts, namer))
  } else if try_key(map, "set", x => Some(x)) is Some(y) {
    Set(parse_pushargs(y, state, contexts, namer))
  } else if try_key(map, "embed", x => Some(x)) is Some(y) {
    // Same as push so we translate it to what it would be
    let embed_escape_context_yaml = []
    let mut commands = @yaml_rust.new_hash()
    commands.insert(
      @yaml_rust.Yaml::String("meta_include_prototype"),
      @yaml_rust.Yaml::Boolean(false),
    )
    |> ignore
    embed_escape_context_yaml.push(@yaml_rust.Yaml::Hash(commands))
    if try_key(map, "embed_scope", x => Some(x)) is Some(s) {
      commands = @yaml_rust.new_hash()
      commands.insert(@yaml_rust.Yaml::String("meta_content_scope"), s)
      |> ignore
      embed_escape_context_yaml.push(@yaml_rust.Yaml::Hash(commands))
    }
    if try_key(map, "escape", x => Some(x)) is Some(v) {
      let match_map = @yaml_rust.new_hash()
      match_map.insert(@yaml_rust.Yaml::String("match"), v) |> ignore
      match_map.insert(
        @yaml_rust.Yaml::String("pop"),
        @yaml_rust.Yaml::Boolean(true),
      )
      |> ignore
      if try_key(map, "escape_captures", x => Some(x)) is Some(y) {
        match_map.insert(@yaml_rust.Yaml::String("captures"), y) |> ignore
      }
      embed_escape_context_yaml.push(@yaml_rust.Yaml::Hash(match_map))
      let escape_context = parse_context(
        embed_escape_context_yaml, state, contexts, false, namer,
      )
      Push([
        Inline(escape_context),
        parse_reference(y, state, contexts, namer, true),
      ])
    } else {
      raise MissingMandatoryKey("escape")
    }
  } else {
    None
  }
  let with_prototype = if try_key(map, "with_prototype", x => x.as_vec())
    is Some(v) {
    // should a with_prototype include the prototype? I don't think so.
    let subname = parse_context(v, state, contexts, true, namer)
    Some(ContextReference::Inline(subname))
  } else if try_key(map, "escape", x => Some(x)) is Some(v) {
    let subname = namer.next()
    let context = Context::new(false)
    let match_map = @yaml_rust.new_hash()
    let v_str = match v.as_str() {
      Some(s) => s
      None => abort("called `Option::unwrap()` on a `None` value")
    }
    match_map.insert(
      @yaml_rust.Yaml::String("match"),
      @yaml_rust.Yaml::String("(?=\{v_str})"),
    )
    |> ignore
    match_map.insert(
      @yaml_rust.Yaml::String("pop"),
      @yaml_rust.Yaml::Boolean(true),
    )
    |> ignore
    let pattern = parse_match_pattern(match_map, state, contexts, namer)
    if pattern.has_captures {
      context.uses_backrefs = true
    }
    context.patterns.push(Match(pattern))
    contexts[subname] = context
    Some(ContextReference::Inline(subname))
  } else {
    None
  }
  MatchPattern::new(
    has_captures, regex_str, scope, captures, operation, with_prototype,
  )
}

///|
fn parse_pushargs(
  y : @yaml_rust.Yaml,
  state : ParserState,
  contexts : Map[String, Context],
  namer : ContextNamer,
) -> Array[ContextReference] raise ParseSyntaxError {
  // check for a push of multiple items
  let multiple = match y.as_vec() {
    Some(v) =>
      !v.is_empty() &&
      (
        v[0].as_str() is Some(_) ||
        (match v[0].as_vec() {
          Some(inner) =>
            match inner.get(0) {
              Some(first) => first.as_hash() is Some(_)
              None =>
                abort("index out of bounds: the len is 0 but the index is 0")
            }
          None => false
        })
      )
    None => false
  }
  if multiple {
    let out = []
    for x in y.as_vec().unwrap() {
      out.push(parse_reference(x, state, contexts, namer, false))
    }
    out
  } else {
    let reference = parse_reference(y, state, contexts, namer, false)
    [reference]
  }
}

///|
fn parse_regex(
  raw_regex : String,
  state : ParserState,
) -> String raise ParseSyntaxError {
  let regex = resolve_variables(raw_regex, state)
  let regex = replace_posix_char_classes(regex)
  let regex = if state.lines_include_newline {
    regex_for_newlines(regex)
  } else {
    // If the passed in strings don't include newlines (unlike Sublime) we
    // can't match on them using the original regex. So this tries to rewrite
    // the regex in a way that allows matching against lines without newlines
    // (essentially replacing `\n` with `$`).
    regex_for_no_newlines(regex)
  }
  try_compile_regex(regex)
  regex
}

///|
fn resolve_variables(raw_regex : String, state : ParserState) -> String {
  let result = StringBuilder()
  let text = ByteIndex::new(raw_regex)
  let mut index = 0
  let region = Region::new()
  while state.variable_regex.search(text, index, text.len(), Some(region)) {
    let (begin, end) = region.pos(0).unwrap()
    result.write_string(text.slice(index, begin))
    let var_pos = region.pos(1).unwrap()
    let var_name = text.slice(var_pos.0, var_pos.1)
    let var_raw = state.variables.get(var_name).unwrap_or("")
    let var_resolved = resolve_variables(var_raw, state)
    result.write_string(var_resolved)
    index = end
  }
  if index < text.len() {
    result.write_string(text.slice(index, text.len()))
  }
  result.to_string()
}

///|
fn try_compile_regex(regex_str : String) -> Unit raise ParseSyntaxError {
  // Replace backreferences with a placeholder value that will also appear
  // in errors
  let regex_str = substitute_backrefs_in_regex(regex_str, i => {
    Some("<placeholder_\{i}>")
  })
  if Regex::try_compile(regex_str) is Some(error) {
    raise RegexCompileError(regex_str, error)
  }
}

///|
fn parse_captures(
  map : @yaml_rust.LinkedHashMap[@yaml_rust.Yaml, @yaml_rust.Yaml],
  regex_str : String,
  state : ParserState,
) -> CaptureMapping raise ParseSyntaxError {
  let valid_indexes = get_consuming_capture_indexes(regex_str)
  let captures = []
  for entry in map.iter() {
    let (key, value) = entry
    if (key.as_i64(), value.as_str()) is (Some(key_int), Some(val_str)) {
      // `key_int as usize`: negative keys wrap around and never match.
      if key_int >= 0L && valid_indexes.contains(key_int.to_int()) {
        captures.push(
          (key_int.to_int(), str_to_scopes(val_str, state.scope_repo)),
        )
      }
    }
  }
  captures
}

///|
/// Sublime treats the top level context slightly differently from including
/// the main context from other syntaxes. When main is popped it is
/// immediately re-added and when it is `set` over the file level scope
/// remains. This behaviour is emulated through some added contexts that are
/// the actual top level contexts used in parsing. See
/// <https://github.com/trishume/syntect/issues/58> for more.
fn add_initial_contexts(
  contexts : Map[String, Context],
  state : ParserState,
  top_level_scope : Scope,
) -> Unit raise ParseSyntaxError {
  let yaml_docs = @yaml_rust.YamlLoader::load_from_str(start_context) catch {
    _ => abort("start context")
  }
  let yaml = yaml_docs[0]
  let start_yaml = yaml
    .as_hash()
    .unwrap()
    .get(@yaml_rust.Yaml::String("__start"))
    .unwrap()
    .as_vec()
    .unwrap()
  parse_context(
    start_yaml,
    state,
    contexts,
    false,
    ContextNamer::new("__start"),
  )
  |> ignore
  if contexts.get("__start") is Some(start) {
    start.meta_content_scope = [top_level_scope]
  }
  let main_yaml = yaml
    .as_hash()
    .unwrap()
    .get(@yaml_rust.Yaml::String("__main"))
    .unwrap()
    .as_vec()
    .unwrap()
  parse_context(main_yaml, state, contexts, false, ContextNamer::new("__main"))
  |> ignore
  let main = contexts["main"]
  let meta_include_prototype = main.meta_include_prototype
  let meta_scope = main.meta_scope.copy()
  let meta_content_scope = main.meta_content_scope.copy()
  if contexts.get("__main") is Some(outer_main) {
    outer_main.meta_include_prototype = meta_include_prototype
    outer_main.meta_scope = meta_scope
    outer_main.meta_content_scope = meta_content_scope
  }

  // add the top_level_scope as a meta_content_scope to main so pushes from
  // other syntaxes add the file scope
  // TODO: this order is not quite correct if main also has a meta_scope
  if contexts.get("main") is Some(main) {
    main.meta_content_scope = [top_level_scope, ..main.meta_content_scope]
  }
}

///|
priv struct ContextNamer {
  name : String
  mut anonymous_index : Int?
}

///|
fn ContextNamer::new(name : String) -> ContextNamer {
  { name, anonymous_index: None, }
}

///|
fn ContextNamer::next(self : ContextNamer) -> String {
  let name = match self.anonymous_index {
    Some(index) => "#anon_\{self.name}_\{index}"
    None => self.name
  }
  self.anonymous_index = Some(
    match self.anonymous_index {
      Some(i) => i + 1
      None => 0
    },
  )
  name
}

///|
/// In fancy-regex, POSIX character classes only match ASCII characters.
///
/// Sublime's syntaxes expect them to match Unicode characters as well, so
/// transform them to corresponding Unicode character classes.
fn replace_posix_char_classes(regex : String) -> String {
  regex
  .replace_all(old="[:alpha:]", new="\\p{L}")
  .replace_all(old="[:alnum:]", new="\\p{L}\\p{N}")
  .replace_all(old="[:lower:]", new="\\p{Ll}")
  .replace_all(old="[:upper:]", new="\\p{Lu}")
  .replace_all(old="[:digit:]", new="\\p{Nd}")
}

///|
/// Some of the regexes include `$` and expect it to match end of line, e.g.
/// *before* the `\n` in `test\n`.
///
/// In fancy-regex, `$` means end of text by default, so that would match
/// *after* `\n`. Using `(?m:$)` instead means it matches end of line.
fn regex_for_newlines(regex : String) -> String {
  if !regex.contains("$") {
    return regex
  }
  let parser = RegexScanner::new(regex)
  let result : Array[Byte] = []
  while parser.peek() is Some(c) {
    match c {
      b'$' => {
        parser.next()
        result.push_iter(@utf8.encode("(?m:$)").iter())
      }
      b'\\' => {
        parser.next()
        result.push(c)
        if parser.peek() is Some(c2) {
          parser.next()
          result.push(c2)
        }
      }
      b'[' => {
        let (content, _) = parser.parse_character_class()
        result.push_iter(content.iter())
      }
      _ => {
        parser.next()
        result.push(c)
      }
    }
  }
  utf8_decode(result)
}

///|
/// Rewrite a regex that matches `\n` to one that matches `$` (end of line)
/// instead. That allows the regex to be used to match lines that don't
/// include a trailing newline character.
///
/// The reason we're doing this is because the regexes in the syntax
/// definitions assume that the lines that are being matched on include a
/// trailing newline.
///
/// Note that the rewrite is just an approximation and there's a couple of
/// cases it can not handle, due to `$` being an anchor whereas `\n` matches
/// a character.
fn regex_for_no_newlines(regex : String) -> String {
  if !regex.contains("\\n") {
    return regex
  }

  // A special fix to rewrite a pattern from the `Rd` syntax that the
  // RegexRewriter can not handle properly.
  let regex = regex.replace_all(old="(?:\\n)?", new="(?:$|)")
  let parser = RegexScanner::new(regex)
  let result : Array[Byte] = []
  while parser.peek() is Some(c) {
    match c {
      b'\\' => {
        parser.next()
        if parser.peek() is Some(c2) {
          parser.next()
          // Replacing `\n` with `$` in `\n?` or `\n+` would make parsing
          // later fail with "target of repeat operator is invalid"
          let c3 = parser.peek()
          if c2 == b'n' &&
            c3 != Some(b'?') &&
            c3 != Some(b'+') &&
            c3 != Some(b'*') {
            result.push(b'$')
          } else {
            result.push(c)
            result.push(c2)
          }
        } else {
          result.push(c)
        }
      }
      b'[' => {
        let (content, matches_newline) = parser.parse_character_class()
        if matches_newline && parser.peek() != Some(b'?') {
          result.push_iter(@utf8.encode("(?:").iter())
          result.push_iter(content.iter())
          result.push_iter(@utf8.encode("|$)").iter())
        } else {
          result.push_iter(content.iter())
        }
      }
      _ => {
        parser.next()
        result.push(c)
      }
    }
  }
  utf8_decode(result)
}

///|
/// Find capture groups which are not inside lookarounds.
///
/// If, in a YAML syntax definition, a scope stack is applied to a capture
/// group inside a lookaround, (i.e. "captures:\n x: scope.stack goes.here",
/// where "x" is the number of a capture group in a lookahead/behind), those
/// those scopes are not applied, so no need to even parse them.
fn get_consuming_capture_indexes(regex : String) -> Array[Int] {
  let parser = RegexScanner::new(regex)
  let result : Array[Int] = []
  let stack = []
  let mut cap_num = 0
  let mut in_lookaround = false
  stack.push(in_lookaround)
  result.push(cap_num)
  while parser.peek() is Some(c) {
    match c {
      b'\\' => {
        parser.next()
        parser.next()
      }
      b'[' => parser.parse_character_class() |> ignore
      b'(' => {
        parser.next()
        // add the current lookaround state to the stack so we can just pop
        // at a closing paren
        stack.push(in_lookaround)
        if parser.peek() is Some(c2) {
          if c2 != b'?' {
            // simple numbered capture group
            cap_num += 1
            // if we are not currently in a lookaround, add this capture
            // group number to the valid ones
            if !in_lookaround {
              result.push(cap_num)
            }
          } else {
            parser.next()
            if parser.peek() is Some(c3) {
              parser.next()
              if c3 == b'=' || c3 == b'!' {
                // lookahead
                in_lookaround = true
              } else if c3 == b'<' {
                if parser.peek() is Some(c4) {
                  if c4 == b'=' || c4 == b'!' {
                    parser.next()
                    // lookbehind
                    in_lookaround = true
                  }
                }
              } else if c3 == b'P' {
                if parser.peek() is Some(c4) {
                  if c4 == b'<' {
                    // named capture group
                    cap_num += 1
                    // if we are not currently in a lookaround, add this
                    // capture group number to the valid ones
                    if !in_lookaround {
                      result.push(cap_num)
                    }
                  }
                }
              }
            }
          }
        }
      }
      b')' => {
        if stack.pop() is Some(value) {
          in_lookaround = value
        }
        parser.next()
      }
      _ => parser.next()
    }
  }
  result
}

///|
/// A byte scanner over a regex (upstream `Parser`).
priv struct RegexScanner {
  bytes : Bytes
  mut index : Int
}

///|
fn RegexScanner::new(s : String) -> RegexScanner {
  { bytes: @utf8.encode(s), index: 0, }
}

///|
fn RegexScanner::peek(self : RegexScanner) -> Byte? {
  self.bytes.get(self.index)
}

///|
fn RegexScanner::next(self : RegexScanner) -> Unit {
  self.index += 1
}

///|
fn RegexScanner::parse_character_class(
  self : RegexScanner,
) -> (Array[Byte], Bool) {
  let content = []
  let mut negated = false
  let mut nesting = 0
  let mut matches_newline = false
  self.next()
  content.push(b'[')
  if self.peek() is Some(b'^') {
    self.next()
    content.push(b'^')
    negated = true
  }

  // An unescaped `]` is allowed after `[` or `[^` and doesn't mean the end
  // of the class.
  if self.peek() is Some(b']') {
    self.next()
    content.push(b']')
  }
  while self.peek() is Some(c) {
    match c {
      b'\\' => {
        self.next()
        content.push(c)
        if self.peek() is Some(c2) {
          self.next()
          if c2 == b'n' && !negated && nesting == 0 {
            matches_newline = true
          }
          content.push(c2)
        }
      }
      b'[' => {
        self.next()
        content.push(b'[')
        nesting += 1
      }
      b']' => {
        self.next()
        content.push(b']')
        if nesting == 0 {
          break
        }
        nesting -= 1
      }
      _ => {
        self.next()
        content.push(c)
      }
    }
  }
  (content, matches_newline)
}

///|
fn utf8_decode(bytes : Array[Byte]) -> String {
  @utf8.decode_lossy(Bytes::from_array(bytes))
}
