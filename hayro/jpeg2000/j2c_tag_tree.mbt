// Port of `hayro-jpeg2000/src/j2c/tag_tree.rs`: the tag tree, described in
// Section B.10.2.
//
// Tag trees are quad trees where each leaf stores an integer value.
// Each intermediate node stores the smallest value of all of its children.
// For example, if a node stores the value 3, it means that all children
// have a value of 3 or higher. The root node therefore stores the smallest
// values across all children.

///|
priv struct TagNode {
  /// The width of the area covered by the node.
  ///
  /// For leaf nodes, this value is always 1. In some cases, the width might
  /// be 0, in which case the leaf node doesn't actually "exist" and is just
  /// a dummy node.
  width : UInt
  /// The height of the area covered by the node.
  ///
  /// For leaf nodes, this value is always 1. In some cases, the height might
  /// be 0, in which case the leaf node doesn't actually "exist" and is just
  /// a dummy node.
  height : UInt
  /// The actual value stored in the node. Only valid once `initialized`
  /// is set to `true`.
  mut value : UInt
  /// Whether the node has been fully initialized. The tag tree is not
  /// stored in its complete form in the JP2 file, but is instead built
  /// up incrementally, each packet contributing the information of the
  /// tag tree. The node is therefore only initialized with its actual
  /// value once we cross it the first time.
  mut initialized : Bool
  /// The level inside the tree. Zero indicates that the given node is
  /// a leaf node, otherwise the level is > 0. The root node has the highest
  /// level.
  level : Int
  /// The indices of the children of the node, some of which might be dummy
  /// nodes (indicated by the fact that the index is `usize::MAX`, here -1).
  children : FixedArray[Int]
}

///|
fn TagNode::new(width : UInt, height : UInt, level : Int) -> TagNode {
  {
    width,
    height,
    level,
    value: 0,
    initialized: false,
    children: FixedArray::make(4, -1),
  }
}

///|
/// The width of the top-left child.
fn TagNode::top_left_width(self : TagNode) -> UInt {
  min_u32(shl_u32(1, self.level - 1), self.width)
}

///|
/// The height of the top-left child.
fn TagNode::top_left_height(self : TagNode) -> UInt {
  min_u32(shl_u32(1, self.level - 1), self.height)
}

///|
fn TagNode::build(
  width : UInt,
  height : UInt,
  level : Int,
  nodes : Array[TagNode],
) -> TagNode {
  let tag = TagNode::new(width, height, level)
  if level == 0 {
    // We reached the leaf node.
    if !(width <= 1 && height <= 1) {
      abort("assertion failed: width <= 1 && height <= 1")
    }
    return tag
  }

  // Determine the width and height of the top-left child node. Based
  // on this, we can infer the dimensions of all other child nodes.
  let top_left_width = tag.top_left_width()
  let top_left_height = tag.top_left_height()
  fn push(node : TagNode, child_idx : Int) {
    // If this is not the case, the child doesn't actually exist.
    if node.width > 0 && node.height > 0 {
      let node_idx = nodes.length()
      nodes.push(node)
      tag.children[child_idx] = node_idx
    }
  }

  // We always push four children, but some nodes might in reality have
  // fewer than that. In this case, the resulting node will simply have
  // a width or height of 0 and we can recognize that it technically
  // doesn't exist.
  let n1 = TagNode::build(top_left_width, top_left_height, level - 1, nodes)
  push(n1, 0)
  let n2 = TagNode::build(
    width - top_left_width,
    top_left_height,
    level - 1,
    nodes,
  )
  push(n2, 1)
  let n3 = TagNode::build(
    top_left_width,
    height - top_left_height,
    level - 1,
    nodes,
  )
  push(n3, 2)
  let n4 = TagNode::build(
    width - top_left_width,
    height - top_left_height,
    level - 1,
    nodes,
  )
  push(n4, 3)
  tag
}

///|
fn read_tag_node(
  node_idx : Int,
  x : UInt,
  y : UInt,
  reader : BitReader,
  parent_val : UInt,
  max_val : UInt,
  nodes : Array[TagNode],
) -> UInt? {
  let node = nodes[node_idx]
  if !node.initialized {
    let mut val = max_u32(parent_val, node.value)
    while true {
      if val >= max_val {
        break
      }

      // "Each node has an associated current value, which is
      // initialized to zero (the minimum). A 0 bit in the tag tree
      // means that the minimum (or the value in the case of the
      // highest level) is larger than the current value and a 1 bit
      // means that the minimum (or the value in the case of the
      // highest level) is equal to the current value."
      guard reader.read_bits_with_stuffing(1) is Some(bit) else { return None }
      if bit == 0 {
        val = val + 1
      } else {
        node.initialized = true
        break
      }
    }
    node.value = val
  }

  // Abort early if we already reached the leaf node or the minimum
  // value of all children is too large.
  if node.value >= max_val || node.level == 0 {
    return Some(node.value)
  }
  let top_left_width = node.top_left_width()
  let top_left_height = node.top_left_height()
  let left = x < top_left_width
  let top = y < top_left_height
  match (left, top) {
    (true, true) =>
      read_tag_node(node.children[0], x, y, reader, node.value, max_val, nodes)
    (false, true) =>
      read_tag_node(
        node.children[1],
        x - top_left_width,
        y,
        reader,
        node.value,
        max_val,
        nodes,
      )
    (true, false) =>
      read_tag_node(
        node.children[2],
        x,
        y - top_left_height,
        reader,
        node.value,
        max_val,
        nodes,
      )
    (false, false) =>
      read_tag_node(
        node.children[3],
        x - top_left_width,
        y - top_left_height,
        reader,
        node.value,
        max_val,
        nodes,
      )
  }
}

///|
// `width` and `height` are only read by upstream's `debug_assert!(x <
// self.width && y < self.height)` (hayro-jpeg2000/src/j2c/tag_tree.rs:234),
// which is not ported (release builds do not check it).
#warnings("-unused_field")
priv struct TagTree {
  root : Int
  width : UInt
  height : UInt
}

///|
fn TagTree::new(width : UInt, height : UInt, nodes : Array[TagNode]) -> TagTree {
  // Calculate how many levels the tree has in total.
  let wl = ilog2_u32(next_power_of_two_u32(width))
  let hl = ilog2_u32(next_power_of_two_u32(height))
  let level = if wl > hl { wl } else { hl }
  let node = TagNode::build(width, height, level & 0xFFFF, nodes)
  let idx = nodes.length()
  nodes.push(node)
  { root: idx, width, height, }
}

///|
fn TagTree::read(
  self : TagTree,
  x : UInt,
  y : UInt,
  reader : BitReader,
  max_val : UInt,
  nodes : Array[TagNode],
) -> UInt? {
  read_tag_node(self.root, x, y, reader, 0, max_val, nodes)
}

///|
/// `u32::next_power_of_two` (0 maps to 1; overflow wraps to 0 in release).
fn next_power_of_two_u32(v : UInt) -> UInt {
  if v <= 1 {
    1
  } else {
    let shift = 32 - (v - 1).clz()
    if shift >= 32 {
      0
    } else {
      1U << shift
    }
  }
}

///|
/// `u32::ilog2` (`v` must not be zero).
fn ilog2_u32(v : UInt) -> Int {
  31 - v.clz()
}
