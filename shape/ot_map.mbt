// Port of rustybuzz 0.20.1 `src/hb/ot_map.rs`.

///|
priv struct OtMap {
  found_script : FixedArray[Bool]
  chosen_script : FixedArray[@otf.Tag?]
  global_mask : UInt
  features : Array[FeatureMap]
  lookups : FixedArray[Array[LookupMap]]
  stages : FixedArray[Array[StageMap]]
}

///|
priv struct FeatureMap {
  tag : @otf.Tag
  // GSUB/GPOS
  index : FixedArray[Int?]
  stage : FixedArray[Int]
  shift : Int
  mask : UInt
  // mask for value=1, for quick access
  one_mask : UInt
  auto_zwnj : Bool
  auto_zwj : Bool
  random : Bool
  per_syllable : Bool
}

///|
priv struct LookupMap {
  index : Int
  // TODO: to bitflags
  mut auto_zwnj : Bool
  mut auto_zwj : Bool
  random : Bool
  mut mask : UInt
  per_syllable : Bool
}

///|
fn LookupMap::copy(self : LookupMap) -> LookupMap {
  { ..self, }
}

///|
/// The derived `Ord` of `lookup_map_t` (field order: index, auto_zwnj,
/// auto_zwj, random, mask, per_syllable).
fn LookupMap::cmp(self : LookupMap, o : LookupMap) -> Int {
  let c = self.index.compare(o.index)
  if c != 0 {
    return c
  }
  let c = self.auto_zwnj.compare(o.auto_zwnj)
  if c != 0 {
    return c
  }
  let c = self.auto_zwj.compare(o.auto_zwj)
  if c != 0 {
    return c
  }
  let c = self.random.compare(o.random)
  if c != 0 {
    return c
  }
  let c = self.mask.compare(o.mask)
  if c != 0 {
    return c
  }
  self.per_syllable.compare(o.per_syllable)
}

///|
/// Pause functions return true if new glyph indices might have been added to
/// the buffer. This is used to update buffer digest.
type PauseFunc = (ShapePlan, Face, Buffer) -> Bool

///|
priv struct StageMap {
  // Cumulative
  last_lookup : Int
  pause_func : PauseFunc?
}

///|
const MAX_BITS : Int = 8

///|
const MAX_VALUE : UInt = 255 // (1 << MAX_BITS) - 1

///|
fn OtMap::found_script(self : OtMap, table_index : TableIndex) -> Bool {
  self.found_script[table_index.to_int()]
}

///|
fn OtMap::chosen_script(self : OtMap, table_index : TableIndex) -> @otf.Tag? {
  self.chosen_script[table_index.to_int()]
}

///|
fn OtMap::get_global_mask(self : OtMap) -> UInt {
  self.global_mask
}

///|
/// `binary_search_by_key(&feature_tag, |f| f.tag)` (any matching index).
fn OtMap::find_feature(self : OtMap, feature_tag : @otf.Tag) -> Int? {
  let features = self.features
  let mut size = features.length()
  if size == 0 {
    return None
  }
  // Rust's slice::binary_search_by (1.97).
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    if features[mid].tag <= feature_tag {
      base = mid
    }
    size -= half
  }
  if features[base].tag == feature_tag {
    Some(base)
  } else {
    None
  }
}

///|
fn OtMap::get_mask(self : OtMap, feature_tag : @otf.Tag) -> (UInt, Int) {
  match self.find_feature(feature_tag) {
    Some(idx) => (self.features[idx].mask, self.features[idx].shift)
    None => (0, 0)
  }
}

///|
fn OtMap::get_1_mask(self : OtMap, feature_tag : @otf.Tag) -> UInt {
  match self.find_feature(feature_tag) {
    Some(idx) => self.features[idx].one_mask
    None => 0
  }
}

///|
fn OtMap::get_feature_index(
  self : OtMap,
  table_index : TableIndex,
  feature_tag : @otf.Tag,
) -> Int? {
  match self.find_feature(feature_tag) {
    Some(idx) => self.features[idx].index[table_index.to_int()]
    None => None
  }
}

///|
fn OtMap::get_feature_stage(
  self : OtMap,
  table_index : TableIndex,
  feature_tag : @otf.Tag,
) -> Int? {
  match self.find_feature(feature_tag) {
    Some(idx) => Some(self.features[idx].stage[table_index.to_int()])
    None => None
  }
}

