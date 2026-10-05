// Compiles the reduced showcase (`doc/twins/showcase.mbt`) with the EDSL
// and writes it as PDF, and optionally as PNG pages.
//
// Usage (from the repository root, where `bench/` holds the images):
//   moon run doc/examples/showcase --target native -- out.pdf [png-prefix]

///|
fn run(pdf_path : String, png_prefix : String?) -> Unit raise {
  let world = @system.world(
    root="bench",
    system_fonts=false,
    today=(2026, 1, 1),
  )
  let compiled = @twins.showcase().compile_paged(world)
  for diagnostic in compiled.warnings {
    println(diagnostic.render())
  }
  let document = compiled.unwrap()
  println(
    "\{document.pages().length()} pages, \{compiled.origins.length()} origins",
  )
  @system.write(pdf_path, compiled.pdf().unwrap())
  println("wrote \{pdf_path}")
  if png_prefix is Some(prefix) {
    for i, page in compiled.png_pages(ppi=96).unwrap() {
      let path = "\{prefix}\{i + 1}.png"
      @system.write(path, page)
      println("wrote \{path}")
    }
  }
}

///|
fn main {
  let args = @env.args()
  let pdf_path = args.get(1).unwrap_or("showcase-edsl.pdf")
  run(pdf_path, args.get(2)) catch {
    @doc.DocError(errors) =>
      for error in errors {
        println(error.render())
      }
    err => println("error: \{err}")
  }
}
