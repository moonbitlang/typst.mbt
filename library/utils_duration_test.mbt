// The tests of `typst-utils/src/duration.rs`.

///|
/// `Duration::from_secs_f64`.
fn from_secs_f64(secs : Double) -> Int64 {
  (secs * 1.0e9).round().to_int64()
}

///|
test "format_duration" {
  let secs = 1000000000L
  let millis = 1000000L
  let micros = 1000L
  inspect(@library.format_duration(1000000L * secs), content="11 d 13 h 46 min")
  inspect(@library.format_duration(3600L * 24L * secs), content="1 d")
  inspect(@library.format_duration(3600L * secs), content="1 h")
  inspect(@library.format_duration((3600L + 240L) * secs), content="1 h 4 min")
  inspect(@library.format_duration(from_secs_f64(364.77)), content="6 min 4 s")
  inspect(
    @library.format_duration(from_secs_f64(264.776)),
    content="4 min 24.78 s",
  )
  inspect(@library.format_duration(3L * secs), content="3 s")
  inspect(@library.format_duration(from_secs_f64(2.8492)), content="2.85 s")
  inspect(@library.format_duration(999L * millis), content="999 ms")
  inspect(@library.format_duration(secs), content="1 s")
  inspect(@library.format_duration(999L * micros), content="999 µs")
  inspect(@library.format_duration(millis), content="1 ms")
  inspect(@library.format_duration(999L), content="999 ns")
  inspect(@library.format_duration(micros), content="1 µs")
  inspect(@library.format_duration(734L * micros), content="734 µs")
  inspect(@library.format_duration(294816L * micros), content="294.82 ms")
  inspect(@library.format_duration(1L), content="1 ns")
}
