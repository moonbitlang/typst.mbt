#!/usr/bin/env python3
"""Generates `doc/elements_gen.mbt`: the typed constructors, set rules,
selectors and views of the `doc` package (docs/edsl-design.md, section 7).

Input: `gen/manifest.json` (the element metadata `elemgen.py` uses) and the
reviewed specification below (`ELEMENTS`). For each listed element function
it emits

- `<Name>` with its true constructor (unless `ctor=False`),
- `Set<Name>` (unless the element has no settable parameter or `set=False`),
- `<Name>View` and `Select::<name>(..)`.

Author-facing parameters are derived from the fields: required ones are
positional, variadic ones an array, settable ones optional labelled
parameters. The engine type of each field is mapped by `map_type`; fields
whose type is not mapped yet are left out and listed in the coverage report
(`doc/elements_coverage.txt`); they stay reachable through the `extra`
parameter of every constructor and through `Call`/`Set`.

Plain values first (docs/edsl-design.md, section 6.1): the engine's
`Smart<T>` and `Option<T>` layers are erased from the parameter types. The
explicit `auto` and `none` states are cases of the facade enums (`Auto`,
`None`), static constructors of the facade structs (`Stroke::none()`),
`AutoValue()`/`NoneValue()` for content, and `extra` for scalars. The
documentation of each constructor lists the states its fields accept.

Storage metadata is not the constructor signature: an element with a
`construct` hook, a `parse` hook on a field, an external field or an
optional positional field must carry a reviewed note (`review=`) that
states its signature decisions, or generation fails.

Usage: python3 scripts/docgen.py
"""

import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
from elemgen import elem_var  # noqa: E402
from promotions import deprecated_extend  # noqa: E402

MANIFEST = json.load(open(os.path.join(ROOT, "gen", "manifest.json")))

# Elements whose construction is a custom hook (`hooks().construct`).
CONSTRUCT_HOOKS = {"TextElem", "PageElem"}

KEYWORDS = {
    "as", "else", "extern", "fn", "if", "let", "const", "match", "mut", "type",
    "typealias", "struct", "enum", "trait", "derive", "while", "break",
    "continue", "import", "return", "throw", "raise", "try", "catch", "pub",
    "priv", "readonly", "true", "false", "test", "loop", "for", "in", "impl",
    "with", "guard", "async", "is", "init", "main", "suberror", "and", "letrec",
    "enumview", "noraise", "defer", "module", "move", "ref", "static", "super",
    "unsafe", "use", "where", "await", "dyn", "abstract", "do", "final", "macro",
    "override", "typeof", "virtual", "yield", "local", "method", "alias",
    "assert", "package", "recur", "isnot", "define", "downcast", "inherit",
    "member", "namespace", "upcast", "using", "void", "lazy", "include", "mixin",
    "protected", "sealed", "constructor", "atomic", "volatile", "anyframe",
    "anytype", "asm", "comptime", "errdefer", "export", "opaque", "orelse",
    "resume", "threadlocal", "unreachable", "dynclass", "dynobj", "dynrec",
    "var", "finally", "noasync", "end", "extend",
}

RESERVED_PARAMS = {"label", "extra", "loc", "args_loc"}


# --------------------------------------------------------------------------
# Type mapping: engine (Rust) type -> (MoonBit parameter type, conversion).
# A conversion is a function from an expression to an expression of type
# `Value`.

def to_value(e):
    return f"ToValue::to_value({e})"


LEAVES = {
    "bool": ("Bool", lambda e: f"Value::bool({e})"),
    "usize": ("Int64", lambda e: f"Value::int({e})"),
    "u64": ("Int64", lambda e: f"Value::int({e})"),
    "i64": ("Int64", lambda e: f"Value::int({e})"),
    "NonZeroUsize": ("Int64", lambda e: f"Value::int({e})"),
    "NonZeroU32": ("Int64", lambda e: f"Value::int({e})"),
    "f64": ("Double", lambda e: f"Value::float({e})"),
    "EcoString": ("String", lambda e: f"Value::str({e})"),
    "Str": ("String", lambda e: f"Value::str({e})"),
    "Lang": ("String", lambda e: f"Value::str({e})"),
    "Region": ("String", lambda e: f"Value::str({e})"),
    "RawContent": ("String", lambda e: f"Value::str({e})"),
    "Paper": ("String", lambda e: f"Value::str({e})"),
    "Label": ("String", lambda e: f"Value::label({e})"),
    "Content": ("&IntoContent", lambda e: f"Value::content({e})"),
    "FootnoteBody": ("&IntoContent", lambda e: f"Value::content({e})"),
    "BlockBody": ("&IntoContent", lambda e: f"Value::content({e})"),
    "Packed<FigureCaption>": ("&IntoContent", lambda e: f"Value::content({e})"),
    "Attribution": ("&IntoContent", lambda e: f"Value::content({e})"),
    "ListMarker": ("&IntoContent", lambda e: f"Value::content({e})"),
    "Length": ("Length", to_value),
    "Rel<Length>": ("Length", to_value),
    "Ratio": ("Length", to_value),
    "TextSize": ("Length", to_value),
    "Spacing": ("Spacing", to_value),
    "Sizing": ("Sizing", to_value),
    "Angle": ("Angle", to_value),
    "Paint": ("Paint", to_value),
    "Color": ("Paint", to_value),
    "Stroke": ("Stroke", to_value),
    "Arc<Stroke>": ("Stroke", to_value),
    "Alignment": ("Alignment", to_value),
    "HAlignment": ("Alignment", to_value),
    "VAlignment": ("Alignment", to_value),
    "OuterHAlignment": ("Alignment", to_value),
    "OuterVAlignment": ("Alignment", to_value),
    "SpecificAlignment<HAlignment, OuterVAlignment>": ("Alignment", to_value),
    "SpecificAlignment<OuterHAlignment, VAlignment>": ("Alignment", to_value),
    "Numbering": ("Numbering", to_value),
    "Supplement": ("Supplement", to_value),
    "LinkTarget": ("LinkTarget", to_value),
    "Derived<DataSource, Loaded>": (
        "&IntoSource",
        lambda e: f"ToValue::to_value({e}.into_source())",
    ),
    "TrackSizings": ("Array[Sizing]", to_value),
    "FontList": ("Array[String]", to_value),
    "OneOrMultiple<EcoString>": ("Array[String]", to_value),
    "FontWeight": ("FontWeight", to_value),
    "Dir": ("Dir", to_value),
    "TextDir": ("Dir", to_value),
    "Value": ("Value", lambda e: e),
    # String enums, written as in Typst.
    "FontStyle": ("String", lambda e: f"Value::str({e})"),
    "ImageFit": ("String", lambda e: f"Value::str({e})"),
    "ImageFormat": ("String", lambda e: f"Value::str({e})"),
    "ImageScaling": ("String", lambda e: f"Value::str({e})"),
    "NumberType": ("String", lambda e: f"Value::str({e})"),
    "NumberWidth": ("String", lambda e: f"Value::str({e})"),
    "PlacementScope": ("String", lambda e: f"Value::str({e})"),
    "Parity": ("String", lambda e: f"Value::str({e})"),
    "RefForm": ("String", lambda e: f"Value::str({e})"),
    "Linebreaks": ("String", lambda e: f"Value::str({e})"),
    "FillRule": ("String", lambda e: f"Value::str({e})"),
    "CloseMode": ("String", lambda e: f"Value::str({e})"),
    "CitationForm": ("String", lambda e: f"Value::str({e})"),
    "RelativeTo": ("String", lambda e: f"Value::str({e})"),
    # A CSL style: a built-in name or a path, as written in Typst.
    "Derived<CslSource, CslStyle>": ("String", lambda e: f"Value::str({e})"),
    # One source or several (`Source::Many`, `Array[String]`).
    "Derived<OneOrMultiple<DataSource>, Bibliography>": (
        "&IntoSource",
        lambda e: f"ToValue::to_value({e}.into_source())",
    ),
    # A length or ratio; the function form goes through `extra`.
    "OutlineIndent": ("Length", to_value),
    "ScaleAmount": ("Length", to_value),
    # The shift of a box's baseline (`box(baseline: 2pt)`); the alignment
    # and `(at:, shift:)` forms go through `extra`.
    "BaselinePos": ("Length", to_value),
    # The edges of text: two facades, since the engine accepts different
    # metric names for each.
    "TopEdge": ("TopEdge", to_value),
    "BottomEdge": ("BottomEdge", to_value),
    # `upper`/`lower` take a string or content; the facade passes content,
    # for which the function sets a text case property (a string value
    # goes through `Value`, as in every content position).
    "Caseable": ("&IntoContent", lambda e: f"Value::content({e})"),
}

