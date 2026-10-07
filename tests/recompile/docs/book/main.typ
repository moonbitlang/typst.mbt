// A book: the main file includes chapters, the chapters import a shared
// module, and the module reads data. Nothing here knows what the chapters
// read: a change of a data file must reach the pages through two files that
// did not change.
#import "lib/shared.typ": config, project

#show: project.with(title: config.title)

#outline()

#include "chapters/intro.typ"
#include "chapters/data.typ"
#include "chapters/figures.typ"

// An author-date style: what a citation says is in the file.
#bibliography("refs.bib", style: "apa")
