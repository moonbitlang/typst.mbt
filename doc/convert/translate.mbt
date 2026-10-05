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
  baseline? : Bool = false,
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
  }
  let source_bytes = @syntax.utf8_len(text)
  // A tree with errors is never translated: the accessors of the AST
  // return placeholders for it, and its diagnostics are the front end's.
  let forced = if baseline {
    Some("baseline")
  } else if has_errors(root) {
    Some("syntax-error")
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
/// A child of a markup stream: the syntax nodes `start..end` of the
/// container and what they are.
priv struct Item {
  start : Int
  end : Int
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
      items.push({ start: i, end: i + 2, kind: item_kind, })
      was_stmt = children[i + 1].kind().is_stmt()
      i += 2
      continue
    }
    if kind is (SpaceNoNewline | SpaceWithNewline) {
      // A newline directly after a statement without a semicolon is no
      // expression.
      if !was_stmt {
        items.push({
          start: i,
          end: i + 1,
          kind: ISpace(kind is SpaceWithNewline),
        })
      } else {
        items.push({ start: i, end: i + 1, kind: ITrivia, })
      }
    } else {
      match @ast.Expr::from_untyped(node) {
        Some(expr) =>
          items.push({ start: i, end: i + 1, kind: IExpr(expr, false), })
        None => items.push({ start: i, end: i + 1, kind: ITrivia, })
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
        Stmt(_) => true
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
  for index, item in items {
    match item.kind {
      ITrivia => ()
      ISpace(newline) =>
        ops.push(
          Push({
            code: if newline {
              "Space::newline()"
            } else {
              "Space()"
            },
            total: true,
          }),
        )
      IExpr(expr, embedded) => {
        let mark = self.mark()
        // Text that a label follows gets a location of its own.
        let labelled = labelled_at(items, index)
        let result : Result[Array[Op], String] = try
          self.item(expr, env, labelled)
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
/// Whether the item at `index` is followed by a label (with only spaces
/// between): the evaluator attaches the label to it.
fn labelled_at(items : Array[Item], index : Int) -> Bool {
  for j in (index + 1)..<items.length() {
    match items[j].kind {
      ISpace(_) | ITrivia => continue
      IExpr(Label(_), _) => return true
      IExpr(Parbreak(_), _) => continue
      _ => return false
    }
  }
  false
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
  match self.names.get(base) {
    None => {
      self.names[base] = 1
      base
    }
    Some(count) => {
      self.names[base] = count + 1
      "\{base}_\{count + 1}"
    }
  }
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
/// each to a fresh variable, so they can stand first.)
fn Tr::emit(
  self : Tr,
  ops : Array[Op],
  ctor : String,
  suffix : String,
) -> String {
  ignore(self)
  let lets : Array[String] = []
  let pushes : Array[String] = []
  for op in ops {
    match op {
      Push(code) => pushes.push(code.code)
      Stmt(code) => lets.push(code)
    }
  }
  let call = ctor + "([" + pushes.join(", ") + "]" + suffix + ")"
  if lets.is_empty() {
    call
  } else if ctor == "Document" {
    lets.join("\n") + "\n" + call
  } else {
    "{\n" + lets.join("\n") + "\n" + call + "\n}"
  }
}
