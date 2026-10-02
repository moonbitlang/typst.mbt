#!/bin/sh
# Run from the worktree root. Lists embedded fonts of the test PDFs and dumps them.
O=target/scratch/oracle/target/release/skrifa-oracle
mkdir -p target/scratch/fonts
for f in target/hayro/hayro-tests/pdfs/custom/font_*.pdf target/hayro/hayro-tests/pdfs/custom/fonts_type1_latex.pdf target/hayro/hayro-tests/pdfs/custom/pdftc_900k_0319_page_1.pdf target/devassets/images/diagrams.pdf; do
  b=$(basename "$f" .pdf)
  mkdir -p "target/scratch/fonts/$b"
  echo "== $b"
  $O fonts "$f" "target/scratch/fonts/$b"
done
