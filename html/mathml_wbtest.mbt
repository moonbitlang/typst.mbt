// Unit tests for the math IR resolution and its MathML conversion. The
// equations are evaluated from math source and realized with the minimal
// stub realization of `semantics_wbtest.mbt`. The expected MathML is the
// upstream output for the same formulas (dumped with the oracle's `html`
// stage, with the pretty-printing whitespace between tags removed).

///|
/// Evaluates math source into an equation, as `$src$` (or `$ src $` for a
/// block equation, with the size its show-set rule sets).
fn eval_equation(
  engine : @library.Engine,
  src : String,
  block : Bool,
) -> @library.Content raise {
  let value = @eval.eval_string(
    engine,
    @library.Context::none(),
    src,
    @syntax.Span::detached(),
    Math,
    @library.Scope::new(),
  )
  guard value is Content(eq) else { fail("expected content") }
  let eq = eq.with_field(@library.equation_elem_block, Bool(block))
  eq.styled(@library.EquationElem::set_size(if block { Display } else { Text }))
}

///|
/// Converts the equation to MathML and returns the encoded `<math>` element
/// and the warnings.
fn mathml(src : String, block? : Bool = false) -> (String, String) raise {
  let engine = test_engine()
  let content = eval_equation(engine, src, block)
  let locator = @library.Locator::root().split()
  let pairs = stub_realize(
    Par,
    engine,
    locator,
    content,
    @library.StyleChain::empty(),
  )
  let nodes = convert_to_nodes(engine, locator, pairs, Block, Normal)
  let p = HtmlElement::new(@library.tag_p).with_children(nodes)
  resolve_inline_styles(p)
  let out = html_encode(p)
  let out = out.unsafe_substring(
    start="<!DOCTYPE html><p>".length(),
    end=out.length() - 4,
  )
  (out, engine.sink.warnings().map(w => w.message).join("; "))
}

///|
/// Resolves the equation into the math IR.
fn resolve(src : String, block? : Bool = false) -> @library.MathItem raise {
  let engine = test_engine()
  let content = eval_equation(engine, src, block)
  let pairs = stub_realize(
    Par,
    engine,
    @library.Locator::root().split(),
    content,
    @library.StyleChain::empty(),
  )
  // The equation itself is realized by its rule; resolve its body instead.
  ignore(pairs)
  let styles = @library.StyleChain::new(
    @library.Styles::from_array([
      @library.EquationElem::set_size(if block { Display } else { Text }),
    ]),
  )
  let eq = @library.EquationElem::of(@library.StyledElem::child(content)).unwrap()
  @library.resolve_equation(eq, engine, @library.Locator::root(), styles)
}

///|
fn class_name(c : @unicode.MathClass) -> String {
  match c {
    Normal => "Normal"
    Alphabetic => "Alphabetic"
    Binary => "Binary"
    Closing => "Closing"
    Diacritic => "Diacritic"
    Fence => "Fence"
    GlyphPart => "GlyphPart"
    Large => "Large"
    Opening => "Opening"
    Punctuation => "Punctuation"
    Relation => "Relation"
    Space => "Space"
    Unary => "Unary"
    Vary => "Vary"
    Special => "Special"
  }
}

///|
/// A compact dump of the IR structure.
fn dump(item : @library.MathItem) -> String {
  let buf = StringBuilder()
  fn go(item : @library.MathItem) -> Unit {
    match item {
      Spacing(_, _, weak) => buf.write_string(if weak { "h~" } else { "h" })
      Space => buf.write_string("_")
      Tag(_) => buf.write_string("tag")
      Comp(comp) => {
        let props = comp.props
        let class = match props.class {
          Some(c) => class_name(c)
          None => "-"
        }
        let spacing = match (props.lspace, props.rspace) {
          (None, None) => ""
          (l, r) => {
            let f = (e : @library.Em?) => {
              match e {
                Some(e) => @library.rust_display_f64(e.get())
                None => "-"
              }
            }
            "[\{f(l)},\{f(r)}]"
          }
        }
        match comp.kind {
          Glyph(g) => buf.write_string("glyph(\{g.text}:\{class}\{spacing})")
          Text(t) => buf.write_string("text(\{t.text}\{spacing})")
          Number(n) => buf.write_string("num(\{n.text}\{spacing})")
          Group(g) => {
            buf.write_string("group(")
            for i, it in g.items {
              if i > 0 {
                buf.write_string(" ")
              }
              go(it)
            }
            buf.write_string(")")
          }
          Fraction(f) => {
            buf.write_string("frac(")
            go(f.numerator)
            buf.write_string(", ")
            go(f.denominator)
            buf.write_string(")")
          }
          Scripts(s) => {
            buf.write_string("scripts\{spacing}(")
            go(s.base)
            for
              pair in [
                ("t", s.top),
                ("b", s.bottom),
                ("tl", s.top_left),
                ("bl", s.bottom_left),
                ("tr", s.top_right),
                ("br", s.bottom_right),
              ] {
              if pair.1 is Some(x) {
                buf.write_string(", \{pair.0}: ")
                go(x)
              }
            }
            buf.write_string(")")
          }
          Fenced(f) => {
            buf.write_string("fenced(")
            if f.open is Some(o) {
              go(o)
            }
            buf.write_string(" | ")
            go(f.body.item())
            buf.write_string(" | ")
            if f.close is Some(c) {
              go(c)
            }
            buf.write_string(")")
          }
          Multiline(m) => {
            buf.write_string("multiline(")
            for i, row in m.rows {
              if i > 0 {
                buf.write_string(" \\\\ ")
              }
              for j, col in row.items() {
                if j > 0 {
                  buf.write_string(" & ")
                }
                go(col)
              }
            }
            buf.write_string(")")
          }
          _ => buf.write_string("other")
        }
      }
    }
  }

  go(item)
  buf.to_string()
}

