// The translator's entry point and the translation of markup streams
// (docs/edsl-convert.md, sections 4.1 and 6).

///|
/// Translate a Typst document to MoonBit source that builds it with the
/// EDSL. `path` is the root-relative path of the source file
/// (`tests/suite/layout/grid.typ`); the document gets its directory, so
/// relative paths resolve alike. `library` decides what the global names
/// denote. With `baseline`, the whole document is one fragment.
pub fn translate(
  text : String,
  path : String,
  library : @library.Library,
  baseline~ : Bool = false,
  prose~ : Bool = false,
) -> Translation {
  let root = @syntax.parse(text)
  let dir = match path.rev_find("/") {
    Some(i) => path.view(end_offset=i).to_owned()
    None => ""
  }
  let dir_arg = if dir == "" { "" } else { ", dir=\{mbt_str(dir)}" }
  let tr : Tr = {
    lib: library,
    mutated: Map([]),
    fallbacks: [],
    hatch: false,
    math: false,
    fallback_bytes: 0,
    typed: 0,
    fresh: 0,
    names: Map([]),
    prose,
  }
  let source_bytes = @syntax.utf8_len(text)
  // A tree with errors or warnings is never translated: the accessors of
  // the AST return placeholders for errors, and the diagnostics are the
  // front end's.
  let (errors, warnings) = root.errors_and_warnings()
  let forced = if baseline {
    Some("baseline")
  } else if !errors.is_empty() || has_errors(root) {
    Some("syntax-error")
  } else if !warnings.is_empty() {
    Some("syntax-warning")
  } else {
    None
  }
  let body = match forced {
    Some(construct) => {
      let fragment = tr.markup_fragment(construct, "stream", text, [])
      "Document([\{fragment}]\{dir_arg})"
    }
    None => {
      mutated_names(root, tr.mutated)
      let ops = tr.stream_ops(root.children(), Env::new())
      tr.emit(ops, "Document", dir_arg)
    }
  }
  let tier = if !tr.fallbacks.is_empty() || tr.math {
    T3
  } else if tr.hatch {
    T2
  } else {
    T1
  }
  {
    body,
    tier,
    math_only: tr.fallbacks.is_empty() && tr.math,
    fallbacks: tr.fallbacks,
    source_bytes,
    fallback_bytes: tr.fallback_bytes,
    typed: tr.typed,
    note: "",
  }
}

///|
/// A child of a markup stream.
priv struct Item {
  kind : ItemKind
}

///|
priv enum ItemKind {
  /// An expression; whether it is embedded code (`#expr`).
  IExpr(@ast.Expr, Bool)
  /// Markup's space (`true`: with a newline).
  ISpace(Bool)
  /// Comments, terminators, delimiters.
  ITrivia
}

///|
/// Split the children of a markup node into items, like `Markup::exprs`.
fn items_of(children : ArrayView[@syntax.SyntaxNode]) -> Array[Item] {
  let items : Array[Item] = []
  let n = children.length()
  let mut i = 0
  let mut was_stmt = false
  while i < n {
    let node = children[i]
    let kind = node.kind()
    if kind is Hash && i + 1 < n {
      let item_kind = match @ast.Expr::from_untyped(children[i + 1]) {
        Some(expr) => IExpr(expr, true)
        None => ITrivia
      }
      items.push({ kind: item_kind, })
      was_stmt = children[i + 1].kind().is_stmt()
      i += 2
      continue
    }
    if kind is (SpaceNoNewline | SpaceWithNewline) {
      // A newline directly after a statement without a semicolon is no
      // expression.
      if !was_stmt {
        items.push({ kind: ISpace(kind is SpaceWithNewline), })
      } else {
        items.push({ kind: ITrivia, })
      }
    } else {
      match @ast.Expr::from_untyped(node) {
        Some(expr) => items.push({ kind: IExpr(expr, false), })
        None => items.push({ kind: ITrivia, })
      }
    }
    was_stmt = kind.is_stmt()
    i += 1
  }
  items
}

