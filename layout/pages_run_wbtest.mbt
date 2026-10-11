// The pages of a kept page run (`pages_run.mbt`, `layout_page_run_impl`):
// what the entry keeps is not what a caller is handed.

///|
/// A world for an engine that lays out a page without content.
priv struct RunWorld {
  library : @library.Library
}

///|
impl @library.World for RunWorld with fn library(self) {
  self.library
}

///|
impl @library.World for RunWorld with fn main(_) {
  @syntax.Source::detached("").id()
}

///|
impl @library.World for RunWorld with fn source(_, _) {
  raise @library.FileError::AccessDenied
}

///|
impl @library.World for RunWorld with fn file(_, _) {
  raise @library.FileError::AccessDenied
}

///|
impl @library.World for RunWorld with fn today(_, _) {
  None
}

///|
test "page runs: the pages that a caller is handed are not the pages that the entry keeps" {
  // `finalize_page` moves the frames of the pages it is handed into the
  // frame of a page. It does not write to them today, so that an entry
  // hands out copies cannot be seen from a document; it is seen here, by
  // a caller that does write.
  @library.evict(0)
  let routines = @library.Routines::new(
    eval_string=(_, _, _, _, _, _) => None,
    eval_closure=(_, _, _, _, _) => None,
  )
  let library = @library.Library::builder(routines, []).build()
  let world : RunWorld = { library, }
  let tracked = @library.TrackedWorld::new(world)
  let mark = (frame : @library.Frame) => {
    frame.push(
      @library.Point::zero(),
      Shape(
        @library.Geometry::Rect(
          @library.Axes::new(@library.Abs::pt(3.0), @library.Abs::pt(3.0)),
        ).filled(Solid(@library.color_white)),
        @syntax.Span::detached(),
      ),
    )
    frame.set_size(
      @library.Axes::new(@library.Abs::pt(1.0), @library.Abs::pt(1.0)),
    )
  }
  let prints = tracked.scoped(() => {
    @library.with_layout_memo(() => {
      let engine : @library.Engine = {
        library,
        world: tracked,
        introspector: @library.Introspector::empty(),
        traced: @library.Traced::new(),
        sink: @library.Sink::new(),
        route: @library.Route::root(),
      }
      let styles = @library.StyleChain::new(library.styles)
      let locator = @library.Locator::root().split().next(1)
      let before = page_run_memo_stats()
      let prints = []
      let frames = []
      // Laid out, then found twice; every caller writes to what it got.
      for _ in 0..<3 {
        let pages = layout_page_run(engine, [][:], locator.relayout(), styles)
        let print = @library.hash128(pages[0].inner)
        prints.push("\{print}")
        frames.push(pages[0].inner)
        mark(pages[0].inner)
      }
      let after = page_run_memo_stats()
      prints.push("\{after.0 - before.0} found, \{after.1 - before.1} computed")
      prints.push(
        if physical_equal(frames[0], frames[1]) ||
          physical_equal(frames[1], frames[2]) {
          "one frame for two callers"
        } else {
          "a frame per caller"
        },
      )
      prints
    })
  })
  inspect(prints[3], content="2 found, 1 computed")
  inspect(prints[4], content="a frame per caller")
  assert_eq(prints[1], prints[0])
  assert_eq(prints[2], prints[0])
}
