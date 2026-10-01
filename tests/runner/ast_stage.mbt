// The `ast` stage: mirrors `oracle/src/ast_dump.rs` line by line.
//
// Every node that casts to a typed AST node with semantic accessors gets one
// line `<start>..<end> <summary>`. Referenced nodes are printed as
// `<Kind>@<start>..<end>` (found by physical identity within the described
// subtree) or `<Kind>@ph` for placeholders outside the tree.

///|
fn ast_report(text : String) -> String {
  let root = @syntax.parse(text)
  let buf = StringBuilder()
  ast_walk(root, 0, buf)
  lines_report(text, buf)
  buf.to_string()
}

///|
fn ast_walk(
  node : @syntax.SyntaxNode,
  offset : Int,
  buf : StringBuilder,
) -> Unit {
  let ctx = { node, offset, }
  if describe(ctx) is Some(summary) {
    buf.write_string("\{offset}..\{offset + node.len()} \{summary}\n")
  }
  let mut off = offset
  for child in node.children() {
    ast_walk(child, off, buf)
    off += child.len()
  }
}

///|
/// The subtree a summary is computed for.
priv struct Ctx {
  node : @syntax.SyntaxNode
  offset : Int
}

///|
/// Find the absolute offset of `target` within this subtree.
fn Ctx::locate(self : Ctx, target : @syntax.SyntaxNode) -> Int? {
  fn go(node : @syntax.SyntaxNode, offset : Int) -> Int? {
    if physical_equal(node, target) {
      return Some(offset)
    }
    let mut off = offset
    for child in node.children() {
      if go(child, off) is Some(found) {
        return Some(found)
      }
      off += child.len()
    }
    None
  }

  go(self.node, self.offset)
}

///|
/// A reference to a node.
fn Ctx::r(self : Ctx, node : @syntax.SyntaxNode) -> String {
  "\{node.kind().debug_name()}\{self.at(node)}"
}

///|
fn[T : @ast.AstNode] Ctx::n(self : Ctx, node : T) -> String {
  self.r(node.to_untyped())
}

///|
/// Just the `@range` part of a reference.
fn Ctx::at(self : Ctx, node : @syntax.SyntaxNode) -> String {
  match self.locate(node) {
    Some(start) => "@\{start}..\{start + node.len()}"
    None => "@ph"
  }
}

///|
fn Ctx::ident(self : Ctx, ident : @ast.Ident) -> String {
  dbg_str(ident.get()) + self.at(ident.to_untyped())
}

///|
fn Ctx::math_ident(self : Ctx, ident : @ast.MathIdent) -> String {
  dbg_str(ident.get()) + self.at(ident.to_untyped())
}

///|
fn Ctx::pattern(self : Ctx, pattern : @ast.Pattern) -> String {
  match pattern {
    Normal(v) => "Normal(\{self.n(v)})"
    Placeholder(v) => "Placeholder(\{self.n(v)})"
    Parenthesized(v) => "Parenthesized(\{self.n(v)})"
    Destructuring(v) => "Destructuring(\{self.n(v)})"
  }
}

///|
fn Ctx::arg(self : Ctx, arg : @ast.Arg) -> String {
  match arg {
    Pos(v) => "Pos(\{self.n(v)})"
    Named(v) => "Named(\{self.n(v)})"
    Spread(v) => "Spread(\{self.n(v)})"
  }
}

///|
fn Ctx::param(self : Ctx, param : @ast.Param) -> String {
  match param {
    Pos(v) => "Pos(\{self.pattern(v)})"
    Named(v) => "Named(\{self.n(v)})"
    Spread(v) => "Spread(\{self.n(v)})"
  }
}

///|
fn Ctx::math_access(self : Ctx, access : @ast.MathAccess) -> String {
  match access {
    MathIdent(v) => "MathIdent(\{self.math_ident(v)})"
    MathFieldAccess(v) => "MathFieldAccess(\{self.n(v)})"
  }
}

