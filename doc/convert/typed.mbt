// Typed values (docs/edsl-convert.md, section 4.3): an expression against
// a parameter type of the EDSL, from its syntactic form only. No MoonBit
// arithmetic is emitted for a Typst operator: sums, differences and
// negations of lengths are the facade's own cases, which lower through
// Typst's operators.
//
// Enum cases (`Pt(11.0)`, `Red`, `Auto`, `Center`) are emitted unqualified:
// every typed form stands where its facade type is expected (a parameter,
// a field of `Sides(..)`, an array or tuple of the type).

///|
/// An expression against a parameter type of the EDSL (section 4.3), given
/// as the MoonBit type of the parameter (`"Length"`, `"Sides[Stroke]"`,
/// `"&IntoContent"`, ...). `None`: the expression has no typed form.
fn Tr::typed(self : Tr, expr : @ast.Expr, ty : String, env : Env) -> Code? {
  let mark = self.mark()
  try self.typed_form(expr, ty, env) catch {
    Bail(_) => {
      self.rollback(mark)
      None
    }
  } noraise {
    code => Some(code)
  }
}

///|
/// The typed form of an expression; raises if it has none.
fn Tr::typed_form(
  self : Tr,
  expr : @ast.Expr,
  ty : String,
  env : Env,
) -> Code raise Bail {
  match ty {
    "&IntoContent" => self.content_arg(expr, env)
    "Bool" => self.scalar(expr, TBool, env)
    "Int64" => self.scalar(expr, TInt, env)
    "Double" => self.scalar(expr, TFloat, env)
    "String" | "&IntoSource" => self.scalar(expr, TStr, env)
    "Length" => self.length(expr, env, true, false)
    "Spacing" | "Sizing" => self.sizing(expr, env, true)
    "Angle" => { code: angle_literal(expr), total: true, }
    "Paint" => self.paint(expr, env, true)
    "Stroke" => self.stroke(expr, env)
    "Alignment" => self.alignment(expr, env, true)
    "Dir" => dir_constant(expr, env)
    "FontWeight" => font_weight(expr)
    "Numbering" =>
      match unparen(expr) {
        None(_) => { code: "Numbering::none()", total: true, }
        _ => {
          let pattern = self.scalar(expr, TStr, env)
          // The pattern is parsed by the field's cast.
          { code: "Numbering(\{pattern.code})", total: true, }
        }
      }
    "Supplement" =>
      match unparen(expr) {
        None(_) => { code: "Supplement::none()", total: true, }
        Auto(_) => { code: "Supplement::auto()", total: true, }
        _ => {
          let content = self.content_arg(expr, env)
          { code: "Supplement(\{content.code})", total: content.total, }
        }
      }
    "LinkTarget" =>
      match unparen(expr) {
        Label(label) =>
          // The facade calls `label`.
          { code: "ToLabel(\{mbt_str(label.get())})", total: false, }
        Str(_) | Ident(_) if self.typed(expr, "String", env) is Some(url) =>
          { code: "Url(\{url.code})", total: true, }
        _ => {
          let value = self.value(expr, env)
          { code: "Dest(\{value.code})", total: value.total, }
        }
      }
    "Value" => self.value(expr, env)
    "(Length, Length)" => {
      guard unparen(expr) is Array(array) else { raise Bail("untyped") }
      let items = array.items().collect()
      guard items.length() == 2 && items[0] is Pos(a) && items[1] is Pos(b) else {
        raise Bail("untyped")
      }
      let a = self.length(a, env, true, false)
      let b = self.length(b, env, true, false)
      { code: "(\{a.code}, \{b.code})", total: a.total && b.total, }
    }
    "Array[Sizing]" => self.tracks(expr, env)
    "Array[String]" => self.strings(expr, env)
    _ =>
      if ty.strip_prefix("Sides[") is Some(rest) &&
        rest.strip_suffix("]") is Some(item) {
        self.sides(expr, item.to_owned(), env)
      } else if ty.strip_prefix("Corners[") is Some(rest) &&
        rest.strip_suffix("]") is Some(item) {
        self.corners(expr, item.to_owned(), env)
      } else if ty.strip_prefix("Cells[") is Some(rest) &&
        rest.strip_suffix("]") is Some(item) {
        self.cells(expr, item.to_owned(), env)
      } else {
        raise Bail("untyped")
      }
  }
}

