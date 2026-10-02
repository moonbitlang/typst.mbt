// Port of rustybuzz 0.20.1 `src/hb/aat_map.rs`.

///|
/// `hb_aat_map_t`
priv struct AatMap {
  chain_flags : Array[Array[RangeFlags]]
}

///|
fn AatMap::default() -> AatMap {
  { chain_flags: [], }
}

///|
/// `feature_info_t`
priv struct AatFeatureInfo {
  kind : Int
  setting : Int
  is_exclusive : Bool
} derive(Eq)

///|
fn AatFeatureInfo::default() -> AatFeatureInfo {
  { kind: 0, setting: 0, is_exclusive: false, }
}

///|
/// `impl PartialOrd for feature_info_t`
fn AatFeatureInfo::cmp(self : AatFeatureInfo, other : AatFeatureInfo) -> Int {
  if self.kind != other.kind {
    self.kind.compare(other.kind)
  } else if !self.is_exclusive &&
    (self.setting & 0xFFFE) != (other.setting & 0xFFFE) {
    self.setting.compare(other.setting)
  } else {
    0
  }
}

///|
/// `feature_range_t`
priv struct AatFeatureRange {
  info : AatFeatureInfo
  start : UInt
  end : UInt
}

///|
/// `feature_event_t`
priv struct AatFeatureEvent {
  index : UInt
  start : Bool
  feature : AatFeatureInfo
}

///|
/// `impl PartialOrd for feature_event_t`
fn AatFeatureEvent::cmp(self : AatFeatureEvent, other : AatFeatureEvent) -> Int {
  if self.index != other.index {
    self.index.compare(other.index)
  } else if self.start != other.start {
    self.start.compare(other.start)
  } else {
    0
  }
}

///|
/// `range_flags_t`
priv struct RangeFlags {
  flags : UInt
  cluster_first : UInt
  mut cluster_last : UInt // end - 1
}

///|
/// `hb_aat_map_builder_t`
priv struct AatMapBuilder {
  mut current_features : Array[AatFeatureInfo]
  features : Array[AatFeatureRange]
  mut range_first : UInt
  mut range_last : UInt
}

///|
fn AatMapBuilder::default() -> AatMapBuilder {
  {
    range_first: HB_FEATURE_GLOBAL_START,
    range_last: HB_FEATURE_GLOBAL_END,
    current_features: [],
    features: [],
  }
}

///|
/// Rust's stable `slice::sort_by` (insertion sort, as used for short
/// slices): `is_less(a, b)` is `cmp(a, b) == Less`.
fn[T] aat_insertion_sort(v : Array[T], cmp : (T, T) -> Int) -> Unit {
  for i in 1..<v.length() {
    let x = v[i]
    let mut j = i
    while j > 0 && cmp(x, v[j - 1]) < 0 {
      v[j] = v[j - 1]
      j -= 1
    }
    v[j] = x
  }
}