///|
fn Ctx::idents(self : Ctx, idents : Iter[@ast.Ident]) -> String {
  list(idents.map(i => self.ident(i)))
}

///|
fn Ctx::opt_expr(self : Ctx, expr : @ast.Expr?) -> String {
  opt(expr.map(e => self.n(e)))
}

///|
fn list(items : Iter[String]) -> String {
  "[" + items.join(", ") + "]"
}

///|
fn opt(v : String?) -> String {
  match v {
    Some(s) => "Some(\{s})"
    None => "None"
  }
}

///|
fn dbg_str(s : String) -> String {
  @unicode.rust_debug_str(s)
}

///|
fn float(v : Double) -> String {
  let bits = v.reinterpret_as_uint64().to_string(radix=16)
  let pad = String::make(16 - bits.length(), '0')
  "\{rust_debug_f64(v)} bits=\{pad}\{bits}"
}

///|
fn describe(c : Ctx) -> String? {
  let node = c.node
  if (@ast.cast(node) : @ast.Expr?) is Some(expr) {
    let summary = describe_expr(c, expr)
    return Some("\{summary} hash=\{expr.hash()} literal=\{expr.is_literal()}")
  }
  if (@ast.cast(node) : @ast.Markup?) is Some(v) {
    return Some("Markup exprs=\{list(v.exprs().map(e => c.n(e)))}")
  }
  if (@ast.cast(node) : @ast.Code?) is Some(v) {
    return Some("Code exprs=\{list(v.exprs().map(e => c.n(e)))}")
  }
  if (@ast.cast(node) : @ast.Args?) is Some(v) {
    return Some(
      "Args items=\{list(v.items().map(a => c.arg(a)))} trailing_comma=\{v.trailing_comma()}",
    )
  }
  if (@ast.cast(node) : @ast.Params?) is Some(v) {
    return Some("Params children=\{list(v.children().map(p => c.param(p)))}")
  }
  if (@ast.cast(node) : @ast.Named?) is Some(v) {
    return Some(
      "Named name=\{c.ident(v.name())} expr=\{c.n(v.expr())} pattern=\{c.pattern(v.pattern())}",
    )
  }
  if (@ast.cast(node) : @ast.Keyed?) is Some(v) {
    return Some("Keyed key=\{c.n(v.key())} expr=\{c.n(v.expr())}")
  }
  if (@ast.cast(node) : @ast.Spread?) is Some(v) {
    return Some(
      "Spread expr=\{c.n(v.expr())} sink_ident=\{opt(v.sink_ident().map(i => c.ident(i)))} sink_expr=\{c.opt_expr(v.sink_expr())}",
    )
  }
  if (@ast.cast(node) : @ast.Destructuring?) is Some(v) {
    let items = v
      .items()
      .map(item => {
        match item {
          Pattern(p) => "Pattern(\{c.pattern(p)})"
          Named(n) => "Named(\{c.n(n)})"
          Spread(s) => "Spread(\{c.n(s)})"
        }
      })
    return Some(
      "Destructuring items=\{list(items)} bindings=\{c.idents(v.bindings().iter())}",
    )
  }
  if (@ast.cast(node) : @ast.ImportItems?) is Some(v) {
    let items = v
      .iter()
      .map(item => {
        let head = match item {
          Simple(p) => "Simple(\{c.n(p)})"
          Renamed(r) => "Renamed(\{c.n(r)})"
        }
        "\{head} path=\{c.n(item.path())} original_name=\{c.ident(item.original_name())} bound_name=\{c.ident(item.bound_name())}"
      })
    return Some("ImportItems iter=\{list(items)}")
  }
  if (@ast.cast(node) : @ast.ImportItemPath?) is Some(v) {
    return Some(
      "ImportItemPath iter=\{c.idents(v.iter())} name=\{c.ident(v.name())}",
    )
  }
  if (@ast.cast(node) : @ast.RenamedImportItem?) is Some(v) {
    return Some(
      "RenamedImportItem path=\{c.n(v.path())} original_name=\{c.ident(v.original_name())} new_name=\{c.ident(v.new_name())}",
    )
  }
  if (@ast.cast(node) : @ast.MathArgs?) is Some(v) {
    let args = v
      .arg_items()
      .map(a => "\{c.arg(a.arg)} semicolon=\{a.ends_in_semicolon}")
    let items = v
      .content_items()
      .map(item => {
        match item {
          Arg(a) => "Arg(\{c.arg(a)})"
          Space(s) => "Space(\{c.n(s)})"
          Comma(ch, n) => "Comma(\{@unicode.rust_debug_char(ch)}, \{c.r(n)})"
          Semicolon(ch, n) =>
            "Semicolon(\{@unicode.rust_debug_char(ch)}, \{c.r(n)})"
          LeftParen(ch, n) =>
            "LeftParen(\{@unicode.rust_debug_char(ch)}, \{c.r(n)})"
          RightParen(ch, n) =>
            "RightParen(\{@unicode.rust_debug_char(ch)}, \{c.r(n)})"
        }
      })
    return Some("MathArgs arg_items=\{list(args)} content_items=\{list(items)}")
  }
  if (@ast.cast(node) : @ast.RawLang?) is Some(v) {
    return Some("RawLang \{dbg_str(v.get())}")
  }
  if (@ast.cast(node) : @ast.LineComment?) is Some(v) {
    return Some("LineComment \{dbg_str(v.text())}")
  }
  if (@ast.cast(node) : @ast.BlockComment?) is Some(v) {
    return Some("BlockComment \{dbg_str(v.text())}")
  }
  None
}