///|
/// A content argument: a content block (`Seq`), a string literal (text),
/// `none`/`auto`, a typed constructor call, or any value form (which is
/// passed as the value).
fn Tr::content_arg(self : Tr, expr : @ast.Expr, env : Env) -> Code raise Bail {
  match expr {
    Parenthesized(p) => self.content_arg(p.expr(), env)
    ContentBlock(block) => self.stream(block.body(), env)
    Str(string) => { code: mbt_str(string.get()), total: true, }
    None(_) => { code: "NoneValue()", total: true, }
    Auto(_) => { code: "AutoValue()", total: true, }
    Ident(ident) =>
      match env.vars.get(ident.get()) {
        // A string is text, a view the matched element itself.
        Some((variable, TStr)) | Some((variable, TView(_))) =>
          { code: variable, total: true, }
        _ => self.value(expr, env)
      }
    FuncCall(call) => self.call_arg(call, env)
    _ => self.value(expr, env)
  }
}

///|
/// A scalar: the literal (with a sign), or a translated variable of the
/// type.
fn Tr::scalar(
  self : Tr,
  expr : @ast.Expr,
  ty : Ty,
  env : Env,
) -> Code raise Bail {
  match unparen(expr) {
    Ident(ident) =>
      match env.vars.get(ident.get()) {
        Some((variable, found)) if found == ty =>
          { code: variable, total: true, }
        _ => raise Bail("untyped")
      }
    literal =>
      match self.literal(literal, env) {
        Some((code, found)) if found == ty => { code, total: true, }
        _ => raise Bail("untyped")
      }
  }
}

///|
/// A finite number as a MoonBit `Double` literal.
fn number(value : Double) -> String raise Bail {
  if value.is_nan() || value.is_inf() {
    raise Bail("untyped")
  }
  float_literal(value)
}

///|
/// A length: numeric literals by unit, their sums, differences and
/// negations as the facade's cases (which lower through Typst's
/// operators), a translated variable; at the `top`, `auto` and `none`.
/// `pure`: only what is certainly a `length` value (no ratios, states or
/// variables).
fn Tr::length(
  self : Tr,
  expr : @ast.Expr,
  env : Env,
  top : Bool,
  pure : Bool,
) -> Code raise Bail {
  match unparen(expr) {
    Numeric(numeric) => {
      let (value, unit) = numeric.get()
      guard length_unit(unit) is Some(ctor) && !(pure && unit is Percent) else {
        raise Bail("untyped")
      }
      { code: "\{ctor}(\{number(value)})", total: true, }
    }
    Binary(binary) => {
      let ctor = match binary.op() {
        Add => "Sum"
        Sub => "Diff"
        _ => raise Bail("untyped")
      }
      let lhs = self.length(binary.lhs(), env, false, pure)
      let rhs = self.length(binary.rhs(), env, false, pure)
      { code: "\{ctor}(\{lhs.code}, \{rhs.code})", total: false, }
    }
    Unary(unary) => {
      let inner = self.length(unary.expr(), env, false, pure)
      match unary.op() {
        Neg => { code: "Neg(\{inner.code})", total: false, }
        // `+x` is `x` for lengths and ratios.
        Pos => { code: inner.code, total: false, }
        Not => raise Bail("untyped")
      }
    }
    Auto(_) if top && !pure => { code: "Auto", total: true, }
    None(_) if top && !pure => { code: "None", total: true, }
    Ident(ident) if !pure =>
      match env.vars.get(ident.get()) {
        Some((variable, TLength)) => { code: variable, total: true, }
        _ => raise Bail("untyped")
      }
    _ => raise Bail("untyped")
  }
}

///|
/// Whether an expression is certainly a `length` value.
fn Tr::is_pure_length(self : Tr, expr : @ast.Expr, env : Env) -> Bool {
  try self.length(expr, env, false, true) catch {
    Bail(_) => false
  } noraise {
    _ => true
  }
}

///|
/// A spacing or sizing: one numeric literal (a fraction, a length or a
/// ratio), any other length form as `Rel(..)`, `auto`/`none` at the `top`.
/// The facades have no arithmetic with fractions.
fn Tr::sizing(
  self : Tr,
  expr : @ast.Expr,
  env : Env,
  top : Bool,
) -> Code raise Bail {
  match unparen(expr) {
    Auto(_) if top => { code: "Auto", total: true, }
    None(_) if top => { code: "None", total: true, }
    Numeric(numeric) => {
      let (value, unit) = numeric.get()
      match unit {
        Fr => { code: "Fr(\{number(value)})", total: true, }
        // The unit cases of `Spacing`/`Sizing` are those of `Length`.
        _ => self.length(expr, env, false, false)
      }
    }
    _ => {
      let length = self.length(expr, env, false, false)
      { code: "Rel(\{length.code})", total: length.total, }
    }
  }
}

