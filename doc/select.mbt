// Selectors and views (docs/edsl-design.md, section 9).

///|
/// A selector whose matches are seen through the view type `W`.
pub struct Selector[W] {
  priv value : Value
  priv wrap : (@library.Content) -> W
}

///|
fn[W] Selector::new(
  value : Value,
  wrap : (@library.Content) -> W,
) -> Selector[W] {
  { value, wrap, }
}

///|
pub impl[W] ToValue for Selector[W] with fn to_value(self) {
  self.value
}

///|
/// The namespace of selector constructors (`Select::heading()`, ...).
#warnings("-struct_never_constructed")
pub struct Select {}

///|
/// A view of engine content: the exact content the engine handed to a
/// callback. As content it re-emits that content unchanged.
pub struct ContentView {
  priv content : @library.Content
}

///|
fn ContentView::new(content : @library.Content) -> ContentView {
  { content, }
}

///|
pub impl IntoContent for ContentView with fn into_content(self) {
  Content::of(NEngine(self.content))
}

///|
/// The qualified name of the content's element function is not stored by
/// the engine; this is its plain name (`heading`, `cell`).
pub fn ContentView::func_name(self : ContentView) -> String {
  self.content.elem().name()
}

///|
/// A field of the content as an engine value (as `it.field` in Typst).
pub fn ContentView::field(
  self : ContentView,
  name : String,
) -> @library.Value raise @library.HintedError {
  self.content.field_by_name(name)
}

///|
/// A content field as a view.
pub fn ContentView::content_field(
  self : ContentView,
  name : String,
) -> ContentView raise @library.HintedError {
  let value : @library.Content = self.content.field_by_name(name).cast()
  ContentView::new(value)
}

///|
/// The plain text of the content.
pub fn ContentView::text(self : ContentView) -> String {
  self.content.plain_text()
}

///|
/// The name of the content's label, if any.
pub fn ContentView::label(self : ContentView) -> String? {
  self.content.label().map(l => l.resolve())
}

///|
/// The engine content itself.
pub fn ContentView::engine(self : ContentView) -> @library.Content {
  self.content
}

///|
/// Engine content as a description (e.g. a function's content result).
pub fn Content::engine(content : @library.Content) -> Content {
  Content::of(NEngine(content))
}

///|
/// `<name>`: the element with this label.
pub fn Select::label(name : String) -> Selector[ContentView] {
  Selector::new(Value::label(name), ContentView::new)
}

///|
/// Text equal to `text` (a string selector, as in `show "x": ..`).
pub fn Select::literal(text : String) -> Selector[ContentView] {
  Selector::new(Value::str(text), ContentView::new)
}

///|
/// Text matching the regular expression (`regex(pattern)`).
pub fn Select::regex(pattern : String) -> Selector[ContentView] {
  Selector::new(
    Value::native(@library.native_regex_construct(), [Value::str(pattern)]),
    ContentView::new,
  )
}

///|
/// The elements of the function with the qualified name `path`
/// (`"table.cell"`), optionally filtered by field values
/// (`path.where(..)`).
pub fn Select::elem(
  path : String,
  where_? : Array[(String, Value)] = [],
) -> Selector[ContentView] {
  let func = Value::global(path)
  let value = if where_.is_empty() {
    func
  } else {
    Value::native(@library.native_func_where(), [func], named=where_)
  }
  Selector::new(value, ContentView::new)
}

///|
/// The selector of an element function, filtered by the given fields.
fn[W] elem_selector(
  elem : @library.Element,
  where_ : Array[(String, Value)],
  wrap : (@library.Content) -> W,
) -> Selector[W] {
  let func = Value::engine(@library.Value::Func(@library.Func::element(elem)))
  let value = if where_.is_empty() {
    func
  } else {
    Value::native(@library.native_func_where(), [func], named=where_)
  }
  Selector::new(value, wrap)
}

///|
/// Matches of either selector (`selector(a).or(b)`).
pub fn[A, B] Selector::or(
  self : Selector[A],
  other : Selector[B],
) -> Selector[ContentView] {
  Selector::new(
    Value::native(@library.native_selector_or(), [
      Value::native(@library.native_selector_construct(), [self.value]),
      other.value,
    ]),
    ContentView::new,
  )
}

///|
/// Matches of both selectors (`selector(a).and(b)`).
pub fn[A, B] Selector::and_(
  self : Selector[A],
  other : Selector[B],
) -> Selector[ContentView] {
  Selector::new(
    Value::native(@library.native_selector_and(), [
      Value::native(@library.native_selector_construct(), [self.value]),
      other.value,
    ]),
    ContentView::new,
  )
}
