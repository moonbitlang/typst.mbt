// Port of wasmparser 0.228.0 `src/validator.rs` (core modules only; the
// `component-model` cargo feature is off).

///|
/// Test whether the given buffer contains a valid WebAssembly module or
/// component, analogous to [`WebAssembly.validate`][js] in the JS API.
///
/// This functions requires the bytes to validate are entirely resident in
/// memory. Additionally this validates the given bytes with the default set
/// of WebAssembly features implemented by `wasmparser`.
///
/// For more fine-tuned control over validation it's recommended to review the
/// documentation of [`Validator`].
///
/// Upon success, the type information for the top-level module or component
/// will be returned.
///
/// [js]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/WebAssembly/validate
pub fn validate(bytes : BytesView) -> Types raise BinaryReaderError {
  Validator::new().validate_all(bytes)
}

///|
fn check_max(
  cur_len : Int,
  amt_added : UInt,
  max : Int,
  desc : String,
  offset : Int,
) -> Unit raise BinaryReaderError {
  if cur_len > max || amt_added.to_uint64() > (max - cur_len).to_uint64() {
    if max == 1 {
      bail(offset, "multiple \{desc}")
    }
    bail(offset, "\{desc} count exceeds limit of \{max}")
  }
}

///|
fn combine_type_sizes(
  a : UInt,
  b : UInt,
  offset : Int,
) -> UInt raise BinaryReaderError {
  let sum = a.to_uint64() + b.to_uint64()
  if sum < MAX_WASM_TYPE_SIZE.to_uint64() {
    sum.to_uint()
  } else {
    bail(
      offset,
      "effective type size exceeds the limit of \{MAX_WASM_TYPE_SIZE}",
    )
  }
}

///|
/// A unique identifier for a particular `Validator`.
///
/// Allows you to save the `ValidatorId` of the [`Validator`][crate::Validator]
/// you get identifiers out of (e.g. [`CoreTypeId`][crate::types::CoreTypeId])
/// and then later assert that you are pairing those identifiers with the same
/// `Validator` instance when accessing the identifier's associated data.
pub(all) struct ValidatorId(Int) derive(Eq, Hash, Show)

///|
let validator_id_counter : Ref[Int] = Ref::new(0)

///|
fn ValidatorId::default() -> ValidatorId {
  let id = validator_id_counter.val
  validator_id_counter.val = id + 1
  ValidatorId(id)
}

///|
/// Validator for a WebAssembly binary module or component.
///
/// This structure encapsulates state necessary to validate a WebAssembly
/// binary. This implements validation as defined by the [core
/// specification][core]. A `Validator` is designed, like
/// [`Parser`], to accept incremental input over time.
/// Additionally a `Validator` is also designed for parallel validation of
/// functions as they are received.
///
/// It's expected that you'll be using a [`Parser`] in tandem with a
/// `Validator`. As each [`Payload`](crate::Payload) is received from a
/// [`Parser`] you'll pass it into a `Validator` to test the validity of the
/// payload. Note that all payloads received from a [`Parser`] are expected to
/// be passed to a [`Validator`]. For example if you receive
/// [`Payload::TypeSection`](crate::Payload) you'll call
/// [`Validator::type_section`] to validate this.
///
/// The design of [`Validator`] is intended that you'd interleave, in your own
/// application's processing, calls to validation. Each variant, after it's
/// received, will be validated and then your application would proceed as
/// usual. At all times, however, you'll have access to the [`Validator`] and
/// the validation context up to that point. This enables applications to check
/// the types of functions and learn how many globals there are, for example.
///
/// [core]: https://webassembly.github.io/spec/core/valid/index.html
pub struct Validator {
  priv id : ValidatorId
  /// The current state of the validator.
  priv mut state : ValidatorState
  /// The global type space used by the validator and any sub-validators.
  priv types : TypeList
  /// The module state when parsing a WebAssembly module.
  priv mut module_ : ModuleState?
  /// Enabled WebAssembly feature flags, dictating what's valid and what
  /// isn't.
  priv features : WasmFeatures
}

