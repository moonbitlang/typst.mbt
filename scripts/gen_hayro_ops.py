# Converts hayro-syntax's `content/ops_generated.rs` into
# `hayro/syntax/content_ops.mbt`:
#   python3 scripts/gen_hayro_ops.py <hayro>/hayro-syntax/src/content/ops_generated.rs \
#     > hayro/syntax/content_ops.mbt && moon fmt
import re, sys
src = open(sys.argv[1]).read()
structs = {}
for m in re.finditer(r'pub struct (\w+)(?:<[^>]*>)?(?:\(((?:[^;]|; OPERANDS_THRESHOLD)*?)\))?;\s*\n\s*(op\w+)!\(\w+(?:<[^>]*>)?,\s*"((?:[^"\\]|\\.)*)"\);', src, re.S):
    name, fields, macro, op = m.groups()
    fl = []
    if fields:
        for f in fields.split(','):
            f = f.strip()
            if not f:
                continue
            f = f.replace('pub ', '').strip()
            fl.append(f)
    structs[name] = (fl, macro, op.replace('\\"', '"'))
enum_body = src.split('pub enum TypedInstruction')[1].split('\n}')[0]
order = re.findall(r'^\s+(\w+)\((?:\w+)(?:<[^>]*>)?\),$', enum_body, re.M)


def ty(f):
    if f == 'Number':
        return 'Number'
    if 'SmallVec' in f:
        return 'Array[Number]'
    if 'Name' in f:
        return 'Name'
    if 'Array' in f:
        return 'PdfArray'
    if 'Stream' in f:
        return 'Stream'
    if 'String' in f:
        return 'PdfString'
    if 'Object' in f:
        return 'Object'
    raise Exception(f)


def getter(t):
    return {'Number': 'operand_number', 'Name': 'operand_name', 'PdfArray': 'operand_array', 'Stream': 'operand_stream', 'PdfString': 'operand_string', 'Object': 'operand_object'}[t]


out = []
out.append('// Port of `hayro-syntax/src/content/ops.rs` and `ops_generated.rs`\n// (converted from upstream by scripts/gen_hayro_ops.py): content operators.\n')
out.append('///|\n/// A typed content stream instruction.\npub(all) enum TypedInstruction {')
for n in order:
    if n in ('StrokeColorNamed', 'NonStrokeColorNamed'):
        out.append(f'  {n}(Array[Number], Name?)')
        continue
    fl, macro, op = structs[n]
    if fl:
        out.append(f'  {n}({", ".join(ty(f) for f in fl)})')
    else:
        out.append(f'  {n}')
out.append('  Fallback(Name)\n}\n')
out.append('''///|
/// Dispatch an instruction to its typed form; `None` if the operands are
/// invalid.
pub fn TypedInstruction::dispatch(instruction : Instruction) -> TypedInstruction? {
  let stack = instruction.operands
  match instruction.operator.0 {''')
for n in order:
    if n in ('StrokeColorNamed', 'NonStrokeColorNamed'):
        op = 'SCN' if n == 'StrokeColorNamed' else 'scn'
        out.append(f'    "{op}" => {{\n      guard parse_named_color(stack) is Some((nums, name)) else {{ return None }}\n      Some({n}(nums, name))\n    }}')
        continue
    fl, macro, op = structs[n]
    opq = op.replace('\\', '\\\\').replace('"', '\\"')
    if macro == 'op0':
        out.append(f'    "{opq}" => Some({n})')
    elif macro == 'op_all':
        out.append(f'    "{opq}" => {{\n      guard stack_get_all_numbers(stack) is Some(nums) else {{ return None }}\n      Some({n}(nums))\n    }}')
    else:
        k = len(fl)
        guards = "".join(f'      guard {getter(ty(f))}(stack, {i} + shift) is Some(a{i}) else {{ return None }}\n' for i, f in enumerate(fl))
        args = ", ".join(f'a{i}' for i in range(k))
        out.append(f'    "{opq}" => {{\n      let shift = saturating_sub(stack.length(), {k})\n{guards}      Some({n}({args}))\n    }}')
out.append('    _ => Some(Fallback(instruction.operator))\n  }\n}\n')
out.append('///|\n/// The name of the instruction variant.\npub fn TypedInstruction::name(self : TypedInstruction) -> String {\n  match self {')
for n in order:
    if n in ('StrokeColorNamed', 'NonStrokeColorNamed'):
        out.append(f'    {n}(_, _) => "{n}"')
        continue
    fl, macro, op = structs[n]
    if fl:
        out.append(f'    {n}({", ".join("_" for _ in fl)}) => "{n}"')
    else:
        out.append(f'    {n} => "{n}"')
out.append('    Fallback(_) => "Fallback"\n  }\n}\n')
print("\n".join(out))