# Variadic parameters of values: engine type -> (MoonBit array type,
# conversion of one item).
VALUE_LISTS = {
    "Vec<Axes<Rel<Length>>>": (
        "Array[(Length, Length)]",
        lambda e: f"Value::array([ToValue::to_value({e}.0), ToValue::to_value({e}.1)])",
    ),
}

CONTENT_LISTS = {
    "Vec<Content>",
    "Vec<GridChild>",
    "Vec<TableChild>",
    "Vec<GridItem>",
    "Vec<TableItem>",
    "Vec<Packed<ListItem>>",
    "Vec<Packed<EnumItem>>",
    "Vec<Packed<TermItem>>",
    "Vec<StackChild>",
    "Vec<CurveComponent>",
}


def split_generic(ty):
    """`Outer<Inner>` -> (Outer, Inner) for one type argument."""
    m = re.fullmatch(r"(\w+)<(.*)>", ty)
    if not m:
        return None
    return m.group(1), m.group(2)


def states_of(ty):
    """The explicit states (`auto`, `none`) an engine type accepts."""
    states = []
    while True:
        g = split_generic(ty)
        if g is None or g[0] not in ("Option", "Smart", "Arc", "Packed", "Spanned"):
            break
        if g[0] == "Smart" and "auto" not in states:
            states.append("auto")
        if g[0] == "Option" and "none" not in states:
            states.append("none")
        ty = g[1]
    return states


SCALARS = {"Bool", "Int64", "Double", "String", "Array[String]", "Array[Sizing]"}


def state_spelling(mty, state):
    """How an author writes the explicit state for a parameter type."""
    if mty == "&IntoContent":
        return "`AutoValue()`" if state == "auto" else "`NoneValue()`"
    if mty in SCALARS or mty.startswith("("):
        return f"`extra` with `Value::{state}()`"
    if mty in ("Length", "Spacing", "Sizing", "Paint", "Alignment", "Dir"):
        return "`Auto`" if state == "auto" else "`None`"
    if mty in ("Value",):
        return f"`Value::{state}()`"
    base = mty.split("[")[0]
    return f"`{base}::{state}()`"


def is_value_type(mty):
    """Whether the mapped type implements `ToValue` (no trait objects)."""
    return "&" not in mty


def map_type(ty):
    """Returns (MoonBit type, conversion) or None if the type is unmapped."""
    if ty in LEAVES:
        return LEAVES[ty]
    g = split_generic(ty)
    if g is None:
        return None
    outer, inner = g
    if outer in ("Arc", "Packed", "Spanned"):
        return map_type(inner)
    if outer in ("Option", "Smart"):
        # Plain values first: the layer is erased; the value family spells
        # the explicit `none`/`auto` state (see `states_of`).
        return map_type(inner)
    if outer in ("Sides", "Margin", "Corners"):
        m = map_type(inner)
        if m is None or not is_value_type(m[0]):
            return None
        facade = "Corners" if outer == "Corners" else "Sides"
        return (f"{facade}[{m[0]}]", to_value)
    if outer == "Celled":
        m = map_type(inner)
        if m is None or not is_value_type(m[0]):
            return None
        return (f"Cells[{m[0]}]", to_value)
    if outer == "Axes":
        m = map_type(inner)
        if m is None or not is_value_type(m[0]):
            return None
        return (f"({m[0]}, {m[0]})", lambda e: f"Value::array([ToValue::to_value({e}.0), ToValue::to_value({e}.1)])")
    return None


# --------------------------------------------------------------------------
# The specification.

class E:
    def __init__(self, name, ident, path, file="", ctor=True, set=True,
                 ext=(), skip=(), pos=(), optional=(), types=None, review=None,
                 doc=None, view=None):
        self.name = name          # EDSL type name
        self.ident = ident        # engine element struct
        self.path = path          # qualified Typst path
        self.file = file          # disambiguates idents (substring of file)
        self.ctor = ctor
        # Whether the view and the selector are generated (default: with
        # the constructor).
        self.view = ctor if view is None else view
        self.set = set
        self.ext = set_(ext)      # external fields to include
        self.skip = set_(skip)    # fields to leave out
        self.pos = list(pos)      # optional positional fields made required
        self.optional = set_(optional)  # required fields made optional
        self.types = types or {}  # field -> engine type override
        self.review = review
        self.doc = doc


def set_(xs):
    return {x for x in xs}


