// Port of `typst-eval/src/methods.rs`.

///|
/// Whether a specific method is mutating.
fn is_mutating_method(method_ : String) -> Bool {
  method_ is ("push" | "pop" | "insert" | "remove")
}

///|
/// Whether a specific method is mutating for dictionaries.
fn is_dict_mutating_method(method_ : String) -> Bool {
  method_ is ("insert" | "remove")
}

///|
/// Whether a specific method is an accessor.
fn is_accessor_method(method_ : String) -> Bool {
  method_ is ("first" | "last" | "at")
}

///|
/// Call a mutating method on a value.
fn call_method_mut(
  place : Place,
  method_ : String,
  args : @library.Args,
  span : @syntax.Span,
) -> @library.Value raise @library.SourceError {
  let value = place.get_mut()
  let ty = value.ty()
  let missing = () => {
    @library.SourceError([
      @library.SourceDiagnostic::error_at(span, missing_method(ty, method_)),
    ])
  }
  let mut output : @library.Value = None
  match value {
    Array(array) =>
      match method_ {
        "push" => array.items.push(args.expect("value"))
        "pop" => output = @library.at(span, () => array.pop())
        "insert" => {
          let index : Int64 = args.expect("index")
          let v : @library.Value = args.expect("value")
          @library.at(span, () => array.insert(index, v))
        }
        "remove" => {
          let index : Int64 = args.expect("index")
          let default : @library.Value? = args.named("default")
          output = @library.at(span, () => array.remove(index, default))
        }
        _ => raise missing()
      }
    Dict(dict) =>
      match method_ {
        "insert" => {
          let key : String = args.expect("key")
          let v : @library.Value = args.expect("value")
          dict.insert(key, v)
        }
        "remove" => {
          let key : String = args.expect("key")
          let default : @library.Value? = args.named("default")
          output = @library.at(span, () => dict.remove(key, default))
        }
        _ => raise missing()
      }
    _ => raise missing()
  }
  args.finish()
  output
}

///|
/// Call an accessor method on a value.
fn call_method_access(
  place : Place,
  method_ : String,
  args : @library.Args,
  span : @syntax.Span,
) -> Place raise @library.SourceError {
  let value = place.get_mut()
  let ty = value.ty()
  let temp_or_missing = () => {
    let msg = if ty.scope().get(method_) is Some(_) {
      "cannot mutate a temporary value"
    } else {
      missing_method(ty, method_)
    }
    @library.SourceError([@library.SourceDiagnostic::error_at(span, msg)])
  }
  let slot : Place = match value {
    Array(array) =>
      match method_ {
        "first" => {
          if array.is_empty() {
            @library.bail_at(span, @library.array_is_empty())
          }
          { get: () => array.items[0], set: v => array.items[0] = v, }
        }
        "last" => {
          if array.is_empty() {
            @library.bail_at(span, @library.array_is_empty())
          }
          let i = array.len() - 1
          { get: () => array.items[i], set: v => array.items[i] = v, }
        }
        "at" => {
          let index : Int64 = args.expect("index")
          let i = @library.at(span, () => array.locate(index, false))
          { get: () => array.items[i], set: v => array.items[i] = v, }
        }
        _ => raise temp_or_missing()
      }
    Dict(dict) =>
      match method_ {
        "at" => {
          let key : String = args.expect("key")
          if !dict.contains(key) {
            raise @library.SourceError([
              @library.HintedString::new(@library.missing_key(key))
              .with_hint("use `insert` to add or update values")
              .into_error_at(span),
            ])
          }
          { get: () => dict.map[key], set: v => dict.map[key] = v, }
        }
        _ => raise temp_or_missing()
      }
    _ => raise temp_or_missing()
  }
  args.finish()
  slot
}

///|
/// The missing method error message.
fn missing_method(ty : @library.Type, method_ : String) -> String {
  "type \{ty} has no method `\{method_}`"
}
