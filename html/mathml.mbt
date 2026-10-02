// Port of `typst-html/src/mathml.rs`: conversion of the math IR into MathML
// elements and the equation stylesheet.

// CSS classes.

///|
let multiline_equation_class : String = "multiline-equation"

///|
let aligned_class : String = "aligned"

///|
let left_align_class : String = "left-align"

///|
let right_align_class : String = "right-align"

///|
let cases_class : String = "cases"

///|
let flushed_class : String = "flushed"

///|
let left_flush_class : String = "left-flush"

///|
let right_flush_class : String = "right-flush"

// CSS values.

///|
let equation_row_gap : @library.Em = @library.Em::new(0.5)

///|
let space_width : @library.Em = @library.Em::new(4.0 / 18.0)

///|
/// The CSS styles for equations, added to the `<head>` of documents with
/// equations (upstream `EQUATION_CSS_STYLES`).
let equation_css_styles : String = {
  let row_gap = @library.to_css(equation_row_gap)
  let frac_padding = @library.to_css(@library.frac_padding)
  let css =
    $|/* Alignment */
    $|mtable.\{right_align_class} > mtr > mtd,
    $|mtable > mtr > mtd.\{right_align_class},
    $|mtable.\{left_align_class} > mtr > mtd.\{right_align_class},
    $|mtable.\{aligned_class} > mtr > mtd:nth-child(odd) {
    $|  justify-items: end;
    $|  text-align: right;
    $|}
    $|mtable.\{cases_class} > mtr > mtd,
    $|mtable.\{left_align_class} > mtr > mtd,
    $|mtable > mtr > mtd.\{left_align_class},
    $|mtable.\{aligned_class} > mtr > mtd:nth-child(even),
    $|math:is(:not([display])) > mtable.\{multiline_equation_class} > mtr > mtd {
    $|  justify-items: start;
    $|  text-align: left;
    $|}
    $|mtable.\{cases_class} > mtr > mtd,
    $|mtable.\{aligned_class} > mtr > mtd,
    $|mtable > mtr > mtd.\{flushed_class},
    $|mtable > mtr > mtd.\{left_flush_class} {
    $|  padding-left: 0;
    $|}
    $|mtable.\{cases_class} > mtr > mtd,
    $|mtable.\{aligned_class} > mtr > mtd,
    $|mtable > mtr > mtd.\{flushed_class},
    $|mtable > mtr > mtd.\{right_flush_class} {
    $|  padding-right: 0;
    $|}
    $|
    $|/* Tables */
    $|mtable {
    $|  math-style: inherit;
    $|}
    $|mtd {
    $|  math-depth: auto-add;
    $|  math-style: compact;
    $|  math-shift: compact;
    $|}
    $|
    $|/* Equations */
    $|mtable.\{multiline_equation_class} > mtr > mtd {
    $|  math-depth: inherit;
    $|  math-style: inherit;
    $|  math-shift: inherit;
    $|  padding: 0;
    $|}
    $|math > mtable.\{multiline_equation_class} > mtr:not(:last-child) > mtd {
    $|  padding-bottom: \{row_gap};
    $|}
    $|
    $|/* Fractions */
    $|mfrac {
    $|  padding-inline: 0;
    $|  margin-inline: \{frac_padding};
    $|}
    $|
    $|/* Accents */
    $|mover[accent="true" i] > :first-child {
    $|  font-feature-settings: "dtls";
    $|}
    $|mover.dotted[accent="true" i] > :first-child {
    $|  font-feature-settings: "dtls" 0;
    $|}
    $|
    $|/* Other rules for scriptlevel, displaystyle and math-shift */
    $|munder > :nth-child(2),
    $|munderover > :nth-child(2) {
    $|  math-shift: compact
    $|}
    $|munder[accentunder="true" i] > :not(:first-child),
    $|mover[accent="true" i] > :not(:first-child) {
    $|  math-depth: inherit;
    $|  math-style: inherit;
    $|  math-shift: inherit;
    $|}
  css
}

///|
/// Converts a resolved equation into MathML nodes.
pub fn convert_math_to_nodes(
  item : @library.MathItem,
  engine : @library.Engine,
  styles : @library.StyleChain,
  block : Bool,
) -> Array[@library.Content] raise @library.SourceError {
  let ctx = MathContext::new(engine, styles, block)
  ctx.handle_into_nodes(item)
}

///|
/// Collapses a collection of nodes into a single node, wrapping multiple
/// nodes in an `mrow` (upstream `ContentExt::into_content`).
fn into_content(nodes : Array[@library.Content]) -> @library.Content {
  if nodes.length() == 1 {
    nodes[0]
  } else {
    html_elem(@library.tag_mathml_mrow, @library.Content::sequence(nodes)).pack()
  }
}

///|
/// Where an item sits among its siblings. Used to derive the default
/// operator form for an `mo`.
priv enum NodePosition {
  Start
  Middle
  End
  /// A lone item, with an optional explicit form given.
  Only(@html_assets.Form?)
}

///|
fn NodePosition::get_form(self : NodePosition) -> @html_assets.Form {
  match self {
    Start => Prefix
    Middle => Infix
    End => Postfix
    Only(form) => form.unwrap_or(Infix)
  }
}