///|
/// The text of syntax nodes as it stands in the source.
fn text_of(nodes : ArrayView[@syntax.SyntaxNode]) -> String {
  let out = StringBuilder()
  for node in nodes {
    out.write_string(node.full_text())
  }
  out.to_string()
}

///|
/// Translate a markup stream (the children of a markup node): its typed
/// descriptions, or the whole stream as one fragment (section 6.2).
fn Tr::stream_ops(
  self : Tr,
  children : ArrayView[@syntax.SyntaxNode],
  env : Env,
) -> Array[Op] {
  let mark = self.mark()
  self.items(children, env.copy()) catch {
    Bail(construct) => {
      self.rollback(mark)
      let text = text_of(children)
      let scope = self.scope(children, env)
      [
        Push({
          code: self.markup_fragment(construct, "stream", text, scope),
          total: false,
        }),
      ]
    }
  }
}

///|
/// A markup stream as content: `Seq([..])`.
fn Tr::stream(self : Tr, markup : @ast.Markup, env : Env) -> Code {
  let ops = self.stream_ops(markup.to_untyped().children(), env)
  let total = ops
    .iter()
    .all(op => {
      match op {
        Push(code) => code.total
        Stmt(_) | Word(_) | Gap(_) | Break | Quote(_) => true
      }
    })
  { code: self.emit(ops, "Seq", ""), total, }
}

///|
/// Translate the items of a stream. `env` is updated with the bindings of
/// the stream.
fn Tr::items(
  self : Tr,
  children : ArrayView[@syntax.SyntaxNode],
  env : Env,
) -> Array[Op] raise Bail {
  let ops : Array[Op] = []
  let items = items_of(children)
  for item in items {
    match item.kind {
      ITrivia => ()
      ISpace(newline) => ops.push(Gap(newline))
      IExpr(expr, embedded) => {
        let mark = self.mark()
        let result : Result[Array[Op], String] = try
          self.item(expr, env)
        catch {
          Bail(construct) => Err(construct)
        } noraise {
          item_ops => Ok(item_ops)
        }
        match result {
          Ok(item_ops) => ops.append(item_ops)
          Err(construct) => {
            self.rollback(mark)
            // Section 6.1: an embedded expression that is no statement,
            // keeps its control flow and is proven not to be a label.
            let node = expr.to_untyped()
            if embedded &&
              !is_statement(expr) &&
              !escapes(node, false, false) &&
              self.not_label(expr, env) {
              let text = "#" + node.full_text()
              let scope = self.scope([node], env)
              ops.push(
                Push({
                  code: self.markup_fragment(construct, "item", text, scope),
                  total: false,
                }),
              )
            } else {
              raise Bail(construct)
            }
          }
        }
      }
    }
  }
  ops
}

///|
/// Statements: their bindings or rules reach beyond themselves, so they
/// are never fragments on their own.
fn is_statement(expr : @ast.Expr) -> Bool {
  match expr {
    LetBinding(_)
    | SetRule(_)
    | ShowRule(_)
    | ModuleImport(_)
    | DestructAssignment(_) => true
    Binary(binary) =>
      binary.op() is (Assign | AddAssign | SubAssign | MulAssign | DivAssign)
    _ => false
  }
}

///|
/// A fresh MoonBit variable for the Typst name `name`.
fn Tr::variable(self : Tr, name : String) -> String {
  let base = "v_" + name.replace_all(old="-", new="_")
  // Every emitted identifier is reserved: `a-b`, `a_b` and `a_b_2` must
  // not share one.
  let mut candidate = base
  let mut count = 1
  while self.names.contains(candidate) {
    count += 1
    candidate = "\{base}_\{count}"
  }
  self.names[candidate] = 1
  candidate
}

///|
/// Whether an emitted expression is a rule (only valid directly in a
/// sequence).
fn is_rule(code : String) -> Bool {
  code.has_prefix("Set") || code.has_prefix("Show")
}

