// The signatures of the generated EDSL constructors, as the translator sees
// them. The table itself (`api_gen.mbt`) is written by `scripts/docgen.py`,
// so the translator never hard-codes a signature.

///|
/// How a parameter of a generated constructor is passed.
priv enum ParamKind {
  /// A positional parameter of the EDSL constructor.
  Pos
  /// Positional in Typst, a labelled optional parameter in the EDSL.
  PosOpt
  /// A named argument in Typst, a labelled optional parameter in the EDSL.
  Named
  /// A variadic positional parameter: an array in the EDSL.
  Variadic
} derive(Eq)

///|
/// An element function with its generated constructor, set rule and
/// selector. A parameter is (Typst field, MoonBit name, kind, MoonBit type).
priv struct ApiElem {
  path : String
  name : String
  ctor : Bool
  set : Bool
  select : String
  params : ReadOnlyArray[(String, String, ParamKind, String)]
  /// The fields that take positional arguments, in the function's order.
  positional : ReadOnlyArray[String]
  settable : ReadOnlyArray[String]
  where_ : ReadOnlyArray[String]
}

///|
/// A function facade: a content type (`owner` empty) or a static method.
priv struct ApiFunc {
  path : String
  name : String
  owner : String
  params : ReadOnlyArray[(String, String, ParamKind, String)]
}

///|
fn find_elem(path : String) -> ApiElem? {
  for elem in api_elems[:] {
    if elem.path == path {
      return Some(elem)
    }
  }
  None
}

///|
fn find_func(path : String) -> ApiFunc? {
  for func in api_funcs[:] {
    if func.path == path {
      return Some(func)
    }
  }
  None
}

///|
fn ApiElem::param(
  self : ApiElem,
  field : String,
) -> (String, String, ParamKind, String)? {
  for p in self.params[:] {
    if p.0 == field {
      return Some(p)
    }
  }
  None
}

///|
/// The names of all generated types (for the `using` declaration of a
/// generated package).
pub fn api_type_names() -> Array[String] {
  let names : Array[String] = []
  for elem in api_elems[:] {
    if elem.ctor {
      names.push(elem.name)
    }
    if elem.set {
      names.push("Set" + elem.name)
    }
  }
  for func in api_funcs[:] {
    if func.owner == "" {
      names.push(func.name)
    }
  }
  names
}
