# `.mbt.typ`: Typst markup with MoonBit as its scripting language

Status: draft for the owner's review, 2026-10-12. Nothing is built. Every
statement under "Verified" was run on this machine (moon 0.1.20261010,
moonc v0.10.15, aarch64 macOS); everything else is a proposal.

## 0. Summary

A `.mbt.typ` file is a document whose prose is Typst markup and whose
code is MoonBit. Headings, emphasis, lists, references and math are
written as in Typst and parsed by the port's Typst parser. Wherever Typst
would switch to its own scripting language (after `#`), the file switches
to MoonBit instead. The Typst scripting language is not available in such
a file.

A tool cuts the file into MoonBit code and markup text and emits one
MoonBit source file. That file is compiled on its own, without the
engine, and running it produces a tree: markup source with typed holes.
A prebuilt engine reads the tree, fills the holes and lays the document
out.

The point of the split is the edit cycle. A MoonBit document that is
linked with the engine takes 16 s to rebuild after a one-line edit; a
document program without the engine takes 0.07 s (section 8).

## 1. Goals and non-goals

Goals:

- Prose reads as prose. A report or a paper should look like its Typst
  version wherever it does not compute.
- Code is vanilla MoonBit: the MoonBit compiler parses and type-checks it,
  and MoonBit packages are the ecosystem.
- An edit is compiled in a fraction of a second.
- The engine and the existing packages are not changed, with one
  exception that is off by default (section 4.1).

Non-goals of the first version, by the owner's decision:

- Typst packages (touying, cetz, ..). Libraries are MoonBit packages.
- Editor support for the mixed file.
- Mapping compiler errors and engine diagnostics back to lines of the
  `.mbt.typ` file.

## 2. Two layers

What is described here is, at its core, a markup language for MoonBit
and not something specific to Typst. The parts separate cleanly:

**Generic: a template with typed holes.** A file is MoonBit declarations,
a separator, and a body of text with code sites. The body compiles to a
function that writes to a writer: text segments through `write_string`,
values through `write_string_interpolation`, which are the two methods
MoonBit's `w <+ "..\{x}.."` calls. Statements run as statements. Nothing
in this layer knows what the text means or what the writer does with it.

**Dialect: what the text is.** The dialect answers four questions:

1. Where in the text does a code site start? (In Typst: at `#`, but not
   at `\#`, not inside raw text, a comment or a string.)
2. Is there a block form that returns from code to text? (In Typst: `[`
   directly after a call.)
3. What does the receiver do with segments and holes? (Here: join them
   into Typst markup with placeholders and evaluate it.)