///|
fn describe_expr(c : Ctx, expr : @ast.Expr) -> String {
  match expr {
    Text(v) => "Text \{dbg_str(v.get())}"
    Space(v) => "Space had_newline=\{v.had_newline()}"
    Linebreak(_) => "Linebreak"
    Parbreak(_) => "Parbreak"
    Escape(v) => "Escape \{@unicode.rust_debug_char(v.get())}"
    Shorthand(v) => "Shorthand \{@unicode.rust_debug_char(v.get())}"
    SmartQuote(v) => "SmartQuote double=\{v.double()}"
    Strong(v) => "Strong body=\{c.n(v.body())}"
    Emph(v) => "Emph body=\{c.n(v.body())}"
    Raw(v) => {
      let lang = v.lang().map(l => dbg_str(l.get()) + c.at(l.to_untyped()))
      let lines = v.lines().map(t => dbg_str(t.get()))
      "Raw block=\{v.block()} lang=\{opt(lang)} lines=\{list(lines)}"
    }
    Link(v) => "Link \{dbg_str(v.get())}"
    Label(v) => "Label \{dbg_str(v.get())}"
    Ref(v) =>
      "Ref target=\{dbg_str(v.target())} supplement=\{opt(v.supplement().map(s => c.n(s)))}"
    Heading(v) => "Heading depth=\{v.depth()} body=\{c.n(v.body())}"
    ListItem(v) => "ListItem body=\{c.n(v.body())}"
    EnumItem(v) =>
      "EnumItem number=\{opt(v.number().map(n => n.to_string()))} body=\{c.n(v.body())}"
    TermItem(v) =>
      "TermItem term=\{c.n(v.term())} description=\{c.n(v.description())}"
    Equation(v) => "Equation block=\{v.block()} body=\{c.n(v.body())}"
    Math(v) =>
      "Math exprs=\{list(v.exprs().map(e => c.n(e)))} was_deparenthesized=\{v.was_deparenthesized()}"
    MathText(v) =>
      match v.get() {
        Grapheme(s) => "MathText Grapheme(\{dbg_str(s)})"
        Number(s) => "MathText Number(\{dbg_str(s)})"
      }
    MathIdent(v) => "MathIdent \{dbg_str(v.get())}"
    MathFieldAccess(v) =>
      "MathFieldAccess target=\{c.math_access(v.target())} field=\{c.math_ident(v.field())}"
    MathShorthand(v) => "MathShorthand \{@unicode.rust_debug_char(v.get())}"
    MathAlignPoint(_) => "MathAlignPoint"
    MathCall(v) =>
      "MathCall callee=\{c.math_access(v.callee())} args=\{c.n(v.args())}"
    MathDelimited(v) =>
      "MathDelimited open=\{c.n(v.open())} body=\{c.n(v.body())} close=\{c.n(v.close())}"
    MathAttach(v) =>
      "MathAttach base=\{c.n(v.base())} bottom=\{c.opt_expr(v.bottom())} top=\{c.opt_expr(v.top())} primes=\{opt(v.primes().map(p => c.n(p)))}"
    MathPrimes(v) => "MathPrimes count=\{v.count()}"
    MathFrac(v) => "MathFrac num=\{c.n(v.num())} denom=\{c.n(v.denom())}"
    MathRoot(v) =>
      "MathRoot index=\{opt(v.index().map(i => i.to_int().to_string()))} radicand=\{c.n(v.radicand())}"
    Ident(v) => "Ident \{dbg_str(v.get())}"
    None(_) => "None"
    Auto(_) => "Auto"
    Bool(v) => "Bool \{v.get()}"
    Int(v) =>
      match v.get() {
        Ok(i) => "Int Ok(\{i})"
        Err(PosOverflow(base~, max_plus_one~)) =>
          "Int Err(PosOverflow base=\{opt(base.map(b => b.name()))} max_plus_one=\{max_plus_one})"
        Err(InvalidDigit(base, digits)) =>
          "Int Err(InvalidDigit \{base.name()} \{dbg_str(digits)})"
      }
    Float(v) => "Float \{float(v.get())}"
    Numeric(v) => {
      let (value, unit) = v.get()
      "Numeric \{float(value)} \{unit_name(unit)}"
    }
    Str(v) => "Str \{dbg_str(v.get())}"
    CodeBlock(v) => "CodeBlock body=\{c.n(v.body())}"
    ContentBlock(v) => "ContentBlock body=\{c.n(v.body())}"
    Parenthesized(v) =>
      "Parenthesized expr=\{c.n(v.expr())} pattern=\{c.pattern(v.pattern())}"
    Array(v) => {
      let items = v
        .items()
        .map(item => {
          match item {
            Pos(e) => "Pos(\{c.n(e)})"
            Spread(s) => "Spread(\{c.n(s)})"
          }
        })
      "Array items=\{list(items)}"
    }
    Dict(v) => {
      let items = v
        .items()
        .map(item => {
          match item {
            Named(n) => "Named(\{c.n(n)})"
            Keyed(k) => "Keyed(\{c.n(k)})"
            Spread(s) => "Spread(\{c.n(s)})"
          }
        })
      "Dict items=\{list(items)}"
    }
    Unary(v) => "Unary op=\{unop_name(v.op())} expr=\{c.n(v.expr())}"
    Binary(v) =>
      "Binary op=\{binop_name(v.op())} lhs=\{c.n(v.lhs())} rhs=\{c.n(v.rhs())}"
    FieldAccess(v) =>
      "FieldAccess target=\{c.n(v.target())} field=\{c.ident(v.field())}"
    FuncCall(v) => "FuncCall callee=\{c.n(v.callee())} args=\{c.n(v.args())}"
    Closure(v) =>
      "Closure name=\{opt(v.name().map(i => c.ident(i)))} params=\{c.n(v.params())} body=\{c.n(v.body())}"
    LetBinding(v) => {
      let kind = match v.kind() {
        Normal(p) => "Normal(\{c.pattern(p)})"
        Closure(i) => "Closure(\{c.ident(i)})"
      }
      "LetBinding kind=\{kind} init=\{c.opt_expr(v.init())} bindings=\{c.idents(v.kind().bindings().iter())}"
    }
    DestructAssignment(v) =>
      "DestructAssignment pattern=\{c.pattern(v.pattern())} value=\{c.n(v.value())}"
    SetRule(v) =>
      "SetRule target=\{c.n(v.target())} args=\{c.n(v.args())} condition=\{c.opt_expr(v.condition())}"
    ShowRule(v) =>
      "ShowRule selector=\{c.opt_expr(v.selector())} transform=\{c.n(v.transform())}"
    Contextual(v) => "Contextual body=\{c.n(v.body())}"
    Conditional(v) =>
      "Conditional condition=\{c.n(v.condition())} if_body=\{c.n(v.if_body())} else_body=\{c.opt_expr(v.else_body())}"
    WhileLoop(v) =>
      "WhileLoop condition=\{c.n(v.condition())} body=\{c.n(v.body())}"
    ForLoop(v) =>
      "ForLoop pattern=\{c.pattern(v.pattern())} iterable=\{c.n(v.iterable())} body=\{c.n(v.body())}"
    ModuleImport(v) => {
      let imports = match v.imports() {
        None => "None"
        Some(Wildcard) => "Some(Wildcard)"
        Some(Items(items)) => "Some(Items(\{c.n(items)}))"
      }
      let bare = match v.bare_name() {
        Ok(name) => "Ok(\{dbg_str(name)})"
        Err(Dynamic) => "Err(Dynamic)"
        Err(PathInvalid) => "Err(PathInvalid)"
        Err(PackageInvalid) => "Err(PackageInvalid)"
      }
      "ModuleImport source=\{c.n(v.source())} imports=\{imports} bare_name=\{bare} new_name=\{opt(v.new_name().map(i => c.ident(i)))}"
    }
    ModuleInclude(v) => "ModuleInclude source=\{c.n(v.source())}"
    LoopBreak(_) => "LoopBreak"
    LoopContinue(_) => "LoopContinue"
    FuncReturn(v) => "FuncReturn body=\{c.opt_expr(v.body())}"
  }
}