///|
/// One numeric literal with an angle unit (the facade has no operators).
fn angle_literal(expr : @ast.Expr) -> String raise Bail {
  guard unparen(expr) is Numeric(numeric) else { raise Bail("untyped") }
  match numeric.get() {
    (value, Deg) => "Deg(\{number(value)})"
    (value, Rad) => "Rad(\{number(value)})"
    _ => raise Bail("untyped")
  }
}

///|
/// A colour by its form: a named constant, a translated colour variable,
/// `rgb("..")`, `luma(n)`.
fn Tr::color(self : Tr, expr : @ast.Expr, env : Env) -> Code raise Bail {
  match unparen(expr) {
    Ident(ident) => {
      let name = ident.get()
      match env.vars.get(name) {
        Some((variable, TPaint)) => { code: variable, total: true, }
        Some(_) => raise Bail("untyped")
        None =>
          match color_constant(name) {
            Some(case) if self.lookup(name) is Some(_) =>
              { code: case, total: true, }
            _ => raise Bail("untyped")
          }
      }
    }
    FuncCall(call) => {
      guard self.global_path(call.callee(), env) is Some(path) else {
        raise Bail("untyped")
      }
      let args = call.args().items().collect()
      guard args.length() == 1 && args[0] is Pos(arg) else {
        raise Bail("untyped")
      }
      match (path, unparen(arg)) {
        // The facade calls the same functions; they can fail.
        ("rgb", Str(hex)) =>
          { code: "Rgb(\{mbt_str(hex.get())})", total: false, }
        ("luma", Int(int)) =>
          match int.get() {
            Ok(value) if value >= 0L && value <= 0x7fffffffL =>
              { code: "Luma(\{value})", total: false, }
            _ => raise Bail("untyped")
          }
        _ => raise Bail("untyped")
      }
    }
    _ => raise Bail("untyped")
  }
}

///|
/// Whether an expression is a colour by its form.
fn Tr::is_color(self : Tr, expr : @ast.Expr, env : Env) -> Bool {
  try self.color(expr, env) catch {
    Bail(_) => false
  } noraise {
    _ => true
  }
}

///|
/// A paint: a colour, `none`/`auto`, a typed paint function (`tiling`),
/// or any value form as `Value(..)`.
fn Tr::paint(
  self : Tr,
  expr : @ast.Expr,
  env : Env,
  hatch : Bool,
) -> Code raise Bail {
  match unparen(expr) {
    None(_) => return { code: "None", total: true, }
    Auto(_) => return { code: "Auto", total: true, }
    FuncCall(call) =>
      if self.global_path(call.callee(), env) is Some(path) &&
        find_func(path) is Some(func) &&
        func.owner == "Paint" &&
        self.lookup(path) is Some(Func(_)) &&
        self.try_sig(Sig::of_func(func), path, call.args(), env) is Ok(code) {
        return code
      }
    _ => ()
  }
  if self.typed_color(expr, env) is Some(code) {
    return code
  }
  guard hatch else { raise Bail("untyped") }
  let value = self.value(expr, env)
  { code: "Value(\{value.code})", total: value.total, }
}

///|
fn Tr::typed_color(self : Tr, expr : @ast.Expr, env : Env) -> Code? {
  try self.color(expr, env) catch {
    Bail(_) => None
  } noraise {
    code => Some(code)
  }
}

///|
/// A stroke: a length, a colour, `length + colour`, `none`/`auto`. Each is
/// the stroke the field's cast makes of the Typst value: `Stroke(..)`
/// calls `stroke(..)` with the same parts, which cannot fail for a certain
/// length and a colour. A dictionary literal has no typed form: Typst
/// validates its fields when the element function casts it, the facade
/// would validate them while the arguments are lowered.
fn Tr::stroke(self : Tr, expr : @ast.Expr, env : Env) -> Code raise Bail {
  match unparen(expr) {
    None(_) => { code: "Stroke::none()", total: true, }
    Auto(_) => { code: "Stroke::auto()", total: true, }
    Binary(binary) if binary.op() is Add => {
      // `length + colour` (in either order) is a stroke.
      let (length, color) = if self.is_pure_length(binary.lhs(), env) {
        (binary.lhs(), binary.rhs())
      } else {
        (binary.rhs(), binary.lhs())
      }
      let color = self.color(color, env)
      let length = self.length(length, env, false, true)
      {
        code: "Stroke(paint=\{color.code}, thickness=\{length.code})",
        total: false,
      }
    }
    _ =>
      if self.is_pure_length(expr, env) {
        let length = self.length(expr, env, false, true)
        { code: "Stroke(thickness=\{length.code})", total: false, }
      } else {
        let color = self.color(expr, env)
        { code: "Stroke(paint=\{color.code})", total: false, }
      }
  }
}

