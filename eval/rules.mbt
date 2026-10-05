// Port of `typst-eval/src/rules.rs`.

///|
fn eval_set_rule(
  vm : Vm,
  set : @ast.SetRule,
) -> @library.Styles raise @library.SourceError {
  if set.condition() is Some(condition) {
    let v = eval_expr(vm, condition)
    if !@library.at(condition.span(), () => v.cast()) {
      return @library.Styles::new()
    }
  }
  let target_expr = set.target()
  let target_value = eval_expr(vm, target_expr)
  let target = @library.at(target_expr.span(), () => {
    let func : @library.Func = target_value.cast() catch {
      @library.HintedError(err) =>
        raise @library.HintedError(hint_if_shadowed_std(vm, target_expr, err))
    }
    match func.to_element() {
      Some(elem) => elem
      None => @library.bail("only element functions can be used in set rules")
    }
  })
  let args = eval_args(vm, set.args()).spanned(set.span())
  target.set(vm.engine, args).spanned(set.span()).liftable()
}

///|
fn eval_show_rule(
  vm : Vm,
  show : @ast.ShowRule,
) -> @library.Recipe raise @library.SourceError {
  let selector = match show.selector() {
    Some(sel) => {
      let v = eval_expr(vm, sel)
      Some(
        @library.at(sel.span(), () => {
          @library.ShowableSelector::from_value(v) catch {
            @library.HintedError(err) =>
              raise @library.HintedError(hint_if_shadowed_std(vm, sel, err))
          }
        }).0,
      )
    }
    None => None
  }
  let transform = show.transform()
  let transform : @library.Transformation = match transform {
    SetRule(set) => Style(eval_set_rule(vm, set))
    expr => {
      let v = eval_expr(vm, expr)
      @library.at(transform.span(), () => v.cast())
    }
  }
  let recipe = @library.Recipe::new(selector, transform, show.span())
  check_recipe(vm.engine, recipe)
  recipe
}

///|
/// The checks `eval_show_rule` performs on a new recipe (upstream: the two
/// calls at the end of `ShowRule::eval`), for hosts that build recipes
/// without evaluating a show rule (the `doc` package).
pub fn check_recipe(engine : @library.Engine, recipe : @library.Recipe) -> Unit {
  check_show_page_rule(engine, recipe)
  check_show_par_set_block(engine, recipe)
}

///|
/// Migration hint for `show page`.
fn check_show_page_rule(
  engine : @library.Engine,
  recipe : @library.Recipe,
) -> Unit {
  if recipe.selector is Some(Elem(elem, _)) && elem == @library.page_elem() {
    engine.sink.warn(
      @library.SourceDiagnostic::warning_at(
        recipe.span,
        "`show page` is not supported and has no effect",
      ).with_hint("customize pages with `set page(..)` instead"),
    )
  }
}

///|
/// Migration hint for `show par: set block(spacing: ..)`.
fn check_show_par_set_block(
  engine : @library.Engine,
  recipe : @library.Recipe,
) -> Unit {
  if recipe.selector is Some(Elem(elem, _)) &&
    elem == @library.par_elem() &&
    recipe.transform is Style(styles) {
    let chain = @library.StyleChain::new(styles)
    if chain.has(@library.block_elem(), @library.block_elem_above) ||
      chain.has(@library.block_elem(), @library.block_elem_below) {
      engine.sink.warn(
        @library.SourceDiagnostic::warning_at(
          recipe.span,
          "`show par: set block(spacing: ..)` has no effect anymore",
        ).with_hints([
          "write `set par(spacing: ..)` instead", "this is specific to paragraphs as they are not considered blocks anymore",
        ]),
      )
    }
  }
}
