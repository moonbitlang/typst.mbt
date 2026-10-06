// Port of `hayro-interpret/src/soft_mask.rs`.

///|
/// Type type of mask.
pub(all) enum MaskType {
  /// A luminosity mask.
  Luminosity
  /// An alpha mask.
  Alpha
} derive(Eq, Debug)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MaskType with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend MaskType with @debug.Debug::{to_repr}

///|
/// A transfer function to apply to the opacity values of a mask.
pub struct TransferFunction(@function.Function)

///|
/// Apply the transfer function to the given value.
///
/// The input value needs to be between 0 and 1 and the return value is
/// guaranteed to be between 0 and 1.
pub fn TransferFunction::apply(self : TransferFunction, val : Float) -> Float {
  let v = match self.0.eval([val]) {
    Some(v) if v.length() > 0 => v[0]
    _ => 0.0
  }
  f32_clamp(v, 0.0, 1.0)
}

///|
priv struct SoftMaskRepr {
  obj_id : @hayro_syntax.ObjectIdentifier
  group : FormXObject
  mask_type : MaskType
  parent_resources : @hayro_syntax.Resources
  root_transform : @kurbo.Affine
  bbox : @kurbo.Rect
  interpreter_cache : InterpreterCache
  transfer_function : TransferFunction?
  settings : InterpreterSettings
  background : Color
  xref : @hayro_syntax.XRef
  nesting_depth : Int
}

///|
/// A soft mask.
pub struct SoftMask {
  priv repr : SoftMaskRepr
}

///|
pub impl Eq for SoftMask with fn equal(self, other) {
  self.repr.obj_id == other.repr.obj_id
}

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SoftMask with Eq::{not_equal, equal}

///|
pub impl CacheKey for SoftMask with fn cache_key(self) {
  // Upstream hashes the object id and the root transform's cache key.
  let root = CacheKey::cache_key(self.repr.root_transform)
  hash128(h => {
    h.write_u32(self.repr.obj_id.obj_number.reinterpret_as_uint())
    h.write_u32(self.repr.obj_id.gen_number.reinterpret_as_uint())
    h.write_u128(root)
  })
}

///|
#deprecated("call as `CacheKey::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend SoftMask with CacheKey::{cache_key}

///|
fn SoftMask::new(
  dict : @hayro_syntax.Dict,
  context : Context,
  parent_resources : @hayro_syntax.Resources,
) -> SoftMask? {
  // TODO: With this setup, if there is a luminosity mask and alpha mask pointing to the
  // same xobject, the ID will be the same.
  guard dict.get_ref("G") is Some(g_ref) else { return None }
  let obj_id = g_ref.to_id()
  guard (dict.get("G") : @hayro_syntax.Stream?) is Some(group_stream) else {
    return None
  }
  guard FormXObject::new(group_stream) is Some(group) else { return None }
  guard (group.dict.get("Group") : @hayro_syntax.Dict?) is Some(group_dict) else {
    return None
  }
  guard (group_dict.get("CS") : @hayro_syntax.Object?) is Some(cs_obj) else {
    return None
  }
  guard ColorSpace::new(cs_obj, context.interpreter_cache.object_cache)
    is Some(cs) else {
    return None
  }
  let transfer_function = match (dict.get("TR") : @hayro_syntax.Object?) {
    Some(o) =>
      match @function.Function::new(o) {
        Some(f) => Some(TransferFunction(f))
        None => None
      }
    None => None
  }
  guard (dict.get("S") : @hayro_syntax.Name?) is Some(s) else { return None }
  let (mask_type, background) = match s.as_str() {
    "Luminosity" => {
      let color = match (dict.get("BC") : @hayro_syntax.PdfArray?) {
        Some(arr) => Color::new(cs, read_f32_array(arr), 1.0)
        None => Color::new(ColorSpace::device_gray(), [0.0], 1.0)
      }
      (MaskType::Luminosity, color)
    }
    "Alpha" =>
      (
        MaskType::Alpha,
        // Background color attribute should only be used with luminosity masks.
        Color::new(ColorSpace::device_gray(), [0.0], 1.0),
      )
    _ => return None
  }
  let nesting_depth = context.nesting_depth() + 1
  Some({
    repr: {
      obj_id,
      group,
      mask_type,
      root_transform: context.get().ctm,
      transfer_function,
      bbox: context.bbox(),
      interpreter_cache: context.interpreter_cache,
      settings: context.settings,
      xref: context.xref,
      background,
      parent_resources,
      nesting_depth,
    },
  })
}

///|
/// Read an array of numbers (upstream `get::<SmallVec<[f32; N]>>`, which
/// collects the leading items that are numbers).
fn read_f32_array(arr : @hayro_syntax.PdfArray) -> Array[Float] {
  (arr.iter() : Iter[Float]).collect()
}

///|
/// Interpret the contents of the mask into the given device.
pub fn SoftMask::interpret(self : SoftMask, device : &Device) -> Unit {
  let r = self.repr
  let state = State::new(r.root_transform)
  let ctx = Context::new_with(
    r.root_transform,
    r.bbox,
    r.interpreter_cache,
    r.xref,
    r.settings,
    state,
    r.nesting_depth,
  )
  draw_form_xobject(r.parent_resources, r.group, ctx, device)
}

///|
/// Return the object identifier of the mask.
///
/// This can be used as a unique identifier for caching purposes.
pub fn SoftMask::id(self : SoftMask) -> @hayro_syntax.ObjectIdentifier {
  self.repr.obj_id
}

///|
/// Return the underlying mask type.
pub fn SoftMask::mask_type(self : SoftMask) -> MaskType {
  self.repr.mask_type
}

///|
/// The background color against which the mask should be composited.
pub fn SoftMask::background_color(self : SoftMask) -> Color {
  self.repr.background
}

///|
/// Return the transfer function that should be used for the mask.
pub fn SoftMask::transfer_function(self : SoftMask) -> TransferFunction? {
  self.repr.transfer_function
}