///|
/// Outer spacing and position for an embellished operator, passed down to
/// the core `mo` where they are emitted as attributes.
priv struct EmbellishmentContext {
  lspace : @library.Em?
  rspace : @library.Em?
  position : NodePosition
  limits : Bool
}

///|
/// The `math-shift` CSS property.
priv enum MathShift {
  Normal
  Compact
} derive(Eq)

///|
fn MathShift::to_string(self : MathShift) -> String {
  match self {
    Normal => "normal"
    Compact => "compact"
  }
}

///|
/// The `math-style` CSS property.
priv enum MathStyle {
  Normal
  Compact
} derive(Eq)

///|
/// The MathML Core CSS properties currently in effect.
///
/// Tracked so children only emit attributes that differ from what the
/// browser will apply via the UA styelsheet and our stylesheet.
priv struct CssContext {
  math_style : MathStyle
  math_shift : MathShift
  math_depth : Int
} derive(Eq)

///|
fn CssContext::new(block : Bool) -> CssContext {
  {
    math_style: if block {
      Normal
    } else {
      Compact
    },
    math_shift: Normal,
    math_depth: 0,
  }
}

///|
fn CssContext::depth_auto_add(self : CssContext) -> CssContext {
  {
    ..self,
    math_depth: if self.math_style == Compact {
      self.math_depth + 1
    } else {
      self.math_depth
    },
  }
}

///|
fn CssContext::depth_add(self : CssContext, n : Int) -> CssContext {
  { ..self, math_depth: self.math_depth + n, }
}

///|
fn CssContext::style_compact(self : CssContext) -> CssContext {
  { ..self, math_style: Compact, }
}

///|
fn CssContext::shift_compact(self : CssContext) -> CssContext {
  { ..self, math_shift: Compact, }
}

///|
fn CssContext::from(size : @library.MathSize, cramped : Bool) -> CssContext {
  let math_shift : MathShift = if cramped { Compact } else { Normal }
  match size {
    Display => { math_style: Normal, math_shift, math_depth: 0, }
    Text => { math_style: Compact, math_shift, math_depth: 0, }
    Script => { math_style: Compact, math_shift, math_depth: 1, }
    ScriptScript => { math_style: Compact, math_shift, math_depth: 2, }
  }
}

///|
/// The context for math handling.
priv struct MathContext {
  engine : @library.Engine
  mut content : Array[@library.Content]
  mut embellishment : EmbellishmentContext?
  mut css : CssContext
  mut trunk_depth : Int
}

///|
/// Create a new math context.
fn MathContext::new(
  engine : @library.Engine,
  styles : @library.StyleChain,
  block : Bool,
) -> MathContext {
  {
    engine,
    content: [],
    embellishment: None,
    css: CssContext::new(block),
    trunk_depth: styles.links().length(),
  }
}

///|
/// Build a text element with the given diverging styles (relative to the
/// equation's trunk). This is so that show rules aren't applied again to
/// this text when the result html elements are realized again.
fn MathContext::body_text(
  self : MathContext,
  text : String,
  span : @syntax.Span,
  styles : @library.StyleChain,
) -> @library.Content {
  self.apply_diverging(@library.TextElem::packed(text).spanned(span), styles)
}

///|
/// Apply the diverging styles (relative to the equation's trunk) to the
/// given content. This is so that show rules on `html.elem` see the styles
/// that were active during math realization.
fn MathContext::apply_diverging(
  self : MathContext,
  content : @library.Content,
  styles : @library.StyleChain,
) -> @library.Content {
  content.styled_with_map(styles.suffix(self.trunk_depth))
}

///|
/// Push a node.
fn MathContext::push(self : MathContext, content : @library.Content) -> Unit {
  self.content.push(content)
}

///|
/// Run `f` with the CSS context temporarily replaced.
fn[T] MathContext::with_css(
  self : MathContext,
  css : CssContext,
  f : () -> T raise @library.SourceError,
) -> T raise @library.SourceError {
  let prev = self.css
  self.css = css
  defer {
    self.css = prev
  }
  f()
}

///|
/// Run `f` with the trunk depth temporarily replaced.
fn[T] MathContext::with_trunk_depth(
  self : MathContext,
  trunk_depth : Int,
  f : () -> T raise @library.SourceError,
) -> T raise @library.SourceError {
  let prev = self.trunk_depth
  self.trunk_depth = trunk_depth
  defer {
    self.trunk_depth = prev
  }
  f()
}

///|
/// Handle the given item and return the resulting nodes, using `only` as
/// the operator form preference if the item turns out to be lone.
fn MathContext::handle_into_nodes_with_only_form(
  self : MathContext,
  item : @library.MathItem,
  only : @html_assets.Form?,
) -> Array[@library.Content] raise @library.SourceError {
  let prev = self.content
  self.content = []
  defer {
    self.content = prev
  }
  self.handle_into_self(item, only)
  self.content
}

///|
/// Handle the given item and return the resulting nodes.
fn MathContext::handle_into_nodes(
  self : MathContext,
  item : @library.MathItem,
) -> Array[@library.Content] raise @library.SourceError {
  self.handle_into_nodes_with_only_form(item, None)
}

