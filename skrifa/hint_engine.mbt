// Port of skrifa 0.42.1 `src/outline/glyf/hint/engine/*.rs`: the TrueType
// bytecode interpreter.

///|
/// Maximum number of instructions we will execute in `Interp::run()`.
const MAX_RUN_INSTRUCTIONS : Int = 1_000_000

///|
const MAX_DEFINITION_SIZE : Int = 65535

///|
/// Tracks budgets for loops to limit execution time.
priv struct LoopBudget {
  limit : Int64
  mut backward_jumps : Int64
  mut loop_calls : Int64
}

///|
fn LoopBudget::new(cvt_len : Int, point_count : Int?) -> LoopBudget {
  // Compute limits for loop calls and backward jumps.
  let limit = match point_count {
    Some(point_count) =>
      imax(point_count * 10, 50).to_int64() + imax(cvt_len / 10, 50).to_int64()
    None => 300L + 22L * cvt_len.to_int64()
  }
  { limit, backward_jumps: 0, loop_calls: 0, }
}

///|
fn LoopBudget::reset(self : LoopBudget) -> Unit {
  self.backward_jumps = 0
  self.loop_calls = 0
}

///|
fn LoopBudget::doing_backward_jump(
  self : LoopBudget,
) -> Unit raise HintErrorKind {
  self.backward_jumps += 1L
  if self.backward_jumps > self.limit {
    raise ExceededExecutionBudget
  }
}

///|
fn LoopBudget::doing_loop_call(
  self : LoopBudget,
  count : Int,
) -> Unit raise HintErrorKind {
  self.loop_calls += count.to_int64()
  if self.loop_calls > self.limit {
    raise ExceededExecutionBudget
  }
}

///|
/// TrueType bytecode interpreter.
priv struct Interp {
  program : ProgramState
  graphics : GraphicsState
  functions : DefinitionMap
  instructions : DefinitionMap
  cvt : CowSlice
  storage : CowSlice
  value_stack : ValueStack
  loop_budget : LoopBudget
  axis_count : Int
  coords : Array[F2Dot14]
}

///|
fn Interp::new(
  cvt_len : Int,
  program : ProgramState,
  graphics : RetainedGraphicsState,
  functions : DefinitionMap,
  instructions : DefinitionMap,
  cvt : CowSlice,
  storage : CowSlice,
  value_stack : ValueStack,
  twilight : Zone,
  glyph : Zone,
  axis_count : Int,
  coords : Array[F2Dot14],
  is_composite : Bool,
) -> Interp {
  let point_count = if glyph.len() == 0 { None } else { Some(glyph.len()) }
  {
    program,
    graphics: GraphicsState::new(graphics, twilight, glyph, is_composite),
    functions,
    instructions,
    cvt,
    storage,
    value_stack,
    loop_budget: LoopBudget::new(cvt_len, point_count),
    axis_count,
    coords,
  }
}

///|
fn Interp::backward_compatibility(self : Interp) -> Bool {
  self.graphics.backward_compatibility
}

// ---------------------------------------------------------------------------
// Dispatch

///|
/// Resets state for the specified program and executes all instructions.
fn Interp::run_program(
  self : Interp,
  program : Program,
  is_pedantic : Bool,
) -> Unit raise HintError {
  self.reset(program, is_pedantic)
  self.run()
}

///|
/// Set internal state for running the specified program.
fn Interp::reset(self : Interp, program : Program, is_pedantic : Bool) -> Unit {
  self.program.reset(program)
  // Reset overall graphics state, keeping the retained bits.
  self.graphics.reset()
  self.graphics.is_pedantic = is_pedantic
  self.loop_budget.reset()
  // Program specific setup.
  match program {
    Font => {
      self.functions.reset()
      self.instructions.reset()
    }
    ControlValue => self.graphics.backward_compatibility = false
    Glyph => {
      // Instruct control bit 1 says we reset retained graphics state
      // to default values.
      if (self.graphics.retained.instruct_control & 2) != 0 {
        self.graphics.reset_retained()
      }
      // Set backward compatibility mode
      let target = self.graphics.retained.target
      if target.preserve_linear_metrics() {
        self.graphics.backward_compatibility = true
      } else if target.is_smooth() {
        self.graphics.backward_compatibility = (
            self.graphics.retained.instruct_control & 0x4
          ) ==
          0
      } else {
        self.graphics.backward_compatibility = false
      }
    }
  }
}

///|
/// Decodes and dispatches all instructions until completion or error.
fn Interp::run(self : Interp) -> Unit raise HintError {
  let mut count = 0
  while true {
    guard self.program.decoder.decode() is Some(ins) else { break }
    guard ins is Some(ins) else {
      raise HintError(
        program=self.program.current,
        glyph_id=None,
        pc=self.program.decoder.pc,
        opcode=None,
        kind=UnexpectedEndOfBytecode,
      )
    }
    self.dispatch(ins)
    count += 1
    if count > MAX_RUN_INSTRUCTIONS {
      raise HintError(
        program=self.program.current,
        glyph_id=None,
        pc=ins.pc,
        opcode=Some(ins.opcode),
        kind=ExceededExecutionBudget,
      )
    }
  }
}

///|
/// Executes the appropriate code for the given instruction.
fn Interp::dispatch(self : Interp, ins : Instruction) -> Unit raise HintError {
  let current_program = self.program.current
  self.dispatch_inner(ins) catch {
    kind =>
      raise HintError(
        program=current_program,
        glyph_id=None,
        pc=ins.pc,
        opcode=Some(ins.opcode),
        kind~,
      )
  }
}