///|
fn OtMap::stages(self : OtMap, table_index : TableIndex) -> Array[StageMap] {
  self.stages[table_index.to_int()]
}

///|
fn OtMap::lookup(
  self : OtMap,
  table_index : TableIndex,
  index : Int,
) -> LookupMap {
  self.lookups[table_index.to_int()][index]
}

///|
fn OtMap::stage_lookups(
  self : OtMap,
  table_index : TableIndex,
  stage : Int,
) -> ArrayView[LookupMap] {
  let (start, end) = self.stage_lookup_range(table_index, stage)
  self.lookups[table_index.to_int()][start:end]
}

///|
fn OtMap::stage_lookup_range(
  self : OtMap,
  table_index : TableIndex,
  stage : Int,
) -> (Int, Int) {
  let stages = self.stages[table_index.to_int()]
  let lookups = self.lookups[table_index.to_int()]
  let start = if stage >= 1 { stages[stage - 1].last_lookup } else { 0 }
  let end = if stage < stages.length() {
    stages[stage].last_lookup
  } else {
    lookups.length()
  }
  (start, end)
}

// hb_ot_map_feature_flags_t

///|
const F_NONE : Int = 0x0000

///|
/// Feature applies to all characters; results in no mask allocated for it.
const F_GLOBAL : Int = 0x0001

///|
/// Has fallback implementation, so include mask bit even if feature not found.
const F_HAS_FALLBACK : Int = 0x0002

///|
/// Don't skip over ZWNJ when matching **context**.
const F_MANUAL_ZWNJ : Int = 0x0004

///|
/// Don't skip over ZWJ when matching **input**.
const F_MANUAL_ZWJ : Int = 0x0008

///|
const F_MANUAL_JOINERS : Int = 0x000C

///|
const F_GLOBAL_MANUAL_JOINERS : Int = 0x000D

///|
const F_GLOBAL_HAS_FALLBACK : Int = 0x0003

///|
/// If feature not found in LangSys, look for it in global feature list and
/// pick one.
const F_GLOBAL_SEARCH : Int = 0x0010

///|
/// Randomly select a glyph from an AlternateSubstFormat1 subtable.
const F_RANDOM : Int = 0x0020

///|
/// Contain lookup application to within syllable.
const F_PER_SYLLABLE : Int = 0x0040

///|
priv struct OtMapBuilder {
  face : Face
  found_script : FixedArray[Bool]
  script_index : FixedArray[Int?]
  chosen_script : FixedArray[@otf.Tag?]
  lang_index : FixedArray[Int?]
  current_stage : FixedArray[Int]
  feature_infos : Array[FeatureInfo]
  stages : FixedArray[Array[StageInfo]]
  mut is_simple : Bool
}

///|
priv struct FeatureInfo {
  tag : @otf.Tag
  // sequence number, used for stable sorting only
  seq : Int
  mut max_value : UInt
  mut flags : Int
  // for non-global features, what should the unset glyphs take
  mut default_value : UInt
  // GSUB/GPOS
  stage : FixedArray[Int]
}

///|
fn FeatureInfo::copy(self : FeatureInfo) -> FeatureInfo {
  { ..self, stage: [self.stage[0], self.stage[1]], }
}

///|
priv struct StageInfo {
  index : Int
  pause_func : PauseFunc?
}

///|
const GLOBAL_BIT_SHIFT : Int = 31 // 8 * u32::SIZE - 1

///|
const GLOBAL_BIT_MASK : UInt = 0x80000000 // 1 << GLOBAL_BIT_SHIFT

///|
fn OtMapBuilder::new(
  face : Face,
  script : Script?,
  language : Language?,
) -> OtMapBuilder {
  // Fetch script/language indices for GSUB/GPOS.  We need these later to skip
  // features not available in either table and not waste precious bits for them.
  let (script_tags, lang_tags) = tags_from_script_and_language(script, language)
  let found_script : FixedArray[Bool] = [false, false]
  let script_index : FixedArray[Int?] = [None, None]
  let chosen_script : FixedArray[@otf.Tag?] = [None, None]
  let lang_index : FixedArray[Int?] = [None, None]
  for entry in face.layout_tables() {
    let (table_index, table) = entry
    let ti = table_index.to_int()
    if layout_select_script(table, script_tags) is Some((found, idx, tag)) {
      chosen_script[ti] = Some(tag)
      found_script[ti] = found
      script_index[ti] = Some(idx)
      if layout_select_script_language(table, idx, lang_tags) is Some(idx) {
        lang_index[ti] = Some(idx)
      }
    }
  }
  {
    face,
    found_script,
    script_index,
    chosen_script,
    lang_index,
    current_stage: [0, 0],
    feature_infos: [],
    stages: [[], []],
    is_simple: false,
  }
}