///|
test "ir: spacing and attachments" {
  inspect(
    dump(resolve("x^2 + y_1 - a_b^c")),
    content="group(scripts(glyph(𝑥:Alphabetic), tr: num(2)) glyph(+:Binary[0.2222222222222222,0.2222222222222222]) scripts(glyph(𝑦:Alphabetic), br: num(1)) glyph(−:Binary[0.2222222222222222,0.2222222222222222]) scripts(glyph(𝑎:Alphabetic), tr: glyph(𝑐:Alphabetic), br: glyph(𝑏:Alphabetic)))",
  )
}

///|
test "ir: limits in display style" {
  inspect(
    dump(resolve("sum_(i=0)^n i", block=true)),
    content="group(scripts[-,0.16666666666666666](glyph(∑:Large), t: glyph(𝑛:Alphabetic), b: group(glyph(𝑖:Alphabetic) glyph(=:Relation) num(0))) glyph(𝑖:Alphabetic))",
  )
}

///|
test "ir: fences and alignment" {
  inspect(
    dump(resolve("(a + b)")),
    content="fenced(glyph((:Opening) | group(glyph(𝑎:Alphabetic) glyph(+:Binary[0.2222222222222222,0.2222222222222222]) glyph(𝑏:Alphabetic)) | glyph():Closing))",
  )
  inspect(
    dump(resolve("a &= b \\ &= c", block=true)),
    content="multiline(glyph(𝑎:Alphabetic) & group(glyph(=:Relation[0.2777777777777778,0.2777777777777778]) glyph(𝑏:Alphabetic)) \\\\ group() & group(glyph(=:Relation[-,0.2777777777777778]) glyph(𝑐:Alphabetic)))",
  )
}

///|
test "mathml: attachments" {
  inspect(
    mathml("x^2 + y_1 - a_b^c").0,
    content="<math><msup><mi>𝑥</mi><mn>2</mn></msup><mo>+</mo><msub><mi>𝑦</mi><mn>1</mn></msub><mo>−</mo><msubsup><mi>𝑎</mi><mi>𝑏</mi><mi>𝑐</mi></msubsup></math>",
  )
}

///|
test "mathml: fractions" {
  inspect(
    mathml("1/2 = a/(b+c)").0,
    content="<math><mfrac><mn>1</mn><mn>2</mn></mfrac><mo>=</mo><mfrac><mi>𝑎</mi><mrow><mi>𝑏</mi><mo lspace=\"0em\" rspace=\"0em\">+</mo><mi>𝑐</mi></mrow></mfrac></math>",
  )
}

///|
test "mathml: block with limits" {
  inspect(
    mathml("sum_(i=0)^n i = (n(n+1))/2", block=true).0,
    content="<math display=\"block\"><munderover><mo lspace=\"0em\">∑</mo><mrow><mi>𝑖</mi><mo lspace=\"0em\" rspace=\"0em\">=</mo><mn>0</mn></mrow><mi>𝑛</mi></munderover><mi>𝑖</mi><mo>=</mo><mfrac><mrow><mi>𝑛</mi><mrow><mo>(</mo><mrow><mi>𝑛</mi><mo>+</mo><mn>1</mn></mrow><mo>)</mo></mrow></mrow><mn>2</mn></mfrac></math>",
  )
}

///|
test "mathml: delimiters" {
  inspect(
    mathml("lr((a/b)) abs(x) [x mid(|) y]").0,
    content="<math><mrow><mo>(</mo><mfrac><mi>𝑎</mi><mi>𝑏</mi></mfrac><mo>)</mo></mrow><mrow><mo>|</mo><mi>𝑥</mi><mo>|</mo></mrow><mrow><mo>[</mo><mrow><mi>𝑥</mi><mo fence=\"false\" stretchy=\"true\" symmetric=\"true\">|</mo><mi>𝑦</mi></mrow><mo>]</mo></mrow></math>",
  )
}

