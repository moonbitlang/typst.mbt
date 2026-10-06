// Port of `typst-library/src/symbols.rs`: modifiable symbols.

///|
/// Hook up all `symbol` definitions.
fn symbols_define(global : Scope) -> Unit {
  global.start_category(Symbols)
  extend_scope_from_codex_module(global, codex_root())
  global.reset_category()
}

///|
/// Hook up all math `symbol` definitions, i.e., elements of the `sym`
/// module.
fn symbols_define_math(math : Scope) -> Unit {
  extend_scope_from_codex_module(math, codex_sym())
}

///|
fn extend_scope_from_codex_module(scope : Scope, module_ : CodexModule) -> Unit {
  for entry in module_.iter() {
    let (name, binding) = entry
    let mut data : NativeFuncData? = None
    let value : Value = match binding.def {
      Symbol(s) => {
        let symbol = Symbol::from_codex(s)
        data = (try? symbol.func()).to_option().bind(func => func.to_native())
        Symbol(symbol)
      }
      Module(m) => Module(Module::new(name, Scope::from_codex(m)))
    }
    let scope_binding = scope.define_(name, value)
    if binding.deprecation is Some(message) {
      scope_binding.with_deprecation(Deprecation::new().with_message(message))
      |> ignore
    }
    if data is Some(data) {
      scope_binding.with_documentation({
        name: data.name,
        title: data.title,
        docs: data.docs,
      })
      |> ignore
    }
  }
}

///|
/// Upstream `From<codex::Module> for Scope`.
fn Scope::from_codex(module_ : CodexModule) -> Scope {
  let scope = Scope::new()
  extend_scope_from_codex_module(scope, module_)
  scope
}

///|
/// Upstream `From<codex::Symbol> for Symbol`.
fn Symbol::from_codex(symbol : CodexSymbol) -> Symbol {
  match symbol {
    Single(value) => Symbol::single(value)
    Multi(list) => Symbol::list(list)
  }
}
