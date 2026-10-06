// cmarker 0.1.10: the options of `render` side by side on Markdown given inline as raw
// blocks: `smart-punctuation`, `h1-level` (0 with a document title, 3, negative),
// `heading-labels` (github, jupyter, none) with links to the generated labels, `raw-typst`
// on and off, `show-source`, `scope` overriding element functions (heading, link, strong,
// raw, quote, divider), `html` overriding a default element, `frontmatter-raw`.
// Engine: many small plugin calls with different option bytes, eval scopes that shadow
// built-in element functions, `title` and `divider` elements, labels with unusual characters.
#import "@preview/cmarker:0.1.10"

#set page(width: 150mm, height: 185mm, margin: (x: 13mm, y: 14mm), numbering: "1")
#set text(size: 9.5pt)
#set heading(numbering: "1.1")
#show link: set text(fill: rgb("#0b5394"))

#let side-by-side(label, source, ..options) = block(
  breakable: false,
  width: 100%,
  stroke: 0.4pt + luma(140),
  inset: 6pt,
  {
    text(8pt, fill: luma(90), label)
    grid(
      columns: (1fr, 1fr),
      gutter: 8pt,
      text(7.5pt, raw(source.text, lang: "md", block: true)), cmarker.render(source, ..options),
    )
  },
)

// With `h1-level: 0` the first heading becomes the document title.
#cmarker.render(
  ```md
  # Options of the Markdown Renderer

  *One source, many readings* --- the same text under different settings.
  ```,
  h1-level: 0,
)

Outside of the rendered block, `document.title` is #context raw(repr(document.title)).

= Punctuation

#let quotes = ```md
"Quotes" and 'apostrophes' -- dashes --- and dots...
```
#side-by-side([`smart-punctuation: true` (default)], quotes)
#side-by-side([`smart-punctuation: false`], quotes, smart-punctuation: false)

= Heading levels and labels

#let headed = ```md
# Tools & Materials!
Text under the first heading.
## Sub-section: glue
See [the top](#tools--materials).
```
#side-by-side([`h1-level: 3`, labels prefixed `a-`], headed, h1-level: 3, label-prefix: "a-")
#side-by-side(
  [`h1-level: -1`: the top heading is plain text, the second level a title (which needs
    `set-document-title: false` inside a container), the third a level-one heading; no labels],
  ```md
  # Not a heading any more
  ## Promoted to a title
  ### Now on level one
  Body text.
  ```,
  h1-level: -1,
  set-document-title: false,
  heading-labels: none,
)
#side-by-side(
  [`heading-labels: "jupyter"`, labels prefixed `j-`],
  ```md
  ### Tools & Materials!
  A link in the Jupyter style: [up](#Tools-&-Materials!).
  ```,
  heading-labels: "jupyter",
  label-prefix: "j-",
)

From Typst, the generated labels are reachable too: #link(<a-tools--materials>)[github style],
#link(label("j-Tools-&-Materials!"))[jupyter style], #link(<a-sub-section-glue>)[the sub-section].

= Raw Typst and the generated source

#let with-comment = ```md
Before. <!--raw-typst #box(fill: yellow, inset: 2pt)[typst: #(6 * 7)] --> After.

<!-- an ordinary comment -->
```
#side-by-side([`raw-typst: true` (default)], with-comment)
#side-by-side([`raw-typst: false`], with-comment, raw-typst: false)
#side-by-side(
  [`show-source: true`],
  ```md
  ## Glue *types*
  - hide glue
  - [PVA](https://glue.example)

  > Clamp for an hour.
  ```,
  show-source: true,
  heading-labels: none,
)

= Overriding element functions

#side-by-side(
  [`scope:` replaces `heading`, `link`, `strong`, `raw`, `quote` and `divider`],
  ```md
  #### A restyled heading
  Some **strong** text, `code`, and a [link](https://wood.example).

  > A quotation.

  ---
  After the break.
  ```,
  heading-labels: none,
  scope: (
    heading: (level: 1, body) => block(
      fill: rgb("#0b5394"),
      inset: 4pt,
      width: 100%,
      text(fill: white, weight: "bold")[#("›" * level) #body],
    ),
    link: (dest, body) => [#underline(body)#footnote(raw(dest))],
    strong: body => text(fill: rgb("#b45f06"), weight: "bold", body),
    raw: (..args) => box(fill: luma(225), inset: (x: 2pt), outset: (y: 2pt), raw(..args)),
    quote: (block: false, body) => pad(left: 1em, emph(body)),
    divider: () => align(center)[∗ ∗ ∗],
  ),
)

#side-by-side(
  [`html:` overrides `<mark>` and adds `<kbd>` and a void `<stamp>`],
  ```md
  Press <kbd>Ctrl</kbd>+<kbd>S</kbd> to <mark>save</mark>. <stamp kind="draft">
  ```,
  html: (
    mark: (attrs, body) => highlight(fill: rgb("#b6d7a8"), body),
    kbd: (attrs, body) => box(stroke: 0.5pt, radius: 2pt, inset: (x: 2.5pt), outset: (y: 2pt), raw(
      body.text,
    )),
    stamp: ("void", attrs => box(rotate(-8deg, text(fill: red, weight: "bold", upper(attrs.kind))))),
  ),
)

= Front matter as a string

#let (front, body) = cmarker.render-with-metadata(
  ```md
  ---
  author = "J. Carpenter"
  revision = 4
  ---
  The *body* follows the block.
  ```,
  metadata-block: "frontmatter-raw",
)
#let parsed = toml(bytes(front))
The block is returned unparsed (#raw(repr(front))) and read here as TOML:
author #parsed.author, revision #parsed.revision. #body