///|
/// Emit a stream as an expression: `ctor([..]suffix)`, in a block with
/// the stream's `let`s before it if it has any. (The `let`s bind literals,
/// each to a fresh variable, so they can stand first.) In the readable
/// mode a stream that `Prose` expresses exactly is `Prose(..)`.
fn Tr::emit(
  self : Tr,
  ops : Array[Op],
  ctor : String,
  suffix : String,
) -> String {
  let lets : Array[String] = []
  let pushes : Array[String] = []
  match (if self.prose { self.prose_text(ops, lets) } else { None }) {
    Some(prose) => pushes.push(prose)
    None =>
      for op in ops {
        match op {
          Push(code) => pushes.push(code.code)
          Stmt(code) => lets.push(code)
          Word(text) => pushes.push("Lit(\{mbt_str(text)})")
          Gap(newline) =>
            pushes.push(if newline { "Space::newline()" } else { "Space()" })
          Break => pushes.push("Parbreak()")
          Quote(double) => pushes.push("Smartquote(double=\{double})")
        }
      }
  }
  // `Prose` is the sequence of its pieces: it stands for `Seq([..])`.
  let call = if ctor == "Seq" &&
    pushes is [single] &&
    single.has_prefix("Prose(") {
    single
  } else {
    ctor + "([" + pushes.join(", ") + "]" + suffix + ")"
  }
  if lets.is_empty() {
    call
  } else if ctor == "Document" {
    lets.join("\n") + "\n" + call
  } else {
    "{\n" + lets.join("\n") + "\n" + call + "\n}"
  }
}

///|
/// The stream as `Prose("..")`, if `Prose` splits that text into exactly
/// these pieces (docs/edsl-design.md, section 4.4): words separated by
/// white space, quotes, paragraph breaks and interpolated descriptions; no
/// rule or statement, no white space at the edges (which `Prose` drops)
/// and no two adjacent words (which `Prose` would join). Descriptions that
/// are not short are bound to variables (pushed to `lets`) and
/// interpolated by name.
fn Tr::prose_text(self : Tr, ops : Array[Op], lets : Array[String]) -> String? {
  guard !ops.is_empty() &&
    !(ops[0] is (Gap(_) | Break)) &&
    !(ops[ops.length() - 1] is (Gap(_) | Break)) else {
    return None
  }
  let mut words = 0
  for i, op in ops {
    match op {
      Stmt(_) => return None
      Push(code) => if is_rule(code.code) { return None }
      Word(text) => {
        words += 1
        if i > 0 && ops[i - 1] is Word(_) {
          return None
        }
        for c in text {
          if c == ' ' ||
            c == '\t' ||
            c == '\n' ||
            c == '\r' ||
            c == '"' ||
            c == '\'' ||
            c == '\u{FDD0}' ||
            c == '\u{FDD1}' {
            return None
          }
        }
      }
      Gap(_) => if i > 0 && ops[i - 1] is (Gap(_) | Break) { return None }
      Break => if i > 0 && ops[i - 1] is (Gap(_) | Break) { return None }
      Quote(_) => ()
    }
  }
  // Plain sequences of descriptions gain nothing.
  guard words > 0 else { return None }
  let text = StringBuilder()
  let bound : Array[String] = []
  for op in ops {
    match op {
      Word(word) => {
        let literal = mbt_str(word)
        text.write_string(
          literal.unsafe_substring(start=1, end=literal.length() - 1),
        )
      }
      Gap(newline) => text.write_string(if newline { "\\n" } else { " " })
      Break => text.write_string("\\n\\n")
      Quote(double) => text.write_string(if double { "\\\"" } else { "'" })
      // A view is interpolated as content (`Content(..)` erases its type).
      Push(code) if code.code.has_prefix("v_") =>
        text.write_string("\\{Content(" + code.code + ")}")
      Push(code) =>
        if code.code.length() <= 48 &&
          !code.code.contains("\\") &&
          !code.code.contains("\n") &&
          !code.code.contains("{") {
          text.write_string("\\{" + code.code + "}")
        } else {
          self.fresh += 1
          let name = "p\{self.fresh}"
          bound.push("let \{name} = \{code.code}")
          text.write_string("\\{" + name + "}")
        }
      Stmt(_) => ()
    }
  }
  lets.append(bound)
  Some("Prose(\"" + text.to_string() + "\")")
}
