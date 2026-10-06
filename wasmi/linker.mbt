// Port of wasmi 1.0.9 `linker.rs`.

///|
/// An error that may occur upon operating with [`Linker`] instances.
pub(all) enum LinkerError {
  /// Encountered duplicate definitions for the same name.
  DuplicateDefinition(import_name~ : ImportName)
  /// Encountered when no definition for an import is found.
  MissingDefinition(name~ : ImportName, ty~ : ExternType)
  /// Encountered when a definition with invalid type is found.
  InvalidTypeDefinition(
    name~ : ImportName,
    expected~ : ExternType,
    found~ : ExternType
  )
}

///|
pub impl Show for LinkerError with fn output(self, f) {
  match self {
    DuplicateDefinition(import_name~) =>
      f.write_string(
        "encountered duplicate definition with name `\{import_name}`",
      )
    MissingDefinition(name~, ty~) =>
      f.write_string(
        "cannot find definition for import \{name} with type \{ty}",
      )
    InvalidTypeDefinition(name~, expected~, found~) =>
      f.write_string(
        "found definition for import \{name} with type \{expected} but found type \{found}",
      )
  }
}

///|
pub extend LinkerError with Show::{to_string, output}

///|
/// A definition stored in a [`Linker`].
priv enum Definition[T] {
  /// An external item from an [`Instance`](crate::Instance).
  Extern(Extern)
  /// A [`Linker`] internal host function.
  HostFunc(
    @wasmi_core.FuncType,
    (Caller[T], Array[Val], Array[Val]) -> Unit raise WasmiError
  )
}

///|
/// Returns the [`ExternType`] of the [`Definition`].
fn[T] Definition::ty(self : Definition[T], store : Store[T]) -> ExternType {
  match self {
    Extern(item) => item.ty(store)
    HostFunc(ty, _) => Func(ty)
  }
}

///|
/// Returns the [`Func`] of the [`Definition`] if it is a function.
///
/// Returns `None` otherwise.
///
/// # Note
///
/// - This allocates a new [`Func`] on the `ctx` if it is a [`Linker`]
///   defined host function.
/// - This unifies handling of [`Definition::Extern(Extern::Func)`] and
///   [`Definition::HostFunc`].
fn[T] Definition::as_func(self : Definition[T], store : Store[T]) -> Func? {
  match self {
    Extern(Func(func)) => Some(func)
    HostFunc(ty, func) => {
      let trampoline = host_trampoline(store.data, ty, func)
      let entity = HostFuncEntity::new(store.inner.engine, ty, trampoline)
      Some(store.inner.alloc_func(Host(entity)))
    }
    _ => None
  }
}

///|
/// A linker used to define module imports and instantiate module instances.
pub struct Linker[T] {
  /// The underlying [`Engine`] for the [`Linker`].
  ///
  /// # Note
  ///
  /// Primarily required to define [`Linker`] owned host functions
  //  using [`Linker::func_wrap`] and [`Linker::func_new`]. TODO: implement methods
  priv engine : Engine
  /// Definitions keyed by `(module, name)`.
  priv definitions : Map[(String, String), Definition[T]]
  /// `true` if shadowing of previous definitions is allowed.
  priv mut allow_shadowing : Bool
}

///|
/// Creates a new [`Linker`].
pub fn[T] Linker::new(engine : Engine) -> Linker[T] {
  { engine, definitions: {}, allow_shadowing: false, }
}

///|
/// Returns the underlying [`Engine`] of the [`Linker`].
pub fn[T] Linker::engine(self : Linker[T]) -> Engine {
  self.engine
}

///|
/// Configures whether this [`Linker`] allows to shadow previous definitions with the same name.
///
/// Disabled by default.
pub fn[T] Linker::allow_shadowing(self : Linker[T], allow : Bool) -> Linker[T] {
  self.allow_shadowing = allow
  self
}

///|
/// Inserts a new definition.
fn[T] Linker::insert(
  self : Linker[T],
  module_ : String,
  name : String,
  item : Definition[T],
) -> Unit raise WasmiError {
  let key = (module_, name)
  if self.definitions.contains(key) && !self.allow_shadowing {
    let import_name = ImportName::new(module_, name)
    raise Linker(DuplicateDefinition(import_name~))
  }
  self.definitions.set(key, item)
}