///|
fn Interp::dispatch_inner(
  self : Interp,
  ins : Instruction,
) -> Unit raise HintErrorKind {
  let opcode = ins.opcode
  match opcode {
    0x00..<=0x05 => self.op_svtca(opcode)
    0x06..<=0x09 => self.op_svtl(opcode)
    0x0A => self.op_spvfs()
    0x0B => self.op_sfvfs()
    0x0C => self.op_gpv()
    0x0D => self.op_gfv()
    0x0E => self.op_sfvtpv()
    0x0F => self.op_isect()
    0x10 => self.graphics.rp0 = self.value_stack.pop()
    0x11 => self.graphics.rp1 = self.value_stack.pop()
    0x12 => self.graphics.rp2 = self.value_stack.pop()
    0x13 => self.graphics.zp0 = zone_pointer_from(self.value_stack.pop())
    0x14 => self.graphics.zp1 = zone_pointer_from(self.value_stack.pop())
    0x15 => self.graphics.zp2 = zone_pointer_from(self.value_stack.pop())
    0x16 => {
      let zp = zone_pointer_from(self.value_stack.pop())
      self.graphics.zp0 = zp
      self.graphics.zp1 = zp
      self.graphics.zp2 = zp
    }
    0x17 => self.op_sloop()
    0x18 => self.graphics.round_state.mode = Grid
    0x19 => self.graphics.round_state.mode = HalfGrid
    0x1A => self.graphics.retained.min_distance = self.value_stack.pop()
    0x1B => self.op_else()
    0x1C => self.do_jump(true)
    0x1D => self.graphics.retained.control_value_cutin = self.value_stack.pop()
    0x1E => self.graphics.retained.single_width_cutin = self.value_stack.pop()
    0x1F => {
      let n = self.value_stack.pop()
      self.graphics.retained.single_width = hmul(
        n,
        self.graphics.retained.scale,
      )
    }
    0x20 => self.value_stack.dup()
    0x21 => ignore(self.value_stack.pop())
    0x22 => self.value_stack.clear()
    0x23 => self.value_stack.swap()
    0x24 => {
      let n = self.value_stack.len
      self.value_stack.push(n)
    }
    0x25 => self.value_stack.copy_index()
    0x26 => self.value_stack.move_index()
    0x27 => self.op_alignpts()
    // UNUSED: 0x28
    0x29 => self.op_utp()
    0x2A => self.op_loopcall()
    0x2B => {
      let f = self.value_stack.pop()
      self.do_call(true, 1, f)
    }
    0x2C => {
      let f = self.value_stack.pop()
      self.do_def(true, f)
    }
    0x2D => self.program.leave()
    0x2E | 0x2F => self.op_mdap(opcode)
    0x30 | 0x31 => self.op_iup(opcode)
    0x32 | 0x33 => self.op_shp(opcode)
    0x34 | 0x35 => self.op_shc(opcode)
    0x36 | 0x37 => self.op_shz(opcode)
    0x38 => self.op_shpix()
    0x39 => self.op_ip()
    0x3A | 0x3B => self.op_msirp(opcode)
    0x3C => self.op_alignrp()
    0x3D => self.graphics.round_state.mode = DoubleGrid
    0x3E | 0x3F => self.op_miap(opcode)
    0x40 | 0x41 => self.value_stack.push_inline_operands(ins)
    0x42 => self.op_ws()
    0x43 => self.op_rs()
    0x44 => self.op_wcvtp()
    0x45 => self.op_rcvt()
    0x46 | 0x47 => self.op_gc(opcode)
    0x48 => self.op_scfs()
    0x49 | 0x4A => self.op_md(opcode)
    0x4B => self.value_stack.push(self.graphics.retained.ppem)
    0x4C => self.value_stack.push(self.graphics.retained.ppem * 64)
    0x4D => self.graphics.retained.auto_flip = true
    0x4E => self.graphics.retained.auto_flip = false
    // Should be unused in production fonts. Just pops a value.
    0x4F => ignore(self.value_stack.pop())
    0x50 => self.value_stack.apply_binary((a, b) => if a < b { 1 } else { 0 })
    0x51 => self.value_stack.apply_binary((a, b) => if a <= b { 1 } else { 0 })
    0x52 => self.value_stack.apply_binary((a, b) => if a > b { 1 } else { 0 })
    0x53 => self.value_stack.apply_binary((a, b) => if a >= b { 1 } else { 0 })
    0x54 => self.value_stack.apply_binary((a, b) => if a == b { 1 } else { 0 })
    0x55 => self.value_stack.apply_binary((a, b) => if a != b { 1 } else { 0 })
    0x56 => {
      let round_state = self.graphics.round_state
      self.value_stack.apply_unary(e1 => {
        if (round_state.round(e1) & 127) == 64 {
          1
        } else {
          0
        }
      })
    }
    0x57 => {
      let round_state = self.graphics.round_state
      self.value_stack.apply_unary(e1 => {
        if (round_state.round(e1) & 127) == 0 {
          1
        } else {
          0
        }
      })
    }
    0x58 => self.op_if()
    0x59 => ()
    0x5A =>
      self.value_stack.apply_binary((a, b) => {
        if a != 0 && b != 0 {
          1
        } else {
          0
        }
      })
    0x5B =>
      self.value_stack.apply_binary((a, b) => {
        if a != 0 || b != 0 {
          1
        } else {
          0
        }
      })
    0x5C => self.value_stack.apply_unary(e => if e == 0 { 1 } else { 0 })
    0x5D => self.op_deltap(opcode)
    0x5E => {
      let n = self.value_stack.pop()
      self.graphics.retained.delta_base = n & 0xFFFF
    }
    0x5F => {
      let n = self.value_stack.pop()
      if n.reinterpret_as_uint() > 6U {
        raise InvalidStackValue(n)
      }
      self.graphics.retained.delta_shift = n
    }
    0x60 => self.value_stack.apply_binary((a, b) => a + b)
    0x61 => self.value_stack.apply_binary((a, b) => a - b)
    0x62 =>
      self.value_stack.apply_binary((a, b) => {
        if b == 0 {
          raise DivideByZero
        }
        mul_div_no_round(a, 64, b)
      })
    0x63 => self.value_stack.apply_binary((a, b) => hmul_div(a, b, 64))
    0x64 => self.value_stack.apply_unary(n => if n < 0 { -n } else { n })
    0x65 => self.value_stack.apply_unary(n => -n)
    0x66 => self.value_stack.apply_unary(n => hfloor(n))
    0x67 => self.value_stack.apply_unary(n => hceil(n))
    0x68..<=0x6B => {
      let n1 = self.value_stack.pop()
      let n2 = self.graphics.round(n1)
      self.value_stack.push(n2)
    }
    // "No round" means do nothing :)
    0x6C..<=0x6F => ()
    0x70 => self.op_wcvtf()
    0x71 | 0x72 => self.op_deltap(opcode)
    0x73..<=0x75 => self.op_deltac(opcode)
    0x76 => {
      let n = self.value_stack.pop()
      self.super_round(0x4000, n)
      self.graphics.round_state.mode = Super
    }
    0x77 => {
      let n = self.value_stack.pop()
      self.super_round(0x2D41, n)
      self.graphics.round_state.mode = Super45
    }
    0x78 => {
      let e = self.value_stack.pop()
      self.do_jump(e != 0)
    }
    0x79 => {
      let e = self.value_stack.pop()
      self.do_jump(e == 0)
    }
    0x7A => self.graphics.round_state.mode = Off
    // UNUSED: 0x7B
    0x7C => self.graphics.round_state.mode = UpToGrid
    0x7D => self.graphics.round_state.mode = DownToGrid
    // totally unsupported but we still need to pop the stack value
    0x7E => ignore(self.value_stack.pop())
    // Unsupported instruction, do nothing
    0x7F => ()
    0x80 => self.op_flippt()
    0x81 => self.set_on_curve_for_range(true)
    0x82 => self.set_on_curve_for_range(false)
    // UNUSED: 0x83 | 0x84
    0x85 => self.op_scanctrl()
    0x86 | 0x87 => self.op_sdpvtl(opcode)
    0x88 => self.op_getinfo()
    0x89 => {
      let op = self.value_stack.pop()
      self.do_def(false, op)
    }
    0x8A => self.value_stack.roll()
    0x8B => self.value_stack.apply_binary((a, b) => imax(a, b))
    0x8C => self.value_stack.apply_binary((a, b) => imin(a, b))
    0x8D => {
      let n = self.value_stack.pop()
      self.graphics.retained.scan_type = n & 0xFFFF
    }
    0x8E => self.op_instctrl()
    // UNUSED: 0x8F | 0x90 (ADJUST?)
    0x91 => self.op_getvariation()
    0x92 =>
      if self.axis_count != 0 {
        self.value_stack.push(17)
      } else {
        self.do_call(false, 1, 0x92)
      }
    _ =>
      // FreeType handles MIRP, MDRP and pushes here.
      if opcode >= 0xE0 {
        self.op_mirp(opcode)
      } else if opcode >= 0xC0 {
        self.op_mdrp(opcode)
      } else if opcode >= 0xB0 {
        self.value_stack.push_inline_operands(ins)
      } else {
        self.do_call(false, 1, opcode)
      }
  }
}

