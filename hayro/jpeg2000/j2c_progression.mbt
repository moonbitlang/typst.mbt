// Port of `hayro-jpeg2000/src/j2c/progression.rs`: progression iterators,
// defined in Section B.12.
//
// A progression iterator essentially yields tuples of
// (`layer_num`, resolution, component, precinct) in a specific order that
// determines in which order the data appears in the codestream.
//
// Iterators are closures returning `None` once exhausted.

///|
priv struct ProgressionData {
  layer_num : Int
  resolution : Int
  component : Int
  precinct : UInt64
}

///|
priv struct IteratorInput {
  layers : (Int, Int)
  tile : Tile
  resolutions : (Int, Int)
  components : (Int, Int)
}

///|
fn IteratorInput::new(tile : Tile) -> IteratorInput {
  IteratorInput::new_with_custom_bounds(
    tile,
    // Will be clamped automatically.
    (0, 0xFF),
    (0, 0xFF),
    (0, 0xFF),
  )
}

///|
fn IteratorInput::new_with_custom_bounds(
  tile : Tile,
  resolutions : (Int, Int),
  layers : (Int, Int),
  components : (Int, Int),
) -> IteratorInput {
  let mut max_resolution = 0
  for c in tile.component_infos {
    if c.coding_style.parameters.num_resolution_levels > max_resolution {
      max_resolution = c.coding_style.parameters.num_resolution_levels
    }
  }
  let max_layer = tile.num_layers
  let max_component = tile.component_infos.length() & 0xFF

  // Make sure we don't exceed what's actually possible
  let resolutions = (
    resolutions.0,
    if resolutions.1 < max_resolution {
      resolutions.1
    } else {
      max_resolution
    },
  )
  let layers = (
    layers.0,
    if layers.1 < max_layer {
      layers.1
    } else {
      max_layer
    },
  )
  let components = (
    components.0,
    if components.1 < max_component {
      components.1
    } else {
      max_component
    },
  )
  if !(resolutions.1 > resolutions.0) {
    abort("assertion failed: resolutions.1 > resolutions.0")
  }
  if !(layers.1 > layers.0) {
    abort("assertion failed: layers.1 > layers.0")
  }
  if !(components.1 > components.0) {
    abort("assertion failed: components.1 > components.0")
  }
  { layers, tile, resolutions, components, }
}

///|
fn IteratorInput::min_layer(self : IteratorInput) -> Int {
  self.layers.0
}

///|
fn IteratorInput::max_layer(self : IteratorInput) -> Int {
  self.layers.1
}

///|
fn IteratorInput::min_resolution(self : IteratorInput) -> Int {
  self.resolutions.0
}

///|
fn IteratorInput::total_max_resolution(self : IteratorInput) -> Int {
  self.resolutions.1
}

///|
fn IteratorInput::max_resolution(
  self : IteratorInput,
  component_idx : Int,
) -> Int {
  // It's possible that the different component tiles have different resolution levels
  // (self.resolutions.1 stores the maximum across all component tiles), so
  // take the minimum of both.
  let a = self.total_max_resolution()
  let b = self.tile.component_infos[component_idx].num_resolution_levels()
  if a < b {
    a
  } else {
    b
  }
}

///|
fn IteratorInput::min_comp(self : IteratorInput) -> Int {
  self.components.0
}

///|
fn IteratorInput::max_comp(self : IteratorInput) -> Int {
  self.components.1
}

///|
fn IteratorInput::component_tiles(self : IteratorInput) -> Array[ComponentTile] {
  self.tile.component_infos.map(c => ComponentTile::new(self.tile, c))
}

///|
/// B.12.1.1 Layer-resolution level-component-position progression.
fn layer_resolution_component_position_progression(
  input : IteratorInput,
) -> () -> ProgressionData? {
  let component_tiles = input.component_tiles()
  let mut layer = input.min_layer()
  let mut resolution = input.min_resolution()
  let mut component_idx = input.min_comp()
  let mut resolution_tile = ResolutionTile::new(component_tiles[0], resolution)
  let mut precinct = 0UL
  fn() {
    if layer == input.max_layer() || resolution == input.total_max_resolution() {
      return None
    }
    if precinct == resolution_tile.num_precincts() {
      while true {
        precinct = 0
        component_idx = (component_idx + 1) & 0xFF
        if component_idx == input.max_comp() {
          component_idx = input.min_comp()
          resolution = (resolution + 1) & 0xFF
          if resolution == input.max_resolution(component_idx) {
            resolution = input.min_resolution()
            layer = (layer + 1) & 0xFF
            if layer == input.max_layer() {
              return None
            }
          }
        }
        resolution_tile = ResolutionTile::new(
          component_tiles[component_idx],
          resolution,
        )

        // Only yield if the resolution tile has precincts, otherwise
        // we need to keep advancing.
        if resolution_tile.num_precincts() != 0 {
          break
        }
      }
    }
    let data = {
      layer_num: layer,
      resolution,
      component: component_idx,
      precinct,
    }
    precinct += 1
    Some(data)
  }
}

