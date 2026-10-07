# Three papers

Three classic papers set as PDF with the document EDSL (`doc/`), each an
executable package. They were written to find out what a paper with dense
mathematics costs an author (`docs/edsl-ports.md`, section 14), against the
EDSL as it was then: paragraphs are `Par(Prose(..))`, the helpers for
formulas, references and running headers are each paper's own. They are
kept that way on purpose, as the before-state of the work that section 14
proposes; do not rewrite them to newer idioms (`Para`, the kit).

| Package | Paper | Pages | Formulas |
| --- | --- | --- | --- |
| `lovelace-1843` | Ada Lovelace, Notes A, F and G to Menabrea's memoir on the Analytical Engine (1843) | 22 | about 290, and about 400 more in the cells of the diagram of Note G |
| `einstein-1916` | A. Einstein, "The Foundation of the Generalised Theory of Relativity" (1916), in S. N. Bose's translation (1920), without footnotes | 38 | 669, 101 of them numbered |
| `ramanujan-1914` | S. Ramanujan, "Modular equations and approximations to π" (1914) | 14, two columns | 355, 50 of them numbered |

## Running

From the repository root (the programs do not create the directory):

```sh
mkdir -p _build/papers
moon run doc/examples/papers/lovelace-1843 --target native --release
moon run doc/examples/papers/einstein-1916 --target native --release
moon run doc/examples/papers/ramanujan-1914 --target native --release
```

Each writes `_build/papers/<package>.pdf` and one PNG per page
(`<package>-<n>.png`, 110 ppi), and prints the engine's warnings and the
EDSL's lints (there are none). Only the embedded fonts are used, so the
output is the same on every machine.

`paper_wbtest.mbt` in each package compiles the paper and checks that there
is no error, warning or lint and that the page count is the one above
(`moon test --target native -p moonbitlang/typst/doc/examples/papers/<package>`;
two to four seconds each in a debug build).

## The texts

All three texts were transcribed from web pages by the agents that wrote the
ports. They were **not checked against scans** of the printed papers, and
the errors of the transcriptions (and the misprints of the originals that
the transcriptions keep) are kept verbatim; what is known of them is listed
below. Each PDF states its source on its last page.

The text of the papers is not under this repository's licence: it is in the
public domain as stated for each paper below. The MoonBit code around it is
under the repository's licence. `doc/examples` is not part of the published
package (`.moonignore`).

### Lovelace 1843

- Work: L. F. Menabrea, "Sketch of the Analytical Engine invented by
  Charles Babbage, Esq." (*Bibliothèque Universelle de Genève*, No. 82,
  October 1842), translated, with Notes A to G, by Ada Augusta, Countess of
  Lovelace (signed A. A. L.), in *Scientific Memoirs*, vol. 3, pages 666 to
  731, London, 1843. Author of the Notes and translator: Lovelace.
- Source of the text: the transcription at English Wikisource,
  <https://en.wikisource.org/wiki/Scientific_Memoirs/3/Sketch_of_the_Analytical_Engine_invented_by_Charles_Babbage,_Esq./Notes_by_the_Translator>.
