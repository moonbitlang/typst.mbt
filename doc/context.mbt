// Context callbacks and introspection (docs/edsl-design.md, section 10).

///|
/// The context of one callback invocation: the engine's location and
/// styles for it. It is only valid until the callback returns.
///
/// All operations call Typst's public functions with the invocation's
/// engine and context, so capability errors (`can only be used when context
/// is known`), casts and tracked introspection are Typst's.
pub struct Ctx {
  priv lower : Lowering
  /// The invocation token: cleared when the callback returns.
  priv alive : @ref.Ref[Bool]
  /// The span of the callback.
  priv span : @syntax.Span
}

///|
/// Check the invocation token and register the operation's call site.
fn Ctx::enter(
  self : Ctx,
  name : String,
  loc : SourceLoc,
) -> @syntax.Span raise @library.SourceError {
  if !self.alive.val {
    raise @library.SourceError([
      @library.SourceDiagnostic::error_at(
        self.span,
        "context used outside of its callback",
      ).with_hint("a `Ctx` is only valid until its callback returns"),
    ])
  }
  self.lower.session.registry.span(self.lower.entry(Site::of_call(name, loc)))
}

///|
/// Call a native function with positional and named value arguments.
fn Ctx::native(
  self : Ctx,
  func : @library.NativeFuncData,
  positional : Array[Value],
  named : Array[(String, Value)],
  span : @syntax.Span,
) -> @library.Value raise @library.SourceError {
  self.lower.call(FNative(func), generic_args(positional, named), -1, span)
}

///|
/// The current location (`here()`).
#callsite(autofill(loc))
pub fn Ctx::location(self : Ctx, loc~ : SourceLoc) -> @library.Location raise {
  let span = self.enter("Ctx::location", loc)
  let value = self.native(@library.native_here(), [], [], span)
  @library.at(span, () => value.cast())
}

///|
/// The active styles (for reading style properties with the engine's API).
#callsite(autofill(loc))
pub fn Ctx::styles(self : Ctx, loc~ : SourceLoc) -> @library.StyleChain raise {
  let span = self.enter("Ctx::styles", loc)
  @library.at(span, () => self.lower.context.get_styles())
}

///|
/// All elements matching the selector (`query(selector)`).
#callsite(autofill(loc))
pub fn[W] Ctx::query(
  self : Ctx,
  selector : Selector[W],
  loc~ : SourceLoc,
) -> Array[W] raise {
  let span = self.enter("Ctx::query", loc)
  let value = self.native(@library.native_query(), [selector.value], [], span)
  let items : Array[@library.Content] = @library.at(span, () => value.cast())
  items.map(selector.wrap)
}

///|
/// The measured size of content, in points (the dictionary that Typst's
/// `measure` returns).
pub struct Size {
  width : Double
  height : Double
  /// The vertical position of the content's baseline relative to its top
  /// edge, positive downwards: for text and for containers of text (a
  /// block, a box, with their insets) the baseline of the first line, so
  /// text can be placed on its baseline without an estimate from the font
  /// size. With Typst's default text edges (cap height to baseline) it
  /// equals the `height` of one line. A box whose `baseline` is set
  /// reports the baseline it was given (`Box(.., baseline=Pt(2))`: 2pt
  /// higher). Content without a baseline of its own (a shape, an image)
  /// has it at the bottom (`height`); for empty content it is `0`.
  baseline : Double
}

///|
/// The size `body` would have when laid out (`measure(body, ..)`).
#callsite(autofill(loc))
pub fn Ctx::measure(
  self : Ctx,
  body : &IntoContent,
  width? : Length,
  height? : Length,
  loc~ : SourceLoc,
) -> Size raise {
  let span = self.enter("Ctx::measure", loc)
  let named : Array[(String, Value)] = []
  if width is Some(width) {
    named.push(("width", ToValue::to_value(width)))
  }
  if height is Some(height) {
    named.push(("height", ToValue::to_value(height)))
  }
  let value = self.native(
    @library.native_measure(),
    [Value::content(body)],
    named,
    span,
  )
  let dict : @library.Dict = @library.at(span, () => value.cast())
  let side = (name : String) => {
    let length : @library.Length = @library.at(span, () => dict.get(name).cast())
    length.abs.to_pt()
  }
  { width: side("width"), height: side("height"), baseline: side("baseline"), }
}