// ---------------------------------------------------------------------------
// Control flow

///|
fn Interp::op_if(self : Interp) -> Unit raise HintErrorKind {
  if self.value_stack.pop() == 0 {
    // The condition variable is false so we jump to the next
    // ELSE or EIF but we have to skip intermediate IF/ELSE/EIF
    // instructions.
    let mut nest_depth = 1
    let mut out = false
    while !out {
      let opcode = self.decode_next_opcode()
      if opcode == OP_IF {
        nest_depth += 1
      } else if opcode == OP_ELSE {
        out = nest_depth == 1
      } else if opcode == OP_EIF {
        nest_depth -= 1
        out = nest_depth == 0
      }
    }
  }
}

///|
fn Interp::op_else(self : Interp) -> Unit raise HintErrorKind {
  let mut nest_depth = 1
  while nest_depth != 0 {
    let opcode = self.decode_next_opcode()
    if opcode == OP_IF {
      nest_depth += 1
    } else if opcode == OP_EIF {
      nest_depth -= 1
    }
  }
}

///|
/// Common code for jump instructions.
fn Interp::do_jump(self : Interp, cond : Bool) -> Unit raise HintErrorKind {
  // Offset is relative to previous jump instruction and decoder is
  // already pointing to next instruction, so subtract one
  let jump_offset = self.value_stack.pop() - 1
  if cond {
    if jump_offset < 0 {
      if jump_offset == -1 {
        // If the offset is -1, we'll just loop in place... forever
        raise InvalidJump
      }
      self.loop_budget.doing_backward_jump()
    }
    let pc = self.program.decoder.pc.to_int64() + jump_offset.to_int64()
    // Negative values stand for wrapped (huge) program counters.
    self.program.decoder.pc = if pc < 0L || pc > 0x7FFFFFFFL {
      -1
    } else {
      pc.to_int()
    }
  }
}

///|
fn Interp::decode_next_opcode(self : Interp) -> Int raise HintErrorKind {
  match self.program.decoder.decode() {
    Some(Some(ins)) => ins.opcode
    _ => raise UnexpectedEndOfBytecode
  }
}

// ---------------------------------------------------------------------------
// Definitions

///|
fn Interp::op_loopcall(self : Interp) -> Unit raise HintErrorKind {
  let f = self.value_stack.pop()
  let count = self.value_stack.pop()
  if count > 0 {
    self.loop_budget.doing_loop_call(count)
    self.do_call(true, count, f)
  }
}

///|
fn Interp::do_def(
  self : Interp,
  is_function : Bool,
  key : Int,
) -> Unit raise HintErrorKind {
  if self.program.initial == Glyph {
    raise DefinitionInGlyphProgram
  }
  let defs = if is_function { self.functions } else { self.instructions }
  let def_ix = defs.allocate(key)
  let start = self.program.decoder.pc
  while self.program.decoder.decode() is Some(ins) {
    guard ins is Some(ins) else { raise UnexpectedEndOfBytecode }
    if ins.opcode == OP_FDEF || ins.opcode == OP_IDEF {
      raise NestedDefinition
    } else if ins.opcode == OP_ENDF {
      let end = ins.pc + 1
      if self.graphics.is_pedantic && end - start > MAX_DEFINITION_SIZE {
        defs.defs[def_ix] = Definition::default()
        raise DefinitionTooLarge
      }
      defs.defs[def_ix] = Definition::new(self.program.current, start, end, key)
      return
    }
  }
  raise UnexpectedEndOfBytecode
}

///|
fn Interp::do_call(
  self : Interp,
  is_function : Bool,
  count : Int,
  key : Int,
) -> Unit raise HintErrorKind {
  if count == 0 {
    return
  }
  let def = if is_function {
    self.functions.get(key)
  } else {
    // Remap an invalid definition error to unhandled opcode
    self.instructions.get(key) catch {
      InvalidDefinition(opcode) => raise UnhandledOpcode(opcode & 0xFF)
      e => raise e
    }
  }
  self.program.enter(def, count)
}

// ---------------------------------------------------------------------------
// Graphics state

