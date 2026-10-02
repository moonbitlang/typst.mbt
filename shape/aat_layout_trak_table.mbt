// Port of rustybuzz 0.20.1 `src/hb/aat_layout_trak_table.rs`.

///|
fn trak_apply(plan : ShapePlan, face : Face, buffer : Buffer) -> Unit? {
  let trak_mask = plan.trak_mask
  guard face.points_per_em is Some(ptem) else { return None }
  if ptem <= 0.0 {
    return None
  }
  guard face.tables().trak is Some(trak) else { return None }
  if !buffer.have_positions {
    buffer.clear_positions()
  }
  if buffer.direction.is_horizontal() {
    guard trak_hor_tracking(trak, ptem) is Some(tracking) else { return None }
    let advance_to_add = tracking
    let offset_to_add = tracking / 2
    buffer.foreach_grapheme((start, _end) => {
      if (buffer.info[start].mask & trak_mask) != 0 {
        buffer.pos[start].x_advance += advance_to_add
        buffer.pos[start].x_offset += offset_to_add
      }
    })
  } else {
    guard trak_ver_tracking(trak, ptem) is Some(tracking) else { return None }
    let advance_to_add = tracking
    let offset_to_add = tracking / 2
    buffer.foreach_grapheme((start, _end) => {
      if (buffer.info[start].mask & trak_mask) != 0 {
        buffer.pos[start].y_advance += advance_to_add
        buffer.pos[start].y_offset += offset_to_add
      }
    })
  }
  Some(())
}

///|
/// `TrackTableExt::hor_tracking`
fn trak_hor_tracking(this : @otf.TrakTable, ptem : Float) -> Int? {
  track_data_tracking(this.horizontal, ptem)
}

///|
/// `TrackTableExt::ver_tracking`
fn trak_ver_tracking(this : @otf.TrakTable, ptem : Float) -> Int? {
  track_data_tracking(this.vertical, ptem)
}

///|
/// `TrackTableDataExt::tracking`
fn track_data_tracking(this : @otf.TrackData, ptem : Float) -> Int? {
  // Choose track.
  guard this.tracks.iter().find_first(t => t.value == 0.0) is Some(track) else {
    return None
  }

  // Choose size.
  if this.sizes.is_empty() {
    return None
  }
  let mut idx = this.sizes.len().to_int() - 1
  for i, s in this.sizes.iter() {
    if s.0 >= ptem {
      idx = i
      break
    }
  }
  idx = if idx > 0 { idx - 1 } else { 0 }
  track_data_interpolate_at(this, idx, ptem, track).map(n => round_f32_to_i32(n))
}

///|
/// `TrackTableDataExt::interpolate_at`
fn track_data_interpolate_at(
  this : @otf.TrackData,
  idx : Int,
  target_size : Float,
  track : @otf.Track,
) -> Float? {
  guard this.sizes.get(idx.to_uint16()) is Some(s0) else { return None }
  let s0 = s0.0
  guard this.sizes.get((idx + 1).to_uint16()) is Some(s1) else { return None }
  let s1 = s1.0
  let t : Float = if s0 == s1 { 0.0 } else { (target_size - s0) / (s1 - s0) }
  guard track.values.get((idx + 1).to_uint16()) is Some(v1) else { return None }
  guard track.values.get(idx.to_uint16()) is Some(v0) else { return None }
  let n = t * Float::from_int(v1.to_int()) +
    (1.0 - t) * Float::from_int(v0.to_int())
  Some(n)
}
