// The review loop of the EDSL (docs/edsl-review.md): write the preview
// page of a document, in which a selection shows the MoonBit constructor
// calls that produced it and becomes feedback for the author, and answer
// the same questions from the command line.
//
// Usage (from the repository root: `bench/` holds the documents' files):
//
//   moon run doc/examples/review --target native --release -- preview [name] [-o preview.html]
//   moon run doc/examples/review --target native --release -- at <name> <page> <x> <y>
//   moon run doc/examples/review --target native --release -- feedback <name> <text> [comment] [--nth n] [--json]
//   moon run doc/examples/review --target native --release -- positions <name> <file>:<line>[:<column>]
//
// `name` is one of the documents of `@twins.originals()` (default:
// `showcase`); `compile_document` takes any `() -> @doc.Document`. The
// MoonBit sources are read from the working directory (the module root),
// so run the commands there.

///|
/// Compile a document function with the files below `root`.
fn compile_document(
  build : () -> @doc.Document,
  root~ : String = "bench",
  system_fonts~ : Bool = false,
) -> @doc.CompileReport[@layout.PagedDocument] raise {
  build().compile_paged(@system.world(root~, system_fonts~, today=(2026, 1, 1)))
}

///|
/// The document with the given name, compiled.
fn compiled(name : String) -> @doc.CompileReport[@layout.PagedDocument] raise {
  for original in @twins.originals() {
    if original.name == name {
      return compile_document(
        original.build,
        system_fonts=original.system_fonts,
      )
    }
  }
  fail("unknown document `\{name}` (one of: tiny, long, longer, showcase)")
}

///|
fn run(args : Array[String]) -> Unit raise {
  match args.get(1).unwrap_or("preview") {
    "preview" => {
      let mut name = "showcase"
      let mut out = "preview.html"
      let mut i = 2
      while i < args.length() {
        if args[i] == "-o" && i + 1 < args.length() {
          out = args[i + 1]
          i += 1
        } else {
          name = args[i]
        }
        i += 1
      }
      let report = compiled(name)
      for warning in report.warnings {
        println(warning.render())
      }
      let html = report.review_html(sources=@system.sources()).unwrap()
      @system.write_text(out, html)
      println(
        "wrote \{out}: \{report.unwrap().pages().length()} pages, \{@utf8.encode(html).length()} bytes",
      )
    }
    "at" => {
      guard args.length() == 6 else { fail("at <name> <page> <x> <y>") }
      let report = compiled(args[2])
      let page = @string.parse_int(args[3])
      let x = @string.parse_double(args[4])
      let y = @string.parse_double(args[5])
      match report.origin_at(page, x, y) {
        Some(origin) => println(origin.describe())
        None => println("nothing with a source location")
      }
    }
    "feedback" => {
      // The words that the `nth` occurrence of a text touches.
      let rest : Array[String] = []
      let mut nth = 0
      let mut json = false
      let mut i = 2
      while i < args.length() {
        if args[i] == "--json" {
          json = true
        } else if args[i] == "--nth" && i + 1 < args.length() {
          nth = @string.parse_int(args[i + 1])
          i += 1
        } else {
          rest.push(args[i])
        }
        i += 1
      }
      guard rest.length() >= 2 else {
        fail("feedback <name> <text> [comment] [--nth n] [--json]")
      }
      let text = compiled(rest[0]).review_text(sources=@system.sources())
      guard text.find(rest[1], nth~) is Some(selection) else {
        fail("`\{rest[1]}` (occurrence \{nth}) is not in the document")
      }
      let feedback = text.feedback(selection, rest.get(2).unwrap_or(""))
      if json {
        println(feedback.to_json().stringify(indent=2))
      } else {
        println(feedback.to_text())
      }
    }
    "positions" => {
      // Where on the pages is what a source line produced.
      guard args.length() == 4 else {
        fail("positions <name> <file>:<line>[:<column>]")
      }
      let parts = args[3].split(":").map(part => part.to_owned()).collect()
      guard parts.length() == 2 || parts.length() == 3 else {
        fail("positions <name> <file>:<line>[:<column>]")
      }
      let column : Int? = if parts.length() == 3 {
        Some(@string.parse_int(parts[2]))
      } else {
        None
      }
      let text = compiled(args[2]).review_text(sources=@system.sources())
      let regions = text.positions(
        parts[0],
        @string.parse_int(parts[1]),
        column?,
      )
      for region in regions {
        println(
          "page \{region.page}: x \{region.x} y \{region.y} width \{region.width} height \{region.height}",
        )
      }
      println("\{regions.length()} boxes")
    }
    command =>
      fail("unknown command `\{command}` (preview, at, feedback, positions)")
  }
}

///|
fn main {
  run(@env.args()) catch {
    @doc.DocError(errors) =>
      for error in errors {
        println(error.render())
      }
    err => println("error: \{err}")
  }
}
