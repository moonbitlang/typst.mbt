// Composites (docs/edsl-ports.md, section 4): elements that are defined
// outside this package by an expansion into its constructors, with the
// provenance of one constructor call.
//
//   #callsite(autofill(loc, args_loc))
//   pub fn Note::Note(
//     body : &IntoContent,
//     fill? : Paint,
//     loc~ : SourceLoc,
//     args_loc~ : ArgsLoc,
//   ) -> Note {
//     {
//       composite: Composite("Note", loc, args_loc, site => {
//         Block(site.arg(0, body), fill?=fill.map(v => site.arg(1, v)))
//       }),
//     }
//   }
//
// A helper function that builds an element puts every use of it on the
// helper's own lines, and one that passes its `loc` and `args_loc` on to a
// constructor makes that constructor read the helper's argument locations
// by its own parameter indices (docs/edsl-guide.md, section 3). A
// composite has neither defect: there is one site, the call of the
// composite with the locations of its arguments, and which argument a
// constructor's parameter is, is said where it is passed (`site.arg`).
//
// How it works. A site is made by `Site::new`, which every constructor
// calls with its autofilled `loc` and `args_loc`. While a `build` runs
// (`composite_scope`), `Site::new` returns the composite's call instead,
// with a table from the constructor's parameters to the composite's
// (`Owner`). The table is filled from what the compiler records anyway:
// `site.arg(i, v)` has the location of its own call, a constructor has the
// locations of its argument expressions, and an argument expression that
// contains the call of `site.arg(i, v)` is the caller's argument `i`.
// A callback runs where it was created (`scoped_callback`): one that a
// `build` creates is a part of it, so the content that an element makes
// while the document is laid out has the same provenance.

///|
/// How the call of a constructor that ran inside the `build` of a composite
/// is seen from the call of the composite, which is its site's `loc` and
/// `args`.
priv struct Owner {
  /// The name of the composite: the constructor that origins report.
  kind : String
  /// Per declared parameter of the constructor, the parameter of the
  /// composite that it was marked as (`site.arg`), or `-1`: the call.
  params : Array[Int]
}

///|
/// The parameter of the call that origins report (an index of `args`) for
/// the parameter `param` of the constructor; `-1`: the call itself.
fn Site::param(self : Site, param : Int) -> Int {
  match self.owner {
    Option::None => param
    Some(owner) =>
      if param >= 0 && param < owner.params.length() {
        owner.params[param]
      } else {
        -1
      }
  }
}

///|
/// The name of the constructor that origins report: the composite's for a
/// constructor that ran inside its `build`.
fn Site::origin_kind(self : Site) -> String {
  match self.owner {
    Option::None => self.kind
    Some(owner) => owner.kind
  }
}

///|
/// A range of a source file (`SourceLoc`).
priv struct SourceRange {
  file : String
  module_name : String
  start_line : Int
  start_column : Int
  end_line : Int
  end_column : Int
} derive(Eq)

///|
fn SourceRange::of(loc : SourceLoc) -> SourceRange {
  let (file, module_name, start_line, start_column, end_line, end_column) = parse_loc(
    loc.to_string(),
  )
  { file, module_name, start_line, start_column, end_line, end_column, }
}

///|
/// Whether `other` is inside `self` (or is `self`).
fn SourceRange::contains(self : SourceRange, other : SourceRange) -> Bool {
  self.file == other.file &&
  self.module_name == other.module_name &&
  (
    self.start_line < other.start_line ||
    (
      self.start_line == other.start_line &&
      self.start_column <= other.start_column
    )
  ) &&
  (
    other.end_line < self.end_line ||
    (other.end_line == self.end_line && other.end_column <= self.end_column)
  )
}

///|
/// A call of `site.arg(i, v)` that no constructor has taken yet: where the
/// call is written, and the parameter (of the call that origins report).
priv struct Mark {
  range : SourceRange
  param : Int
}

///|
/// The state of a running `build`, or of a running callback of one.
priv struct Scope {
  /// The composite's site.
  site : Site
  /// The marks that were made and not taken, without duplicates: a mark in
  /// a loop is one mark. (A mark that no constructor takes, of a value
  /// that was bound to a name, is dropped with the scope.)
  mut marks : Array[Mark]
}

///|
/// The `build` that is running (process-wide, like the serials of
/// callbacks: descriptions are built by ordinary function calls).
let composite_scope : @ref.Ref[Scope?] = { val: Option::None, }

///|
/// A parameter that two different marks claim.
const AMBIGUOUS : Int = -2

