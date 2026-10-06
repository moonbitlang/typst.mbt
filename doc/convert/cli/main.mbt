// A development tool: translates one Typst file to the EDSL
// (docs/edsl-convert.md) and prints a complete MoonBit source file for a
// package that imports `moonbitlang/typst/doc`, so that a translation can
// be read and type-checked on its own.
//
// Usage: moon run doc/convert/cli --target native -- <file.typ> [--baseline]
//        [--prose] [--path=<root-relative path>] [--name=<function>]
//        [--no-using]
//
// The file's path, or `--path`, is taken as its root-relative path (the
// document gets its directory). `--prose` is the readable mode
// (docs/edsl-convert.md, section 4.7). Global names are those of the standard library. The
// source goes to standard output; the tier, the number of typed
// expressions and the fallback fragments go to standard error.
//
// The printed file names every type of `doc` that generated code can
// mention, so its `using` declaration carries
// `#warnings("-unused_type_declaration")` for the ones this translation
// does not use. A `using` declaration holds for a whole package: with
// several translations in one package, all but one are printed with
// `--no-using`.

///|
/// The handwritten types of `doc` that generated code may name (the
/// generated ones are `@convert.api_type_names()`).
let handwritten_types : Array[String] = [
  "Document", "Seq", "Lit", "Labelled", "Keyed", "Space", "Symbol", "Quoted", "Markup",
  "Equation", "Call", "Set", "Show", "ShowSet", "ShowWith", "Select", "Context",
  "Value", "NoneValue", "AutoValue", "Paint", "Stroke", "Sides", "Corners", "Cells",
  "Sizing", "Numbering", "Supplement", "Prose", "Content",
]

///|
/// The MoonBit source file of a translation.
fn render(
  translation : @convert.Translation,
  function : String,
  using_ : Bool,
) -> String {
  let out = StringBuilder()
  if using_ {
    out.write_string(
      "///|\n#warnings(\"-unused_type_declaration\")\nusing @doc {\n",
    )
    let names = @convert.api_type_names()
    names.append(handwritten_types)
    for name in names {
      out.write_string("  type \{name},\n")
    }
    out.write_string("}\n\n")
  }
  out.write_string("///|\n")
  out.write_string("pub fn \{function}() -> @doc.Document {\n")
  out.write_string(translation.body)
  out.write_string("\n}\n")
  out.to_string()
}

///|
fn main {
  let args = @platform.args()
  let mut path : String? = None
  let mut baseline = false
  let mut prose = false
  let mut virtual_path : String? = None
  let mut function = "build"
  let mut using_ = true
  for arg in args {
    if arg == "--baseline" {
      baseline = true
    } else if arg == "--prose" {
      prose = true
    } else if arg.strip_prefix("--path=") is Some(value) {
      virtual_path = Some(value.to_owned())
    } else if arg == "--no-using" {
      using_ = false
    } else if arg.strip_prefix("--name=") is Some(name) {
      function = name.to_owned()
    } else {
      path = Some(arg)
    }
  }
  guard path is Some(path) else {
    @platform.print_stderr(
      "usage: convert-cli <file.typ> [--baseline] [--prose] [--path=<root-relative path>] [--name=<function>] [--no-using]\n",
    )
    return
  }
  let text = try @system.read(path) catch {
    error => {
      @platform.print_stderr("\{path}: \{error}\n")
      return
    }
  } noraise {
    bytes => @utf8.decode_lossy(bytes)
  }
  let translation = @convert.translate(
    text,
    virtual_path.unwrap_or(path),
    @doc.standard_library(),
    baseline~,
    prose~,
  )
  println(render(translation, function, using_))
  let report = StringBuilder()
  let math = if translation.math_only { " (math only)" } else { "" }
  report.write_string(
    "tier \{translation.tier}\{math}, typed \{translation.typed}, fallback \{translation.fallback_bytes}/\{translation.source_bytes} bytes\n",
  )
  for fallback in translation.fallbacks {
    report.write_string(
      "  fallback \{fallback.kind} \{fallback.construct} \{fallback.bytes} bytes\n",
    )
  }
  @platform.print_stderr(report.to_string())
}