///|
fn line_vector(
  p1 : (Int, Int),
  p2 : (Int, Int),
  is_parallel : Bool,
) -> (Int, Int) {
  let mut a = p1.0 - p2.0
  let mut b = p1.1 - p2.1
  if a == 0 && b == 0 {
    // If the points are equal, set to the x axis.
    a = 0x4000
  } else if !is_parallel {
    // Perform a counter-clockwise rotation by 90 degrees to form a
    // perpendicular line.
    let c = b
    b = a
    a = -c
  }
  normalize14(a, b)
}

///|
// Cannot fail; every opcode handler returns `OpResult`
// (skrifa 0.42.1 src/outline/glyf/hint/engine/graphics.rs:40).
#warnings("-unused_error_type")
fn Interp::op_svtca(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  // The low bit of the opcode determines the axis to set (1 = x, 0 = y).
  let x = (opcode & 1) << 14
  let y = x ^ 0x4000
  let gs = self.graphics
  // Opcodes 0..4 set the projection vector.
  if opcode < 4 {
    gs.proj_x = x
    gs.proj_y = y
    gs.dual_proj_x = x
    gs.dual_proj_y = y
  }
  // Opcodes with bit 2 unset modify the freedom vector.
  if (opcode & 2) == 0 {
    gs.freedom_x = x
    gs.freedom_y = y
  }
  gs.update_projection_state()
}

///|
fn Interp::op_svtl(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let index1 = self.value_stack.pop()
  let index2 = self.value_stack.pop()
  let is_parallel = (opcode & 1) == 0
  let gs = self.graphics
  let p1 = gs.zp1z().point(index2)
  let p2 = gs.zp2z().point(index1)
  let (vx, vy) = line_vector(p1, p2, is_parallel)
  if opcode < 8 {
    gs.proj_x = vx
    gs.proj_y = vy
    gs.dual_proj_x = vx
    gs.dual_proj_y = vy
  } else {
    gs.freedom_x = vx
    gs.freedom_y = vy
  }
  gs.update_projection_state()
}

///|
// Cannot fail; every opcode handler returns `OpResult`
// (skrifa 0.42.1 src/outline/glyf/hint/engine/graphics.rs:105).
#warnings("-unused_error_type")
fn Interp::op_sfvtpv(self : Interp) -> Unit raise HintErrorKind {
  let gs = self.graphics
  gs.freedom_x = gs.proj_x
  gs.freedom_y = gs.proj_y
  gs.update_projection_state()
}

///|
fn Interp::op_sdpvtl(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let index1 = self.value_stack.pop()
  let index2 = self.value_stack.pop()
  let is_parallel = (opcode & 1) == 0
  let gs = self.graphics
  // First set the dual projection vector from *original* points.
  let p1 = gs.zp1z().original(index2)
  let p2 = gs.zp2z().original(index1)
  let (dx, dy) = line_vector(p1, p2, is_parallel)
  gs.dual_proj_x = dx
  gs.dual_proj_y = dy
  // Now set the projection vector from the *current* points.
  let p1 = gs.zp1z().point(index2)
  let p2 = gs.zp2z().point(index1)
  let (px, py) = line_vector(p1, p2, is_parallel)
  gs.proj_x = px
  gs.proj_y = py
  gs.update_projection_state()
}

///|
fn Interp::op_spvfs(self : Interp) -> Unit raise HintErrorKind {
  let y = self.value_stack.pop() << 16 >> 16
  let x = self.value_stack.pop() << 16 >> 16
  let gs = self.graphics
  let (vx, vy) = if x == 0 && y == 0 {
    (gs.proj_x, gs.proj_y)
  } else {
    normalize14(x, y)
  }
  gs.proj_x = vx
  gs.proj_y = vy
  gs.dual_proj_x = vx
  gs.dual_proj_y = vy
  gs.update_projection_state()
}

///|
fn Interp::op_sfvfs(self : Interp) -> Unit raise HintErrorKind {
  let y = self.value_stack.pop() << 16 >> 16
  let x = self.value_stack.pop() << 16 >> 16
  let gs = self.graphics
  let (vx, vy) = if x == 0 && y == 0 {
    (gs.freedom_x, gs.freedom_y)
  } else {
    normalize14(x, y)
  }
  gs.freedom_x = vx
  gs.freedom_y = vy
  gs.update_projection_state()
}

///|
fn Interp::op_gpv(self : Interp) -> Unit raise HintErrorKind {
  self.value_stack.push(self.graphics.proj_x)
  self.value_stack.push(self.graphics.proj_y)
}

///|
fn Interp::op_gfv(self : Interp) -> Unit raise HintErrorKind {
  self.value_stack.push(self.graphics.freedom_x)
  self.value_stack.push(self.graphics.freedom_y)
}

///|
fn Interp::super_round(
  self : Interp,
  grid_period : Int,
  selector : Int,
) -> Unit {
  let round_state = self.graphics.round_state
  let period = match selector & 0xC0 {
    0 => grid_period / 2
    0x40 => grid_period
    0x80 => grid_period * 2
    _ => grid_period
  }
  let phase = match selector & 0x30 {
    0 => 0
    0x10 => period / 4
    0x20 => period / 2
    _ => period * 3 / 4
  }
  let threshold = if (selector & 0x0F) == 0 {
    period - 1
  } else {
    ((selector & 0x0F) - 4) * period / 8
  }
  round_state.period = period >> 8
  round_state.phase = phase >> 8
  round_state.threshold = threshold >> 8
}

///|
fn Interp::op_sloop(self : Interp) -> Unit raise HintErrorKind {
  let n = self.value_stack.pop()
  if n < 0 {
    raise NegativeLoopCounter
  }
  // As in FreeType, heuristically limit the number of loops to 16 bits.
  self.graphics.loop_counter = imin(n, 0xFFFF)
}

