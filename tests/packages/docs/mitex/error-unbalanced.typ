// mitex 0.2.7: LaTeX that the converter rejects (an environment that is never closed and a
// stray closing brace): the error is raised by the WebAssembly plugin and reported through
// the package's call chain.
// Engine: plugin error results turned into diagnostics, trace through package functions.
#import "@preview/mitex:0.2.7": mitex

#set page(width: 100mm, height: 50mm, margin: 10mm)

The matrix below was pasted from a draft and lost its last line:

#mitex(`
  M = \begin{pmatrix}
    1 & 0 \\
    0 & 1 }
`)