ELEMENTS = [
    # Model.
    E("Heading", "HeadingElem", "heading"),
    E("Par", "ParElem", "par"),
    E("Parbreak", "ParbreakElem", "parbreak"),
    E("Strong", "StrongElem", "strong"),
    E("Emph", "EmphElem", "emph"),
    E("Link", "LinkElem", "link", optional=["body"],
      review="`Link(dest, body?)`: the parser synthesizes the body of URL "
             "destinations, so `body` is an optional labelled parameter that "
             "is passed as the second positional argument when given. Twin: "
             "`link(dest)` / `link(dest, body)`."),
    E("Ref", "RefElem", "ref"),
    E("Footnote", "FootnoteElem", "footnote"),
    E("Quote", "QuoteElem", "quote"),
    E("List", "ListElem", "list"),
    E("ListItem", "ListItem", "list.item"),
    E("Enum", "EnumElem", "enum"),
    E("EnumItem", "EnumItem", "enum.item",
      review="`EnumItem(body, number?)`: the optional positional `number` is "
             "a labelled parameter passed positionally before the body. "
             "Twin: `enum.item(body)` / `enum.item(number, body)`."),
    E("Terms", "TermsElem", "terms"),
    E("TermsItem", "TermItem", "terms.item"),
    E("Figure", "FigureElem", "figure"),
    E("Table", "TableElem", "table", ext=["gutter"],
      review="`Table(children, ..)`: `gutter` is the external shorthand the "
             "parsers of `column-gutter`/`row-gutter` read; all three are "
             "passed as named arguments. Twin: `table(..named, ..children)`."),
    E("TableCell", "TableCell", "table.cell"),
    E("TableHeader", "TableHeader", "table.header"),
    E("TableFooter", "TableFooter", "table.footer"),
    E("TableHline", "TableHLine", "table.hline"),
    E("TableVline", "TableVLine", "table.vline"),
    E("Outline", "OutlineElem", "outline"),
    E("Document", "DocumentElem", "document", ctor=False, skip=["path", "body"],
      review="Set rule only (`SetDocument`): the `document` function is "
             "not constructed by authors; `path` and `body` belong to bundle "
             "documents. Twin: `set document(..)`."),
    E("Title", "TitleElem", "title",
      review="`Title(body?)`: the optional positional body is a labelled "
             "parameter passed positionally. Twin: `title()` / `title(body)`."),
    # Text.
    E("Text", "TextElem", "text", ext=["body"], skip=["text"],
      review="`Text(body, ..)`: the custom constructor styles `body` with the "
             "settable fields; the stored `text` field is not a parameter. "
             "`font`, `size` and `fill` have parse hooks that also accept "
             "positional arguments; the EDSL passes them named. Twin: "
             "`text(size: .., fill: .., body)`."),
    E("Raw", "RawElem", "raw",
      review="`Raw(text, ..)`: `text` is a string. `syntaxes` and `theme` "
             "(parse hooks that load files) are not typed yet. Twin: "
             "`raw(text, block: .., lang: ..)`."),
    E("Linebreak", "LinebreakElem", "linebreak"),
    E("Smartquote", "SmartQuoteElem", "smartquote"),
    E("Underline", "UnderlineElem", "underline", file="text/deco"),
    E("Overline", "OverlineElem", "overline", file="text/deco"),
    E("Strike", "StrikeElem", "strike"),
    E("Highlight", "HighlightElem", "highlight"),
    E("Sub", "SubElem", "sub"),
    E("Super", "SuperElem", "super"),
    E("Smallcaps", "SmallcapsElem", "smallcaps"),
    # Layout.
    E("Page", "PageElem", "page", ext=["paper", "body"],
      review="`Page(body, ..)`: the custom constructor produces page breaks "
             "around the styled body. `paper` is external and read by the "
             "`width`/`height` parsers, which share locals; all are passed "
             "named. Twin: `page(paper: .., body)`."),
    E("Pagebreak", "PagebreakElem", "pagebreak"),
    E("Align", "AlignElem", "align", pos=["alignment"],
      review="`Align(alignment, body)`: the optional positional `alignment` "
             "is required and first, as authors write it. `SetAlign` passes "
             "it positionally. Twin: `align(alignment, body)`."),
    E("Block", "BlockElem", "block", ext=["spacing"], pos=["body"],
      review="`Block(body, ..)`: the optional positional body is required "
             "(an empty block is `Block(Seq([]))`, whose body is empty "
             "content rather than `none`; `Call(\"block\")` gives the "
             "body-less form). `spacing` is the external shorthand read by "
             "the `above`/`below` parsers. Twin: `block(.., body)`."),
    E("Box", "BoxElem", "box", pos=["body"],
      review="`Box(body, ..)`: as `Block`. `baseline` is the shift form of "
             "the field (`box(baseline: 2pt)`: how far the box is moved down "
             "from the text baseline, a length or a ratio of the box's "
             "height); the alignment form and the `(at:, shift:)` form go "
             "through `extra`. Twin: `box(.., body)`."),
    E("Pad", "PadElem", "pad", ext=["x", "y", "rest"],
      review="`Pad(body, left?, .., x?, y?, rest?)`: `x`, `y` and `rest` are "
             "external shorthands read by the side parsers. Twin: "
             "`pad(x: .., body)`."),
    E("Place", "PlaceElem", "place",
      review="`Place(body, alignment?, ..)`: the optional positional "
             "`alignment` is a labelled parameter passed positionally. Twin: "
             "`place(alignment, body)`."),
    E("Stack", "StackElem", "stack"),
    E("Grid", "GridElem", "grid", ext=["gutter"],
      review="As `Table`."),
    E("GridCell", "GridCell", "grid.cell"),
    E("GridHeader", "GridHeader", "grid.header"),
    E("GridFooter", "GridFooter", "grid.footer"),
    E("GridHline", "GridHLine", "grid.hline"),
    E("GridVline", "GridVLine", "grid.vline"),
    E("Columns", "ColumnsElem", "columns",
      review="`Columns(body, count?, ..)`: the optional positional `count` "
             "is a labelled parameter passed positionally. Twin: "
             "`columns(count, body)`."),
    E("Colbreak", "ColbreakElem", "colbreak"),
    E("H", "HElem", "h"),
    E("V", "VElem", "v",
      review="`V(amount, weak?)`: the internal `attach` field (a parse hook "
             "for markup) is not a parameter. Twin: `v(amount)`."),
    E("Hide", "HideElem", "hide"),
    E("Repeat", "RepeatElem", "repeat"),
    E("Move", "MoveElem", "move", file="layout/transform"),
    E("Rotate", "RotateElem", "rotate",
      review="`Rotate(body, angle?, ..)`: the optional positional `angle` is "
             "a labelled parameter passed positionally. Twin: "
             "`rotate(angle, body)`."),
    # Visualize.
    E("Image", "ImageElem", "image",
      review="`Image(source, ..)`: `source` (a parse hook that loads the "
             "data) takes a path string, resolved against the project root, "
             "or bytes. `icc` is not typed yet. Twin: `image(source, ..)`."),
    E("Line", "LineElem", "line"),
    E("Rect", "RectElem", "rect",
      review="`Rect(body?, ..)`: the optional positional body is a labelled "
             "parameter passed positionally (shapes are usually empty). "
             "Twin: `rect(.., body)`."),
    E("Square", "SquareElem", "square", ext=["size"],
      review="As `Rect`; `size` is the external shorthand read by the "
             "`width`/`height` parsers."),
    E("Ellipse", "EllipseElem", "ellipse", review="As `Rect`."),
    E("Circle", "CircleElem", "circle", ext=["radius"],
      review="As `Rect`; `radius` is the external shorthand read by the "
             "`width`/`height` parsers."),
    E("Polygon", "PolygonElem", "polygon"),
    E("Curve", "CurveElem", "curve"),
    E("CurveMove", "CurveMove", "curve.move"),
    E("CurveLine", "CurveLine", "curve.line"),
    E("CurveQuad", "CurveQuad", "curve.quad"),
    E("CurveCubic", "CurveCubic", "curve.cubic"),
    E("CurveClose", "CurveClose", "curve.close"),
    E("Scale", "ScaleElem", "scale", ext=["factor"],
      review="`Scale(body, factor?, x?, y?, ..)`: `factor` is the external "
             "positional shorthand read by the `x`/`y` parsers; it is a "
             "labelled parameter passed positionally before the body. Twin: "
             "`scale(factor, body)` / `scale(x: .., y: .., body)`."),
    E("Skew", "SkewElem", "skew"),
    # Math.
    E("Equation", "EquationElem", "math.equation", ctor=False, view=True,
      review="Set rule, view and selector only (`SetEquation`, "
             "`Select::equation`): the constructor is the handwritten "
             "`Equation(source, ..)`, which takes a math string (section "
             "13). Twin: `set math.equation(..)`."),
    # Bibliography.
    E("Bibliography", "BibliographyElem", "bibliography",
      review="`Bibliography(sources, ..)`: `sources` (a parse hook that "
             "loads and decodes the files) takes one path string, bytes, or "
             "several of them (`Array[String]`, `Source::Many`), resolved "
             "against the project root; `style` (a parse hook) is a built-in "
             "CSL style name or a path, as a string. `target` is not typed "
             "yet. Twin: `bibliography(sources, style: ..)`."),
    E("Cite", "CiteElem", "cite",
      review="`Cite(key, ..)`: `key` is the label name; `style` (a parse "
             "hook) is a built-in CSL style name or a path. Twin: "
             "`cite(label(key), supplement: .., form: ..)`."),
    # Introspection.
    E("Metadata", "MetadataElem", "metadata"),
]