///|
fn Interp::op_instctrl(self : Interp) -> Unit raise HintErrorKind {
  let selector = self.value_stack.pop().reinterpret_as_uint()
  let value = self.value_stack.pop().reinterpret_as_uint()
  // Selectors are indices starting with 1; not flags.
  if !(selector >= 1U && selector <= 3U) {
    return
  }
  // Convert index to flag.
  let selector_flag = 1U << (selector - 1U).reinterpret_as_int()
  if value != 0U && value != selector_flag {
    return
  }
  // If preserving linear metrics, prevent modification of the backward
  // compatibility flag.
  if selector == 3U && self.graphics.retained.target.preserve_linear_metrics() {
    return
  }
  match (self.program.initial, selector) {
    // Typically, this instruction can only be executed in the prep table.
    (ControlValue, _) => {
      let r = self.graphics.retained
      r.instruct_control = r.instruct_control &
        (selector_flag.reinterpret_as_int() ^ 0xFF)
      r.instruct_control = r.instruct_control |
        (value.reinterpret_as_int() & 0xFF)
    }
    // Allow an exception in the glyph program for selector 3 which can
    // temporarily disable backward compatibility mode.
    (Glyph, 3U) => self.graphics.backward_compatibility = value != 4U
    _ => ()
  }
}

///|
fn Interp::op_scanctrl(self : Interp) -> Unit raise HintErrorKind {
  let n = self.value_stack.pop()
  let r = self.graphics.retained
  // Bits 0-7 represent the threshold value for ppem.
  let threshold = n & 0xFF
  match threshold {
    0xFF => r.scan_control = true
    0 => r.scan_control = false
    _ => {
      let ppem = r.ppem
      if (n & 0x100) != 0 && ppem <= threshold {
        r.scan_control = true
      }
      if (n & 0x200) != 0 && r.is_rotated {
        r.scan_control = true
      }
      if (n & 0x400) != 0 && r.is_stretched {
        r.scan_control = true
      }
      if (n & 0x800) != 0 && ppem > threshold {
        r.scan_control = false
      }
      if (n & 0x1000) != 0 && r.is_rotated {
        r.scan_control = false
      }
      if (n & 0x2000) != 0 && r.is_stretched {
        r.scan_control = false
      }
    }
  }
}

// ---------------------------------------------------------------------------
// CVT and storage

///|
fn Interp::op_wcvtp(self : Interp) -> Unit raise HintErrorKind {
  let value = self.value_stack.pop()
  let location = self.value_stack.pop()
  let ok = self.cvt.set(location, value)
  if self.graphics.is_pedantic && !ok {
    raise InvalidCvtIndex(location)
  }
}

///|
fn Interp::op_wcvtf(self : Interp) -> Unit raise HintErrorKind {
  let value = self.value_stack.pop()
  let location = self.value_stack.pop()
  let ok = self.cvt.set(location, hmul(value, self.graphics.retained.scale))
  if self.graphics.is_pedantic && !ok {
    raise InvalidCvtIndex(location)
  }
}

///|
fn Interp::op_rcvt(self : Interp) -> Unit raise HintErrorKind {
  let location = self.value_stack.pop()
  let value = match self.cvt.get(location) {
    Some(v) => v
    None =>
      if self.graphics.is_pedantic {
        raise InvalidCvtIndex(location)
      } else {
        0
      }
  }
  self.value_stack.push(value)
}

///|
fn Interp::op_rs(self : Interp) -> Unit raise HintErrorKind {
  let location = self.value_stack.pop()
  let value = match self.storage.get(location) {
    Some(v) => v
    None =>
      if self.graphics.is_pedantic {
        raise InvalidStorageIndex(location)
      } else {
        0
      }
  }
  self.value_stack.push(value)
}

///|
fn Interp::op_ws(self : Interp) -> Unit raise HintErrorKind {
  let value = self.value_stack.pop()
  let location = self.value_stack.pop()
  let ok = self.storage.set(location, value)
  if self.graphics.is_pedantic && !ok {
    raise InvalidStorageIndex(location)
  }
}

// ---------------------------------------------------------------------------
// Data

///|
fn Interp::op_gc(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let p = self.value_stack.pop()
  let gs = self.graphics
  if !gs.is_pedantic && !gs.in_bounds([(gs.zp2, p)]) {
    self.value_stack.push(0)
    return
  }
  let value = if (opcode & 1) != 0 {
    gs.dual_project(gs.zp2z().original(p), (0, 0))
  } else {
    gs.project(gs.zp2z().point(p), (0, 0))
  }
  self.value_stack.push(value)
}

///|
fn Interp::op_scfs(self : Interp) -> Unit raise HintErrorKind {
  let value = self.value_stack.pop()
  let p = self.value_stack.pop()
  let gs = self.graphics
  let projection = gs.project(gs.zp2z().point(p), (0, 0))
  gs.move_point(gs.zp2, p, value - projection)
  if gs.zp2.is_twilight() {
    let twilight = gs.zone(ZonePointer(0))
    let pt = twilight.point(p)
    twilight.set_original(p, pt)
  }
}

///|
fn Interp::op_md(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let p1 = self.value_stack.pop()
  let p2 = self.value_stack.pop()
  let gs = self.graphics
  if !gs.is_pedantic && !gs.in_bounds([(gs.zp0, p2), (gs.zp1, p1)]) {
    self.value_stack.push(0)
    return
  }
  let distance = if (opcode & 1) != 0 {
    // measure in grid fitted outline
    gs.project(gs.zp0z().point(p2), gs.zp1z().point(p1))
  } else if gs.zp0.is_twilight() || gs.zp1.is_twilight() {
    // special case for twilight zone
    gs.dual_project(gs.zp0z().original(p2), gs.zp1z().original(p1))
  } else {
    // measure in original unscaled outline
    hmul(
      gs.dual_project(gs.zp0z().unscaled(p2), gs.zp1z().unscaled(p1)),
      gs.unscaled_to_pixels(),
    )
  }
  self.value_stack.push(distance)
}

// ---------------------------------------------------------------------------
// Delta exceptions

