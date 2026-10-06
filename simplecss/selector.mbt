// Port of `simplecss` 0.2.2 `src/selector.rs`.

///|
/// An attribute selector operator.
pub(all) enum AttributeOperator {
  /// `[attr]`
  Exists
  /// `[attr=value]`
  Matches(String)
  /// `[attr~=value]`
  Contains(String)
  /// `[attr|=value]`
  StartsWith(String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AttributeOperator with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend AttributeOperator with @debug.Debug::{to_repr}

///|
/// Checks that value is matching the operator.
pub fn AttributeOperator::matches(
  self : AttributeOperator,
  value : String,
) -> Bool {
  match self {
    Exists => true
    Matches(v) => value == v
    Contains(v) => value.split(" ").any(s => s == v)
    StartsWith(v) =>
      // exactly `v` or beginning with `v` immediately followed by `-`
      if value == v {
        true
      } else if value.has_prefix(v) {
        value.length() > v.length() && value.code_unit_at(v.length()) == '-'
      } else {
        false
      }
  }
}

///|
/// A pseudo-class.
pub(all) enum PseudoClass {
  FirstChild
  Link
  Visited
  Hover
  Active
  Focus
  Lang(String)
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PseudoClass with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PseudoClass with @debug.Debug::{to_repr}

///|
/// Upstream `Display`.
pub impl Show for PseudoClass with fn output(self, logger) {
  match self {
    FirstChild => logger.write_string("first-child")
    Link => logger.write_string("link")
    Visited => logger.write_string("visited")
    Hover => logger.write_string("hover")
    Active => logger.write_string("active")
    Focus => logger.write_string("focus")
    Lang(lang) => logger.write_string("lang(\{lang})")
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PseudoClass with Show::{to_string, output}

///|
/// A trait to query an element node metadata.
pub(open) trait Element {
  /// Returns a parent element.
  fn parent_element(Self) -> Self?
  /// Returns a previous sibling element.
  fn prev_sibling_element(Self) -> Self?
  /// Checks that the element has a specified local name.
  fn has_local_name(Self, String) -> Bool
  /// Checks that the element has a specified attribute.
  fn attribute_matches(Self, String, AttributeOperator) -> Bool
  /// Checks that the element matches a specified pseudo-class.
  fn pseudo_class_matches(Self, PseudoClass) -> Bool
}

///|
priv enum SimpleSelectorType {
  Type(String)
  Universal
} derive(Debug)

///|
priv enum SubSelector {
  Attribute(String, AttributeOperator)
  PseudoClass(PseudoClass)
} derive(Debug)

///|
priv struct SimpleSelector {
  kind : SimpleSelectorType
  subselectors : Array[SubSelector]
} derive(Debug)

///|
priv enum Combinator {
  None
  Descendant
  Child
  AdjacentSibling
} derive(Eq, Debug)

///|
priv struct Component {
  /// A combinator that precede the selector.
  combinator : Combinator
  selector : SimpleSelector
} derive(Debug)

///|
/// A selector.
struct Selector {
  components : Array[Component]
} derive(Debug)

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Selector with @debug.Debug::{to_repr}

///|
/// Parses a selector from a string.
///
/// Parsing will be stopped at EOF, `,` or `{`.
pub fn Selector::parse(text : String) -> Selector? {
  parse_selector(@utf8.encode(text)).0
}

///|
/// Compute the selector's specificity.
///
/// Cf. <https://www.w3.org/TR/selectors/#specificity>.
pub fn Selector::specificity(self : Selector) -> FixedArray[Byte] {
  let spec = FixedArray::make(3, b'\x00')
  for component in self.components {
    let selector = component.selector
    if selector.kind is Type(_) {
      spec[2] = saturating_add(spec[2])
    }
    for sub in selector.subselectors {
      match sub {
        Attribute("id", _) => spec[0] = saturating_add(spec[0])
        _ => spec[1] = saturating_add(spec[1])
      }
    }
  }
  spec
}

///|
fn saturating_add(b : Byte) -> Byte {
  if b == b'\xFF' {
    b
  } else {
    b + 1
  }
}

///|
/// Checks that the provided element matches the current selector.
pub fn[E : Element] Selector::matches(self : Selector, element : E) -> Bool {
  if self.components.is_empty() {
    abort("selector must not be empty")
  }
  if self.components[0].combinator != Combinator::None {
    abort("the first component must not have a combinator")
  }
  self.matches_impl(self.components.length() - 1, element)
}

///|
fn[E : Element] Selector::matches_impl(
  self : Selector,
  idx : Int,
  element : E,
) -> Bool {
  let component = self.components[idx]
  if !match_selector(component.selector, element) {
    return false
  }
  match component.combinator {
    Descendant => {
      let mut parent = element.parent_element()
      while parent is Some(e) {
        if self.matches_impl(idx - 1, e) {
          return true
        }
        parent = e.parent_element()
      }
      false
    }
    Child => {
      if element.parent_element() is Some(parent) {
        if self.matches_impl(idx - 1, parent) {
          return true
        }
      }
      false
    }
    AdjacentSibling => {
      if element.prev_sibling_element() is Some(prev) {
        if self.matches_impl(idx - 1, prev) {
          return true
        }
      }
      false
    }
    None => true
  }
}

///|
fn[E : Element] match_selector(selector : SimpleSelector, element : E) -> Bool {
  if selector.kind is Type(ident) {
    if !element.has_local_name(ident) {
      return false
    }
  }
  for sub in selector.subselectors {
    match sub {
      Attribute(name, operator) =>
        if !element.attribute_matches(name, operator) {
          return false
        }
      PseudoClass(class) =>
        if !element.pseudo_class_matches(class) {
          return false
        }
    }
  }
  true
}

///|
fn add_sub(
  components : Array[Component],
  combinator : Ref[Combinator],
  sub : SubSelector,
) -> Unit {
  if combinator.val == Combinator::None && !components.is_empty() {
    components.last().unwrap().selector.subselectors.push(sub)
  } else {
    components.push({
      selector: { kind: Universal, subselectors: [sub], },
      combinator: combinator.val,
    })
    combinator.val = Combinator::None
  }
}

///|
/// Upstream `selector::parse`: the parsed selector (if any) and the number of
/// consumed bytes.
fn parse_selector(text : BytesView) -> (Selector?, Int) {
  let components : Array[Component] = []
  let combinator : Ref[Combinator] = { val: Combinator::None, }
  let tokenizer = SelectorTokenizer::from_bytes(text)
  while tokenizer.next() is Some(token) {
    let token = match token {
      Ok(t) => t
      Err(_) => return (None, tokenizer.stream.pos())
    }
    match token {
      UniversalSelector => {
        components.push({
          selector: { kind: Universal, subselectors: [], },
          combinator: combinator.val,
        })
        combinator.val = Combinator::None
      }
      TypeSelector(ident) => {
        components.push({
          selector: { kind: Type(ident), subselectors: [], },
          combinator: combinator.val,
        })
        combinator.val = Combinator::None
      }
      ClassSelector(ident) =>
        add_sub(components, combinator, Attribute("class", Contains(ident)))
      IdSelector(id) =>
        add_sub(components, combinator, Attribute("id", Matches(id)))
      AttributeSelector(name, op) =>
        add_sub(components, combinator, Attribute(name, op))
      PseudoClass(ident) => {
        let class : PseudoClass = match ident {
          "first-child" => FirstChild
          "link" => Link
          "visited" => Visited
          "hover" => Hover
          "active" => Active
          "focus" => Focus
          _ => return (None, tokenizer.stream.pos())
        }

        // TODO: duplicates
        // TODO: order

        add_sub(components, combinator, PseudoClass(class))
      }
      LangPseudoClass(lang) =>
        add_sub(components, combinator, PseudoClass(Lang(lang)))
      DescendantCombinator => combinator.val = Descendant
      ChildCombinator => combinator.val = Child
      AdjacentCombinator => combinator.val = AdjacentSibling
    }
  }
  if components.is_empty() {
    (None, tokenizer.stream.pos())
  } else if components[0].combinator != Combinator::None {
    (None, tokenizer.stream.pos())
  } else {
    (Some({ components, }), tokenizer.stream.pos())
  }
}

///|
/// Upstream `Display`.
pub impl Show for Selector with fn output(self, logger) {
  for component in self.components {
    match component.combinator {
      Descendant => logger.write_string(" ")
      Child => logger.write_string(" > ")
      AdjacentSibling => logger.write_string(" + ")
      None => ()
    }
    match component.selector.kind {
      Universal => logger.write_string("*")
      Type(ident) => logger.write_string(ident)
    }
    for sel in component.selector.subselectors {
      match sel {
        Attribute(name, operator) =>
          match operator {
            Exists => logger.write_string("[\{name}]")
            Matches(value) => logger.write_string("[\{name}='\{value}']")
            Contains(value) => logger.write_string("[\{name}~='\{value}']")
            StartsWith(value) => logger.write_string("[\{name}|='\{value}']")
          }
        PseudoClass(class) => logger.write_string(":\{class}")
      }
    }
  }
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Selector with Show::{to_string, output}

///|
/// A selector token.
pub(all) enum SelectorToken {
  /// `*`
  UniversalSelector
  /// `div`
  TypeSelector(String)
  /// `.class`
  ClassSelector(String)
  /// `#id`
  IdSelector(String)
  /// `[color=red]`
  AttributeSelector(String, AttributeOperator)
  /// `:first-child`
  PseudoClass(String)
  /// `:lang(en)`
  LangPseudoClass(String)
  /// `a b`
  DescendantCombinator
  /// `a > b`
  ChildCombinator
  /// `a + b`
  AdjacentCombinator
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SelectorToken with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SelectorToken with @debug.Debug::{to_repr}

///|
/// A selector tokenizer.
///
/// ```mbt check
/// test {
///   let t = @simplecss.SelectorTokenizer::from("div > p:first-child")
///   assert_eq(t.next(), Some(Ok(TypeSelector("div"))))
///   assert_eq(t.next(), Some(Ok(ChildCombinator)))
///   assert_eq(t.next(), Some(Ok(TypeSelector("p"))))
///   assert_eq(t.next(), Some(Ok(PseudoClass("first-child"))))
///   assert_eq(t.next(), None)
/// }
/// ```
pub struct SelectorTokenizer {
  priv stream : Stream
  priv mut after_combinator : Bool
  priv mut finished : Bool
}

///|
pub fn SelectorTokenizer::from(text : String) -> SelectorTokenizer {
  SelectorTokenizer::from_bytes(@utf8.encode(text))
}

///|
fn SelectorTokenizer::from_bytes(text : BytesView) -> SelectorTokenizer {
  { stream: Stream::new(text), after_combinator: true, finished: false, }
}

///|
pub fn SelectorTokenizer::iter(
  self : SelectorTokenizer,
) -> Iter[Result[SelectorToken, CssError]] {
  Iter::new(() => self.next())
}

///|
pub fn SelectorTokenizer::next(
  self : SelectorTokenizer,
) -> Result[SelectorToken, CssError]? {
  if self.finished || self.stream.at_end() {
    if self.after_combinator {
      self.after_combinator = false
      return Some(Err(SelectorMissing))
    }
    return None
  }
  match self.stream.curr_byte_unchecked() {
    b'*' => {
      if !self.after_combinator {
        self.finished = true
        return Some(Err(UnexpectedSelector))
      }
      self.after_combinator = false
      self.stream.advance(1)
      Some(Ok(UniversalSelector))
    }
    b'#' => {
      self.after_combinator = false
      self.stream.advance(1)
      let ident = self.stream.consume_ident() catch { e => return self.fail(e) }
      Some(Ok(IdSelector(ident)))
    }
    b'.' => {
      self.after_combinator = false
      self.stream.advance(1)
      let ident = self.stream.consume_ident() catch { e => return self.fail(e) }
      Some(Ok(ClassSelector(ident)))
    }
    b'[' => {
      self.after_combinator = false
      self.stream.advance(1)
      let ident = self.stream.consume_ident() catch { e => return self.fail(e) }
      let curr = self.stream.curr_byte() catch { e => return self.fail(e) }
      let op = match curr {
        b']' => Exists
        b'=' => {
          self.stream.advance(1)
          let value = self.stream.consume_string() catch {
            e => return self.fail(e)
          }
          Matches(value)
        }
        b'~' => {
          self.stream.advance(1)
          self.stream.consume_byte(b'=') catch {
            e => return self.fail(e)
          }
          let value = self.stream.consume_string() catch {
            e => return self.fail(e)
          }
          Contains(value)
        }
        b'|' => {
          self.stream.advance(1)
          self.stream.consume_byte(b'=') catch {
            e => return self.fail(e)
          }
          let value = self.stream.consume_string() catch {
            e => return self.fail(e)
          }
          StartsWith(value)
        }
        _ => {
          self.finished = true
          return Some(Err(InvalidAttributeSelector))
        }
      }
      self.stream.consume_byte(b']') catch {
        e => return self.fail(e)
      }
      Some(Ok(AttributeSelector(ident, op)))
    }
    b':' => {
      self.after_combinator = false
      self.stream.advance(1)
      let ident = self.stream.consume_ident() catch { e => return self.fail(e) }
      if ident == "lang" {
        self.stream.consume_byte(b'(') catch {
          e => return self.fail(e)
        }
        let lang = rust_trim(self.stream.consume_bytes(c => c != b')'))
        self.stream.consume_byte(b')') catch {
          e => return self.fail(e)
        }
        if lang.is_empty() {
          self.finished = true
          return Some(Err(InvalidLanguagePseudoClass))
        }
        Some(Ok(LangPseudoClass(lang)))
      } else {
        Some(Ok(PseudoClass(ident)))
      }
    }
    b'>' => {
      if self.after_combinator {
        self.after_combinator = false
        self.finished = true
        return Some(Err(UnexpectedCombinator))
      }
      self.stream.advance(1)
      self.after_combinator = true
      Some(Ok(ChildCombinator))
    }
    b'+' => {
      if self.after_combinator {
        self.after_combinator = false
        self.finished = true
        return Some(Err(UnexpectedCombinator))
      }
      self.stream.advance(1)
      self.after_combinator = true
      Some(Ok(AdjacentCombinator))
    }
    b' ' | b'\t' | b'\n' | b'\r' | b'\x0C' => {
      self.stream.skip_spaces()
      if self.after_combinator {
        return self.next()
      }
      while self.stream.curr_byte_ok() == Some(b'/') {
        self.stream.skip_comment() catch {
          e => return self.fail(e)
        }
        self.stream.skip_spaces()
      }
      match self.stream.curr_byte_ok() {
        Some(b'>') | Some(b'+') | Some(b',') | Some(b'{') | None => self.next()
        _ => {
          if self.after_combinator {
            self.after_combinator = false
            self.finished = true
            return Some(Err(UnexpectedSelector))
          }
          self.after_combinator = true
          Some(Ok(DescendantCombinator))
        }
      }
    }
    b'/' => {
      if self.stream.next_byte_ok() == Some(b'*') {
        self.stream.skip_comment() catch {
          e => return self.fail(e)
        }
      } else {
        self.finished = true
      }
      self.next()
    }
    b',' | b'{' => {
      self.finished = true
      self.next()
    }
    _ => {
      let ident = self.stream.consume_ident() catch { e => return self.fail(e) }
      if !self.after_combinator {
        self.finished = true
        return Some(Err(UnexpectedSelector))
      }
      self.after_combinator = false
      Some(Ok(TypeSelector(ident)))
    }
  }
}

///|
/// Upstream's `try2!` error path.
fn SelectorTokenizer::fail(
  self : SelectorTokenizer,
  e : CssError,
) -> Result[SelectorToken, CssError]? {
  self.finished = true
  Some(Err(e))
}
