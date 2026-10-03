#!/usr/bin/env python3
"""Generates wasmparser/validator_test.mbt: hand-written modules validated by
the oracle (`oracle/src/bin/gen_wasmparser_tests.rs`, build it first with
`cd oracle && cargo build --release --offline --bin gen_wasmparser_tests`).

Usage: python3 wasmparser/testdata/gen_validator_test.py
"""
import os, shutil, subprocess, tempfile
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')
TMP = tempfile.mkdtemp()
D = os.path.join(TMP, 'unit')
shutil.rmtree(D, ignore_errors=True)
os.makedirs(D)

HDR = b'\x00asm\x01\x00\x00\x00'


def leb(n):
    out = bytearray()
    while True:
        b = n & 0x7f
        n >>= 7
        if n:
            out.append(b | 0x80)
        else:
            out.append(b)
            return bytes(out)


def sec(id, body):
    return bytes([id]) + leb(len(body)) + body


def vec(items):
    return leb(len(items)) + b''.join(items)


def func_type(params, results):
    return b'\x60' + vec([bytes([p]) for p in params]) + vec([bytes([r]) for r in results])


def code(locals_, body):
    f = vec(locals_) + body
    return leb(len(f)) + f


I32, I64, F32, F64, V128 = 0x7f, 0x7e, 0x7d, 0x7c, 0x7b

cases = {}
cases['empty'] = HDR
cases['bad_magic'] = b'\x00asn\x01\x00\x00\x00'
cases['version2'] = b'\x00asm\x02\x00\x00\x00'
cases['component'] = b'\x00asm\x0d\x00\x01\x00'
cases['truncated_header'] = b'\x00asm\x01\x00'

# (func (param i32) (result i32) local.get 0 i32.const 1 i32.add)
t1 = sec(1, vec([func_type([I32], [I32])]))
f1 = sec(3, vec([leb(0)]))
cases['add'] = HDR + t1 + f1 + sec(10, vec([code([], b'\x20\x00\x41\x01\x6a\x0b')]))
# type mismatch: local.get 0 f32.const 1.0 i32.add
cases['type_mismatch'] = HDR + t1 + f1 + sec(10, vec([code([], b'\x20\x00\x43\x00\x00\x80\x3f\x6a\x0b')]))
# missing end
cases['no_end'] = HDR + t1 + f1 + sec(10, vec([code([], b'\x20\x00')]))
# memory + i32.load with align 3
mem = sec(5, vec([b'\x00\x01']))
t0 = sec(1, vec([func_type([], [])]))
f0 = sec(3, vec([leb(0)]))
cases['align'] = HDR + t0 + f0 + mem + sec(10, vec([code([], b'\x41\x00\x28\x03\x00\x1a\x0b')]))
# section out of order: function section before type section
cases['order'] = HDR + f0 + t0
# function count overlong LEB (6 bytes)
cases['leb_long'] = HDR + t0 + sec(3, b'\x81\x80\x80\x80\x80\x00' + leb(0))
# function count too large
cases['leb_large'] = HDR + t0 + sec(3, b'\xff\xff\xff\xff\x1f' + leb(0))
# simd: v128.const + i8x16.shuffle with lane 32
shuffle = b'\xfd\x0c' + bytes(16) + b'\xfd\x0c' + bytes(16) + b'\xfd\x0d' + bytes([32] + [0] * 15) + b'\x1a\x0b'
cases['shuffle_lane'] = HDR + t0 + f0 + sec(10, vec([code([], shuffle)]))
simd_ok = b'\xfd\x0c' + bytes(16) + b'\xfd\x0c' + bytes(16) + b'\xfd\x0d' + bytes(range(16)) + b'\x1a\x0b'
cases['shuffle_ok'] = HDR + t0 + f0 + sec(10, vec([code([], simd_ok)]))
# threads: memory.atomic.notify
cases['threads'] = HDR + t0 + f0 + mem + sec(10, vec([code([], b'\x41\x00\x41\x00\xfe\x00\x02\x00\x1a\x0b')]))
# relaxed simd: i8x16.relaxed_swizzle
cases['relaxed'] = HDR + t0 + f0 + sec(10, vec([code([], b'\xfd\x0c' + bytes(16) + b'\xfd\x0c' + bytes(16) + b'\xfd\x80\x02\x1a\x0b')]))
# unknown section id 14
cases['unknown_section'] = HDR + sec(14, b'')
# export with malformed utf-8 name
cases['bad_utf8'] = HDR + t0 + f0 + sec(7, vec([leb(2) + b'\xc3\x28' + b'\x00\x00'])) + sec(10, vec([code([], b'\x0b')]))
# duplicate export
cases['dup_export'] = HDR + t0 + f0 + sec(7, vec([leb(1) + b'a' + b'\x00\x00', leb(1) + b'a' + b'\x00\x00'])) + sec(10, vec([code([], b'\x0b')]))
# multi-value block + br_table
body = b'\x02\x40' + b'\x41\x00' + b'\x0e\x02\x00\x00\x00' + b'\x0b' + b'\x0b'
cases['br_table'] = HDR + t0 + f0 + sec(10, vec([code([], body)]))
# global.get of mutable global in const expr
glob = sec(6, vec([b'\x7f\x01\x41\x00\x0b', b'\x7f\x00\x23\x00\x0b']))
cases['global_const'] = HDR + glob
# custom section with name
cases['custom'] = HDR + sec(0, leb(4) + b'name' + b'\x00\x01\x02')
# data count mismatch
cases['data_count'] = HDR + mem + sec(12, leb(2)) + sec(11, vec([b'\x00\x41\x00\x0b' + leb(1) + b'x']))
# too many locals
cases['locals'] = HDR + t0 + f0 + sec(10, vec([code([leb(50001) + bytes([I32])], b'\x0b')]))
# typed select with 2 results
cases['select_arity'] = HDR + t0 + f0 + sec(10, vec([code([], b'\x1c\x02\x7f\x7f\x0b')]))

