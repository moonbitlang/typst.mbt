// Port of `usvg` 0.47.0 `src/parser/switch.rs`.

///|
// Full list can be found here: https://www.w3.org/TR/SVG11/feature.html
let features : Array[String] = [
  "http://www.w3.org/TR/SVG11/feature#SVGDOM-static", "http://www.w3.org/TR/SVG11/feature#SVG-static",
  "http://www.w3.org/TR/SVG11/feature#CoreAttribute", // no xml:base and xml:lang
   "http://www.w3.org/TR/SVG11/feature#Structure", "http://www.w3.org/TR/SVG11/feature#BasicStructure",
  "http://www.w3.org/TR/SVG11/feature#ContainerAttribute", // `enable-background`
   "http://www.w3.org/TR/SVG11/feature#ConditionalProcessing", "http://www.w3.org/TR/SVG11/feature#Image",
  "http://www.w3.org/TR/SVG11/feature#Style",
  // "http://www.w3.org/TR/SVG11/feature#ViewportAttribute", // `clip` and `overflow`, not yet
   "http://www.w3.org/TR/SVG11/feature#Shape", "http://www.w3.org/TR/SVG11/feature#Text",
  "http://www.w3.org/TR/SVG11/feature#BasicText", "http://www.w3.org/TR/SVG11/feature#PaintAttribute", // no color-interpolation and color-rendering
   "http://www.w3.org/TR/SVG11/feature#BasicPaintAttribute", // no color-interpolation
   "http://www.w3.org/TR/SVG11/feature#OpacityAttribute", "http://www.w3.org/TR/SVG11/feature#GraphicsAttribute",
  "http://www.w3.org/TR/SVG11/feature#BasicGraphicsAttribute", "http://www.w3.org/TR/SVG11/feature#Marker",
  // "http://www.w3.org/TR/SVG11/feature#ColorProfile", // not yet
   "http://www.w3.org/TR/SVG11/feature#Gradient", "http://www.w3.org/TR/SVG11/feature#Pattern",
  "http://www.w3.org/TR/SVG11/feature#Clip", "http://www.w3.org/TR/SVG11/feature#BasicClip",
  "http://www.w3.org/TR/SVG11/feature#Mask", "http://www.w3.org/TR/SVG11/feature#Filter",
  "http://www.w3.org/TR/SVG11/feature#BasicFilter",
  // only xlink:href
   "http://www.w3.org/TR/SVG11/feature#XlinkAttribute",
  // "http://www.w3.org/TR/SVG11/feature#Font",
  // "http://www.w3.org/TR/SVG11/feature#BasicFont",
]

///|
fn switch_convert(
  node : SvgNode,
  state : State,
  cache : Cache,
  parent : Group,
) -> Unit? {
  guard node.children().find_first(n => is_condition_passed(n, state.opt))
    is Some(child) else {
    return None
  }
  if convert_group(node, state, false, cache, parent, (cache, g) => {
      convert_element(child, state, cache, g)
    })
    is Some(g) {
    parent.children.push(Group(g))
  }
  Some(())
}

///|
fn is_condition_passed(node : SvgNode, opt : Options) -> Bool {
  if !node.is_element() {
    return false
  }
  if node.has_attribute(AId::RequiredExtensions) {
    return false
  }

  // 'The value is a list of feature strings, with the individual values separated by white space.
  // Determines whether all of the named features are supported by the user agent.
  // Only feature strings defined in the Feature String appendix are allowed.
  // If all of the given features are supported, then the attribute evaluates to true;
  // otherwise, the current element and its children are skipped and thus will not be rendered.'
  let required_features : String? = node.attribute(AId::RequiredFeatures)
  if required_features is Some(features_str) {
    for feature in features_str.split(" ") {
      let feature = feature.to_string()
      if !features.contains(feature) {
        return false
      }
    }
  }
  if !is_valid_sys_lang(node, opt) {
    return false
  }
  true
}

///|
/// SVG spec 5.8.5
fn is_valid_sys_lang(node : SvgNode, opt : Options) -> Bool {
  // 'The attribute value is a comma-separated list of language names
  // as defined in BCP 47.'
  //
  // But we support only simple cases like `en` or `en-US`.
  // No one really uses this, especially with complex BCP 47 values.
  let langs : String? = node.attribute(AId::SystemLanguage)
  if langs is Some(langs) {
    let mut has_match = false
    for lang in langs.split(",") {
      let lang = rust_trim(lang.to_string())

      // 'Evaluates to `true` if one of the languages indicated by user preferences exactly
      // equals one of the languages given in the value of this parameter.'
      if opt.languages.iter().any(v => v == lang) {
        has_match = true
        break
      }

      // 'If one of the languages indicated by user preferences exactly equals a prefix
      // of one of the languages given in the value of this parameter such that
      // the first tag character following the prefix is `-`.'
      if lang.find("-") is Some(idx) {
        let lang_prefix = lang.unsafe_substring(start=0, end=idx)
        if opt.languages.iter().any(v => v == lang_prefix) {
          has_match = true
          break
        }
      }
    }
    has_match
  } else {
    true
  }
}
