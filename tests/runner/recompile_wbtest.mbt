// The parts of the `recompile` stage that do not compile anything: the
// file set, the edits and the names of snapshots.

///|
/// A file set over a disk that has `on-disk.txt` only.
fn recompile_test_files() -> FileSet {
  FileSet::new(
    id => {
      if file_path(id) == "on-disk.txt" {
        b"disk"
      } else {
        raise @library.FileError::NotFound("disk/" + file_path(id))
      }
    },
    [(project_file("main.typ"), b"= Title\n\nSome text with 12 words.\n")],
  )
}

///|
/// What a file set says of a file.
fn recompile_test_show(files : FileSet, path : String) -> String {
  match files.get(project_file(path)) {
    Ok(bytes) => "ok " + decoded(bytes).unwrap_or("?")
    Err(err) => "err " + err.to_string()
  }
}

///|
test "recompile: splice replaces a range of bytes" {
  let spliced = (start : Int, end : Int, replacement : Bytes) => {
    decoded(splice(b"abcdef", start, end, replacement)).unwrap_or("?")
  }
  inspect(spliced(2, 4, b"XYZ"), content="abXYZef")
  inspect(spliced(0, 0, b"X"), content="Xabcdef")
  inspect(spliced(6, 6, b"X"), content="abcdefX")
  inspect(spliced(1, 6, b""), content="a")
}

///|
test "recompile: an edited file, a removed file and a file that never was" {
  let files = recompile_test_files()
  let on_disk = project_file("on-disk.txt")
  let never = project_file("never.txt")
  inspect(recompile_test_show(files, "on-disk.txt"), content="ok disk")
  inspect(
    recompile_test_show(files, "never.txt"),
    content="err file not found (searched at disk/never.txt)",
  )
  // A snapshot does not see later edits.
  let before = files.copy()
  files.set(on_disk, Some(b"edited"))
  files.set(never, Some(b"created"))
  inspect(recompile_test_show(files, "on-disk.txt"), content="ok edited")
  inspect(recompile_test_show(files, "never.txt"), content="ok created")
  inspect(recompile_test_show(before, "on-disk.txt"), content="ok disk")
  inspect(
    recompile_test_show(before, "never.txt"),
    content="err file not found (searched at disk/never.txt)",
  )
  // A file of the disk that is removed is not found; a file that never was
  // on disk is, once removed, what it was: the disk's error.
  files.set(on_disk, None)
  files.set(never, None)
  inspect(
    recompile_test_show(files, "on-disk.txt"),
    content="err file not found (searched at on-disk.txt)",
  )
  inspect(
    recompile_test_show(files, "never.txt"),
    content="err file not found (searched at disk/never.txt)",
  )
}

///|
test "recompile: every content of a file is kept, and a file can go back" {
  let files = recompile_test_files()
  let main = project_file("main.typ")
  let variant : Variant = { main, inputs: 0, day: 0, fonts: 0, }
  let project = Project::new(files, variant)
  let first = project.content(main)
  project.set(main, Some(b"B"))
  // The same bytes again are not another version.
  project.set(main, Some(b"B"))
  project.set(main, None)
  project.set(main, first)
  inspect(project.versions[main].length(), content="3")
  assert_true(project.versions[main][0] == first)
  assert_true(project.content(main) == first)
}

///|
test "recompile: the places of harmless edits are byte offsets" {
  let text = "#set text(size: 11pt)\n= Ünïcode\n\nWörter und 3 Zahlen.\n\n#let x = 0.5\n"
  let sites = Sites::of(text)
  let bytes = @utf8.encode(text)
  let at = (site : (Int, Int)) => ascii(bytes, site.0, site.1)
  inspect(sites.set_numbers.map(at).join(" "), content="11pt")
  inspect(sites.numbers.map(at).join(" "), content="11pt 0.5")
  inspect(sites.parbreaks.length(), content="2")
  // Text leaves start and end between characters.
  for site in sites.text {
    assert_true(decoded(splice(bytes, site.0, site.0 + site.1, b"")) is Some(_))
  }
}

///|
test "recompile: a changed number is another number of the same length" {
  let rng : Rng = { state: 7UL, }
  for literal in ["7", "12", "1.5em", "100%", "3.25", "0"] {
    for _ in 0..<50 {
      let changed = changed_number(rng, literal)
      assert_true(changed != literal)
      assert_true(changed.length() == literal.length())
    }
  }
  // Not decimal: replaced as a whole.
  assert_true(changed_number(rng, "0xff") != "0xff")
}

