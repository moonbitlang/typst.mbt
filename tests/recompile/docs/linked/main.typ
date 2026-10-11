// Linked images: an SVG shows a PNG that no element of the document names.
// What the pages show is in a file whose bytes are in no element, and a
// value that holds the decoded SVG (a tiling keeps the frame of its body)
// is handed to functions that read no file. A change of `art/photo.png`
// must reach every page but the last, through an SVG file and a main file
// that did not change.
#set page(width: 7cm, height: 4cm, margin: 5mm)

= The image
#image("art/frame.svg", width: 2cm)

#pagebreak()
= A tiling of it, handed to functions
#let tile = tiling(size: (1cm, 1cm), image("art/frame.svg", width: 1cm))
#let id(x) = x
#let filled(t) = rect(width: 4cm, height: 1.5cm, fill: t)
#filled(id(tile))

#pagebreak()
= And captured by one
#let captured() = rect(width: 2cm, height: 1.5cm, fill: tile)
#captured() #captured()

#pagebreak()
= The other image
// As it is, and of the same kind as the linked one: an edit can give one
// the content of the other.
#image("art/other.png", width: 1cm)
