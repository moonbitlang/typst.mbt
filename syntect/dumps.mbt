// Loading of syntax sets from a compact serialization (the counterpart of
// upstream's `dumps.rs`, which uses bincode).
//
// The format is produced by `oracle/src/bin/gen_syntect.rs` from a linked
// syntect `SyntaxSet` (see there for the grammar). The contexts of each
// syntax are decoded on first use, like upstream's `LazyContexts`.

///|
priv struct Decoder {
  s : String
  mut pos : Int
}

///|
fn Decoder::peek(self : Decoder) -> Int {
  self.s.code_unit_at(self.pos).to_int()
}

///|
fn Decoder::tag(self : Decoder) -> Int {
  let c = self.peek()
  self.pos += 1
  c
}

///|
fn Decoder::int(self : Decoder) -> Int {
  let mut n = 0
  while true {
    let c = self.tag()
    if c == ','.to_int() {
      break
    }
    n = n * 10 + (c - '0'.to_int())
  }
  n
}

///|
fn Decoder::str(self : Decoder) -> String {
  let mut n = 0
  while true {
    let c = self.tag()
    if c == ':'.to_int() {
      break
    }
    n = n * 10 + (c - '0'.to_int())
  }
  let s = self.s.unsafe_substring(start=self.pos, end=self.pos + n)
  self.pos += n
  s
}

///|
fn Decoder::opt_str(self : Decoder) -> String? {
  if self.peek() == '-'.to_int() {
    self.pos += 1
    None
  } else {
    Some(self.str())
  }
}

///|
fn Decoder::scopes(self : Decoder, table : Array[Scope]) -> Array[Scope] {
  let n = self.int()
  Array::makei(n, _ => table[self.int()])
}

///|
fn Decoder::context_id(self : Decoder) -> ContextId {
  let syntax_index = self.int()
  let context_index = self.int()
  { syntax_index, context_index }
}

///|
fn Decoder::reference(self : Decoder) -> ContextReference {
  let tag = self.tag()
  if tag == 'D'.to_int() {
    Direct(self.context_id())
  } else if tag == 'N'.to_int() {
    Named(self.str())
  } else if tag == 'I'.to_int() {
    Inline(self.str())
  } else if tag == 'S'.to_int() {
    let scope = Scope::new(self.str()) catch { _ => abort("invalid scope") }
    let sub_context = self.opt_str()
    let with_escape = self.int() != 0
    ByScope(scope~, sub_context~, with_escape~)
  } else if tag == 'F'.to_int() {
    let name = self.str()
    let sub_context = self.opt_str()
    let with_escape = self.int() != 0
    File(name~, sub_context~, with_escape~)
  } else {
    abort("invalid context reference")
  }
}

///|
fn Decoder::refs(self : Decoder) -> Array[ContextReference] {
  let n = self.int()
  Array::makei(n, _ => self.reference())
}

///|
fn Decoder::context(self : Decoder, table : Array[Scope]) -> Context {
  let meta_scope = self.scopes(table)
  let meta_content_scope = self.scopes(table)
  let meta_include_prototype = self.int() != 0
  let tag = self.tag()
  let clear_scopes : ClearAmount? = if tag == '-'.to_int() {
    None
  } else if tag == 'A'.to_int() {
    Some(ClearAmount::All)
  } else {
    Some(ClearAmount::TopN(self.int()))
  }
  let prototype : ContextId? = if self.peek() == '-'.to_int() {
    self.pos += 1
    None
  } else {
    Some(self.context_id())
  }
  let uses_backrefs = self.int() != 0
  let n = self.int()
  let patterns = Array::makei(n, _ => {
    if self.tag() == 'C'.to_int() {
      Pattern::Include(self.reference())
    } else {
      let has_captures = self.int() != 0
      let regex = self.str()
      let scope = self.scopes(table)
      let captures : CaptureMapping? = if self.peek() == '-'.to_int() {
        self.pos += 1
        None
      } else {
        let n = self.int()
        Some(
          Array::makei(n, _ => {
            let index = self.int()
            (index, self.scopes(table))
          }),
        )
      }
      let tag = self.tag()
      let operation : MatchOperation = if tag == 'P'.to_int() {
        Push(self.refs())
      } else if tag == 'T'.to_int() {
        Set(self.refs())
      } else if tag == 'O'.to_int() {
        Pop
      } else {
        MatchOperation::None
      }
      let with_prototype : ContextReference? = if self.peek() == '-'.to_int() {
        self.pos += 1
        None
      } else {
        Some(self.reference())
      }
      Pattern::Match(
        MatchPattern::new(
          has_captures, regex, scope, captures, operation, with_prototype,
        ),
      )
    }
  })
  {
    meta_scope,
    meta_content_scope,
    meta_include_prototype,
    clear_scopes,
    prototype,
    uses_backrefs,
    patterns,
  }
}

///|
/// Loads a syntax set from the compact serialization: the header (scope
/// table and syntax metadata) and the contexts of each syntax.
pub fn SyntaxSet::from_compact(
  header : String,
  contexts : FixedArray[String],
) -> SyntaxSet {
  let d : Decoder = { s: header, pos: 0 }
  let nscopes = d.int()
  let table = Array::makei(nscopes, _ => {
    Scope::new(d.str()) catch {
      _ => abort("invalid scope")
    }
  })
  let nsyntaxes = d.int()
  let syntaxes = Array::makei(nsyntaxes, i => {
    let name = d.str()
    let next = d.int()
    let file_extensions = Array::makei(next, _ => d.str())
    let scope = Scope::new(d.str()) catch { _ => abort("invalid scope") }
    let first_line_match = d.opt_str()
    let hidden = d.int() != 0
    let start = d.int()
    let ncontexts = d.int()
    SyntaxReference::new_lazy(
      name~,
      file_extensions~,
      scope~,
      first_line_match~,
      hidden~,
      variables={},
      loader=() => {
        let cd : Decoder = { s: contexts[i], pos: 0 }
        let contexts = Array::makei(ncontexts, _ => cd.context(table))
        {
          context_ids: { "__start": { syntax_index: i, context_index: start } },
          contexts,
        }
      },
    )
  })
  SyntaxSet::from_lazy_syntaxes(syntaxes)
}