///|
fn AatMapBuilder::add_feature(
  self : AatMapBuilder,
  face : Face,
  feature : Feature,
) -> Unit? {
  guard face.tables().feat is Some(feat) else { return None }
  if feature.tag == tag("aalt") {
    let exposes_feature = feat.names
      .find(HB_AAT_LAYOUT_FEATURE_TYPE_CHARACTER_ALTERNATIVES.to_uint16())
      .map(f => !f.setting_names.is_empty())
      .unwrap_or(false)
    if !exposes_feature {
      return Some(())
    }
    guard! feature.value <= 0xFFFF
    self.features.push({
      start: feature.start,
      end: feature.end,
      info: {
        kind: HB_AAT_LAYOUT_FEATURE_TYPE_CHARACTER_ALTERNATIVES,
        setting: feature.value.reinterpret_as_int(),
        is_exclusive: true,
      },
    })
  }
  guard aat_feature_mapping_find(feature.tag) is Some(mapping) else {
    return None
  }
  let mut feature_name = feat.names.find(mapping.aat_feature_type.to_uint16())
  match feature_name {
    Some(feature) if !feature.setting_names.is_empty() => ()
    _ =>
      // Special case: Chain::compile_flags will fall back to the deprecated version of
      // small-caps if necessary, so we need to check for that possibility.
      // https://github.com/harfbuzz/harfbuzz/issues/2307
      if mapping.aat_feature_type == HB_AAT_LAYOUT_FEATURE_TYPE_LOWER_CASE &&
        mapping.selector_to_enable ==
        HB_AAT_LAYOUT_FEATURE_SELECTOR_LOWER_CASE_SMALL_CAPS {
        feature_name = feat.names.find(
          HB_AAT_LAYOUT_FEATURE_TYPE_LETTER_CASE.to_uint16(),
        )
      }
  }
  match feature_name {
    Some(feature_name) if !feature_name.setting_names.is_empty() => {
      let setting = if feature.value != 0 {
        mapping.selector_to_enable
      } else {
        mapping.selector_to_disable
      }
      self.features.push({
        start: feature.start,
        end: feature.end,
        info: {
          kind: mapping.aat_feature_type,
          setting,
          is_exclusive: feature_name.exclusive,
        },
      })
    }
    _ => ()
  }
  Some(())
}

///|
/// `feature_mappings.binary_search_by(|map| map.ot_feature_tag.cmp(&tag))`
fn aat_feature_mapping_find(feature_tag : @otf.Tag) -> AatFeatureMapping? {
  let mut lo = 0
  let mut hi = feature_mappings.length()
  while lo < hi {
    let mid = lo + (hi - lo) / 2
    let c = feature_mappings[mid].ot_feature_tag.compare(feature_tag)
    if c == 0 {
      return Some(feature_mappings[mid])
    } else if c < 0 {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  None
}

///|
fn AatMapBuilder::compile(
  self : AatMapBuilder,
  face : Face,
  m : AatMap,
) -> Unit {
  // Compute active features per range, and compile each.
  let feature_events : Array[AatFeatureEvent] = []
  for feature in self.features {
    if feature.start == feature.end {
      continue
    }
    feature_events.push({
      index: feature.start,
      start: true,
      feature: feature.info,
    })
    feature_events.push({
      index: feature.end,
      start: false,
      feature: feature.info,
    })
  }
  aat_insertion_sort(feature_events, (a, b) => a.cmp(b))

  // Add a strategic final event.
  feature_events.push({
    index: 0xFFFFFFFF,
    start: false,
    feature: AatFeatureInfo::default(),
  })

  // Scan events and save features for each range.
  let active_features : Array[AatFeatureInfo] = []
  let mut last_index : UInt = 0
  for event in feature_events {
    if event.index != last_index {
      // Save a snapshot of active features and the range.
      // Sort features and merge duplicates.
      self.current_features = active_features.copy()
      self.range_first = last_index
      self.range_last = event.index - 1
      if !self.current_features.is_empty() {
        let current_features = self.current_features
        aat_insertion_sort(current_features, (a, b) => a.cmp(b))
        let mut j = 0
        for i in 1..<current_features.length() {
          // Nonexclusive feature selectors come in even/odd pairs to turn a setting on/off
          // respectively, so we mask out the low-order bit when checking for "duplicates"
          // (selectors referring to the same feature setting) here.
          let non_exclusive = !current_features[i].is_exclusive &&
            (current_features[i].setting & 0xFFFE) !=
            (current_features[j].setting & 0xFFFE)
          if current_features[i].kind != current_features[j].kind ||
            non_exclusive {
            j += 1
            current_features[j] = current_features[i]
          }
        }
        current_features.truncate(j + 1)
      }
      compile_flags(face, self, m) |> ignore
      last_index = event.index
    }
    if event.start {
      active_features.push(event.feature)
    } else {
      match active_features.search(event.feature) {
        Some(index) => active_features.remove(index) |> ignore
        None => ()
      }
    }
  }
  for chain_flags in m.chain_flags {
    if chain_flags.last() is Some(last) {
      last.cluster_last = HB_FEATURE_GLOBAL_END
    }
  }
}
