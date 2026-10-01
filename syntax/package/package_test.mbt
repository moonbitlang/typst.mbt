///|
fn version(s : String) -> @package.PackageVersion raise {
  match @package.PackageVersion::from_str(s) {
    Ok(v) => v
    Err(e) => fail(e)
  }
}

///|
fn bound(s : String) -> @package.VersionBound raise {
  match @package.VersionBound::from_str(s) {
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
  let show = (r : Result[@package.PackageSpec, String]) => {
    match r {
      Ok(spec) => "Ok(\{spec})"
      Err(e) => "Err(\{e})"
    }
  }
  inspect(
    show(@package.PackageSpec::from_str("@preview/foo:0.1.0")),
    content="Ok(@preview/foo:0.1.0)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview/foo:+1.2.3")),
    content="Ok(@preview/foo:1.2.3)",
  )
  inspect(
    show(@package.PackageSpec::from_str("preview/foo:0.1.0")),
    content="Err(package specification must start with '@')",
  )
  inspect(
    show(@package.PackageSpec::from_str("@/foo:0.1.0")),
    content="Err(package specification is missing namespace)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@1x/foo:0.1.0")),
    content="Err(`1x` is not a valid package namespace)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview")),
    content="Err(package specification is missing name)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview/f-o:0.1.0")),
    content="Ok(@preview/f-o:0.1.0)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview/foo")),
    content="Err(package specification is missing version)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview/foo:1")),
    content="Err(version number is missing minor version)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview/foo:1..2")),
    content="Err(version number is missing minor version)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview/foo:1.x.2")),
    content="Err(`x` is not a valid minor version)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview/foo:1.2.3.4")),
    content="Err(version number has unexpected fourth component: `4`)",
  )
  inspect(
    show(@package.PackageSpec::from_str("@preview/foo:1.2.4294967296")),
    content="Err(`4294967296` is not a valid patch version)",
  )
  let versionless = (s : String) => {
    match @package.VersionlessPackageSpec::from_str(s) {
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
    match @package.VersionBound::from_str(s) {
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
