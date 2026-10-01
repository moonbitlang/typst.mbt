// Port of the `Library` construction in `typst-library/src/lib.rs`.

///|
/// Helper to define a native function quickly (hand-written natives).
pub fn native_func(
  name : String,
  title? : String = "",
  params? : Array[ParamInfo] = [],
  scope? : () -> Scope = Scope::new,
  contextual? : Bool = false,
  function : NativeFn,
) -> NativeFuncData {
  NativeFuncData::new(
    name~,
    title=if title.is_empty() { name } else { title },
    params~,
    scope~,
    contextual~,
    function,
  )
}

///|
/// Define a native function in a scope.
pub fn Scope::define_func(self : Scope, data : NativeFuncData) -> Binding {
  self.define(data.name, Func(Func::native(data)))
}

///|
/// Define a native type in a scope.
pub fn Scope::define_type(self : Scope, ty : Type) -> Binding {
  self.define(ty.short_name(), Type(ty))
}

///|
/// Define an element in a scope.
pub fn Scope::define_elem(self : Scope, elem : Element) -> Binding {
  self.define(elem.name(), Func(Func::element(elem)))
}

///|
/// Define the generated global native functions of a category.
fn define_globals(scope : Scope, category : String) -> Unit {
  for f in generated_globals(category) {
    scope.define_func(f) |> ignore
  }
}

///|
/// Whether the scopes of native types and elements were registered.
let scopes_registered : Ref[Bool] = { val: false, }

///|
/// Register the scopes of native types and elements (once).
fn ensure_scopes() -> Unit {
  if !scopes_registered.val {
    scopes_registered.val = true
    register_scopes()
  }
}

///|
/// The `calc` module (upstream `calc::module`).
fn calc_module() -> Module {
  let scope = Scope::new()
  for f in generated_calc_funcs() {
    scope.define_func(f) |> ignore
  }
  scope.define("inf", Float(@double.infinity)) |> ignore
  scope.define("pi", Float(@math.PI)) |> ignore
  scope.define("tau", Float(2.0 * @math.PI)) |> ignore
  scope.define("e", Float(2.718281828459045)) |> ignore
  Module::new("calc", scope)
}

///|
/// The version of upstream Typst this is a port of.
pub let typst_version : (Int, Int, Int) = @syntax.typst_version

///|
/// The `sys` module (upstream `sys::module`).
fn sys_module(inputs : Dict) -> Module {
  let scope = Scope::deduplicating()
  let (major, minor, patch) = typst_version
  scope.define("version", Version(Version([major, minor, patch]))) |> ignore
  scope.define("inputs", Dict(inputs)) |> ignore
  Module::new("sys", scope)
}

///|
/// The foundations definitions (upstream `foundations::define`).
fn foundations_define(global : Scope, inputs : Dict) -> Unit {
  global.start_category(Foundations)
  for
    ty in [
      Type::bool(),
      Type::int(),
      Type::float(),
      Type::str(),
      Type::label(),
      Type::bytes(),
      Type::content(),
      Type::array(),
      Type::dict(),
      Type::func(),
      Type::args(),
      Type::type_(),
      Type::module(),
      Type::regex(),
      Type::selector(),
      Type::datetime(),
      Type::decimal(),
      Type::symbol(),
      Type::duration(),
      Type::version(),
      Type::path(),
    ] {
    global.define_type(ty) |> ignore
  }
  define_globals(global, "foundations")
  global.define("calc", Module(calc_module())) |> ignore
  global.define("sys", Module(sys_module(inputs))) |> ignore
  global.reset_category()
}

///|
/// The model definitions (upstream `model::define`).
fn model_define(global : Scope) -> Unit {
  global.start_category(Model)
  for
    elem in [
      document_elem(),
      par_elem(),
      parbreak_elem(),
      strong_elem(),
      emph_elem(),
      list_elem(),
      enum_elem(),
      terms_elem(),
      link_elem(),
      title_elem(),
      heading_elem(),
      divider_elem(),
      figure_elem(),
      quote_elem(),
      footnote_elem(),
      outline_elem(),
      ref_elem(),
      cite_elem(),
      bibliography_elem(),
      table_elem(),
    ] {
    global.define_elem(elem) |> ignore
  }
  define_globals(global, "model")
  global.reset_category()
}

///|
/// The text definitions (upstream `text::define`).
fn text_define(global : Scope) -> Unit {
  global.start_category(Text)
  for
    elem in [
      text_elem(),
      linebreak_elem(),
      smart_quote_elem(),
      sub_elem(),
      super_elem(),
      underline_elem(),
      overline_elem(),
      strike_elem(),
      highlight_elem(),
      smallcaps_elem(),
      raw_elem(),
    ] {
    global.define_elem(elem) |> ignore
  }
  define_globals(global, "text")
  global.reset_category()
}

