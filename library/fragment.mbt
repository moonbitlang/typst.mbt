// Port of `typst-library/src/layout/fragment.rs`.

///|
/// A partial layout result.
pub struct Fragment(Array[Frame])

///|
/// Create a fragment from a single frame.
pub fn Fragment::frame(frame : Frame) -> Fragment {
  Fragment([frame])
}

///|
/// Create a fragment from multiple frames.
pub fn Fragment::frames(frames : Array[Frame]) -> Fragment {
  Fragment(frames)
}

///|
/// Return `true` if the length is 0.
pub fn Fragment::is_empty(self : Fragment) -> Bool {
  self.0.is_empty()
}

///|
/// The number of frames in the fragment.
pub fn Fragment::len(self : Fragment) -> Int {
  self.0.length()
}

///|
/// Extract the first and only frame.
///
/// Panics if there are multiple frames.
pub fn Fragment::into_frame(self : Fragment) -> Frame {
  guard self.0.length() == 1 else { abort("expected exactly one frame") }
  self.0[0]
}

///|
/// Extract the frames.
pub fn Fragment::into_frames(self : Fragment) -> Array[Frame] {
  self.0
}

///|
/// Extract a slice with the contained frames.
pub fn Fragment::as_slice(self : Fragment) -> ArrayView[Frame] {
  self.0[:]
}

///|
/// Iterate over the contained frames (frames are mutable objects, so this
/// also serves as upstream `iter_mut`).
pub fn Fragment::iter(self : Fragment) -> Iter[Frame] {
  self.0.iter()
}