///|
/// Handle the given item and collapse the resulting nodes into a single
/// node.
fn MathContext::handle_into_node(
  self : MathContext,
  item : @library.MathItem,
) -> @library.Content raise @library.SourceError {
  into_content(self.handle_into_nodes(item))
}

///|
/// Handle the given item and collapse the resulting nodes into a single
/// node, using `only` as the operator form preference if the item turns out
/// to be lone.
fn MathContext::handle_into_node_with_only_form(
  self : MathContext,
  item : @library.MathItem,
  only : @html_assets.Form,
) -> @library.Content raise @library.SourceError {
  into_content(self.handle_into_nodes_with_only_form(item, Some(only)))
}

///|
/// Handle the given item as a lone child and strip form/spacing attributes
/// from a resulting bare `mo`.
///
/// This is for attachments in MathML, where a lone `mo` would otherwise get
/// form `postfix` and have its `lspace`/`rspace` ignored. See § 3.3.1.2
/// Layout of `<mrow>` of MathML Core.
fn MathContext::handle_into_node_lone(
  self : MathContext,
  item : @library.MathItem,
) -> @library.Content raise @library.SourceError {
  strip_inert_mo_attrs(self.handle_into_node_with_only_form(item, Postfix))
}

///|
/// Dispatch each child to the element handler, tagging it with its position
/// among siblings. For a single-child item, `only` is the form preference.
fn MathContext::handle_into_self(
  self : MathContext,
  item : @library.MathItem,
  only : @html_assets.Form?,
) -> Unit raise @library.SourceError {
  let items = item.as_slice()
  let len = items.length()
  for i, item in items {
    let position = if len == 1 {
      Only(only)
    } else if i == 0 {
      Start
    } else if i == len - 1 {
      End
    } else {
      Middle
    }
    handle_realized(item, self, position)
  }
}

///|
/// Handles a leaf element resulting from realization.
fn handle_realized(
  item : @library.MathItem,
  ctx : MathContext,
  position : NodePosition,
) -> Unit raise @library.SourceError {
  // Handle non-component items first.
  let comp = match item {
    Comp(comp) => comp
    Spacing(amount, _, _) => {
      ctx.push(
        @library.HtmlElem::new(@library.tag_mathml_mspace)
        .with_attr(@library.attr_mathml_width, @library.to_css(amount))
        .pack(),
      )
      return
    }
    Space => {
      // We hard-code the space width as `(4/18)em`.
      ctx.push(
        @library.HtmlElem::new(@library.tag_mathml_mspace)
        .with_attr(@library.attr_mathml_width, @library.to_css(space_width))
        .pack(),
      )
      return
    }
    Tag(tag) => {
      ctx.push(@library.TagElem::new(tag).pack())
      return
    }
  }
  let props = comp.props
  let styles = comp.styles
  let embellished = is_embellished_operator(item)
  let target = CssContext::from(props.size, props.cramped)
  // We clamp the tracked depth at 2 so we don't emit unnecessary
  // `scriptlevel="2"` everywhere.
  let ctx_depth = if ctx.css.math_depth < 2 { ctx.css.math_depth } else { 2 }
  let scriptlevel = if target.math_depth != ctx_depth {
    Some(target.math_depth.to_string())
  } else {
    None
  }
  let displaystyle = if target.math_style != ctx.css.math_style {
    Some((target.math_style == Normal).to_string())
  } else {
    None
  }
  let properties = @library.CssProperties::new()
  if target.math_shift != ctx.css.math_shift {
    properties.push("math-shift", target.math_shift.to_string())
  }

  // Push explicit lspace if it won't be added to the attributes of an `mo`.
  if !embellished &&
    props.lspace is Some(lspace) &&
    !props.align_form_infix &&
    !lspace.is_zero() {
    ctx.push(
      @library.HtmlElem::new(@library.tag_mathml_mspace)
      .with_attr(
        @library.attr_mathml_width,
        "\{@library.rust_display_f64(lspace.get())}em",
      )
      .with_optional_attr(@library.attr_mathml_scriptlevel, scriptlevel)
      .pack(),
    )
  }

  // For embellished operators which aren't an `mo` element, pass the outer
  // spacing and position to the core operator.
  if embellished &&
    !(comp.kind is (Glyph(_) | Text(_))) &&
    ctx.embellishment is None &&
    !props.align_form_infix {
    ctx.embellishment = Some({
      lspace: props.lspace,
      rspace: props.rspace,
      position,
      limits: has_limits(item),
    })
  }
  let css = if target != ctx.css { target } else { ctx.css }
  let trunk_depth = styles.links().length()
  // Element's own context, established by the attributes emitted on it below.
  let node = ctx.with_css(css, () => {
    ctx.with_trunk_depth(trunk_depth, () => {
      match comp.kind {
        Glyph(item) => Some(handle_glyph(item, ctx, props, position, styles))
        Radical(item) => Some(handle_radical(item, ctx, props))
        Accented(item) => Some(handle_accent(item, ctx, props))
        Scripts(item) => Some(handle_scripts(item, ctx, props))
        Primes(item) => Some(handle_primes(item, ctx, props, position, styles))
        Table(item) => Some(handle_table(item, ctx, props))
        Fraction(item) => Some(handle_fraction(item, ctx, props))
        Text(item) => Some(handle_math_text(item, ctx, props, position, styles))
        Number(item) => Some(handle_number(item, ctx, props, styles))
        Fenced(item) => Some(handle_fenced(item, ctx, props))
        Group(_) => Some(ctx.handle_into_node(item))
        Multiline(item) => Some(handle_multiline(item, ctx, props))
        Mathml(item) => Some(handle_mathml(item, ctx, props))

        // Polyfill required for MathML Core.
        SkewedFraction(item) =>
          Some(
            ignored_math_item(
              ctx,
              item.numerator,
              props.span,
              "skewed fraction",
            ),
          )
        Line(item) if item.position is Above =>
          Some(ignored_math_item(ctx, item.base, props.span, "overline"))
        Line(item) =>
          Some(ignored_math_item(ctx, item.base, props.span, "underline"))
        Cancel(item) =>
          Some(ignored_math_item(ctx, item.base, props.span, "cancel"))

        // TODO: enforce phrasing content.
        //
        // Arbitrary content is not allowed, as per the HTML spec. Only
        // MathML token elements (mi, mo, mn, ms, and mtext), when
        // descendants of HTML elements, may contain phrasing content from
        // the HTML namespace. See
        // https://html.spec.whatwg.org/#phrasing-content-2
        //
        // In MathML 3, nothing is allowed except MathML elements. Further,
        // nesting root-level math elements is disallowed. Since the math
        // element is considered phrasing content, it can be nested in MathML
        // Core (as long as it is itself within a MathML token element).
        Box(item) => Some(item.elem.pack())
        External(item) => Some(item.content)
      }
    })
  })
  if node is Some(node) {
    let (node, modified) = modify_inner_html_elem(node, elem => {
      elem
      .with_optional_attr(@library.attr_mathml_scriptlevel, scriptlevel)
      .with_optional_attr(@library.attr_mathml_displaystyle, displaystyle)
      .with_css(properties)
    })
    ctx.push(if modified { ctx.apply_diverging(node, styles) } else { node })
  }

  // Push explicit rspace if it won't be added to the attributes of an `mo`.
  if !embellished && props.rspace is Some(rspace) && !rspace.is_zero() {
    ctx.push(
      @library.HtmlElem::new(@library.tag_mathml_mspace)
      .with_attr(
        @library.attr_mathml_width,
        "\{@library.rust_display_f64(rspace.get())}em",
      )
      .with_optional_attr(@library.attr_mathml_scriptlevel, scriptlevel)
      .pack(),
    )
  }
}

