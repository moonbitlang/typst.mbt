"""Shared Rust -> MoonBit type mapping for the code generators.

A Rust type maps to a MoonBit type implementing `FromValue` + `IntoValue` with
upstream's casting semantics. Types without a port map to `Value` (accepted
unchecked); add entries here as types get ported.
"""
import re

TYPEMAP = {
    "bool": "Bool",
    "i64": "Int64",
    "f64": "Double",
    "u8": "U8",
    "u16": "U16",
    "u32": "U32",
    "u64": "U64",
    "usize": "USize",
    "i8": "I8",
    "i16": "I16",
    "i32": "I32",
    "NonZeroU32": "NonZeroU32",
    "NonZeroU64": "NonZeroU64",
    "NonZeroUsize": "NonZeroUSize",
    "NonZeroI64": "NonZeroI64",
    "Content": "Content",
    "Length": "Length",
    "Angle": "Angle",
    "Ratio": "Ratio",
    "Fr": "Fr",
    "Rel<Length>": "Rel[Length]",
    "Rel": "Rel[Length]",
    "EcoString": "String",
    "Str": "String",
    "String": "String",
    "Func": "Func",
    "Label": "Label",
    "Styles": "Styles",
    "Value": "Value",
    "Array": "Arr",
    "Dict": "Dict",
    "Args": "Args",
    "Type": "Type",
    "Alignment": "Alignment",
    "HAlignment": "HAlignment",
    "VAlignment": "VAlignment",
    "OuterHAlignment": "OuterHAlignment",
    "OuterVAlignment": "OuterVAlignment",
    "Dir": "Dir",
    "Side": "Side",
    "Axis": "Axis",
    "Spacing": "Spacing",
    "Sizing": "Sizing",
    "SyntaxMode": "@syntax.SyntaxMode",
    "Symbol": "Symbol",
    "SymbolVariant": "SymbolVariant",
    "Accent": "Accent",
    "RootedPath": "RootedPath",
    "PathOrStr": "PathOrStr",
    "BundlePath": "BundlePath",
    "DataSource": "DataSource",
    "Readable": "Readable",
    "Encoding": "Encoding",
    "Delimiter": "Delimiter",
    "RowType": "RowType",
    # foundations/array.rs, dict.rs, args.rs
    "ToArray": "ToArray",
    "ToDict": "ToDict",
    "ArgumentKey": "ArgumentKey",
    # foundations/calc.rs
    "ToAbs": "ToAbs",
    "Num": "Num",
    "DecNum": "DecNum",
    "AngleLike": "AngleLike",
    # foundations/int.rs, float.rs, str.rs (`Base`)
    "ToInt": "ToInt",
    "ToFloat": "ToFloat",
    "Base": "Base",
    "Endianness": "Endianness",
    # foundations/str.rs, text/case.rs
    "char": "Char",
    "Regex": "Regex",
    "StrPattern": "StrPattern",
    "StrSide": "StrSide",
    "Replacement": "Replacement",
    "ToStr": "ToStr",
    "UnicodeNormalForm": "UnicodeNormalForm",
    "Caseable": "Caseable",
    "Case": "Case",
    "Selector": "Selector",
    "LocatableSelector": "LocatableSelector",
    "ShowableSelector": "ShowableSelector",
    "Element": "Element",
    "Location": "Location",
    "Counter": "Counter",
    "CounterKey": "CounterKey",
    "CounterUpdate": "CounterUpdate",
    "CounterState": "CounterState",
    "State": "State",
    "StateUpdate": "StateUpdate",
    "Numbering": "Numbering",
    "NumberingPattern": "NumberingPattern",
    "Decimal": "Decimal",
    "ToDecimal": "ToDecimal",
    "Version": "Version",
    "VersionComponents": "VersionComponents",
    "Bytes": "BytesValue",
    "ToBytes": "ToBytes",
    "Datetime": "Datetime",
    "Duration": "Duration",
    "Month": "@time.Month",
    "Smart<DisplayPattern>": "SmartDisplayPattern",
    "Smart<TodayOffset>": "SmartTodayOffset",
    # layout/grid/mod.rs, model/table.rs
    "TrackSizings": "TrackSizings",
    "GridChild": "GridChild",
    "GridItem": "GridItem",
    "GridCell": "GridCell",
    "TableChild": "TableChild",
    "TableItem": "TableItem",
    "TableCell": "TableCell",
    "TableElem": "TableElem",
    "TableHeaderScope": "TableHeaderScope",
    # text/mod.rs, text/font/, text/lang.rs
    "FontList": "FontList",
    "FontStyle": "FontStyle",
    "FontWeight": "FontWeight",
    "FontStretch": "FontStretch",
    "TextSize": "TextSize",
    "TopEdge": "TopEdge",
    "BottomEdge": "BottomEdge",
    "TextDir": "TextDir",
    "Costs": "Costs",
    "Alternates": "Alternates",
    "StylisticSets": "StylisticSets",
    "NumberType": "NumberType",
    "NumberWidth": "NumberWidth",
    "FontFeatures": "FontFeatures",
    "FontVariations": "FontVariations",
    "WeightDelta": "WeightDelta",
    "ItalicToggle": "ItalicToggle",
    "Never": "Never",
    "Lang": "Lang",
    "Region": "Region",
    "WritingScript": "WritingScript",
    "SmartQuoteDict": "SmartQuoteDict",
    "RawContent": "RawContent",
    # layout/page.rs, place.rs, transform.rs, container.rs, stack.rs
    "Paper": "Paper",
    "Binding": "PageBinding",
    "Parity": "Parity",
    "PageRanges": "PageRanges",
    "PlacementScope": "PlacementScope",
    "ScaleAmount": "ScaleAmount",
    "BlockBody": "BlockBody",
    "BaselinePos": "BaselinePos",
    "StackChild": "StackChild",
    # model/*.rs
    "Depth": "Depth",
    "ListMarker": "ListMarker",
    "Packed<ListItem>": "ListItem",
    "Packed<EnumItem>": "EnumItem",
    "Packed<TermItem>": "TermItem",
    "Packed<FigureCaption>": "FigureCaption",
    "Packed<FootnoteElem>": "FootnoteElem",
    "SmallVec<[u64; 4]>": "Array[U64]",
    "FigureKind": "FigureKind",
    "Supplement": "Supplement",
    "RefForm": "RefForm",
    "OutlineIndent": "OutlineIndent",
    "Attribution": "Attribution",
    "FootnoteBody": "FootnoteBody",
    "JustificationLimits": "JustificationLimits",
    "Linebreaks": "Linebreaks",
    "FirstLineIndent": "FirstLineIndent",
    "LineNumberingScope": "LineNumberingScope",
    "DocumentFormat": "DocumentFormat",
    "ArtifactKind": "ArtifactKind",
    # visualize/color.rs
    "Color": "Color",
    "ProcessColor": "ProcessColor",
    "ColorSpace": "ColorSpace",
    "ProcessColorSpace": "ProcessColorSpace",
    "SpotColorant": "SpotColorant",
    "SpotColorantName": "SpotColorantName",
    "WeightedColor": "WeightedColor",
    "Component": "Component",
    "RatioComponent": "RatioComponent",
    "ChromaComponent": "ChromaComponent",
    # visualize/gradient.rs
    "Gradient": "Gradient",
    "GradientStop": "GradientStop",
    "RatioOrAngle": "RatioOrAngle",
    "RelativeTo": "RelativeTo",
    # visualize/tiling.rs, paint.rs
    "Tiling": "Tiling",
    "Paint": "Paint",
    # visualize/stroke.rs
    "Stroke": "Stroke",
    "Arc<Stroke>": "Stroke",
    "LineCap": "LineCap",
    "LineJoin": "LineJoin",
    "DashPattern": "DashPattern",
    "DashLength": "DashLength",
    # visualize/shape.rs, curve.rs
    "FillRule": "FillRule",
    "CloseMode": "CloseMode",
    "CurveComponent": "CurveComponent",
    # math/*.rs
    "MathSize": "MathSize",
    "MathVariant": "MathVariant",
    "MathClass": "@unicode.MathClass",
    "FracStyle": "FracStyle",
    "DelimiterPair": "DelimiterPair",
    "Augment": "Augment",
    "CancelAngle": "CancelAngle",
    "(i16, i16)": "(I16, I16)",
    # visualize/image/*.rs
    "ImageFormat": "ImageFormat",
    "ImageFit": "ImageFit",
    "ImageScaling": "ImageScaling",
    "RasterFormat": "RasterFormat",
    "VectorFormat": "VectorFormat",
    "ExchangeFormat": "ExchangeFormat",
    "PixelFormat": "PixelFormat",
    "PixelEncoding": "PixelEncoding",
    # typst-pdf/src/format.rs, model/accessibility.rs
    "PdfStandards": "PdfStandards",
    "PdfStandard": "PdfStandard",
    "AttachedFileRelationship": "AttachedFileRelationship",
    "PdfMarkerTagKind": "PdfMarkerTagKind",
    # typst_utils
    "Scalar": "Scalar",
    # model/link.rs, introspection/position.rs
    "LinkTarget": "LinkTarget",
    "Destination": "Destination",
    "Url": "Url",
    "PagedPosition": "PagedPosition",
    # typst-bundle/src/format.rs
    "AssetData": "AssetData",
    # model/cite.rs
    "CitationForm": "CitationForm",
    # text/lang.rs
    "Locale": "Locale",
    # foundations/target.rs, introspection/tag.rs
    "Target": "Target",
    "Tag": "Tag",
    # typst-html (dom.rs, css/encode.rs); ported in library/html_*.mbt
    "HtmlTag": "HtmlTag",
    "HtmlAttr": "HtmlAttr",
    "HtmlAttrs": "HtmlAttrs",
    "css::Properties": "CssProperties",
}