///|
fn OtMapBuilder::chosen_script(
  self : OtMapBuilder,
  table_index : TableIndex,
) -> @otf.Tag? {
  self.chosen_script[table_index.to_int()]
}

///|
fn OtMapBuilder::has_feature(self : OtMapBuilder, tag : @otf.Tag) -> Bool {
  for entry in self.face.layout_tables() {
    let (table_index, table) = entry
    if self.script_index[table_index.to_int()] is Some(script_index) {
      if layout_find_language_feature(
          table,
          script_index,
          self.lang_index[table_index.to_int()],
          tag,
        )
        is Some(_) {
        return true
      }
    }
  }
  false
}

///|
fn OtMapBuilder::add_feature(
  self : OtMapBuilder,
  tag : @otf.Tag,
  flags : Int,
  value : UInt,
) -> Unit {
  if !tag.is_null() {
    let seq = self.feature_infos.length()
    self.feature_infos.push({
      tag,
      seq,
      max_value: value,
      flags,
      default_value: if (flags & F_GLOBAL) != 0 {
        value
      } else {
        0
      },
      stage: [self.current_stage[0], self.current_stage[1]],
    })
  }
}

///|
fn OtMapBuilder::enable_feature(
  self : OtMapBuilder,
  tag : @otf.Tag,
  flags : Int,
  value : UInt,
) -> Unit {
  self.add_feature(tag, flags | F_GLOBAL, value)
}

///|
fn OtMapBuilder::disable_feature(self : OtMapBuilder, tag : @otf.Tag) -> Unit {
  self.add_feature(tag, F_GLOBAL, 0)
}

///|
fn OtMapBuilder::add_gsub_pause(
  self : OtMapBuilder,
  pause : PauseFunc?,
) -> Unit {
  self.add_pause(GSUB, pause)
}

///|
fn OtMapBuilder::add_gpos_pause(
  self : OtMapBuilder,
  pause : PauseFunc?,
) -> Unit {
  self.add_pause(GPOS, pause)
}

///|
fn OtMapBuilder::add_pause(
  self : OtMapBuilder,
  table_index : TableIndex,
  pause : PauseFunc?,
) -> Unit {
  let ti = table_index.to_int()
  self.stages[ti].push({ index: self.current_stage[ti], pause_func: pause, })
  self.current_stage[ti] += 1
}

///|
fn OtMapBuilder::compile(self : OtMapBuilder) -> OtMap {
  // We default to applying required feature in stage 0.  If the required
  // feature has a tag that is known to the shaper, we apply required feature
  // in the stage for that tag.
  let required_index : FixedArray[Int?] = [None, None]
  let required_tag : FixedArray[@otf.Tag?] = [None, None]
  for entry in self.face.layout_tables() {
    let (table_index, table) = entry
    let ti = table_index.to_int()
    if self.script_index[ti] is Some(script) {
      let lang = self.lang_index[ti]
      if layout_get_required_language_feature(table, script, lang)
        is Some((idx, tag)) {
        required_index[ti] = Some(idx)
        required_tag[ti] = Some(tag)
      }
    }
  }
  let (features, required_stage, global_mask) = self.collect_feature_maps(
    required_tag,
  )
  self.add_gsub_pause(None)
  self.add_gpos_pause(None)
  let (lookups, stages) = self.collect_lookup_stages(
    features, required_index, required_stage,
  )
  {
    found_script: [self.found_script[0], self.found_script[1]],
    chosen_script: [self.chosen_script[0], self.chosen_script[1]],
    global_mask,
    features,
    lookups,
    stages,
  }
}

///|
fn leading_zeros_u32(v : UInt) -> Int {
  v.clz()
}

