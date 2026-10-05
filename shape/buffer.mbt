// Port of rustybuzz 0.20.1 `src/hb/buffer.rs`.
//
// `GlyphInfo`/`GlyphPosition` are `Copy` in Rust. Here they are mutable
// objects: the arrays of a buffer never share objects, and every
// whole-element assignment between slots copies (`assign`/`copy`).
//
// Rust keeps the separate output buffer in the memory of `pos` (via
// `bytemuck`); here it is the separate array `out_sep`, resized together
// with `info` and `pos` and swapped with `info` on `sync`. Physical array
// lengths follow the Rust `Vec` lengths, since some loops (e.g. in
// `ensure_native_direction`) iterate over the whole vector.

///|
const CONTEXT_LENGTH : Int = 5

// glyph_flag

///|
/// Indicates that if input text is broken at the beginning of the cluster
/// this glyph is part of, then both sides need to be re-shaped, as the
/// result might be different.
pub const UNSAFE_TO_BREAK : UInt = 0x00000001

///|
/// Indicates that if input text is changed on one side of the beginning of
/// the cluster this glyph is part of, then the shaping results for the other
/// side might change. The UNSAFE_TO_BREAK flag will always imply this flag.
pub const UNSAFE_TO_CONCAT : UInt = 0x00000002

///|
/// In scripts that use elongation (Arabic, Mongolian, Syriac, etc.), this
/// flag signifies that it is safe to insert a U+0640 TATWEEL character
/// *before* this cluster for elongation.
pub const SAFE_TO_INSERT_TATWEEL : UInt = 0x00000004

///|
/// All the currently defined flags.
pub const GLYPH_FLAG_DEFINED : UInt = 0x00000007

// BufferFlags

///|
/// Indicates that special handling of the beginning of text paragraph can be
/// applied to this buffer.
pub const BUFFER_FLAG_BEGINNING_OF_TEXT : UInt = 0x00000001

///|
/// Indicates that special handling of the end of text paragraph can be
/// applied to this buffer.
pub const BUFFER_FLAG_END_OF_TEXT : UInt = 0x00000002

///|
/// Use the glyphs of `Default_Ignorable` characters instead of hiding them.
pub const BUFFER_FLAG_PRESERVE_DEFAULT_IGNORABLES : UInt = 0x00000004

///|
/// Remove `Default_Ignorable` characters instead of hiding them.
pub const BUFFER_FLAG_REMOVE_DEFAULT_IGNORABLES : UInt = 0x00000008

///|
/// Do not insert a dotted circle for incorrect character sequences.
pub const BUFFER_FLAG_DO_NOT_INSERT_DOTTED_CIRCLE : UInt = 0x00000010

///|
/// Verify the shaping results (unused).
pub const BUFFER_FLAG_VERIFY : UInt = 0x00000020

///|
/// Produce the `UNSAFE_TO_CONCAT` glyph flag.
pub const BUFFER_FLAG_PRODUCE_UNSAFE_TO_CONCAT : UInt = 0x00000040

///|
/// Produce the `SAFE_TO_INSERT_TATWEEL` glyph flag (same bit as
/// `PRODUCE_UNSAFE_TO_CONCAT` in rustybuzz 0.20.1).
pub const BUFFER_FLAG_PRODUCE_SAFE_TO_INSERT_TATWEEL : UInt = 0x00000040

///|
/// All currently defined flags.
pub const BUFFER_FLAG_DEFINED : UInt = 0x000000FF

// Cluster levels.

///|
pub const HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES : Int = 0

///|
pub const HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS : Int = 1

///|
pub const HB_BUFFER_CLUSTER_LEVEL_CHARACTERS : Int = 2

///|
pub const HB_BUFFER_CLUSTER_LEVEL_DEFAULT : Int = 0

// UnicodeProps

///|
const UPROPS_MASK_GEN_CAT : Int = 0x001F

///|
const UPROPS_MASK_IGNORABLE : Int = 0x0020

///|
/// MONGOLIAN FREE VARIATION SELECTOR 1..4, or TAG characters, or CGJ sometimes
const UPROPS_MASK_HIDDEN : Int = 0x0040

///|
const UPROPS_MASK_CONTINUATION : Int = 0x0080

///|
/// If GEN_CAT=FORMAT, top byte masks:
const UPROPS_MASK_CF_ZWJ : Int = 0x0100

///|
const UPROPS_MASK_CF_ZWNJ : Int = 0x0200

///|
const UPROPS_MASK_CF_VS : Int = 0x0400

// GlyphPropsFlags

///|
/// The following three match LookupFlags::Ignore* numbers.
const GLYPH_PROPS_BASE_GLYPH : Int = 0x02

///|
const GLYPH_PROPS_LIGATURE : Int = 0x04

///|
const GLYPH_PROPS_MARK : Int = 0x08

///|
const GLYPH_PROPS_CLASS_MASK : Int = 0x0E

///|
/// The following are used internally; not derived from GDEF.
const GLYPH_PROPS_SUBSTITUTED : Int = 0x10

///|
const GLYPH_PROPS_LIGATED : Int = 0x20

///|
const GLYPH_PROPS_MULTIPLIED : Int = 0x40

///|
const GLYPH_PROPS_PRESERVE : Int = 0x70

// Scratch flags.

///|
const HB_BUFFER_SCRATCH_FLAG_DEFAULT : UInt = 0x00000000

///|
const HB_BUFFER_SCRATCH_FLAG_HAS_NON_ASCII : UInt = 0x00000001

///|
const HB_BUFFER_SCRATCH_FLAG_HAS_DEFAULT_IGNORABLES : UInt = 0x00000002

///|
const HB_BUFFER_SCRATCH_FLAG_HAS_SPACE_FALLBACK : UInt = 0x00000004

///|
const HB_BUFFER_SCRATCH_FLAG_HAS_GPOS_ATTACHMENT : UInt = 0x00000008

///|
const HB_BUFFER_SCRATCH_FLAG_HAS_CGJ : UInt = 0x00000010

///|
const HB_BUFFER_SCRATCH_FLAG_HAS_GLYPH_FLAGS : UInt = 0x00000020

///|
const HB_BUFFER_SCRATCH_FLAG_HAS_BROKEN_SYLLABLE : UInt = 0x00000040

///|
const HB_BUFFER_SCRATCH_FLAG_HAS_VARIATION_SELECTOR_FALLBACK : UInt = 0x00000080

///|
/// Reserved for shapers' internal use.
const HB_BUFFER_SCRATCH_FLAG_SHAPER0 : UInt = 0x01000000

///|
/// Holds the positions of the glyph in both horizontal and vertical
/// directions. All positions are relative to the current point.
pub(all) struct GlyphPosition {
  /// How much the line advances after drawing this glyph when setting text
  /// in horizontal direction.
  mut x_advance : Int
  /// How much the line advances after drawing this glyph when setting text
  /// in vertical direction.
  mut y_advance : Int
  /// How much the glyph moves on the X-axis before drawing it, this should
  /// not affect how much the line advances.
  mut x_offset : Int
  /// How much the glyph moves on the Y-axis before drawing it, this should
  /// not affect how much the line advances.
  mut y_offset : Int
  mut var_ : UInt
} derive(Debug)

///|
fn GlyphPosition::new() -> GlyphPosition {
  { x_advance: 0, y_advance: 0, x_offset: 0, y_offset: 0, var_: 0, }
}

///|
/// `self.assign(GlyphPosition::new())` without allocating the temporary.
fn GlyphPosition::reset(self : GlyphPosition) -> Unit {
  self.x_advance = 0
  self.y_advance = 0
  self.x_offset = 0
  self.y_offset = 0
  self.var_ = 0
}