///|
fn unit_name(unit : @ast.NumericUnit) -> String {
  match unit {
    Pt => "Pt"
    Mm => "Mm"
    Cm => "Cm"
    In => "In"
    Rad => "Rad"
    Deg => "Deg"
    Em => "Em"
    Fr => "Fr"
    Percent => "Percent"
  }
}

///|
fn unop_name(op : @ast.UnOp) -> String {
  match op {
    Pos => "Pos"
    Neg => "Neg"
    Not => "Not"
  }
}

///|
fn binop_name(op : @ast.BinOp) -> String {
  match op {
    Add => "Add"
    Sub => "Sub"
    Mul => "Mul"
    Div => "Div"
    And => "And"
    Or => "Or"
    Eq => "Eq"
    Neq => "Neq"
    Lt => "Lt"
    Leq => "Leq"
    Gt => "Gt"
    Geq => "Geq"
    Assign => "Assign"
    In => "In"
    NotIn => "NotIn"
    AddAssign => "AddAssign"
    SubAssign => "SubAssign"
    MulAssign => "MulAssign"
    DivAssign => "DivAssign"
  }
}

///|
/// Exhaustive `Lines` conversions for every position of every line.
fn lines_report(text : String, buf : StringBuilder) -> Unit {
  let lines = @syntax.Lines::new(text)
  buf.write_string(
    "lines len_bytes=\{lines.len_bytes()} len_utf16=\{lines.len_utf16()} len_lines=\{lines.len_lines()}\n",
  )
  let n = lines.len_lines()
  let o = (v : Int?) => {
    match v {
      Some(v) => v.to_string()
      None => "-"
    }
  }
  for i in 0..<=n {
    guard lines.line_to_range(i) is Some((start, end)) else {
      buf.write_string("L\{i} -\n")
      continue
    }
    let last = i + 1 == n
    buf.write_string("L\{i} \{start}..\{end}\n")

    // Byte positions (including non-char boundaries).
    let b_end = if last { end + 1 } else { end }
    let items = []
    for b in start..<=b_end {
      let u = lines.byte_to_utf16(b)
      let l = lines.byte_to_line(b)
      let c = lines.byte_to_column(b)
      let lc = lines.byte_to_line_column(b)
      let expected = match (l, c) {
        (Some(l), Some(c)) => Some((l, c))
        _ => None
      }
      let check = if lc == expected { "" } else { "!" }
      items.push("\{o(u)}:\{o(l)}:\{o(c)}\{check}")
    }
    buf.write_string("  b \{items.join(" ")}\n")

    // UTF-16 positions.
    guard lines.byte_to_utf16(start) is Some(u_start) &&
      lines.byte_to_utf16(end) is Some(u_end) else {
      continue
    }
    let u_end = if last { u_end + 1 } else { u_end }
    let items = []
    for u in u_start..<=u_end {
      items.push(o(lines.utf16_to_byte(u)))
    }
    buf.write_string("  u \{items.join(" ")}\n")

    // Columns.
    let mut chars = 0
    for _ in @syntax.utf8_slice(text, start, end) {
      chars += 1
    }
    let items = []
    for col in 0..<=(chars + 1) {
      items.push(o(lines.line_column_to_byte(i, col)))
    }
    buf.write_string("  c \{items.join(" ")}\n")
  }
}

