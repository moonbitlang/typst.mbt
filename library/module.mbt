// Port of `typst-library/src/foundations/module.rs`.

///|
priv struct ModuleInner {
  scope : Scope
  content : Content
  file_id : @syntax.FileId?
  /// The fingerprint of the fields above (not upstream: modules are shared,
  /// and their scope is not modified once they are built, so they are
  /// hashed once; see `value_hash.mbt` and [LazyFingerprint]).
  hash : LazyFingerprint
  /// Whether the fingerprint identifies the module in a compilation: two
  /// modules with this fingerprint are the same object (not upstream, whose
  /// memoization compares hashes only; see `memo.mbt`). Modules compare by
  /// identity, so this is only so where whoever makes the module says it
  /// ([Module::canonical]):
  /// - the library's modules;
  /// - the module of an evaluated source file (`eval_source_memoized`
  ///   returns one object per file; under IDE tracing a file that holds the
  ///   traced span is evaluated again for an evaluated string, which has no
  ///   traced span, upstream too);
  /// - the module of a plugin that exports functions: their fingerprints
  ///   carry the plugin, and a plugin is loaded once per content
  ///   (`plugin_module_cache`, `plugin_transition_cache`).
  /// It is not so for a plugin that exports no function (all of them have
  /// the same fingerprint) and for what an embedder builds. A fingerprint
  /// that covers such a module is marked `fingerprint_identity`.
  identified : Bool
}

///|
/// A collection of variables and functions that are commonly related to each
/// other.
pub struct Module {
  /// The module's name.
  priv name : String?
  /// The shared inner fields.
  priv inner : ModuleInner
}

///|
/// Create a new module.
pub fn Module::new(name : String, scope : Scope) -> Module {
  {
    name: Some(name),
    inner: {
      scope,
      content: Content::empty(),
      file_id: None,
      hash: LazyFingerprint::new(),
      identified: false,
    },
  }
}

///|
/// Create a new anonymous module without a name.
pub fn Module::anonymous(scope : Scope) -> Module {
  {
    name: None,
    inner: {
      scope,
      content: Content::empty(),
      file_id: None,
      hash: LazyFingerprint::new(),
      identified: false,
    },
  }
}

///|
/// The module, as the one module with its fingerprint in a compilation
/// (not upstream; see `ModuleInner.identified`). For the last step of
/// making a module that is made once: the changes below make a module that
/// is not canonical.
pub fn Module::canonical(self : Module) -> Module {
  {
    name: self.name,
    inner: { ..self.inner, hash: LazyFingerprint::new(), identified: true, },
  }
}

///|
/// Update the module's name.
pub fn Module::with_name(self : Module, name : String) -> Module {
  { name: Some(name), inner: self.inner, }
}

///|
/// Update the module's scope.
pub fn Module::with_scope(self : Module, scope : Scope) -> Module {
  {
    name: self.name,
    inner: {
      ..self.inner,
      scope,
      hash: LazyFingerprint::new(),
      identified: false,
    },
  }
}

///|
/// Update the module's content.
pub fn Module::with_content(self : Module, content : Content) -> Module {
  {
    name: self.name,
    inner: {
      ..self.inner,
      content,
      hash: LazyFingerprint::new(),
      identified: false,
    },
  }
}

///|
/// Update the module's file id.
pub fn Module::with_file_id(self : Module, file_id : @syntax.FileId) -> Module {
  {
    name: self.name,
    inner: {
      ..self.inner,
      file_id: Some(file_id),
      hash: LazyFingerprint::new(),
      identified: false,
    },
  }
}

///|
/// Get the module's name.
pub fn Module::name(self : Module) -> String? {
  self.name
}

///|
/// Access the module's scope.
pub fn Module::scope(self : Module) -> Scope {
  self.inner.scope
}

///|
/// Access the module's file id.
pub fn Module::file_id(self : Module) -> @syntax.FileId? {
  self.inner.file_id
}

///|
/// Try to access a definition in the module.
pub fn Module::field(
  self : Module,
  field : String,
  guard_ : BindingGuard,
) -> Value raise HintedError {
  match self.scope().get(field) {
    Some(binding) =>
      if binding.is_guarded() {
        binding.read(guard_, "access field `\{field}`").shared()
      } else {
        binding.value.shared()
      }
    None =>
      match self.name {
        Some(name) => bail("module `\{name}` does not contain `\{field}`")
        None => bail("module does not contain `\{field}`")
      }
  }
}

///|
/// Extract the module's content.
pub fn Module::content(self : Module) -> Content {
  self.inner.content
}

///|
/// Upstream `Repr for Module`.
pub fn Module::repr(self : Module) -> String {
  match self.name {
    Some(module_) => "<module \{module_}>"
    None => "<module>"
  }
}

///|
/// Upstream `PartialEq for Module`: same name and same shared inner data.
pub impl Eq for Module with fn equal(self, other) {
  self.name == other.name && physical_equal(self.inner, other.inner)
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Module with Eq::{not_equal, equal}