///|
fn GlyphPosition::copy(self : GlyphPosition) -> GlyphPosition {
  { ..self, }
}

///|
fn GlyphPosition::assign(self : GlyphPosition, o : GlyphPosition) -> Unit {
  self.x_advance = o.x_advance
  self.y_advance = o.y_advance
  self.x_offset = o.x_offset
  self.y_offset = o.y_offset
  self.var_ = o.var_
}

///|
/// Glyph to which this attaches to, relative to current glyphs; negative
/// for going back, positive for forward.
fn GlyphPosition::attach_chain(self : GlyphPosition) -> Int {
  // var as [i16; 2], element 0.
  let v = (self.var_ & 0xFFFF).reinterpret_as_int()
  if v >= 0x8000 {
    v - 0x10000
  } else {
    v
  }
}

///|
fn GlyphPosition::set_attach_chain(self : GlyphPosition, n : Int) -> Unit {
  self.var_ = (self.var_ & 0xFFFF0000) | (n.reinterpret_as_uint() & 0xFFFF)
}

///|
/// Attachment type. Note! if attach_chain() is zero, the value of
/// attach_type() is irrelevant.
fn GlyphPosition::attach_type(self : GlyphPosition) -> Int {
  // var as [u8; 4], element 2.
  ((self.var_ >> 16) & 0xFF).reinterpret_as_int()
}

///|
fn GlyphPosition::set_attach_type(self : GlyphPosition, n : Int) -> Unit {
  self.var_ = (self.var_ & 0xFF00FFFF) |
    ((n.reinterpret_as_uint() & 0xFF) << 16)
}

///|
/// A glyph info.
///
/// `glyph_id` stores a Unicode codepoint before shaping and a glyph ID
/// after. Just like harfbuzz, the same variable is used for two purposes.
pub(all) struct GlyphInfo {
  /// A selected glyph (guaranteed to be <= `u16::MAX` after shaping).
  mut glyph_id : UInt
  mut mask : UInt
  /// An index to the start of the grapheme cluster in the original string.
  mut cluster : UInt
  mut var1 : UInt
  mut var2 : UInt
} derive(Debug)

///|
fn GlyphInfo::new() -> GlyphInfo {
  { glyph_id: 0, mask: 0, cluster: 0, var1: 0, var2: 0, }
}

///|
/// `self.assign(GlyphInfo::new())` without allocating the temporary.
fn GlyphInfo::reset(self : GlyphInfo) -> Unit {
  self.glyph_id = 0
  self.mask = 0
  self.cluster = 0
  self.var1 = 0
  self.var2 = 0
}

///|
fn GlyphInfo::copy(self : GlyphInfo) -> GlyphInfo {
  { ..self, }
}

///|
fn GlyphInfo::assign(self : GlyphInfo, o : GlyphInfo) -> Unit {
  self.glyph_id = o.glyph_id
  self.mask = o.mask
  self.cluster = o.cluster
  self.var1 = o.var1
  self.var2 = o.var2
}

///|
/// Indicates that if input text is broken at the beginning of the cluster
/// this glyph is part of, then both sides need to be re-shaped, as the
/// result might be different.
pub fn GlyphInfo::unsafe_to_break(self : GlyphInfo) -> Bool {
  (self.mask & UNSAFE_TO_BREAK) != 0
}

///|
/// The codepoint (before shaping).
fn GlyphInfo::as_char(self : GlyphInfo) -> Int {
  self.glyph_id.reinterpret_as_int()
}

///|
fn GlyphInfo::as_glyph(self : GlyphInfo) -> @otf.GlyphId {
  @otf.GlyphId((self.glyph_id & 0xFFFF).to_uint16())
}

// Var allocation: unicode_props
// Used during the entire shaping process to store unicode properties

///|
fn GlyphInfo::unicode_props(self : GlyphInfo) -> Int {
  (self.var2 & 0xFFFF).reinterpret_as_int()
}

///|
fn GlyphInfo::set_unicode_props(self : GlyphInfo, n : Int) -> Unit {
  self.var2 = (self.var2 & 0xFFFF0000) | (n.reinterpret_as_uint() & 0xFFFF)
}

///|
fn GlyphInfo::init_unicode_props(self : GlyphInfo, buffer : Buffer) -> Unit {
  let u = self.as_char()
  let gc = char_general_category(u)
  let mut props = gc
  if u >= 0x80 {
    buffer.scratch_flags = buffer.scratch_flags |
      HB_BUFFER_SCRATCH_FLAG_HAS_NON_ASCII
    if char_is_default_ignorable(u) {
      props = props | UPROPS_MASK_IGNORABLE
      buffer.scratch_flags = buffer.scratch_flags |
        HB_BUFFER_SCRATCH_FLAG_HAS_DEFAULT_IGNORABLES
      match u {
        0x200C => props = props | UPROPS_MASK_CF_ZWNJ
        0x200D => props = props | UPROPS_MASK_CF_ZWJ

        // Mongolian Free Variation Selectors need to be remembered
        // because although we need to hide them like default-ignorables,
        // they need to non-ignorable during shaping.  This is similar to
        // what we do for joiners in Indic-like shapers, but since the
        // FVSes are GC=Mn, we have use a separate bit to remember them.
        // Fixes:
        // https://github.com/harfbuzz/harfbuzz/issues/234
        0x180B..=0x180D | 0x180F => props = props | UPROPS_MASK_HIDDEN

        // TAG characters need similar treatment. Fixes:
        // https://github.com/harfbuzz/harfbuzz/issues/463
        0xE0020..=0xE007F => props = props | UPROPS_MASK_HIDDEN

        // COMBINING GRAPHEME JOINER should not be skipped during GSUB either.
        // https://github.com/harfbuzz/harfbuzz/issues/554
        0x034F => {
          props = props | UPROPS_MASK_HIDDEN
          buffer.scratch_flags = buffer.scratch_flags |
            HB_BUFFER_SCRATCH_FLAG_HAS_CGJ
        }
        _ => ()
      }
    }
    if gc_is_mark(gc) {
      props = props | UPROPS_MASK_CONTINUATION
      props = props | (char_modified_combining_class(u) << 8)
    }
  }
  self.set_unicode_props(props)
}

///|
fn GlyphInfo::unhide(self : GlyphInfo) -> Unit {
  let n = self.unicode_props()
  self.set_unicode_props(n & UPROPS_MASK_HIDDEN.lnot())
}

///|
fn GlyphInfo::lig_props(self : GlyphInfo) -> Int {
  // var1 as [u8; 4], element 2.
  ((self.var1 >> 16) & 0xFF).reinterpret_as_int()
}

///|
fn GlyphInfo::set_lig_props(self : GlyphInfo, n : Int) -> Unit {
  self.var1 = (self.var1 & 0xFF00FFFF) |
    ((n.reinterpret_as_uint() & 0xFF) << 16)
}

///|
fn GlyphInfo::glyph_props(self : GlyphInfo) -> Int {
  // var1 as [u16; 2], element 0.
  (self.var1 & 0xFFFF).reinterpret_as_int()
}

///|
fn GlyphInfo::set_glyph_props(self : GlyphInfo, n : Int) -> Unit {
  self.var1 = (self.var1 & 0xFFFF0000) | (n.reinterpret_as_uint() & 0xFFFF)
}

///|
fn GlyphInfo::syllable(self : GlyphInfo) -> Int {
  // var1 as [u8; 4], element 3.
  ((self.var1 >> 24) & 0xFF).reinterpret_as_int()
}

