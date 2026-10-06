///|
/// Parses an SVG like Typst's `SvgImage::new` (`base_options`) and writes
/// it back: `size <width bits> <height bits>` followed by the SVG, or
/// `error <variant>`. Mirrors `tree_case` in `oracle/src/bin/gen_usvg_golden.rs`.
fn corpus_case(input : String) -> String {
  let opts : @usvg.Options = {
    ..@usvg.Options::default(),
    font_family: "",
    resources_dir: None,
    image_href_resolver: {
      resolve_data: @usvg.ImageHrefResolver::default_data_resolver(),
      resolve_string: (_, _) => None,
    },
  }
  let bits = (x : Float) => {
    let h = x.reinterpret_as_uint().to_string(radix=16)
    String::make(8 - h.length(), '0') + h
  }
  try @usvg.Tree::from_data(@utf8.encode(input), opts) catch {
    e =>
      "error " +
      (match e {
        NotAnUtf8Str => "NotAnUtf8Str"
        MalformedGZip => "MalformedGZip"
        ElementsLimitReached => "ElementsLimitReached"
        InvalidSize => "InvalidSize"
        ParsingFailed(e) => "ParsingFailed: \{e.to_string()}"
      })
  } noraise {
    tree =>
      "size \{bits(tree.size().width())} \{bits(tree.size().height())}\n" +
      tree.to_string(@usvg.WriteOptions::default())
  }
}