t_i32 = sec(1, vec([func_type([], []), func_type([], [I32]), func_type([I32], [])]))
# code section trailing bytes
cases['code_trailing'] = HDR + t0 + f0 + sec(10, vec([code([], b'\x0b')]) + b'\x00')
# function body size beyond section
cases['body_size'] = HDR + t0 + f0 + bytes([10]) + leb(4) + leb(1) + leb(10) + b'\x00\x0b'
# start section with extra content
cases['start_extra'] = HDR + t0 + f0 + sec(8, leb(0) + b'\x00') + sec(10, vec([code([], b'\x0b')]))
# empty code section without function section
cases['empty_code'] = HDR + sec(10, vec([]))
# code section without function section
cases['code_no_func'] = HDR + t0 + sec(10, vec([code([], b'\x0b')]))
# element segments: passive with exprs, declared with funcs, active
tab = sec(4, vec([b'\x70\x00\x01']))
elem = sec(9, vec([b'\x05\x70' + vec([b'\xd2\x00\x0b', b'\xd0\x70\x0b']), b'\x03\x00' + vec([leb(0)]), b'\x00\x41\x00\x0b' + vec([leb(0)])]))
cases['elems'] = HDR + t0 + f0 + tab + elem + sec(10, vec([code([], b'\xd2\x00\x1a\x0b')]))
# ref.func undeclared
cases['ref_func_undeclared'] = HDR + t0 + f0 + sec(10, vec([code([], b'\xd2\x00\x1a\x0b')]))
# table with init expr
cases['table_init_expr'] = HDR + sec(4, vec([b'\x40\x00\x70\x00\x01\xd0\x70\x0b']))
# data segment with memory index 1
cases['data_mem_index'] = HDR + mem + sec(11, vec([b'\x02\x01\x41\x00\x0b' + leb(0)]))
# memory64 too large
cases['mem64_large'] = HDR + sec(5, vec([b'\x04' + leb(1 << 49)]))
# tag section
cases['tag_section'] = HDR + t0 + sec(13, vec([b'\x00\x00']))
# tag import
cases['tag_import'] = HDR + t0 + sec(2, vec([leb(1) + b'm' + leb(1) + b'n' + b'\x04\x00\x00']))
# mutable global import + export
cases['global_mut'] = HDR + sec(2, vec([leb(1) + b'm' + leb(1) + b'g' + b'\x03\x7f\x01'])) + sec(7, vec([leb(1) + b'g' + b'\x03\x00']))
# call_indirect through externref table
cases['call_indirect_extern'] = HDR + t0 + f0 + sec(4, vec([b'\x6f\x00\x01'])) + sec(10, vec([code([], b'\x41\x00\x11\x00\x00\x0b')]))
# return_call with mismatched results
cases['return_call_mismatch'] = HDR + t_i32 + sec(3, vec([leb(1), leb(0)])) + sec(10, vec([code([], b'\x12\x01\x0b'), code([], b'\x41\x00\x0b')]))
# memory.init without data count
cases['memory_init_no_count'] = HDR + t0 + f0 + mem + sec(10, vec([code([], b'\x41\x00\x41\x00\x41\x00\xfc\x08\x00\x00\x0b')])) + sec(11, vec([b'\x01' + leb(0)]))
# select with externref
cases['select_ref'] = HDR + t0 + f0 + sec(10, vec([code([], b'\xd0\x6f\xd0\x6f\x41\x00\x1b\x1a\x0b')]))
# typed select with v128
cases['typed_select_v128'] = HDR + t0 + f0 + sec(10, vec([code([], b'\xfd\x0c' + bytes(16) + b'\xfd\x0c' + bytes(16) + b'\x41\x00\x1c\x01\x7b\x1a\x0b')]))
# br_table arity mismatch
cases['br_table_arity'] = HDR + t0 + f0 + sec(10, vec([code([], b'\x02\x7f\x02\x40\x41\x00\x0e\x01\x00\x01\x0b\x41\x00\x0b\x1a\x0b')]))
# wide arithmetic
cases['wide'] = HDR + t0 + f0 + sec(10, vec([code([], b'\x42\x00\x42\x00\x42\x00\x42\x00\xfc\x13\x1a\x1a\x0b')]))
# try_table
cases['try_table'] = HDR + t0 + f0 + sec(10, vec([code([], b'\x1f\x40\x00\x0b\x0b')]))
# gc op
cases['gc_op'] = HDR + t0 + f0 + sec(10, vec([code([], b'\xfb\x1c\x1a\x0b')]))
# unknown 0xfc subopcode
cases['fc_unknown'] = HDR + t0 + f0 + sec(10, vec([code([], b'\xfc\x20\x0b')]))
# locals count overflow
cases['locals_overflow'] = HDR + t0 + f0 + sec(10, vec([code([b'\xff\xff\xff\xff\x0f\x7f', b'\x02\x7f'], b'\x0b')]))
# data section after code section with an error inside (offset quirk of wasmi)
cases['data_after_code_err'] = HDR + t0 + f0 + mem + sec(10, vec([code([], b'\x0b')])) + sec(11, vec([b'\x00\x42\x00\x0b' + leb(0)]))
# data section without code section, with an error inside
cases['data_no_code_err'] = HDR + mem + sec(11, vec([b'\x00\x42\x00\x0b' + leb(0)]))
# custom section after data
cases['custom_after_data'] = HDR + mem + sec(11, vec([b'\x00\x41\x00\x0b' + leb(0)])) + sec(0, leb(1) + b'x')
# type section after code (out of order in the data phase)
cases['type_after_code'] = HDR + t0 + f0 + sec(10, vec([code([], b'\x0b')])) + t0
# block with type index params
cases['block_params'] = HDR + sec(1, vec([func_type([], []), func_type([I32], [I32])])) + f0 + sec(10, vec([code([], b'\x41\x00\x02\x01\x0b\x1a\x0b')]))
# multi-memory and memory64 load
cases['mem64_load'] = HDR + t0 + f0 + sec(5, vec([b'\x04\x01', b'\x00\x01'])) + sec(10, vec([code([], b'\x42\x00\x28\x42\x01\x00\x1a\x0b')]))
# global with extended const
cases['extended_const'] = HDR + sec(2, vec([leb(1) + b'm' + leb(1) + b'g' + b'\x03\x7f\x00'])) + sec(6, vec([b'\x7f\x00\x23\x00\x41\x01\x6a\x0b']))
# nonzero byte after atomic.fence
cases['fence'] = HDR + t0 + f0 + sec(10, vec([code([], b'\xfe\x03\x01\x0b')]))
# br_on_cast flags
cases['cast_flags'] = HDR + t0 + f0 + sec(10, vec([code([], b'\xfb\x18\x04\x00\x70\x70\x0b')]))