///|
/// The layout definitions (upstream `layout::define`).
fn layout_define(global : Scope) -> Unit {
  global.start_category(Layout)
  for
    ty in [
      Type::length(),
      Type::angle(),
      Type::ratio(),
      Type::relative(),
      Type::fraction(),
      Type::direction(),
      Type::alignment(),
    ] {
    global.define_type(ty) |> ignore
  }
  for
    elem in [
      page_elem(),
      pagebreak_elem(),
      v_elem(),
      h_elem(),
      box_elem(),
      block_elem(),
      stack_elem(),
      grid_elem(),
      columns_elem(),
      colbreak_elem(),
      place_elem(),
      align_elem(),
      pad_elem(),
      repeat_elem(),
      move_elem(),
      scale_elem(),
      rotate_elem(),
      skew_elem(),
      hide_elem(),
    ] {
    global.define_elem(elem) |> ignore
  }
  define_globals(global, "layout")
  global.reset_category()
}

///|
/// The visualize definitions (upstream `visualize::define`).
fn visualize_define(global : Scope) -> Unit {
  global.start_category(Visualize)
  for ty in [Type::color(), Type::gradient(), Type::tiling(), Type::stroke()] {
    global.define_type(ty) |> ignore
  }
  for
    elem in [
      image_elem(),
      line_elem(),
      rect_elem(),
      square_elem(),
      ellipse_elem(),
      circle_elem(),
      polygon_elem(),
      curve_elem(),
    ] {
    global.define_elem(elem) |> ignore
  }
  define_globals(global, "visualize")
  global.reset_category()
}

///|
/// The introspection definitions (upstream `introspection::define`).
fn introspection_define(global : Scope) -> Unit {
  global.start_category(Introspection)
  for ty in [Type::location(), Type::counter(), Type::state()] {
    global.define_type(ty) |> ignore
  }
  global.define_elem(metadata_elem()) |> ignore
  define_globals(global, "introspection")
  global.reset_category()
}

///|
/// The loading definitions (upstream `loading::define`).
fn loading_define(global : Scope) -> Unit {
  global.start_category(DataLoading)
  define_globals(global, "loading")
  global.reset_category()
}

///|
/// The math module (upstream `math::module`).
pub fn math_module() -> Module {
  let math = Scope::deduplicating()
  math.start_category(Math)
  for
    elem in [
      equation_elem(),
      text_elem(),
      lr_elem(),
      mid_elem(),
      math_attach_elem(),
      stretch_elem(),
      scripts_elem(),
      limits_elem(),
      accent_elem(),
      math_underline_elem(),
      math_overline_elem(),
      underbrace_elem(),
      overbrace_elem(),
      underbracket_elem(),
      overbracket_elem(),
      underparen_elem(),
      overparen_elem(),
      undershell_elem(),
      overshell_elem(),
      cancel_elem(),
      frac_elem(),
      binom_elem(),
      vec_elem(),
      mat_elem(),
      cases_elem(),
      root_elem(),
      class_elem(),
      op_elem(),
      primes_elem(),
    ] {
    math.define_elem(elem) |> ignore
  }
  define_globals(math, "math")
  Module::new("math", math)
}

///|
/// Extra definitions added to the global scope by embedders (e.g. test
/// functions), applied after the standard definitions.
pub(all) struct LibraryBuilder {
  /// Enabled features.
  mut features : Features
  /// Additional global definitions.
  extra : Array[(Scope) -> Unit]
  /// Routines into the compiler.
  routines : Routines
  /// The `sys.inputs` dictionary.
  mut inputs : Dict
}

///|
/// Create a library builder with the given routines.
pub fn Library::builder(routines : Routines) -> LibraryBuilder {
  { features: Features::all(), extra: [], routines, inputs: Dict::new(), }
}

///|
/// Configure the features.
pub fn LibraryBuilder::with_features(
  self : LibraryBuilder,
  features : Features,
) -> LibraryBuilder {
  self.features = features
  self
}

///|
/// Configure the `sys.inputs` dictionary.
pub fn LibraryBuilder::with_inputs(
  self : LibraryBuilder,
  inputs : Dict,
) -> LibraryBuilder {
  self.inputs = inputs
  self
}

///|
/// Add extra definitions to the global scope.
pub fn LibraryBuilder::with_global(
  self : LibraryBuilder,
  f : (Scope) -> Unit,
) -> LibraryBuilder {
  self.extra.push(f)
  self
}

///|
/// Build the library.
pub fn LibraryBuilder::build(self : LibraryBuilder) -> Library {
  ensure_scopes()
  let math = math_module()
  let global = Scope::deduplicating()
  foundations_define(global, self.inputs)
  model_define(global)
  text_define(global)
  layout_define(global)
  visualize_define(global)
  introspection_define(global)
  loading_define(global)
  global.define("math", Module(math)) |> ignore
  for f in self.extra {
    f(global)
  }
  let global = Module::new("global", global)
  {
    routines: self.routines,
    global,
    math,
    styles: Styles::new(),
    std: Binding::detached(Module(global)),
    features: self.features,
  }
}