# Generic Rust types with a MoonBit port: Rust name -> MoonBit name. A use
# `X<A, B>` maps to `X[A', B']` if every argument maps to a ported type
# (or is literally `Value`).
GENERICS = {
    "Smart": "Smart",
    "Axes": "Axes",
    # Only `Sides<Option<T>>` / `Corners<Option<T>>` are castable upstream.
    "Sides": "Sides",
    "Corners": "Corners",
    "SpecificAlignment": "SpecificAlignment",
    "Celled": "Celled",
    # layout/page.rs
    "Margin": "Margin",
    # foundations/array.rs
    "OneOrMultiple": "OneOrMultiple",
}


def _split_generics(s):
    """Split `A, B<C, D>` at top-level commas."""
    out, depth, cur = [], 0, ""
    for ch in s:
        if ch == "<":
            depth += 1
        elif ch == ">":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out

def mbt_type(rust):
    """Map a Rust type to a MoonBit type, or 'Value' if unknown."""
    rust = rust.strip()
    if rust in TYPEMAP:
        return TYPEMAP[rust]
    m = re.fullmatch(r"Option<(.*)>", rust)
    if m:
        inner = mbt_type(m.group(1))
        return "Value" if inner == "Value" and m.group(1) != "Value" else inner + "?"
    # `Derived<S, D>` casts like its user-visible source `S` (upstream's
    # `Reflect`/`IntoValue` impls); the derived part is computed by the
    # field's `#[parse]` hook and not stored in the field value.
    m = re.fullmatch(r"Derived<(.*)>", rust)
    if m:
        return mbt_type(_split_generics(m.group(1))[0])
    m = re.fullmatch(r"Vec<(.*)>", rust)
    if m:
        inner = mbt_type(m.group(1))
        if inner == "Value" and m.group(1) != "Value":
            return "Value"
        return f"Array[{inner}]"
    m = re.fullmatch(r"(\w+)<(.*)>", rust)
    if m and m.group(1) in GENERICS:
        args = _split_generics(m.group(2))
        mapped = [mbt_type(a) for a in args]
        if any(x == "Value" and a != "Value" for x, a in zip(mapped, args)):
            return "Value"
        return f"{GENERICS[m.group(1)]}[{', '.join(mapped)}]"
    return "Value"