class F:
    """A facade of a native function (docs/edsl-design.md, section 6.4): a
    constructor with the function's parameters that lowers by calling it."""

    def __init__(self, name, path, ident, parent=None, owner=None, doc=None,
                 review=None, api=True):
        self.name = name      # EDSL type name, or the method name with `owner`
        self.path = path      # qualified Typst path (documentation)
        self.ident = ident    # the function's Rust identifier
        self.parent = parent  # the Rust type whose scope holds the function
        # For value functions: the facade type that gets a static method
        # `owner::name(..)` instead of a content type of its own.
        self.owner = owner
        self.doc = doc
        # A note on the signature and the functional twin, as for elements.
        self.review = review
        # Whether the translator's table (`doc/convert/api_gen.mbt`) lists
        # the facade. Not for a function whose result depends on the kind
        # of its argument in a way the typed parameter does not keep.
        self.api = api


FUNCS = [
    F("Lorem", "lorem", "lorem"),
    F("PolygonRegular", "polygon.regular", "regular", parent="PolygonElem"),
    F("tiling", "tiling", "construct", parent="Tiling", owner="Paint"),
    # Not in the translator's table: `upper("x")` on a string literal is the
    # string `"X"`, which is not what the facade's content argument gives.
    F("Upper", "upper", "upper", api=False,
      review="`Upper(body)`: `body` is content, so the function sets a text "
             "case property on it (`upper` of a string value, which gives "
             "the converted string, is `Call(\"upper\", ..)` or a "
             "`Value::str` body). Twin: `upper[#body]`."),
    F("Lower", "lower", "lower", api=False,
      review="`Lower(body)`: as `Upper`. Twin: `lower[#body]`."),
]


# --------------------------------------------------------------------------
# Generation.

def find_elem(spec):
    found = [
        e for e in MANIFEST["elems"]
        if e["ident"] == spec.ident and spec.file in e["file"]
    ]
    if len(found) != 1:
        raise SystemExit(f"{spec.name}: {len(found)} elements match {spec.ident}")
    return found[0]


def param_name(field):
    name = field.replace("-", "_")
    if name in KEYWORDS:
        name += "_"
    if name in RESERVED_PARAMS:
        raise SystemExit(f"reserved parameter name: {field}")
    return name


def method_name(name):
    s = re.sub(r"(?<=[a-z0-9])([A-Z])", r"_\1", name).lower()
    return s + "_" if s in KEYWORDS else s


class Param:
    def __init__(self, field, kind, mty, conv, ty=""):
        self.field = field      # Typst field name
        self.name = param_name(field)
        self.kind = kind        # "pos", "variadic", "named", "pos_opt"
        self.mty = mty
        self.conv = conv
        self.ty = ty            # engine type


def states_doc(params):
    """Documentation lines: the explicit states the parameters accept."""
    lines = []
    for p in params:
        if p.kind == "variadic":
            continue
        states = states_of(p.ty)
        if not states:
            continue
        how = ", ".join(
            f"`{s}` as {state_spelling(p.mty, s)}" for s in states
        )
        lines.append(f"- `{p.name}`: {how}")
    return lines