// Counters.

///|
/// A counter (`counter(key)`).
pub struct Counter {
  priv key : Value
}

///|
/// The page counter (`counter(page)`).
pub fn Counter::page() -> Counter {
  {
    key: Value::engine(
      @library.Value::Func(@library.Func::element(@library.page_elem())),
    ),
  }
}

///|
/// The counter of the elements a selector matches (`counter(heading)`,
/// `counter(figure.where(kind: table))`).
pub fn[W] Counter::of(selector : Selector[W]) -> Counter {
  { key: selector.value, }
}

///|
/// A custom counter (`counter("name")`).
pub fn Counter::named(key : String) -> Counter {
  { key: Value::str(key), }
}

///|
pub impl ToValue for Counter with fn to_value(self) {
  Value::native(@library.native_counter_construct(), [self.key])
}

///|
#deprecated("call as `ToValue::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Counter with ToValue::{to_value}

///|
/// A counter read in a context.
pub struct CounterHandle {
  priv cx : Ctx
  priv counter : Counter
}

///|
/// Access a counter in this context.
pub fn Ctx::counter(self : Ctx, counter : Counter) -> CounterHandle {
  { cx: self, counter, }
}

///|
fn counter_state(
  value : @library.Value,
  span : @syntax.Span,
) -> Array[Int64] raise @library.SourceError {
  let state : @library.CounterState = @library.at(span, () => value.cast())
  state.0.copy()
}

///|
/// The value of the counter at the current location (`counter.get()`).
#callsite(autofill(loc))
pub fn CounterHandle::get(
  self : CounterHandle,
  loc~ : SourceLoc,
) -> Array[Int64] raise {
  let span = self.cx.enter("CounterHandle::get", loc)
  let value = self.cx.native(
    @library.native_counter_get(),
    [ToValue::to_value(self.counter)],
    [],
    span,
  )
  counter_state(value, span)
}

///|
/// The value of the counter at the end of the document
/// (`counter.final()`).
#callsite(autofill(loc))
pub fn CounterHandle::final_value(
  self : CounterHandle,
  loc~ : SourceLoc,
) -> Array[Int64] raise {
  let span = self.cx.enter("CounterHandle::final_value", loc)
  let value = self.cx.native(
    @library.native_counter_final(),
    [ToValue::to_value(self.counter)],
    [],
    span,
  )
  counter_state(value, span)
}

///|
/// The value of the counter at the element the selector matches
/// (`counter.at(selector)`).
#callsite(autofill(loc))
pub fn[W] CounterHandle::at(
  self : CounterHandle,
  selector : Selector[W],
  loc~ : SourceLoc,
) -> Array[Int64] raise {
  let span = self.cx.enter("CounterHandle::at", loc)
  let value = self.cx.native(
    @library.native_counter_at(),
    [ToValue::to_value(self.counter), selector.value],
    [],
    span,
  )
  counter_state(value, span)
}

///|
/// The counter formatted with a numbering (`counter.display(numbering,
/// both: ..)`); without a numbering, the one of the counted element.
#callsite(autofill(loc))
pub fn CounterHandle::display(
  self : CounterHandle,
  numbering? : Numbering,
  both? : Bool,
  loc~ : SourceLoc,
) -> Content raise {
  let span = self.cx.enter("CounterHandle::display", loc)
  let positional = [ToValue::to_value(self.counter)]
  if numbering is Some(numbering) {
    positional.push(ToValue::to_value(numbering))
  }
  let named : Array[(String, Value)] = []
  if both is Some(both) {
    named.push(("both", Value::bool(both)))
  }
  let value = self.cx.native(
    @library.native_counter_display(),
    positional,
    named,
    span,
  )
  Content::of(NEngine(value.display().spanned(span)))
}

