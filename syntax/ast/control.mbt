// Rules, control flow, imports and includes.

///|
/// The function to set style properties for.
pub fn SetRule::target(self : SetRule) -> Expr {
  cast_first(self.node)
}

///|
/// The style properties to set.
pub fn SetRule::args(self : SetRule) -> Args {
  cast_last(self.node)
}

///|
/// A condition under which the set rule applies.
pub fn SetRule::condition(self : SetRule) -> Expr? {
  find_after(self.node, If)
}

///|
/// Defines which nodes the show rule applies to.
pub fn ShowRule::selector(self : ShowRule) -> Expr? {
  let children = self.node.children()
  let mut found = false
  for i = children.length() - 1; i >= 0; i = i - 1 {
    let child = children[i]
    if !found && !(child.kind() is Colon) {
      continue
    }
    found = true
    if Expr::from_untyped(child) is Some(expr) {
      return Some(expr)
    }
  }
  None
}

///|
/// The transformation recipe.
pub fn ShowRule::transform(self : ShowRule) -> Expr {
  cast_last(self.node)
}

///|
/// The expression which depends on the context.
pub fn Contextual::body(self : Contextual) -> Expr {
  cast_first(self.node)
}

///|
/// The condition which selects the body to evaluate.
pub fn Conditional::condition(self : Conditional) -> Expr {
  cast_first(self.node)
}

///|
/// The expression to evaluate if the condition is true.
pub fn Conditional::if_body(self : Conditional) -> Expr {
  match (cast_children(self.node) : Iter[Expr]).nth(1) {
    Some(expr) => expr
    None => Expr::placeholder()
  }
}

///|
/// The expression to evaluate if the condition is false.
pub fn Conditional::else_body(self : Conditional) -> Expr? {
  (cast_children(self.node) : Iter[Expr]).nth(2)
}

///|
/// The condition which selects whether to evaluate the body.
pub fn WhileLoop::condition(self : WhileLoop) -> Expr {
  cast_first(self.node)
}

///|
/// The expression to evaluate while the condition is true.
pub fn WhileLoop::body(self : WhileLoop) -> Expr {
  cast_last(self.node)
}

///|
/// The pattern to assign to.
pub fn ForLoop::pattern(self : ForLoop) -> Pattern {
  cast_first(self.node)
}

///|
/// The expression to iterate over.
pub fn ForLoop::iterable(self : ForLoop) -> Expr {
  match find_after(self.node, In) {
    Some(expr) => expr
    None => Expr::placeholder()
  }
}

///|
/// The expression to evaluate for each iteration.
pub fn ForLoop::body(self : ForLoop) -> Expr {
  cast_last(self.node)
}

///|
/// The module or path from which the items should be imported.
pub fn ModuleImport::source(self : ModuleImport) -> Expr {
  cast_first(self.node)
}

///|
/// The items to be imported.
pub fn ModuleImport::imports(self : ModuleImport) -> Imports? {
  for node in self.node.children() {
    match node.kind() {
      Star => return Some(Wildcard)
      ImportItems =>
        if ImportItems::from_untyped(node) is Some(items) {
          return Some(Items(items))
        }
      _ => ()
    }
  }
  None
}

///|
/// The name that will be bound for a bare import. This name must be
/// statically known. It can come from:
/// - an identifier
/// - a field access
/// - a string that is a valid file path where the file stem is a valid
///   identifier
/// - a string that is a valid package spec
pub fn ModuleImport::bare_name(
  self : ModuleImport,
) -> Result[String, BareImportError] {
  match self.source() {
    Ident(ident) => Ok(ident.get())
    FieldAccess(access) => Ok(access.field().get())
    Str(string) => {
      let string = string.get()
      let name = if string.has_prefix("@") {
        match @syntax.PackageSpec::from_str(string) {
          Ok(spec) => spec.name
          Err(_) => return Err(PackageInvalid)
        }
      } else {
        match path_file_stem(string) {
          Some(stem) => stem
          None => return Err(PathInvalid)
        }
      }
      if !@syntax.is_ident(name) {
        return Err(PathInvalid)
      }
      Ok(name)
    }
    _ => Err(Dynamic)
  }
}