def params_of(spec, elem, coverage):
    """The author-facing parameters of an element, and whether its
    signature needs a review note."""
    params = []
    needs_review = spec.ident in CONSTRUCT_HOOKS
    for f in elem["fields"]:
        name = f["name"]
        if f["internal"] or f["synthesized"]:
            continue
        if name in spec.skip:
            coverage.append(f"{spec.path}.{name}: skipped by the specification ({f['ty']})")
            needs_review = True
            continue
        if f["external"]:
            needs_review = True
            if name not in spec.ext:
                coverage.append(f"{spec.path}.{name}: external field not exposed ({f['ty']})")
                continue
        if f["parse"]:
            needs_review = True
        ty = spec.types.get(name, f["ty"])
        if f["variadic"]:
            if ty in VALUE_LISTS:
                mty, conv = VALUE_LISTS[ty]
                params.append(Param(name, "variadic", mty, conv))
                continue
            if ty not in CONTENT_LISTS:
                coverage.append(f"{spec.path}.{name}: unmapped variadic type {ty}")
                continue
            params.append(Param(
                name, "variadic", "Array[&IntoContent]",
                lambda e: f"Value::content({e})",
            ))
            continue
        required = f["required"] and name not in spec.optional
        positional = f["positional"]
        if positional and not f["required"]:
            needs_review = True
        if name in spec.optional:
            needs_review = True
        if required or name in spec.pos:
            # Required parameters keep the engine type without `Option`.
            g = split_generic(ty)
            if name in spec.pos and g is not None and g[0] in ("Option", "Smart"):
                ty = g[1]
            m = map_type(ty)
            if m is None:
                raise SystemExit(f"{spec.name}: required field {name} has unmapped type {ty}")
            params.append(Param(name, "pos", m[0], m[1], ty))
            continue
        m = map_type(ty)
        if m is None:
            coverage.append(f"{spec.path}.{name}: unmapped type {ty}")
            continue
        params.append(Param(name, "pos_opt" if positional else "named", m[0], m[1], ty))
    if needs_review and spec.review is None:
        raise SystemExit(
            f"{spec.name}: the constructor signature needs a reviewed note "
            "(`review=`): construct hook, parse hook, external field, "
            "optional positional or skipped field"
        )
    return params


def first_sentence(doc):
    doc = (doc or "").strip().split("\n\n")[0].replace("\n", " ")
    return doc


def doc_comment(text, indent=""):
    out = []
    line = ""
    for word in text.split():
        if len(indent) + 4 + len(line) + len(word) + 1 > 78 and line:
            out.append(f"{indent}/// {line}")
            line = word
        else:
            line = f"{line} {word}".strip()
    if line:
        out.append(f"{indent}/// {line}")
    return "\n".join(out)


def emit_arg(p, index, expr):
    name = "None" if p.kind in ("pos", "pos_opt") else f'Some("{p.field}")'
    return f"{{ name: {name}, value: {p.conv(expr)}, param: {index} }}"


def positional_names(spec, ps):
    """The `positional=` argument of `push_extra` for these parameters: the
    function's optional positional fields, which `extra` entries supply in
    their positional place."""
    names = [
        p.field for p in ps
        if p.kind == "pos_opt" or (p.kind == "pos" and p.field in spec.pos)
    ]
    if not names:
        return ""
    return ", positional=[" + ", ".join(f'"{n}"' for n in names) + "]"


# The rows of the translator's table.
API_ELEMS = []
API_FUNCS = []


def lowering_order(spec, ps):
    """The fields of a constructor in the order its generated code pushes
    their arguments (the order `Lowering::args` evaluates them in); the same
    order as `push_args` of `emit_element`."""
    order = (
        [p for p in ps if p.kind == "pos_opt"]
        + [p for p in ps if p.kind == "pos" and p.field in spec.pos]
        + [p for p in ps if p.kind == "pos" and p.field not in spec.pos]
        + [p for p in ps if p.kind == "named"]
        + [p for p in ps if p.kind == "variadic"]
    )
    late = [p for p in order if p.field in spec.optional]
    order = [p for p in order if p.field not in spec.optional]
    pos_end = max(
        [i for i, p in enumerate(order) if p.kind == "pos"], default=-1
    )
    order[pos_end + 1:pos_end + 1] = late
    return [p.field for p in order]


def api_kind(spec, p):
    """The kind of a parameter in the translator's table."""
    if p.kind == "variadic":
        return "Variadic"
    if p.kind == "named":
        return "Named"
    if p.kind == "pos_opt" or p.field in spec.optional:
        # Labelled in the EDSL, positional in Typst.
        return "PosOpt"
    return "Pos"


def mbt_string(s):
    return json.dumps(s, ensure_ascii=False)


def emit_api():
    """`doc/convert/api_gen.mbt`: the signatures of the generated
    constructors, for the Typst-to-EDSL translator."""
    out = [
        "// Generated by scripts/docgen.py from gen/manifest.json. DO NOT EDIT.",
        "",
        "///|",
        "/// The generated element constructors, set rules and selectors.",
        "let api_elems : ReadOnlyArray[ApiElem] = [",
    ]

    def params(rows):
        return "[" + ", ".join(
            f"({mbt_string(f)}, {mbt_string(n)}, {k}, {mbt_string(t)})"
            for f, n, k, t in rows
        ) + "]"

    def strings(xs):
        return "[" + ", ".join(mbt_string(x) for x in xs) + "]"

    for e in API_ELEMS:
        out.append(
            f"  {{ path: {mbt_string(e['path'])}, name: {mbt_string(e['name'])}, "
            f"ctor: {str(e['ctor']).lower()}, set: {str(e['set']).lower()}, "
            f"select: {mbt_string(e['select'])}, params: {params(e['params'])}, "
            f"positional: {strings(e['positional'])}, order: {strings(e['order'])}, "
            f"settable: {strings(e['settable'])}, "
            f"where_: {strings(e['where'])} }},"
        )
    out.append("]")
    out.append("")
    out.append("///|")
    out.append("/// The generated function facades.")
    out.append("let api_funcs : ReadOnlyArray[ApiFunc] = [")
    for f in API_FUNCS:
        out.append(
            f"  {{ path: {mbt_string(f['path'])}, name: {mbt_string(f['name'])}, "
            f"owner: {mbt_string(f['owner'])}, params: {params(f['params'])} }},"
        )
    out.append("]")
    path = os.path.join(ROOT, "doc", "convert", "api_gen.mbt")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")


