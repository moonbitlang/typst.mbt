// Tests of the HTML value types (`html_tag.mbt`, `html_attr.mbt`,
// `html_css.mbt`, `html_property.mbt`).

///|
test "html tag" {
  inspect(@library.tag_div, content="<div>")
  inspect(
    @library.tag_mathml_annotation_xml.resolve(),
    content="annotation-xml",
  )
  inspect(@library.HtmlTag::intern("my-elem"), content="<my-elem>")
  let err = (s : String) => {
    let _ = @library.HtmlTag::intern(s) catch {
      @library.HintedError(e) => return e.message
    }
    "ok"
  }
  inspect(err(""), content="tag name must not be empty")
  inspect(
    err("my@element"),
    content="the character \"@\" is not valid in a tag name",
  )
  inspect(
    err("1-custom"),
    content="custom element name must start with a lowercase letter",
  )
  inspect(
    err("my-ELEM"),
    content="custom element name must not contain uppercase letters",
  )
  inspect(
    err("font-face"),
    content="name is reserved and not valid for a custom element",
  )
  // Uppercase is fine for non-custom elements.
  inspect(err("DIV"), content="ok")
}

///|
test "html tag predicates" {
  assert_true(@library.tag_br.is_void())
  assert_false(@library.tag_div.is_void())
  assert_true(@library.tag_script.is_raw())
  assert_true(@library.tag_title.is_escapable_raw())
  assert_true(@library.tag_mathml_mspace.is_foreign_self_closing())
  assert_true(@library.tag_mathml_annotation_xml.is_mathml())
  assert_true(@library.tag_mathml_mi.is_mathml_token())
  assert_false(@library.tag_mathml_mrow.is_mathml_token())
  assert_true(@library.tag_mathml_math.is_phrasing_content())
  assert_true(@library.tag_div.is_whitespace_collapsing())
  assert_true(@library.tag_br.is_whitespace_collapsing())
  assert_false(@library.tag_span.is_whitespace_collapsing())
  assert_true(@library.tag_span.should_group_into_pars())
  assert_false(@library.tag_script.should_group_into_pars())
  assert_false(@library.tag_div.should_group_into_pars())
  inspect(
    @library.CssDisplay::default_for(@library.tag_li).unwrap().as_str(),
    content="list-item",
  )
  inspect(
    @library.CssDisplay::default_for(@library.tag_mathml_math).unwrap().as_str(),
    content="inline math",
  )
  assert_true(
    @library.CssDisplay::default_for(@library.HtmlTag::constant("x-y")) is None,
  )
}

///|
test "html attrs" {
  let err = (s : String) => {
    let _ = @library.HtmlAttr::intern(s) catch {
      @library.HintedError(e) => return e.message
    }
    "ok"
  }
  inspect(err(""), content="attribute name must not be empty")
  inspect(
    err("a=b"),
    content="the character \"=\" is not valid in an attribute name",
  )
  inspect(
    err("a\u{fdd0}"),
    content="the character \"\\u{fdd0}\" is not valid in an attribute name",
  )
  inspect(err("@click.\u{2029}"), content="ok")
  let inner = @library.HtmlAttrs::new()
  inner.push(@library.attr_id, "1")
  inner.push(@library.attr_class, "c")
  let outer = @library.HtmlAttrs::new()
  outer.push(@library.attr_class, "d")
  outer.push(@library.attr_title, "t")
  let folded = @library.Fold::fold(inner, outer)
  inspect(
    folded.pairs().map(p => "\{p.0}=\{p.1}").join(", "),
    content="id=1, class=c, title=t",
  )
  inspect(
    @library.IntoValue::into_value(folded).repr(),
    content="(id: \"1\", class: \"c\", title: \"t\")",
  )
}

///|
test "css properties" {
  let props = @library.CssProperties::new()
  props.push("display", "block")
  props.push("color", "red")
  props.push("b", "1")
  props.push("aa", "2")
  props.push("display", "inline")
  inspect(props.to_inline(), content="aa: 2; b: 1; color: red; display: inline")
  props.remove("b")
  props.remove("zz")
  inspect(props.to_inline(), content="aa: 2; color: red; display: inline")
}

///|
test "to_css" {
  let pt = (x : Double) => @library.Length::from_abs(@library.Abs::pt(x))
  let em = (x : Double) => @library.Length::from_em(@library.Em::new(x))
  inspect(@library.to_css(@library.Abs::pt(12.0)), content="12pt")
  inspect(@library.to_css(@library.Abs::pt(1.23456)), content="1.2346pt")
  inspect(@library.to_css(@library.Abs::pt(0.1 + 0.2)), content="0.3pt")
  inspect(@library.to_css(@library.Em::new(1.5)), content="1.5em")
  inspect(@library.to_css(pt(0.0)), content="0")
  inspect(@library.to_css(pt(-3.0)), content="-3pt")
  inspect(@library.to_css(em(1.0) + pt(2.0)), content="calc(1em + 2pt)")
  inspect(@library.to_css(em(1.0) + pt(-2.0)), content="calc(1em - 2pt)")
  inspect(@library.to_css(em(-1.0) + pt(-2.0)), content="calc(-1em - 2pt)")
  inspect(@library.to_css(@library.Ratio::new(0.5)), content="50%")
  inspect(@library.to_css(@library.Ratio::new(1.0 / 3.0)), content="33.33%")
  inspect(
    @library.to_css(
      @library.Rel::new(@library.Ratio::new(0.5), em(1.0) + pt(2.0)),
    ),
    content="calc(50% + 1em + 2pt)",
  )
  inspect(
    @library.to_css(@library.Rel::new(@library.Ratio::new(0.0), pt(2.0))),
    content="2pt",
  )
  inspect(@library.to_css(@library.Angle::deg(90.0)), content="90deg")
  inspect(
    @library.to_css(@library.CssDisplay::InlineBlock),
    content="inline-block",
  )
  let warnings = []
  let built = @library.CssProperties::build(w => warnings.push(w.message))
    .with_("width", pt(10.0))
    .with_("display", @library.CssDisplay::Block)
    .finish()
  inspect(built.to_inline(), content="display: block; width: 10pt")
  assert_true(warnings.is_empty())
}