///|
priv enum ValidatorState {
  /// A header has not yet been parsed.
  ///
  /// The value is the expected encoding for the header.
  Unparsed(Encoding?)
  /// A module header has been parsed.
  ///
  /// The associated module state is available via [`Validator::module`].
  Module
  /// The parse has completed and no more data is expected.
  End
}

///|
fn ValidatorState::ensure_parsable(
  self : ValidatorState,
  offset : Int,
) -> Unit raise BinaryReaderError {
  match self {
    Module => ()
    Unparsed(_) =>
      raise BinaryReaderError::new(
        "unexpected section before header was parsed", offset,
      )
    End =>
      raise BinaryReaderError::new(
        "unexpected section after parsing has completed", offset,
      )
  }
}

///|
fn ValidatorState::ensure_module(
  self : ValidatorState,
  _section : String,
  offset : Int,
) -> Unit raise BinaryReaderError {
  self.ensure_parsable(offset)
}

///|
/// `Result<(), &'static str>`: `None` if `ty` is supported, otherwise the
/// error message.
pub fn WasmFeatures::check_value_type(
  self : WasmFeatures,
  ty : ValType,
) -> String? {
  match ty {
    I32 | I64 => None
    F32 | F64 =>
      if self.floats() {
        None
      } else {
        Some("floating-point support is disabled")
      }
    Ref(r) => self.check_ref_type(r)
    V128 => if self.simd() { None } else { Some("SIMD support is not enabled") }
  }
}

///|
/// `Result<(), &'static str>`: `None` if `r` is supported, otherwise the
/// error message.
pub fn WasmFeatures::check_ref_type(
  self : WasmFeatures,
  r : RefType,
) -> String? {
  if !self.reference_types() {
    return Some("reference types support is not enabled")
  }
  match r.heap_type() {
    Concrete(_) =>
      // Note that `self.gc_types()` is not checked here because
      // concrete pointers to function types are allowed. GC types
      // are disallowed by instead rejecting the definition of
      // array/struct types and only allowing the definition of
      // function types.

      // Indexed types require either the function-references or gc
      // proposal as gc implies function references here.
      if self.function_references() || self.gc() {
        None
      } else {
        Some("function references required for index reference types")
      }
    Abstract(shared~, ty~) => {
      if shared && !self.shared_everything_threads() {
        return Some(
          "shared reference types require the shared-everything-threads proposal",
        )
      }

      // Apply the "gc-types" feature which disallows all heap types
      // except exnref/funcref.
      if !self.gc_types() && ty != Func && ty != Exn {
        return Some("gc types are disallowed but found type which requires gc")
      }
      match (ty, r.is_nullable()) {
        // funcref/externref only require `reference-types`.
        (Func, true) | (Extern, true) => None

        // Non-nullable func/extern references requires the
        // `function-references` proposal.
        (Func | Extern, false) =>
          if self.function_references() {
            None
          } else {
            Some("function references required for non-nullable types")
          }

        // These types were added in the gc proposal.
        (Any | None_ | Eq | Struct | Array | I31 | NoExtern | NoFunc, _) =>
          if self.gc() {
            None
          } else {
            Some("heap types not supported without the gc feature")
          }

        // These types were added in the exception-handling proposal.
        (Exn | NoExn, _) =>
          if self.exceptions() {
            None
          } else {
            Some(
              "exception refs not supported without the exception handling feature",
            )
          }

        // These types were added in the stack switching proposal.
        (Cont | NoCont, _) =>
          if self.stack_switching() {
            None
          } else {
            Some(
              "continuation refs not supported without the stack switching feature",
            )
          }
      }
    }
  }
}

///|
/// Possible return values from [`Validator::payload`].
pub(all) enum ValidPayload {
  /// The payload validated, no further action need be taken.
  Ok
  /// A function was found to be validated.
  Func(FuncToValidate, FunctionBody)
  /// The end payload was validated and the types known to the validator
  /// are provided.
  End(Types)
}