4. What library of values can fill a hole? (Here: Typst's elements.)

The same generic layer with an HTML or Markdown dialect would be a
template language for those. The proposal is to keep the seam in the
code (a dialect is a small interface) and to build one dialect, Typst's.
Whether the generic layer becomes a package of its own, or part of the
MoonBit toolchain as `.mbt.md` is, is the owner's to decide later.

## 3. The file

### 3.1 Header and body

```
fn total(xs : Array[Int]) -> Int {
  xs.fold(init=0, (a, b) => a + b)
}

let scores : Array[Int] = [72, 85, 91]
---
#SetText(size=Pt(12))
= Results

We ran #scores.length() trials with a total of *#total(scores)*.

#for s in scores {
  m <+ "- A score of \{s}\n"
}

#slide(title="Chart")[
  #figure(image("plot.png"), caption="Scores by trial")
]

$ x = #total(scores) / 3 $
```

Everything before the first line that consists of `---` alone is the
header: top-level MoonBit (`fn`, `struct`, `enum`, `let`, `impl`),
copied unchanged. Such a line cannot occur in valid top-level MoonBit
(there are no block comments, and every line of a multi-line string
starts with `#|` or `$|`), so the tool finds it without parsing MoonBit.
A file without the line has no header.

Everything after it is the body: Typst markup in which `#` starts
MoonBit.

### 3.2 Code sites

After `#` in markup or math comes one of two things.

**An expression site** is a value that fills a hole at that place:

- a name, `@pkg.name` or a constructor, followed by any number of
  `.name`, `::name` and `( .. )`, each written directly behind the last;
- or a parenthesised expression, `#( .. )`, for anything else.

It ends where none of these follows, or at a `;`, which is consumed
(`#name;.txt`). This is Typst's rule for where an embedded expression
ends.

**A statement site** starts with a keyword and writes nothing by itself:
`let`, `for`, `while`, `if`, `match`, `guard`, `fn`, or a block `#{ .. }`.
A `let` runs to the end of its line, across lines only inside brackets;
the others run through their `{ .. }` blocks, including `else`. An `if`
or a `match` that is meant as a value is written `#(if c { a } else { b })`.

Inside the parentheses and braces of a site the text is vanilla MoonBit.
The scanner that finds the end of a site works on tokens only: strings
with their `\{ .. }` interpolations, characters, `#|` and `$|` lines,
comments and balanced brackets. It never decides what a `[` means,
because inside code a `[` is always MoonBit's.

### 3.3 The writer

The body is a function of one parameter, the writer, named `m`.
Statements that produce markup write to it:

```
#for s in scores {
  m <+ "- A score of \{s}\n"
}
```

The text of a `m <+ ".."` is markup, exactly as if it stood in the body;
its holes are typed (section 5.2). Loops and conditions need no rule for
joining their results: a loop writes several times.

A line of the body that holds nothing but a statement site produces
nothing, not its line break either. Without this rule a `#let` between
two lines of text would turn the line break into a paragraph break, and
with a placeholder in its place the `- ` that a loop writes would not
be at the start of a line.

### 3.4 Trailing blocks

A `[` written directly behind an expression site in markup starts a
markup block, which ends at its matching `]` and is passed to the call
as its last argument:

```
#slide(title="Chart")[
  This is _markup_ again, and #total(scores) is code again.
]
```

This is the only place where the file returns from code to markup by
syntax, and the markup side sees it: the expression has ended, so there
is no clash with MoonBit's arrays. The cost is that `#xs[0]` is a call
with a block; indexing directly after `#` is `#(xs[0])`.

The rule comes from a count of how markup sits inside code in Typst
documents today (section 8.2): blocks inside parentheses are short labels
(median 10 to 41 bytes, 65 to 76 % plain text), while trailing blocks
hold the document (27,860 of the 30,306 bytes of a 14-file slide deck).

### 3.5 Markup as a value inside code

Inside code, markup is a value built by a function that takes a closure:

```
#figure(image("cat.png"), caption=markup() <| m => { m <+ "A _sleepy_ cat, aged \{age}" })
```

`markup` makes a writer, runs the closure on it and returns it. A
trailing block is translated to exactly this form, so there is one
mechanism. A label without formatting is a plain string, which a hole
takes as literal text.

### 3.6 Including a file

`#include "ch1.mbt.typ"` runs the body of that file at this place, with
the current writer. A file's body is therefore an ordinary function, not
`init` and not `main`: `init` runs once at program start and cannot be
placed, and a program has one `main`.

## 4. The tool

### 4.1 Splitting

The tool parses the body with the port's Typst parser in a mode in which
the one function that parses an embedded code expression
(`embedded_code_expr`, `syntax/parser.mbt`; markup and math both call it)
is replaced by the scanner of section 3.2, which yields one opaque node
with the text of the site. The parser keeps deciding where `#` means
code at all, which a separate pre-pass would have to re-implement.

This is the only change to a ported package. The mode is off by default,
so a `.typ` file takes upstream's path and the parser stages are
unaffected. The reparser is not involved: the tool parses whole files.

### 4.2 What it emits

For the file of section 3.1 (compiled as written here, with a stub
library; section 8.4):

```moonbit
// header, unchanged
fn total(xs : Array[Int]) -> Int {
  xs.fold(init=0, (a, b) => a + b)
}

let scores : Array[Int] = [72, 85, 91]

// body
fn body(m : Markup) -> Unit {
  m.write_string_interpolation(SetText(size=Pt(12)))
  m.write_string("\n= Results\n\nWe ran ")
  m.write_string_interpolation(scores.length())
  m.write_string(" trials with a total of *")
  m.write_string_interpolation(total(scores))
  m.write_string("*.\n\n")
  for s in scores {
    m <+ "- A score of \{s}\n"
  }
  m.write_string("\n")
  m.write_string_interpolation(
    slide(
      title="Chart",
      markup() <| m => {
        m.write_string("\n  ")
        m.write_string_interpolation(
          figure(image("plot.png"), caption="Scores by trial"),
        )
        m.write_string("\n")
      },
    ),
  )
  m.write_string("\n\n$ x = ")
  m.write_string_interpolation(total(scores))
  m.write_string(" / 3 $\n")
}
```

The tool emits the two method calls that `<+` stands for, not `<+`
itself: a segment is then an ordinary string literal with ordinary
escapes, and a hole can be any expression (an interpolation cannot hold
every expression, and escapes in `$|` lines are deprecated). For the
root file the tool also emits `main`, which runs the body and hands the
tree over.

## 5. The document-side library

A small package that the document program links, without the engine.

### 5.1 The writer

`Markup` holds a list of pieces: `Source(String)` for a segment, and one
case per kind of hole. `markup(build)` is section 3.5's function.

### 5.2 Holes

`write_string_interpolation` is generic over a trait (`Hole` in the
prototype) that says what piece a value becomes:

| Value | Piece |
| --- | --- |
| `String` | literal text, never markup |
| `Int`, `Double` | a number |
| an element (`figure(..)`) | a node: element name and arguments |
| `Markup` | a nested template |
| a length (`Pt(12)`), a colour, .. | a value |
| a rule (`SetText(..)`) | a rule (section 6.2) |

Because the library sees every hole with its static type, a string that
contains `*` or `#` cannot become markup, and content is passed as a
value. Verified with a user-defined writer (section 8.3).

### 5.3 Elements, values, rules

One constructor per Typst element, generated from the table that
`scripts/docgen.py` already has, building a node and nothing else: no
constructor calls the engine. Lengths are constructors, `Pt(12)`, as the
owner decided. A set rule is a value, `SetText(size=Pt(12))`.

Whether these are new functions or the names and signatures of the
existing `doc` package (`Heading(..)`, `SetText(..)`, `Pt(..)`) is open
(section 10).

## 6. The engine side

### 6.1 Filling a template

The engine joins the pieces of a `Markup` into one string of Typst
markup in which every hole is a placeholder, `#h.at(3);`, and evaluates
it with `h` bound to the array of hole values. The parser sees the whole
text, so emphasis that spans a hole, a list that a loop wrote and math
with a hole are parsed as in a `.typ` file. A nested `Markup` is filled
first and is a content value in the array.

Engine code for this exists: `eval_string` in markup mode with a scope
(`@doc.Markup(source, scope=..)` wraps it).

### 6.2 Rules

Typst applies a `set` or `show` rule to the rest of its block, and does
so by syntax: a value that happens to be a rule is not treated that way.
A rule hole is therefore the placeholder `#show: h.at(0);`, where the
value is a function from the rest of the block to that rest with the
rule applied. This is Typst's own idiom for templates and needs no
engine change.

### 6.3 Verified

A document with a set rule, a heading, holes in text, a list written
item by item, a block that contains a figure whose caption is a template
with a hole, and a hole in math was written twice: as plain Typst, and
as a filled template in the form above. The port compiles both to
byte-identical SVG (section 8.5).

### 6.4 Elements

A node is an element name with arguments. The engine looks the function
up in the standard library and calls it, as the evaluator does for
`#figure(..)`, so argument checking, conversion and error messages are
the engine's own. The `doc` package lowers its description tree the same
way; how much of that lowering the engine side can reuse through `doc`'s
public API is to be found out in the first slice.

## 7. Execution

### 7.1 First version: one-shot

Two programs and no callbacks:

1. The tool emits MoonBit; `moon build --target wasm-gc` compiles it
   with the document-side library.
2. The document program runs under `moonrun` and prints its tree.
3. An engine executable reads the tree, fills it and writes the PDF.

This covers prose, headings, lists, math, figures, tables, grids, `let`,
loops, conditions, includes and set rules. It does not cover show rules
with a function, `context`, or anything that measures.

### 7.2 Callbacks

Those three need an answer during layout. The tree then carries a
closure number; the document program keeps the closures and stays alive;
the engine sends "call closure 12 with these arguments" and reads the
result. While it computes, the closure may ask the engine (a field of an
element it was given, a query, a measurement), so the exchange is a stack
of requests and replies between two single-threaded programs. Content
that is passed to a closure is a handle, an integer that names an object
the engine keeps.

A wasm-gc program under `moonrun` can block on a line from its parent
and reply (section 8.6): about 20 to 40 µs per round trip before any
work. A show rule on a thousand headings is then about 40 ms per layout
pass; a show rule on every paragraph of a long document is seconds. Work
that a Typst package does in Typst code runs inside the document program
here and does not cross.

Not designed yet: the message format, the cost of serialising real
arguments, what the engine reports when the document program fails in a
callback, and how a closure of a rebuilt program is told from the closure
with the same number before the rebuild (the engine keeps results of
callbacks only for a pure function of its arguments, and across rebuilds
only under a key that survives them).

### 7.3 A long-lived engine

With the engine as a process that outlives the document program, fonts
are loaded once and what the last compilation computed is found again,
as in `typst watch`. Later: segments shipped as data, so that an edit of
prose alone compiles no MoonBit.

## 8. Verified

### 8.1 Rebuild times

After a one-line edit, debug builds:

| What is rebuilt | Time |
| --- | --- |
| `doc/examples/showcase` linked with the engine, native | 16.3 s (`moonc link-core` 15 to 21 s of it; the package itself 0.07 s) |
| the same, wasm-gc | 7.5 s |
| a document program without the engine (4,000 nodes), wasm-gc or wasm | 0.07 s |
| the same, native debug | 0.18 s |
| the same, native release | 0.43 s |

The document program runs in about 10 ms under `moonrun`.

### 8.2 How markup and code nest in Typst documents

Counted with the port's parser. A site is one `#..` in markup.

| Set | Bytes that are code | Sites | with markup inside | whose markup holds code again | Deepest nesting |
| --- | --- | --- | --- | --- | --- |
| `bench/` (3 files) | 47 % | 74 | 35 % | 15 % | 7 |
| `tests/packages/docs` (99 files) | 53 % | 2,594 | 34 % | 8 % | 7 |
| a slide deck (14 files) | 48 % | 267 | 69 % | 21 % | 10 |

Markup blocks inside code:

| Where | Set | Blocks | Plain text | Median | 90th percentile |
| --- | --- | --- | --- | --- | --- |
| in parentheses, named, in arrays | package documents | 1,652 | 76 % | 10 bytes | 45 bytes |
| | slide deck | 244 | 65 % | 41 bytes | 153 bytes |
| trailing | package documents | 1,033 | 62 % | 17 bytes | 134 bytes |
| | slide deck | 88 | 71 % | 26 bytes | 1,897 bytes |

Loops, conditions and closures around markup are 1 to 3 % of the blocks.

### 8.3 `<+` with a user-defined writer

A struct with `write_string(String)` and a generic
`write_string_interpolation[T : Hole]` receives, for
`m <+ "A _sleepy_ \{cat} called \{name}, aged \{age}"`, a segment, a
node, a segment, the string as literal text, a segment and a number, in
that order. `$|` lines work. `<+` has type `Unit`, and
`markup() <| m => { m <+ ".." }` is an expression; the braces are
required.

### 8.4 The generated file

The file of section 4.2, with a stub of the library, compiles for
wasm-gc and prints the expected tree.

### 8.5 Filling

Section 6.3: byte-identical SVG from the port's CLI for the plain and
the filled document.

### 8.6 Blocking exchange under `moonrun`

A wasm-gc program reads lines from its parent through `moonrun`'s
`read_char` and answers with `println`: 5,000 round trips at 40.5 µs
each, of which 22.2 µs is the test's Python parent (measured with `cat`
as the child).