for k, v in cases.items():
    open(os.path.join(D, k + '.wasm'), 'wb').write(v)

os.makedirs(os.path.join(TMP, 'no_plugins'), exist_ok=True)
out = subprocess.run([
    os.path.join(ROOT, 'oracle/target/release/gen_wasmparser_tests'),
    D, os.path.join(TMP, 'no_plugins')], capture_output=True, text=True, check=True).stdout
lines = [l for l in out.split('\n') if l and '@' not in l]


def mbt_bytes(b):
    return 'b"' + ''.join(f'\\x{x:02x}' for x in b) + '"'


def mbt_str(s):
    return '"' + s.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n') + '"'


res = ['''// Validation of hand-written modules. The expected outcomes are those of
// wasmparser 0.228.0 driven like wasmi 1.0.9 loads a module
// (`oracle/src/bin/gen_wasmparser_tests.rs`); generated by
// `wasmparser/testdata/gen_validator_test.py`. `wasmi_outcome` is the same
// driver as the runner's `wasm-validate` stage.

///|
fn wasmi_test_features() -> WasmFeatures {
  WasmFeatures::empty()
  .set(MUTABLE_GLOBAL, true)
  .set(MULTI_VALUE, true)
  .set(MULTI_MEMORY, true)
  .set(SATURATING_FLOAT_TO_INT, true)
  .set(SIGN_EXTENSION, true)
  .set(BULK_MEMORY, true)
  .set(REFERENCE_TYPES, true)
  .set(GC_TYPES, true)
  .set(TAIL_CALL, true)
  .set(EXTENDED_CONST, true)
  .set(FLOATS, true)
  .set(MEMORY64, true)
  .set(SIMD, true)
}

///|
/// wasmi's `ModuleParser::parse_buffered`: note that it re-parses the
/// payload which ends a phase (a data section or the end in the header
/// phase, anything but a code entry in the code phase) without consuming
/// it, which shifts the offsets of everything after it.
fn wasmi_run(bytes : Bytes) -> Unit raise BinaryReaderError {
  let features = wasmi_test_features()
  let parser = Parser::new(0)
  parser.set_features(features)
  let v = Validator::new_with_features(features)
  let mut buffer = bytes[:]
  fn next(buffer : BytesView) -> (Int, Payload) raise BinaryReaderError {
    match parser.parse(buffer, true) {
      Parsed(consumed~, payload~) => (consumed, payload)
      NeedMoreData(_) => abort("unreachable")
    }
  }
  while true {
    let (consumed, payload) = next(buffer)
    match payload {
      CodeSectionStart(count~, range~, ..) => {
        v.code_section_start(count, range)
        buffer = buffer[consumed:]
        break
      }
      DataSection(_) | End(_) => break
      CustomSection(_) => ()
      payload => v.payload(payload) |> ignore
    }
    buffer = buffer[consumed:]
  }
  while true {
    let (consumed, payload) = next(buffer)
    guard payload is CodeSectionEntry(body) else { break }
    buffer = buffer[consumed:]
    let func = v.code_section_entry(body)
    let validator = func.into_validator(FuncValidatorAllocations::default())
    let body = FunctionBody::new(
      BinaryReader::new_features(
        body.as_bytes(),
        body.get_binary_reader().original_position(),
        features,
      ),
    )
    let locals = body.get_locals_reader()
    for _ in 0U..<locals.get_count() {
      let offset = locals.original_position()
      let (amount, ty) = locals.read()
      validator.define_locals(offset, amount, ty)
    }
    let reader = body.get_operators_reader()
    while !reader.eof() {
      let pos = reader.original_position()
      validator.op(pos, reader.read())
    }
    reader.ensure_end()
    validator.finish(reader.original_position())
  }
  while true {
    let (consumed, payload) = next(buffer)
    match payload {
      End(offset) => {
        v.end(offset) |> ignore
        break
      }
      CustomSection(_) => ()
      payload => v.payload(payload) |> ignore
    }
    buffer = buffer[consumed:]
  }
}

///|
fn wasmi_outcome(bytes : Bytes) -> String {
  match (try? wasmi_run(bytes)) {
    Ok(_) => "ok"
    Err(e) => e.to_string()
  }
}
''']
for l in lines:
    name, outcome, *rest = l.split('\t')
    exp = 'ok' if outcome == 'ok' else rest[0].replace('\\n', '\n').replace('\\t', '\t').replace('\\\\', '\\')
    data = open(os.path.join(D, name), 'rb').read()
    res.append(f'''
///|
test "wasmi validate {name[:-5]}" {{
  assert_eq(
    wasmi_outcome({mbt_bytes(data)}),
    {mbt_str(exp)},
  )
}}
''')
open(os.path.join(ROOT, 'wasmparser/validator_test.mbt'), 'w').write(''.join(res))
print(len(lines))
shutil.rmtree(TMP)
