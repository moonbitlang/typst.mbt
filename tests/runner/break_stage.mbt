// The `break` stage: bidi levels/runs, line break opportunities, word bounds
// and hyphenation. Mirrors `oracle/src/breaking.rs`; every golden record
// carries its input, so sections are recomputed from the golden alone.

///|
fn run_break_stage(filter : String?, verbose : Bool) -> Unit {
  let dir = golden_dir + "/break"
  let files = []
  fn walk(dir : String) {
    let entries = (@fs.read_dir(dir) catch { _ => [][:] }).to_owned()
    for entry in entries {
      let path = dir + "/" + entry
      let is_dir = @fs.is_dir(path) catch { _ => false }
      if is_dir {
        walk(path)
      } else if path.has_suffix(".txt") {
        files.push(path)
      }
    }
  }

  walk(dir)
  files.sort()
  let mut passed = 0
  let mut failed = 0
  let failures = []
  for path in files {
    let rel = path.unsafe_substring(start=dir.length() + 1, end=path.length())
    let golden = split_golden(read(path))
    let dump = StringBuilder()
    for name, expected in golden {
      if filter is Some(f) && !name.contains(f) {
        continue
      }
      let actual = break_section(expected)
      dump.write_string("=== \{name}\n\{actual}")
      if actual == expected {
        passed += 1
      } else {
        failed += 1
        failures.push((rel, name, expected, actual))
      }
    }
    if dump_actual.val && dump.to_string() != "" {
      let out = "_build/actual/break/" + rel
      ensure_parent_dir(out)
      @fs.write_string_to_file(out, dump.to_string()) catch {
        _ => ()
      }
    }
  }
  for f in failures {
    let (rel, name, expected, actual) = f
    println("FAIL \{rel} :: \{name}")
    if verbose {
      println(first_diff(expected, actual))
    }
  }
  println("break: \{passed} passed, \{failed} failed")
}

///|
/// Recompute a golden section from the inputs it records.
fn break_section(expected : String) -> String {
  let out = StringBuilder()
  let mut lang = "en"
  for line in expected.split("\n") {
    let line = line.to_owned()
    if line.has_prefix("lang: ") {
      lang = line.unsafe_substring(start=6, end=line.length())
      out.write_string(line + "\n")
    } else if line.has_prefix("text: ") {
      let text = parse_hex(line.unsafe_substring(start=6, end=line.length()))
      out.write_string(line + "\n")
      out.write_string(break_text_report(text, lang))
    } else if line.has_prefix("line: ") {
      let text = parse_hex(line.unsafe_substring(start=6, end=line.length()))
      out.write_string(line + "\n")
      out.write_string(break_line_report(text))
    } else if line.has_prefix("word: ") {
      let text = parse_hex(line.unsafe_substring(start=6, end=line.length()))
      out.write_string(line + "\n")
      out.write_string(break_word_report(text))
    } else if line.has_prefix("bidi: ") {
      let rest = line.unsafe_substring(start=6, end=line.length())
      let (dir, hex) = match rest.find(" ") {
        Some(k) =>
          (
            rest.unsafe_substring(start=0, end=k),
            rest.unsafe_substring(start=k + 1, end=rest.length()),
          )
        None => (rest, "")
      }
      out.write_string(bidi_record(parse_hex(hex), dir, hex))
    }
  }
  out.to_string()
}

///|
fn parse_hex(s : String) -> String {
  let buf = StringBuilder()
  for part in s.split(" ") {
    if part.is_empty() {
      continue
    }
    let mut v = 0
    for c in part {
      let d = if c >= '0' && c <= '9' {
        c.to_int() - '0'.to_int()
      } else {
        c.to_int() - 'A'.to_int() + 10
      }
      v = v * 16 + d
    }
    buf.write_char(Int::unsafe_to_char(v))
  }
  buf.to_string()
}

///|
fn join_ints(v : Array[Int]) -> String {
  v.map(x => x.to_string()).join(" ")
}

///|
fn break_line_report(text : String) -> String {
  "lb: \{join_ints(@linebreak.default_segmenter().segment_str(text))}\n" +
  "lb-cj: \{join_ints(@linebreak.cj_segmenter().segment_str(text))}\n"
}

