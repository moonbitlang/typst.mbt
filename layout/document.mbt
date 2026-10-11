// Port of `typst-layout/src/document.rs`.

///|
/// A finished document with metadata and page frames.
pub struct PagedDocument {
  priv pages : Array[Page]
  priv info : @library.DocumentInfo
  priv options : @library.DocumentFormatOptions
  priv introspector : @library.Introspector
  priv paged_introspector : PagedIntrospector
}

///|
/// Creates a new paged document from its parts.
///
/// Internally builds the introspector.
pub fn PagedDocument::new(
  pages : Array[Page],
  info : @library.DocumentInfo,
  options : @library.DocumentFormatOptions,
) -> PagedDocument {
  let paged_introspector = PagedIntrospector::new(pages[:])
  {
    pages,
    info,
    options,
    introspector: @library.Introspector::new(paged_introspector),
    paged_introspector,
  }
}

///|
/// The document as an entry of a memoized layout keeps it (not upstream,
/// whose `PagedDocument: Clone` shares what cannot be written to: an
/// `EcoVec` of pages, frames with shared items, an `Arc` of the
/// introspector; `layout_document_impl` in `pages.mbt`).
///
/// Another document with other pages, whose frames are copy-on-write
/// clones, another info (its authors and keywords are arrays) and other
/// format options. The introspector is the same object: it is made once
/// from the pages as they were laid out, it answers the same for as long
/// as it lives, and what it hands out is for reading. That it is the same
/// matters: it is the introspector that the next iteration of a
/// compilation lays the document out against, and an entry computed with
/// it is found by its number (`@library.Introspector::serial`).
///
/// It is also the first half of what an entry hands out; the second is
/// [PagedDocument::owned].
fn PagedDocument::kept(self : PagedDocument) -> PagedDocument {
  {
    pages: self.pages.map(Page::kept),
    info: self.info.copy(),
    options: self.options.copy(),
    introspector: self.introspector,
    paged_introspector: self.paged_introspector,
  }
}

///|
/// The page with a copy-on-write clone of its frame (see
/// [PagedDocument::kept]).
fn Page::kept(self : Page) -> Page {
  { ..self, frame: self.frame.clone(), }
}

///|
/// The document as a memoized layout hands it to its caller, which may be
/// a host: with pages whose frames share no frame and no group with
/// anything that an entry keeps, at any depth (`@library.Frame::
/// deep_clone`).
///
/// A copy-on-write clone is not enough here. The frames of a document are
/// made of the frames that the entries of page runs, paragraphs and
/// fragments keep, pushed into one another as clones, and a clone shares
/// its groups with what it was cloned from: a holder that takes a group
/// out of `Frame::items` and writes to it (its transform, its frame)
/// would write to the kept layouts. So the document of a computation and
/// the document that an entry hands out both get frames and groups of
/// their own, all the way down; the info and the format options are
/// already the caller's ([PagedDocument::kept], or the computation's
/// own). What the items of a frame hold besides frames is shared (glyphs,
/// curves, images, the content of tags): items are values.
fn PagedDocument::owned(self : PagedDocument) -> PagedDocument {
  { ..self, pages: self.pages.map(Page::owned), }
}

///|
/// The page with a frame of its own ([PagedDocument::owned]).
fn Page::owned(self : Page) -> Page {
  { ..self, frame: self.frame.deep_clone(), }
}

///|
/// Whether the document may be kept by an entry: no frame of its pages
/// holds a host closure in its tags or in the frame of a tiling, nor does
/// a fill (`@library.frame_cacheable`, the rule of every kept layout).
fn PagedDocument::cacheable(self : PagedDocument) -> Bool {
  for page in self.pages {
    if !@library.frame_cacheable(page.frame) || !fill_cacheable(page.fill) {
      return false
    }
  }
  true
}

///|
/// The document's finished pages.
pub fn PagedDocument::pages(self : PagedDocument) -> ArrayView[Page] {
  self.pages[:]
}

