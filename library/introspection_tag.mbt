// Port of `typst-library/src/introspection/tag.rs`.

///|
/// Marks the start or end of a locatable element.
pub(all) enum Tag {
  /// The stored element starts here.
  ///
  /// Content placed in a tag **must** have a [Location] or there will be
  /// panics.
  Start(Content, TagFlags)
  /// The element with the given location and key hash ends here.
  ///
  /// Note: The key hash is stored here instead of in `Start` simply to make
  /// the two enum variants more balanced in size, keeping a `Tag`'s memory
  /// size down. There are no semantic reasons for this.
  End(Location, U128, TagFlags)
} derive(Eq)

///|
/// Access the location of the tag.
pub fn Tag::location(self : Tag) -> Location {
  match self {
    Start(elem, _) => elem.location().unwrap()
    End(loc, _, _) => loc
  }
}

///|
/// Upstream `Debug for Tag`.
pub impl Show for Tag with fn output(self, logger) {
  let loc = self.location()
  match self {
    Start(elem, _) =>
      logger.write_string("Start(\{repr_str(elem.elem().name())}, \{loc})")
    End(_, _, _) => logger.write_string("End(\{loc})")
  }
}

///|
pub impl Fingerprint for Tag with fn fingerprint(self, state) {
  match self {
    Start(elem, flags) => {
      state.write_discriminant(0)
      state.write(elem)
      state.write(flags)
    }
    End(loc, key, flags) => {
      state.write_discriminant(1)
      state.write(loc)
      state.write(key)
      state.write(flags)
    }
  }
}

///|
/// Flags of a [Tag].
pub(all) struct TagFlags {
  /// Whether the element will be inserted into the [Introspector]. Either
  /// because it is `Locatable`, has been labelled, or a location has been
  /// manually set.
  introspectable : Bool
  /// Whether the element is `Tagged`.
  tagged : Bool
} derive(Eq, Hash, Debug)

///|
/// Whether any flag is set.
pub fn TagFlags::any(self : TagFlags) -> Bool {
  self.introspectable || self.tagged
}

///|
pub impl Fingerprint for TagFlags with fn fingerprint(self, state) {
  state.write_bool(self.introspectable)
  state.write_bool(self.tagged)
}

// Internal codec: tags are stored as `Value::Dyn(Tag(..))` in the internal,
// required `tag` field of `TagElem`. They are never exposed to users.

///|
pub impl Reflect for Tag with fn input() {
  Type(Type::content())
}

///|
pub impl Reflect for Tag with fn output() {
  Type(Type::content())
}

///|
pub impl Reflect for Tag with fn castable(v) {
  v is Dyn(Tag(_))
}

///|
pub extend Tag with Reflect::{input, castable}

///|
pub impl IntoValue for Tag with fn into_value(self) {
  Dyn(Tag(self))
}

///|
pub impl FromValue for Tag with fn from_value(v) {
  match v {
    Dyn(Tag(tag)) => tag
    v => raise HintedError(Tag::input().error(v))
  }
}

///|
/// Creates a tag element and directly packs it into type-erased content
/// (upstream `TagElem::packed`).
pub fn TagElem::packed(tag : Tag) -> Content {
  // We can skip preparation for the `TagElem`.
  TagElem::new(tag).pack().mark_prepared()
}

///|
/// `TagElem` cannot be constructed manually (upstream `Construct for
/// TagElem`).
fn tag_elem_init(e : Element) -> Unit {
  e.hooks().construct = Some((_, args) => {
    bail_at(args.span, "cannot be constructed manually")
  })
}
