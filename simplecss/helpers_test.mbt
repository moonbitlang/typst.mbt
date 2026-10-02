// Dump helpers for `oracle_test.mbt` (same formats as
// `oracle/src/bin/gen_simplecss_tests.rs`).

///|
fn spec(s : @simplecss.Selector) -> String {
  let sp = s.specificity()
  "\{sp[0].to_int()},\{sp[1].to_int()},\{sp[2].to_int()}"
}

///|
fn dump_sheet(sheet : @simplecss.StyleSheet) -> String {
  let out = StringBuilder()
  out.write_string("\{sheet}\n--\n")
  for rule in sheet.rules {
    out.write_string("\{rule.selector}|\{spec(rule.selector)}|")
    for d in rule.declarations {
      out.write_string(
        "\{d.name}=\{d.value}\{if d.important { "!" } else { "" }};",
      )
    }
    out.write_string("\n")
  }
  out.to_string()
}

///|
fn check_eq(
  what : String,
  input : String,
  actual : String,
  expected : String,
) -> Unit raise {
  if actual != expected {
    fail(
      "\{what} \{repr(input)}:\n  expected: \{repr(expected)}\n  actual:   \{repr(actual)}",
    )
  }
}

///|
fn check_sheet(texts : Array[String], expected : String) -> Unit raise {
  let sheet = @simplecss.StyleSheet::new()
  for t in texts {
    sheet.parse_more(t)
  }
  check_eq("sheet", texts.join(" || "), dump_sheet(sheet), expected)
}

///|
fn check_decls(text : String, expected : String) -> Unit raise {
  let out = StringBuilder()
  let t = @simplecss.DeclarationTokenizer::from(text)
  for _ in 0..<100 {
    match t.next() {
      Some(d) =>
        out.write_string(
          "\{d.name}=\{d.value}\{if d.important { " !important" } else { "" }}\n",
        )
      None => break
    }
  }
  check_eq("decls", text, out.to_string(), expected)
}

///|
fn fmt_op(op : @simplecss.AttributeOperator) -> String {
  match op {
    Exists => ""
    Matches(v) => "=\{v}"
    Contains(v) => "~=\{v}"
    StartsWith(v) => "|=\{v}"
  }
}

///|
fn fmt_token(t : @simplecss.SelectorToken) -> String {
  match t {
    UniversalSelector => "*"
    TypeSelector(s) => "type:\{s}"
    ClassSelector(s) => "class:\{s}"
    IdSelector(s) => "id:\{s}"
    AttributeSelector(n, op) => "attr:[\{n}\{fmt_op(op)}]"
    PseudoClass(s) => "pseudo:\{s}"
    LangPseudoClass(s) => "lang:\{s}"
    DescendantCombinator => "desc"
    ChildCombinator => "child"
    AdjacentCombinator => "adj"
  }
}

///|
fn check_sel_tokens(text : String, expected : String) -> Unit raise {
  let out = StringBuilder()
  let t = @simplecss.SelectorTokenizer::from(text)
  for _ in 0..<100 {
    match t.next() {
      Some(Ok(tok)) => out.write_string("\{fmt_token(tok)}\n")
      Some(Err(e)) => out.write_string("err:\{e}\n")
      None => break
    }
  }
  check_eq("selector tokens", text, out.to_string(), expected)
}

///|
fn check_selector(text : String, expected : String) -> Unit raise {
  let actual = match @simplecss.Selector::parse(text) {
    Some(s) => "\{s}|\{spec(s)}"
    None => "None"
  }
  check_eq("selector", text, actual, expected)
}

///|
/// A node of the element tree in `tree_spec`.
struct Node {
  idx : Int
}

///|
impl @simplecss.Element for Node with fn parent_element(self) {
  let parent = tree_spec[self.idx].0
  if parent < 0 {
    None
  } else {
    Some({ idx: parent, })
  }
}

///|
impl @simplecss.Element for Node with fn prev_sibling_element(self) {
  let parent = tree_spec[self.idx].0
  if parent < 0 {
    return None
  }
  for i = self.idx - 1; i >= 0; i = i - 1 {
    if tree_spec[i].0 == parent {
      return Some({ idx: i, })
    }
  }
  None
}

///|
impl @simplecss.Element for Node with fn has_local_name(self, name) {
  tree_spec[self.idx].1 == name
}

///|
impl @simplecss.Element for Node with fn attribute_matches(
  self,
  local_name,
  operator,
) {
  for attr in tree_spec[self.idx].2 {
    if attr.0 == local_name {
      return operator.matches(attr.1)
    }
  }
  false
}

///|
impl @simplecss.Element for Node with fn pseudo_class_matches(self, class) {
  match class {
    FirstChild => @simplecss.Element::prev_sibling_element(self) is None
    Lang(l) =>
      @simplecss.Element::attribute_matches(self, "lang", StartsWith(l))
    Hover => @simplecss.Element::attribute_matches(self, "hover", Exists)
    _ => false
  }
}

///|
fn check_match(text : String, expected : String) -> Unit raise {
  let actual = match @simplecss.Selector::parse(text) {
    Some(s) => {
      let ids = []
      for i in 0..<tree_spec.length() {
        if s.matches(Node::{ idx: i, }) {
          ids.push(tree_spec[i].2[0].1)
        }
      }
      ids.join(",")
    }
    None => "None"
  }
  check_eq("match", text, actual, expected)
}

///|
fn check_attr_op(
  op : @simplecss.AttributeOperator,
  value : String,
  expected : Bool,
) -> Unit raise {
  check_eq(
    "attr op \{fmt_op(op)}",
    value,
    op.matches(value).to_string(),
    expected.to_string(),
  )
}

///|
fn check_error(e : @simplecss.CssError, expected : String) -> Unit raise {
  check_eq("error", "", e.to_string(), expected)
}

///|
fn[T : Show] check_display(v : T, expected : String) -> Unit raise {
  check_eq("display", "", v.to_string(), expected)
}