///|
/// Creates a new [`Validator`] ready to validate a WebAssembly module
/// or component.
///
/// The new validator will receive payloads parsed from
/// [`Parser`], and expects the first payload received to be
/// the version header from the parser.
pub fn Validator::new() -> Validator {
  Validator::new_with_features(WasmFeatures::default())
}

///|
/// Creates a new [`Validator`] which has the specified set of wasm
/// features activated for validation.
///
/// This function is the same as [`Validator::new`] except it also allows
/// you to customize the active wasm features in use for validation. This
/// can allow enabling experimental proposals or also turning off
/// on-by-default wasm proposals.
pub fn Validator::new_with_features(features : WasmFeatures) -> Validator {
  {
    id: ValidatorId::default(),
    state: Unparsed(None),
    types: TypeList::new(),
    module_: None,
    features,
  }
}

///|
/// Returns the wasm features used for this validator.
pub fn Validator::features(self : Validator) -> WasmFeatures {
  self.features
}

///|
/// Get this validator's unique identifier.
///
/// Allows you to assert that you are always working with the same
/// `Validator` instance, when you can't otherwise statically ensure that
/// property by e.g. storing a reference to the validator inside your
/// structure.
pub fn Validator::id(self : Validator) -> ValidatorId {
  self.id
}

///|
/// Validates an entire in-memory module or component with this validator.
///
/// This function will internally create a [`Parser`] to parse the `bytes`
/// provided. The entire module or component specified by `bytes` will be
/// parsed and validated.
///
/// Upon success, the type information for the top-level module or component
/// will be returned.
pub fn Validator::validate_all(
  self : Validator,
  bytes : BytesView,
) -> Types raise BinaryReaderError {
  let functions_to_validate = []
  let mut last_types = None
  let parser = Parser::new(0)
  parser.set_features(self.features)
  parser.parse_all(bytes, payload => {
    match self.payload(payload) {
      Func(a, b) => functions_to_validate.push((a, b))
      End(types) =>
        // Only the last (top-level) type information will be returned
        last_types = Some(types)
      Ok => ()
    }
  })
  let mut allocs = FuncValidatorAllocations::default()
  for item in functions_to_validate {
    let (func, body) = item
    let validator = func.into_validator(allocs)
    validator.validate(body)
    allocs = validator.into_allocations()
  }
  last_types.unwrap()
}

///|
/// Gets the types known by the validator so far within the
/// module/component `level` modules/components up from the
/// module/component currently being parsed.
pub fn Validator::types(self : Validator, level : Int) -> Types? {
  match self.module_ {
    Some(module_) if level == 0 =>
      Some({ id: self.id, list: self.types, module_: module_.module_, })
    _ => None
  }
}

///|
/// Convenience function to validate a single [`Payload`].
///
/// This function is intended to be used as a convenience. It will
/// internally perform any validation necessary to validate the [`Payload`]
/// provided. The convenience part is that you're likely already going to
/// be matching on [`Payload`] in your application, at which point it's more
/// appropriate to call the individual methods on [`Validator`] per-variant
/// in [`Payload`], such as [`Validator::type_section`].
///
/// This function returns a [`ValidPayload`] variant on success, indicating
/// one of a few possible actions that need to be taken after a payload is
/// validated. For example function contents are not validated here, they're
/// returned through [`ValidPayload`] for validation by the caller.
pub fn Validator::payload(
  self : Validator,
  payload : Payload,
) -> ValidPayload raise BinaryReaderError {
  match payload {
    Version(num~, encoding~, range~) => self.version(num, encoding, range)

    // Module sections
    TypeSection(s) => self.type_section(s)
    ImportSection(s) => self.import_section(s)
    FunctionSection(s) => self.function_section(s)
    TableSection(s) => self.table_section(s)
    MemorySection(s) => self.memory_section(s)
    TagSection(s) => self.tag_section(s)
    GlobalSection(s) => self.global_section(s)
    ExportSection(s) => self.export_section(s)
    StartSection(func~, range~) => self.start_section(func, range)
    ElementSection(s) => self.element_section(s)
    DataCountSection(count~, range~) => self.data_count_section(count, range)
    CodeSectionStart(count~, range~, size=_) =>
      self.code_section_start(count, range)
    CodeSectionEntry(body) => {
      let func_validator = self.code_section_entry(body)
      return Func(func_validator, body)
    }
    DataSection(s) => self.data_section(s)
    End(offset) => return End(self.end(offset))
    CustomSection(_) => () // no validation for custom sections
    UnknownSection(id~, range~, ..) => self.unknown_section(id, range)
  }
  Ok
}