///|
fn handle_multiline(
  item : @library.MultilineItem,
  ctx : MathContext,
  _props : @library.MathProperties,
) -> @library.Content raise @library.SourceError {
  let cells = []
  for row in item.rows {
    let cell_nodes = []
    for cell in row.items() {
      cell_nodes.push(
        html_elem(
          @library.tag_mathml_mtd,
          @library.Content::sequence(ctx.handle_into_nodes(cell)),
        ).pack(),
      )
    }
    cells.push(
      html_elem(@library.tag_mathml_mtr, @library.Content::sequence(cell_nodes)).pack(),
    )
  }
  let class = StringBuilder()
  class.write_string(multiline_equation_class)
  if item.rows.get(0) is Some(row) && row.len() > 1 {
    class.write_char(' ')
    class.write_string(aligned_class)
  }
  @library.HtmlElem::new(@library.tag_mathml_mtable)
  .with_attr(@library.attr_class, class.to_string())
  .with_body(Some(@library.Content::sequence(cells)))
  .pack()
}

///|
fn handle_fraction(
  item : @library.FractionItem,
  ctx : MathContext,
  _props : @library.MathProperties,
) -> @library.Content raise @library.SourceError {
  // UA stylesheet.
  let num = ctx.with_css(ctx.css.depth_auto_add().style_compact(), () => {
    ctx.handle_into_node(item.numerator)
  })
  // UA stylesheet.
  let denom = ctx.with_css(
    ctx.css.depth_auto_add().style_compact().shift_compact(),
    () => ctx.handle_into_node(item.denominator),
  )
  let line = if !item.line { Some("0") } else { None }
  @library.HtmlElem::new(@library.tag_mathml_mfrac)
  .with_body(Some(num.add(denom)))
  .with_optional_attr(@library.attr_mathml_linethickness, line)
  .pack()
}

///|
fn handle_radical(
  item : @library.RadicalItem,
  ctx : MathContext,
  _props : @library.MathProperties,
) -> @library.Content raise @library.SourceError {
  // UA stylesheet.
  let radicand = ctx.with_css(ctx.css.shift_compact(), () => {
    ctx.handle_into_nodes(item.radicand)
  })
  let index = match item.index {
    Some(index) =>
      // UA stylesheet.
      Some(
        ctx.with_css(ctx.css.depth_add(2).style_compact().shift_compact(), () => {
          ctx.handle_into_node(index)
        }),
      )
    None => None
  }
  let (tag, body) = match index {
    Some(index) =>
      (@library.tag_mathml_mroot, into_content(radicand).add(index))
    None => (@library.tag_mathml_msqrt, @library.Content::sequence(radicand))
  }
  html_elem(tag, body).pack()
}