///|
fn OtMapBuilder::collect_feature_maps(
  self : OtMapBuilder,
  required_tag : FixedArray[@otf.Tag?],
) -> (Array[FeatureMap], FixedArray[Int], UInt) {
  let map_features : Array[FeatureMap] = []
  let required_stage : FixedArray[Int] = [0, 0]
  let mut global_mask = GLOBAL_BIT_MASK
  let mut next_bit = GLYPH_FLAG_DEFINED.popcnt() + 1

  // Sort features and merge duplicates.
  self.dedup_feature_infos()
  for info in self.feature_infos {
    let bits_needed = if (info.flags & F_GLOBAL) != 0 && info.max_value == 1 {
      // Uses the global bit.
      0
    } else {
      // Limit bits per feature.
      let v = info.max_value
      let num_bits = 32 - leading_zeros_u32(v)
      imin(MAX_BITS, num_bits)
    }
    if info.max_value == 0 || next_bit + bits_needed >= GLOBAL_BIT_SHIFT {
      // Feature disabled, or not enough bits.
      continue
    }
    let mut found = false
    let feature_index : FixedArray[Int?] = [None, None]
    for entry in self.face.layout_tables() {
      let (table_index, table) = entry
      let ti = table_index.to_int()
      if required_tag[ti] == Some(info.tag) {
        required_stage[ti] = info.stage[ti]
      }
      if self.script_index[ti] is Some(script) {
        let lang = self.lang_index[ti]
        if layout_find_language_feature(table, script, lang, info.tag)
          is Some(idx) {
          feature_index[ti] = Some(idx)
          found = true
        }
      }
    }
    if !found && (info.flags & F_GLOBAL_SEARCH) != 0 {
      // hb_ot_layout_table_find_feature
      for entry in self.face.layout_tables() {
        let (table_index, table) = entry
        if table.features.index(info.tag) is Some(idx) {
          feature_index[table_index.to_int()] = Some(idx.to_int())
          found = true
        }
      }
    }
    if !found && (info.flags & F_HAS_FALLBACK) == 0 {
      continue
    }
    let (shift, mask) = if (info.flags & F_GLOBAL) != 0 && info.max_value == 1 {
      // Uses the global bit
      (GLOBAL_BIT_SHIFT, GLOBAL_BIT_MASK)
    } else {
      let shift = next_bit
      let mask = (1U << (next_bit + bits_needed)) - (1U << next_bit)
      next_bit += bits_needed
      global_mask = global_mask | ((info.default_value << shift) & mask)
      (shift, mask)
    }
    map_features.push({
      tag: info.tag,
      index: feature_index,
      stage: [info.stage[0], info.stage[1]],
      shift,
      mask,
      one_mask: (1U << shift) & mask,
      auto_zwnj: (info.flags & F_MANUAL_ZWNJ) == 0,
      auto_zwj: (info.flags & F_MANUAL_ZWJ) == 0,
      random: (info.flags & F_RANDOM) != 0,
      per_syllable: (info.flags & F_PER_SYLLABLE) != 0,
    })
  }
  if self.is_simple {
    // Stable sort by tag.
    stable_sort_by(map_features, 0, map_features.length(), (a, b) => {
      a.tag.compare(b.tag)
    })
  }
  (map_features, required_stage, global_mask)
}

///|
/// A stable sort of `v[start:end]` (Rust's `slice::sort_by`).
fn[T] stable_sort_by(
  v : Array[T],
  start : Int,
  end : Int,
  cmp : (T, T) -> Int,
) -> Unit {
  for i in (start + 1)..<end {
    let x = v[i]
    let mut j = i
    while j > start && cmp(v[j - 1], x) > 0 {
      v[j] = v[j - 1]
      j -= 1
    }
    v[j] = x
  }
}

///|
fn OtMapBuilder::dedup_feature_infos(self : OtMapBuilder) -> Unit {
  let feature_infos = self.feature_infos
  if feature_infos.is_empty() {
    return
  }
  if !self.is_simple {
    // The derived `Ord` of `feature_info_t`: (tag, seq, ...); seq is unique.
    stable_sort_by(feature_infos, 0, feature_infos.length(), (a, b) => {
      let c = a.tag.compare(b.tag)
      if c != 0 {
        c
      } else {
        a.seq.compare(b.seq)
      }
    })
  }
  let mut j = 0
  for i in 1..<feature_infos.length() {
    if feature_infos[i].tag != feature_infos[j].tag {
      j += 1
      feature_infos[j] = feature_infos[i].copy()
    } else {
      let fi = feature_infos[i]
      let fj = feature_infos[j]
      if (fi.flags & F_GLOBAL) != 0 {
        fj.flags = fj.flags | F_GLOBAL
        fj.max_value = fi.max_value
        fj.default_value = fi.default_value
      } else {
        if (fj.flags & F_GLOBAL) != 0 {
          fj.flags = fj.flags ^ F_GLOBAL
        }
        fj.max_value = if fj.max_value > fi.max_value {
          fj.max_value
        } else {
          fi.max_value
        }
        // Inherit default_value from j
      }
      let flags = fi.flags & F_HAS_FALLBACK
      fj.flags = fj.flags | flags
      fj.stage[0] = imin(fj.stage[0], fi.stage[0])
      fj.stage[1] = imin(fj.stage[1], fi.stage[1])
    }
  }
  feature_infos.truncate(j + 1)
}