///|
/// Validates [`Payload::Version`](crate::Payload).
pub fn Validator::version(
  self : Validator,
  num : UInt,
  encoding : Encoding,
  range : Range,
) -> Unit raise BinaryReaderError {
  match self.state {
    Unparsed(expected) =>
      if expected is Some(expected) {
        if expected != encoding {
          let what = match expected {
            Module => "module"
            Component => "component"
          }
          bail(range.start, "expected a version header for a \{what}")
        }
      }
    _ =>
      raise BinaryReaderError::new(
        "wasm version header out of order",
        range.start,
      )
  }
  self.state = match encoding {
    Module =>
      if num == wasm_module_version {
        guard self.module_ is None
        self.module_ = Some(ModuleState::default())
        Module
      } else {
        bail(
          range.start,
          "unknown binary version: 0x\{num.to_string(radix=16)}",
        )
      }
    Component => {
      if !self.features.component_model() {
        bail(
          range.start,
          "unknown binary version and encoding combination: 0x\{num.to_string(radix=16)} and 0x1, note: encoded as a component but the WebAssembly component model feature is not enabled - enable the feature to allow component validation",
        )
      }
      bail(
        range.start,
        "component model validation support disabled at compile time",
      )
    }
  }
}

///|
/// Validates [`Payload::TypeSection`](crate::Payload).
pub fn Validator::type_section(
  self : Validator,
  section : SectionLimited[RecGroup],
) -> Unit raise BinaryReaderError {
  self.process_module_section(
    Type,
    section,
    "type",
    (state, _, _types, count, offset) => {
      check_max(
        state.module_.types.length(),
        count,
        MAX_WASM_TYPES,
        "types",
        offset,
      )
    },
    (state, features, types, rec_group, offset) => {
      state.module_.add_types(rec_group, features, types, offset, true)
    },
  )
}

///|
/// Validates [`Payload::ImportSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::import_section(
  self : Validator,
  section : SectionLimited[Import],
) -> Unit raise BinaryReaderError {
  self.process_module_section(
    Import,
    section,
    "import",
    (state, _, _, count, offset) => {
      check_max(
        state.module_.imports.length(),
        count,
        MAX_WASM_IMPORTS,
        "imports",
        offset,
      )
    },
    (state, features, types, import_, offset) => {
      state.module_.add_import(import_, features, types, offset)
    },
  )
}

///|
/// Validates [`Payload::FunctionSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::function_section(
  self : Validator,
  section : SectionLimited[UInt],
) -> Unit raise BinaryReaderError {
  self.process_module_section(
    Function,
    section,
    "function",
    (state, _, _, count, offset) => {
      check_max(
        state.module_.functions.length(),
        count,
        MAX_WASM_FUNCTIONS,
        "functions",
        offset,
      )
      state.expected_code_bodies = Some(count)
    },
    (state, _, types, ty, offset) => {
      state.module_.add_function(ty, types, offset)
    },
  )
}

///|
/// Validates [`Payload::TableSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::table_section(
  self : Validator,
  section : SectionLimited[Table],
) -> Unit raise BinaryReaderError {
  let features = self.features
  self.process_module_section(
    Table,
    section,
    "table",
    (state, _, _, count, offset) => {
      check_max(
        state.module_.tables.length(),
        count,
        state.module_.max_tables(features),
        "tables",
        offset,
      )
    },
    (state, features, types, table, offset) => {
      state.add_table(table, features, types, offset)
    },
  )
}