///|
/// A parameter that no mark claims.
const UNMARKED : Int = -3

///|
/// The parameter that the marks inside `range` name, which are taken:
/// `UNMARKED` if there is none, `AMBIGUOUS` if they name different ones.
fn Scope::take(self : Scope, range : SourceRange) -> Int {
  let mut found = UNMARKED
  let rest : Array[Mark] = []
  for mark in self.marks {
    if !range.contains(mark.range) {
      rest.push(mark)
    } else if found == UNMARKED {
      found = mark.param
    } else if found != mark.param {
      found = AMBIGUOUS
    }
  }
  self.marks = rest
  found
}

///|
/// The site of a constructor that is called inside the `build`: the call of
/// the composite. A parameter of the constructor whose argument expression
/// contains calls of `site.arg(i, ..)` that all name the same `i` is that
/// parameter of the composite; every other parameter is the call as a
/// whole. The marks belong to the innermost constructor call around them:
/// arguments are evaluated before the constructor runs, so that one takes
/// them first.
fn Scope::own(
  self : Scope,
  kind : String,
  loc : SourceLoc,
  args : ArgsLoc,
) -> Site {
  ignore(loc)
  let ArgsLoc(arg_locs) = args
  let params = Array::make(arg_locs.length(), -1)
  if !self.marks.is_empty() {
    for p, arg in arg_locs {
      if arg is Some(arg) {
        let found = self.take(SourceRange::of(arg))
        params[p] = if found >= 0 { found } else { -1 }
      }
    }
  }
  {
    loc: self.site.loc,
    args: self.site.args,
    kind,
    owner: Some({ kind: self.site.origin_kind(), params, }),
  }
}

///|
/// The description of `body`. The `into_content` of a type of the caller
/// is the caller's code: the constructors that it runs are not those of a
/// composite that the value is passed through, so they keep their own
/// call sites.
fn described(body : &IntoContent) -> Content {
  guard composite_scope.val is Some(_) else { return body.into_content() }
  let scope = composite_scope.val
  composite_scope.val = Option::None
  let content = body.into_content()
  composite_scope.val = scope
  content
}

///|
/// The call site of a composite, for its `build` and the callbacks that
/// the `build` creates: see [Composite].
pub struct CompositeSite {
  priv site : Site
}

///|
/// `value`, marked as the argument `param` of the composite's call:
/// `param` is the index of the parameter in the declaration of the function
/// that has the `#callsite(autofill(loc, args_loc))` (the first is `0`;
/// `loc~` and `args_loc~` count).
///
/// Written as an argument of a constructor, or inside one
/// (`fill=Cells::all(site.arg(3, fill))`), it makes that argument of the
/// constructor the caller's argument `param`: an error in the value is
/// reported there, and text without a location of its own in it (a plain
/// string) resolves to it. The value itself is returned unchanged, so it
/// has the type that the constructor's parameter wants.
///
/// - The mark belongs to the innermost constructor call around it. A
///   value that is bound to a name first (`let b = site.arg(0, body)`) is
///   not marked where the name is used.
/// - An argument that contains marks of different parameters
///   (`Seq([site.arg(0, a), site.arg(1, b)])`) is attributed to the call
///   of the composite as a whole, like an argument without a mark.
/// - A description that the caller built has the origin of its own call
///   whether it is marked or not.
/// - An argument that the caller did not write (a default) has no
///   location: it is the call.
#callsite(autofill(loc))
pub fn[T] CompositeSite::arg(
  self : CompositeSite,
  param : Int,
  value : T,
  loc~ : SourceLoc,
) -> T {
  if composite_scope.val is Some(scope) {
    let range = SourceRange::of(loc)
    let param = self.site.param(param)
    let mut known = false
    for mark in scope.marks {
      if mark.param == param && mark.range == range {
        known = true
        break
      }
    }
    if !known {
      scope.marks.push({ range, param, })
    }
  }
  value
}

///|
/// The function of a callback that is created now (`Callback::new`): it
/// runs where it was created. A callback that the `build` of a composite
/// creates is a part of that `build`, which runs later: while it runs, the
/// constructors that it calls are the composite's (also `cx.measure(..)`,
/// which records where it is called), and `site.arg` marks their
/// arguments. A callback that was created outside of every `build` runs
/// outside of every `build`, also when the engine calls it while a
/// callback of a composite is running (the composite measures content of
/// the caller that has a `Context` in it). The callback's own identity,
/// occurrence and keys are those of every callback (docs/edsl-design.md,
/// section 11.2): a callback description that is created while it runs is
/// created inside a callback.
fn scoped_callback(
  invoke : (Ctx, @library.Args) -> Value raise,
) -> (Ctx, @library.Args) -> Value raise {
  let site = composite_scope.val.map(scope => scope.site)
  (cx, args) => {
    let outer = composite_scope.val
    composite_scope.val = site.map(site => { site, marks: [], })
    defer {
      composite_scope.val = outer
    }
    invoke(cx, args)
  }
}