///|
test "mathml: tables" {
  inspect(
    mathml("mat(1, 2; 3, 4) vec(a, b) cases(x &\"if\" y, z &\"else\")").0,
    content="<math><mrow><mo>(</mo><mtable><mtr><mtd><mn>1</mn></mtd><mtd><mn>2</mn></mtd></mtr><mtr><mtd><mn>3</mn></mtd><mtd><mn>4</mn></mtd></mtr></mtable><mo>)</mo></mrow><mrow><mo>(</mo><mtable><mtr><mtd><mi>𝑎</mi></mtd></mtr><mtr><mtd><mi>𝑏</mi></mtd></mtr></mtable><mo>)</mo></mrow><mrow><mo>{</mo><mtable class=\"cases\"><mtr><mtd><mi>𝑥</mi><mspace width=\"0.2222em\"/></mtd><mtd><mtext>if</mtext><mspace width=\"0.2222em\"/><mi>𝑦</mi></mtd></mtr><mtr><mtd><mi>𝑧</mi><mspace width=\"0.2222em\"/></mtd><mtd><mtext>else</mtext></mtd></mtr></mtable></mrow></math>",
  )
}

///|
test "mathml: multiline alignment" {
  inspect(
    mathml("a &= b + c \\ &= d", block=true).0,
    content="<math display=\"block\"><mtable class=\"multiline-equation aligned\"><mtr><mtd><mi>𝑎</mi></mtd><mtd><mo form=\"infix\">=</mo><mi>𝑏</mi><mo>+</mo><mi>𝑐</mi></mtd></mtr><mtr><mtd></mtd><mtd><mo form=\"infix\">=</mo><mi>𝑑</mi></mtd></mtr></mtable></math>",
  )
}

///|
test "mathml: accents and ignored items" {
  let (out, warnings) = mathml(
    "hat(x) arrow(a b) overline(z) tilde(i) underbrace(x, 1)",
  )
  inspect(
    out,
    content="<math><mover accent=\"true\"><mi>𝑥</mi><mo>̂</mo></mover><mover accent=\"true\"><mrow><mi>𝑎</mi><mi>𝑏</mi></mrow><mo stretchy=\"true\">⃗</mo></mover><mi>𝑧</mi><mover accent=\"true\"><mi>𝑖</mi><mo>̃</mo></mover><munder><munder accentunder=\"true\"><mi>𝑥</mi><mo>⏟</mo></munder><mn>1</mn></munder></math>",
  )
  inspect(warnings, content="overline was ignored during MathML export")
}

///|
test "mathml: roots and primes" {
  inspect(
    mathml("sqrt(x) root(3, y) x'' f''''' n!").0,
    content="<math><msqrt><mi>𝑥</mi></msqrt><mroot><mi>𝑦</mi><mn>3</mn></mroot><msup><mi>𝑥</mi><mo>″</mo></msup><msup><mi>𝑓</mi><mo>′′′′′</mo></msup><mi>𝑛</mi><mo>!</mo></math>",
  )
}

///|
test "mathml: text, variants and operators" {
  inspect(
    mathml("\"if\" x in RR, bold(A) cal(B) 3.14 lim_(x -> 0) sin x").0,
    content="<math><mtext>if</mtext><mspace width=\"0.2222em\"/><mi>𝑥</mi><mo>∈</mo><mi>ℝ</mi><mo>,</mo><mi>𝑨</mi><mi>ℬ︀</mi><mn>3.14</mn><msub><mo form=\"prefix\" lspace=\"0.16666666666666666em\" rspace=\"0.16666666666666666em\">lim</mo><mrow><mi>𝑥</mi><mo lspace=\"0em\" rspace=\"0em\" stretchy=\"false\">→</mo><mn>0</mn></mrow></msub><mo form=\"prefix\" lspace=\"0em\" rspace=\"0.16666666666666666em\">sin</mo><mi>𝑥</mi></math>",
  )
}

///|
test "mathml: unsupported items" {
  let (out, warnings) = mathml(
    "frac(a, b, style: \"skewed\") cancel(x) a #h(1em) b",
  )
  inspect(
    out,
    content="<math><mi scriptlevel=\"1\">𝑎</mi><mi>𝑥</mi><mi>𝑎</mi><mspace width=\"1em\"/><mi>𝑏</mi></math>",
  )
  inspect(
    warnings,
    content="skewed fraction was ignored during MathML export; cancel was ignored during MathML export",
  )
}

///|
test "mathml: classes, binomials and operators" {
  inspect(
    mathml(
      "a class(\"relation\", +) b binom(n, k) op(\"ess\", limits: #true)_x",
    ).0,
    content="<math><mi>𝑎</mi><mo lspace=\"0.2777777777777778em\" rspace=\"0.2777777777777778em\">+</mo><mi>𝑏</mi><mrow><mo>(</mo><mfrac linethickness=\"0\"><mi>𝑛</mi><mi>𝑘</mi></mfrac><mo>)</mo></mrow><msub><mo form=\"prefix\" lspace=\"0.16666666666666666em\" rspace=\"0em\">ess</mo><mi>𝑥</mi></msub></math>",
  )
}
