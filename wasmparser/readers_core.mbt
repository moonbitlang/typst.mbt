// Port of wasmparser 0.228.0 `src/readers/core.rs` and `src/readers.rs`
// aliases: the section readers (upstream `<Name>SectionReader<'a>`).

///|
/// A reader for the import section of a WebAssembly module.
pub type ImportSectionReader = SectionLimited[Import]

///|
/// A reader for the function section of a WebAssembly module.
pub type FunctionSectionReader = SectionLimited[UInt]

///|
/// A reader for the table section of a WebAssembly module.
pub type TableSectionReader = SectionLimited[Table]

///|
/// A reader for the memory section of a WebAssembly module.
pub type MemorySectionReader = SectionLimited[MemoryType]

///|
/// A reader for the tag section of a WebAssembly module.
pub type TagSectionReader = SectionLimited[TagType]

///|
/// A reader for the global section of a WebAssembly module.
pub type GlobalSectionReader = SectionLimited[Global]

///|
/// A reader for the export section of a WebAssembly module.
pub type ExportSectionReader = SectionLimited[Export]

///|
/// A reader for the element section of a WebAssembly module.
pub type ElementSectionReader = SectionLimited[Element]

///|
/// A reader for the code section of a WebAssembly module.
pub type CodeSectionReader = SectionLimited[FunctionBody]

///|
/// A reader for the data section of a WebAssembly module.
pub type DataSectionReader = SectionLimited[Data]
