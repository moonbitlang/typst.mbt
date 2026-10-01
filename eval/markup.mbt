// Port of `typst-eval/src/markup.rs`.

///|
/// Evaluate markup.
pub fn eval_markup(
  vm : Vm,
  markup : @ast.Markup,
) -> @library.Content raise @library.SourceError {
  let exprs = markup.exprs().collect()
  eval_markup_exprs(vm, exprs[:])
}

///|
/// Evaluate a stream of markup.
fn eval_markup_exprs(
  vm : Vm,
  exprs : ArrayView[@ast.Expr],
) -> @library.Content raise @library.SourceError {
  let flow = vm.flow
  vm.flow = None
  let seq : Array[@library.Content] = []
  let mut i = 0
  while i < exprs.length() {
    let expr = exprs[i]
    i += 1
    match expr {
      SetRule(set) => {
        let styles = eval_set_rule(vm, set)
        if vm.flow is Some(_) {
          break
        }
        let tail = eval_markup_exprs(vm, exprs[i:])
        i = exprs.length()
        seq.push(tail.styled_with_map(styles))
      }
      ShowRule(show) => {
        let recipe = eval_show_rule(vm, show)
        if vm.flow is Some(_) {
          break
        }
        let tail = eval_markup_exprs(vm, exprs[i:])
        i = exprs.length()
        seq.push(styled_with_recipe(vm, tail, recipe))
      }
      expr =>
        match eval_expr(vm, expr) {
          Label(label) => {
            let mut found = -1
            for j = seq.length() - 1; j >= 0; j = j - 1 {
              if !seq[j].can("Unlabellable") {
                found = j
                break
              }
            }
            if found >= 0 {
              let elem = seq[found]
              if elem.label() is Some(_) {
                vm.engine.sink.warn(
                  @library.SourceDiagnostic::warning_at(
                    elem.span(),
                    "content labelled multiple times",
                  ).with_hint(
                    "only the last label is used, the rest are ignored",
                  ),
                )
              }
              seq[found] = elem.labelled(label)
            } else {
              vm.engine.sink.warn(
                @library.SourceDiagnostic::warning_at(
                  expr.span(),
                  "label `\{label.repr()}` is not attached to anything",
                ),
              )
            }
          }
          value => seq.push(value.display().spanned(expr.span()))
        }
    }
    if vm.flow is Some(_) {
      break
    }
  }
  if flow is Some(_) {
    vm.flow = flow
  }
  @library.Content::sequence(seq)
}

///|
fn space_content(had_newline : Bool) -> @library.Content {
  if had_newline {
    @library.SpaceElem::shared_with_newline()
  } else {
    @library.SpaceElem::shared()
  }
}

///|
fn eval_smart_quote(v : @ast.SmartQuote) -> @library.Content {
  @library.Content::new(@library.smart_quote_elem(), []).with_field(
    @library.smart_quote_elem_double,
    Bool(v.double()),
  )
}

///|
fn eval_strong(
  vm : Vm,
  v : @ast.Strong,
) -> @library.Content raise @library.SourceError {
  let body = eval_markup(vm, v.body())
  @library.Content::new(@library.strong_elem(), [
    (@library.strong_elem_body, Content(body)),
  ])
}

///|
fn eval_emph(
  vm : Vm,
  v : @ast.Emph,
) -> @library.Content raise @library.SourceError {
  let body = eval_markup(vm, v.body())
  @library.Content::new(@library.emph_elem(), [
    (@library.emph_elem_body, Content(body)),
  ])
}

///|
fn eval_raw(v : @ast.Raw) -> @library.Content {
  let lines = v.lines().map(line => line.get()).collect()
  let text = lines.join("\n")
  let elem = @library.Content::new(@library.raw_elem(), [
    (@library.raw_elem_text, Str(text)),
  ]).with_field(@library.raw_elem_block, Bool(v.block()))
  match v.lang() {
    Some(lang) => elem.with_field(@library.raw_elem_lang, Str(lang.get()))
    None => elem
  }
}

///|
fn eval_link(v : @ast.Link) -> @library.Content raise @library.SourceError {
  @library.at(v.span(), () => @library.LinkElem::from_url(v.get()))
}

///|
fn eval_ref(
  vm : Vm,
  v : @ast.Ref,
) -> @library.Content raise @library.SourceError {
  let target : @library.Label = Label(v.target())
  let elem = @library.Content::new(@library.ref_elem(), [
    (@library.ref_elem_target, Label(target)),
  ])
  match v.supplement() {
    Some(supplement) =>
      elem.with_field(
        @library.ref_elem_supplement,
        Content(eval_content_block(vm, supplement)),
      )
    None => elem
  }
}

///|
fn eval_heading(
  vm : Vm,
  v : @ast.Heading,
) -> @library.Content raise @library.SourceError {
  let depth = v.depth()
  let body = eval_markup(vm, v.body())
  @library.Content::new(@library.heading_elem(), [
    (@library.heading_elem_body, Content(body)),
  ]).with_field(@library.heading_elem_depth, Int(depth.to_int64()))
}

///|
fn eval_list_item(
  vm : Vm,
  v : @ast.ListItem,
) -> @library.Content raise @library.SourceError {
  @library.Content::new(@library.list_item_elem(), [
    (@library.list_item_elem_body, Content(eval_markup(vm, v.body()))),
  ])
}

///|
fn eval_enum_item(
  vm : Vm,
  v : @ast.EnumItem,
) -> @library.Content raise @library.SourceError {
  let body = eval_markup(vm, v.body())
  let elem = @library.Content::new(@library.enum_item_elem(), [
    (@library.enum_item_elem_body, Content(body)),
  ])
  match v.number() {
    Some(number) =>
      elem.with_field(
        @library.enum_item_elem_number,
        Int(number.reinterpret_as_int64()),
      )
    None => elem
  }
}

///|
fn eval_term_item(
  vm : Vm,
  v : @ast.TermItem,
) -> @library.Content raise @library.SourceError {
  let term = eval_markup(vm, v.term())
  let description = eval_markup(vm, v.description())
  @library.Content::new(@library.term_item_elem(), [
    (@library.term_item_elem_term, Content(term)),
    (@library.term_item_elem_description, Content(description)),
  ])
}
