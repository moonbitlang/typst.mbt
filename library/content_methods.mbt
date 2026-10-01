// The methods of the `content` type (upstream `#[scope] impl Content` in
// `foundations/content/mod.rs`).

///|
/// The content's element function.
fn impl_content_func(self_ : Content) -> Element raise HintedError {
  self_.elem()
}

///|
/// Whether the content has the specified field.
fn impl_content_has(self_ : Content, field_ : String) -> Bool raise HintedError {
  self_.has(field_)
}

///|
/// Access the specified field on the content.
fn impl_content_at(
  self_ : Content,
  field_ : String,
  default_ : Value?,
) -> Value raise HintedError {
  self_.get_by_name(field_) catch {
    e =>
      match default_ {
        Some(v) => v
        None => bail(e.message_no_default(self_, field_))
      }
  }
}

///|
/// Returns the fields of this content.
fn impl_content_fields(self_ : Content) -> Dict raise HintedError {
  self_.fields()
}
