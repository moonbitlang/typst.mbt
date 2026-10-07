// Port of `typst-utils/src/duration.rs`.

///|
/// Formats a duration with a precision suitable for human display (upstream
/// `typst_utils::format_duration`). The duration (Rust's `Duration`) is
/// given in nanoseconds.
pub fn format_duration(duration : Int64) -> String {
  let buf = StringBuilder()
  let mut space = false
  let piece = (text : String) => {
    if space {
      buf.write_char(' ')
    }
    space = true
    buf.write_string(text)
  }
  let subsec_nanos = duration % 1000000000L
  let secs = duration / 1000000000L
  let (mins, secs) = (secs / 60L, secs % 60L)
  let (hours, mins) = (mins / 60L, mins % 60L)
  let (days, hours) = (hours / 24L, hours % 24L)
  if days > 0L {
    piece("\{days} d")
  }
  if hours > 0L {
    piece("\{hours} h")
  }
  if mins > 0L {
    piece("\{mins} min")
  }

  // No need to display anything more than minutes at this point.
  if days > 0L || hours > 0L {
    return buf.to_string()
  }
  let order = (exp : Int) => {
    let mut order = 1L
    for _ in 0..<exp {
      order *= 1000L
    }
    order
  }
  let nanos = secs * order(3) + subsec_nanos
  let fract = (exp : Int) => {
    rust_display_f64(
      round_with_precision(nanos.to_double() / order(exp).to_double(), 2),
    )
  }
  if nanos == 0L || duration >= order(3) {
    // For durations >= 5 min, we drop the fractional part.
    if duration >= 300L * order(3) {
      piece("\{secs} s")
    } else {
      piece("\{fract(3)} s")
    }
  } else if duration >= order(2) {
    piece("\{fract(2)} ms")
  } else if duration >= order(1) {
    piece("\{fract(1)} µs")
  } else {
    piece("\{fract(0)} ns")
  }
  buf.to_string()
}
