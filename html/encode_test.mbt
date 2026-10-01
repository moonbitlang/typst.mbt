// Helpers for the generated encoder tests (`encode_gen_test.mbt`, produced
// by `oracle/src/bin/gen_html_encode_tests.rs` from upstream's encoder) and
// handwritten tests of the DOM and CSS resolution.

///|
/// An element node with the given (validated) tag and attributes.
fn el(
  tag : String,
  attrs? : Array[(String, String)] = [],
  children? : Array[@html.HtmlNode] = [],
  pre_span? : Bool = false,
) -> @html.HtmlNode {
  let elem = @html.HtmlElement::new(@library.HtmlTag::intern(tag)) catch {
    _ => abort("invalid tag")
  }
  for pair in attrs {
    let attr = @library.HtmlAttr::intern(pair.0) catch {
      _ => abort("invalid attr")
    }
    elem.attrs.push(attr, pair.1)
  }
  elem.children = children
  elem.pre_span = pre_span
  Element(elem)
}

///|
/// A text node.
fn txt(text : String) -> @html.HtmlNode {
  @html.HtmlNode::text(text, @syntax.Span::detached())
}

///|
/// Renders errors like the generator: `error: msg` plus `hint: ..` lines.
fn encode_or_error(root : @html.HtmlElement, pretty : Bool) -> String {
  @html.html_encode(root, pretty~) catch {
    @library.SourceError(diags) => {
      let lines = []
      for d in diags {
        lines.push("error: " + d.message)
        for h in d.hints {
          lines.push("hint: " + h.v)
        }
      }
      lines.join("\n")
    }
  }
}

///|
fn check_encode(
  root : @html.HtmlNode,
  pretty~ : Bool,
  expected : String,
) -> Unit raise {
  guard root is Element(root) else { fail("root must be an element") }
  assert_eq(encode_or_error(root, pretty), expected)
}

///|
test "iter_with_dom_indices" {
  // Upstream's test without the `Tag` node (not ported yet), which
  // receives the index of the preceding node.
  let nodes = [
    txt("A"),
    el("span"),
    txt("hi"),
    txt(" you"),
    txt(" there"),
    el("span"),
    txt(" my"),
    txt(" friend!"),
  ]
  assert_eq(@html.iter_with_dom_indices(nodes).map(p => p.1), [
    0, 1, 2, 2, 2, 3, 4, 4,
  ])
}

///|
test "resolve_inline_styles" {
  let css = @library.CssProperties::new()
    .with_("text-decoration", "underline")
    .with_("display", "inline-block")
  let a = @html.HtmlElement::new(@library.tag_span).with_css(css)
  let b = @html.HtmlElement::new(@library.tag_span)
    .with_attr(@library.attr_style, "color: red")
    .with_css(css)
  let c = @html.HtmlElement::new(@library.tag_span)
    .with_attr(@library.attr_id, "x")
    .with_attr(@library.attr_style, "")
    .with_css(css)
  let d = @html.HtmlElement::new(@library.tag_span).with_attr(
    @library.attr_style, "color: red",
  )
  let root = @html.HtmlElement::new(@library.tag_div).with_children([
    Element(a),
    Element(b),
    Element(c),
    Element(d),
  ])
  @html.resolve_inline_styles(root)
  assert_eq(
    encode_or_error(root, false),
    "<!DOCTYPE html><div>" +
    "<span style=\"display: inline-block; text-decoration: underline\"></span>" +
    "<span style=\"display: inline-block; text-decoration: underline; color: red\"></span>" +
    "<span id=\"x\" style=\"display: inline-block; text-decoration: underline\"></span>" +
    "<span style=\"color: red\"></span>" +
    "</div>",
  )
}
