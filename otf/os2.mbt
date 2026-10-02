// A [OS/2 and Windows Metrics Table](https://docs.microsoft.com/en-us/typography/opentype/spec/os2)
// implementation.

///|
let os2_weight_class_offset : Int = 4

///|
let os2_width_class_offset : Int = 6

///|
let os2_type_offset : Int = 8

///|
let os2_y_subscript_x_size_offset : Int = 10

///|
let os2_y_superscript_x_size_offset : Int = 18

///|
let os2_y_strikeout_size_offset : Int = 26

///|
let os2_y_strikeout_position_offset : Int = 28

///|
let os2_unicode_ranges_offset : Int = 42

///|
let os2_selection_offset : Int = 62

///|
let os2_typo_ascender_offset : Int = 68

///|
let os2_typo_descender_offset : Int = 70

///|
let os2_typo_line_gap_offset : Int = 72

///|
let os2_win_ascent : Int = 74

///|
let os2_win_descent : Int = 76

///|
let os2_x_height_offset : Int = 86

///|
let os2_cap_height_offset : Int = 88

///|
/// A face [weight](https://docs.microsoft.com/en-us/typography/opentype/spec/os2#usweightclass).
pub(all) enum Weight {
  Thin
  ExtraLight
  Light
  Normal
  Medium
  SemiBold
  Bold
  ExtraBold
  Black
  Other(UInt16)
} derive(Eq, Debug, Hash)

///|
/// Returns a numeric representation of a weight.
pub fn Weight::to_number(self : Weight) -> UInt16 {
  match self {
    Thin => 100
    ExtraLight => 200
    Light => 300
    Normal => 400
    Medium => 500
    SemiBold => 600
    Bold => 700
    ExtraBold => 800
    Black => 900
    Other(n) => n
  }
}

///|
pub fn Weight::from_u16(value : UInt16) -> Weight {
  match value {
    100 => Thin
    200 => ExtraLight
    300 => Light
    400 => Normal
    500 => Medium
    600 => SemiBold
    700 => Bold
    800 => ExtraBold
    900 => Black
    _ => Other(value)
  }
}

///|
pub impl Default for Weight with fn default() {
  Normal
}

///|
/// A face [width](https://docs.microsoft.com/en-us/typography/opentype/spec/os2#uswidthclass).
pub(all) enum Width {
  UltraCondensed
  ExtraCondensed
  Condensed
  SemiCondensed
  Normal
  SemiExpanded
  Expanded
  ExtraExpanded
  UltraExpanded
} derive(Eq, Compare, Debug, Hash)

///|
/// Returns a numeric representation of a width.
pub fn Width::to_number(self : Width) -> UInt16 {
  match self {
    UltraCondensed => 1
    ExtraCondensed => 2
    Condensed => 3
    SemiCondensed => 4
    Normal => 5
    SemiExpanded => 6
    Expanded => 7
    ExtraExpanded => 8
    UltraExpanded => 9
  }
}

///|
pub impl Default for Width with fn default() {
  Normal
}

///|
/// Face [permissions](https://docs.microsoft.com/en-us/typography/opentype/spec/os2#fst).
pub(all) enum Permissions {
  Installable
  Restricted
  PreviewAndPrint
  Editable
} derive(Eq, Compare, Debug, Hash)

///|
/// A face style.
pub(all) enum Style {
  /// A face that is neither italic not obliqued.
  Normal
  /// A form that is generally cursive in nature.
  Italic
  /// A typically-sloped version of the regular face.
  Oblique
} derive(Eq, Debug, Hash)

///|
pub impl Default for Style with fn default() {
  Normal
}

///|
/// A script metrics used by subscript and superscript.
pub(all) struct ScriptMetrics {
  /// Horizontal face size.
  mut x_size : Int16
  /// Vertical face size.
  mut y_size : Int16
  /// X offset.
  mut x_offset : Int16
  /// Y offset.
  mut y_offset : Int16
} derive(Eq, Debug, Hash)

///|
/// [Unicode Ranges](https://docs.microsoft.com/en-us/typography/opentype/spec/os2#ur).
///
/// A `u128` upstream; stored as low and high 64 bits.
pub(all) struct UnicodeRanges {
  lo : UInt64
  hi : UInt64
} derive(Eq, Default, Debug)

///|
/// Checks if ranges contain the specified character.
pub fn UnicodeRanges::contains_char(self : UnicodeRanges, c : Char) -> Bool {
  let range = char_range_index(c)
  if range >= 0 {
    if range < 64 {
      (self.lo & (1UL << range)) != 0
    } else {
      (self.hi & (1UL << (range - 64))) != 0
    }
  } else {
    false
  }
}

///|
/// A [OS/2 and Windows Metrics Table](https://docs.microsoft.com/en-us/typography/opentype/spec/os2).
pub struct Os2Table {
  /// Table version.
  version : Byte
  data : BytesView
}