///|
/// An alignment: the constants, `a + b`, `auto`/`none` at the `top`.
fn Tr::alignment(
  self : Tr,
  expr : @ast.Expr,
  env : Env,
  top : Bool,
) -> Code raise Bail {
  match unparen(expr) {
    Auto(_) if top => { code: "Auto", total: true, }
    None(_) if top => { code: "None", total: true, }
    Ident(ident) if !env.vars.contains(ident.get()) => {
      let case = match ident.get() {
        "start" => "Start"
        "left" => "Left"
        "center" => "Center"
        "right" => "Right"
        "end" => "End"
        "top" => "Top"
        "horizon" => "Horizon"
        "bottom" => "Bottom"
        _ => raise Bail("untyped")
      }
      { code: case, total: false, }
    }
    Binary(binary) if top && binary.op() is Add => {
      // Two constants; adding two alignments of one axis fails.
      guard unparen(binary.lhs()) is Ident(_) &&
        unparen(binary.rhs()) is Ident(_) else {
        raise Bail("untyped")
      }
      let lhs = self.alignment(binary.lhs(), env, false)
      let rhs = self.alignment(binary.rhs(), env, false)
      { code: "Both(\{lhs.code}, \{rhs.code})", total: false, }
    }
    _ => raise Bail("untyped")
  }
}

///|
fn dir_constant(expr : @ast.Expr, env : Env) -> Code raise Bail {
  match unparen(expr) {
    Auto(_) => { code: "Auto", total: true, }
    Ident(ident) if !env.vars.contains(ident.get()) => {
      let case = match ident.get() {
        "ltr" => "Ltr"
        "rtl" => "Rtl"
        "ttb" => "Ttb"
        "btt" => "Btt"
        _ => raise Bail("untyped")
      }
      { code: case, total: false, }
    }
    _ => raise Bail("untyped")
  }
}

///|
/// A font weight: one of the named weights or an integer.
fn font_weight(expr : @ast.Expr) -> Code raise Bail {
  match unparen(expr) {
    Str(string) => {
      let case = match string.get() {
        "thin" => "Thin"
        "extralight" => "ExtraLight"
        "light" => "Light"
        "regular" => "Regular"
        "medium" => "Medium"
        "semibold" => "SemiBold"
        "bold" => "Bold"
        "extrabold" => "ExtraBold"
        "black" => "Black"
        _ => raise Bail("untyped")
      }
      { code: case, total: true, }
    }
    Int(int) =>
      match int.get() {
        Ok(value) if value >= 0L && value <= 0x7fffffffL =>
          { code: "Weight(\{value})", total: true, }
        _ => raise Bail("untyped")
      }
    _ => raise Bail("untyped")
  }
}

///|
/// The keys of a sides dictionary, in the order `Sides(..)` lowers them.
let side_keys : Array[(String, String)] = [
  ("x", "x"),
  ("y", "y"),
  ("left", "left"),
  ("top", "top"),
  ("right", "right"),
  ("bottom", "bottom"),
  ("rest", "rest"),
]

///|
/// The keys of a corners dictionary, in the order `Corners(..)` lowers
/// them.
let corner_keys : Array[(String, String)] = [
  ("top", "top"),
  ("bottom", "bottom"),
  ("left", "left"),
  ("right", "right"),
  ("top-left", "top_left"),
  ("top-right", "top_right"),
  ("bottom-left", "bottom_left"),
  ("bottom-right", "bottom_right"),
  ("rest", "rest"),
]