///|
fn handle_glyph(
  item : @library.GlyphItem,
  ctx : MathContext,
  props : @library.MathProperties,
  position : NodePosition,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let text = item.text

  // Prime and factorial characters have math class Normal but are
  // semantically postfix operators, so emit `mo`. But only do this when the
  // math class hasn't been explicitly set by the user to something else.
  if props.class() == Normal && (is_prime(text) || text == "!") {
    return make_mo(
      text,
      props.span,
      ctx,
      props,
      position,
      Some(Postfix),
      false,
      false,
      false,
      None,
      styles,
    )
  }
  let mut form : @html_assets.Form? = None
  let mut fence = false
  let mut separator = false
  let mut largeop = false
  match props.class() {
    Normal | Alphabetic | Special | GlyphPart | Space => {
      let mathvariant = if @html_assets.will_auto_transform(text) {
        Some("normal")
      } else {
        None
      }
      return @library.HtmlElem::new(@library.tag_mathml_mi)
        .with_body(Some(ctx.body_text(text, props.span, styles)))
        .with_optional_attr(@library.attr_mathml_mathvariant, mathvariant)
        .pack()
    }
    Diacritic => form = Some(Postfix)
    Binary | Relation => form = Some(Infix)
    Vary | Unary => form = Some(Prefix)
    Punctuation => separator = true
    Fence => fence = true
    Large => {
      largeop = item.class == Large
      form = Some(Prefix)
    }
    Opening => {
      fence = true
      form = Some(Prefix)
    }
    Closing => {
      fence = true
      form = Some(Postfix)
    }
  }
  make_mo(
    text,
    props.span,
    ctx,
    props,
    position,
    form,
    fence,
    separator,
    largeop,
    Some(item.stretch),
    styles,
  )
}

///|
fn handle_accent(
  item : @library.AccentItem,
  ctx : MathContext,
  _props : @library.MathProperties,
) -> @library.Content raise @library.SourceError {
  let (tag, attr, css) = if item.position == Below {
    (@library.tag_mathml_munder, @library.attr_mathml_accentunder, ctx.css)
  } else {
    (
      @library.tag_mathml_mover,
      @library.attr_mathml_accent,
      ctx.css.shift_compact(),
    )
  }

  // UA stylesheet.
  let base = ctx.with_css(css, () => ctx.handle_into_node(item.base))

  // Firefox seems to be the only browser that applies the `dtls` OpenType
  // feature for the base of accents by default. We use our own CSS to force
  // enable/disable it on all browsers.
  let dotted = if !item.exact_frame_width &&
    item.position == Above &&
    !item.dotless {
    Some("dotted")
  } else {
    None
  }

  // Whilst the validator https://validator.w3.org/nu/#file warns "Text run
  // starts with a composing character", using non-combining characters isn't
  // possible at the moment as not all accents have a non-combining
  // equivalent and the display of them is bad in browsers.
  // See https://github.com/w3c/mathml-core/issues/311.
  let accent = ctx.handle_into_node_lone(item.accent)
  @library.HtmlElem::new(tag)
  .with_body(Some(base.add(accent)))
  .with_attr(attr, "true")
  .with_optional_attr(@library.attr_class, dotted)
  .pack()
}

///|
fn handle_scripts(
  item : @library.ScriptsItem,
  ctx : MathContext,
  _props : @library.MathProperties,
) -> @library.Content raise @library.SourceError {
  let mut base = ctx.handle_into_node(item.base)

  // UA stylesheet + Typst stylesheet making bottom attachments cramped.
  let sup_css = ctx.css.depth_add(1).style_compact()
  let sub_css = sup_css.shift_compact()
  let handle = (x : @library.MathItem?, css : CssContext) => {
    match x {
      Some(x) => Some(ctx.with_css(css, () => ctx.handle_into_node_lone(x)))
      None => None
    }
  }
  let t = handle(item.top, sup_css)
  let tr = handle(item.top_right, sup_css)
  let tl = handle(item.top_left, sup_css)
  let b = handle(item.bottom, sub_css)
  let br = handle(item.bottom_right, sub_css)
  let bl = handle(item.bottom_left, sub_css)
  let scripts : (@library.HtmlTag, Array[@library.Content])? = match
    (tl, tr, bl, br) {
    (None, None, None, None) => None
    (None, None, None, Some(br)) => Some((@library.tag_mathml_msub, [br]))
    (None, Some(tr), None, None) => Some((@library.tag_mathml_msup, [tr]))
    (None, Some(tr), None, Some(br)) =>
      Some((@library.tag_mathml_msubsup, [br, tr]))
    (tl, tr, bl, br) => {
      let unwrap = (node : @library.Content?) => {
        node.unwrap_or(@library.HtmlElem::new(@library.tag_mathml_mrow).pack())
      }
      Some(
        (
          @library.tag_mathml_mmultiscripts,
          [
            unwrap(br),
            unwrap(tr),
            @library.HtmlElem::new(@library.tag_mathml_mprescripts).pack(),
            unwrap(bl),
            unwrap(tl),
          ],
        ),
      )
    }
  }
  if scripts is Some((tag, other_children)) {
    let children = [base]
    children.append(other_children)
    base = html_elem(tag, @library.Content::sequence(children)).pack()
  }
  let limits : (@library.HtmlTag, Array[@library.Content])? = match (t, b) {
    (None, None) => None
    (Some(t), None) => Some((@library.tag_mathml_mover, [t]))
    (None, Some(b)) => Some((@library.tag_mathml_munder, [b]))
    (Some(t), Some(b)) => Some((@library.tag_mathml_munderover, [b, t]))
  }
  if limits is Some((tag, other_children)) {
    let children = [base]
    children.append(other_children)
    base = html_elem(tag, @library.Content::sequence(children)).pack()
  }
  base
}