///|
test "recompile: the edits are a function of the seed and the files" {
  let run = (seed : UInt64) => {
    let files = recompile_test_files()
    let main = project_file("main.typ")
    let project = Project::new(files, { main, inputs: 0, day: 0, fonts: 0, })
    project.note([project_file("on-disk.txt"), project_file("never.txt")])
    let rng : Rng = { state: seed, }
    let edits = []
    for _ in 0..<40 {
      edits.push(project.edit(rng))
    }
    let contents = project.known.map(id => {
      match project.content(id) {
        Some(bytes) => sha256_hex(bytes[:])
        None => "-"
      }
    })
    (edits, contents, project.variant.day, project.variant.inputs)
  }
  let (edits, contents, day, inputs) = run(42UL)
  let (edits2, contents2, day2, inputs2) = run(42UL)
  assert_true(edits == edits2)
  assert_true(contents == contents2)
  assert_true(day == day2 && inputs == inputs2)
  let (other, _, _, _) = run(43UL)
  assert_true(edits != other)
  // Every kind of thing a sequence can do is among 40 edits of some seed.
  let kinds : Map[String, Unit] = Map([])
  for seed in 0..<60 {
    for edit in run(seed.to_uint64()).0 {
      kinds[edit_kind(edit)] = ()
    }
  }
  for
    kind in [
      "nothing", "touch", "today", "inputs", "fonts", "two-files", "revert", "remove",
      "create", "repair", "insert-text", "append-block", "change-number", "add-set-rule",
      "insert-breaker", "change-digit", "truncate",
    ] {
    assert_true(kinds.contains(kind))
  }
}

///|
test "recompile: the sweep changes every file once and then nothing is left" {
  let files = recompile_test_files()
  let main = project_file("main.typ")
  let project = Project::new(files, { main, inputs: 0, day: 0, fonts: 0, })
  let first = project.content(main)
  project.note([project_file("on-disk.txt")])
  let rng : Rng = { state: 1UL, }
  let sweep = Sweep::new(16, true)
  let edits = []
  // The document "compiles" after every step but the third.
  while project.sweep(rng, sweep, edits.length() != 2) is Some(edit) {
    edits.push(edit_kind(edit))
  }
  // No file reads the date or `sys.inputs`; the edit of the main file is
  // undone with the next one.
  inspect(edits.length(), content="4")
  inspect(edits[0], content="fonts")
  inspect(edits[2], content="change-letter")
  inspect(edits[3], content="everything-back")
  assert_true(project.content(main) == first)
  inspect(recompile_test_show(files, "on-disk.txt"), content="ok disk")
  inspect(project.variant.fonts, content="0")
}

///|
test "recompile: a snapshot names its files so that they are found again" {
  for
    path in [
      "main.typ", "tests/suite/layout/grid.typ", "@preview/cetz:0.5.2/src/lib.typ",
      "@test/adder:0.1.0/typst.toml",
    ] {
    assert_eq(file_path(file_of_path(path)), path)
  }
}

///|
test "recompile: a page image is written again only if the hash of its page changed" {
  // The CLI's rule (`ExportCache`): the files of a watching compiler are
  // those of the last compilation only where the page hashes say so.
  let filled = (red : Float) => {
    let frame = @library.Frame::soft(size(20.0, 10.0))
    frame.push(
      pos(0.0, 0.0),
      Shape(
        @library.Geometry::Rect(size(20.0, 10.0)).filled(
          Solid(rgb(red, 0.0, 0.0)),
        ),
        @syntax.Span::detached(),
      ),
    )
    page(frame)
  }
  let lines = (pages : PageFiles, document : Array[@layout.Page]) => {
    let written = pages.write(
      @layout.PagedDocument::new(
        document,
        @library.DocumentInfo::new(),
        @library.DocumentFormatOptions::new(),
      ),
    )
    written.split("\n").map(line => line.to_owned()).collect()
  }
  let files = PageFiles::new()
  let first = lines(files, [filled(1.0), filled(0.5)])
  // (Two lines and what follows the last line break.)
  inspect(first.length(), content="3")
  assert_true(first[0].has_prefix("page 1: 10x5 "))
  assert_true(first[1].has_prefix("page 2: 10x5 "))
  assert_true(files.files[0] != files.files[1])
  // The same pages again: the same files, which are what a compiler
  // without files writes.
  assert_eq(lines(files, [filled(1.0), filled(0.5)]), first)
  assert_eq(lines(PageFiles::new(), [filled(1.0), filled(0.5)]), first)
  // One page changes and one is new: the file of the first stays.
  let image = files.files[1]
  let third = lines(files, [filled(1.0), filled(0.25), filled(0.5)])
  assert_eq(third[0], first[0])
  assert_true(files.files[1] != image)
  assert_eq(files.files[2], image)
  // A page whose hash did not change keeps its file, whatever is in it:
  // that is the cache, and where a fingerprint that says too little shows.
  files.files[0] = "stale"
  let kept = lines(files, [filled(1.0), filled(0.25), filled(0.5)])
  inspect(kept[0], content="page 1: stale")
  // A shorter document leaves the files of the pages it no longer has, and
  // their hashes: a page that comes back as it was is not written.
  lines(files, [filled(0.75)]) |> ignore
  files.files[2] = "left on disk"
  let back = lines(files, [filled(0.75), filled(0.25), filled(0.5)])
  inspect(back[0], content="page 1: " + files.files[0])
  assert_true(back[0] != "page 1: stale")
  inspect(back[2], content="page 3: left on disk")
}