///|
/// Content that cannot be lowered: `message` is reported when the document
/// is compiled, at the argument `arg` of the composite's call (an index as
/// for [CompositeSite::arg]) if the caller wrote it, else at the call. For
/// arguments that the element cannot accept (constructors do not raise).
pub fn CompositeSite::invalid(
  self : CompositeSite,
  message : String,
  arg? : Int = -1,
) -> Content {
  Content::of(NInvalid(message, self.site, self.site.param(arg)))
}

///|
/// An element that is defined by an expansion into constructors of this
/// package, with the provenance of one constructor call: the hook for
/// packages of elements such as `doc/kit`.
///
/// `Composite(name, loc, args_loc, build)` is the content that `build`
/// returns, for the call site `loc` with the argument locations `args_loc`
/// (the autofilled ones of the function that defines the element; `name`
/// is the constructor that origins report). `build` runs at once.
///
/// - **One site.** The constructors that run inside `build` do not record
///   their own call sites, which are lines of the element's definition,
///   and the indices of their parameters are not used for locations: what
///   they produce (shapes, generated text, errors) resolves to the call of
///   the composite as a whole.
/// - **Arguments.** `site.arg(i, v)` ([CompositeSite::arg]) passes `v` on
///   to a constructor as the caller's argument `i`: a plain string in it
///   resolves to that argument, and an error in it is reported there.
/// - **The caller's descriptions** were built before `build` ran and keep
///   the origins of their own calls. So does what the `into_content` of a
///   type of the caller builds. A function of the caller that `build`
///   calls runs inside it: an element that takes one calls it before the
///   hook.
/// - **The result** of `build` is not an argument of a constructor: a
///   string of the caller that is the whole result is the call. Inside a
///   constructor it is an argument: `site => Seq(site.arg(0, [body]))`.
/// - **Nesting.** A composite that is built inside the `build` of another
///   one is a constructor like the others there: everything it produces
///   resolves to the call of the outermost composite, and its arguments to
///   the outer arguments they were marked as.
/// - **Callbacks.** `build` runs when the element is constructed, so a
///   callback that it creates (`Layout`, `Context`, a `Cells` function)
///   exists before the document is compiled, if the element itself is not
///   constructed inside a callback; an element that creates one says so in
///   its documentation. A callback is a part of the `build` that created
///   it: when it runs, the constructors that it calls are the composite's
///   too, and `site.arg` marks their arguments. (A callback of the caller
///   runs as the caller's, also when the engine calls it while the
///   element measures.) The caller's content is converted in `build`
///   (`Content(body)`), once, not in the callback.
/// - **Keys.** The origins are those of the call under the keys of the
///   enclosing `Keyed` wrappers, as for any constructor; an element that
///   builds a part per item of its data wraps each in `Keyed`.
/// - **Reuse.** A composite that is used twice is one description in two
///   places, as any description is.
///
/// Twin: the content that `build` returns; an element has a Typst function
/// with the same expansion as its twin.
pub struct Composite {
  priv content : Content
}

///|
pub fn Composite::Composite(
  name : String,
  loc : SourceLoc,
  args_loc : ArgsLoc,
  build : (CompositeSite) -> &IntoContent,
) -> Composite {
  // (Inside the `build` of another composite this is a site of that one.)
  let site = Site::new(name, loc, args_loc)
  let outer = composite_scope.val
  composite_scope.val = Some({ site, marks: [], })
  let body = described(build({ site, }))
  composite_scope.val = outer
  { content: Content::of(NComposite(body, site)), }
}

///|
pub impl IntoContent for Composite with fn into_content(self) {
  self.content
}

///|
#deprecated("call as `IntoContent::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Composite with IntoContent::{into_content}

///|
/// Interpolation into the text of `Prose`.
pub impl @builtin.Show for Composite with fn output(self, logger) {
  prose_placeholder(self.content, logger)
}

///|
#deprecated("call as `Show::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Composite with @builtin.Show::{to_string, output}

///|
pub impl @debug.Debug for Composite with fn to_repr(self) {
  @debug.Debug::to_repr(self.content)
}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend Composite with @debug.Debug::{to_repr}