///|
fn GlyphInfo::set_syllable(self : GlyphInfo, n : Int) -> Unit {
  self.var1 = (self.var1 & 0x00FFFFFF) |
    ((n.reinterpret_as_uint() & 0xFF) << 24)
}

// Var allocation: glyph_index
// Used during the normalization process to store glyph indices

///|
fn GlyphInfo::glyph_index(self : GlyphInfo) -> UInt {
  self.var1
}

///|
fn GlyphInfo::set_glyph_index(self : GlyphInfo, n : UInt) -> Unit {
  self.var1 = n
}

///|
/// Resize a vector like Rust's `Vec::resize` with default objects.
///
/// Truncated objects are kept in `spare` and reset when the vector grows
/// again (performance: `push_str` reserves all slots, then every `add`
/// truncates to `len + 1` and grows by one, like upstream's `ensure`).
fn resize_infos(
  v : Array[GlyphInfo],
  size : Int,
  spare : Array[GlyphInfo],
) -> Unit {
  if size < v.length() {
    while v.length() > size {
      spare.push(v.unsafe_pop())
    }
  } else {
    if size > v.capacity() {
      let doubled = 2 * v.capacity()
      v.reserve_capacity(if size > doubled { size } else { doubled })
    }
    while v.length() < size {
      match spare.pop() {
        Some(info) => {
          info.reset()
          v.push(info)
        }
        None => v.push(GlyphInfo::new())
      }
    }
  }
}

///|
/// [resize_infos] for positions.
fn resize_positions(
  v : Array[GlyphPosition],
  size : Int,
  spare : Array[GlyphPosition],
) -> Unit {
  if size < v.length() {
    while v.length() > size {
      spare.push(v.unsafe_pop())
    }
  } else {
    if size > v.capacity() {
      let doubled = 2 * v.capacity()
      v.reserve_capacity(if size > doubled { size } else { doubled })
    }
    while v.length() < size {
      match spare.pop() {
        Some(pos) => {
          pos.reset()
          v.push(pos)
        }
        None => v.push(GlyphPosition::new())
      }
    }
  }
}

///|
/// The shaping buffer (`hb_buffer_t`).
struct Buffer {
  // Information about how the text in the buffer should be treated.
  mut flags : UInt
  mut cluster_level : Int
  mut invisible : @otf.GlyphId?
  mut not_found_variation_selector : UInt?

  // Buffer contents.
  mut direction : Direction
  mut script : Script?
  mut language : Language?
  /// Shaping failure
  mut shaping_failed : Bool
  /// Allocations successful.
  mut successful : Bool
  /// Whether we have an output buffer going on.
  mut have_output : Bool
  mut have_separate_output : Bool
  /// Whether we have positions
  mut have_positions : Bool
  mut idx : Int
  mut len : Int
  mut out_len : Int
  mut info : Array[GlyphInfo]
  mut pos : Array[GlyphPosition]
  /// The separate output buffer (lives in `pos` in Rust).
  mut out_sep : Array[GlyphInfo]
  /// Truncated slots for reuse (see [resize_infos]).
  spare_infos : Array[GlyphInfo]
  spare_positions : Array[GlyphPosition]

  // Text before / after the main buffer contents.
  // Always in Unicode, and ordered outward.
  // Index 0 is for "pre-context", 1 for "post-context".
  context : Array[Array[Int]]
  context_len : Array[Int]

  // Managed by enter / leave
  mut serial : Int
  mut scratch_flags : UInt
  /// Maximum allowed len.
  mut max_len : Int
  /// Maximum allowed operations.
  mut max_ops : Int
}

///|
const MAX_LEN_FACTOR : Int = 64

///|
const MAX_LEN_MIN : Int = 16384

///|
/// Shaping more than a billion chars? Let us know!
const MAX_LEN_DEFAULT : Int = 0x3FFFFFFF

///|
const MAX_OPS_FACTOR : Int = 1024

///|
const MAX_OPS_MIN : Int = 16384

///|
/// Shaping more than a billion operations? Let us know!
const MAX_OPS_DEFAULT : Int = 0x1FFFFFFF

///|
/// Creates a new `Buffer`.
fn Buffer::new() -> Buffer {
  {
    flags: 0,
    cluster_level: HB_BUFFER_CLUSTER_LEVEL_DEFAULT,
    invisible: None,
    scratch_flags: HB_BUFFER_SCRATCH_FLAG_DEFAULT,
    not_found_variation_selector: None,
    max_len: MAX_LEN_DEFAULT,
    max_ops: MAX_OPS_DEFAULT,
    direction: Invalid,
    script: None,
    language: None,
    shaping_failed: false,
    successful: true,
    have_output: false,
    have_positions: false,
    idx: 0,
    len: 0,
    out_len: 0,
    info: [],
    pos: [],
    out_sep: [],
    spare_infos: [],
    spare_positions: [],
    have_separate_output: false,
    serial: 0,
    context: [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0]],
    context_len: [0, 0],
  }
}

///|
/// Reset to the state of [Buffer::new], keeping the glyph slots in the spare
/// pools (see [GlyphBuffer::recycle]).
fn Buffer::reset(self : Buffer) -> Unit {
  self.flags = 0
  self.cluster_level = HB_BUFFER_CLUSTER_LEVEL_DEFAULT
  self.invisible = None
  self.scratch_flags = HB_BUFFER_SCRATCH_FLAG_DEFAULT
  self.not_found_variation_selector = None
  self.max_len = MAX_LEN_DEFAULT
  self.max_ops = MAX_OPS_DEFAULT
  self.direction = Invalid
  self.script = None
  self.language = None
  self.shaping_failed = false
  self.successful = true
  self.have_output = false
  self.have_positions = false
  self.idx = 0
  self.len = 0
  self.out_len = 0
  while self.info.pop() is Some(info) {
    self.spare_infos.push(info)
  }
  while self.out_sep.pop() is Some(info) {
    self.spare_infos.push(info)
  }
  while self.pos.pop() is Some(pos) {
    self.spare_positions.push(pos)
  }
  self.have_separate_output = false
  self.serial = 0
  for side in 0..<2 {
    for i in 0..<CONTEXT_LENGTH {
      self.context[side][i] = 0
    }
    self.context_len[side] = 0
  }
}

///|
/// The output infos (the separate output buffer, or `info`).
fn Buffer::out_info(self : Buffer) -> Array[GlyphInfo] {
  if self.have_separate_output {
    self.out_sep
  } else {
    self.info
  }
}

///|
fn Buffer::set_out_info(self : Buffer, i : Int, info : GlyphInfo) -> Unit {
  self.out_info()[i].assign(info)
}

///|
fn Buffer::cur(self : Buffer, i : Int) -> GlyphInfo {
  self.info[self.idx + i]
}

///|
fn Buffer::cur_pos(self : Buffer) -> GlyphPosition {
  self.pos[self.idx]
}

///|
fn Buffer::prev(self : Buffer) -> GlyphInfo {
  let idx = if self.out_len > 0 { self.out_len - 1 } else { 0 }
  self.out_info()[idx]
}

///|
fn Buffer::digest(self : Buffer) -> SetDigest {
  let digest = SetDigest::new()
  for info in self.info {
    digest.add(info.glyph_id.reinterpret_as_int() & 0xFFFF)
  }
  digest
}