///|
/// Validates [`Payload::MemorySection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::memory_section(
  self : Validator,
  section : SectionLimited[MemoryType],
) -> Unit raise BinaryReaderError {
  self.process_module_section(
    Memory,
    section,
    "memory",
    (state, features, _, count, offset) => {
      check_max(
        state.module_.memories.length(),
        count,
        state.module_.max_memories(features),
        "memories",
        offset,
      )
    },
    (state, features, _, ty, offset) => {
      state.module_.add_memory(ty, features, offset)
    },
  )
}

///|
/// Validates [`Payload::TagSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::tag_section(
  self : Validator,
  section : SectionLimited[TagType],
) -> Unit raise BinaryReaderError {
  if !self.features.exceptions() {
    raise BinaryReaderError::new(
      "exceptions proposal not enabled",
      section.range().start,
    )
  }
  self.process_module_section(
    Tag,
    section,
    "tag",
    (state, _, _, count, offset) => {
      check_max(
        state.module_.tags.length(),
        count,
        MAX_WASM_TAGS,
        "tags",
        offset,
      )
    },
    (state, features, types, ty, offset) => {
      state.module_.add_tag(ty, features, types, offset)
    },
  )
}

///|
/// Validates [`Payload::GlobalSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::global_section(
  self : Validator,
  section : SectionLimited[Global],
) -> Unit raise BinaryReaderError {
  self.process_module_section(
    Global,
    section,
    "global",
    (state, _, _, count, offset) => {
      check_max(
        state.module_.globals.length(),
        count,
        MAX_WASM_GLOBALS,
        "globals",
        offset,
      )
    },
    (state, features, types, global, offset) => {
      state.add_global(global, features, types, offset)
    },
  )
}

///|
/// Validates [`Payload::ExportSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::export_section(
  self : Validator,
  section : SectionLimited[Export],
) -> Unit raise BinaryReaderError {
  self.process_module_section(
    Export,
    section,
    "export",
    (state, _, _, count, offset) => {
      check_max(
        state.module_.exports.length(),
        count,
        MAX_WASM_EXPORTS,
        "exports",
        offset,
      )
    },
    (state, features, types, e, offset) => {
      let state = state.module_
      let ty = state.export_to_entity_type(e, offset)
      state.add_export(
        e.name,
        ty,
        features,
        offset,
        false, // checked above
        types,
      )
    },
  )
}

///|
/// Validates [`Payload::StartSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::start_section(
  self : Validator,
  func : UInt,
  range : Range,
) -> Unit raise BinaryReaderError {
  let offset = range.start
  self.state.ensure_module("start", offset)
  let state = self.module_.unwrap()
  state.update_order(Start, offset)
  let ty = state.module_.get_func_type(func, self.types, offset)
  if ty.params().length() != 0 || ty.results().length() != 0 {
    raise BinaryReaderError::new("invalid start function type", offset)
  }
}

///|
/// Validates [`Payload::ElementSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::element_section(
  self : Validator,
  section : SectionLimited[Element],
) -> Unit raise BinaryReaderError {
  self.process_module_section(
    Element,
    section,
    "element",
    (state, _, _, count, offset) => {
      check_max(
        state.module_.element_types.length(),
        count,
        MAX_WASM_ELEMENT_SEGMENTS,
        "element segments",
        offset,
      )
    },
    (state, features, types, e, offset) => {
      state.add_element_segment(e, features, types, offset)
    },
  )
}

///|
/// Validates [`Payload::DataCountSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::data_count_section(
  self : Validator,
  count : UInt,
  range : Range,
) -> Unit raise BinaryReaderError {
  let offset = range.start
  self.state.ensure_module("data count", offset)
  let state = self.module_.unwrap()
  state.update_order(DataCount, offset)
  if count > MAX_WASM_DATA_SEGMENTS.reinterpret_as_uint() {
    raise BinaryReaderError::new(
      "data count section specifies too many data segments", offset,
    )
  }
  state.module_.data_count = Some(count)
}