///|
/// A dictionary literal whose keys are all among `keys` (and distinct,
/// and at least one): the labelled arguments of `Sides(..)`/`Corners(..)`.
/// `None`: the expression is no such dictionary. Raises if a component is
/// not total.
fn Tr::keyed(
  self : Tr,
  expr : @ast.Expr,
  keys : Array[(String, String)],
  item : String,
  env : Env,
) -> Code? raise Bail {
  guard unparen(expr) is Dict(dict) else { return None }
  let items = dict.items().collect()
  if items.is_empty() {
    return None
  }
  // A dictionary of other keys is one value (a stroke).
  let found : Array[(Int, String, @ast.Expr)] = []
  for entry in items {
    guard entry is Named(named) else { return None }
    let key = named.name().get()
    let mut at = -1
    for i, pair in keys {
      if pair.0 == key {
        at = i
      }
    }
    if at < 0 || found.iter().any(f => f.0 == at) {
      return None
    }
    found.push((at, keys[at].1, named.expr()))
  }
  let parts : Array[String] = []
  let mut total = true
  for entry in found {
    let code = self.typed_form(entry.2, item, env)
    total = total && code.total
    parts.push("\{entry.1}=\{code.code}")
  }
  // The facade lowers its fields in a fixed order, not in source order:
  // a dictionary with a component that is not total stays a dictionary.
  guard total else { raise Bail("untyped") }
  Some({ code: parts.join(", "), total, })
}

///|
/// The sides of a box: a dictionary literal with the side keys, `auto`/
/// `none` for the field, otherwise one value for all sides.
fn Tr::sides(
  self : Tr,
  expr : @ast.Expr,
  item : String,
  env : Env,
) -> Code raise Bail {
  match unparen(expr) {
    None(_) => return { code: "Sides::none()", total: true, }
    Auto(_) => return { code: "Sides::auto()", total: true, }
    _ => ()
  }
  match self.keyed(expr, side_keys, item, env) {
    Some(sides) => { code: "Sides(\{sides.code})", total: sides.total, }
    None => {
      let all = self.typed_form(expr, item, env)
      { code: "Sides(all=\{all.code})", total: all.total, }
    }
  }
}

///|
/// The corners of a box, like the sides.
fn Tr::corners(
  self : Tr,
  expr : @ast.Expr,
  item : String,
  env : Env,
) -> Code raise Bail {
  match self.keyed(expr, corner_keys, item, env) {
    Some(corners) => { code: "Corners(\{corners.code})", total: corners.total, }
    None => {
      let all = self.typed_form(expr, item, env)
      { code: "Corners(all=\{all.code})", total: all.total, }
    }
  }
}

///|
/// The items of an array literal without spreads.
fn array_items(array : @ast.ArrayLit) -> Array[@ast.Expr] raise Bail {
  let items : Array[@ast.Expr] = []
  for item in array.items() {
    match item {
      Pos(expr) => items.push(expr)
      Spread(_) => raise Bail("spread")
    }
  }
  items
}

///|
/// A per-cell value: an array literal is one value per column, anything
/// else one value for all cells (the field's cast decides alike: it takes
/// an array or a function as such).
fn Tr::cells(
  self : Tr,
  expr : @ast.Expr,
  item : String,
  env : Env,
) -> Code raise Bail {
  match unparen(expr) {
    Array(array) => {
      let parts : Array[String] = []
      let mut total = true
      for entry in array_items(array) {
        let code = self.typed_form(entry, item, env)
        total = total && code.total
        parts.push(code.code)
      }
      { code: "Cells::columns([\{parts.join(", ")}])", total, }
    }
    _ => {
      let all = self.typed_form(expr, item, env)
      { code: "Cells::all(\{all.code})", total: all.total, }
    }
  }
}

///|
/// Track sizes: an array literal, the count shorthand, or one size.
fn Tr::tracks(self : Tr, expr : @ast.Expr, env : Env) -> Code raise Bail {
  match unparen(expr) {
    Array(array) => {
      let parts : Array[String] = []
      let mut total = true
      for entry in array_items(array) {
        let size = self.sizing(entry, env, true)
        total = total && size.total
        parts.push(size.code)
      }
      { code: "[\{parts.join(", ")}]", total, }
    }
    // An integer count stays an integer (through `extra`): Typst
    // validates it.
    Int(_) => raise Bail("untyped")
    // `none` is no track size: a value alone is cast differently from an
    // array of it only if it is no size.
    None(_) => raise Bail("untyped")
    _ => {
      let size = self.sizing(expr, env, true)
      { code: "[\{size.code}]", total: size.total, }
    }
  }
}

///|
/// A list of strings: an array literal of strings, or one string.
fn Tr::strings(self : Tr, expr : @ast.Expr, env : Env) -> Code raise Bail {
  match unparen(expr) {
    Array(array) => {
      let parts : Array[String] = []
      for entry in array_items(array) {
        parts.push(self.scalar(entry, TStr, env).code)
      }
      { code: "[\{parts.join(", ")}]", total: true, }
    }
    _ => {
      let one = self.scalar(expr, TStr, env)
      { code: "[\{one.code}]", total: true, }
    }
  }
}