///|
fn Buffer::clear(self : Buffer) -> Unit {
  self.direction = Invalid
  self.script = None
  self.language = None
  self.successful = true
  self.have_output = false
  self.have_positions = false
  self.idx = 0
  self.info.clear()
  self.pos.clear()
  self.out_sep.clear()
  self.len = 0
  self.out_len = 0
  self.have_separate_output = false
  for side in 0..<2 {
    for i in 0..<CONTEXT_LENGTH {
      self.context[side][i] = 0
    }
    self.context_len[side] = 0
  }
  self.serial = 0
  self.scratch_flags = HB_BUFFER_SCRATCH_FLAG_DEFAULT
  self.cluster_level = HB_BUFFER_CLUSTER_LEVEL_DEFAULT
  self.not_found_variation_selector = None
}

///|
fn Buffer::backtrack_len(self : Buffer) -> Int {
  if self.have_output {
    self.out_len
  } else {
    self.idx
  }
}

///|
fn Buffer::lookahead_len(self : Buffer) -> Int {
  self.len - self.idx
}

///|
fn Buffer::next_serial(self : Buffer) -> Int {
  // A `serial` overflow/wrap-around here is perfectly fine.
  self.serial = (self.serial + 1) & 0xFF
  if self.serial == 0 {
    self.serial += 1
  }
  self.serial
}

///|
fn Buffer::add(self : Buffer, codepoint : UInt, cluster : UInt) -> Unit {
  if !self.ensure(self.len + 1) {
    return
  }
  let i = self.len
  // `assign` of a fresh `GlyphInfo`, without allocating it.
  let info = self.info[i]
  info.glyph_id = codepoint
  info.mask = 0
  info.cluster = cluster
  info.var1 = 0
  info.var2 = 0
  self.len += 1
}

///|
fn Buffer::reverse(self : Buffer) -> Unit {
  if self.is_empty() {
    return
  }
  self.reverse_range(0, self.len)
}

///|
fn Buffer::reverse_range(self : Buffer, start : Int, end : Int) -> Unit {
  if end - start < 2 {
    return
  }
  reverse_slice(self.info, start, end)
  if self.have_positions {
    reverse_slice(self.pos, start, end)
  }
}

///|
fn[T] reverse_slice(v : Array[T], start : Int, end : Int) -> Unit {
  let mut i = start
  let mut j = end - 1
  while i < j {
    v.swap(i, j)
    i += 1
    j -= 1
  }
}

///|
fn Buffer::reverse_groups(
  self : Buffer,
  group : (GlyphInfo, GlyphInfo) -> Bool,
  merge_clusters : Bool,
) -> Unit {
  if self.is_empty() {
    return
  }
  let mut start = 0
  let mut i = 1
  while i < self.len {
    if !group(self.info[i - 1], self.info[i]) {
      if merge_clusters {
        self.merge_clusters(start, i)
      }
      self.reverse_range(start, i)
      start = i
    }
    i += 1
  }
  if merge_clusters {
    self.merge_clusters(start, i)
  }
  self.reverse_range(start, i)
  self.reverse()
}

///|
fn Buffer::group_end(
  self : Buffer,
  start : Int,
  group : (GlyphInfo, GlyphInfo) -> Bool,
) -> Int {
  let mut start = start + 1
  while start < self.len && group(self.info[start - 1], self.info[start]) {
    start += 1
  }
  start
}

///|
fn Buffer::reset_clusters(self : Buffer) -> Unit {
  for i, info in self.info {
    info.cluster = i.reinterpret_as_uint()
  }
}

///|
fn Buffer::guess_segment_properties(self : Buffer) -> Unit {
  if self.script is None {
    for info in self.info {
      let s = char_script(info.as_char())
      if s == script_common || s == script_inherited || s == script_unknown {
        continue
      }
      self.script = Some(s)
      break
    }
  }
  if self.direction == Invalid {
    if self.script is Some(script) {
      self.direction = Direction::from_script(script).unwrap_or(Invalid)
    }
    if self.direction == Invalid {
      self.direction = LeftToRight
    }
  }

  // TODO: language must be set
}

///|
fn Buffer::sync(self : Buffer) -> Bool {
  guard! self.have_output
  guard! self.idx <= self.len
  if !self.successful {
    self.have_output = false
    self.out_len = 0
    self.idx = 0
    return false
  }
  self.next_glyphs(self.len - self.idx)
  if self.have_separate_output {
    // Swap info and pos buffers.
    let info = self.info
    self.info = self.out_sep
    self.out_sep = info
    self.have_separate_output = false
  }
  self.len = self.out_len
  self.have_output = false
  self.out_len = 0
  self.idx = 0
  true
}

///|
fn Buffer::clear_output(self : Buffer) -> Unit {
  self.have_output = true
  self.have_positions = false
  self.idx = 0
  self.out_len = 0
  self.have_separate_output = false
}

///|
fn Buffer::clear_positions(self : Buffer) -> Unit {
  self.have_output = false
  self.have_positions = true
  self.out_len = 0
  self.have_separate_output = false
  for pos in self.pos {
    pos.reset()
  }
}

///|
fn Buffer::replace_glyphs(
  self : Buffer,
  num_in : Int,
  num_out : Int,
  glyph_data : Array[UInt],
) -> Unit {
  if !self.make_room_for(num_in, num_out) {
    return
  }
  guard! self.idx + num_in <= self.len
  self.merge_clusters(self.idx, self.idx + num_in)
  let orig_info = self.info[self.idx].copy()
  for i in 0..<num_out {
    let ii = self.out_len + i
    self.set_out_info(ii, orig_info)
    self.out_info()[ii].glyph_id = glyph_data[i]
  }
  self.idx += num_in
  self.out_len += num_out
}

///|
fn Buffer::replace_glyph(self : Buffer, glyph_index : UInt) -> Unit {
  if self.have_separate_output || self.out_len != self.idx {
    if !self.make_room_for(1, 1) {
      return
    }
    self.set_out_info(self.out_len, self.info[self.idx])
  }
  let out_len = self.out_len
  self.out_info()[out_len].glyph_id = glyph_index
  self.idx += 1
  self.out_len += 1
}

///|
fn Buffer::output_glyph(self : Buffer, glyph_index : UInt) -> Unit {
  if !self.make_room_for(0, 1) {
    return
  }
  if self.idx == self.len && self.out_len == 0 {
    return
  }
  let out_len = self.out_len
  if self.idx < self.len {
    self.set_out_info(out_len, self.info[self.idx])
  } else {
    let info = self.out_info()[out_len - 1].copy()
    self.set_out_info(out_len, info)
  }
  self.out_info()[out_len].glyph_id = glyph_index
  self.out_len += 1
}

///|
fn Buffer::output_info(self : Buffer, glyph_info : GlyphInfo) -> Unit {
  if !self.make_room_for(0, 1) {
    return
  }
  self.set_out_info(self.out_len, glyph_info)
  self.out_len += 1
}

///|
/// Copies glyph at idx to output but doesn't advance idx.
fn Buffer::copy_glyph(self : Buffer) -> Unit {
  if !self.make_room_for(0, 1) {
    return
  }
  self.set_out_info(self.out_len, self.info[self.idx])
  self.out_len += 1
}

///|
/// Copies glyph at idx to output and advance idx.
///
/// If there's no output, just advance idx.
fn Buffer::next_glyph(self : Buffer) -> Unit {
  if self.have_output {
    if self.have_separate_output || self.out_len != self.idx {
      if !self.make_room_for(1, 1) {
        return
      }
      self.set_out_info(self.out_len, self.info[self.idx])
    }
    self.out_len += 1
  }
  self.idx += 1
}