///|
fn Interp::op_deltap(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let ppem = gs.retained.ppem.reinterpret_as_uint()
  let point_count = gs.zp0z().len()
  let n = self.value_stack.pop_count_checked()
  // Each exception requires two values on the stack so limit our count.
  let n = imin(n, self.value_stack.len / 2)
  let bias = (match opcode {
      0x71 => 16U
      0x72 => 32U
      _ => 0U
    }) +
    gs.retained.delta_base.reinterpret_as_uint()
  let back_compat = gs.backward_compatibility
  let did_iup = gs.did_iup_x && gs.did_iup_y
  for _ in 0..<n {
    let point_ix = self.value_stack.pop()
    let mut b = self.value_stack.pop()
    // FreeType notes that some popular fonts contain invalid DELTAP
    // instructions so out of bounds points are ignored.
    if point_ix < 0 || point_ix >= point_count {
      continue
    }
    let mut c = (b.reinterpret_as_uint() & 0xF0U) >> 4
    c = c + bias
    if ppem == c {
      b = (b & 0xF) - 8
      if b >= 0 {
        b += 1
      }
      b = b * (1 << (6 - gs.retained.delta_shift))
      let distance = b
      if back_compat {
        if !did_iup &&
          (
            (gs.is_composite && gs.freedom_y != 0) ||
            gs.zp0z().is_touched(point_ix, Y)
          ) {
          gs.move_point(gs.zp0, point_ix, distance)
        }
      } else {
        gs.move_point(gs.zp0, point_ix, distance)
      }
    }
  }
}

///|
fn Interp::op_deltac(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let ppem = gs.retained.ppem.reinterpret_as_uint()
  let n = self.value_stack.pop_count_checked()
  let n = imin(n, self.value_stack.len / 2)
  let bias = (match opcode {
      0x74 => 16U
      0x75 => 32U
      _ => 0U
    }) +
    gs.retained.delta_base.reinterpret_as_uint()
  for _ in 0..<n {
    let cvt_ix = self.value_stack.pop()
    let mut b = self.value_stack.pop()
    let mut c = (b.reinterpret_as_uint() & 0xF0U) >> 4
    c = c + bias
    if ppem == c {
      b = (b & 0xF) - 8
      if b >= 0 {
        b += 1
      }
      b = b * (1 << (6 - gs.retained.delta_shift))
      let cvt_val = self.cvt.cvt_get(cvt_ix)
      self.cvt.cvt_set(cvt_ix, cvt_val + b)
    }
  }
}

// ---------------------------------------------------------------------------
// Misc

///|
fn Interp::op_getinfo(self : Interp) -> Unit raise HintErrorKind {
  let selector = self.value_stack.pop()
  let mut result = 0
  let r = self.graphics.retained
  if (selector & 1) != 0 {
    result = 40
  }
  if (selector & (1 << 1)) != 0 && r.is_rotated {
    result = result | (1 << 8)
  }
  if (selector & (1 << 2)) != 0 && r.is_stretched {
    result = result | (1 << 9)
  }
  if (selector & (1 << 3)) != 0 && self.axis_count != 0 {
    result = result | (1 << 10)
  }
  if r.target.is_smooth() {
    if (selector & (1 << 6)) != 0 {
      result = result | (1 << 13)
    }
    if (selector & (1 << 8)) != 0 && r.target.is_vertical_lcd() {
      result = result | (1 << 15)
    }
    if (selector & (1 << 10)) != 0 {
      result = result | (1 << 17)
    }
    if (selector & (1 << 11)) != 0 && r.target.symmetric_rendering() {
      result = result | (1 << 18)
    }
    if (selector & (1 << 12)) != 0 && r.target.is_grayscale_cleartype() {
      result = result | (1 << 19)
    }
  }
  self.value_stack.push(result)
}

///|
fn Interp::op_getvariation(self : Interp) -> Unit raise HintErrorKind {
  let axis_count = self.axis_count
  if axis_count != 0 {
    for i in 0..<axis_count {
      let v = match self.coords.get(i) {
        Some(c) => c.to_bits()
        None => 0
      }
      self.value_stack.push(v)
    }
  } else {
    self.do_call(false, 1, 0x91)
  }
}

// ---------------------------------------------------------------------------
// Outline manipulation

///|
fn Interp::op_flippt(self : Interp) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let count = gs.loop_counter
  gs.loop_counter = 1
  if gs.backward_compatibility && gs.did_iup_x && gs.did_iup_y {
    for _ in 0..<count {
      ignore(self.value_stack.pop())
    }
    return
  }
  let zone = gs.zone(ZonePointer(1))
  for _ in 0..<count {
    let p = self.value_stack.pop()
    zone.flip_on_curve(p)
  }
}

///|
fn Interp::set_on_curve_for_range(
  self : Interp,
  on : Bool,
) -> Unit raise HintErrorKind {
  let high_point = self.value_stack.pop()
  let low_point = self.value_stack.pop()
  // `usize::MAX + 1` overflows
  if high_point == -1 {
    raise InvalidPointIndex(high_point)
  }
  let high_point = high_point + 1
  let gs = self.graphics
  if gs.backward_compatibility && gs.did_iup_x && gs.did_iup_y {
    return
  }
  gs.zone(ZonePointer(1)).set_on_curve(low_point, high_point, on)
}

///|
fn Interp::op_shp(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let disp = gs.point_displacement(opcode)
  let count = gs.loop_counter
  gs.loop_counter = 1
  for _ in 0..<count {
    let p = self.value_stack.pop()
    gs.move_zp2_point(p, disp.dx, disp.dy, true)
  }
}

///|
fn Interp::op_shc(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let contour_ix = self.value_stack.pop()
  if !gs.is_pedantic && (contour_ix < 0 || contour_ix >= gs.zp2z().contours.len) {
    return
  }
  let point_disp = gs.point_displacement(opcode)
  let start = if contour_ix != 0 {
    gs.zp2z().contour(contour_ix - 1) + 1
  } else {
    0
  }
  let end = if gs.zp2.is_twilight() {
    gs.zp2z().len()
  } else {
    gs.zp2z().contour(contour_ix) + 1
  }
  for i in start..<end {
    if point_disp.zone != gs.zp2 || point_disp.point_ix != i {
      gs.move_zp2_point(i, point_disp.dx, point_disp.dy, true)
    }
  }
}

///|
fn Interp::op_shz(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  ignore(zone_pointer_from(self.value_stack.pop()))
  let gs = self.graphics
  let point_disp = gs.point_displacement(opcode)
  let z = gs.zp2z()
  let end = if gs.zp2.is_twilight() {
    z.len()
  } else if z.contours.len != 0 {
    z.contours.get(z.contours.len - 1) + 1
  } else {
    0
  }
  for i in 0..<end {
    if point_disp.zone != gs.zp2 || i != point_disp.point_ix {
      gs.move_zp2_point(i, point_disp.dx, point_disp.dy, false)
    }
  }
}