def emit_element(spec, out, coverage):
    elem = find_elem(spec)
    params = params_of(spec, elem, coverage)
    handle = f"@library.{elem_var(elem['ident'], elem['file'])}()"
    doc = first_sentence(elem.get("doc"))
    title = spec.path

    required = [p for p in params if p.kind == "pos"]
    variadic = [p for p in params if p.kind == "variadic"]
    optional = [p for p in params if p.kind in ("named", "pos_opt")]
    # Declaration order: required, variadic, optional.
    ordered = required + variadic + optional
    index = {p.name: i for i, p in enumerate(ordered)}

    def push_args(lines, ps, var="args"):
        # Arguments are passed in the engine's field order for positionals:
        # optional positionals first (as authors write them), then required
        # ones, then the variadic ones; named ones in between do not matter.
        order = (
            [p for p in ps if p.kind == "pos_opt"]
            + [p for p in ps if p.kind == "pos" and p.field in spec.pos]
            + [p for p in ps if p.kind == "pos" and p.field not in spec.pos]
            + [p for p in ps if p.kind == "named"]
            + [p for p in ps if p.kind == "variadic"]
        )
        # A required field that the specification made optional keeps its
        # place after the other required ones.
        late = [p for p in order if p.field in spec.optional]
        order = [p for p in order if p.field not in spec.optional]
        pos_end = max(
            [i for i, p in enumerate(order) if p.kind == "pos"], default=-1
        )
        order[pos_end + 1:pos_end + 1] = late
        for p in order:
            i = index[p.name]
            if p.kind == "pos" and p.field not in spec.pos:
                # Required by the function: no states besides a value.
                lines.append(f"  {var}.push({emit_arg(p, i, p.name)})")
            elif p.kind == "pos":
                # An `extra` entry naming an optional positional field
                # replaces the typed argument in its positional place.
                lines.append(f'  if extra_arg(extra, "{p.field}") is Some(v) {{')
                lines.append(
                    f"    {var}.push({{ name: None, value: v, param: {len(ordered)} }})"
                )
                lines.append("  } else {")
                lines.append(f"    {var}.push({emit_arg(p, i, p.name)})")
                lines.append("  }")
            elif p.kind == "pos_opt":
                lines.append(f'  if extra_arg(extra, "{p.field}") is Some(v) {{')
                lines.append(
                    f"    {var}.push({{ name: None, value: v, param: {len(ordered)} }})"
                )
                lines.append(f"  }} else if {p.name} is Some(v) {{")
                lines.append(f"    {var}.push({emit_arg(p, i, 'v')})")
                lines.append("  }")
            elif p.kind == "variadic":
                lines.append(f"  for child in {p.name} {{")
                lines.append(
                    f"    {var}.push({{ name: None, value: {p.conv('child')}, param: {i} }})"
                )
                lines.append("  }")
            else:
                lines.append(f"  if {p.name} is Some(v) {{")
                lines.append(f"    {var}.push({emit_arg(p, i, 'v')})")
                lines.append("  }")

    # --- constructor
    if spec.ctor:
        out.append("///|")
        out.append(doc_comment(f"`{title}`: {doc}"))
        if spec.review:
            out.append("///")
            out.append(doc_comment(spec.review))
        states = states_doc(params)
        if states:
            out.append("///")
            out.append("/// Explicit states besides a value:")
            out.extend("/// " + line for line in states)
        out.append(f"pub struct {spec.name} {{\n  priv content : Content\n}}\n")
        out.append("///|")
        out.append("#callsite(autofill(loc, args_loc))")
        out.append(f"pub fn {spec.name}::{spec.name}(")
        for p in required + variadic:
            out.append(f"  {p.name} : {p.mty},")
        for p in optional:
            out.append(f"  {p.name}? : {p.mty},")
        out.append("  extra? : Array[(String, Value)] = [],")
        out.append("  label? : String,")
        out.append("  loc~ : SourceLoc,")
        out.append("  args_loc~ : ArgsLoc,")
        out.append(f") -> {spec.name} {{")
        lines = ["  let args : Array[ArgNode] = []"]
        push_args(lines, params)
        out.extend(lines)
        out.append(
            f"  push_extra(args, extra, {len(ordered)}{positional_names(spec, params)})"
        )
        out.append("  {")
        out.append("    content: labelled_call(")
        out.append(
            f'      {{ func: FElem({handle}), args, origin: Site::new("{spec.name}", loc, args_loc) }},'
        )
        out.append("      label,")
        out.append(f"      {len(ordered) + 1},")
        out.append("    ),")
        out.append("  }")
        out.append("}\n")
        out.append("///|")
        out.append(
            f"pub impl IntoContent for {spec.name} with fn into_content(self) {{\n  self.content\n}}\n"
        )
        out.append(deprecated_extend(spec.name, "IntoContent", ["into_content"]))
        out.append("///|")
        out.append("/// Interpolation into the text of `Prose`.")
        out.append(
            f"pub impl @builtin.Show for {spec.name} with fn output(self, logger) {{\n  prose_placeholder(self.content, logger)\n}}\n"
        )
        out.append(deprecated_extend(spec.name, "@builtin.Show", ["to_string", "output"]))
        out.append("///|")
        out.append(
            f"pub impl @debug.Debug for {spec.name} with fn to_repr(self) {{\n  @debug.Debug::to_repr(self.content)\n}}\n"
        )
        out.append(deprecated_extend(spec.name, "@debug.Debug", ["to_repr"]))

    # --- set rule
    # Settable: every field that the function does not require (an optional
    # positional body included: `set rect([x])`). Optional positionals that
    # the constructor requires (`spec.pos`) are settable; required fields
    # that the specification made optional are not.
    settable = [p for p in optional]
    if spec.pos:
        settable = [p for p in required if p.field in spec.pos] + settable
    settable = [p for p in settable if p.field not in spec.optional]
    if spec.set and settable:
        sname = f"Set{spec.name}"
        sindex = {p.name: i for i, p in enumerate(settable)}
        out.append("///|")
        out.append(doc_comment(f"`set {title}(..)`."))
        states = states_doc(settable)
        if states:
            out.append("///")
            out.append("/// Explicit states besides a value:")
            out.extend("/// " + line for line in states)
        out.append(f"pub struct {sname} {{\n  priv node : SetNode\n}}\n")
        out.append("///|")
        out.append("#callsite(autofill(loc, args_loc))")
        out.append(f"pub fn {sname}::{sname}(")
        for p in settable:
            out.append(f"  {p.name}? : {p.mty},")
        out.append("  extra? : Array[(String, Value)] = [],")
        out.append("  loc~ : SourceLoc,")
        out.append("  args_loc~ : ArgsLoc,")
        out.append(f") -> {sname} {{")
        out.append("  let args : Array[ArgNode] = []")
        for p in settable:
            i = sindex[p.name]
            positional = p.kind in ("pos", "pos_opt")
            name = "None" if positional else f'Some("{p.field}")'
            if positional:
                out.append(f'  if extra_arg(extra, "{p.field}") is Some(v) {{')
                out.append(
                    f"    args.push({{ name: None, value: v, param: {len(settable)} }})"
                )
                out.append(f"  }} else if {p.name} is Some(v) {{")
            else:
                out.append(f"  if {p.name} is Some(v) {{")
            out.append(
                f"    args.push({{ name: {name}, value: {p.conv('v')}, param: {i} }})"
            )
            out.append("  }")
        out.append(
            f"  push_extra(args, extra, {len(settable)}{positional_names(spec, settable)})"
        )
        out.append(
            f'  {{ node: {{ func: FElem({handle}), args, origin: Site::new("{sname}", loc, args_loc) }} }}'
        )
        out.append("}\n")
        out.append("///|")
        out.append(
            f"pub impl IntoContent for {sname} with fn into_content(self) {{\n  Content::of(NSetRule(self.node))\n}}\n"
        )
        out.append(deprecated_extend(sname, "IntoContent", ["into_content"]))
        out.append("///|")
        out.append(f"pub impl SetRule for {sname}\n")
        out.append("///|")
        out.append(
            f"pub impl @debug.Debug for {sname} with fn to_repr(self) {{\n  @debug.Debug::to_repr(Content::of(NSetRule(self.node)))\n}}\n"
        )
        out.append(deprecated_extend(sname, "@debug.Debug", ["to_repr"]))

    # --- view and selector
    if spec.view:
        vname = f"{spec.name}View"
        out.append("///|")
        out.append(
            doc_comment(
                f"A `{title}` element handed to a callback. As content it "
                "re-emits the element unchanged."
            )
        )
        out.append(f"pub struct {vname} {{\n  priv content : @library.Content\n}}\n")
        out.append("///|")
        out.append(
            f"pub impl IntoContent for {vname} with fn into_content(self) {{\n  Content::of(NEngine(self.content))\n}}\n"
        )
        out.append(deprecated_extend(vname, "IntoContent", ["into_content"]))
        out.append("///|")
        out.append("/// Interpolation into the text of `Prose`.")
        out.append(
            f"pub impl @builtin.Show for {vname} with fn output(self, logger) {{\n  prose_placeholder(Content::of(NEngine(self.content)), logger)\n}}\n"
        )
        out.append(deprecated_extend(vname, "@builtin.Show", ["to_string", "output"]))
        out.append("///|")
        out.append(
            f"pub impl @debug.Debug for {vname} with fn to_repr(self) {{\n  @debug.Debug::to_repr(Content::of(NEngine(self.content)))\n}}\n"
        )
        out.append(deprecated_extend(vname, "@debug.Debug", ["to_repr"]))
        out.append("///|")
        out.append("/// The element as a generic view.")
        out.append(
            f"pub fn {vname}::view(self : {vname}) -> ContentView {{\n  ContentView::new(self.content)\n}}\n"
        )
        field_ty = {f["name"]: f["ty"] for f in elem["fields"]}
        for p in required:
            if field_ty[p.field] == "Content":
                out.append("///|")
                out.append(f"/// The `{p.field}` of the element.")
                out.append(
                    f"pub fn {vname}::{p.name}(self : {vname}) -> ContentView raise @library.HintedError {{\n"
                    f'  ContentView::new(self.content.field_by_name("{p.field}").cast())\n}}\n'
                )
        where = [
            p for p in optional
            if p.kind == "named" and is_value_type(p.mty) and not p.mty.startswith("Cells[")
        ]
        out.append("///|")
        out.append(
            doc_comment(
                f"The `{title}` elements; with arguments, those whose fields "
                f"have the given values (`{title}.where(..)`)."
            )
        )
        out.append(f"pub fn Select::{method_name(spec.name)}(")
        for p in where:
            out.append(f"  {p.name}? : {p.mty},")
        out.append(f") -> Selector[{vname}] {{")
        out.append("  let fields : Array[(String, Value)] = []")
        for p in where:
            out.append(f"  if {p.name} is Some(v) {{")
            out.append(f'    fields.push(("{p.field}", {p.conv("v")}))')
            out.append("  }")
        out.append(f"  elem_selector({handle}, fields, content => {vname}::{{ content, }})")
        out.append("}\n")

    # --- the translator's table (doc/convert/api_gen.mbt)
    has_set = spec.set and bool(settable)
    where_names = []
    if spec.view:
        where_names = [
            p.field for p in optional
            if p.kind == "named" and is_value_type(p.mty) and not p.mty.startswith("Cells[")
        ]
    # Positional parameters in the engine's field order (the order in which
    # the function takes positional arguments).
    by_field = {p.field: p for p in params}
    positional = [
        f["name"] for f in elem["fields"]
        if f["name"] in by_field
        and by_field[f["name"]].kind in ("pos", "pos_opt", "variadic")
    ]
    API_ELEMS.append({
        "path": spec.path,
        "name": spec.name,
        "ctor": spec.ctor,
        "set": has_set,
        "select": method_name(spec.name) if spec.view else "",
        "params": [
            (p.field, p.name, api_kind(spec, p), p.mty) for p in ordered
        ],
        "positional": positional,
        "order": lowering_order(spec, params),
        "settable": [p.field for p in settable] if has_set else [],
        "where": where_names,
    })


