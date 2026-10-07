// Ada Lovelace's Notes A, F and G to Menabrea's "Sketch of the Analytical
// Engine" (Scientific Memoirs, vol. 3, 1843), set with the EDSL.
//
// Usage (from the repository root):
//   moon run doc/examples/papers/lovelace-1843 --target native
// writes `_build/papers/lovelace-1843.pdf` and one PNG per page.

///|
fn run() -> Unit raise {
  let world = @system.world(
    root="doc/examples/papers/lovelace-1843",
    system_fonts=false,
    today=(1843, 9, 1),
  )
  let compiled = paper().compile_paged(world)
  for diagnostic in compiled.warnings {
    println(diagnostic.render())
  }
  for lint in compiled.lints {
    println(lint.render())
  }
  let document = compiled.unwrap()
  println("\{document.pages().length()} pages")
  let out = "_build/papers/lovelace-1843"
  @system.write("\{out}.pdf", compiled.pdf().unwrap())
  for i, page in compiled.png_pages(ppi=110).unwrap() {
    @system.write("\{out}-\{i + 1}.png", page)
  }
  println("wrote \{out}.pdf")
}

///|
fn main {
  run() catch {
    @doc.DocError(errors) =>
      for error in errors {
        println(error.render())
      }
    err => println("error: \{err}")
  }
}
