// The functions of the standard library compare by identity (elements,
// native functions) while their fingerprints are structural (an element's
// key; a native function's name, title and documentation) and carry no
// identity flag. This is only sound if distinct functions have distinct
// fingerprints: check it for every function reachable from the library's
// scopes.

///|
/// Collect the functions reachable from a scope (through the scopes of
/// functions, types and modules).
fn collect_funcs(
  scope : @library.Scope,
  funcs : Array[@library.Func],
  modules : Array[@library.Module],
  depth : Int,
) -> Unit {
  if depth > 6 {
    return
  }
  for pair in scope.iter() {
    let value = pair.1.read(
      @library.BindingGuard::silent(@library.Features::all()),
      "",
    ) catch {
      _ => continue
    }
    match value {
      Func(func) => {
        if funcs.contains(func) {
          continue
        }
        funcs.push(func)
        if func.scope() is Some(inner) {
          collect_funcs(inner, funcs, modules, depth + 1)
        }
      }
      Type(ty) => collect_funcs(ty.scope(), funcs, modules, depth + 1)
      Module(m) => {
        if modules.contains(m) {
          continue
        }
        modules.push(m)
        collect_funcs(m.scope(), funcs, modules, depth + 1)
      }
      _ => ()
    }
  }
}

///|
test "distinct library functions have distinct fingerprints" {
  let lib = library([
    @library.html_format(),
    @library.pdf_format(),
    @library.svg_format(),
    @library.png_format(),
    @library.bundle_format(),
  ])
  let funcs : Array[@library.Func] = []
  let modules : Array[@library.Module] = []
  collect_funcs(lib.global.scope(), funcs, modules, 0)
  collect_funcs(lib.math.scope(), funcs, modules, 0)
  assert_true(funcs.length() > 400)
  let seen : Map[@library.U128, @library.Func] = Map([])
  let collisions : Array[String] = []
  for func in funcs {
    let hash = @library.hash128(func)
    match seen.get(hash) {
      Some(other) =>
        // `funcs` holds each function once (by identity).
        collisions.push("\{func.repr()} / \{other.repr()}")
      None => seen[hash] = func
    }
  }
  inspect(collisions.join("; "), content="")
}