///|
fn break_word_report(text : String) -> String {
  let lens = @unicode.split_word_bounds(text).map(w => @syntax.utf8_len(w))
  "words: \{join_ints(lens)}\n"
}

///|
fn all_alphabetic(s : StringView) -> Bool {
  for c in s {
    if !@unicode.is_alphabetic(c) {
      return false
    }
  }
  true
}

///|
fn break_text_report(text : String, lang : String) -> String {
  let out = StringBuilder()
  out.write_string(break_line_report(text))
  out.write_string(break_word_report(text))
  let hlang = @hypher.Lang::from_iso(lang)

  // Hyphenation of every alphabetic word-bound segment.
  if hlang is Some(hlang) {
    let words = []
    for w in @unicode.split_word_bounds(text) {
      if !w.is_empty() && all_alphabetic(w) {
        words.push(@hypher.hyphenate(w.to_owned(), hlang).join("|"))
      }
    }
    out.write_string("hyph: \{words.join(" ")}\n")
  }

  // Typst's breakpoints.
  for pair in [("bp", false), ("bp-cj", true)] {
    let (label, cj) = pair
    let points = []
    @linebreak.breakpoints(
      text,
      cj~,
      hyphenate=true,
      lang_at=_ => hlang,
      hyphenate_at=_ => true,
      (i, bp) => {
        points.push(
          match bp {
            Normal => "\{i}"
            Mandatory => "\{i}m"
            Hyphen(l, r) => "\{i}h\{l},\{r}"
          },
        )
      },
    )
    out.write_string("\{label}: \{points.join(" ")}\n")
  }

  // Bidi.
  let lb = @linebreak.default_segmenter().segment_str(text)
  for
    pair in [
      ("ltr", Some(@bidi.Level::ltr())),
      ("rtl", Some(@bidi.Level::rtl())),
      ("auto", None),
    ] {
    let (label, level) = pair
    let bidi = @bidi.BidiInfo::new(text, level)
    out.write_string("bidi-\{label}: \{bidi_summary(bidi)}\n")
    for para in bidi.paragraphs {
      out.write_string("  para \{runs_report(bidi, para, para.range)}\n")
    }
    if bidi.has_rtl() {
      // Lines between consecutive line break opportunities.
      for k in 1..<lb.length() {
        let a = lb[k - 1]
        let b = lb[k]
        guard bidi.paragraphs.search_by(p => p.range.contains(a)) is Some(pi) else {
          continue
        }
        let para = bidi.paragraphs[pi]
        out.write_string(
          "  line \{runs_report(bidi, para, { start: a, end: b })}\n",
        )
      }
    }
  }
  out.to_string()
}

///|
fn bidi_summary(bidi : @bidi.BidiInfo) -> String {
  let paras = bidi.paragraphs
    .map(p => "\{p.range.start}..\{p.range.end}@\{p.level.number()}")
    .join(" ")
  "paras \{paras} levels \{rle(bidi.levels[:])}"
}

///|
fn rle(levels : ArrayView[@bidi.Level]) -> String {
  let out : Array[(Int, Int)] = []
  for l in levels {
    match out.last() {
      Some((v, n)) if v == l.number() => out[out.length() - 1] = (v, n + 1)
      _ => out.push((l.number(), 1))
    }
  }
  out.map(p => "\{p.0}x\{p.1}").join(" ")
}

///|
fn runs_report(
  bidi : @bidi.BidiInfo,
  para : @bidi.ParagraphInfo,
  line : @bidi.Range,
) -> String {
  let (levels, runs) = bidi.visual_runs(para, line)
  let runs = runs
    .map(r => "\{r.start}..\{r.end}@\{levels[r.start].number()}")
    .join(" ")
  "\{line.start}..\{line.end}: \{runs} | \{rle(levels[line.start:line.end])}"
}

///|
fn bidi_record(text : String, dir : String, hex : String) -> String {
  let level = match dir {
    "ltr" => Some(@bidi.Level::ltr())
    "rtl" => Some(@bidi.Level::rtl())
    _ => None
  }
  let bidi = @bidi.BidiInfo::new(text, level)
  let out = StringBuilder()
  out.write_string("bidi: \{dir} \{hex}\n  \{bidi_summary(bidi)}\n")
  for para in bidi.paragraphs {
    out.write_string("  para \{runs_report(bidi, para, para.range)}\n")
  }
  out.to_string()
}