///|
/// What a compilation gave, as far as [pinned_verdict] looks: pages that
/// show `svg`.
fn pinned_test_compiled(
  svg : String,
  dependencies? : String = "main.typ\na.typ",
  diagnostics? : String = "ok\n",
) -> Compiled {
  {
    parts: [
      dependencies,
      diagnostics,
      "frames of \{svg}",
      "",
      "merged \{svg}",
      "images of \{svg}",
      "ok\n",
      "pdf of \{svg}",
    ],
    pdf: @utf8.encode(svg),
    ok: true,
    document: None,
    reparsed: [],
    cli_svg: Some(svg),
  }
}

///|
fn pinned_test_verdict(
  step : PinnedStep,
  expected : Compiled,
  actual : Compiled,
) -> String {
  match pinned_verdict(step, expected, actual) {
    Same => "same"
    AsUpstream => "as upstream's watch"
    Fails(reason) => "fails: \{reason}"
  }
}

///|
test "recompile: the one difference from a fresh compilation that passes is upstream's watch's, at its step" {
  let fresh = pinned_test_compiled("FRESH")
  let stale = pinned_test_compiled("WATCH")
  let agrees : PinnedStep = {
    edit: "an edit",
    files: [],
    fresh: "FRESH",
    watch: None,
  }
  let differs : PinnedStep = { ..agrees, watch: Some("WATCH"), }
  // The loop gives what a fresh compilation gives: always fine.
  inspect(pinned_test_verdict(agrees, fresh, fresh), content="same")
  inspect(pinned_test_verdict(differs, fresh, fresh), content="same")
  // It gives what upstream's watch gave, where that is something else.
  inspect(
    pinned_test_verdict(differs, fresh, stale),
    content="as upstream's watch",
  )
  // Where upstream's watch gives what a fresh compilation gives, the loop
  // must too.
  inspect(
    pinned_test_verdict(agrees, fresh, stale),
    content="fails: frames, svg, page images, pdf differ from a fresh compilation, where upstream's watch gives what a fresh compilation gives",
  )
  // Something else than both.
  inspect(
    pinned_test_verdict(differs, fresh, pinned_test_compiled("OTHER")),
    content="fails: frames, svg, page images, pdf differ from a fresh compilation, and the pages are not what upstream's watch gives either",
  )
  // Upstream's pages with other dependencies or diagnostics: a stale
  // result of another kind next to the accepted one.
  inspect(
    pinned_test_verdict(
      differs,
      fresh,
      pinned_test_compiled("WATCH", dependencies="main.typ"),
    ),
    content="fails: the pages are what upstream's watch gives, but the dependencies differ from a fresh compilation",
  )
  inspect(
    pinned_test_verdict(
      differs,
      fresh,
      pinned_test_compiled("WATCH", diagnostics="ok\nwarning: stale\n"),
    ),
    content="fails: the pages are what upstream's watch gives, but the diagnostics differ from a fresh compilation",
  )
  // A fresh compilation that is not upstream's fresh compilation: the
  // fixture is of other files, or the port's answer from scratch is not
  // upstream's. Whatever the loop gave.
  for actual in [pinned_test_compiled("OTHER"), stale] {
    inspect(
      pinned_test_verdict(differs, pinned_test_compiled("OTHER"), actual),
      content="fails: a fresh compilation does not give the SVG of upstream's fresh compilation",
    )
  }
  // A document that does not compile has no pages to be upstream's.
  let failed : Compiled = { ..pinned_test_compiled("WATCH"), cli_svg: None, }
  inspect(
    pinned_test_verdict(differs, fresh, failed),
    content="fails: frames, svg, page images, pdf differ from a fresh compilation, and the pages are not what upstream's watch gives either",
  )
}

///|
test "recompile: the fixtures of upstream's watch" {
  let fixture = pinned_parse(
    "example",
    (
      #|{"upstream": "typst", "steps": [
      #| {"edit": "the project", "files": {"main.typ": "A\n", "a.typ": "B"}, "fresh": "<svg/>", "watch": null},
      #| {"edit": "an edit", "files": {"a.typ": "C"}, "fresh": "<svg/>", "watch": "<svg a/>"}
      #|]}
    ),
  )
  assert_eq(fixture.steps.length(), 2)
  assert_eq(fixture.steps[0].files, [("main.typ", "A\n"), ("a.typ", "B")])
  assert_true(fixture.steps[0].watch is None)
  assert_eq(fixture.steps[1].watch, Some("<svg a/>"))
  let document = fixture.document()
  inspect(document.name, content="upstream/example")
  assert_eq(document.files.length(), 2)
  // Those of the repository: each starts with a fresh compilation and has
  // a step at which upstream's watch gives something else.
  let pinned = pinned_sequences()
  assert_eq(pinned.map(fixture => fixture.name), ["getter", "modules"])
  for fixture in pinned {
    assert_true(fixture.steps[0].watch is None)
    assert_true(fixture.steps.iter().any(step => step.watch is Some(_)))
    for step in fixture.steps {
      assert_true(step.fresh.has_prefix("<svg "))
      assert_false(step.watch == Some(step.fresh))
    }
  }
}
