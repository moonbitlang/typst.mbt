///|
test "absolutize keeps backslashes and parent components on Unix" {
  if @platform.os() == Windows {
    return
  }
  inspect(@platform.absolutize("/tmp/a\\b"), content="/tmp/a\\b")
  inspect(
    @platform.absolutize("/tmp/./link/../x//y"),
    content="/tmp/link/../x/y",
  )
  inspect(@platform.absolutize("/"), content="/")
}

///|
test "double backslashes are not UNC prefixes on Unix" {
  if @platform.os() == Windows {
    return
  }
  inspect(@platform.is_absolute("\\\\server\\share"), content="false")
  inspect(@platform.join("/base", "\\\\x"), content="/base/\\\\x")
}

///|
test "path helpers" {
  @debug.debug_inspect(
    @platform.parent("/a/b/c.typ"),
    content=(
      #|Some("/a/b")
    ),
  )
  @debug.debug_inspect(
    @platform.parent("/a"),
    content=(
      #|Some("/")
    ),
  )
  @debug.debug_inspect(@platform.parent("/"), content="None")
  @debug.debug_inspect(
    @platform.parent("c.typ"),
    content=(
      #|Some("")
    ),
  )
  @debug.debug_inspect(
    @platform.file_name("/a/b/c.typ"),
    content=(
      #|Some("c.typ")
    ),
  )
  @debug.debug_inspect(@platform.file_name("/a/.."), content="None")
  inspect(@platform.join("/a", "b"), content="/a/b")
  inspect(@platform.join("/a/", "b"), content="/a/b")
  inspect(@platform.join("/a", "/b"), content="/b")
}

///|
test "file errors" {
  let err = try @platform.read_file("/nonexistent/typst-mbt-test") catch {
    e => "\{@debug.to_string(e.kind())}: \{e}"
  } noraise {
    _ => "ok"
  }
  inspect(err, content="NotFound: No such file or directory (os error 2)")
  let err = try @platform.read_file("a\u{0}b") catch {
    e => "\{@debug.to_string(e.kind())}: \{e}"
  } noraise {
    _ => "ok"
  }
  inspect(
    err,
    content="InvalidInput: file name contained an unexpected NUL byte",
  )
}