///|
/// Rust's `Path::new(path).file_stem()` for Unix paths: the final normal
/// component of the path (ignoring empty and `.` components) without its
/// extension. A leading dot does not start an extension.
fn path_file_stem(path : String) -> String? {
  let mut name : String? = None
  for part in path.split("/") {
    if part.is_empty() || part == "." {
      continue
    }
    name = Some(part.to_owned())
  }
  guard name is Some(name) && name != ".." else { return None }
  match name.rev_find(".") {
    None | Some(0) => Some(name)
    Some(i) => Some(name.unsafe_substring(start=0, end=i))
  }
}

///|
/// The name this module was assigned to, if it was renamed with `as`
/// (`renamed` in `import "..." as renamed`).
pub fn ModuleImport::new_name(self : ModuleImport) -> Ident? {
  find_after(self.node, As)
}

///|
/// Reasons why a bare name cannot be determined for an import source.
pub(all) enum BareImportError {
  /// There is no statically resolvable binding name.
  Dynamic
  /// The import source is not a valid path or the path stem not a valid
  /// identifier.
  PathInvalid
  /// The import source is not a valid package spec.
  PackageInvalid
} derive(Eq, Hash, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BareImportError with Eq::{not_equal, equal}

///|
#deprecated("call as `Hash::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BareImportError with Hash::{hash, hash_combine}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend BareImportError with @debug.Debug::{to_repr}

///|
/// The items that ought to be imported from a file.
pub(all) enum Imports {
  /// All items in the scope of the file should be imported.
  Wildcard
  /// The specified items from the file should be imported.
  Items(ImportItems)
}

///|
/// Returns an iterator over the items to import from the module.
pub fn ImportItems::iter(self : ImportItems) -> Iter[ImportItem] {
  self.node
  .children()
  .iter()
  .filter_map(child => {
    match child.kind() {
      RenamedImportItem =>
        RenamedImportItem::from_untyped(child).map(v => Renamed(v))
      ImportItemPath => ImportItemPath::from_untyped(child).map(v => Simple(v))
      _ => None
    }
  })
}

///|
/// An iterator over the path's components.
pub fn ImportItemPath::iter(self : ImportItemPath) -> Iter[Ident] {
  cast_children(self.node)
}

///|
/// The name of the imported item. This is the last segment in the path.
pub fn ImportItemPath::name(self : ImportItemPath) -> Ident {
  cast_last(self.node)
}

///|
/// An imported item, potentially renamed to another identifier.
pub(all) enum ImportItem {
  /// A non-renamed import (the item's name in the scope is the same as its
  /// name).
  Simple(ImportItemPath)
  /// A renamed import (the item was bound to a different name in the scope
  /// than the one it was defined as).
  Renamed(RenamedImportItem)
}

///|
/// The path to the imported item.
pub fn ImportItem::path(self : ImportItem) -> ImportItemPath {
  match self {
    Simple(path) => path
    Renamed(renamed_item) => renamed_item.path()
  }
}

///|
/// The original name of the imported item, at its source. This will be the
/// equal to the bound name if the item wasn't renamed with 'as'.
pub fn ImportItem::original_name(self : ImportItem) -> Ident {
  match self {
    Simple(path) => path.name()
    Renamed(renamed_item) => renamed_item.original_name()
  }
}

///|
/// The name which this import item was bound to. Corresponds to the new
/// name, if it was renamed; otherwise, it's just its original name.
pub fn ImportItem::bound_name(self : ImportItem) -> Ident {
  match self {
    Simple(path) => path.name()
    Renamed(renamed_item) => renamed_item.new_name()
  }
}

///|
/// The path to the imported item.
pub fn RenamedImportItem::path(self : RenamedImportItem) -> ImportItemPath {
  cast_first(self.node)
}

///|
/// The original name of the imported item (`a` in `a as d` or `c.b.a as d`).
pub fn RenamedImportItem::original_name(self : RenamedImportItem) -> Ident {
  self.path().name()
}

///|
/// The new name of the imported item (`d` in `a as d`).
pub fn RenamedImportItem::new_name(self : RenamedImportItem) -> Ident {
  cast_last(self.node)
}

///|
/// The module or path from which the content should be included.
pub fn ModuleInclude::source(self : ModuleInclude) -> Expr {
  cast_last(self.node)
}

///|
/// The expression to return.
pub fn FuncReturn::body(self : FuncReturn) -> Expr? {
  try_cast_last(self.node)
}