///|
fn OtMapBuilder::collect_lookup_stages(
  self : OtMapBuilder,
  map_features : Array[FeatureMap],
  required_feature_index : FixedArray[Int?],
  required_feature_stage : FixedArray[Int],
) -> (FixedArray[Array[LookupMap]], FixedArray[Array[StageMap]]) {
  let map_lookups : FixedArray[Array[LookupMap]] = [[], []]
  let map_stages : FixedArray[Array[StageMap]] = [[], []]
  for table_index in [TableIndex::GSUB, TableIndex::GPOS] {
    let ti = table_index.to_int()
    // Collect lookup indices for features.
    let mut stage_index = 0
    let mut last_lookup = 0
    let coords = self.face.variation_coordinates()
    let variation_index = match self.face.layout_table(table_index) {
      Some(t) =>
        match t.variations {
          Some(v) => v.find_index(coords)
          None => None
        }
      None => None
    }
    for stage in 0..<self.current_stage[ti] {
      if required_feature_index[ti] is Some(feature_index) {
        if required_feature_stage[ti] == stage {
          self.add_lookups(
            map_lookups[ti],
            table_index,
            feature_index,
            variation_index,
            GLOBAL_BIT_MASK,
            true,
            true,
            false,
            false,
          )
          |> ignore
        }
      }
      for feature in map_features {
        if feature.index[ti] is Some(feature_index) {
          if feature.stage[ti] == stage {
            self.add_lookups(
              map_lookups[ti],
              table_index,
              feature_index,
              variation_index,
              feature.mask,
              feature.auto_zwnj,
              feature.auto_zwj,
              feature.random,
              feature.per_syllable,
            )
            |> ignore
          }
        }
      }

      // Sort lookups and merge duplicates.
      let lookups = map_lookups[ti]
      let len = lookups.length()
      if last_lookup + 1 < len {
        stable_sort_by(lookups, last_lookup, len, (a, b) => a.cmp(b))
        let mut j = last_lookup
        for i in (j + 1)..<len {
          if lookups[i].index != lookups[j].index {
            j += 1
            lookups[j] = lookups[i].copy()
          } else {
            lookups[j].mask = lookups[j].mask | lookups[i].mask
            lookups[j].auto_zwnj = lookups[j].auto_zwnj && lookups[i].auto_zwnj
            lookups[j].auto_zwj = lookups[j].auto_zwj && lookups[i].auto_zwj
          }
        }
        lookups.truncate(j + 1)
      }
      last_lookup = lookups.length()
      if stage_index < self.stages[ti].length() {
        let info = self.stages[ti][stage_index]
        if info.index == stage {
          map_stages[ti].push({ last_lookup, pause_func: info.pause_func, })
          stage_index += 1
        }
      }
    }
  }
  (map_lookups, map_stages)
}

///|
fn OtMapBuilder::add_lookups(
  self : OtMapBuilder,
  lookups : Array[LookupMap],
  table_index : TableIndex,
  feature_index : Int,
  variation_index : UInt?,
  mask : UInt,
  auto_zwnj : Bool,
  auto_zwj : Bool,
  random : Bool,
  per_syllable : Bool,
) -> Unit? {
  guard self.face.layout_table(table_index) is Some(table) else { return None }
  let lookup_count = table.lookups.len().to_int()
  let feature : @otf.Feature = match variation_index {
    Some(idx) => {
      let sub = match table.variations {
        Some(vars) => vars.find_substitute(feature_index.to_uint16(), idx)
        None => None
      }
      match sub {
        Some(f) => f
        None =>
          match table.features.get(feature_index.to_uint16()) {
            Some(f) => f
            None => return None
          }
      }
    }
    None =>
      match table.features.get(feature_index.to_uint16()) {
        Some(f) => f
        None => return None
      }
  }
  for index in feature.lookup_indices.iter() {
    let index = index.to_int()
    if index < lookup_count {
      lookups.push({ mask, index, auto_zwnj, auto_zwj, random, per_syllable, })
    }
  }
  Some(())
}