def find_func(spec):
    found = [
        f for f in MANIFEST["funcs"]
        if f["ident"] == spec.ident and (f.get("parent") or None) == spec.parent
    ]
    if len(found) != 1:
        raise SystemExit(f"{spec.name}: {len(found)} functions match {spec.ident}")
    return found[0]


def emit_function(spec, out):
    """A facade of a native function: required parameters positional,
    named ones optional labelled parameters with plain values."""
    from funcgen import func_key
    func = find_func(spec)
    handle = f"@library.native_{func_key(func)}()"
    doc = first_sentence(func.get("doc"))
    required, optional = [], []
    for prm in func["params"]:
        if prm["variadic"]:
            raise SystemExit(f"{spec.name}: variadic parameter {prm['name']}")
        m = map_type(prm["ty"])
        if m is None:
            raise SystemExit(f"{spec.name}: parameter {prm['name']} has unmapped type {prm['ty']}")
        kind = "named" if prm["named"] else "pos"
        (optional if prm["named"] else required).append(
            Param(prm["name"], kind, m[0], m[1], prm["ty"])
        )
    ordered = required + optional
    if spec.api:
        API_FUNCS.append({
            "path": spec.path,
            "name": spec.name,
            "owner": spec.owner or "",
            "params": [
                (prm.field, prm.name, "Pos" if prm.kind == "pos" else "Named", prm.mty)
                for prm in ordered
            ],
        })
    out.append("///|")
    out.append(doc_comment(f"`{spec.path}`: {doc}"))
    if spec.review:
        out.append("///")
        out.append(doc_comment(spec.review))
    states = states_doc(ordered)
    if states:
        out.append("///")
        out.append("/// Explicit states besides a value:")
        out.extend("/// " + line for line in states)
    if spec.owner is None:
        out.append(f"pub struct {spec.name} {{\n  priv content : Content\n}}\n")
        out.append("///|")
        out.append("#callsite(autofill(loc, args_loc))")
        out.append(f"pub fn {spec.name}::{spec.name}(")
    else:
        out.append(f"pub fn {spec.owner}::{spec.name}(")
    for prm in required:
        out.append(f"  {prm.name} : {prm.mty},")
    for prm in optional:
        out.append(f"  {prm.name}? : {prm.mty},")
    if spec.owner is None:
        out.append("  extra? : Array[(String, Value)] = [],")
        out.append("  label? : String,")
        out.append("  loc~ : SourceLoc,")
        out.append("  args_loc~ : ArgsLoc,")
        out.append(f") -> {spec.name} {{")
        out.append("  let args : Array[ArgNode] = []")
        for i, prm in enumerate(ordered):
            if prm.kind == "pos":
                out.append(f"  args.push({emit_arg(prm, i, prm.name)})")
            else:
                out.append(f"  if {prm.name} is Some(v) {{")
                out.append(f"    args.push({emit_arg(prm, i, 'v')})")
                out.append("  }")
        out.append(f"  push_extra(args, extra, {len(ordered)})")
        out.append("  {")
        out.append("    content: labelled_call(")
        out.append(
            f'      {{ func: FNative({handle}), args, origin: Site::new("{spec.name}", loc, args_loc) }},'
        )
        out.append("      label,")
        out.append(f"      {len(ordered) + 1},")
        out.append("    ),")
        out.append("  }")
        out.append("}\n")
        out.append("///|")
        out.append(
            f"pub impl IntoContent for {spec.name} with fn into_content(self) {{\n  self.content\n}}\n"
        )
        out.append(deprecated_extend(spec.name, "IntoContent", ["into_content"]))
        out.append("///|")
        out.append("/// Interpolation into the text of `Prose`.")
        out.append(
            f"pub impl @builtin.Show for {spec.name} with fn output(self, logger) {{\n  prose_placeholder(self.content, logger)\n}}\n"
        )
        out.append(deprecated_extend(spec.name, "@builtin.Show", ["to_string", "output"]))
        out.append("///|")
        out.append(
            f"pub impl @debug.Debug for {spec.name} with fn to_repr(self) {{\n  @debug.Debug::to_repr(self.content)\n}}\n"
        )
        out.append(deprecated_extend(spec.name, "@debug.Debug", ["to_repr"]))
    else:
        out.append(f") -> {spec.owner} {{")
        out.append("  let positional : Array[Value] = []")
        out.append("  let named : Array[(String, Value)] = []")
        for prm in ordered:
            if prm.kind == "pos":
                out.append(f"  positional.push({prm.conv(prm.name)})")
            else:
                out.append(f"  if {prm.name} is Some(v) {{")
                out.append(f'    named.push(("{prm.field}", {prm.conv("v")}))')
                out.append("  }")
        out.append(f"  Value(Value::native({handle}, positional, named~))")
        out.append("}\n")