///|
/// Details about the document.
pub fn PagedDocument::info(self : PagedDocument) -> @library.DocumentInfo {
  self.info
}

///|
/// Details about the document, mutably (upstream `info_mut`; the document
/// info is a mutable object).
pub fn PagedDocument::info_mut(self : PagedDocument) -> @library.DocumentInfo {
  self.info
}

///|
/// The format options set by the document.
pub fn PagedDocument::options(
  self : PagedDocument,
) -> @library.DocumentFormatOptions {
  self.options
}

///|
/// Provides the ability to execute queries on the document.
pub fn PagedDocument::introspector(
  self : PagedDocument,
) -> @library.Introspector {
  self.introspector
}

///|
/// The document's paged introspector (upstream `introspector()` returns the
/// `Arc<PagedIntrospector>`).
pub fn PagedDocument::paged_introspector(
  self : PagedDocument,
) -> PagedIntrospector {
  self.paged_introspector
}

///|
pub impl @library.Output for PagedDocument with fn introspector(self) {
  self.introspector
}

///|
pub impl @library.Output for PagedDocument with fn target() {
  Paged
}

///|
pub impl @library.Output for PagedDocument with fn create(
  engine,
  content,
  styles,
) {
  layout_document(engine, content, styles)
}

///|
// `introspector` is not named here: the type already has a method of this name.
#deprecated("call as `Output::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend PagedDocument with @library.Output::{create, target}

///|
/// A finished page.
pub(all) struct Page {
  /// The frame that defines the page.
  frame : @library.Frame
  /// The bleed amount to be added on each side of the page. The bleed is not
  /// included in frame.
  bleed : @library.Sides[@library.Abs]
  /// How the page is filled.
  ///
  /// - When `None`, the background is transparent.
  /// - When `Auto`, the background is transparent for PDF and white for
  ///   raster and SVG targets.
  ///
  /// Exporters should access the resolved value of this property through
  /// `fill_or_transparent()` or `fill_or_white()`.
  fill : @library.Smart[@library.Paint?]
  /// The page's numbering.
  numbering : @library.Numbering?
  /// The page's supplement.
  supplement : @library.Content
  /// The logical page number (controlled by `counter(page)` and may thus not
  /// match the physical number).
  number : UInt64
}

///|
/// Upstream derives `Hash` for `Page`: frame, bleed, fill, numbering,
/// supplement and number.
pub impl @library.Fingerprint for Page with fn fingerprint(self, state) {
  state.write(self.frame)
  state.write_f64(self.bleed.left.to_raw())
  state.write_f64(self.bleed.top.to_raw())
  state.write_f64(self.bleed.right.to_raw())
  state.write_f64(self.bleed.bottom.to_raw())
  match self.fill {
    Auto => state.write_discriminant(0)
    Custom(fill) => {
      state.write_discriminant(1)
      match fill {
        None => state.write_discriminant(0)
        Some(paint) => {
          state.write_discriminant(1)
          state.write(paint)
        }
      }
    }
  }
  match self.numbering {
    None => state.write_discriminant(0)
    Some(numbering) => {
      state.write_discriminant(1)
      state.write(numbering)
    }
  }
  state.write(self.supplement)
  state.write_u64(self.number)
}

///|
#deprecated("call as `Fingerprint::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Page with @library.Fingerprint::{fingerprint}

///|
/// Get the configured background or `None` if it is `Auto`.
///
/// This is used in PDF export.
pub fn Page::fill_or_transparent(self : Page) -> @library.Paint? {
  match self.fill {
    Auto => None
    Custom(fill) => fill
  }
}

///|
/// Get the configured background or white if it is `Auto`.
///
/// This is used in raster and SVG export.
pub fn Page::fill_or_white(self : Page) -> @library.Paint? {
  match self.fill {
    Auto => Some(Solid(@library.color_white))
    Custom(fill) => fill
  }
}