///|
fn Interp::op_shpix(self : Interp) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let in_twilight = gs.zp0.is_twilight() ||
    gs.zp1.is_twilight() ||
    gs.zp2.is_twilight()
  let amount = self.value_stack.pop()
  let dx = mul14(amount, gs.freedom_x)
  let dy = mul14(amount, gs.freedom_y)
  let count = gs.loop_counter
  gs.loop_counter = 1
  let did_iup = gs.did_iup_x && gs.did_iup_y
  for _ in 0..<count {
    let p = self.value_stack.pop()
    if gs.backward_compatibility {
      if in_twilight ||
        (
          !did_iup &&
          ((gs.is_composite && gs.freedom_y != 0) || gs.zp2z().is_touched(p, Y))
        ) {
        gs.move_zp2_point(p, dx, dy, true)
      }
    } else {
      gs.move_zp2_point(p, dx, dy, true)
    }
  }
}

///|
fn Interp::op_msirp(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let distance = self.value_stack.pop()
  let point_ix = self.value_stack.pop()
  if !gs.is_pedantic && !gs.in_bounds([(gs.zp1, point_ix), (gs.zp0, gs.rp0)]) {
    return
  }
  if gs.zp1.is_twilight() {
    let o = gs.zp0z().original(gs.rp0)
    gs.zp1z().set_point(point_ix, o)
    gs.move_original(gs.zp1, point_ix, distance)
    let o2 = gs.zp1z().original(point_ix)
    gs.zp1z().set_point(point_ix, o2)
  }
  let d = gs.project(gs.zp1z().point(point_ix), gs.zp0z().point(gs.rp0))
  gs.move_point(gs.zp1, point_ix, distance - d)
  gs.rp1 = gs.rp0
  gs.rp2 = point_ix
  if (opcode & 1) != 0 {
    gs.rp0 = point_ix
  }
}

///|
fn Interp::op_mdap(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let p = self.value_stack.pop()
  if !gs.is_pedantic && !gs.in_bounds([(gs.zp0, p)]) {
    gs.rp0 = p
    gs.rp1 = p
    return
  }
  let distance = if (opcode & 1) != 0 {
    let cur_dist = gs.project(gs.zp0z().point(p), (0, 0))
    gs.round(cur_dist) - cur_dist
  } else {
    0
  }
  gs.move_point(gs.zp0, p, distance)
  gs.rp0 = p
  gs.rp1 = p
}

///|
fn abs32(x : Int) -> Int {
  if x < 0 {
    -x
  } else {
    x
  }
}

///|
fn Interp::op_miap(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let cvt_entry = self.value_stack.pop()
  let point_ix = self.value_stack.pop()
  let mut distance = self.cvt.cvt_get(cvt_entry)
  if gs.zp0.is_twilight() {
    let z = gs.zp0z()
    ignore(z.original(point_ix))
    let o = (mul14(distance, gs.freedom_x), mul14(distance, gs.freedom_y))
    z.set_original(point_ix, o)
    z.set_point(point_ix, o)
  }
  let original_distance = gs.project(gs.zp0z().point(point_ix), (0, 0))
  if (opcode & 1) != 0 {
    let delta = abs32(distance - original_distance)
    if delta > gs.retained.control_value_cutin {
      distance = original_distance
    }
    distance = gs.round(distance)
  }
  gs.move_point(gs.zp0, point_ix, distance - original_distance)
  gs.rp0 = point_ix
  gs.rp1 = point_ix
}

///|
fn Interp::op_mdrp(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let p = self.value_stack.pop()
  if !gs.is_pedantic && !gs.in_bounds([(gs.zp1, p), (gs.zp0, gs.rp0)]) {
    gs.rp1 = gs.rp0
    gs.rp2 = p
    if (opcode & 16) != 0 {
      gs.rp0 = p
    }
    return
  }
  let mut original_distance = if gs.zp0.is_twilight() || gs.zp1.is_twilight() {
    gs.dual_project(gs.zp1z().original(p), gs.zp0z().original(gs.rp0))
  } else {
    let v1 = gs.zp1z().unscaled(p)
    let v2 = gs.zp0z().unscaled(gs.rp0)
    let dist = gs.dual_project(v1, v2)
    hmul(dist, gs.unscaled_to_pixels())
  }
  let cutin = gs.retained.single_width_cutin
  let value = gs.retained.single_width
  if cutin > 0 &&
    original_distance < value + cutin &&
    original_distance > value - cutin {
    original_distance = if original_distance >= 0 { value } else { -value }
  }
  let mut distance = if (opcode & 4) != 0 {
    gs.round(original_distance)
  } else {
    original_distance
  }
  if (opcode & 8) != 0 {
    let min_distance = gs.retained.min_distance
    if original_distance >= 0 {
      if distance < min_distance {
        distance = min_distance
      }
    } else if distance > -min_distance {
      distance = -min_distance
    }
  }
  original_distance = gs.project(gs.zp1z().point(p), gs.zp0z().point(gs.rp0))
  gs.move_point(gs.zp1, p, distance - original_distance)
  gs.rp1 = gs.rp0
  gs.rp2 = p
  if (opcode & 16) != 0 {
    gs.rp0 = p
  }
}

///|
fn Interp::op_mirp(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let n = self.value_stack.pop() + 1
  let p = self.value_stack.pop()
  if !gs.is_pedantic &&
    (
      !gs.in_bounds([(gs.zp1, p), (gs.zp0, gs.rp0)]) ||
      n < 0 ||
      n > self.cvt.len()
    ) {
    gs.rp1 = gs.rp0
    if (opcode & 16) != 0 {
      gs.rp0 = p
    }
    gs.rp2 = p
    return
  }
  let mut cvt_distance = if n == 0 { 0 } else { self.cvt.cvt_get(n - 1) }
  let cutin = gs.retained.single_width_cutin
  let value = gs.retained.single_width
  let mut delta = abs32(cvt_distance - value)
  if delta < cutin {
    cvt_distance = if cvt_distance >= 0 { value } else { -value }
  }
  if gs.zp1.is_twilight() {
    let d = cvt_distance
    let p2 = gs.zp0z().original(gs.rp0)
    let z1 = gs.zp1z()
    ignore(z1.original(p))
    let pt = (p2.0 + hmul(d, gs.freedom_x), p2.1 + hmul(d, gs.freedom_y))
    z1.set_original(p, pt)
    z1.set_point(p, pt)
  }
  let original_distance = gs.dual_project(
    gs.zp1z().original(p),
    gs.zp0z().original(gs.rp0),
  )
  let current_distance = gs.project(gs.zp1z().point(p), gs.zp0z().point(gs.rp0))
  if gs.retained.auto_flip && (original_distance ^ cvt_distance) < 0 {
    cvt_distance = -cvt_distance
  }
  let mut distance = if (opcode & 4) != 0 {
    if gs.zp0 == gs.zp1 {
      delta = abs32(cvt_distance - original_distance)
      if delta > gs.retained.control_value_cutin {
        cvt_distance = original_distance
      }
    }
    gs.round(cvt_distance)
  } else {
    cvt_distance
  }
  if (opcode & 8) != 0 {
    let min_distance = gs.retained.min_distance
    if original_distance >= 0 {
      if distance < min_distance {
        distance = min_distance
      }
    } else if distance > -min_distance {
      distance = -min_distance
    }
  }
  gs.move_point(gs.zp1, p, distance - current_distance)
  gs.rp1 = gs.rp0
  if (opcode & 16) != 0 {
    gs.rp0 = p
  }
  gs.rp2 = p
}