///|
/// Parses a table from raw data.
pub fn Os2Table::parse(data : BytesView) -> Os2Table? {
  let s = Stream::new(data)
  let version = s.read_u16() catch { _ => return None }
  let table_len = match version {
    0 => 78
    1 => 86
    2 => 96
    3 => 96
    4 => 96
    5 => 100
    _ => return None
  }

  // Do not check the exact length, because some fonts include
  // padding in table's length in table records, which is incorrect.
  if data.length() < table_len {
    return None
  }
  Some({ version: version.to_int().to_byte(), data, })
}

///|
fn Os2Table::u16_at(self : Os2Table, offset : Int) -> UInt16 {
  Stream::read_at(self.data, offset) catch {
    _ => 0
  }
}

///|
fn Os2Table::i16_at(self : Os2Table, offset : Int) -> Int16 {
  Stream::read_at(self.data, offset) catch {
    _ => 0
  }
}

///|
/// Returns weight class.
pub fn Os2Table::weight(self : Os2Table) -> Weight {
  Weight::from_u16(self.u16_at(os2_weight_class_offset))
}

///|
/// Returns face width.
pub fn Os2Table::width(self : Os2Table) -> Width {
  match self.u16_at(os2_width_class_offset) {
    1 => UltraCondensed
    2 => ExtraCondensed
    3 => Condensed
    4 => SemiCondensed
    5 => Normal
    6 => SemiExpanded
    7 => Expanded
    8 => ExtraExpanded
    9 => UltraExpanded
    _ => Normal
  }
}

///|
/// Returns face permissions.
///
/// Returns `None` in case of a malformed value.
pub fn Os2Table::permissions(self : Os2Table) -> Permissions? {
  let n = self.u16_at(os2_type_offset)
  if self.version <= 2 {
    // Version 2 and prior, applications are allowed to take
    // the most permissive of provided flags
    let permission : Permissions = if (n & 0xF) == 0 {
      Installable
    } else if (n & 8) != 0 {
      Editable
    } else if (n & 4) != 0 {
      PreviewAndPrint
    } else {
      Restricted
    }
    Some(permission)
  } else {
    // Version 3 onwards, flags must be mutually exclusive.
    match n & 0xF {
      0 => Some(Installable)
      2 => Some(Restricted)
      4 => Some(PreviewAndPrint)
      8 => Some(Editable)
      _ => None
    }
  }
}

///|
/// Checks if the face allows embedding a subset, further restricted by `permissions`.
pub fn Os2Table::is_subsetting_allowed(self : Os2Table) -> Bool {
  if self.version <= 1 {
    // Flag introduced in version 2
    true
  } else {
    let n = self.u16_at(os2_type_offset)
    (n & 0x0100) == 0
  }
}

///|
/// Checks if the face allows outline data to be embedded.
///
/// If false, only bitmaps may be embedded in accordance with `permissions`.
///
/// If the font contains no bitmaps and this flag is not set, it implies no embedding is allowed.
pub fn Os2Table::is_outline_embedding_allowed(self : Os2Table) -> Bool {
  if self.version <= 1 {
    // Flag introduced in version 2
    true
  } else {
    let n = self.u16_at(os2_type_offset)
    (n & 0x0200) == 0
  }
}

///|
fn Os2Table::script_metrics_at(self : Os2Table, offset : Int) -> ScriptMetrics {
  let s = Stream::new_at(self.data, offset).unwrap_or(Stream::default())
  let x_size = s.read_i16() catch { _ => 0 }
  let y_size = s.read_i16() catch { _ => 0 }
  let x_offset = s.read_i16() catch { _ => 0 }
  let y_offset = s.read_i16() catch { _ => 0 }
  { x_size, y_size, x_offset, y_offset, }
}

///|
/// Returns subscript metrics.
pub fn Os2Table::subscript_metrics(self : Os2Table) -> ScriptMetrics {
  self.script_metrics_at(os2_y_subscript_x_size_offset)
}

///|
/// Returns superscript metrics.
pub fn Os2Table::superscript_metrics(self : Os2Table) -> ScriptMetrics {
  self.script_metrics_at(os2_y_superscript_x_size_offset)
}

///|
/// Returns strikeout metrics.
pub fn Os2Table::strikeout_metrics(self : Os2Table) -> LineMetrics {
  {
    thickness: self.i16_at(os2_y_strikeout_size_offset),
    position: self.i16_at(os2_y_strikeout_position_offset),
  }
}

