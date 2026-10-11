// Port of the `Library` construction in `typst-library/src/lib.rs`.

///|
/// Helper to define a native function quickly (hand-written natives).
pub fn native_func(
  name : String,
  title~ : String = "",
  params~ : Array[ParamInfo] = [],
  scope~ : () -> Scope = Scope::new,
  contextual~ : Bool = false,
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
  self
  .define_(data.name, Func(Func::native(data)))
  .with_documentation(BindingDocumentation::from_func(data))
}

///|
/// Define a native type in a scope.
pub fn Scope::define_type(self : Scope, ty : Type) -> Binding {
  self
  .define_(ty.short_name(), Type(ty))
  .with_documentation(BindingDocumentation::from_type(ty.0))
}

///|
/// Define an element in a scope.
pub fn Scope::define_elem(self : Scope, elem : Element) -> Binding {
  self
  .define_(elem.name(), Func(Func::element(elem)))
  .with_documentation(BindingDocumentation::from_elem(elem))
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
  scope
  .define_("inf", Float(@double.infinity))
  .with_documentation({
    name: "inf",
    title: "Infinity",
    docs: "\n            Infinity ($+oo$) as a value.\n\n            This is the same value as @float.inf. See the corresponding\n            documentation for more details.\n            ",
    since: Some(Forever),
    keywords: [],
  })
  |> ignore
  scope
  .define_("pi", Float(@math.PI))
  .with_documentation({
    name: "pi",
    title: "Pi",
    docs: "\n            Archimedes' constant ($pi$).\n\n            This is the ratio of a circle's circumference to its diameter.\n\n            ```example\n            #calc.pi\n            ```\n            ",
    since: Some(Forever),
    keywords: ["Archimedes"],
  })
  |> ignore
  scope
  .define_("tau", Float(2.0 * @math.PI))
  .with_documentation({
    name: "tau",
    title: "Tau",
    docs: "\n            The circumference of a unit circle ($tau$).\n\n            The constant $tau$ is defined by the relation $tau = 2 pi$.\n\n            ```example\n            #calc.tau \\\n            #(2 * calc.pi)\n            ```\n            ",
    since: Some(Version(0, 8, 0)),
    keywords: [],
  })
  |> ignore
  scope
  .define_("e", Float(2.718281828459045))
  .with_documentation({
    name: "e",
    title: "Euler's number",
    docs: "\n            Euler's number ($e$).\n\n            This is the base of the natural logarithm and the exponential function.\n\n            ```example\n            #calc.e\n            ```\n            ",
    since: Some(Forever),
    keywords: [],
  })
  |> ignore
  Module::new("calc", scope).canonical()
}

///|
/// The version of upstream Typst this is a port of.
pub let typst_version : (Int, Int, Int) = @syntax.typst_version

///|
/// The `sys` module (upstream `sys::module`).
fn sys_module(inputs : Dict) -> Module {
  let scope = Scope::deduplicating()
  let (major, minor, patch) = typst_version
  scope
  .define_(
    "version",
    Version(
      Version([
        major.reinterpret_as_uint(),
        minor.reinterpret_as_uint(),
        patch.reinterpret_as_uint(),
      ]),
    ),
  )
  .with_documentation({
    name: "version",
    title: "Compiler Version",
    docs: "\n            The currently active Typst compiler version.\n\n            ```example\n            #sys.version\n            ```\n            ",
    since: Some(Version(0, 9, 0)),
    keywords: [],
  })
  |> ignore
  scope
  .define_("inputs", Dict(inputs))
  .with_documentation({
    name: "inputs",
    title: "CLI inputs",
    docs: "\n            Makes external inputs available to the project.\n\n            An input specified in the command line as `--input key=value` becomes\n            available under `{sys.inputs.key}` as `{\"value\"}`. To include spaces in\n            the value, it may be enclosed with single or double quotes.\n\n            The value is always of type @str[string]. More complex data may be\n            parsed manually using functions like @json.\n            ",
    since: Some(Version(0, 11, 0)),
    keywords: [],
  })
  |> ignore
  Module::new("sys", scope).canonical()
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
      Type::module_(),
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
  global.define_("calc", Module(calc_module())) |> ignore
  global.define_("sys", Module(sys_module(inputs))) |> ignore
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

  // Text operators.
  op_define(math)

  // Spacings.
  math_define_spacings(math)

  // Symbols.
  symbols_define_math(math)
  Module::new("math", math).canonical()
}

///|
/// Defines scoped items in the global scope (upstream `prelude`).
fn prelude_define(global : Scope) -> Unit {
  global.define_("black", Color(color_black)) |> ignore
  global.define_("gray", Color(color_gray)) |> ignore
  global.define_("silver", Color(color_silver)) |> ignore
  global.define_("white", Color(color_white)) |> ignore
  global.define_("navy", Color(color_navy)) |> ignore
  global.define_("blue", Color(color_blue)) |> ignore
  global.define_("aqua", Color(color_aqua)) |> ignore
  global.define_("teal", Color(color_teal)) |> ignore
  global.define_("eastern", Color(color_eastern)) |> ignore
  global.define_("purple", Color(color_purple)) |> ignore
  global.define_("fuchsia", Color(color_fuchsia)) |> ignore
  global.define_("maroon", Color(color_maroon)) |> ignore
  global.define_("red", Color(color_red)) |> ignore
  global.define_("orange", Color(color_orange)) |> ignore
  global.define_("yellow", Color(color_yellow)) |> ignore
  global.define_("olive", Color(color_olive)) |> ignore
  global.define_("green", Color(color_green)) |> ignore
  global.define_("lime", Color(color_lime)) |> ignore
  global.define_func(native_color_luma()) |> ignore
  global.define_func(native_color_oklab()) |> ignore
  global.define_func(native_color_oklch()) |> ignore
  global.define_func(native_color_rgb()) |> ignore
  global.define_func(native_color_cmyk()) |> ignore
  global.define_func(native_array_range()) |> ignore
  // Directions and alignments.
  prelude_layout(global)
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
  /// The registered export formats.
  formats : Array[Format]
}

///|
/// Create a library builder with the given routines.
pub fn Library::builder(
  routines : Routines,
  formats : Array[Format],
) -> LibraryBuilder {
  {
    features: Features::all(),
    extra: [],
    routines,
    inputs: Dict::new(),
    formats,
  }
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
  symbols_define(global)
  global.define_("format", Module(format_module(self.formats))) |> ignore
  global.define_("math", Module(math)) |> ignore
  prelude_define(global)
  // If available, add some items to the global prelude.
  global.prelude_path(["format", "html"]) |> ignore
  global.prelude_path(["format", "pdf"]) |> ignore
  global.prelude_path(["format", "bundle", "asset"]) |> ignore
  for f in self.extra {
    f(global)
  }
  let global = Module::new("global", global).canonical()
  let rules = (self.routines.rules)()
  for format in self.formats {
    format.register_rules(rules)
  }
  {
    routines: self.routines,
    global,
    math,
    styles: Styles::new(),
    rules,
    std: Binding::detached(Module(global)),
    features: self.features,
    formats: self.formats,
  }
}
