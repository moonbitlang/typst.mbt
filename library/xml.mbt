// Port of `typst-library/src/loading/xml.rs`.

///|
/// Reads structured data from an XML file.
///
/// The XML file is parsed into an array of dictionaries and strings. XML
/// nodes can be elements or strings. Elements are represented as
/// dictionaries with the following keys:
///
/// - `tag`: The name of the element as a string.
/// - `attrs`: A dictionary of the element's attributes as strings.
/// - `children`: An array of the element's child nodes.
fn impl_xml(
  engine : Engine,
  source_ : @syntax.Spanned[DataSource],
) -> Value raise SourceError {
  let loaded = source_.v.load(source_.span, engine.world)
  let text = within(loaded, () => bytes_as_str(loaded.data))
  let document = within(loaded, () => {
    @xml.Document::parse_with_options(text, {
      ..@xml.ParsingOptions::default(),
      allow_dtd: true,
    }) catch {
      error => raise LoadErr(format_xml_error(error))
    }
  })
  convert_xml(document.root())
}

///|
/// Convert an XML node to a Typst value.
fn convert_xml(node : @xml.Node) -> Value {
  if node.is_text() {
    return Str(node.text().unwrap_or(""))
  }
  let children = Arr::from_array(node.children().map(convert_xml))
  if node.is_root() {
    return Array(children)
  }
  let ns = match node.tag_name().namespace_() {
    Some(ns) => Value::Str(ns)
    None => None
  }
  let tag = node.tag_name().name()
  let attrs = Dict::new()
  for attr in node.attributes() {
    attrs.insert(attr.name(), Str(attr.value()))
  }
  Dict(
    Dict::from_pairs([
      ("namespace", ns),
      ("tag", Str(tag)),
      ("attrs", Dict(attrs)),
      ("children", Array(children)),
    ]),
  )
}

///|
/// Format the user-facing XML error message.
fn format_xml_error(error : @xml.XmlError) -> LoadError {
  format_xml_like_error("XML", error)
}