///|
/// Copies n glyphs at idx to output and advance idx.
///
/// If there's no output, just advance idx.
fn Buffer::next_glyphs(self : Buffer, n : Int) -> Unit {
  if self.have_output {
    if self.have_separate_output || self.out_len != self.idx {
      if !self.make_room_for(n, n) {
        return
      }
      for i in 0..<n {
        self.set_out_info(self.out_len + i, self.info[self.idx + i])
      }
    }
    self.out_len += n
  }
  self.idx += n
}

///|
/// Advance idx without copying to output.
fn Buffer::skip_glyph(self : Buffer) -> Unit {
  self.idx += 1
}

///|
fn Buffer::reset_masks(self : Buffer, mask : UInt) -> Unit {
  for i in 0..<self.len {
    self.info[i].mask = mask
  }
}

///|
fn Buffer::set_masks(
  self : Buffer,
  value : UInt,
  mask : UInt,
  cluster_start : UInt,
  cluster_end : UInt,
) -> Unit {
  if mask == 0 {
    return
  }
  let not_mask = mask ^ 0xFFFFFFFF
  let value = value & mask
  if cluster_start == 0 && cluster_end == 0xFFFFFFFF {
    for i in 0..<self.len {
      let info = self.info[i]
      info.mask = (info.mask & not_mask) | value
    }
    return
  }
  for i in 0..<self.len {
    let info = self.info[i]
    if cluster_start <= info.cluster && info.cluster < cluster_end {
      info.mask = (info.mask & not_mask) | value
    }
  }
}

///|
fn Buffer::merge_clusters(self : Buffer, start : Int, end : Int) -> Unit {
  if end - start < 2 {
    return
  }
  self.merge_clusters_impl(start, end)
}