### Not checked

- Whether the stable toolchain that CI installs (moonc v0.10.14) has
  `<+` with a user-defined writer.
- Linking the real document-side library (generated constructors for
  every element) instead of a stub: its build time and size.
- Anything about callbacks beyond 8.6.

## 9. Decided by the owner

- The format: Typst markup for prose, MoonBit instead of Typst's
  scripting; the name `.mbt.typ`; kept apart from the existing work.
- Code is vanilla MoonBit; a trailing `[ .. ]` after a call is the one
  markup block ("mostly").
- Markup as a value: `markup() <| m => { m <+ .. }`.
- Header, then a line `---`, then the body.
- Lengths are `Pt(12)`.
- The engine is native and long-lived; the document code is compiled to
  wasm; two processes.
- Libraries come from MoonBit's ecosystem, not from Typst packages.
- Editor support and error locations are delayed.

## 10. Open

1. **The parser mode** (section 4.1): a switch in `syntax/`, off by
   default. It is a change to a ported package.
2. **The writer's name** in the body, `m` here. It is part of the
   language, since statements write to it.
3. **Several trailing blocks**, `#grid(columns=2)[a][b]`: one array
   argument, or not supported in the first version (write
   `#grid(columns=2, [x, y])` with values).
4. **The library's surface**: the names and signatures of `doc`
   (`Heading`, `SetText`, uppercase constructors), or lowercase functions
   as in Typst (`figure`, `grid`). The samples above mix both and should
   not.
5. **Where it lives**: packages of this repository (a tool that links
   `syntax/` only, the document-side library, an engine executable), and
   how a `.mbt.typ` file is found and built (a command of its own, or a
   step of `moon`).
6. **`#include`**: how a path becomes the function of another file, and
   whether an included file's header is visible to the includer.
7. **The line rule** of section 3.3 for statement-only lines.
8. **Show rules** in the one-shot version: a show rule whose
   transformation is a value (show-set, show with content) could be
   allowed before callbacks exist.

## 11. Slices

1. **One-shot** (section 7.1), with twins: each example is written as
   `.mbt.typ` and as `.typ`, and their frames, SVG and PDF are compared
   as the `edsl` stage compares its pairs. Examples: a report, a paper
   with math, a short deck. This is where it shows whether documents
   written this way read well.
2. **Callbacks** (section 7.2).
3. **The long-lived engine** and prose edits without a compile
   (section 7.3).
4. What section 1 delays: error locations, editor support.
