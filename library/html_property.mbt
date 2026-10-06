// Port of `typst-html/src/property.rs`: typed CSS properties.
//
// Sourced from the HTML and CSS specifications, but also sometimes informed
// by real-world user agent style sheets:
// - <https://searchfox.org/firefox-main/rev/33682acc1fa0db34ac826b143048db28ee9f16a6/layout/style/res/>
// - <https://source.chromium.org/chromium/chromium/src/+/main:third_party/blink/renderer/core/html/resources/html.css;drc=25f499fd1faae687309ba0a07b23798efcc099a8>
//
// Upstream `property::Display` is `CssDisplay` here.

///|
/// A value for the CSS `display` property.
///
/// <https://www.w3.org/TR/css-display-3/#propdef-display>
/// <https://www.w3.org/TR/mathml-core/#new-display-math-value>
pub(all) enum CssDisplay {
  // <display-outside>
  Block
  Inline
  RunIn

  // <display-inside>
  Flow
  FlowRoot
  Table
  Flex
  Grid
  Ruby

  // <display-listitem>
  ListItem

  // <display-internal>
  TableRowGroup
  TableHeaderGroup
  TableFooterGroup
  TableRow
  TableCell
  TableColumnGroup
  TableColumn
  TableCaption
  RubyBase
  RubyText

  // <display-box>
  Contents
  /// (upstream `None`)
  None_

  // <display-legacy>
  InlineBlock
  InlineTable
  InlineFlex
  InlineGrid