- Included: Note A (pages 691 to 701), Note F (720 to 722) and Note G (722
  to 731) complete, with Lovelace's own footnotes and the folding diagram
  of Note G ("Diagram for the computation by the Engine of the Numbers of
  Bernoulli") as a table on an A3 landscape page; the head of the memoir
  from page 666. Omitted: the memoir itself and Notes B, C, D and E. The
  works the Notes name are listed from what the Notes say of them
  (`refs.yml`).
- Rights: public domain worldwide. Lovelace died in 1852 and Menabrea in
  1896; Wikisource marks the text "This work was published before January
  1, 1931, and is in the public domain worldwide because the author died at
  least 100 years ago."
- Known errors, kept (the lists are in the comments at the head of
  `note_a.mbt`, `note_g.mbt` and `diagram.mbt`): the misprints of 1843 that
  the transcription marks ("tho" on page 696, "hovever", "sucessively",
  "a x_n" for "a x^n"), the unbalanced parenthesis in the third line of
  formula (3.) of Note G, "to make number", the signature "A. L. L.", the
  last column of the table of cycles, whose cells end with "="; and in the
  diagram the cells where the transcription (proofread once, from page 734
  of the scan) differs from what the computation asks for: Operation 4, the
  indices of Operations 7, 10, 11, 21 and 23, a cell of Operation 8, "n" on
  V10 in Operation 7, the shifted cells of Operation 16, "(2n-2)/3" and
  "A_2" in Operations 19, 21 and 22.

### Einstein 1916, in Bose's translation of 1920

- Work: Albert Einstein, "Die Grundlage der allgemeinen
  Relativitätstheorie", *Annalen der Physik* 354 (7), 1916, pages 769 to
  822. Translation: Satyendra Nath Bose, "The Foundation of the Generalised
  Theory of Relativity", in *The Principle of Relativity: Original Papers
  by A. Einstein and H. Minkowski*, University of Calcutta, 1920, pages 89
  to 163.
- Source of the text: the transcription at English Wikisource,
  <https://en.wikisource.org/wiki/The_Foundation_of_the_Generalised_Theory_of_Relativity>.
  That page says that its notation was replaced by Einstein's original and
  that "the omitted references were included and translated from the German
  original".
- Included: the whole body of the paper, parts A to E, § 1 to § 22, with the
  101 numbered formulas under the paper's own numbers. The numbers (29),
  (41a), (54) and (70), which the transcription lacks and the text refers
  to, are those of the original; the diagram of § 22 is drawn again from the
  text (the source shows an image).
- Omitted: **all sixteen footnotes** of the transcription (at § 2, 3, 4,
  10, 12, 13, 14, 15, 16, 18, 19 and 22; 15 formulas with them). By the
  page's own statement some of its notes are translations made by Wikisource
  contributors, which are licensed CC BY-SA and are not Bose's text of 1920.
  Neither the port nor its comments tell which notes are which, so none is
  reproduced: no footnote of the transcription is in this directory or in
  the history of its commits. The three works that the footnotes cite (Hilbert 1915, Einstein 1915,
  Schwarzschild 1916) are kept as a list of references: authors, journals
  in the paper's abbreviations, years and pages (`refs.yml`), which is
  bibliographic data, not text of the notes. The first build of this port
  had the footnotes and 39 pages.
- Rights: Einstein's original (1916; he died in 1955) and Bose's translation
  (1920; he died in 1974) are in the public domain in the United States,
  because they were published before January 1, 1931. The translation is
  also in the public domain in countries where copyright ends 50 years
  after the author's death. It is **not** in the public domain in India,
  where it was published (60 years after the author's death: until the end
  of 2034), nor in the countries with a term of 70 years, among them the
  member states of the European Union and the United Kingdom. How long it
  lasts in those depends on the country: until the end of 2044 at the
  latest, and until the end of 2034 where the term of a foreign work is
  limited to that of its country of origin (the rule of the shorter term:
  article 7 of the European Union's term directive, section 12(6) of the
  United Kingdom's act). Whoever distributes the PDF or this text there
  needs to take that into account.
- Not established: that every word of the body is Bose's. The transcription
  is an edited text. By its own account its notation was replaced by
  Einstein's, and the review of this commit reports that the page also says
  "some slight inaccuracies were corrected" (the page was not read again
  for this commit). The body was not compared with the edition of 1920, so
  a correction of wording by a Wikisource contributor, if there is one, is
  still in it. Removing the footnotes removes what the page itself
  identifies as translated by its contributors, and no more than that.
- Known errors: none were recorded by the port; the text is as found in the
  transcription.

### Ramanujan 1914

- Work: Srinivasa Ramanujan, "Modular equations and approximations to π",
  *Quarterly Journal of Mathematics*, XLV, 1914, pages 350 to 372. Written
  in English: no translator.
- Source of the text: the transcription at
  <https://ramanujan.sirinudi.org/Volumes/published/ram06.html>, named in
  the PDF's colophon.
- Included: the whole paper, sections 1 to 15, the 50 numbered displays,
  Tables I to III across both columns, and the one footnote of the title
  (the journal reference). The two figures of section 12 are drawn again
  from the constructions in the text. Omitted: nothing of the paper.
- Rights: public domain. The paper was published in 1914 and its author
  died in 1920: it is in the public domain in the United States (published
  before January 1, 1931) and in every country whose term is the author's
  life plus 100 years or less.
- Known errors: none were recorded by the port; the text and the formulas
  are as found. The numeric checker below reports the statements that do
  not hold as they stand in the port; it was not established for each
  whether that is the paper of 1914, the transcription or the port.

## Checking Ramanujan's formulas

`ramanujan-1914/check_formulas.py` evaluates the formula strings of the port
numerically. It needs Python 3 and nothing but its standard library.

```sh
mkdir -p _build/papers
moon run doc/examples/papers/ramanujan-1914 --target native --release -- --check
python3 doc/examples/papers/ramanujan-1914/check_formulas.py \
    _build/papers/ramanujan-1914-math.txt        # -v also lists what holds and what is skipped
```

`--check` writes no pages. It lists the displays that are wider than the
place they are set in (three, by up to 4pt: the engine sets an overfull
display over the neighbouring column without a warning, finding M2 of
section 14, and no lint reports it yet) and writes every formula in the
paper's order to `_build/papers/ramanujan-1914-math.txt` (kind, a tab, the
source). The script parses the subset of Typst math that the port uses and
evaluates both sides of every statement without a free variable but `n`
(the class invariants `G_n` and `g_n` come from their product definitions).
A statement with `n` is evaluated at `n = 22` only. The arithmetic is
decimal with 60 digits, except sines, tangents and the gamma function,
which go through binary floats (about 16 digits).

Its output is to be read, not a verdict (it always exits with 0): a `diff`
is expected where the paper says "approximately" or ends a series with
dots, and is a wrong formula otherwise; `BAD` is a decimal expansion whose
printed digits are not the first digits of the value. Today it reports 83
statements that hold, 59 with a difference, 79 that it cannot evaluate, and
2 `BAD`. The differences that are not approximations or truncated series:

- Table I: the right-hand sides of `1/G_147`, `G_445` and `G_505^2` differ
  from the invariants (relative differences 1.1, 0.33 and 0.12).
- Table II: `e^(pi sqrt(22 slash 12)) = 2 + sqrt(2)` and the entries with
  `sqrt(58 slash 12)`, `sqrt(55 slash 24)` and `sqrt(190 slash 12)`: the
  port's strings have the divisor under the root, where the approximations
  that follow in the table (`pi = 12/sqrt(190) log(..)`) ask for
  `pi sqrt(190) slash 12`.
- Sections 11 and 12: `19/16 sqrt(7) = 3.14180…` (the value is 3.14182…)
  and `(9^2 + 19^2/22)^(1/4) = 3.14159265262…` (the value is
  3.14159265258…).