///|
fn imin(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn imax(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn umin(a : UInt, b : UInt) -> UInt {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn Buffer::merge_clusters_impl(self : Buffer, start : Int, end : Int) -> Unit {
  let mut start = start
  let mut end = end
  if self.cluster_level == HB_BUFFER_CLUSTER_LEVEL_CHARACTERS {
    self.unsafe_to_break(Some(start), Some(end))
    return
  }
  let mut cluster = self.info[start].cluster
  for i in (start + 1)..<end {
    cluster = umin(cluster, self.info[i].cluster)
  }

  // Extend end
  if cluster != self.info[end - 1].cluster {
    while end < self.len && self.info[end - 1].cluster == self.info[end].cluster {
      end += 1
    }
  }

  // Extend start
  if cluster != self.info[start].cluster {
    while end < start &&
          self.info[start - 1].cluster == self.info[start].cluster {
      start -= 1
    }
  }

  // If we hit the start of buffer, continue in out-buffer.
  if self.idx == start && self.info[start].cluster != cluster {
    let mut i = self.out_len
    while i != 0 && self.out_info()[i - 1].cluster == self.info[start].cluster {
      set_cluster(self.out_info()[i - 1], cluster, 0)
      i -= 1
    }
  }
  for i in start..<end {
    set_cluster(self.info[i], cluster, 0)
  }
}

///|
fn Buffer::merge_out_clusters(self : Buffer, start : Int, end : Int) -> Unit {
  let mut start = start
  let mut end = end
  if self.cluster_level == HB_BUFFER_CLUSTER_LEVEL_CHARACTERS {
    return
  }
  if end - start < 2 {
    return
  }
  let out = self.out_info()
  let mut cluster = out[start].cluster
  for i in (start + 1)..<end {
    cluster = umin(cluster, out[i].cluster)
  }

  // Extend start
  while start != 0 && out[start - 1].cluster == out[start].cluster {
    start -= 1
  }

  // Extend end
  while end < self.out_len && out[end - 1].cluster == out[end].cluster {
    end += 1
  }

  // If we hit the start of buffer, continue in out-buffer.
  if end == self.out_len {
    let mut i = self.idx
    while i < self.len && self.info[i].cluster == out[end - 1].cluster {
      set_cluster(self.info[i], cluster, 0)
      i += 1
    }
  }
  for i in start..<end {
    set_cluster(out[i], cluster, 0)
  }
}

///|
/// Merge clusters for deleting current glyph, and skip it.
fn Buffer::delete_glyph(self : Buffer) -> Unit {
  let cluster = self.info[self.idx].cluster
  if (self.idx + 1 < self.len && cluster == self.info[self.idx + 1].cluster) ||
    (self.out_len != 0 && cluster == self.out_info()[self.out_len - 1].cluster) {
    // Cluster survives; do nothing.
    self.skip_glyph()
    return
  }
  if self.out_len != 0 {
    // Merge cluster backward.
    if cluster < self.out_info()[self.out_len - 1].cluster {
      let mask = self.info[self.idx].mask
      let old_cluster = self.out_info()[self.out_len - 1].cluster
      let mut i = self.out_len
      while i != 0 && self.out_info()[i - 1].cluster == old_cluster {
        set_cluster(self.out_info()[i - 1], cluster, mask)
        i -= 1
      }
    }
    self.skip_glyph()
    return
  }
  if self.idx + 1 < self.len {
    // Merge cluster forward.
    self.merge_clusters(self.idx, self.idx + 2)
  }
  self.skip_glyph()
}

///|
fn Buffer::delete_glyphs_inplace(
  self : Buffer,
  filter : (GlyphInfo) -> Bool,
) -> Unit {
  // Merge clusters and delete filtered glyphs.
  // NOTE! We can't use out-buffer as we have positioning data.
  let mut j = 0
  for i in 0..<self.len {
    if filter(self.info[i]) {
      // Merge clusters.
      // Same logic as delete_glyph(), but for in-place removal

      let cluster = self.info[i].cluster
      if i + 1 < self.len && cluster == self.info[i + 1].cluster {
        // Cluster survives; do nothing.
        continue
      }
      if j != 0 {
        // Merge cluster backward.
        if cluster < self.info[j - 1].cluster {
          let mask = self.info[i].mask
          let old_cluster = self.info[j - 1].cluster
          let mut k = j
          while k > 0 && self.info[k - 1].cluster == old_cluster {
            set_cluster(self.info[k - 1], cluster, mask)
            k -= 1
          }
        }
        continue
      }
      if i + 1 < self.len {
        // Merge cluster forward.
        self.merge_clusters(i, i + 2)
      }
      continue
    }
    if j != i {
      self.info[j].assign(self.info[i])
      self.pos[j].assign(self.pos[i])
    }
    j += 1
  }
  self.len = j
}

///|
fn Buffer::unsafe_to_break(self : Buffer, start : Int?, end : Int?) -> Unit {
  self._set_glyph_flags(
    UNSAFE_TO_BREAK | UNSAFE_TO_CONCAT,
    start,
    end,
    Some(true),
    None,
  )
}

///|
fn Buffer::safe_to_insert_tatweel(
  self : Buffer,
  start : Int?,
  end : Int?,
) -> Unit {
  if (self.flags & BUFFER_FLAG_PRODUCE_SAFE_TO_INSERT_TATWEEL) == 0 {
    self.unsafe_to_break(start, end)
    return
  }
  self._set_glyph_flags(SAFE_TO_INSERT_TATWEEL, start, end, Some(true), None)
}

///|
/// Adds glyph flags in mask to infos with clusters between start and end.
/// The start index will be from out-buffer if from_out_buffer is true.
/// If interior is true, then the cluster having the minimum value is skipped.
fn Buffer::_set_glyph_flags(
  self : Buffer,
  mask : UInt,
  start : Int?,
  end : Int?,
  interior : Bool?,
  from_out_buffer : Bool?,
) -> Unit {
  let start = start.unwrap_or(0)
  let end = imin(end.unwrap_or(self.len), self.len)
  let interior = interior.unwrap_or(false)
  let from_out_buffer = from_out_buffer.unwrap_or(false)
  if interior && !from_out_buffer && end - start < 2 {
    return
  }
  self.scratch_flags = self.scratch_flags |
    HB_BUFFER_SCRATCH_FLAG_HAS_GLYPH_FLAGS
  if !from_out_buffer || !self.have_output {
    if !interior {
      for i in start..<end {
        self.info[i].mask = self.info[i].mask | mask
      }
    } else {
      let cluster = self._infos_find_min_cluster(self.info, start, end, None)
      self._infos_set_glyph_flags(false, start, end, cluster, mask)
    }
  } else {
    guard! start <= self.out_len
    guard! self.idx <= end
    if !interior {
      for i in start..<self.out_len {
        let info = self.out_info()[i]
        info.mask = info.mask | mask
      }
      for i in self.idx..<end {
        self.info[i].mask = self.info[i].mask | mask
      }
    } else {
      let mut cluster = self._infos_find_min_cluster(
        self.info,
        self.idx,
        end,
        None,
      )
      cluster = self._infos_find_min_cluster(
        self.out_info(),
        start,
        self.out_len,
        Some(cluster),
      )
      let out_len = self.out_len
      self._infos_set_glyph_flags(true, start, out_len, cluster, mask)
      self._infos_set_glyph_flags(false, self.idx, end, cluster, mask)
    }
  }
}

///|
fn Buffer::unsafe_to_concat(self : Buffer, start : Int?, end : Int?) -> Unit {
  if (self.flags & BUFFER_FLAG_PRODUCE_UNSAFE_TO_CONCAT) == 0 {
    return
  }
  self._set_glyph_flags(UNSAFE_TO_CONCAT, start, end, Some(false), None)
}

///|
fn Buffer::unsafe_to_break_from_outbuffer(
  self : Buffer,
  start : Int?,
  end : Int?,
) -> Unit {
  self._set_glyph_flags(
    UNSAFE_TO_BREAK | UNSAFE_TO_CONCAT,
    start,
    end,
    Some(true),
    Some(true),
  )
}

///|
fn Buffer::unsafe_to_concat_from_outbuffer(
  self : Buffer,
  start : Int?,
  end : Int?,
) -> Unit {
  if (self.flags & BUFFER_FLAG_PRODUCE_UNSAFE_TO_CONCAT) == 0 {
    return
  }
  self._set_glyph_flags(UNSAFE_TO_CONCAT, start, end, Some(false), Some(true))
}

///|
fn Buffer::move_to(self : Buffer, i : Int) -> Bool {
  if !self.have_output {
    guard! i <= self.len
    self.idx = i
    return true
  }
  if !self.successful {
    return false
  }
  guard! i <= self.out_len + (self.len - self.idx)
  if self.out_len < i {
    let count = i - self.out_len
    if !self.make_room_for(count, count) {
      return false
    }
    for j in 0..<count {
      self.set_out_info(self.out_len + j, self.info[self.idx + j])
    }
    self.idx += count
    self.out_len += count
  } else if self.out_len > i {
    // Tricky part: rewinding...
    let count = self.out_len - i

    // This will blow in our face if memory allocation fails later
    // in this same lookup...
    //
    // We used to shift with extra 32 items.
    // But that would leave empty slots in the buffer in case of allocation
    // failures.  See comments in shift_forward().  This can cause O(N^2)
    // behavior more severely than adding 32 empty slots can...
    if self.idx < count {
      self.shift_forward(count - self.idx)
    }
    guard! self.idx >= count
    self.idx -= count
    self.out_len -= count
    for j in 0..<count {
      self.info[self.idx + j].assign(self.out_info()[self.out_len + j])
    }
  }
  true
}

///|
fn Buffer::ensure(self : Buffer, size : Int) -> Bool {
  if size < self.len {
    return true
  }
  if size > self.max_len {
    self.successful = false
    return false
  }
  resize_infos(self.info, size, self.spare_infos)
  resize_positions(self.pos, size, self.spare_positions)
  resize_infos(self.out_sep, size, self.spare_infos)
  true
}

///|
fn Buffer::make_room_for(self : Buffer, num_in : Int, num_out : Int) -> Bool {
  if !self.ensure(self.out_len + num_out) {
    return false
  }
  if !self.have_separate_output && self.out_len + num_out > self.idx + num_in {
    guard! self.have_output
    self.have_separate_output = true
    for i in 0..<self.out_len {
      self.out_sep[i].assign(self.info[i])
    }
  }
  true
}

///|
fn Buffer::shift_forward(self : Buffer, count : Int) -> Unit {
  guard! self.have_output
  if !self.ensure(self.len + count) {
    return
  }
  for i = self.len - self.idx - 1; i >= 0; i = i - 1 {
    self.info[self.idx + count + i].assign(self.info[self.idx + i])
  }
  if self.idx + count > self.len {
    for i in self.len..<(self.idx + count) {
      self.info[i].reset()
    }
  }
  self.len += count
  self.idx += count
}

///|
fn Buffer::clear_context(self : Buffer, side : Int) -> Unit {
  self.context_len[side] = 0
}

///|
fn Buffer::sort(
  self : Buffer,
  start : Int,
  end : Int,
  cmp : (GlyphInfo, GlyphInfo) -> Bool,
) -> Unit {
  guard! !self.have_positions
  for i in (start + 1)..<end {
    let mut j = i
    while j > start && cmp(self.info[j - 1], self.info[i]) {
      j -= 1
    }
    if i == j {
      continue
    }

    // Move item i to occupy place for item j, shift what's in between.
    self.merge_clusters(j, i + 1)
    let t = self.info[i]
    for idx = i - j - 1; idx >= 0; idx = idx - 1 {
      self.info[idx + j + 1] = self.info[idx + j]
    }
    self.info[j] = t
  }
}

///|
fn set_cluster(info : GlyphInfo, cluster : UInt, mask : UInt) -> Unit {
  if info.cluster != cluster {
    info.mask = (info.mask & (GLYPH_FLAG_DEFINED ^ 0xFFFFFFFF)) |
      (mask & GLYPH_FLAG_DEFINED)
  }
  info.cluster = cluster
}

///|
/// Called around shape()
fn Buffer::enter(self : Buffer) -> Unit {
  self.serial = 0
  self.shaping_failed = false
  self.scratch_flags = HB_BUFFER_SCRATCH_FLAG_DEFAULT
  let len = self.len.to_int64() * MAX_LEN_FACTOR.to_int64()
  self.max_len = if len > MAX_LEN_MIN.to_int64() {
    len.to_int()
  } else {
    MAX_LEN_MIN
  }
  let ops = self.len.to_int64() * MAX_OPS_FACTOR.to_int64()
  if ops <= 2147483647L {
    self.max_ops = if ops > MAX_OPS_MIN.to_int64() {
      ops.to_int()
    } else {
      MAX_OPS_MIN
    }
  }
}

///|
/// Called around shape()
fn Buffer::leave(self : Buffer) -> Unit {
  self.max_len = MAX_LEN_DEFAULT
  self.max_ops = MAX_OPS_DEFAULT
  self.serial = 0
  // Intentionally not resetting shaping_failed, such that it can be inspected.
}

///|
fn Buffer::_infos_find_min_cluster(
  self : Buffer,
  info : Array[GlyphInfo],
  start : Int,
  end : Int,
  cluster : UInt?,
) -> UInt {
  let mut cluster = cluster.unwrap_or(0xFFFFFFFF)
  if start == end {
    return cluster
  }
  if self.cluster_level == HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS {
    for i in start..<end {
      cluster = umin(cluster, info[i].cluster)
    }
  }
  umin(cluster, umin(info[start].cluster, info[end - 1].cluster))
}

///|
fn Buffer::_infos_set_glyph_flags(
  self : Buffer,
  out_info : Bool,
  start : Int,
  end : Int,
  cluster : UInt,
  mask : UInt,
) -> Unit {
  let mut apply_scratch_flags = false
  if start == end {
    return
  }
  let cluster_level = self.cluster_level
  let infos = if out_info { self.out_info() } else { self.info }
  let cluster_first = infos[start].cluster
  let cluster_last = infos[end - 1].cluster
  if cluster_level == HB_BUFFER_CLUSTER_LEVEL_CHARACTERS ||
    (cluster != cluster_first && cluster != cluster_last) {
    for i in start..<end {
      if infos[i].cluster != cluster {
        apply_scratch_flags = true
        infos[i].mask = infos[i].mask | mask
      }
    }
    if apply_scratch_flags {
      self.scratch_flags = self.scratch_flags |
        HB_BUFFER_SCRATCH_FLAG_HAS_GLYPH_FLAGS
    }
    return
  }

  // Monotone clusters
  if cluster == cluster_first {
    let mut i = end
    while start < i && infos[i - 1].cluster != cluster_first {
      if cluster != infos[i - 1].cluster {
        apply_scratch_flags = true
        infos[i - 1].mask = infos[i - 1].mask | mask
      }
      i -= 1
    }
  } else {
    let mut i = start
    while i < end && infos[i].cluster != cluster_last {
      if cluster != infos[i].cluster {
        apply_scratch_flags = true
        infos[i].mask = infos[i].mask | mask
      }
      i += 1
    }
  }
  if apply_scratch_flags {
    self.scratch_flags = self.scratch_flags |
      HB_BUFFER_SCRATCH_FLAG_HAS_GLYPH_FLAGS
  }
}

///|
/// Checks that buffer contains no elements.
fn Buffer::is_empty(self : Buffer) -> Bool {
  self.len == 0
}

///|
fn Buffer::push_str(self : Buffer, text : StringView) -> Unit {
  let mut count = 0
  for _ in text {
    count += 1
  }
  if !self.ensure(self.len + count) {
    return
  }
  let mut offset = 0
  for c in text {
    self.add(c.to_int().reinterpret_as_uint(), offset.reinterpret_as_uint())
    offset += utf8_len(c)
  }
}

///|
fn utf8_len(c : Char) -> Int {
  let c = c.to_int()
  if c < 0x80 {
    1
  } else if c < 0x800 {
    2
  } else if c < 0x10000 {
    3
  } else {
    4
  }
}

///|
fn Buffer::set_pre_context(self : Buffer, text : Array[Int]) -> Unit {
  self.clear_context(0)
  let mut i = 0
  for j = text.length() - 1; j >= 0 && i < CONTEXT_LENGTH; j = j - 1 {
    self.context[0][i] = text[j]
    self.context_len[0] += 1
    i += 1
  }
}

///|
fn Buffer::set_post_context(self : Buffer, text : Array[Int]) -> Unit {
  self.clear_context(1)
  for i, c in text {
    if i >= CONTEXT_LENGTH {
      break
    }
    self.context[1][i] = c
    self.context_len[1] += 1
  }
}

///|
fn Buffer::next_syllable(self : Buffer, start : Int) -> Int {
  let mut start = start
  if start >= self.len {
    return start
  }
  let syllable = self.info[start].syllable()
  start += 1
  while start < self.len && syllable == self.info[start].syllable() {
    start += 1
  }
  start
}

///|
fn Buffer::allocate_lig_id(self : Buffer) -> Int {
  let mut lig_id = self.next_serial() & 0x07
  if lig_id == 0 {
    lig_id = self.allocate_lig_id()
  }
  lig_id
}

///|
fn cluster_group_func(a : GlyphInfo, b : GlyphInfo) -> Bool {
  a.cluster == b.cluster
}

///|
/// The `foreach_group!` macro.
fn Buffer::foreach_group(
  self : Buffer,
  group_func : (GlyphInfo, GlyphInfo) -> Bool,
  body : (Int, Int) -> Unit,
) -> Unit {
  let count = self.len
  let mut start = 0
  let mut end = if count > 0 { self.group_end(0, group_func) } else { 0 }
  while start < count {
    body(start, end)
    start = end
    end = self.group_end(start, group_func)
  }
}

///|
/// The `foreach_cluster!` macro.
fn Buffer::foreach_cluster(self : Buffer, body : (Int, Int) -> Unit) -> Unit {
  self.foreach_group(cluster_group_func, body)
}

///|
/// The `foreach_syllable!` macro.
fn Buffer::foreach_syllable(self : Buffer, body : (Int, Int) -> Unit) -> Unit {
  let mut start = 0
  let mut end = self.next_syllable(0)
  while start < self.len {
    body(start, end)
    start = end
    end = self.next_syllable(start)
  }
}

///|
/// The `foreach_grapheme!` macro.
fn Buffer::foreach_grapheme(self : Buffer, body : (Int, Int) -> Unit) -> Unit {
  self.foreach_group(grapheme_group_func, body)
}

///|
/// A buffer that contains an input string ready for shaping.
pub struct UnicodeBuffer(Buffer)

///|
/// Create a new `UnicodeBuffer`.
pub fn UnicodeBuffer::new() -> UnicodeBuffer {
  UnicodeBuffer(Buffer::new())
}

///|
/// The number of unicode codepoints contained in the buffer.
pub fn UnicodeBuffer::len(self : UnicodeBuffer) -> Int {
  self.0.len
}

///|
/// Returns `true` if the buffer contains no elements.
pub fn UnicodeBuffer::is_empty(self : UnicodeBuffer) -> Bool {
  self.0.is_empty()
}

///|
/// Pushes a string to a buffer (clusters are UTF-8 byte offsets).
pub fn UnicodeBuffer::push_str(self : UnicodeBuffer, str : StringView) -> Unit {
  self.0.push_str(str)
}

///|
/// Sets the pre-context for this buffer.
pub fn UnicodeBuffer::set_pre_context(
  self : UnicodeBuffer,
  chars : Array[Int],
) -> Unit {
  self.0.set_pre_context(chars)
}

///|
/// Sets the post-context for this buffer.
pub fn UnicodeBuffer::set_post_context(
  self : UnicodeBuffer,
  chars : Array[Int],
) -> Unit {
  self.0.set_post_context(chars)
}

///|
/// Appends a character to a buffer with the given cluster value.
pub fn UnicodeBuffer::add(
  self : UnicodeBuffer,
  codepoint : Int,
  cluster : UInt,
) -> Unit {
  self.0.add(codepoint.reinterpret_as_uint(), cluster)
  self.0.context_len[1] = 0
}

///|
/// Set the text direction of the `Buffer`'s contents.
pub fn UnicodeBuffer::set_direction(
  self : UnicodeBuffer,
  direction : Direction,
) -> Unit {
  self.0.direction = direction
}

///|
/// Returns the `Buffer`'s text direction.
pub fn UnicodeBuffer::direction(self : UnicodeBuffer) -> Direction {
  self.0.direction
}

///|
/// Set the script from an ISO15924 tag.
pub fn UnicodeBuffer::set_script(self : UnicodeBuffer, script : Script) -> Unit {
  self.0.script = Some(script)
}

///|
/// Get the ISO15924 script tag.
pub fn UnicodeBuffer::script(self : UnicodeBuffer) -> Script {
  self.0.script.unwrap_or(script_unknown)
}

///|
/// Set the buffer language.
pub fn UnicodeBuffer::set_language(
  self : UnicodeBuffer,
  lang : Language,
) -> Unit {
  self.0.language = Some(lang)
}

///|
/// Set the glyph value to replace not-found variation-selector characters
/// with.
pub fn UnicodeBuffer::set_not_found_variation_selector_glyph(
  self : UnicodeBuffer,
  glyph : UInt,
) -> Unit {
  self.0.not_found_variation_selector = Some(glyph)
}

///|
/// Get the buffer language.
pub fn UnicodeBuffer::language(self : UnicodeBuffer) -> Language? {
  self.0.language
}

///|
/// Guess the segment properties (direction, language, script) for the
/// current buffer.
pub fn UnicodeBuffer::guess_segment_properties(self : UnicodeBuffer) -> Unit {
  self.0.guess_segment_properties()
}

///|
/// Set the flags for this buffer (`BUFFER_FLAG_*`).
pub fn UnicodeBuffer::set_flags(self : UnicodeBuffer, flags : UInt) -> Unit {
  self.0.flags = flags
}

///|
/// Get the flags for this buffer.
pub fn UnicodeBuffer::flags(self : UnicodeBuffer) -> UInt {
  self.0.flags
}

///|
/// Set the cluster level of the buffer (`HB_BUFFER_CLUSTER_LEVEL_*`).
pub fn UnicodeBuffer::set_cluster_level(
  self : UnicodeBuffer,
  cluster_level : Int,
) -> Unit {
  self.0.cluster_level = cluster_level
}

///|
/// Retrieve the cluster level of the buffer.
pub fn UnicodeBuffer::cluster_level(self : UnicodeBuffer) -> Int {
  match self.0.cluster_level {
    HB_BUFFER_CLUSTER_LEVEL_MONOTONE_CHARACTERS
    | HB_BUFFER_CLUSTER_LEVEL_CHARACTERS => self.0.cluster_level
    _ => HB_BUFFER_CLUSTER_LEVEL_MONOTONE_GRAPHEMES
  }
}

///|
/// Resets clusters.
pub fn UnicodeBuffer::reset_clusters(self : UnicodeBuffer) -> Unit {
  self.0.reset_clusters()
}

///|
/// Clear the contents of the buffer.
pub fn UnicodeBuffer::clear(self : UnicodeBuffer) -> Unit {
  self.0.clear()
}

///|
/// A buffer that contains the results of the shaping process.
pub struct GlyphBuffer(Buffer)

///|
/// The number of glyphs stored.
pub fn GlyphBuffer::len(self : GlyphBuffer) -> Int {
  self.0.len
}

///|
/// Returns `true` if the buffer contains no elements.
pub fn GlyphBuffer::is_empty(self : GlyphBuffer) -> Bool {
  self.0.is_empty()
}

///|
/// Get the glyph infos.
pub fn GlyphBuffer::glyph_infos(self : GlyphBuffer) -> ArrayView[GlyphInfo] {
  self.0.info[0:self.0.len]
}

///|
/// Get the glyph positions.
pub fn GlyphBuffer::glyph_positions(
  self : GlyphBuffer,
) -> ArrayView[GlyphPosition] {
  self.0.pos[0:self.0.len]
}

///|
/// Clears the content of the glyph buffer and returns an empty
/// `UnicodeBuffer` reusing the existing allocation.
pub fn GlyphBuffer::clear(self : GlyphBuffer) -> UnicodeBuffer {
  self.0.clear()
  UnicodeBuffer(self.0)
}

///|
/// Turn the glyph buffer back into a buffer in the state of
/// `UnicodeBuffer::new()` (not upstream: unlike [GlyphBuffer::clear], also
/// resets the flags and limits). Its glyph slots are kept for reuse, so
/// that shaping many runs with one recycled buffer does not allocate them
/// again.
pub fn GlyphBuffer::recycle(self : GlyphBuffer) -> UnicodeBuffer {
  self.0.reset()
  UnicodeBuffer(self.0)
}

// Serialize flags (`SerializeFlags`).

///|
/// Do not serialize glyph cluster.
pub const SERIALIZE_NO_CLUSTERS : Int = 0b00000001

///|
/// Do not serialize glyph position information.
pub const SERIALIZE_NO_POSITIONS : Int = 0b00000010

///|
/// Do no serialize glyph name.
pub const SERIALIZE_NO_GLYPH_NAMES : Int = 0b00000100

///|
/// Serialize glyph extents.
pub const SERIALIZE_GLYPH_EXTENTS : Int = 0b00001000

///|
/// Serialize glyph flags.
pub const SERIALIZE_GLYPH_FLAGS : Int = 0b00010000

///|
/// Do not serialize glyph advances, glyph offsets will reflect absolute
/// glyph positions.
pub const SERIALIZE_NO_ADVANCES : Int = 0b00100000

///|
/// Converts the glyph buffer content into a string (hb-shape format).
pub fn GlyphBuffer::serialize(
  self : GlyphBuffer,
  face : Face,
  flags : Int,
) -> String {
  let s = StringBuilder()
  let infos = self.glyph_infos()
  let poss = self.glyph_positions()
  let mut x = 0
  let mut y = 0
  for i, info in infos {
    let pos = poss[i]
    if (flags & SERIALIZE_NO_GLYPH_NAMES) == 0 {
      match face.glyph_name(info.as_glyph()) {
        Some(name) => s.write_string(name)
        None => s.write_string("gid\{info.glyph_id}")
      }
    } else {
      s.write_string("\{info.glyph_id}")
    }
    if (flags & SERIALIZE_NO_CLUSTERS) == 0 {
      s.write_string("=\{info.cluster}")
    }
    if (flags & SERIALIZE_NO_POSITIONS) == 0 {
      if x + pos.x_offset != 0 || y + pos.y_offset != 0 {
        s.write_string("@\{x + pos.x_offset},\{y + pos.y_offset}")
      }
      if (flags & SERIALIZE_NO_ADVANCES) == 0 {
        s.write_string("+\{pos.x_advance}")
        if pos.y_advance != 0 {
          s.write_string(",\{pos.y_advance}")
        }
      }
    }
    if (flags & SERIALIZE_GLYPH_FLAGS) != 0 {
      if (info.mask & GLYPH_FLAG_DEFINED) != 0 {
        s.write_string("#\{hex_upper(info.mask & GLYPH_FLAG_DEFINED)}")
      }
    }
    if (flags & SERIALIZE_GLYPH_EXTENTS) != 0 {
      let extents = GlyphExtents::new()
      let _ = face.glyph_extents(info.as_glyph(), extents)
      s.write_string(
        "<\{extents.x_bearing},\{extents.y_bearing},\{extents.width},\{extents.height}>",
      )
    }
    if (flags & SERIALIZE_NO_ADVANCES) != 0 {
      x += pos.x_advance
      y += pos.y_advance
    }
    s.write_char('|')
  }
  // Remove last `|`.
  let out = s.to_string()
  if out.is_empty() {
    out
  } else {
    out[:out.length() - 1].to_owned()
  }
}

///|
fn hex_upper(n : UInt) -> String {
  let digits = "0123456789ABCDEF"
  if n == 0 {
    return "0"
  }
  let buf = []
  let mut n = n
  while n > 0 {
    buf.push(digits[(n & 0xF).reinterpret_as_int()].to_int().unsafe_to_char())
    n = n >> 4
  }
  buf.rev_in_place()
  String::from_array(buf)
}