///|
/// Returns Unicode ranges.
pub fn Os2Table::unicode_ranges(self : Os2Table) -> UnicodeRanges {
  let s = Stream::new_at(self.data, os2_unicode_ranges_offset).unwrap()
  let n1 = (s.read_u32() catch { _ => 0 }).to_uint64()
  let n2 = (s.read_u32() catch { _ => 0 }).to_uint64()
  let n3 = (s.read_u32() catch { _ => 0 }).to_uint64()
  let n4 = (s.read_u32() catch { _ => 0 }).to_uint64()
  { lo: (n2 << 32) | n1, hi: (n4 << 32) | n3, }
}

///|
fn Os2Table::fs_selection(self : Os2Table) -> UInt16 {
  self.u16_at(os2_selection_offset)
}

///|
/// Returns style.
pub fn Os2Table::style(self : Os2Table) -> Style {
  let flags = self.fs_selection()
  if (flags & (1 << 0)) != 0 {
    Italic
  } else if self.version >= 4 && (flags & (1 << 9)) != 0 {
    Oblique
  } else {
    Normal
  }
}

///|
/// Checks if face is bold.
///
/// Do not confuse with `Weight::Bold`.
pub fn Os2Table::is_bold(self : Os2Table) -> Bool {
  (self.fs_selection() & (1 << 5)) != 0
}

///|
/// Checks if typographic metrics should be used.
pub fn Os2Table::use_typographic_metrics(self : Os2Table) -> Bool {
  if self.version < 4 {
    false
  } else {
    (self.fs_selection() & (1 << 7)) != 0
  }
}

///|
/// Returns typographic ascender.
pub fn Os2Table::typographic_ascender(self : Os2Table) -> Int16 {
  self.i16_at(os2_typo_ascender_offset)
}

///|
/// Returns typographic descender.
pub fn Os2Table::typographic_descender(self : Os2Table) -> Int16 {
  self.i16_at(os2_typo_descender_offset)
}

///|
/// Returns typographic line gap.
pub fn Os2Table::typographic_line_gap(self : Os2Table) -> Int16 {
  self.i16_at(os2_typo_line_gap_offset)
}

///|
/// Returns Windows ascender.
pub fn Os2Table::windows_ascender(self : Os2Table) -> Int16 {
  self.i16_at(os2_win_ascent)
}

///|
/// Returns Windows descender.
pub fn Os2Table::windows_descender(self : Os2Table) -> Int16 {
  // Should be negated.
  -self.i16_at(os2_win_descent)
}

///|
/// Returns x height.
///
/// Returns `None` version is < 2.
pub fn Os2Table::x_height(self : Os2Table) -> Int16? {
  if self.version < 2 {
    None
  } else {
    try Stream::read_at(self.data, os2_x_height_offset) catch {
      _ => None
    } noraise {
      v => Some(v)
    }
  }
}

///|
/// Returns capital height.
///
/// Returns `None` version is < 2.
pub fn Os2Table::capital_height(self : Os2Table) -> Int16? {
  if self.version < 2 {
    None
  } else {
    try Stream::read_at(self.data, os2_cap_height_offset) catch {
      _ => None
    } noraise {
      v => Some(v)
    }
  }
}