///|
/// Format a double exactly like Rust's `impl Debug for f64`.
fn rust_debug_f64(v : Double) -> String {
  if v.is_nan() {
    return "NaN"
  }
  if v.is_inf() {
    return if v > 0.0 { "inf" } else { "-inf" }
  }
  let negative = v.reinterpret_as_uint64() >> 63 == 1UL
  let sign = if negative { "-" } else { "" }
  if v == 0.0 {
    return sign + "0.0"
  }
  // Recover the shortest round-tripping digits from MoonBit's formatting:
  // value = 0.<digits> * 10^point.
  let s = v.abs().to_string()
  let digits = StringBuilder()
  let mut point : Int? = None
  let mut exp = 0
  let mut i = 0
  while i < s.length() {
    let c = s.code_unit_at(i).to_int()
    if c >= '0' && c <= '9' {
      digits.write_char(Int::unsafe_to_char(c))
    } else if c == '.' {
      point = Some(digits.to_string().length())
    } else if c == 'e' || c == 'E' {
      exp = @string.parse_int(s.unsafe_substring(start=i + 1, end=s.length())) catch {
        _ => 0
      }
      break
    }
    i += 1
  }
  let raw = digits.to_string()
  let mut point = point.unwrap_or(raw.length()) + exp
  // Strip leading zeros (moving the point) and trailing zeros.
  let mut lead = 0
  while lead < raw.length() && raw.code_unit_at(lead) == '0' {
    lead += 1
  }
  point -= lead
  let mut trail = raw.length()
  while trail > lead && raw.code_unit_at(trail - 1) == '0' {
    trail -= 1
  }
  let digits = raw.unsafe_substring(start=lead, end=trail)
  let abs = v.abs()
  if abs < 1.0e-4 || abs >= 1.0e16 {
    // Exponential notation.
    let mantissa = if digits.length() == 1 {
      digits
    } else {
      digits.unsafe_substring(start=0, end=1) +
      "." +
      digits.unsafe_substring(start=1, end=digits.length())
    }
    "\{sign}\{mantissa}e\{point - 1}"
  } else if point <= 0 {
    "\{sign}0.\{String::make(-point, '0')}\{digits}"
  } else if point >= digits.length() {
    "\{sign}\{digits}\{String::make(point - digits.length(), '0')}.0"
  } else {
    "\{sign}\{digits.unsafe_substring(start=0, end=point)}.\{digits.unsafe_substring(start=point, end=digits.length())}"
  }
}
