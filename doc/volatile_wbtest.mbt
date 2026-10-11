// Which files of a session's world change during a compilation
// (`Registry::changes`).

///|
test "the files that change during a session: the listing and every snippet slot, by path" {
  let registry = Registry::new(dir="sub")
  assert_true(registry.changes(registry.origins))
  // A snippet that does not exist yet: a read of it falls through to the
  // caller's world today and is the registry's later in the compilation.
  assert_true(registry.snippets.is_empty())
  assert_true(registry.changes(virtual_file("sub", "<edsl-markup-7>").unwrap()))
  assert_true(
    registry.changes(virtual_file("sub", "<edsl-markup-4095>").unwrap()),
  )
  // Not: the same names in another directory or in a package, and other
  // files of the directory.
  assert_false(registry.changes(virtual_file("", "<edsl-markup-7>").unwrap()))
  assert_false(
    registry.changes(virtual_file("other", "<edsl-origins>").unwrap()),
  )
  assert_false(registry.changes(virtual_file("sub", "main.typ").unwrap()))
  assert_false(registry.changes(virtual_file("sub", "<edsl-markup-7").unwrap()))
  let spec = @syntax.PackageSpec::from_str("@preview/example:0.1.0").unwrap()
  let in_package = @syntax.RootedPath::new(
    Package(spec),
    @syntax.VirtualPath::new("sub/<edsl-markup-7>") catch {
      _ => fail("invalid path")
    },
  ).intern()
  assert_false(registry.changes(in_package))
  // A session at the root of the project.
  let root = Registry::new()
  assert_true(root.changes(root.origins))
  assert_true(root.changes(virtual_file("", "<edsl-markup-0>").unwrap()))
  assert_false(root.changes(virtual_file("sub", "<edsl-markup-0>").unwrap()))
}
