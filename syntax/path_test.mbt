// Ports of the unit tests in upstream `crates/typst-syntax/src/path.rs`.

///|
fn vp(p : String) -> @syntax.VirtualPath raise {
  @syntax.VirtualPath::new(p) catch {
    e => fail(e.to_string())
  }
}

///|
test "virtual path new" {
  let t = (p : String) => {
    try @syntax.VirtualPath::new(p) catch {
      e => "Err(\{e})"
    } noraise {
      v => "Ok(\{v.get_with_slash()})"
    }
  }
  assert_eq(t(""), "Ok(/)")
  assert_eq(t("a/./file.txt"), "Ok(/a/file.txt)")
  assert_eq(t("file.txt"), "Ok(/file.txt)")
  assert_eq(t("/file.txt"), "Ok(/file.txt)")
  assert_eq(t("hello/world"), "Ok(/hello/world)")
  assert_eq(t("hello/world/"), "Ok(/hello/world)")
  assert_eq(t("a///b"), "Ok(/a/b)")
  assert_eq(t("/a///b"), "Ok(/a/b)")
  assert_eq(t("./world.txt"), "Ok(/world.txt)")
  assert_eq(t("./world.txt/"), "Ok(/world.txt)")
  assert_eq(t("hello/.././/wor/ld.typ.extra"), "Ok(/wor/ld.typ.extra)")
  assert_eq(t("hello/.../world"), "Ok(/hello/.../world)")
  assert_eq(t("\u{200b}.."), "Ok(/\u{200b}..)")
  assert_eq(t(".."), "Err(path escapes project root)")
  assert_eq(t("../world.txt"), "Err(path escapes project root)")
  assert_eq(t("a\\world.txt"), "Err(path contains backslash)")
}

///|
test "virtualize unix" {
  let t = (root : String, p : String) => {
    try @syntax.VirtualPath::virtualize(root, p) catch {
      e => "Err(\{e})"
    } noraise {
      v => "Ok(\{v.get_with_slash()})"
    }
  }
  assert_eq(t("/", "/main.typ"), "Ok(/main.typ)")
  assert_eq(t("//a/b", "/a//b///c//d"), "Ok(/c/d)")
  assert_eq(
    t("/home/typst/desktop/", "/home/typst/desktop/src/main.typ"),
    "Ok(/src/main.typ)",
  )
  assert_eq(
    t("/home/typst/desktop/", "/home/typst/main.typ"),
    "Err(path escapes project root)",
  )
  assert_eq(t("", "tests/suite/a.typ"), "Ok(/tests/suite/a.typ)")
}

///|
test "realize" {
  let p = vp("src/text/main.typ")
  assert_eq(
    p.realize("/home/users/typst"),
    "/home/users/typst/src/text/main.typ",
  )
  assert_eq(p.realize(""), "src/text/main.typ")
}

///|
test "file ops" {
  let p1 = vp("src/text/file.typ")
  assert_eq(p1.file_name(), Some("file.typ"))
  assert_eq(p1.file_stem(), Some("file"))
  assert_eq(p1.extension(), Some("typ"))
  assert_true(p1.with_extension("txt") == vp("src/text/file.txt"))
  assert_true(p1.parent() == Some(vp("src/text")))
  let p2 = vp("src")
  assert_eq(p2.file_name(), Some("src"))
  assert_eq(p2.file_stem(), Some("src"))
  assert_eq(p2.extension(), None)
  assert_true(p2.with_extension("txt") == vp("src.txt"))
  assert_true(p2.parent() == Some(vp("/")))
  let p3 = vp("")
  assert_eq(p3.file_name(), None)
  assert_eq(p3.file_stem(), None)
  assert_eq(p3.extension(), None)
  assert_true(p3.with_extension("txt") == p3)
  assert_true(p3.parent() is None)
  let p4 = vp(".hidden")
  assert_eq(p4.file_stem(), Some(".hidden"))
  assert_eq(p4.extension(), None)
}

///|
test "join" {
  let p1 = vp("src")
  assert_eq(
    try p1.join("a\\b") catch {
      e => e.to_string()
    } noraise {
      _ => "ok"
    },
    "path contains backslash",
  )
  let p2 = p1.join("text")
  assert_eq(p2.get_with_slash(), "/src/text")
  let p3 = p2.join("..")
  assert_true(p1 == p3)
  assert_eq(p3.get_with_slash(), "/src")
  let p4 = p3.join("..")
  assert_eq(p4.get_with_slash(), "/")
  assert_eq(
    try p4.join("..") catch {
      e => e.to_string()
    } noraise {
      _ => "ok"
    },
    "path escapes project root",
  )
}

///|
test "relative from" {
  let p1 = vp("src/text/main.typ")
  assert_eq(p1.relative_from(vp("/src/text")), "main.typ")
  assert_eq(p1.relative_from(vp("/src/data")), "../text/main.typ")
  assert_eq(p1.relative_from(vp("src/")), "text/main.typ")
  assert_eq(p1.relative_from(vp("/")), "src/text/main.typ")
  let p2 = vp("src")
  assert_eq(p2.relative_from(vp("src")), "")
  assert_eq(p2.relative_from(vp("src/data")), "..")
}

///|
test "file id interning" {
  let a = @syntax.RootedPath::new(Project, vp("a/b.typ"))
  let id1 = a.intern()
  let id2 = @syntax.RootedPath::new(Project, vp("/a/./b.typ")).intern()
  assert_true(id1 == id2)
  assert_true(id1.get() == a)
  let id3 = @syntax.FileId::unique(a)
  assert_true(id3 != id1)
  assert_true(id3.get() == a)
  assert_eq(id1.vpath().get_without_slash(), "a/b.typ")
}

///|
/// Upstream's manual `Debug` impls (path.rs:62, :183, :386): a virtual path
/// is its text with a slash, debug-quoted; a rooted path prefixes the
/// package; a file id prints its rooted path.
test "path debug" {
  let project = @syntax.RootedPath::new(Project, vp("src/a b.typ"))
  assert_eq(@debug.to_string(project.vpath()), "\"/src/a b.typ\"")
  assert_eq(@debug.to_string(project), "\"/src/a b.typ\"")
  assert_eq(@debug.to_string(project.intern()), "\"/src/a b.typ\"")
  assert_eq(@debug.to_string(vp("a\"b\u{7f}.typ")), "\"/a\\\"b\\u{7f}.typ\"")
  guard! @syntax.PackageSpec::from_str("@preview/foo:0.1.0") is Ok(spec)
  let packaged = @syntax.RootedPath::new(Package(spec), vp("lib.typ"))
  assert_eq(@debug.to_string(packaged), "@preview/foo:0.1.0\"/lib.typ\"")
  assert_eq(
    @debug.to_string(packaged.intern()),
    "@preview/foo:0.1.0\"/lib.typ\"",
  )
  assert_eq(
    @debug.to_string(Some(packaged.intern())),
    "Some(@preview/foo:0.1.0\"/lib.typ\")",
  )
  // `VirtualRoot` derives `Debug` upstream too.
  assert_eq(@debug.to_string(packaged.root()), "Package(@preview/foo:0.1.0)")
}