///|
fn handle_table(
  item : @library.MathTableItem,
  ctx : MathContext,
  _props : @library.MathProperties,
) -> @library.Content raise @library.SourceError {
  let (ncols, has_sub_cols) = match item.cells.get(0) {
    Some(row) => (row.length(), row.iter().any(cell => cell.len() > 1))
    None => (0, false)
  }

  // Typst stylesheet.
  let css = ctx.css.depth_auto_add().style_compact().shift_compact()
  let cells = []
  for row in item.cells {
    let nodes = []
    for cell in row {
      let count = cell.len()
      for i, sub_col in cell.items() {
        let body = ctx.with_css(css, () => ctx.handle_into_nodes(sub_col))
        nodes.push(
          @library.HtmlElem::new(@library.tag_mathml_mtd)
          .with_body(Some(@library.Content::sequence(body)))
          .with_optional_attr(
            @library.attr_class,
            table_mtd_class(i, count, ncols, item.alternator),
          )
          .pack(),
        )
      }
    }
    cells.push(
      html_elem(@library.tag_mathml_mtr, @library.Content::sequence(nodes)).pack(),
    )
  }
  let class = match (item.alternator, item.align) {
    (None_, _) if ncols == 1 => Some(cases_class)
    (Right, _) if ncols == 1 && has_sub_cols => Some(aligned_class)
    (_, Start) => Some(left_align_class)
    (_, End) => Some(right_align_class)
    (_, Center) => None
  }
  @library.HtmlElem::new(@library.tag_mathml_mtable)
  .with_body(Some(@library.Content::sequence(cells)))
  .with_optional_attr(@library.attr_class, class)
  .pack()
}

///|
/// Upstream `handle_text` (renamed; `convert.mbt` has its own).
fn handle_math_text(
  item : @library.MathTextItem,
  ctx : MathContext,
  props : @library.MathProperties,
  position : NodePosition,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  if props.class() == Large {
    make_mo(
      item.text,
      props.span,
      ctx,
      props,
      position,
      Some(Prefix),
      false,
      false,
      false,
      None,
      styles,
    )
  } else {
    html_elem(
      @library.tag_mathml_mtext,
      ctx.body_text(item.text, props.span, styles),
    ).pack()
  }
}

///|
fn handle_number(
  item : @library.NumberItem,
  ctx : MathContext,
  props : @library.MathProperties,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  html_elem(
    @library.tag_mathml_mn,
    ctx.body_text(item.text, props.span, styles),
  ).pack()
}

///|
fn handle_primes(
  item : @library.PrimesItem,
  ctx : MathContext,
  props : @library.MathProperties,
  position : NodePosition,
  styles : @library.StyleChain,
) -> @library.Content raise @library.SourceError {
  let text = StringBuilder()
  for _ in 0..<item.count {
    text.write_char(@library.prime_char)
  }
  make_mo(
    text.to_string(),
    props.span,
    ctx,
    props,
    position,
    Some(Postfix),
    false,
    false,
    false,
    None,
    styles,
  )
}

///|
fn handle_fenced(
  item : @library.FencedItem,
  ctx : MathContext,
  _props : @library.MathProperties,
) -> @library.Content raise @library.SourceError {
  let children = []
  if item.open is Some(open) {
    children.push(ctx.handle_into_node_with_only_form(open, Prefix))
  }
  let body = ctx.handle_into_node(item.body.item())
  children.push(body)
  if item.close is Some(close) {
    children.push(ctx.handle_into_node_with_only_form(close, Postfix))
  }

  // We shouldn't always need to wrap this in an `mrow`, but browsers don't
  // follow the spec and insert an inferred `mrow` in situations like
  // `<msqrt>...</msqrt>`, `<mtd>...</mtd>`, and the top-level
  // `<math>...</math>`. For example:
  // https://bugzilla.mozilla.org/show_bug.cgi?id=236963
  // https://bugzilla.mozilla.org/show_bug.cgi?id=2018403
  html_elem(@library.tag_mathml_mrow, @library.Content::sequence(children)).pack()
}

///|
fn handle_mathml(
  item : @library.MathmlItem,
  ctx : MathContext,
  _props : @library.MathProperties,
) -> @library.Content raise @library.SourceError {
  let body = match item.body {
    Some(body) => Some(@library.Content::sequence(ctx.handle_into_nodes(body)))
    None => None
  }
  let elem = @library.HtmlElem::of(item.elem).unwrap()
  elem.with_body(body).pack()
}

