name = "moonbitlang/typst"

version = "0.1.1"

readme = "README.md"

repository = "https://github.com/moonbitlang/typst.mbt"

license = "Apache-2.0"

keywords = [ "typst", "typesetting", "markup", "pdf" ]

description = "A port of the Typst typesetting engine to MoonBit."

preferred_target = "native"

warnings = "-implicit_impl_as_method"

import {
  "moonbitlang/x@0.5.5",
  "moonbitlang/pdflite@0.3.6",
  "moonbit-community/flate@0.8.5",
}