///|
fn Interp::op_alignrp(self : Interp) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let count = gs.loop_counter
  gs.loop_counter = 1
  for _ in 0..<count {
    let p = self.value_stack.pop()
    let distance = gs.project(gs.zp1z().point(p), gs.zp0z().point(gs.rp0))
    gs.move_point(gs.zp1, p, -distance)
  }
}

///|
fn Interp::op_isect(self : Interp) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let b1 = self.value_stack.pop()
  let b0 = self.value_stack.pop()
  let a1 = self.value_stack.pop()
  let a0 = self.value_stack.pop()
  let point_ix = self.value_stack.pop()
  let pa0 = gs.zp1z().point(a0)
  let pa1 = gs.zp1z().point(a1)
  let pb0 = gs.zp0z().point(b0)
  let pb1 = gs.zp0z().point(b1)
  let dbx = pb1.0 - pb0.0
  let dby = pb1.1 - pb0.1
  let dax = pa1.0 - pa0.0
  let day = pa1.1 - pa0.1
  let dx = pb0.0 - pa0.0
  let dy = pb0.1 - pa0.1
  let discriminant = hmul_div(dax, -dby, 0x40) + hmul_div(day, dbx, 0x40)
  let dotproduct = hmul_div(dax, dbx, 0x40) + hmul_div(day, dby, 0x40)
  if abs32(discriminant) * 19 > abs32(dotproduct) {
    let v = hmul_div(dx, -dby, 0x40) + hmul_div(dy, dbx, 0x40)
    let x = hmul_div(v, dax, discriminant)
    let y = hmul_div(v, day, discriminant)
    gs.zp2z().set_point(point_ix, (pa0.0 + x, pa0.1 + y))
  } else {
    gs
    .zp2z()
    .set_point(
      point_ix,
      ((pa0.0 + pa1.0 + pb0.0 + pb1.0) / 4, (pa0.1 + pa1.1 + pb0.1 + pb1.1) / 4),
    )
  }
  gs.zp2z().touch(point_ix, Both)
}

///|
fn Interp::op_alignpts(self : Interp) -> Unit raise HintErrorKind {
  let p2 = self.value_stack.pop()
  let p1 = self.value_stack.pop()
  let gs = self.graphics
  let distance = gs.project(gs.zp0z().point(p2), gs.zp1z().point(p1)) / 2
  gs.move_point(gs.zp1, p1, distance)
  gs.move_point(gs.zp0, p2, -distance)
}

///|
fn Interp::op_ip(self : Interp) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let count = gs.loop_counter
  gs.loop_counter = 1
  if !gs.is_pedantic && !gs.in_bounds([(gs.zp0, gs.rp1), (gs.zp1, gs.rp2)]) {
    return
  }
  let in_twilight = gs.zp0.is_twilight() ||
    gs.zp1.is_twilight() ||
    gs.zp2.is_twilight()
  let orus_base = if in_twilight {
    gs.zp0z().original(gs.rp1)
  } else {
    gs.zp0z().unscaled(gs.rp1)
  }
  let cur_base = gs.zp0z().point(gs.rp1)
  let old_range = if in_twilight {
    gs.dual_project(gs.zp1z().original(gs.rp2), orus_base)
  } else {
    gs.dual_project(gs.zp1z().unscaled(gs.rp2), orus_base)
  }
  let cur_range = gs.project(gs.zp1z().point(gs.rp2), cur_base)
  for _ in 0..<count {
    let point = self.value_stack.pop()
    if !gs.is_pedantic && !gs.in_bounds([(gs.zp2, point)]) {
      continue
    }
    let original_distance = if in_twilight {
      gs.dual_project(gs.zp2z().original(point), orus_base)
    } else {
      gs.dual_project(gs.zp2z().unscaled(point), orus_base)
    }
    let cur_distance = gs.project(gs.zp2z().point(point), cur_base)
    let new_distance = if original_distance != 0 {
      if old_range != 0 {
        hmul_div(original_distance, cur_range, old_range)
      } else {
        original_distance
      }
    } else {
      0
    }
    gs.move_point(gs.zp2, point, new_distance - cur_distance)
  }
}

///|
fn Interp::op_iup(self : Interp, opcode : Int) -> Unit raise HintErrorKind {
  let gs = self.graphics
  let axis = if (opcode & 1) != 0 { X } else { Y }
  let mut run = true
  if gs.backward_compatibility {
    if gs.did_iup_x && gs.did_iup_y {
      run = false
    }
    if axis == X {
      gs.did_iup_x = true
    } else {
      gs.did_iup_y = true
    }
  }
  if run {
    gs.zone(ZonePointer(1)).iup(axis)
  }
}

///|
fn Interp::op_utp(self : Interp) -> Unit raise HintErrorKind {
  let p = self.value_stack.pop()
  let gs = self.graphics
  let coord_axis = match (gs.freedom_x != 0, gs.freedom_y != 0) {
    (true, true) => Some(CoordAxis::Both)
    (true, false) => Some(X)
    (false, true) => Some(Y)
    (false, false) => None
  }
  if coord_axis is Some(axis) {
    gs.zp0z().untouch(p, axis)
  }
}