# The audited exceptions of docs/edsl-design.md, section 5.3: the only
# places where the `doc` package builds element storage itself instead of
# calling a public Typst function. Pattern -> allowed occurrences by file.
STORAGE_PATTERNS = {
    r"@library\.Content::new\(": {"lower.mbt": 1},        # `context`
    r"@library\.Content::from_fields\(": {},
    r"@library\.SpaceElem::shared": {"lower.mbt": 2},     # markup's spaces
    r"@library\.\w+Elem::(new|packed)\(": {},
    r"\.with_field\(": {},
    r"\.without_field\(": {},
    r"@library\.StyledElem::new\(": {},
    r"@library\.SequenceElem::new\(": {},
}


def audit():
    """Fail if `doc` builds element storage outside the audited list."""
    doc = os.path.join(ROOT, "doc")
    problems = []
    for name in sorted(os.listdir(doc)):
        if not name.endswith(".mbt") or name.endswith("_test.mbt") or name.endswith("_wbtest.mbt"):
            continue
        text = open(os.path.join(doc, name)).read()
        for pattern, allowed in STORAGE_PATTERNS.items():
            found = len(re.findall(pattern, text))
            if found != allowed.get(name, 0):
                problems.append(
                    f"doc/{name}: {found} uses of /{pattern}/, "
                    f"{allowed.get(name, 0)} audited"
                )
    if problems:
        raise SystemExit(
            "element storage is built outside the audited exceptions "
            "(docs/edsl-design.md, section 5.3):\n  " + "\n  ".join(problems)
        )


def main():
    out = [
        "// Generated by scripts/docgen.py from gen/manifest.json. DO NOT EDIT.",
        "",
    ]
    coverage = []
    names = set()
    for spec in ELEMENTS:
        if spec.name in names:
            raise SystemExit(f"duplicate name {spec.name}")
        names.add(spec.name)
        emit_element(spec, out, coverage)
    for spec in FUNCS:
        if spec.owner is None:
            if spec.name in names:
                raise SystemExit(f"duplicate name {spec.name}")
            names.add(spec.name)
        emit_function(spec, out)
    # The element table: qualified path and handle of every constructor
    # (checked against the library's scope by a test).
    out.append("///|")
    out.append("/// The generated element types: the name of each type, the qualified")
    out.append("/// path of its Typst function and the engine element it constructs.")
    out.append("pub fn generated_elements() -> Array[(String, String, @library.Element)] {")
    out.append("  [")
    for spec in ELEMENTS:
        elem = find_elem(spec)
        out.append(
            f'    ("{spec.name}", "{spec.path}", @library.{elem_var(elem["ident"], elem["file"])}()),'
        )
    out.append("  ]")
    out.append("}")
    path = os.path.join(ROOT, "doc", "elements_gen.mbt")
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    emit_api()

    # Coverage report: what the typed constructors do not cover yet.
    listed = {(s.ident, s.file) for s in ELEMENTS}
    missing = []
    for e in MANIFEST["elems"]:
        if not any(e["ident"] == i and f in e["file"] for i, f in listed):
            missing.append(f"{e['ident']} ({e['name']}, {e['file']})")
    with open(os.path.join(ROOT, "doc", "elements_coverage.txt"), "w") as f:
        f.write("# Generated by scripts/docgen.py. Fields and elements without a typed\n")
        f.write("# constructor parameter (reachable through `Call`/`Set`).\n\n")
        f.write("## Fields\n")
        for line in coverage:
            f.write(line + "\n")
        f.write("\n## Elements without a generated constructor\n")
        for line in missing:
            f.write(line + "\n")
    print(f"generated {len(ELEMENTS)} elements and {len(FUNCS)} function "
          f"facades; {len(coverage)} fields and "
          f"{len(missing)} element structs not covered")
    audit()
    print("audit: element storage is only built in the audited exceptions")


if __name__ == "__main__":
    main()