///|
/// B.12.1.2 Resolution level-layer-component-position progression.
fn resolution_layer_component_position_progression(
  input : IteratorInput,
) -> () -> ProgressionData? {
  let component_tiles = input.component_tiles()
  let mut layer = 0
  let mut resolution = 0
  let mut component_idx = 0
  let mut resolution_tile = ResolutionTile::new(
    component_tiles[component_idx],
    resolution,
  )
  let mut precinct = 0UL
  fn() {
    if layer == input.max_layer() || resolution == input.total_max_resolution() {
      return None
    }
    if precinct == resolution_tile.num_precincts() {
      while true {
        precinct = 0
        component_idx = (component_idx + 1) & 0xFF
        if component_idx == input.max_comp() {
          component_idx = 0
          layer = (layer + 1) & 0xFF
          if layer == input.max_layer() {
            layer = 0
            resolution = (resolution + 1) & 0xFF
            if resolution == input.total_max_resolution() {
              return None
            }
          }
        }

        // If the given resolution level doesn't exist for the current
        // component, continue.
        if resolution >= input.max_resolution(component_idx) {
          continue
        }
        resolution_tile = ResolutionTile::new(
          component_tiles[component_idx],
          resolution,
        )

        // Only yield if the resolution tile has precincts, otherwise
        // we need to keep advancing.
        if resolution_tile.num_precincts() != 0 {
          break
        }
      }
    }
    let data = {
      layer_num: layer,
      resolution,
      component: component_idx,
      precinct,
    }
    precinct += 1
    Some(data)
  }
}

// The formula for the remaining three progressions looks very intimidating.
// But really, all they boil down to is that we need to determine all precinct
// indices for each component/resolution combination and sort them by ascending
// y/x coordinate on the reference grid. Other than that, they can be treated
// exactly the same, except that the sort order precedence of the fields change.

///|
// Note that the order of fields here is important!
priv struct PrecinctStore {
  resolution : Int
  precinct_y : UInt
  precinct_x : UInt
  component_idx : Int
  precinct_idx : UInt64
}

///|
fn position_progression_common(
  input : IteratorInput,
  sort : (PrecinctStore, PrecinctStore) -> Int,
) -> (() -> ProgressionData?)? {
  let elements : Array[PrecinctStore] = []
  let component_tiles = input.tile.component_tiles()
  let comp_end = input.max_comp()
  for component_idx in input.min_comp()..<comp_end {
    if component_idx >= component_tiles.length() {
      break
    }
    let component = component_tiles[component_idx]
    let resolution_tiles = component.resolution_tiles()
    for resolution in input.min_resolution()..<input.total_max_resolution() {
      if resolution >= resolution_tiles.length() {
        break
      }
      guard resolution_tiles[resolution].precincts() is Some(precincts) else {
        return None
      }
      for d in precincts {
        elements.push({
          precinct_y: d.r_y,
          precinct_x: d.r_x,
          component_idx,
          resolution,
          precinct_idx: d.idx,
        })
      }
    }
  }
  // A stable sort, like Rust's `sort_by`.
  let order = Array::makei(elements.length(), i => i)
  order.sort_by((a, b) => {
    let c = sort(elements[a], elements[b])
    if c != 0 {
      c
    } else {
      a.compare(b)
    }
  })
  let mut e_idx = 0
  let mut layer = input.min_layer()
  Some(fn() {
    while e_idx < order.length() {
      if layer < input.max_layer() {
        let e = elements[order[e_idx]]
        let data = {
          layer_num: layer,
          resolution: e.resolution,
          component: e.component_idx,
          precinct: e.precinct_idx,
        }
        layer += 1
        return Some(data)
      }
      e_idx += 1
      layer = input.min_layer()
    }
    None
  })
}

///|
/// B.12.1.3 Resolution level-position-component-layer progression.
fn resolution_position_component_layer_progression(
  input : IteratorInput,
) -> (() -> ProgressionData?)? {
  position_progression_common(input, (p, s) => {
    let c = p.resolution.compare(s.resolution)
    if c != 0 {
      return c
    }
    let c = p.precinct_y.compare(s.precinct_y)
    if c != 0 {
      return c
    }
    let c = p.precinct_x.compare(s.precinct_x)
    if c != 0 {
      return c
    }
    let c = p.component_idx.compare(s.component_idx)
    if c != 0 {
      return c
    }
    p.precinct_idx.compare(s.precinct_idx)
  })
}

///|
/// B.12.1.4 Position-component-resolution level-layer progression.
fn position_component_resolution_layer_progression(
  input : IteratorInput,
) -> (() -> ProgressionData?)? {
  position_progression_common(input, (p, s) => {
    let c = p.precinct_y.compare(s.precinct_y)
    if c != 0 {
      return c
    }
    let c = p.precinct_x.compare(s.precinct_x)
    if c != 0 {
      return c
    }
    let c = p.component_idx.compare(s.component_idx)
    if c != 0 {
      return c
    }
    let c = p.resolution.compare(s.resolution)
    if c != 0 {
      return c
    }
    p.precinct_idx.compare(s.precinct_idx)
  })
}

///|
/// B.12.1.5 Component-position-resolution level-layer progression.
fn component_position_resolution_layer_progression(
  input : IteratorInput,
) -> (() -> ProgressionData?)? {
  position_progression_common(input, (p, s) => {
    let c = p.component_idx.compare(s.component_idx)
    if c != 0 {
      return c
    }
    let c = p.precinct_y.compare(s.precinct_y)
    if c != 0 {
      return c
    }
    let c = p.precinct_x.compare(s.precinct_x)
    if c != 0 {
      return c
    }
    let c = p.resolution.compare(s.resolution)
    if c != 0 {
      return c
    }
    p.precinct_idx.compare(s.precinct_idx)
  })
}