  // MathML Core
  InlineMath
  BlockMath
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssDisplay with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssDisplay with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CssDisplay with @debug.Debug::{to_repr}

///|
/// Returns the default value for the given tag as defined by the user agent
/// styles in § 15 of the HTML spec.
pub fn CssDisplay::default_for(tag : HtmlTag) -> CssDisplay? {
  Some(
    match tag.resolve() {
      // § 15.3.1 Hidden elements.
      "area" => None_
      "base" => None_
      "datalist" => None_
      "head" => None_
      "link" => None_
      "meta" => None_
      "rp" => None_
      "script" => None_
      "style" => None_
      "template" => None_
      "title" => None_

      // § 15.3.2 The page.
      "html" => Block
      "body" => Block

      // § 15.3.3 Flow content.
      "address" => Block
      "blockquote" => Block
      "dialog" => Block
      "div" => Block
      "figure" => Block
      "figcaption" => Block
      "footer" => Block
      "form" => Block
      "header" => Block
      "hr" => Block
      "legend" => Block
      "main" => Block
      "p" => Block
      "pre" => Block
      "search" => Block
      "slot" => Contents

      // § 15.3.4 Phrasing content.
      "ruby" => Ruby
      "rt" => RubyText

      // § 15.3.6 Sections and headings.
      "article" => Block
      "aside" => Block
      "h1" => Block
      "h2" => Block
      "h3" => Block
      "h4" => Block
      "h5" => Block
      "h6" => Block
      "hgroup" => Block
      "nav" => Block
      "section" => Block

      // § 15.3.7 Lists.
      "dd" => Block
      "dl" => Block
      "dt" => Block
      "menu" => Block
      "ol" => Block
      "ul" => Block
      "li" => ListItem

      // § 15.3.8 Tables.
      "table" => Table
      "thead" => TableHeaderGroup
      "tbody" => TableRowGroup
      "tfoot" => TableFooterGroup
      "tr" => TableRow
      "th" => TableCell
      "td" => TableCell
      "caption" => TableCaption
      "col" => TableColumn
      "colgroup" => TableColumnGroup

      // § 15.3.10 Form controls.
      "input" => InlineBlock
      "button" => InlineBlock

      // § 15.3.12 The fieldset and legend elements.
      "fieldset" => Block

      // § 15.5.5 The details and summary elements.
      "details" => Block
      "summary" => Block

      // § 15.5.14 The meter element.
      //
      // Defined in free text rather than in a CSS snippet.
      "meter" => InlineBlock

      // § 15.5.15 The progress element.
      //
      // Defined in free text rather than in a CSS snippet.
      "progress" => InlineBlock

      // § 15.5.16 The select element.
      //
      // The spec is silent on `option` and only specifies a value for
      // `select optgroup`, but UA style sheets specify `display: block`.
      "select" => InlineBlock
      "option" => Block
      "optgroup" => Block

      // § 15.5.17 The textarea element.
      //
      // Defined in free text rather than in a CSS snippet.
      "textarea" => InlineBlock

      // `display: inline` is the default of the CSS property.
      "a" => Inline
      "abbr" => Inline
      "audio" => Inline
      "b" => Inline
      "bdi" => Inline
      "bdo" => Inline
      "br" => Inline
      "canvas" => Inline
      "cite" => Inline
      "code" => Inline
      "data" => Inline
      "del" => Inline
      "dfn" => Inline
      "em" => Inline
      "embed" => Inline
      "i" => Inline
      "iframe" => Inline
      "img" => Inline
      "ins" => Inline
      "kbd" => Inline
      "label" => Inline
      "map" => Inline
      "mark" => Inline
      "noscript" => Inline
      "object" => Inline
      "output" => Inline
      "picture" => Inline
      "q" => Inline
      "s" => Inline
      "samp" => Inline
      "small" => Inline
      "source" => Inline
      "span" => Inline
      "strong" => Inline
      "sub" => Inline
      "sup" => Inline
      "time" => Inline
      "track" => Inline
      "u" => Inline
      "var" => Inline
      "video" => Inline
      "wbr" => Inline

      // MathML Core elements.
      "math" => InlineMath
      "mtable" => InlineTable
      "mtr" => TableRow
      "mtd" => TableCell

      // We don't make any assumptions about unknown elements.
      _ => return None
    },
  )
}

///|
/// Whether this is any of the `table(-.*)?` display modes.
pub fn CssDisplay::is_tabular(self : CssDisplay) -> Bool {
  self
  is (Table
  | TableCaption
  | TableColumn
  | TableColumnGroup
  | TableRow
  | TableRowGroup
  | TableHeaderGroup
  | TableFooterGroup
  | TableCell)
}

///|
/// The CSS identifier of the value.
pub fn CssDisplay::as_str(self : CssDisplay) -> String {
  match self {
    Block => "block"
    Inline => "inline"
    RunIn => "run-in"
    Flow => "flow"
    FlowRoot => "flow-root"
    Table => "table"
    Flex => "flex"
    Grid => "grid"
    Ruby => "ruby"
    ListItem => "list-item"
    TableRowGroup => "table-row-group"
    TableHeaderGroup => "table-header-group"
    TableFooterGroup => "table-footer-group"
    TableRow => "table-row"
    TableCell => "table-cell"
    TableColumnGroup => "table-column-group"
    TableColumn => "table-column"
    TableCaption => "table-caption"
    RubyBase => "ruby-base"
    RubyText => "ruby-text"
    Contents => "contents"
    None_ => "none"
    InlineBlock => "inline-block"
    InlineTable => "inline-table"
    InlineFlex => "inline-flex"
    InlineGrid => "inline-grid"
    InlineMath => "inline math"
    BlockMath => "block math"
  }
}

// Non-standard sets (upstream `tag.rs`).

///|
/// Whether HTML whitespace next to an element with this tag will be collapsed
/// (assuming normal user agent styles). (upstream `tag::is_whitespace_collapsing`)
pub fn HtmlTag::is_whitespace_collapsing(self : HtmlTag) -> Bool {
  // TODO: Reconsider this check. What about e.g. tables?
  CssDisplay::default_for(self) == Some(Block) || self == tag_br
}

///|
/// Whether we group this kind of HTML element into paragraphs _if_ paragraphs
/// are forced in some way (either through being top-level or due to being in
/// the same flow as a Typst-native `block` element or `parbreak`). When using
/// solely the low-level HTML API, no paragraphs are ever forced.
/// (upstream `tag::should_group_into_pars`)
///
/// The maximal set of tags we can choose here is HTML "phrasing content" as
/// that is the content model of `<p>`. Most elements that are phrasing content
/// are also reasonable to group into paragraphs. However, it's a bit more
/// subtle:
///
/// - A few elements that are phrasing content are `display: none` through the
///   user agent style sheet, e.g. `<script>`. These are called hidden content.
///   It does not make sense to group them into paragraphs as they are not
///   visible and also not really used in prose. We exclude those.
///
/// - A few elements that are phrasing content are actually kind of "generic".
///   They can be used in paragraphs and may then also only contain phrasing
///   content or they may be used directly in the block flow and then they may
///   also include arbitrary flow content. This includes the `<a>`, `<ins>`,
///   `<del>`, `<noscript>`, and `<map>` elements, which have a "transparent"
///   content model.
///
///   It would make sense for these elements to group into paragraphs only if
///   their contents themselves are fully groupable. This would require
///   realizing their bodies to check what they contain, in a way that is not
///   unlike measurement in layouting. We currently unconditionally group these
///   elements, but we might want to do the smarter thing in the future.
///
///   There are a few more elements that have a "transparent" content model, but
///   their contents are only used as fallback content. This includes `<video>`,
///   `<audio>`, `<canvas>`, `<object>`, and `<slot>`. Sacrificing consistency
///   of the multi-media elements with `<img>` to make their grouping behavior
///   depend on their _fallback_ body seems not so useful.
///
/// Finally, note that we don't impose Typst's ideas about blockiness here. For
/// example, `<img>` is included here even though Typst's `image` function is
/// block-level by default. Instead the built-in `image` show rule wraps the
/// produced `<img>` in a Typst `block`. With `box` and `block`, it's always
/// possible to override the default defined by this function.
pub fn HtmlTag::should_group_into_pars(self : HtmlTag) -> Bool {
  self.is_phrasing_content() && CssDisplay::default_for(self) != Some(None_)
}