///|
/// Creates an `mo` element.
fn make_mo(
  text : String,
  span : @syntax.Span,
  ctx : MathContext,
  props : @library.MathProperties,
  position : NodePosition,
  form : @html_assets.Form?,
  fence : Bool,
  separator : Bool,
  largeop : Bool,
  stretch : @library.Stretch?,
  styles : @library.StyleChain,
) -> @library.Content {
  // If this is the core operator of an embellished operator, use the spacing
  // and position stored in the context.
  let (lspace, rspace, position, limits) = match ctx.embellishment {
    Some(e) => {
      ctx.embellishment = None
      (e.lspace, e.rspace, e.position, e.limits)
    }
    None => (props.lspace, props.rspace, position, false)
  }
  let mut form = form
  let mut lspace = lspace
  if props.align_form_infix {
    form = Some(Infix)
    // The lspace at this stage is gone, but since it is infix the spacing
    // is symmetric, so we can just use the rspace.
    lspace = rspace
  }
  let initial_form = position.get_form()
  let info = @html_assets.OperatorInfo::of(
    text,
    form.unwrap_or(initial_form),
    form is Some(f) && f != initial_form,
  )

  // We force emitting `lspace` and `rspace` for a fraction slash (for
  // horizontal style) as it renders in browsers with spacing around it.
  // Browsers haven't updated the operator dictionary. See
  // https://phabricator.wikimedia.org/T375337
  // https://github.com/w3c/mathml-core/issues/260
  // https://github.com/w3c/mathml-core/pull/265
  // https://issues.chromium.org/issues/414588528
  // https://bugzilla.mozilla.org/show_bug.cgi?id=1586575
  let force_space = text == "/" && form.unwrap_or(initial_form) == Infix
  let form = match form {
    Some(f) if f != initial_form =>
      Some(
        match f {
          Prefix => "prefix"
          Infix => "infix"
          Postfix => "postfix"
        },
      )
    _ => None
  }
  let lspace = lspace.unwrap_or(@library.Em::zero()).get()
  let lspace = if force_space || lspace != info.lspace {
    Some("\{@library.rust_display_f64(lspace)}em")
  } else {
    None
  }
  let rspace = rspace.unwrap_or(@library.Em::zero()).get()
  let rspace = if force_space || rspace != info.rspace {
    Some("\{@library.rust_display_f64(rspace)}em")
  } else {
    None
  }
  let fence = if fence != @html_assets.is_fence(text) {
    Some(fence.to_string())
  } else {
    None
  }
  let separator = if separator != @html_assets.is_separator(text) {
    Some(separator.to_string())
  } else {
    None
  }
  let largeop = if largeop !=
    info.properties.contains(@html_assets.properties_largeop) {
    Some(largeop.to_string())
  } else {
    None
  }

  // In compact styles the browser will move top/bottom attachments to the tl
  // and br positions, so we need to explicitly disable this.
  let movablelimits = if limits &&
    ctx.css.math_style == Compact &&
    info.properties.contains(@html_assets.properties_movablelimits) {
    Some("false")
  } else {
    None
  }
  let stretch_axis : @library.Axis = match single_char(text) {
    Some(c) if @html_assets.is_stretch_axis_inline(c) => X
    _ => Y
  }
  let explicit = stretch is Some(stretch) && stretch.is_explicit(stretch_axis)
  let stretchy = if explicit !=
    info.properties.contains(@html_assets.properties_stretchy) {
    Some(explicit.to_string())
  } else {
    None
  }

  // We don't need to set `maxsize` as it is infinity by default.
  let (symmetric, minsize) = if explicit {
    let symmetric = if stretch_axis == Y &&
      !info.properties.contains(@html_assets.properties_symmetric) {
      Some("true")
    } else {
      None
    }
    let minsize = match stretch.unwrap().resolve_requested(stretch_axis) {
      Some(target) => Some(@library.to_css(target))
      None => None
    }
    (symmetric, minsize)
  } else {
    (None, None)
  }
  @library.HtmlElem::new(@library.tag_mathml_mo)
  .with_body(Some(ctx.body_text(text, span, styles)))
  .with_optional_attr(@library.attr_mathml_form, form)
  .with_optional_attr(@library.attr_mathml_fence, fence)
  .with_optional_attr(@library.attr_mathml_separator, separator)
  .with_optional_attr(@library.attr_mathml_lspace, lspace)
  .with_optional_attr(@library.attr_mathml_rspace, rspace)
  .with_optional_attr(@library.attr_mathml_stretchy, stretchy)
  .with_optional_attr(@library.attr_mathml_symmetric, symmetric)
  .with_optional_attr(@library.attr_mathml_minsize, minsize)
  .with_optional_attr(@library.attr_mathml_largeop, largeop)
  .with_optional_attr(@library.attr_mathml_movablelimits, movablelimits)
  .pack()
}

