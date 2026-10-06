#!/usr/bin/env bash
# Regenerate reference outputs from upstream Typst (needs Rust).
# Usage: scripts/goldens.sh [syntax|ast|reparse|eval|html|bundle|realize|fonts|font|paged|svg|pdf-semantic|pdftags|shape|shape-hb|break|usvg|usvg-images|resvg|packages|raster|wasm-validate|wasm-spec ...]
#
# `packages` compiles the documents of tests/packages/docs, which use real
# packages of the Typst package registry (pinned by
# tests/packages/manifest.tsv; fetch them with scripts/packages.sh first),
# and dumps their frames like `paged` and their SVG like `svg`
# (oracle/src/packages.rs).
# `reparse` applies seeded pseudo-random edits to every test body through
# `Source::edit`/`Source::replace` and dumps the reparsed ranges and trees
# (oracle/src/reparse.rs).
# `fonts` writes the font manifest of the test world (tests/golden/fonts.json);
# `font` dumps what ttf-parser reports for every face (oracle/src/font.rs);
# `paged` dumps every paged test in the `typst-frame-v1` format (see
# oracle/src/paged.rs); `svg` dumps the raw upstream SVG of every paged test
# (pretty, merged pages, 1pt gap; see oracle/src/svg.rs). `pdf-semantic`
# exports every paged test to PDF like the upstream harness and dumps a
# canonical description of the file (oracle/src/pdf_semantic.rs; set
# ORACLE_SAVE_PDF=<dir> to also keep the PDFs for the runner's
# `pdf-extract-check` stage); `pdftags` dumps upstream's `pdftags` YAML of
# the tests with a `pdftags` attribute.
# `usvg-images` dumps
# the usvg trees of the SVG images placed by paged tests
# (oracle/src/usvg_images.rs). `render` dumps the size and SHA-256 of the
# raster image the upstream harness renders for every paged test
# (oracle/src/render.rs).
# `shape` dumps every text run Typst shapes while
# compiling the paged tests, with rustybuzz's output (oracle/src/shape.rs);
# `shape-hb` extracts rustybuzz's own shaping test suite.
# The `break` stage additionally dumps the Unicode bidi conformance files
# (BidiTest.txt, BidiCharacterTest.txt, Unicode 16.0) if BIDI_TEST_DATA
# names a directory containing them.
# `resvg` renders resvg's own regression suite (.repos/resvg, see upstream.sh)
# with the real crate and dumps the size and SHA-256 of every pixmap
# (oracle/src/bin/gen_resvg_golden.rs); it also regenerates resvg/oracle_test.mbt
# from oracle/src/bin/resvg_corpus.txt.
# `raster` regenerates codecs/{webp,gif}_oracle_test.mbt: the WebP and GIF
# corpora (oracle/src/bin/{webp,gif}_corpus.txt, made by
# scripts/gen_{webp,gif}_corpus.py) decoded with image-webp and gif
# (oracle/src/bin/gen_raster_golden.rs), and codecs/image_oracle_test.mbt:
# those corpora and oracle/src/bin/image_corpus.txt (made by
# scripts/gen_image_corpus.py) decoded with the `image` crate like upstream
# `RasterImage::new` (oracle/src/bin/gen_image_golden.rs).
# `bundle` compiles every `bundle` test to a bundle and dumps the exported
# files (paths, kinds, sizes, sha256, and the text of HTML/SVG/UTF-8 files;
# see oracle/src/bundle.rs).
set -euo pipefail
cd "$(dirname "$0")/.."
# Build from inside oracle/ so that its rust-toolchain.toml applies.
(cd oracle && cargo build --release -q)
ORACLE=oracle/target/release/typst-oracle
SUITE=.repos/typst/tests/suite
stages=("$@")
[ ${#stages[@]} -eq 0 ] && stages=(syntax ast reparse eval html bundle realize fonts font paged svg render pdf-semantic pdftags shape shape-hb break usvg usvg-images resvg packages)
for stage in "${stages[@]}"; do
  if [ "$stage" = packages ]; then
    # Exactly the pinned packages (no network access here).
    scripts/packages.sh --check || {
      echo "goldens.sh: fetch the packages with scripts/packages.sh" >&2
      exit 1
    }
    rm -rf tests/golden/packages
    "$ORACLE" packages tests/packages/docs .repos/typst-packages tests/golden/packages
    continue
  fi
  if [ "$stage" = shape-hb ]; then
    # rustybuzz's own shaping tests (needs .repos/rustybuzz, see upstream.sh).
    rm -rf tests/golden/shape-hb
    python3 scripts/shape_hb_tests.py .repos/rustybuzz tests/golden/shape-hb
    continue
  fi
  if [ "$stage" = usvg ]; then
    # The SVG simplifier (oracle/src/bin/gen_usvg_golden.rs): dev-assets SVGs,
    # the usvg corpora and the SVG glyphs of the test fonts. Also regenerates
    # usvg/oracle_test.mbt.
    assets=$(ls -d ~/.cargo/git/checkouts/typst-dev-assets-*/*/files | head -1)
    (cd oracle && cargo run --release -q --bin gen_usvg_golden -- "$assets" ../tests/golden/usvg)
    mv tests/golden/usvg/oracle_test.mbt usvg/oracle_test.mbt
    moon fmt
    continue
  fi
  if [ "$stage" = raster ]; then
    (cd oracle && cargo run --release -q --bin gen_raster_golden -- ../codecs)
    (cd oracle && cargo run --release -q --bin gen_image_golden -- ../codecs)
    moon fmt
    continue
  fi
  if [ "$stage" = resvg ]; then
    rm -rf tests/golden/resvg
    (cd oracle && cargo run --release -q --bin gen_resvg_golden -- ../.repos/resvg/crates/resvg/tests ../tests/golden/resvg)
    mv tests/golden/resvg/oracle_test.mbt resvg/oracle_test.mbt
    moon fmt
    continue
  fi
  if [ "$stage" = wasm-validate ]; then
    # wasmparser validation like wasmi's module parser
    # (oracle/src/bin/gen_wasmparser_tests.rs) of the WebAssembly spec corpus
    # (scripts/wasm_spec_extract.sh) and the Typst test plugins.
    assets=$(ls -d ~/.cargo/git/checkouts/typst-dev-assets-*/*/files | head -1)
    (cd oracle && cargo run --release -q --bin gen_wasmparser_tests -- \
      ../tests/golden/wasm-spec/corpus "$assets/plugins") \
      > tests/golden/wasm-spec/validate.tsv
    continue
  fi
  if [ "$stage" = wasm-spec ]; then
    # The WebAssembly spec test suite (WASM_TESTSUITE, default
    # .repos/wasm-testsuite) run with the real wasmi 1.0.9
    # (oracle/src/bin/gen_wasmi_spec.rs).
    scripts/wasm_spec_extract.sh
    rm -rf tests/golden/wasm-spec/expected
    (cd oracle && cargo run --release -q --bin gen_wasmi_spec -- \
      ../tests/golden/wasm-spec/corpus ../tests/golden/wasm-spec/expected)
    continue
  fi
  if [ "$stage" = fonts ]; then
    "$ORACLE" fonts tests/golden/fonts.json
    continue
  fi
  rm -rf "tests/golden/$stage"
  "$ORACLE" "$stage" "$SUITE" "tests/golden/$stage"
done
