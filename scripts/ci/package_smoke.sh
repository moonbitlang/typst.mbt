#!/usr/bin/env bash
# CI: the package must work as a dependency (see "Publishing" in AGENTS.md).
#
#   scripts/ci/package_smoke.sh [target ...]      (default: native wasm-gc)
#
# Packages the module like the publish workflow (`moon package`), unpacks
# the zip and builds and runs a tiny consumer of `moonbitlang/typst/doc`
# (and of `doc/kit`, a package of its own on top of it)
# that depends on the unpacked package: only what is in the zip is there,
# and moon does not run the `pre-build` steps of a dependency, so a package
# without the generated font data (of `typst_assets/fonts` and of
# `doc/fonts`, the EDSL's sans-serif family) fails here like 0.1.0-0.1.2
# did for their users.
set -euo pipefail
cd "$(dirname "$0")/../.."
targets=("$@")
[ ${#targets[@]} -eq 0 ] && targets=(native wasm-gc)

work="$PWD/_build/ci/package"
rm -rf "$work" _build/publish
mkdir -p "$work/consumer/cmd"

# The pre-build step generates the font data on the first build or check.
moon check --target native > "$work/check.log" 2>&1 || { tail -60 "$work/check.log"; exit 1; }
moon package
zips=(_build/publish/*.zip)
[ ${#zips[@]} -eq 1 ] || { echo "package_smoke: expected one zip, got: ${zips[*]}" >&2; exit 1; }
zip=${zips[0]}
echo "package: $zip ($(du -h "$zip" | cut -f1))"
# (Listed into a variable: `unzip | grep -q` fails under pipefail when grep
# exits before unzip has written everything.)
listing=$(unzip -l "$zip")
for f in typst_assets/fonts/fonts_gen.c typst_assets/fonts/fonts_wasm_gen.mbt \
  doc/fonts/fonts_gen.c doc/fonts/fonts_wasm_gen.mbt doc/fonts/files/LICENSE.txt; do
  grep -q " $f\$" <<< "$listing" || { echo "package_smoke: missing $f in the package" >&2; exit 1; }
done
unzip -q "$zip" -d "$work/typst"

cat > "$work/consumer/moon.mod.json" <<'EOF'
{
  "name": "ci/consumer",
  "version": "0.1.0",
  "deps": {
    "moonbitlang/typst": { "path": "../typst" }
  }
}
EOF
cat > "$work/consumer/cmd/moon.pkg.json" <<'EOF'
{
  "is-main": true,
  "import": [
    "moonbitlang/typst/doc",
    "moonbitlang/typst/doc/kit",
    "moonbitlang/typst/doc/system",
    "moonbitlang/typst/library"
  ]
}
EOF
cat > "$work/consumer/cmd/main.mbt" <<'EOF'
///|
let sans_text : String = "Sans-serif text"

///|
fn report() -> @doc.Document {
  @doc.Document([
    @doc.SetPage(paper="a5", margin=@doc.Sides(all=@doc.Cm(1.8))),
    @doc.SetHeading(numbering=@doc.Numbering("1.")),
    @doc.Heading("Build times"),
    @doc.Prose("Plain text with \{@doc.Emph("emphasis")} and \{@doc.Raw("code")}."),
    @doc.Par(@doc.Text(sans_text, font=["IBM Plex Sans"])),
    @doc.Equation("sum_(k=1)^n k = (n(n+1))/2", block=true),
    @kit.Cards(["native", "wasm-gc"], gutter=[Pt(6)], fill=Luma(235)),
  ])
}

///|
/// Whether `frame` has `text` set in a font of the family `family`.
fn has_text(frame : @library.Frame, text : String, family : String) -> Bool {
  for entry in frame.items() {
    match entry.1 {
      Group(group) => if has_text(group.frame, text, family) { return true }
      Text(item) =>
        if item.text == text && item.font.font().family() == family {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn build() -> Bytes raise {
  let world = @system.world(root=".", system_fonts=false, today=(2026, 10, 5))
  let compiled = report().compile_paged(world)
  // The family of `doc/fonts` was found (an unknown family is a warning)
  // and draws its text.
  for warning in compiled.warnings {
    println("consumer: warning: \{warning.message}")
  }
  guard compiled.warnings.is_empty() else { fail("warnings") }
  let pages = compiled.unwrap().pages()
  guard has_text(pages[0].frame, sans_text, "IBM Plex Sans") else {
    fail("no text in IBM Plex Sans")
  }
  compiled.pdf().unwrap()
}

///|
fn main {
  let pdf = build() catch {
    e => {
      println("consumer: failed: \{e}")
      panic()
    }
  }
  // "%PDF": the embedded fonts were found (those of both font packages:
  // see `build`) and the exporter ran.
  guard pdf.length() > 1000 &&
    pdf[0] == b'%' &&
    pdf[1] == b'P' &&
    pdf[2] == b'D' &&
    pdf[3] == b'F' else {
    println("consumer: not a PDF (\{pdf.length()} bytes)")
    panic()
  }
  println("consumer: ok, \{pdf.length()} bytes of PDF")
}
EOF

cd "$work/consumer"
for target in "${targets[@]}"; do
  echo "== consumer on $target"
  out=$(moon run --target "$target" cmd)
  echo "$out"
  grep -q '^consumer: ok, ' <<< "$out" || {
    echo "package_smoke: the consumer failed on $target" >&2
    exit 1
  }
done
echo "package_smoke: ok (${targets[*]})"