///|
/// Content that advances a counter (`counter.step(level: ..)`).
pub struct CounterStep {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn CounterStep::CounterStep(
  counter : Counter,
  level? : Int64,
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> CounterStep {
  let args : Array[ArgNode] = [
    { name: None, value: ToValue::to_value(counter), param: 0, },
  ]
  if level is Some(level) {
    args.push({ name: Some("level"), value: Value::int(level), param: 1, })
  }
  {
    content: Content::of(
      NCall({
        func: FNative(@library.native_counter_step()),
        args,
        origin: Site::new("CounterStep", loc, args_loc),
      }),
    ),
  }
}

///|
pub impl IntoContent for CounterStep with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CounterStep with IntoContent::{into_content}

///|
/// Content that sets a counter (`counter.update(..)`): one value per
/// level.
pub struct CounterUpdate {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn CounterUpdate::CounterUpdate(
  counter : Counter,
  values : Array[Int64],
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
) -> CounterUpdate {
  let update = if values.length() == 1 {
    Value::int(values[0])
  } else {
    Value::array(values.map(Value::int))
  }
  {
    content: Content::of(
      NCall({
        func: FNative(@library.native_counter_update()),
        args: [
          { name: None, value: ToValue::to_value(counter), param: 0, },
          { name: None, value: update, param: 1, },
        ],
        origin: Site::new("CounterUpdate", loc, args_loc),
      }),
    ),
  }
}

///|
pub impl IntoContent for CounterUpdate with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend CounterUpdate with IntoContent::{into_content}

// Context callbacks.

///|
/// Content that depends on its context (`context { .. }`).
pub struct Context {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Context::Context(
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
  f : (Ctx) -> &IntoContent raise,
) -> Context {
  let site = Site::new("Context", loc, args_loc)
  let callback = Callback::new(site, (cx, _) => Value::content(f(cx)))
  { content: Content::of(NContext(callback, site)), }
}

///|
pub impl IntoContent for Context with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Context with IntoContent::{into_content}

// Layout callbacks.

///|
/// The size a [Layout] callback receives, in points: the dictionary that
/// Typst's `layout` passes to its function, which has a `width` and a
/// `height` (and no baseline: it is not the [Size] that `measure` returns).
///
/// It is the base size of the enclosing region: the width and height of the
/// container (a block or box with that dimension, a grid cell, the page
/// without its margins; where the container does not fix a dimension, that
/// of the region around it), not the space that remains on the page. A
/// dimension that nothing bounds is infinite: the height on a page with
/// `height: auto`, the width on one with `width: auto`, and both while the
/// content is measured (`cx.measure(..)` without a `width` or `height`).
/// Check `is_inf()` before computing with it.
pub struct LayoutSize {
  width : Double
  height : Double
}

///|
/// Content that depends on the size of its container
/// (`layout(size => ..)`).
///
/// The callback receives the size of the enclosing region and the context
/// of the invocation, which has a location and styles, so `cx.measure(..)`
/// works in it. The result is laid out as a block. Like every callback it
/// cannot be created inside another callback.
///
/// Twin: `layout(size => ..)`.
pub struct Layout {
  priv content : Content
}

///|
#callsite(autofill(loc, args_loc))
pub fn Layout::Layout(
  loc~ : SourceLoc,
  args_loc~ : ArgsLoc,
  f : (LayoutSize, Ctx) -> &IntoContent raise,
) -> Layout {
  let site = Site::new("Layout", loc, args_loc)
  let callback = Callback::new(site, (cx, args) => {
    // The dictionary of the engine's layout rule (`regions.base()`).
    let size : @library.Dict = args.expect("size")
    let side = (name : String) => {
      let length : @library.Length = size.get(name).cast()
      length.abs.to_pt()
    }
    Value::content(f({ width: side("width"), height: side("height"), }, cx))
  })
  // `layout` is a public function: it is called like one, with the host
  // function as its argument. The callback is the third declared
  // parameter: `ArgsLoc` counts the autofilled ones.
  {
    content: Content::of(
      NCall({
        func: FNative(@library.native_layout()),
        args: [
          {
            name: Option::None,
            value: Value::of(VCallback(callback)),
            param: 2,
          },
        ],
        origin: site,
      }),
    ),
  }
}

///|
pub impl IntoContent for Layout with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Layout with IntoContent::{into_content}