///|
/// Define a new item in this [`Linker`].
///
/// # Errors
///
/// If there already is a definition under the same name for this [`Linker`].
pub fn[T] Linker::define_(
  self : Linker[T],
  module_ : String,
  name : String,
  item : Extern,
) -> Linker[T] raise WasmiError {
  self.insert(module_, name, Extern(item))
  self
}

///|
/// Creates a new named [`Func::new`]-style host [`Func`] for this [`Linker`].
///
/// For more information see [`Linker::func_wrap`].
///
/// # Errors
///
/// If there already is a definition under the same name for this [`Linker`].
pub fn[T] Linker::func_new(
  self : Linker[T],
  module_ : String,
  name : String,
  ty : @wasmi_core.FuncType,
  func : (Caller[T], Array[Val], Array[Val]) -> Unit raise WasmiError,
) -> Linker[T] raise WasmiError {
  self.insert(module_, name, HostFunc(ty, func))
  self
}

///|
/// Looks up a defined [`Extern`] by name in this [`Linker`].
///
/// - Returns `None` if this name was not previously defined in this [`Linker`].
/// - Returns `None` if the definition is a [`Linker`] host function.
pub fn[T] Linker::get(
  self : Linker[T],
  module_ : String,
  name : String,
) -> Extern? {
  match self.definitions.get((module_, name)) {
    Some(Extern(item)) => Some(item)
    _ => None
  }
}

///|
/// Convenience wrapper to define an entire [`Instance`] in this [`Linker`].
///
/// This is a convenience wrapper around [`Linker::define`] which defines all exports of
/// the `instance` for `self`. The module name for each export is `module_name` and the
/// field name for each export is the name in the `instance` itself.
///
/// # Errors
///
/// If there already is a definition for any of the exported items for this [`Linker`].
///
/// # Panics
///
/// If the [`Engine`] of this [`Linker`] and the [`Engine`] of `store` are not the same.
pub fn[T] Linker::instance(
  self : Linker[T],
  store : Store[T],
  module_name : String,
  instance : Instance,
) -> Linker[T] raise WasmiError {
  if !Engine::same(store.inner.engine, self.engine) {
    abort(
      "assertion failed: Engine::same(store.as_context().store.engine(), self.engine())",
    )
  }
  for export_ in instance.exports(store) {
    let (name, item) = export_
    self.insert(module_name, name, Extern(item))
  }
  self
}

///|
/// Instantiates the given [`Module`] using the definitions in the [`Linker`].
///
/// # Errors
///
/// - If the linker does not define imports of the instantiated [`Module`].
/// - If any imported item does not satisfy its type requirements.
/// - If the start function traps.
pub fn[T] Linker::instantiate_and_start(
  self : Linker[T],
  store : Store[T],
  module_ : Module,
) -> Instance raise WasmiError {
  if !Engine::same(self.engine, store.inner.engine) {
    abort(
      "assertion failed: Engine::same(self.engine(), context.as_context().engine())",
    )
  }
  let externals = []
  for imp in module_.imports() {
    externals.push(self.process_import(store, imp))
  }
  module_.instantiate(store, externals)
}

///|
/// Processes a single [`Module`] imp.
///
/// # Errors
///
/// If the imported item does not satisfy constraints set by the [`Module`].
fn[T] Linker::process_import(
  self : Linker[T],
  store : Store[T],
  imp : ImportType,
) -> Extern raise WasmiError {
  let module_name = imp.module_()
  let field_name = imp.name()
  guard self.definitions.get((module_name, field_name)) is Some(resolved) else {
    raise Linker(MissingDefinition(name=imp.name, ty=imp.ty))
  }
  let invalid_type = fn() {
    WasmiError::Linker(
      InvalidTypeDefinition(
        name=imp.name,
        expected=imp.ty,
        found=resolved.ty(store),
      ),
    )
  }
  match imp.ty() {
    Func(_) =>
      match resolved.as_func(store) {
        Some(func) => Func(func)
        None => raise invalid_type()
      }
    Table(_) =>
      match resolved {
        Extern(Table(table)) => Table(table)
        _ => raise invalid_type()
      }
    Memory(_) =>
      match resolved {
        Extern(Memory(memory)) => Memory(memory)
        _ => raise invalid_type()
      }
    Global(_) =>
      match resolved {
        Extern(Global(global)) => Global(global)
        _ => raise invalid_type()
      }
  }
}
