// Port of `icu_segmenter 2.3.0`: `complex/mod.rs` and `complex/script.rs`
// (the LSTM path used by `LineSegmenter::new_lstm`; the dictionary payloads
// are not ported because Typst doesn't load them).

///|
priv enum ComplexScript {
  None
  Myanmar
  ChineseOrJapanese
  Khmer
  Lao
  Thai
} derive(Eq)

///|
// TODO: Use data provider
fn get_complex_script(codepoint : Int) -> ComplexScript {
  // For Thai, Burmese, Lao and Khmer, these are the intersections
  // of lb=SA with the respective Script
  // (The Lao range `0x0E8C..0x0EA3` is exclusive upstream.)
  match codepoint {
    0xE01..=0xE3A | 0xE40..=0x0E4E => Thai
    0x0E81
    | 0x0E82
    | 0x0E84
    | 0x0E86..=0x0E8A
    | 0x0E8C..=0x0EA2
    | 0x0EA5
    | 0x0EA7..=0x0EBD
    | 0x0EC0..=0x0EC4
    | 0x0EC6
    | 0x0EC8..=0x0ECE
    | 0x0EDC..=0x0EDF => Lao
    0x1000..=0x103F
    | 0x1050..=0x108F
    | 0x109A..=0x109F
    | 0xA9E0..=0xA9EF
    | 0xA9FA..=0xA9FE
    | 0xAA60..=0xAA7F => Myanmar
    0x1780..=0x17d3 | 0x17d7 | 0x17dc | 0x17dd => Khmer
    0x2E80..=0x2E99
    | 0x2E9B..=0x2EF3
    | 0x2F00..=0x2FD5
    | 0x3005
    | 0x3007
    | 0x3021..=0x3029
    | 0x3038..=0x303B
    | 0x3041..=0x3096
    | 0x309D..=0x309F
    | 0x3400..=0x4DBF
    | 0x4E00..=0x9FFF
    | 0xF900..=0xFA6D
    | 0xFA70..=0xFAD9
    | 0x00016FE2
    | 0x00016FE3
    | 0x00016FF0..=0x00016FF6
    | 0x0001B001..=0x0001B11F
    | 0x0001B132
    | 0x0001B150..=0x0001B152
    | 0x0001F200
    | 0x00020000..=0x0002A6DF
    | 0x0002A700..=0x0002B81D
    | 0x0002B820..=0x0002CEAD
    | 0x0002CEB0..=0x0002EBE0
    | 0x0002EBF0..=0x0002EE5D
    | 0x0002F800..=0x0002FA1D
    | 0x00030000..=0x0003134A
    | 0x00031350..=0x00033479 => ChineseOrJapanese
    _ => None
  }
}

///|
/// The complex-script payloads of a segmenter.
priv struct ComplexPayloads {
  mut my : LstmSegmenter?
  mut km : LstmSegmenter?
  mut lo : LstmSegmenter?
  mut th : LstmSegmenter?
  /// Whether the Southeast Asian LSTM models are enabled. They are decoded on
  /// first use (not upstream, where they are baked data: decoding all of
  /// them took a third of the CLI's startup time).
  mut lstms : Bool
}

///|
fn ComplexPayloads::new() -> ComplexPayloads {
  { my: None, km: None, lo: None, th: None, lstms: false, }
}

///|
fn ComplexPayloads::with_southeast_asian_lstms(self : ComplexPayloads) -> Unit {
  self.lstms = true
}

///|
fn ComplexPayloads::select(
  self : ComplexPayloads,
  complex_script : ComplexScript,
) -> LstmSegmenter? {
  match complex_script {
    Myanmar => {
      if self.lstms && self.my is None {
        self.my = Some(lstm_burmese.get())
      }
      self.my
    }
    Khmer => {
      if self.lstms && self.km is None {
        self.km = Some(lstm_khmer.get())
      }
      self.km
    }
    Lao => {
      if self.lstms && self.lo is None {
        self.lo = Some(lstm_lao.get())
      }
      self.lo
    }
    Thai => {
      if self.lstms && self.th is None {
        self.th = Some(lstm_thai.get())
      }
      self.th
    }
    // No Chinese/Japanese dictionary is loaded by the line segmenter.
    ChineseOrJapanese => None
    None => None
  }
}

///|
/// Segment a run of complex-script characters, returning UTF-8 byte offsets
/// (relative to the run).
fn ComplexPayloads::segment_str(
  self : ComplexPayloads,
  input : Array[Int],
) -> Array[Int] {
  let result = []
  let mut offset = 0
  // ComplexScriptIterator
  let mut start = 0
  while start < input.length() {
    let lang = get_complex_script(input[start])
    let mut end = start + 1
    while end < input.length() && get_complex_script(input[end]) == lang {
      end += 1
    }
    let slice = input[start:end]
    let mut slice_len = 0
    for c in slice {
      slice_len += utf8_len(c)
    }
    match self.select(lang) {
      Some(d) =>
        for b in d.segment_str(slice) {
          result.push(b + offset)
        }
      None => result.push(offset + slice_len)
    }
    offset += slice_len
    start = end
  }
  result
}