///|
/// The string's only character, if it has exactly one (upstream
/// `str::parse::<char>` / a two-step `chars()` check).
fn single_char(text : String) -> Char? {
  let mut result = None
  for i, c in text {
    if i > 0 {
      return None
    }
    result = Some(c)
  }
  result
}

///|
/// The class for an `mtd` that is one of multiple sub-columns in a table.
fn table_mtd_class(
  index : Int,
  count : Int,
  ncols : Int,
  alternator : @library.LeftRightAlternator,
) -> String? {
  if count <= 1 || ncols <= 1 || !(alternator is Right) {
    return None
  }
  let class = StringBuilder()
  class.write_string(
    if index % 2 == 0 {
      right_align_class
    } else {
      left_align_class
    },
  )
  class.write_char(' ')
  if index == 0 {
    class.write_string(right_flush_class)
  } else if index + 1 == count {
    class.write_string(left_flush_class)
  } else {
    class.write_string(flushed_class)
  }
  Some(class.to_string())
}

///|
/// Strips `form`, `lspace`, and `rspace` from a singleton `mo`.
fn strip_inert_mo_attrs(node : @library.Content) -> @library.Content {
  let (node, _) = modify_inner_html_elem(node, elem => {
    if elem.tag() == @library.tag_mathml_mo {
      let attrs = @library.HtmlAttrs::new()
      if elem.attrs_local() is Some(old) {
        for pair in old.pairs() {
          let (a, v) = pair
          if a != @library.attr_mathml_form &&
            a != @library.attr_mathml_lspace &&
            a != @library.attr_mathml_rspace {
            attrs.push(a, v)
          }
        }
      }
      elem.with_attrs(attrs)
    } else {
      elem
    }
  })
  node
}

///|
/// Modifies the inner `HtmlElem` of a content node, peeking through any
/// outer `StyledElem` wrapper.
///
/// Returns the new content and `true` if a modification was made.
fn modify_inner_html_elem(
  content : @library.Content,
  f : (@library.HtmlElem) -> @library.HtmlElem,
) -> (@library.Content, Bool) {
  if content.elem() == @library.styled_elem() {
    let (child, modified) = modify_inner_html_elem(
      @library.StyledElem::child(content),
      f,
    )
    return (content.with_field(0, Content(child)), modified)
  }
  if @library.HtmlElem::of(content) is Some(_) {
    // Upstream unpacks the element and packs it again, which drops the
    // content's metadata (span, label, location).
    let unpacked = @library.Content::from_fields(content.elem(), content.fields)
    let elem = @library.HtmlElem::of(unpacked).unwrap()
    return (f(elem).pack(), true)
  }
  (content, false)
}

///|
/// Whether the text is one of the dedicated Unicode prime characters.
fn is_prime(text : String) -> Bool {
  single_char(text) is Some('′' | '″' | '‴' | '⁗')
}

///|
/// Whether this item is considered an embellished operator in MathML Core.
/// See § 3.2.4.1 Embellished operators.
fn is_embellished_operator(item : @library.MathItem) -> Bool {
  guard item is Comp(comp) else { return false }
  match comp.kind {
    Glyph(_) =>
      !(comp.props.class()
      is (Normal | Alphabetic | Special | GlyphPart | Space))
    Text(_) => comp.props.class() == Large
    Scripts(scripts) => is_embellished_operator(scripts.base)
    Accented(accent) => is_embellished_operator(accent.base)
    Fraction(fraction) => is_embellished_operator(fraction.numerator)
    Group(group) => {
      let items = group.items.filter(item => {
        !item.is_ignorant() && !is_space_like(item)
      })
      items.length() == 1 && is_embellished_operator(items[0])
    }
    _ => false
  }
}

///|
/// Whether this item is considered a space-like element in MathML Core. See
/// § 3.2.5.1 Definition of space-like elements.
fn is_space_like(item : @library.MathItem) -> Bool {
  match item {
    Spacing(_, _, _) | Space => true
    Comp(comp) =>
      match comp.kind {
        Text(_) => comp.props.class() != Large
        Group(group) =>
          group.items
          .iter()
          .filter(item => !item.is_ignorant())
          .all(is_space_like)
        _ => false
      }
    Tag(_) => false
  }
}

///|
/// Whether this item, which is considered an embellished operator in MathML
/// Core, has top or bottom attachements somewhere.
fn has_limits(item : @library.MathItem) -> Bool {
  guard item is Comp(comp) else { return false }
  match comp.kind {
    Glyph(_) => false
    Text(_) => false
    Scripts(scripts) =>
      scripts.top is Some(_) ||
      scripts.bottom is Some(_) ||
      has_limits(scripts.base)
    Accented(accent) => has_limits(accent.base)
    Fraction(fraction) => has_limits(fraction.numerator)
    Group(group) => group.items.iter().any(has_limits)
    _ => false
  }
}

///|
/// Warn on ignored math items, but still handle their main part.
fn ignored_math_item(
  ctx : MathContext,
  body : @library.MathItem,
  span : @syntax.Span,
  name : String,
) -> @library.Content raise @library.SourceError {
  ctx.engine.sink.warn(
    @library.SourceDiagnostic::warning_at(
      span,
      "\{name} was ignored during MathML export",
    ),
  )
  ctx.handle_into_node(body)
}
