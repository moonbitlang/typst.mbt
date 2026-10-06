///|
fn version(s : String) -> @syntax.PackageVersion raise {
  match @syntax.PackageVersion::from_str(s) {
    Ok(v) => v
    Err(e) => fail(e)
  }
}

///|
fn bound(s : String) -> @syntax.VersionBound raise {
  match @syntax.VersionBound::from_str(s) {
    Ok(v) => v
    Err(e) => fail(e)
  }
}

///|
/// Port of upstream `version_version_match`.
test "version version match" {
  let v1_1_1 = version("1.1.1")
  assert_true(v1_1_1.matches_eq(bound("1")))
  assert_true(v1_1_1.matches_eq(bound("1.1")))
  assert_true(!v1_1_1.matches_eq(bound("1.2")))
  assert_true(!v1_1_1.matches_gt(bound("1")))
  assert_true(v1_1_1.matches_gt(bound("1.0")))
  assert_true(!v1_1_1.matches_gt(bound("1.1")))
  assert_true(!v1_1_1.matches_lt(bound("1")))
  assert_true(!v1_1_1.matches_lt(bound("1.1")))
  assert_true(v1_1_1.matches_lt(bound("1.2")))
}

///|
test "package spec parsing" {
  let show = (r : Result[@syntax.PackageSpec, String]) => {
    match r {
      Ok(spec) => "Ok(\{spec})"
      Err(e) => "Err(\{e})"
    }
  }
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/foo:0.1.0")),
    content="Ok(@preview/foo:0.1.0)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/foo:+1.2.3")),
    content="Ok(@preview/foo:1.2.3)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("preview/foo:0.1.0")),
    content="Err(package specification must start with '@')",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@/foo:0.1.0")),
    content="Err(package specification is missing namespace)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@1x/foo:0.1.0")),
    content="Err(`1x` is not a valid package namespace)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview")),
    content="Err(package specification is missing name)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/f-o:0.1.0")),
    content="Ok(@preview/f-o:0.1.0)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/foo")),
    content="Err(package specification is missing version)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/foo:1")),
    content="Err(version number is missing minor version)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/foo:1..2")),
    content="Err(version number is missing minor version)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/foo:1.x.2")),
    content="Err(`x` is not a valid minor version)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/foo:1.2.3.4")),
    content="Err(version number has unexpected fourth component: `4`)",
  )
  inspect(
    show(@syntax.PackageSpec::from_str("@preview/foo:1.2.4294967296")),
    content="Err(`4294967296` is not a valid patch version)",
  )
  let versionless = (s : String) => {
    match @syntax.VersionlessPackageSpec::from_str(s) {
      Ok(spec) => "Ok(\{spec})"
      Err(e) => "Err(\{e})"
    }
  }
  inspect(versionless("@preview/foo"), content="Ok(@preview/foo)")
  inspect(
    versionless("@preview/foo:0.1.0"),
    content="Err(unexpected version in versionless package specification)",
  )
}

///|
test "version bound parsing" {
  let show = (s : String) => {
    match @syntax.VersionBound::from_str(s) {
      Ok(b) => "Ok(\{b})"
      Err(e) => "Err(\{e})"
    }
  }
  inspect(show("1"), content="Ok(1)")
  inspect(show("1.2"), content="Ok(1.2)")
  inspect(show("1.2.3"), content="Ok(1.2.3)")
  inspect(show(""), content="Err(`` is not a valid major version bound)")
  inspect(
    show("1.2.3.4"),
    content="Err(version bound has unexpected fourth component: `4`)",
  )
}

///|
test "package manifest" {
  let spec = match @syntax.PackageSpec::from_str("@test/future:0.1.0") {
    Ok(s) => s
    Err(e) => fail(e)
  }
  let text =
    #|# A manifest.
    #|[package]
    #|name = "future"
    #|version = "0.1.0"
    #|entrypoint = 'lib.typ'
    #|authors = ["A", "Bé",]
    #|compiler = "1.0.0"
    #|extra = { a = 1, b.c = [1.5, true] }
    #|
    #|[tool.my-tool]
    #|key = """
    #|value"""
  let manifest = match @syntax.PackageManifest::from_toml(text) {
    Ok(m) => m
    Err(e) => fail(e)
  }
  assert_eq(manifest.package_.entrypoint, "lib.typ")
  assert_eq(manifest.package_.authors, ["A", "Bé"])
  assert_eq(manifest.package_.unknown_fields, ["extra"])
  assert_eq(manifest.tool.sections, ["my-tool"])
  assert_eq(
    manifest.validate(spec),
    Err("package requires Typst 1.0.0 or newer (current version is 0.15.1)"),
  )
  let missing = @syntax.PackageManifest::from_toml("[package]\nname = \"x\"\n")
  assert_true(missing is Err("missing field `version`"))
  let wrong = @syntax.PackageManifest::from_toml(
    "[package]\nname = 1\nversion = \"0.1.0\"\nentrypoint = \"a\"",
  )
  assert_true(wrong is Err("invalid type: integer `1`, expected a string"))
}

///|
/// Upstream `{:?}` of a package spec is its `Display` form (package.rs:256,
/// :302), also inside other values.
test "package spec debug" {
  guard! @syntax.PackageSpec::from_str("@preview/foo:0.1.0") is Ok(spec)
  assert_eq(@debug.to_string(spec), "@preview/foo:0.1.0")
  assert_eq(@debug.to_string(spec.versionless()), "@preview/foo")
  assert_eq(@debug.to_string(Some(spec)), "Some(@preview/foo:0.1.0)")
}