///|
fn char_range_index(c : Char) -> Int {
  match c.to_int() {
    0x0000..=0x007F => 0
    0x0080..=0x00FF => 1
    0x0100..=0x017F => 2
    0x0180..=0x024F => 3
    0x0250..=0x02AF => 4
    0x1D00..=0x1DBF => 4
    0x02B0..=0x02FF => 5
    0xA700..=0xA71F => 5
    0x0300..=0x036F => 6
    0x1DC0..=0x1DFF => 6
    0x0370..=0x03FF => 7
    0x2C80..=0x2CFF => 8
    0x0400..=0x052F => 9
    0x2DE0..=0x2DFF => 9
    0xA640..=0xA69F => 9
    0x0530..=0x058F => 10
    0x0590..=0x05FF => 11
    0xA500..=0xA63F => 12
    0x0600..=0x06FF => 13
    0x0750..=0x077F => 13
    0x07C0..=0x07FF => 14
    0x0900..=0x097F => 15
    0x0980..=0x09FF => 16
    0x0A00..=0x0A7F => 17
    0x0A80..=0x0AFF => 18
    0x0B00..=0x0B7F => 19
    0x0B80..=0x0BFF => 20
    0x0C00..=0x0C7F => 21
    0x0C80..=0x0CFF => 22
    0x0D00..=0x0D7F => 23
    0x0E00..=0x0E7F => 24
    0x0E80..=0x0EFF => 25
    0x10A0..=0x10FF => 26
    0x2D00..=0x2D2F => 26
    0x1B00..=0x1B7F => 27
    0x1100..=0x11FF => 28
    0x1E00..=0x1EFF => 29
    0x2C60..=0x2C7F => 29
    0xA720..=0xA7FF => 29
    0x1F00..=0x1FFF => 30
    0x2000..=0x206F => 31
    0x2E00..=0x2E7F => 31
    0x2070..=0x209F => 32
    0x20A0..=0x20CF => 33
    0x20D0..=0x20FF => 34
    0x2100..=0x214F => 35
    0x2150..=0x218F => 36
    0x2190..=0x21FF => 37
    0x27F0..=0x27FF => 37
    0x2900..=0x297F => 37
    0x2B00..=0x2BFF => 37
    0x2200..=0x22FF => 38
    0x2A00..=0x2AFF => 38
    0x27C0..=0x27EF => 38
    0x2980..=0x29FF => 38
    0x2300..=0x23FF => 39
    0x2400..=0x243F => 40
    0x2440..=0x245F => 41
    0x2460..=0x24FF => 42
    0x2500..=0x257F => 43
    0x2580..=0x259F => 44
    0x25A0..=0x25FF => 45
    0x2600..=0x26FF => 46
    0x2700..=0x27BF => 47
    0x3000..=0x303F => 48
    0x3040..=0x309F => 49
    0x30A0..=0x30FF => 50
    0x31F0..=0x31FF => 50
    0x3100..=0x312F => 51
    0x31A0..=0x31BF => 51
    0x3130..=0x318F => 52
    0xA840..=0xA87F => 53
    0x3200..=0x32FF => 54
    0x3300..=0x33FF => 55
    0xAC00..=0xD7AF => 56
    0x10900..=0x1091F => 58
    0x4E00..=0x9FFF => 59
    0x2E80..=0x2FDF => 59
    0x2FF0..=0x2FFF => 59
    0x3400..=0x4DBF => 59
    0x20000..=0x2A6DF => 59
    0x3190..=0x319F => 59
    0xE000..=0xF8FF => 60
    0x31C0..=0x31EF => 61
    0xF900..=0xFAFF => 61
    0x2F800..=0x2FA1F => 61
    0xFB00..=0xFB4F => 62
    0xFB50..=0xFDFF => 63
    0xFE20..=0xFE2F => 64
    0xFE10..=0xFE1F => 65
    0xFE30..=0xFE4F => 65
    0xFE50..=0xFE6F => 66
    0xFE70..=0xFEFF => 67
    0xFF00..=0xFFEF => 68
    0xFFF0..=0xFFFF => 69
    0x0F00..=0x0FFF => 70
    0x0700..=0x074F => 71
    0x0780..=0x07BF => 72
    0x0D80..=0x0DFF => 73
    0x1000..=0x109F => 74
    0x1200..=0x139F => 75
    0x2D80..=0x2DDF => 75
    0x13A0..=0x13FF => 76
    0x1400..=0x167F => 77
    0x1680..=0x169F => 78
    0x16A0..=0x16FF => 79
    0x1780..=0x17FF => 80
    0x19E0..=0x19FF => 80
    0x1800..=0x18AF => 81
    0x2800..=0x28FF => 82
    0xA000..=0xA48F => 83
    0xA490..=0xA4CF => 83
    0x1700..=0x177F => 84
    0x10300..=0x1032F => 85
    0x10330..=0x1034F => 86
    0x10400..=0x1044F => 87
    0x1D000..=0x1D24F => 88
    0x1D400..=0x1D7FF => 89
    0xF0000..=0xFFFFD => 90
    0x100000..=0x10FFFD => 90
    0xFE00..=0xFE0F => 91
    0xE0100..=0xE01EF => 91
    0xE0000..=0xE007F => 92
    0x1900..=0x194F => 93
    0x1950..=0x197F => 94
    0x1980..=0x19DF => 95
    0x1A00..=0x1A1F => 96
    0x2C00..=0x2C5F => 97
    0x2D30..=0x2D7F => 98
    0x4DC0..=0x4DFF => 99
    0xA800..=0xA82F => 100
    0x10000..=0x1013F => 101
    0x10140..=0x1018F => 102
    0x10380..=0x1039F => 103
    0x103A0..=0x103DF => 104
    0x10450..=0x1047F => 105
    0x10480..=0x104AF => 106
    0x10800..=0x1083F => 107
    0x10A00..=0x10A5F => 108
    0x1D300..=0x1D35F => 109
    0x12000..=0x123FF => 110
    0x12400..=0x1247F => 110
    0x1D360..=0x1D37F => 111
    0x1B80..=0x1BBF => 112
    0x1C00..=0x1C4F => 113
    0x1C50..=0x1C7F => 114
    0xA880..=0xA8DF => 115
    0xA900..=0xA92F => 116
    0xA930..=0xA95F => 117
    0xAA00..=0xAA5F => 118
    0x10190..=0x101CF => 119
    0x101D0..=0x101FF => 120
    0x102A0..=0x102DF => 121
    0x10280..=0x1029F => 121
    0x10920..=0x1093F => 121
    0x1F030..=0x1F09F => 122
    0x1F000..=0x1F02F => 122
    _ => -1
  }
}