///|
/// Validates [`Payload::CodeSectionStart`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::code_section_start(
  self : Validator,
  count : UInt,
  range : Range,
) -> Unit raise BinaryReaderError {
  let offset = range.start
  self.state.ensure_module("code", offset)
  let state = self.module_.unwrap()
  state.update_order(Code, offset)
  let expected = state.expected_code_bodies
  state.expected_code_bodies = None
  match expected {
    Some(n) if n == count => ()
    Some(_) =>
      raise BinaryReaderError::new(
        "function and code section have inconsistent lengths", offset,
      )
    // empty code sections are allowed even if the function section is
    // missing
    None if count == 0 => ()
    None =>
      raise BinaryReaderError::new(
        "code section without function section", offset,
      )
  }

  // Take a snapshot of the types when we start the code section.
  state.module_.snapshot = Some(self.types)
}

///|
/// Validates [`Payload::CodeSectionEntry`](crate::Payload).
///
/// This function will prepare a [`FuncToValidate`] which can be used to
/// create a [`FuncValidator`] to validate the function. The function body
/// provided will not be parsed or validated by this function.
///
/// Note that the returned [`FuncToValidate`] is "connected" to this
/// [`Validator`] in that it uses the internal context of this validator for
/// validating the function. The [`FuncToValidate`] can be sent to another
/// thread, for example, to offload actual processing of functions
/// elsewhere.
///
/// This method should only be called when parsing a module.
pub fn Validator::code_section_entry(
  self : Validator,
  body : FunctionBody,
) -> FuncToValidate raise BinaryReaderError {
  let offset = body.range().start
  self.state.ensure_module("code", offset)
  let state = self.module_.unwrap()
  let (index, ty) = state.next_code_index_and_type(offset)
  {
    index,
    ty,
    resources: {
      module_: state.module_,
      types: state.module_.snapshot.unwrap_or(self.types),
    },
    features: self.features,
  }
}

///|
/// Validates [`Payload::DataSection`](crate::Payload).
///
/// This method should only be called when parsing a module.
pub fn Validator::data_section(
  self : Validator,
  section : SectionLimited[Data],
) -> Unit raise BinaryReaderError {
  self.process_module_section(
    Data,
    section,
    "data",
    (state, _, _, count, offset) => {
      state.data_segment_count = count
      check_max(0, count, MAX_WASM_DATA_SEGMENTS, "data segments", offset)
    },
    (state, features, types, d, offset) => {
      state.add_data_segment(d, features, types, offset)
    },
  )
}

///|
/// Validates [`Payload::UnknownSection`](crate::Payload).
///
/// Currently always returns an error.
pub fn Validator::unknown_section(
  _self : Validator,
  id : Byte,
  range : Range,
) -> Unit raise BinaryReaderError {
  bail(range.start, "malformed section id: \{id.to_int()}")
}

///|
/// Validates [`Payload::End`](crate::Payload).
///
/// Returns the types known to the validator for the module or component.
pub fn Validator::end(
  self : Validator,
  offset : Int,
) -> Types raise BinaryReaderError {
  let state = self.state
  self.state = End
  match state {
    Unparsed(_) =>
      raise BinaryReaderError::new(
        "cannot call `end` before a header has been parsed", offset,
      )
    End =>
      raise BinaryReaderError::new(
        "cannot call `end` after parsing has completed", offset,
      )
    Module => {
      let state = self.module_.unwrap()
      self.module_ = None
      state.validate_end(offset)
      { id: self.id, list: self.types, module_: state.module_, }
    }
  }
}

///|
fn[T : FromReader] Validator::process_module_section(
  self : Validator,
  order : Order,
  section : SectionLimited[T],
  name : String,
  validate_section : (ModuleState, WasmFeatures, TypeList, UInt, Int) -> Unit raise BinaryReaderError,
  validate_item : (ModuleState, WasmFeatures, TypeList, T, Int) -> Unit raise BinaryReaderError,
) -> Unit raise BinaryReaderError {
  let offset = section.range().start
  self.state.ensure_module(name, offset)
  let state = self.module_.unwrap()
  state.update_order(order, offset)
  validate_section(state, self.features, self.types, section.count(), offset)
  let iter = section.into_iter()
  while iter.next_with_offset() is Some((offset, item)) {
    validate_item(state, self.features, self.types, item, offset)
  }
}
