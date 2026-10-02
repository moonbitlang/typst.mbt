///|
fn dev_asset(name : String) -> Bytes? {
  let home = @env.get_env_vars().get("HOME").unwrap_or("")
  let base = home + "/.cargo/git/checkouts"
  let dirs = (@fs.read_dir(base) catch { _ => [][:] }).to_owned()
  for d in dirs {
    if d.has_prefix("typst-dev-assets-") {
      let revs = (@fs.read_dir(base + "/" + d) catch { _ => [][:] }).to_owned()
      for r in revs {
        let path = base + "/" + d + "/" + r + "/files/" + name
        return Some(@fs.read_file_to_bytes(path)) catch { _ => None }
      }
    }
  }
  None
}

///|
fn describe(name : String) -> String {
  guard dev_asset(name) is Some(data) else { return "missing" }
  match @syntax.Pdf::new(data) {
    Err(Invalid) => "error invalid"
    Err(Decryption(_)) => "error decryption"
    Ok(pdf) => {
      let sb = StringBuilder::new()
      sb.write_string(
        "version=\{pdf.version().as_str()} pages=\{pdf.pages().length()}",
      )
      for page in pdf.pages().iter() {
        let (w, h) = page.render_dimensions()
        let stream = page.page_stream()
        let len = match stream {
          Some(s) => s.length()
          None => -1
        }
        sb.write_string("\n  \{w}x\{h} stream=\{len}")
        let mut n = 0
        let iter = page.typed_operations()
        while iter.next() is Some(_) {
          n += 1
        }
        sb.write_string(" ops=\{n}")
      }
      sb.to_string()
    }
  }
}

///|
test "load test pdfs" {
  inspect(
    describe("images/star.pdf"),
    content=(
      #|version=1.7 pages=1
      #|  70x70 stream=137 ops=16
    ),
  )
  inspect(
    describe("images/matplotlib.pdf"),
    content=(
      #|version=1.4 pages=1
      #|  460.79998779296875x345.6000061035156 stream=76070 ops=2029
    ),
  )
  inspect(
    describe("images/diagrams.pdf"),
    content=(
      #|version=1.7 pages=3
      #|  476.8799743652344x318.9599914550781 stream=39080 ops=2910
      #|  282x72.95999908447266 stream=3097 ops=254
      #|  822.9599609375x523.9199829101562 stream=29017 ops=1127
    ),
  )
  inspect(
    describe("images/base14-fonts.pdf"),
    content=(
      #|version=1.5 pages=1
      #|  200x280 stream=1771 ops=98
    ),
  )
}
