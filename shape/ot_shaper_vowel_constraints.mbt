// Port of rustybuzz 0.20.1 `src/hb/ot_shaper_vowel_constraints.rs`
// (generated there by scripts/gen-vowel-constraints.py; ported by hand).

///|
fn output_dotted_circle(buffer : Buffer) -> Unit {
  buffer.output_glyph(0x25CC)
  let out_idx = buffer.out_len - 1
  buffer.out_info()[out_idx].reset_continuation()
}

///|
fn output_with_dotted_circle(buffer : Buffer) -> Unit {
  output_dotted_circle(buffer)
  buffer.next_glyph()
}

///|
fn preprocess_text_vowel_constraints(buffer : Buffer) -> Unit {
  if (buffer.flags & BUFFER_FLAG_DO_NOT_INSERT_DOTTED_CIRCLE) != 0 {
    return
  }

  // UGLY UGLY UGLY business of adding dotted-circle in the middle of
  // vowel-sequences that look like another vowel.  Data for each script
  // collected from the USE script development spec.
  //
  // https://github.com/harfbuzz/harfbuzz/issues/1019
  buffer.clear_output()
  fn cur(i : Int) -> Int {
    buffer.cur(i).as_char()
  }

  match buffer.script {
    Some(s) if s == script_devanagari => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0905 =>
            match cur(1) {
              0x093A
              | 0x093B
              | 0x093E
              | 0x0945
              | 0x0946
              | 0x0949
              | 0x094A
              | 0x094B
              | 0x094C
              | 0x094F
              | 0x0956
              | 0x0957 => matched = true
              _ => ()
            }
          0x0906 =>
            match cur(1) {
              0x093A | 0x0945 | 0x0946 | 0x0947 | 0x0948 => matched = true
              _ => ()
            }
          0x0909 => matched = 0x0941 == cur(1)
          0x090F =>
            match cur(1) {
              0x0945 | 0x0946 | 0x0947 => matched = true
              _ => ()
            }
          0x0930 =>
            if 0x094D == cur(1) &&
              buffer.idx + 2 < buffer.len &&
              0x0907 == cur(2) {
              buffer.next_glyph()
              buffer.next_glyph()
              output_dotted_circle(buffer)
            }
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_bengali => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0985 => matched = 0x09BE == cur(1)
          0x098B => matched = 0x09C3 == cur(1)
          0x098C => matched = 0x09E2 == cur(1)
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_gurmukhi => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0A05 =>
            match cur(1) {
              0x0A3E | 0x0A48 | 0x0A4C => matched = true
              _ => ()
            }
          0x0A72 =>
            match cur(1) {
              0x0A3F | 0x0A40 | 0x0A47 => matched = true
              _ => ()
            }
          0x0A73 =>
            match cur(1) {
              0x0A41 | 0x0A42 | 0x0A4B => matched = true
              _ => ()
            }
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_gujarati => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0A85 =>
            match cur(1) {
              0x0ABE | 0x0AC5 | 0x0AC7 | 0x0AC8 | 0x0AC9 | 0x0ACB | 0x0ACC =>
                matched = true
              _ => ()
            }
          0x0AC5 => matched = 0x0ABE == cur(1)
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_oriya => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0B05 => matched = 0x0B3E == cur(1)
          0x0B0F | 0x0B13 => matched = 0x0B57 == cur(1)
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_tamil => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let matched = false
        if 0x0B85 == cur(0) && 0x0BC2 == cur(1) {
          buffer.next_glyph()
          output_dotted_circle(buffer)
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_telugu => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0C12 =>
            match cur(1) {
              0x0C4C | 0x0C55 => matched = true
              _ => ()
            }
          0x0C3F | 0x0C46 | 0x0C4A => matched = 0x0C55 == cur(1)
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_kannada => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0C89 | 0x0C8B => matched = 0x0CBE == cur(1)
          0x0C92 => matched = 0x0CCC == cur(1)
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_malayalam => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0D07 | 0x0D09 => matched = 0x0D57 == cur(1)
          0x0D0E => matched = 0x0D46 == cur(1)
          0x0D12 =>
            match cur(1) {
              0x0D3E | 0x0D57 => matched = true
              _ => ()
            }
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_sinhala => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x0D85 =>
            match cur(1) {
              0x0DCF | 0x0DD0 | 0x0DD1 => matched = true
              _ => ()
            }
          0x0D8B | 0x0D8F | 0x0D94 => matched = 0x0DDF == cur(1)
          0x0D8D => matched = 0x0DD8 == cur(1)
          0x0D91 =>
            match cur(1) {
              0x0DCA | 0x0DD9 | 0x0DDA | 0x0DDC | 0x0DDD | 0x0DDE =>
                matched = true
              _ => ()
            }
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_brahmi => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x11005 => matched = 0x11038 == cur(1)
          0x1100B => matched = 0x1103E == cur(1)
          0x1100F => matched = 0x11042 == cur(1)
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_khojki => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x11200 =>
            match cur(1) {
              0x1122C | 0x11231 | 0x11233 => matched = true
              _ => ()
            }
          0x11206 => matched = 0x1122C == cur(1)
          0x1122C =>
            match cur(1) {
              0x11230 | 0x11231 => matched = true
              _ => ()
            }
          0x11240 => matched = 0x1122E == cur(1)
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_khudawadi => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x112B0 =>
            match cur(1) {
              0x112E0 | 0x112E5 | 0x112E6 | 0x112E7 | 0x112E8 => matched = true
              _ => ()
            }
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_tirhuta => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x11481 => matched = 0x114B0 == cur(1)
          0x1148B | 0x1148D => matched = 0x114BA == cur(1)
          0x114AA =>
            match cur(1) {
              0x114B5 | 0x114B6 => matched = true
              _ => ()
            }
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_modi => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x11600 | 0x11601 =>
            match cur(1) {
              0x11639 | 0x1163A => matched = true
              _ => ()
            }
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    Some(s) if s == script_takri => {
      buffer.idx = 0
      while buffer.idx + 1 < buffer.len {
        let mut matched = false
        match cur(0) {
          0x11680 =>
            match cur(1) {
              0x116AD | 0x116B4 | 0x116B5 => matched = true
              _ => ()
            }
          0x11686 => matched = 0x116B2 == cur(1)
          _ => ()
        }
        buffer.next_glyph()
        if matched {
          output_with_dotted_circle(buffer)
        }
      }
    }
    _ => ()
  }
  buffer.sync() |> ignore
}
