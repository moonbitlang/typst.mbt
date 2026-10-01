// Generated stubs for native functions that are not ported yet.

///|
/// TODO: port `Args.construct` (typst-library/src/foundations/args.rs).
fn impl_args_construct(args : Args) -> Args raise HintedError {
  ignore(args)
  bail("`Args.construct` is not yet ported")
}

///|
/// TODO: port `Args.len` (typst-library/src/foundations/args.rs).
fn impl_args_len(self_ : Args) -> USize raise HintedError {
  ignore(self_)
  bail("`Args.len` is not yet ported")
}

///|
/// TODO: port `Args.at` (typst-library/src/foundations/args.rs).
fn impl_args_at(
  self_ : Args,
  key_ : Value,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(key_)
  ignore(default_)
  bail("`Args.at` is not yet ported")
}

///|
/// TODO: port `Args.pos` (typst-library/src/foundations/args.rs).
fn impl_args_to_pos(self_ : Args) -> Arr raise HintedError {
  ignore(self_)
  bail("`Args.pos` is not yet ported")
}

///|
/// TODO: port `Args.named` (typst-library/src/foundations/args.rs).
fn impl_args_to_named(self_ : Args) -> Dict raise HintedError {
  ignore(self_)
  bail("`Args.named` is not yet ported")
}

///|
/// TODO: port `Args.filter` (typst-library/src/foundations/args.rs).
fn impl_args_filter(
  self_ : Args,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Args raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(test_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Args.filter` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Args.map` (typst-library/src/foundations/args.rs).
fn impl_args_map(
  self_ : Args,
  engine : Engine,
  context : Context,
  mapper_ : Func,
) -> Args raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(mapper_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Args.map` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.construct` (typst-library/src/foundations/array.rs).
fn impl_array_construct(value_ : Value) -> Arr raise HintedError {
  ignore(value_)
  bail("`Array.construct` is not yet ported")
}

///|
/// TODO: port `Array.len` (typst-library/src/foundations/array.rs).
fn impl_array_len(self_ : Arr) -> USize raise HintedError {
  ignore(self_)
  bail("`Array.len` is not yet ported")
}

///|
/// TODO: port `Array.first` (typst-library/src/foundations/array.rs).
fn impl_array_first(self_ : Arr, default_ : Value?) -> Value raise HintedError {
  ignore(self_)
  ignore(default_)
  bail("`Array.first` is not yet ported")
}

///|
/// TODO: port `Array.last` (typst-library/src/foundations/array.rs).
fn impl_array_last(self_ : Arr, default_ : Value?) -> Value raise HintedError {
  ignore(self_)
  ignore(default_)
  bail("`Array.last` is not yet ported")
}

///|
/// TODO: port `Array.at` (typst-library/src/foundations/array.rs).
fn impl_array_at(
  self_ : Arr,
  index_ : Int64,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(index_)
  ignore(default_)
  bail("`Array.at` is not yet ported")
}

///|
/// TODO: port `Array.push` (typst-library/src/foundations/array.rs).
fn impl_array_push(self_ : Arr, value_ : Value) -> Unit raise HintedError {
  ignore(self_)
  ignore(value_)
  bail("`Array.push` is not yet ported")
}

///|
/// TODO: port `Array.pop` (typst-library/src/foundations/array.rs).
fn impl_array_pop(self_ : Arr) -> Value raise HintedError {
  ignore(self_)
  bail("`Array.pop` is not yet ported")
}

///|
/// TODO: port `Array.insert` (typst-library/src/foundations/array.rs).
fn impl_array_insert(
  self_ : Arr,
  index_ : Int64,
  value_ : Value,
) -> Unit raise HintedError {
  ignore(self_)
  ignore(index_)
  ignore(value_)
  bail("`Array.insert` is not yet ported")
}

///|
/// TODO: port `Array.remove` (typst-library/src/foundations/array.rs).
fn impl_array_remove(
  self_ : Arr,
  index_ : Int64,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(index_)
  ignore(default_)
  bail("`Array.remove` is not yet ported")
}

///|
/// TODO: port default `Default::default()`.
fn impl_array_slice__end_default() -> Int64? raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `array_slice.end` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.slice` (typst-library/src/foundations/array.rs).
fn impl_array_slice(
  self_ : Arr,
  start_ : Int64,
  end_ : Int64?,
  count_ : Int64?,
) -> Arr raise HintedError {
  ignore(self_)
  ignore(start_)
  ignore(end_)
  ignore(count_)
  bail("`Array.slice` is not yet ported")
}

///|
/// TODO: port `Array.contains` (typst-library/src/foundations/array.rs).
fn impl_array_contains(self_ : Arr, value_ : Value) -> Bool raise HintedError {
  ignore(self_)
  ignore(value_)
  bail("`Array.contains` is not yet ported")
}

///|
/// TODO: port `Array.find` (typst-library/src/foundations/array.rs).
fn impl_array_find(
  self_ : Arr,
  engine : Engine,
  context : Context,
  searcher_ : Func,
) -> Value? raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(searcher_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.find` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.position` (typst-library/src/foundations/array.rs).
fn impl_array_position(
  self_ : Arr,
  engine : Engine,
  context : Context,
  searcher_ : Func,
) -> Int64? raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(searcher_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.position` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_array_range__start_default() -> Int64 raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `array_range.start` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `NonZeroI64::new(1).unwrap()`.
fn impl_array_range__step_default() -> NonZeroI64 raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `array_range.step` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.range` (typst-library/src/foundations/array.rs).
fn impl_array_range(
  args : Args,
  inclusive_ : Bool,
  step_ : NonZeroI64,
) -> Arr raise SourceError {
  ignore(args)
  ignore(inclusive_)
  ignore(step_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.range` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.filter` (typst-library/src/foundations/array.rs).
fn impl_array_filter(
  self_ : Arr,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Arr raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(test_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.filter` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.map` (typst-library/src/foundations/array.rs).
fn impl_array_map(
  self_ : Arr,
  engine : Engine,
  context : Context,
  mapper_ : Func,
) -> Arr raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(mapper_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.map` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.enumerate` (typst-library/src/foundations/array.rs).
fn impl_array_enumerate(self_ : Arr, start_ : Int64) -> Arr raise HintedError {
  ignore(self_)
  ignore(start_)
  bail("`Array.enumerate` is not yet ported")
}

///|
/// TODO: port `Array.zip` (typst-library/src/foundations/array.rs).
fn impl_array_zip(
  self_ : Arr,
  args : Args,
  exact_ : Bool,
) -> Arr raise SourceError {
  ignore(self_)
  ignore(args)
  ignore(exact_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.zip` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.fold` (typst-library/src/foundations/array.rs).
fn impl_array_fold(
  self_ : Arr,
  engine : Engine,
  context : Context,
  init_ : Value,
  folder_ : Func,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(init_)
  ignore(folder_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.fold` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.sum` (typst-library/src/foundations/array.rs).
fn impl_array_sum(self_ : Arr, default_ : Value?) -> Value raise HintedError {
  ignore(self_)
  ignore(default_)
  bail("`Array.sum` is not yet ported")
}

///|
/// TODO: port `Array.product` (typst-library/src/foundations/array.rs).
fn impl_array_product(
  self_ : Arr,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(default_)
  bail("`Array.product` is not yet ported")
}

///|
/// TODO: port `Array.any` (typst-library/src/foundations/array.rs).
fn impl_array_any(
  self_ : Arr,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Bool raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(test_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.any` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.all` (typst-library/src/foundations/array.rs).
fn impl_array_all(
  self_ : Arr,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Bool raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(test_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.all` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.flatten` (typst-library/src/foundations/array.rs).
fn impl_array_flatten(self_ : Arr) -> Arr raise HintedError {
  ignore(self_)
  bail("`Array.flatten` is not yet ported")
}

///|
/// TODO: port `Array.rev` (typst-library/src/foundations/array.rs).
fn impl_array_rev(self_ : Arr) -> Arr raise HintedError {
  ignore(self_)
  bail("`Array.rev` is not yet ported")
}

///|
/// TODO: port `Array.split` (typst-library/src/foundations/array.rs).
fn impl_array_split(self_ : Arr, at_ : Value) -> Arr raise HintedError {
  ignore(self_)
  ignore(at_)
  bail("`Array.split` is not yet ported")
}

///|
/// TODO: port default `Default::default()`.
fn impl_array_join__separator_default() -> Value? raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `array_join.separator` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_array_join__default_default() -> Value? raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `array_join.default` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.join` (typst-library/src/foundations/array.rs).
fn impl_array_join(
  self_ : Arr,
  separator_ : Value?,
  last_ : Value?,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(separator_)
  ignore(last_)
  ignore(default_)
  bail("`Array.join` is not yet ported")
}

///|
/// TODO: port `Array.intersperse` (typst-library/src/foundations/array.rs).
fn impl_array_intersperse(
  self_ : Arr,
  separator_ : Value,
) -> Arr raise HintedError {
  ignore(self_)
  ignore(separator_)
  bail("`Array.intersperse` is not yet ported")
}

///|
/// TODO: port `Array.chunks` (typst-library/src/foundations/array.rs).
fn impl_array_chunks(
  self_ : Arr,
  chunk_size_ : NonZeroUSize,
  exact_ : Bool,
) -> Arr raise HintedError {
  ignore(self_)
  ignore(chunk_size_)
  ignore(exact_)
  bail("`Array.chunks` is not yet ported")
}

///|
/// TODO: port `Array.windows` (typst-library/src/foundations/array.rs).
fn impl_array_windows(
  self_ : Arr,
  window_size_ : NonZeroUSize,
) -> Arr raise HintedError {
  ignore(self_)
  ignore(window_size_)
  bail("`Array.windows` is not yet ported")
}

///|
/// TODO: port `Array.sorted` (typst-library/src/foundations/array.rs).
fn impl_array_sorted(
  self_ : Arr,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  key_ : Func?,
  by_ : Func?,
) -> Arr raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(key_)
  ignore(by_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.sorted` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.dedup` (typst-library/src/foundations/array.rs).
fn impl_array_dedup(
  self_ : Arr,
  engine : Engine,
  context : Context,
  key_ : Func?,
) -> Arr raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(key_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.dedup` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Array.to-dict` (typst-library/src/foundations/array.rs).
fn impl_array_to_dict(self_ : Arr) -> Dict raise HintedError {
  ignore(self_)
  bail("`Array.to-dict` is not yet ported")
}

///|
/// TODO: port `Array.reduce` (typst-library/src/foundations/array.rs).
fn impl_array_reduce(
  self_ : Arr,
  engine : Engine,
  context : Context,
  reducer_ : Func,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(reducer_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Array.reduce` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Bytes.construct` (typst-library/src/foundations/bytes.rs).
fn impl_bytes_construct(value_ : Value) -> Value raise HintedError {
  ignore(value_)
  bail("`Bytes.construct` is not yet ported")
}

///|
/// TODO: port `Bytes.len` (typst-library/src/foundations/bytes.rs).
fn impl_bytes_len(self_ : Value) -> USize raise HintedError {
  ignore(self_)
  bail("`Bytes.len` is not yet ported")
}

///|
/// TODO: port `Bytes.at` (typst-library/src/foundations/bytes.rs).
fn impl_bytes_at(
  self_ : Value,
  index_ : Int64,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(index_)
  ignore(default_)
  bail("`Bytes.at` is not yet ported")
}

///|
/// TODO: port default `Default::default()`.
fn impl_bytes_slice__end_default() -> Int64? raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `bytes_slice.end` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Bytes.slice` (typst-library/src/foundations/bytes.rs).
fn impl_bytes_slice(
  self_ : Value,
  start_ : Int64,
  end_ : Int64?,
  count_ : Int64?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(start_)
  ignore(end_)
  ignore(count_)
  bail("`Bytes.slice` is not yet ported")
}

///|
/// TODO: port `calc.abs` (typst-library/src/foundations/calc.rs).
fn impl_calc_abs(value_ : Value) -> Value raise HintedError {
  ignore(value_)
  bail("`calc.abs` is not yet ported")
}

///|
/// TODO: port `calc.pow` (typst-library/src/foundations/calc.rs).
fn impl_calc_pow(
  span : @syntax.Span,
  base_ : Value,
  exponent_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(span)
  ignore(base_)
  ignore(exponent_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.pow` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.exp` (typst-library/src/foundations/calc.rs).
fn impl_calc_exp(
  span : @syntax.Span,
  exponent_ : @syntax.Spanned[Value],
) -> Double raise SourceError {
  ignore(span)
  ignore(exponent_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.exp` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.sqrt` (typst-library/src/foundations/calc.rs).
fn impl_calc_sqrt(value_ : @syntax.Spanned[Value]) -> Double raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.sqrt` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.root` (typst-library/src/foundations/calc.rs).
fn impl_calc_root(
  radicand_ : Double,
  index_ : @syntax.Spanned[Int64],
) -> Double raise SourceError {
  ignore(radicand_)
  ignore(index_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.root` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.sin` (typst-library/src/foundations/calc.rs).
fn impl_calc_sin(angle_ : Value) -> Double raise HintedError {
  ignore(angle_)
  bail("`calc.sin` is not yet ported")
}

///|
/// TODO: port `calc.cos` (typst-library/src/foundations/calc.rs).
fn impl_calc_cos(angle_ : Value) -> Double raise HintedError {
  ignore(angle_)
  bail("`calc.cos` is not yet ported")
}

///|
/// TODO: port `calc.tan` (typst-library/src/foundations/calc.rs).
fn impl_calc_tan(angle_ : Value) -> Double raise HintedError {
  ignore(angle_)
  bail("`calc.tan` is not yet ported")
}

///|
/// TODO: port `calc.asin` (typst-library/src/foundations/calc.rs).
fn impl_calc_asin(value_ : @syntax.Spanned[Value]) -> Angle raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.asin` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.acos` (typst-library/src/foundations/calc.rs).
fn impl_calc_acos(value_ : @syntax.Spanned[Value]) -> Angle raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.acos` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.atan` (typst-library/src/foundations/calc.rs).
fn impl_calc_atan(value_ : Value) -> Angle raise HintedError {
  ignore(value_)
  bail("`calc.atan` is not yet ported")
}

///|
/// TODO: port `calc.atan2` (typst-library/src/foundations/calc.rs).
fn impl_calc_atan2(x_ : Value, y_ : Value) -> Angle raise HintedError {
  ignore(x_)
  ignore(y_)
  bail("`calc.atan2` is not yet ported")
}

///|
/// TODO: port `calc.sinh` (typst-library/src/foundations/calc.rs).
fn impl_calc_sinh(value_ : Double) -> Double raise HintedError {
  ignore(value_)
  bail("`calc.sinh` is not yet ported")
}

///|
/// TODO: port `calc.cosh` (typst-library/src/foundations/calc.rs).
fn impl_calc_cosh(value_ : Double) -> Double raise HintedError {
  ignore(value_)
  bail("`calc.cosh` is not yet ported")
}

///|
/// TODO: port `calc.tanh` (typst-library/src/foundations/calc.rs).
fn impl_calc_tanh(value_ : Double) -> Double raise HintedError {
  ignore(value_)
  bail("`calc.tanh` is not yet ported")
}

///|
/// TODO: port `calc.asinh` (typst-library/src/foundations/calc.rs).
fn impl_calc_asinh(value_ : Double) -> Double raise HintedError {
  ignore(value_)
  bail("`calc.asinh` is not yet ported")
}

///|
/// TODO: port `calc.acosh` (typst-library/src/foundations/calc.rs).
fn impl_calc_acosh(
  value_ : @syntax.Spanned[Double],
) -> Double raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.acosh` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.atanh` (typst-library/src/foundations/calc.rs).
fn impl_calc_atanh(
  value_ : @syntax.Spanned[Double],
) -> Double raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.atanh` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(10.0)`.
fn impl_calc_log__base_default() -> @syntax.Spanned[Double] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `calc_log.base` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.log` (typst-library/src/foundations/calc.rs).
fn impl_calc_log(
  span : @syntax.Span,
  value_ : @syntax.Spanned[Value],
  base_ : @syntax.Spanned[Double],
) -> Double raise SourceError {
  ignore(span)
  ignore(value_)
  ignore(base_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.log` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.ln` (typst-library/src/foundations/calc.rs).
fn impl_calc_ln(
  span : @syntax.Span,
  value_ : @syntax.Spanned[Value],
) -> Double raise SourceError {
  ignore(span)
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.ln` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.erf` (typst-library/src/foundations/calc.rs).
fn impl_calc_erf(value_ : Double) -> Double raise HintedError {
  ignore(value_)
  bail("`calc.erf` is not yet ported")
}

///|
/// TODO: port `calc.fact` (typst-library/src/foundations/calc.rs).
fn impl_calc_fact(number_ : U64) -> Int64 raise HintedError {
  ignore(number_)
  bail("`calc.fact` is not yet ported")
}

///|
/// TODO: port `calc.perm` (typst-library/src/foundations/calc.rs).
fn impl_calc_perm(base_ : U64, numbers_ : U64) -> Int64 raise HintedError {
  ignore(base_)
  ignore(numbers_)
  bail("`calc.perm` is not yet ported")
}

///|
/// TODO: port `calc.binom` (typst-library/src/foundations/calc.rs).
fn impl_calc_binom(n_ : U64, k_ : U64) -> Int64 raise HintedError {
  ignore(n_)
  ignore(k_)
  bail("`calc.binom` is not yet ported")
}

///|
/// TODO: port `calc.gcd` (typst-library/src/foundations/calc.rs).
fn impl_calc_gcd(a_ : Int64, b_ : Int64) -> Int64 raise HintedError {
  ignore(a_)
  ignore(b_)
  bail("`calc.gcd` is not yet ported")
}

///|
/// TODO: port `calc.lcm` (typst-library/src/foundations/calc.rs).
fn impl_calc_lcm(a_ : Int64, b_ : Int64) -> Int64 raise HintedError {
  ignore(a_)
  ignore(b_)
  bail("`calc.lcm` is not yet ported")
}

///|
/// TODO: port `calc.floor` (typst-library/src/foundations/calc.rs).
fn impl_calc_floor(value_ : Value) -> Int64 raise HintedError {
  ignore(value_)
  bail("`calc.floor` is not yet ported")
}

///|
/// TODO: port `calc.ceil` (typst-library/src/foundations/calc.rs).
fn impl_calc_ceil(value_ : Value) -> Int64 raise HintedError {
  ignore(value_)
  bail("`calc.ceil` is not yet ported")
}

///|
/// TODO: port `calc.trunc` (typst-library/src/foundations/calc.rs).
fn impl_calc_trunc(value_ : Value) -> Int64 raise HintedError {
  ignore(value_)
  bail("`calc.trunc` is not yet ported")
}

///|
/// TODO: port `calc.fract` (typst-library/src/foundations/calc.rs).
fn impl_calc_fract(value_ : Value) -> Value raise HintedError {
  ignore(value_)
  bail("`calc.fract` is not yet ported")
}

///|
/// TODO: port `calc.round` (typst-library/src/foundations/calc.rs).
fn impl_calc_round(value_ : Value, digits_ : Int64) -> Value raise HintedError {
  ignore(value_)
  ignore(digits_)
  bail("`calc.round` is not yet ported")
}

///|
/// TODO: port `calc.clamp` (typst-library/src/foundations/calc.rs).
fn impl_calc_clamp(
  span : @syntax.Span,
  value_ : Value,
  min_ : Value,
  max_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(span)
  ignore(value_)
  ignore(min_)
  ignore(max_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.clamp` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.min` (typst-library/src/foundations/calc.rs).
fn impl_calc_min(
  span : @syntax.Span,
  values_ : Array[@syntax.Spanned[Value]],
) -> Value raise SourceError {
  ignore(span)
  ignore(values_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.min` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.max` (typst-library/src/foundations/calc.rs).
fn impl_calc_max(
  span : @syntax.Span,
  values_ : Array[@syntax.Spanned[Value]],
) -> Value raise SourceError {
  ignore(span)
  ignore(values_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.max` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.even` (typst-library/src/foundations/calc.rs).
fn impl_calc_even(value_ : Int64) -> Bool raise HintedError {
  ignore(value_)
  bail("`calc.even` is not yet ported")
}

///|
/// TODO: port `calc.odd` (typst-library/src/foundations/calc.rs).
fn impl_calc_odd(value_ : Int64) -> Bool raise HintedError {
  ignore(value_)
  bail("`calc.odd` is not yet ported")
}

///|
/// TODO: port `calc.rem` (typst-library/src/foundations/calc.rs).
fn impl_calc_rem(
  span : @syntax.Span,
  dividend_ : Value,
  divisor_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(span)
  ignore(dividend_)
  ignore(divisor_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.rem` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.div-euclid` (typst-library/src/foundations/calc.rs).
fn impl_calc_div_euclid(
  span : @syntax.Span,
  dividend_ : Value,
  divisor_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(span)
  ignore(dividend_)
  ignore(divisor_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.div-euclid` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.rem-euclid` (typst-library/src/foundations/calc.rs).
fn impl_calc_rem_euclid(
  span : @syntax.Span,
  dividend_ : Value,
  divisor_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(span)
  ignore(dividend_)
  ignore(divisor_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.rem-euclid` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.quo` (typst-library/src/foundations/calc.rs).
fn impl_calc_quo(
  span : @syntax.Span,
  dividend_ : Value,
  divisor_ : @syntax.Spanned[Value],
) -> Int64 raise SourceError {
  ignore(span)
  ignore(dividend_)
  ignore(divisor_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.quo` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(2.0)`.
fn impl_calc_norm__p_default() -> @syntax.Spanned[Double] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `calc_norm.p` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `calc.norm` (typst-library/src/foundations/calc.rs).
fn impl_calc_norm(
  p_ : @syntax.Spanned[Double],
  values_ : Array[Double],
) -> Double raise SourceError {
  ignore(p_)
  ignore(values_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`calc.norm` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Content.func` (typst-library/src/foundations/content/mod.rs).
fn impl_content_func(self_ : Content) -> Value raise HintedError {
  ignore(self_)
  bail("`Content.func` is not yet ported")
}

///|
/// TODO: port `Content.has` (typst-library/src/foundations/content/mod.rs).
fn impl_content_has(self_ : Content, field_ : String) -> Bool raise HintedError {
  ignore(self_)
  ignore(field_)
  bail("`Content.has` is not yet ported")
}

///|
/// TODO: port `Content.at` (typst-library/src/foundations/content/mod.rs).
fn impl_content_at(
  self_ : Content,
  field_ : String,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(field_)
  ignore(default_)
  bail("`Content.at` is not yet ported")
}

///|
/// TODO: port `Content.fields` (typst-library/src/foundations/content/mod.rs).
fn impl_content_fields(self_ : Content) -> Dict raise HintedError {
  ignore(self_)
  bail("`Content.fields` is not yet ported")
}

///|
/// TODO: port `Content.location` (typst-library/src/foundations/content/mod.rs).
fn impl_content_location(self_ : Content) -> Value raise HintedError {
  ignore(self_)
  bail("`Content.location` is not yet ported")
}

///|
/// TODO: port `Datetime.construct` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_construct(
  year_ : I32?,
  month_ : Value?,
  day_ : U8?,
  hour_ : U8?,
  minute_ : U8?,
  second_ : U8?,
) -> Value raise HintedError {
  ignore(year_)
  ignore(month_)
  ignore(day_)
  ignore(hour_)
  ignore(minute_)
  ignore(second_)
  bail("`Datetime.construct` is not yet ported")
}

///|
/// TODO: port default `Default::default()`.
fn impl_datetime_today__offset_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `datetime_today.offset` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Datetime.today` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_today(
  engine : Engine,
  offset_ : Value,
) -> Value raise HintedError {
  ignore(engine)
  ignore(offset_)
  bail("`Datetime.today` is not yet ported")
}

///|
/// TODO: port default `Default::default()`.
fn impl_datetime_display__pattern_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `datetime_display.pattern` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Datetime.display` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_display(
  self_ : Value,
  pattern_ : Value,
) -> String raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Datetime.display` is not yet ported")
}

///|
/// TODO: port `Datetime.year` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_year(self_ : Value) -> I32? raise HintedError {
  ignore(self_)
  bail("`Datetime.year` is not yet ported")
}

///|
/// TODO: port `Datetime.month` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_month(self_ : Value) -> U8? raise HintedError {
  ignore(self_)
  bail("`Datetime.month` is not yet ported")
}

///|
/// TODO: port `Datetime.weekday` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_weekday(self_ : Value) -> U8? raise HintedError {
  ignore(self_)
  bail("`Datetime.weekday` is not yet ported")
}

///|
/// TODO: port `Datetime.day` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_day(self_ : Value) -> U8? raise HintedError {
  ignore(self_)
  bail("`Datetime.day` is not yet ported")
}

///|
/// TODO: port `Datetime.hour` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_hour(self_ : Value) -> U8? raise HintedError {
  ignore(self_)
  bail("`Datetime.hour` is not yet ported")
}

///|
/// TODO: port `Datetime.minute` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_minute(self_ : Value) -> U8? raise HintedError {
  ignore(self_)
  bail("`Datetime.minute` is not yet ported")
}

///|
/// TODO: port `Datetime.second` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_second(self_ : Value) -> U8? raise HintedError {
  ignore(self_)
  bail("`Datetime.second` is not yet ported")
}

///|
/// TODO: port `Datetime.ordinal` (typst-library/src/foundations/datetime.rs).
fn impl_datetime_ordinal(self_ : Value) -> U16? raise HintedError {
  ignore(self_)
  bail("`Datetime.ordinal` is not yet ported")
}

///|
/// TODO: port `Decimal.construct` (typst-library/src/foundations/decimal.rs).
fn impl_decimal_construct(
  engine : Engine,
  value_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Decimal.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Dict.construct` (typst-library/src/foundations/dict.rs).
fn impl_dict_construct(
  engine : Engine,
  value_ : @syntax.Spanned[Value],
) -> Dict raise SourceError {
  ignore(engine)
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Dict.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Dict.len` (typst-library/src/foundations/dict.rs).
fn impl_dict_len(self_ : Dict) -> USize raise HintedError {
  ignore(self_)
  bail("`Dict.len` is not yet ported")
}

///|
/// TODO: port `Dict.at` (typst-library/src/foundations/dict.rs).
fn impl_dict_at(
  self_ : Dict,
  key_ : String,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(key_)
  ignore(default_)
  bail("`Dict.at` is not yet ported")
}

///|
/// TODO: port `Dict.insert` (typst-library/src/foundations/dict.rs).
fn impl_dict_insert(
  self_ : Dict,
  key_ : String,
  value_ : Value,
) -> Unit raise HintedError {
  ignore(self_)
  ignore(key_)
  ignore(value_)
  bail("`Dict.insert` is not yet ported")
}

///|
/// TODO: port `Dict.remove` (typst-library/src/foundations/dict.rs).
fn impl_dict_remove(
  self_ : Dict,
  key_ : String,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(key_)
  ignore(default_)
  bail("`Dict.remove` is not yet ported")
}

///|
/// TODO: port `Dict.keys` (typst-library/src/foundations/dict.rs).
fn impl_dict_keys(self_ : Dict) -> Arr raise HintedError {
  ignore(self_)
  bail("`Dict.keys` is not yet ported")
}

///|
/// TODO: port `Dict.values` (typst-library/src/foundations/dict.rs).
fn impl_dict_values(self_ : Dict) -> Arr raise HintedError {
  ignore(self_)
  bail("`Dict.values` is not yet ported")
}

///|
/// TODO: port `Dict.pairs` (typst-library/src/foundations/dict.rs).
fn impl_dict_pairs(self_ : Dict) -> Arr raise HintedError {
  ignore(self_)
  bail("`Dict.pairs` is not yet ported")
}

///|
/// TODO: port `Dict.filter` (typst-library/src/foundations/dict.rs).
fn impl_dict_filter(
  self_ : Dict,
  engine : Engine,
  context : Context,
  test_ : Func,
) -> Dict raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(test_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Dict.filter` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Dict.map` (typst-library/src/foundations/dict.rs).
fn impl_dict_map(
  self_ : Dict,
  engine : Engine,
  context : Context,
  mapper_ : Func,
) -> Dict raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(mapper_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Dict.map` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Duration.construct` (typst-library/src/foundations/duration.rs).
fn impl_duration_construct(
  seconds_ : Int64,
  minutes_ : Int64,
  hours_ : Int64,
  days_ : Int64,
  weeks_ : Int64,
) -> Value raise HintedError {
  ignore(seconds_)
  ignore(minutes_)
  ignore(hours_)
  ignore(days_)
  ignore(weeks_)
  bail("`Duration.construct` is not yet ported")
}

///|
/// TODO: port `Duration.seconds` (typst-library/src/foundations/duration.rs).
fn impl_duration_seconds(self_ : Value) -> Double raise HintedError {
  ignore(self_)
  bail("`Duration.seconds` is not yet ported")
}

///|
/// TODO: port `Duration.minutes` (typst-library/src/foundations/duration.rs).
fn impl_duration_minutes(self_ : Value) -> Double raise HintedError {
  ignore(self_)
  bail("`Duration.minutes` is not yet ported")
}

///|
/// TODO: port `Duration.hours` (typst-library/src/foundations/duration.rs).
fn impl_duration_hours(self_ : Value) -> Double raise HintedError {
  ignore(self_)
  bail("`Duration.hours` is not yet ported")
}

///|
/// TODO: port `Duration.days` (typst-library/src/foundations/duration.rs).
fn impl_duration_days(self_ : Value) -> Double raise HintedError {
  ignore(self_)
  bail("`Duration.days` is not yet ported")
}

///|
/// TODO: port `Duration.weeks` (typst-library/src/foundations/duration.rs).
fn impl_duration_weeks(self_ : Value) -> Double raise HintedError {
  ignore(self_)
  bail("`Duration.weeks` is not yet ported")
}

///|
/// TODO: port `f64.construct` (typst-library/src/foundations/float.rs).
fn impl_f64_construct(value_ : Value) -> Double raise HintedError {
  ignore(value_)
  bail("`f64.construct` is not yet ported")
}

///|
/// TODO: port `f64.is-nan` (typst-library/src/foundations/float.rs).
fn impl_f64_is_nan(self_ : Double) -> Bool raise HintedError {
  ignore(self_)
  bail("`f64.is-nan` is not yet ported")
}

///|
/// TODO: port `f64.is-infinite` (typst-library/src/foundations/float.rs).
fn impl_f64_is_infinite(self_ : Double) -> Bool raise HintedError {
  ignore(self_)
  bail("`f64.is-infinite` is not yet ported")
}

///|
/// TODO: port `f64.signum` (typst-library/src/foundations/float.rs).
fn impl_f64_signum(self_ : Double) -> Double raise HintedError {
  ignore(self_)
  bail("`f64.signum` is not yet ported")
}

///|
/// TODO: port default `Endianness::Little`.
fn impl_f64_from_bytes__endian_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `f64_from_bytes.endian` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `f64.from-bytes` (typst-library/src/foundations/float.rs).
fn impl_f64_from_bytes(
  bytes_ : Value,
  endian_ : Value,
) -> Double raise HintedError {
  ignore(bytes_)
  ignore(endian_)
  bail("`f64.from-bytes` is not yet ported")
}

///|
/// TODO: port default `Endianness::Little`.
fn impl_f64_to_bytes__endian_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `f64_to_bytes.endian` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `f64.to-bytes` (typst-library/src/foundations/float.rs).
fn impl_f64_to_bytes(
  self_ : Double,
  endian_ : Value,
  size_ : U32,
) -> Value raise HintedError {
  ignore(self_)
  ignore(endian_)
  ignore(size_)
  bail("`f64.to-bytes` is not yet ported")
}

///|
/// TODO: port `Func.with` (typst-library/src/foundations/func.rs).
fn impl_func_with(self_ : Func, args : Args) -> Func raise HintedError {
  ignore(self_)
  ignore(args)
  bail("`Func.with` is not yet ported")
}

///|
/// TODO: port `Func.where-` (typst-library/src/foundations/func.rs).
fn impl_func_where(self_ : Func, args : Args) -> Value raise HintedError {
  ignore(self_)
  ignore(args)
  bail("`Func.where-` is not yet ported")
}

///|
/// TODO: port default `Spanned::new(Base::Default, Span::detached())`.
fn impl_i64_construct__base_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `i64_construct.base` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `i64.construct` (typst-library/src/foundations/int.rs).
fn impl_i64_construct(
  value_ : @syntax.Spanned[Value],
  base_ : @syntax.Spanned[Value],
) -> Int64 raise SourceError {
  ignore(value_)
  ignore(base_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`i64.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `i64.signum` (typst-library/src/foundations/int.rs).
fn impl_i64_signum(self_ : Int64) -> Int64 raise HintedError {
  ignore(self_)
  bail("`i64.signum` is not yet ported")
}

///|
/// TODO: port `i64.bit-not` (typst-library/src/foundations/int.rs).
fn impl_i64_bit_not(self_ : Int64) -> Int64 raise HintedError {
  ignore(self_)
  bail("`i64.bit-not` is not yet ported")
}

///|
/// TODO: port `i64.bit-and` (typst-library/src/foundations/int.rs).
fn impl_i64_bit_and(self_ : Int64, rhs_ : Int64) -> Int64 raise HintedError {
  ignore(self_)
  ignore(rhs_)
  bail("`i64.bit-and` is not yet ported")
}

///|
/// TODO: port `i64.bit-or` (typst-library/src/foundations/int.rs).
fn impl_i64_bit_or(self_ : Int64, rhs_ : Int64) -> Int64 raise HintedError {
  ignore(self_)
  ignore(rhs_)
  bail("`i64.bit-or` is not yet ported")
}

///|
/// TODO: port `i64.bit-xor` (typst-library/src/foundations/int.rs).
fn impl_i64_bit_xor(self_ : Int64, rhs_ : Int64) -> Int64 raise HintedError {
  ignore(self_)
  ignore(rhs_)
  bail("`i64.bit-xor` is not yet ported")
}

///|
/// TODO: port `i64.bit-lshift` (typst-library/src/foundations/int.rs).
fn impl_i64_bit_lshift(self_ : Int64, shift_ : U32) -> Int64 raise HintedError {
  ignore(self_)
  ignore(shift_)
  bail("`i64.bit-lshift` is not yet ported")
}

///|
/// TODO: port `i64.bit-rshift` (typst-library/src/foundations/int.rs).
fn impl_i64_bit_rshift(
  self_ : Int64,
  shift_ : U32,
  logical_ : Bool,
) -> Int64 raise HintedError {
  ignore(self_)
  ignore(shift_)
  ignore(logical_)
  bail("`i64.bit-rshift` is not yet ported")
}

///|
/// TODO: port default `Endianness::Little`.
fn impl_i64_from_bytes__endian_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `i64_from_bytes.endian` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `i64.from-bytes` (typst-library/src/foundations/int.rs).
fn impl_i64_from_bytes(
  bytes_ : Value,
  endian_ : Value,
  signed_ : Bool,
) -> Int64 raise HintedError {
  ignore(bytes_)
  ignore(endian_)
  ignore(signed_)
  bail("`i64.from-bytes` is not yet ported")
}

///|
/// TODO: port default `Endianness::Little`.
fn impl_i64_to_bytes__endian_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `i64_to_bytes.endian` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `i64.to-bytes` (typst-library/src/foundations/int.rs).
fn impl_i64_to_bytes(
  self_ : Int64,
  endian_ : Value,
  size_ : USize,
) -> Value raise HintedError {
  ignore(self_)
  ignore(endian_)
  ignore(size_)
  bail("`i64.to-bytes` is not yet ported")
}

///|
/// TODO: port `Label.construct` (typst-library/src/foundations/label.rs).
fn impl_label_construct(name_ : String) -> Label raise HintedError {
  ignore(name_)
  bail("`Label.construct` is not yet ported")
}

///|
/// TODO: port `panic` (typst-library/src/foundations/mod.rs).
fn impl_panic(values_ : Array[Value]) -> Unit raise HintedError {
  ignore(values_)
  bail("`panic` is not yet ported")
}

///|
/// TODO: port `assert` (typst-library/src/foundations/mod.rs).
fn impl_assert(condition_ : Bool, message_ : String?) -> Unit raise HintedError {
  ignore(condition_)
  ignore(message_)
  bail("`assert` is not yet ported")
}

///|
/// TODO: port `assert.eq` (typst-library/src/foundations/mod.rs).
fn impl_assert_eq(
  left_ : Value,
  right_ : Value,
  message_ : String?,
) -> Unit raise HintedError {
  ignore(left_)
  ignore(right_)
  ignore(message_)
  bail("`assert.eq` is not yet ported")
}

///|
/// TODO: port `assert.ne` (typst-library/src/foundations/mod.rs).
fn impl_assert_ne(
  left_ : Value,
  right_ : Value,
  message_ : String?,
) -> Unit raise HintedError {
  ignore(left_)
  ignore(right_)
  ignore(message_)
  bail("`assert.ne` is not yet ported")
}

///|
/// TODO: port default `SyntaxMode::Code`.
fn impl_eval__mode_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `eval.mode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_eval__scope_default() -> Dict raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `eval.scope` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `eval` (typst-library/src/foundations/mod.rs).
fn impl_eval(
  engine : Engine,
  source_ : @syntax.Spanned[String],
  mode_ : Value,
  scope_ : Dict,
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  ignore(mode_)
  ignore(scope_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`eval` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `RootedPath.construct` (typst-library/src/foundations/path.rs).
fn impl_rooted_path_construct(
  path_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(path_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`RootedPath.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `plugin` (typst-library/src/foundations/plugin.rs).
fn impl_plugin(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`plugin` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `plugin.transition` (typst-library/src/foundations/plugin.rs).
fn impl_plugin_transition(
  func_ : Value,
  arguments_ : Array[Value],
) -> Value raise HintedError {
  ignore(func_)
  ignore(arguments_)
  bail("`plugin.transition` is not yet ported")
}

///|
/// TODO: port `repr` (typst-library/src/foundations/repr.rs).
fn impl_repr(value_ : Value) -> String raise HintedError {
  ignore(value_)
  bail("`repr` is not yet ported")
}

///|
/// TODO: port `Selector.construct` (typst-library/src/foundations/selector.rs).
fn impl_selector_construct(target_ : Value) -> Value raise HintedError {
  ignore(target_)
  bail("`Selector.construct` is not yet ported")
}

///|
/// TODO: port `Selector.or` (typst-library/src/foundations/selector.rs).
fn impl_selector_or(
  self_ : Value,
  others_ : Array[Value],
) -> Value raise HintedError {
  ignore(self_)
  ignore(others_)
  bail("`Selector.or` is not yet ported")
}

///|
/// TODO: port `Selector.and` (typst-library/src/foundations/selector.rs).
fn impl_selector_and(
  self_ : Value,
  others_ : Array[Value],
) -> Value raise HintedError {
  ignore(self_)
  ignore(others_)
  bail("`Selector.and` is not yet ported")
}

///|
/// TODO: port `Selector.before` (typst-library/src/foundations/selector.rs).
fn impl_selector_before(
  self_ : Value,
  end_ : Value,
  inclusive_ : Bool,
) -> Value raise HintedError {
  ignore(self_)
  ignore(end_)
  ignore(inclusive_)
  bail("`Selector.before` is not yet ported")
}

///|
/// TODO: port `Selector.after` (typst-library/src/foundations/selector.rs).
fn impl_selector_after(
  self_ : Value,
  start_ : Value,
  inclusive_ : Bool,
) -> Value raise HintedError {
  ignore(self_)
  ignore(start_)
  ignore(inclusive_)
  bail("`Selector.after` is not yet ported")
}

///|
/// TODO: port `Selector.within` (typst-library/src/foundations/selector.rs).
fn impl_selector_within(
  self_ : Value,
  ancestor_ : Value,
) -> Value raise HintedError {
  ignore(self_)
  ignore(ancestor_)
  bail("`Selector.within` is not yet ported")
}

///|
/// TODO: port default `Spanned::detached(Base::Default)`.
fn impl_str_construct__base_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `str_construct.base` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Str.construct` (typst-library/src/foundations/str.rs).
fn impl_str_construct(
  value_ : Value,
  base_ : @syntax.Spanned[Value],
) -> String raise SourceError {
  ignore(value_)
  ignore(base_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Str.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Str.len` (typst-library/src/foundations/str.rs).
fn impl_str_len(self_ : String) -> USize raise HintedError {
  ignore(self_)
  bail("`Str.len` is not yet ported")
}

///|
/// TODO: port `Str.first` (typst-library/src/foundations/str.rs).
fn impl_str_first(
  self_ : String,
  default_ : String?,
) -> String raise HintedError {
  ignore(self_)
  ignore(default_)
  bail("`Str.first` is not yet ported")
}

///|
/// TODO: port `Str.last` (typst-library/src/foundations/str.rs).
fn impl_str_last(
  self_ : String,
  default_ : String?,
) -> String raise HintedError {
  ignore(self_)
  ignore(default_)
  bail("`Str.last` is not yet ported")
}

///|
/// TODO: port `Str.at` (typst-library/src/foundations/str.rs).
fn impl_str_at(
  self_ : String,
  index_ : Int64,
  default_ : Value?,
) -> Value raise HintedError {
  ignore(self_)
  ignore(index_)
  ignore(default_)
  bail("`Str.at` is not yet ported")
}

///|
/// TODO: port default `Default::default()`.
fn impl_str_slice__end_default() -> Int64? raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `str_slice.end` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Str.slice` (typst-library/src/foundations/str.rs).
fn impl_str_slice(
  self_ : String,
  start_ : Int64,
  end_ : Int64?,
  count_ : Int64?,
) -> String raise HintedError {
  ignore(self_)
  ignore(start_)
  ignore(end_)
  ignore(count_)
  bail("`Str.slice` is not yet ported")
}

///|
/// TODO: port `Str.clusters` (typst-library/src/foundations/str.rs).
fn impl_str_clusters(self_ : String) -> Arr raise HintedError {
  ignore(self_)
  bail("`Str.clusters` is not yet ported")
}

///|
/// TODO: port `Str.codepoints` (typst-library/src/foundations/str.rs).
fn impl_str_codepoints(self_ : String) -> Arr raise HintedError {
  ignore(self_)
  bail("`Str.codepoints` is not yet ported")
}

///|
/// TODO: port `Str.to-unicode` (typst-library/src/foundations/str.rs).
fn impl_str_to_unicode(character_ : Value) -> U32 raise HintedError {
  ignore(character_)
  bail("`Str.to-unicode` is not yet ported")
}

///|
/// TODO: port `Str.from-unicode` (typst-library/src/foundations/str.rs).
fn impl_str_from_unicode(value_ : U32) -> String raise HintedError {
  ignore(value_)
  bail("`Str.from-unicode` is not yet ported")
}

///|
/// TODO: port default `UnicodeNormalForm::Nfc`.
fn impl_str_normalize__form_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `str_normalize.form` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Str.normalize` (typst-library/src/foundations/str.rs).
fn impl_str_normalize(
  self_ : String,
  form_ : Value,
) -> String raise HintedError {
  ignore(self_)
  ignore(form_)
  bail("`Str.normalize` is not yet ported")
}

///|
/// TODO: port `Str.contains` (typst-library/src/foundations/str.rs).
fn impl_str_contains(
  self_ : String,
  pattern_ : Value,
) -> Bool raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Str.contains` is not yet ported")
}

///|
/// TODO: port `Str.starts-with` (typst-library/src/foundations/str.rs).
fn impl_str_starts_with(
  self_ : String,
  pattern_ : Value,
) -> Bool raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Str.starts-with` is not yet ported")
}

///|
/// TODO: port `Str.ends-with` (typst-library/src/foundations/str.rs).
fn impl_str_ends_with(
  self_ : String,
  pattern_ : Value,
) -> Bool raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Str.ends-with` is not yet ported")
}

///|
/// TODO: port `Str.find` (typst-library/src/foundations/str.rs).
fn impl_str_find(self_ : String, pattern_ : Value) -> String? raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Str.find` is not yet ported")
}

///|
/// TODO: port `Str.position` (typst-library/src/foundations/str.rs).
fn impl_str_position(
  self_ : String,
  pattern_ : Value,
) -> USize? raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Str.position` is not yet ported")
}

///|
/// TODO: port `Str.match-` (typst-library/src/foundations/str.rs).
fn impl_str_match(self_ : String, pattern_ : Value) -> Dict? raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Str.match-` is not yet ported")
}

///|
/// TODO: port `Str.matches` (typst-library/src/foundations/str.rs).
fn impl_str_matches(self_ : String, pattern_ : Value) -> Arr raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Str.matches` is not yet ported")
}

///|
/// TODO: port `Str.replace` (typst-library/src/foundations/str.rs).
fn impl_str_replace(
  self_ : String,
  engine : Engine,
  context : Context,
  pattern_ : Value,
  replacement_ : Value,
  count_ : USize?,
) -> String raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(pattern_)
  ignore(replacement_)
  ignore(count_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Str.replace` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_str_trim__pattern_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `str_trim.pattern` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Str.trim` (typst-library/src/foundations/str.rs).
fn impl_str_trim(
  self_ : String,
  pattern_ : Value,
  at_ : Value?,
  repeat_ : Bool,
) -> String raise HintedError {
  ignore(self_)
  ignore(pattern_)
  ignore(at_)
  ignore(repeat_)
  bail("`Str.trim` is not yet ported")
}

///|
/// TODO: port default `Default::default()`.
fn impl_str_split__pattern_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `str_split.pattern` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Str.split` (typst-library/src/foundations/str.rs).
fn impl_str_split(self_ : String, pattern_ : Value) -> Arr raise HintedError {
  ignore(self_)
  ignore(pattern_)
  bail("`Str.split` is not yet ported")
}

///|
/// TODO: port `Str.rev` (typst-library/src/foundations/str.rs).
fn impl_str_rev(self_ : String) -> String raise HintedError {
  ignore(self_)
  bail("`Str.rev` is not yet ported")
}

///|
/// TODO: port `Regex.construct` (typst-library/src/foundations/str.rs).
fn impl_regex_construct(
  regex_ : @syntax.Spanned[String],
) -> Value raise SourceError {
  ignore(regex_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Regex.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Symbol.construct` (typst-library/src/foundations/symbol.rs).
fn impl_symbol_construct(
  span : @syntax.Span,
  variants_ : Array[@syntax.Spanned[Value]],
) -> Value raise SourceError {
  ignore(span)
  ignore(variants_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Symbol.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `target` (typst-library/src/foundations/target.rs).
fn impl_target(context : Context) -> Value raise HintedError {
  ignore(context)
  bail("`target` is not yet ported")
}

///|
/// TODO: port `Type.construct` (typst-library/src/foundations/ty.rs).
fn impl_type_construct(value_ : Value) -> Type raise HintedError {
  ignore(value_)
  bail("`Type.construct` is not yet ported")
}

///|
/// TODO: port `Version.construct` (typst-library/src/foundations/version.rs).
fn impl_version_construct(
  components_ : Array[Value],
) -> Value raise HintedError {
  ignore(components_)
  bail("`Version.construct` is not yet ported")
}

///|
/// TODO: port `Version.at` (typst-library/src/foundations/version.rs).
fn impl_version_at(self_ : Value, index_ : Int64) -> Int64 raise HintedError {
  ignore(self_)
  ignore(index_)
  bail("`Version.at` is not yet ported")
}

///|
/// TODO: port `Counter.construct` (typst-library/src/introspection/counter.rs).
fn impl_counter_construct(key_ : Value) -> Value raise HintedError {
  ignore(key_)
  bail("`Counter.construct` is not yet ported")
}

///|
/// TODO: port `Counter.get` (typst-library/src/introspection/counter.rs).
fn impl_counter_get(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Counter.get` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_counter_display__numbering_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `counter_display.numbering` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_counter_display__at_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `counter_display.at` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Counter.display` (typst-library/src/introspection/counter.rs).
fn impl_counter_display(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  numbering_ : Value,
  at_ : Value,
  both_ : Bool,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(numbering_)
  ignore(at_)
  ignore(both_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Counter.display` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Counter.at` (typst-library/src/introspection/counter.rs).
fn impl_counter_at(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  selector_ : Value,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(selector_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Counter.at` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Counter.final-` (typst-library/src/introspection/counter.rs).
fn impl_counter_final(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Counter.final-` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `NonZeroUsize::ONE`.
fn impl_counter_step__level_default() -> NonZeroUSize raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `counter_step.level` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Counter.step` (typst-library/src/introspection/counter.rs).
fn impl_counter_step(
  self_ : Value,
  span : @syntax.Span,
  level_ : NonZeroUSize,
) -> Content raise HintedError {
  ignore(self_)
  ignore(span)
  ignore(level_)
  bail("`Counter.step` is not yet ported")
}

///|
/// TODO: port `Counter.update` (typst-library/src/introspection/counter.rs).
fn impl_counter_update(
  self_ : Value,
  span : @syntax.Span,
  update_ : Value,
) -> Content raise HintedError {
  ignore(self_)
  ignore(span)
  ignore(update_)
  bail("`Counter.update` is not yet ported")
}

///|
/// TODO: port `here` (typst-library/src/introspection/here.rs).
fn impl_here(context : Context) -> Value raise HintedError {
  ignore(context)
  bail("`here` is not yet ported")
}

///|
/// TODO: port `locate` (typst-library/src/introspection/locate.rs).
fn impl_locate(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  selector_ : Value,
) -> Value raise SourceError {
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(selector_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`locate` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Location.page` (typst-library/src/introspection/location.rs).
fn impl_location_page(
  self_ : Value,
  engine : Engine,
  span : @syntax.Span,
) -> NonZeroUSize? raise HintedError {
  ignore(self_)
  ignore(engine)
  ignore(span)
  bail("`Location.page` is not yet ported")
}

///|
/// TODO: port `Location.page-numbering` (typst-library/src/introspection/location.rs).
fn impl_location_page_numbering(
  self_ : Value,
  engine : Engine,
  span : @syntax.Span,
) -> Value raise HintedError {
  ignore(self_)
  ignore(engine)
  ignore(span)
  bail("`Location.page-numbering` is not yet ported")
}

///|
/// TODO: port `Location.position` (typst-library/src/introspection/location.rs).
fn impl_location_position(
  self_ : Value,
  engine : Engine,
  span : @syntax.Span,
) -> Dict? raise HintedError {
  ignore(self_)
  ignore(engine)
  ignore(span)
  bail("`Location.position` is not yet ported")
}

///|
/// TODO: port `query` (typst-library/src/introspection/query.rs).
fn impl_query(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  target_ : Value,
) -> Arr raise HintedError {
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(target_)
  bail("`query` is not yet ported")
}

///|
/// TODO: port default `Default::default()`.
fn impl_state_construct__init_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `state_construct.init` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `State.construct` (typst-library/src/introspection/state.rs).
fn impl_state_construct(
  key_ : String,
  init_ : Value,
) -> Value raise HintedError {
  ignore(key_)
  ignore(init_)
  bail("`State.construct` is not yet ported")
}

///|
/// TODO: port `State.get` (typst-library/src/introspection/state.rs).
fn impl_state_get(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`State.get` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `State.at` (typst-library/src/introspection/state.rs).
fn impl_state_at(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  selector_ : Value,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(selector_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`State.at` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `State.final-` (typst-library/src/introspection/state.rs).
fn impl_state_final(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Value raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`State.final-` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `State.update` (typst-library/src/introspection/state.rs).
fn impl_state_update(
  self_ : Value,
  span : @syntax.Span,
  update_ : Value,
) -> Content raise HintedError {
  ignore(self_)
  ignore(span)
  ignore(update_)
  bail("`State.update` is not yet ported")
}

///|
/// TODO: port `Alignment.axis` (typst-library/src/layout/align.rs).
fn impl_alignment_axis(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Alignment.axis` is not yet ported")
}

///|
/// TODO: port `Alignment.inv` (typst-library/src/layout/align.rs).
fn impl_alignment_inv(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Alignment.inv` is not yet ported")
}

///|
/// TODO: port `Angle.rad` (typst-library/src/layout/angle.rs).
fn impl_angle_to_rad(self_ : Angle) -> Double raise HintedError {
  ignore(self_)
  bail("`Angle.rad` is not yet ported")
}

///|
/// TODO: port `Angle.deg` (typst-library/src/layout/angle.rs).
fn impl_angle_to_deg(self_ : Angle) -> Double raise HintedError {
  ignore(self_)
  bail("`Angle.deg` is not yet ported")
}

///|
/// TODO: port `Dir.from` (typst-library/src/layout/dir.rs).
fn impl_dir_from(side_ : Value) -> Value raise HintedError {
  ignore(side_)
  bail("`Dir.from` is not yet ported")
}

///|
/// TODO: port `Dir.to` (typst-library/src/layout/dir.rs).
fn impl_dir_to(side_ : Value) -> Value raise HintedError {
  ignore(side_)
  bail("`Dir.to` is not yet ported")
}

///|
/// TODO: port `Dir.axis` (typst-library/src/layout/dir.rs).
fn impl_dir_axis(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Dir.axis` is not yet ported")
}

///|
/// TODO: port `Dir.sign` (typst-library/src/layout/dir.rs).
fn impl_dir_sign(self_ : Value) -> Int64 raise HintedError {
  ignore(self_)
  bail("`Dir.sign` is not yet ported")
}

///|
/// TODO: port `Dir.start` (typst-library/src/layout/dir.rs).
fn impl_dir_start(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Dir.start` is not yet ported")
}

///|
/// TODO: port `Dir.end` (typst-library/src/layout/dir.rs).
fn impl_dir_end(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Dir.end` is not yet ported")
}

///|
/// TODO: port `Dir.inv` (typst-library/src/layout/dir.rs).
fn impl_dir_inv(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Dir.inv` is not yet ported")
}

///|
/// TODO: port `layout` (typst-library/src/layout/layout.rs).
fn impl_layout(span : @syntax.Span, func_ : Func) -> Content raise HintedError {
  ignore(span)
  ignore(func_)
  bail("`layout` is not yet ported")
}

///|
/// TODO: port `Length.pt` (typst-library/src/layout/length.rs).
fn impl_length_to_pt(
  self_ : Length,
  span : @syntax.Span,
) -> Double raise SourceError {
  ignore(self_)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Length.pt` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Length.mm` (typst-library/src/layout/length.rs).
fn impl_length_to_mm(
  self_ : Length,
  span : @syntax.Span,
) -> Double raise SourceError {
  ignore(self_)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Length.mm` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Length.cm` (typst-library/src/layout/length.rs).
fn impl_length_to_cm(
  self_ : Length,
  span : @syntax.Span,
) -> Double raise SourceError {
  ignore(self_)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Length.cm` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Length.inches` (typst-library/src/layout/length.rs).
fn impl_length_to_inches(
  self_ : Length,
  span : @syntax.Span,
) -> Double raise SourceError {
  ignore(self_)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Length.inches` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Length.to-absolute` (typst-library/src/layout/length.rs).
fn impl_length_to_absolute(
  self_ : Length,
  context : Context,
) -> Length raise HintedError {
  ignore(self_)
  ignore(context)
  bail("`Length.to-absolute` is not yet ported")
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_measure__width_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `measure.width` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_measure__height_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `measure.height` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `measure` (typst-library/src/layout/measure.rs).
fn impl_measure(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  width_ : Value,
  height_ : Value,
  content_ : Content,
) -> Dict raise SourceError {
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(width_)
  ignore(height_)
  ignore(content_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`measure` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `cbor` (typst-library/src/loading/cbor.rs).
fn impl_cbor(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`cbor` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `cbor.encode` (typst-library/src/loading/cbor.rs).
fn impl_cbor_encode(value_ : @syntax.Spanned[Value]) -> Value raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`cbor.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_csv__delimiter_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `csv.delimiter` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `RowType::Array`.
fn impl_csv__row_type_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `csv.row_type` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `csv` (typst-library/src/loading/csv.rs).
fn impl_csv(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
  delimiter_ : Value,
  row_type_ : Value,
) -> Arr raise SourceError {
  ignore(engine)
  ignore(source_)
  ignore(delimiter_)
  ignore(row_type_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`csv` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `json` (typst-library/src/loading/json.rs).
fn impl_json(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`json` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `json.encode` (typst-library/src/loading/json.rs).
fn impl_json_encode(
  value_ : @syntax.Spanned[Value],
  pretty_ : Bool,
) -> String raise SourceError {
  ignore(value_)
  ignore(pretty_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`json.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Some(Encoding::Utf8)`.
fn impl_read__encoding_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `read.encoding` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `read` (typst-library/src/loading/read.rs).
fn impl_read(
  engine : Engine,
  path_ : @syntax.Spanned[Value],
  encoding_ : Value,
) -> Value raise SourceError {
  ignore(engine)
  ignore(path_)
  ignore(encoding_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`read` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `toml` (typst-library/src/loading/toml.rs).
fn impl_toml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Dict raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`toml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `toml.encode` (typst-library/src/loading/toml.rs).
fn impl_toml_encode(
  value_ : @syntax.Spanned[Dict],
  pretty_ : Bool,
) -> String raise SourceError {
  ignore(value_)
  ignore(pretty_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`toml.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `xml` (typst-library/src/loading/xml.rs).
fn impl_xml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`xml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `yaml` (typst-library/src/loading/yaml.rs).
fn impl_yaml(
  engine : Engine,
  source_ : @syntax.Spanned[Value],
) -> Value raise SourceError {
  ignore(engine)
  ignore(source_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`yaml` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `yaml.encode` (typst-library/src/loading/yaml.rs).
fn impl_yaml_encode(
  value_ : @syntax.Spanned[Value],
) -> String raise SourceError {
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`yaml.encode` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `math.floor` (typst-library/src/math/lr.rs).
fn impl_math_floor(
  size_ : Rel[Length]?,
  body_ : Content,
) -> Content raise HintedError {
  ignore(size_)
  ignore(body_)
  bail("`math.floor` is not yet ported")
}

///|
/// TODO: port `math.ceil` (typst-library/src/math/lr.rs).
fn impl_math_ceil(
  size_ : Rel[Length]?,
  body_ : Content,
) -> Content raise HintedError {
  ignore(size_)
  ignore(body_)
  bail("`math.ceil` is not yet ported")
}

///|
/// TODO: port `math.round` (typst-library/src/math/lr.rs).
fn impl_math_round(
  size_ : Rel[Length]?,
  body_ : Content,
) -> Content raise HintedError {
  ignore(size_)
  ignore(body_)
  bail("`math.round` is not yet ported")
}

///|
/// TODO: port `math.abs` (typst-library/src/math/lr.rs).
fn impl_math_abs(
  size_ : Rel[Length]?,
  body_ : Content,
) -> Content raise HintedError {
  ignore(size_)
  ignore(body_)
  bail("`math.abs` is not yet ported")
}

///|
/// TODO: port `math.norm` (typst-library/src/math/lr.rs).
fn impl_math_norm(
  size_ : Rel[Length]?,
  body_ : Content,
) -> Content raise HintedError {
  ignore(size_)
  ignore(body_)
  bail("`math.norm` is not yet ported")
}

///|
/// TODO: port `math.sqrt` (typst-library/src/math/root.rs).
fn impl_math_sqrt(
  span : @syntax.Span,
  radicand_ : Content,
) -> Content raise HintedError {
  ignore(span)
  ignore(radicand_)
  bail("`math.sqrt` is not yet ported")
}

///|
/// TODO: port `math.bold` (typst-library/src/math/style.rs).
fn impl_math_bold(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.bold` is not yet ported")
}

///|
/// TODO: port `math.upright` (typst-library/src/math/style.rs).
fn impl_math_upright(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.upright` is not yet ported")
}

///|
/// TODO: port `math.italic` (typst-library/src/math/style.rs).
fn impl_math_italic(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.italic` is not yet ported")
}

///|
/// TODO: port `math.serif` (typst-library/src/math/style.rs).
fn impl_math_serif(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.serif` is not yet ported")
}

///|
/// TODO: port `math.sans` (typst-library/src/math/style.rs).
fn impl_math_sans(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.sans` is not yet ported")
}

///|
/// TODO: port `math.cal` (typst-library/src/math/style.rs).
fn impl_math_cal(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.cal` is not yet ported")
}

///|
/// TODO: port `math.scr` (typst-library/src/math/style.rs).
fn impl_math_scr(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.scr` is not yet ported")
}

///|
/// TODO: port `math.frak` (typst-library/src/math/style.rs).
fn impl_math_frak(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.frak` is not yet ported")
}

///|
/// TODO: port `math.mono` (typst-library/src/math/style.rs).
fn impl_math_mono(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.mono` is not yet ported")
}

///|
/// TODO: port `math.bb` (typst-library/src/math/style.rs).
fn impl_math_bb(body_ : Content) -> Content raise HintedError {
  ignore(body_)
  bail("`math.bb` is not yet ported")
}

///|
/// TODO: port `math.display` (typst-library/src/math/style.rs).
fn impl_math_display(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  ignore(body_)
  ignore(cramped_)
  bail("`math.display` is not yet ported")
}

///|
/// TODO: port `math.inline` (typst-library/src/math/style.rs).
fn impl_math_inline(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  ignore(body_)
  ignore(cramped_)
  bail("`math.inline` is not yet ported")
}

///|
/// TODO: port `math.script` (typst-library/src/math/style.rs).
fn impl_math_script(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  ignore(body_)
  ignore(cramped_)
  bail("`math.script` is not yet ported")
}

///|
/// TODO: port `math.sscript` (typst-library/src/math/style.rs).
fn impl_math_sscript(
  body_ : Content,
  cramped_ : Bool,
) -> Content raise HintedError {
  ignore(body_)
  ignore(cramped_)
  bail("`math.sscript` is not yet ported")
}

///|
/// TODO: port `numbering` (typst-library/src/model/numbering.rs).
fn impl_numbering(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  numbering_ : Value,
  numbers_ : Array[U64],
) -> Value raise SourceError {
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(numbering_)
  ignore(numbers_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`numbering` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Em::new(0.5).into()`.
fn impl_outline_entry_indented__gap_default() -> Length raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `outline_entry_indented.gap` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.indented` (typst-library/src/model/outline.rs).
fn impl_outline_entry_indented(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  prefix_ : Content?,
  inner_ : Content,
  gap_ : Length,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  ignore(prefix_)
  ignore(inner_)
  ignore(gap_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.indented` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.prefix` (typst-library/src/model/outline.rs).
fn impl_outline_entry_prefix(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content? raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.prefix` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.inner` (typst-library/src/model/outline.rs).
fn impl_outline_entry_inner(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.inner` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `OutlineEntry.body` (typst-library/src/model/outline.rs).
fn impl_outline_entry_body(self_ : Value) -> Content raise HintedError {
  ignore(self_)
  bail("`OutlineEntry.body` is not yet ported")
}

///|
/// TODO: port `OutlineEntry.page` (typst-library/src/model/outline.rs).
fn impl_outline_entry_page(
  self_ : Value,
  engine : Engine,
  context : Context,
  span : @syntax.Span,
) -> Content raise SourceError {
  ignore(self_)
  ignore(engine)
  ignore(context)
  ignore(span)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`OutlineEntry.page` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `lower` (typst-library/src/text/case.rs).
fn impl_lower(text_ : Value) -> Value raise HintedError {
  ignore(text_)
  bail("`lower` is not yet ported")
}

///|
/// TODO: port `upper` (typst-library/src/text/case.rs).
fn impl_upper(text_ : Value) -> Value raise HintedError {
  ignore(text_)
  bail("`upper` is not yet ported")
}

///|
/// TODO: port `lorem` (typst-library/src/text/lorem.rs).
fn impl_lorem(words_ : USize) -> String raise HintedError {
  ignore(words_)
  bail("`lorem` is not yet ported")
}

///|
/// TODO: port `Color.luma` (typst-library/src/visualize/color.rs).
fn impl_color_luma(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.luma` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.oklab` (typst-library/src/visualize/color.rs).
fn impl_color_oklab(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.oklab` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.oklch` (typst-library/src/visualize/color.rs).
fn impl_color_oklch(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.oklch` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.linear-rgb` (typst-library/src/visualize/color.rs).
fn impl_color_linear_rgb(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.linear-rgb` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.rgb` (typst-library/src/visualize/color.rs).
fn impl_color_rgb(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.rgb` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.cmyk` (typst-library/src/visualize/color.rs).
fn impl_color_cmyk(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.cmyk` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.hsl` (typst-library/src/visualize/color.rs).
fn impl_color_hsl(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.hsl` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.hsv` (typst-library/src/visualize/color.rs).
fn impl_color_hsv(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.hsv` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.components` (typst-library/src/visualize/color.rs).
fn impl_color_components(self_ : Value, alpha_ : Bool) -> Arr raise HintedError {
  ignore(self_)
  ignore(alpha_)
  bail("`Color.components` is not yet ported")
}

///|
/// TODO: port `Color.space` (typst-library/src/visualize/color.rs).
fn impl_color_space(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Color.space` is not yet ported")
}

///|
/// TODO: port `Color.to-hex` (typst-library/src/visualize/color.rs).
fn impl_color_to_hex(self_ : Value) -> String raise HintedError {
  ignore(self_)
  bail("`Color.to-hex` is not yet ported")
}

///|
/// TODO: port `Color.lighten` (typst-library/src/visualize/color.rs).
fn impl_color_lighten(
  self_ : Value,
  factor_ : Ratio,
) -> Value raise HintedError {
  ignore(self_)
  ignore(factor_)
  bail("`Color.lighten` is not yet ported")
}

///|
/// TODO: port `Color.darken` (typst-library/src/visualize/color.rs).
fn impl_color_darken(self_ : Value, factor_ : Ratio) -> Value raise HintedError {
  ignore(self_)
  ignore(factor_)
  bail("`Color.darken` is not yet ported")
}

///|
/// TODO: port `Color.saturate` (typst-library/src/visualize/color.rs).
fn impl_color_saturate(
  self_ : Value,
  span : @syntax.Span,
  factor_ : Ratio,
) -> Value raise SourceError {
  ignore(self_)
  ignore(span)
  ignore(factor_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.saturate` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.desaturate` (typst-library/src/visualize/color.rs).
fn impl_color_desaturate(
  self_ : Value,
  span : @syntax.Span,
  factor_ : Ratio,
) -> Value raise SourceError {
  ignore(self_)
  ignore(span)
  ignore(factor_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.desaturate` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_color_negate__space_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `color_negate.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.negate` (typst-library/src/visualize/color.rs).
fn impl_color_negate(self_ : Value, space_ : Value) -> Value raise HintedError {
  ignore(self_)
  ignore(space_)
  bail("`Color.negate` is not yet ported")
}

///|
/// TODO: port default `ProcessColorSpace::Oklch`.
fn impl_color_rotate__space_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `color_rotate.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.rotate` (typst-library/src/visualize/color.rs).
fn impl_color_rotate(
  self_ : Value,
  span : @syntax.Span,
  angle_ : Angle,
  space_ : Value,
) -> Value raise SourceError {
  ignore(self_)
  ignore(span)
  ignore(angle_)
  ignore(space_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Color.rotate` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_color_mix__space_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `color_mix.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Color.mix` (typst-library/src/visualize/color.rs).
fn impl_color_mix(
  colors_ : Array[Value],
  space_ : Value,
) -> Value raise HintedError {
  ignore(colors_)
  ignore(space_)
  bail("`Color.mix` is not yet ported")
}

///|
/// TODO: port `Color.transparentize` (typst-library/src/visualize/color.rs).
fn impl_color_transparentize(
  self_ : Value,
  scale_ : Ratio,
) -> Value raise HintedError {
  ignore(self_)
  ignore(scale_)
  bail("`Color.transparentize` is not yet ported")
}

///|
/// TODO: port `Color.opacify` (typst-library/src/visualize/color.rs).
fn impl_color_opacify(self_ : Value, scale_ : Ratio) -> Value raise HintedError {
  ignore(self_)
  ignore(scale_)
  bail("`Color.opacify` is not yet ported")
}

///|
/// TODO: port `SpotColorant.construct` (typst-library/src/visualize/color.rs).
fn impl_spot_colorant_construct(
  name_ : Value,
  fallback_ : Value,
) -> Value raise SourceError {
  ignore(name_)
  ignore(fallback_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`SpotColorant.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `SpotColorant.tint` (typst-library/src/visualize/color.rs).
fn impl_spot_colorant_tint(
  self_ : Value,
  value_ : @syntax.Spanned[Ratio],
) -> Value raise SourceError {
  ignore(self_)
  ignore(value_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`SpotColorant.tint` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Smart::Auto)`.
fn impl_gradient_linear__space_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_linear.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_gradient_linear__relative_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_linear.relative` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Dir::LTR`.
fn impl_gradient_linear__dir_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_linear.dir` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.linear` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_linear(
  args : Args,
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[Value]],
  space_ : @syntax.Spanned[Value],
  relative_ : Value,
) -> Value raise SourceError {
  ignore(args)
  ignore(span)
  ignore(stops_)
  ignore(space_)
  ignore(relative_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.linear` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Smart::Auto)`.
fn impl_gradient_radial__space_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_gradient_radial__relative_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.relative` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Axes::splat(Ratio::new(0.5))`.
fn impl_gradient_radial__center_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.center` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Ratio::new(0.5))`.
fn impl_gradient_radial__radius_default() -> @syntax.Spanned[Ratio] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.radius` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_gradient_radial__focal_center_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.focal_center` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Ratio::new(0.0))`.
fn impl_gradient_radial__focal_radius_default() -> @syntax.Spanned[Ratio] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_radial.focal_radius` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.radial` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_radial(
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[Value]],
  space_ : @syntax.Spanned[Value],
  relative_ : Value,
  center_ : Value,
  radius_ : @syntax.Spanned[Ratio],
  focal_center_ : Value,
  focal_radius_ : @syntax.Spanned[Ratio],
) -> Value raise SourceError {
  ignore(span)
  ignore(stops_)
  ignore(space_)
  ignore(relative_)
  ignore(center_)
  ignore(radius_)
  ignore(focal_center_)
  ignore(focal_radius_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.radial` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Angle::zero()`.
fn impl_gradient_conic__angle_default() -> Angle raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_conic.angle` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Smart::Auto)`.
fn impl_gradient_conic__space_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_conic.space` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_gradient_conic__relative_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_conic.relative` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Axes::splat(Ratio::new(0.5))`.
fn impl_gradient_conic__center_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_conic.center` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.conic` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_conic(
  span : @syntax.Span,
  stops_ : Array[@syntax.Spanned[Value]],
  angle_ : Angle,
  space_ : @syntax.Spanned[Value],
  relative_ : Value,
  center_ : Value,
) -> Value raise SourceError {
  ignore(span)
  ignore(stops_)
  ignore(angle_)
  ignore(space_)
  ignore(relative_)
  ignore(center_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.conic` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Ratio::zero())`.
fn impl_gradient_sharp__smoothness_default() -> @syntax.Spanned[Ratio] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `gradient_sharp.smoothness` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.sharp` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_sharp(
  self_ : Value,
  steps_ : @syntax.Spanned[USize],
  smoothness_ : @syntax.Spanned[Ratio],
) -> Value raise SourceError {
  ignore(self_)
  ignore(steps_)
  ignore(smoothness_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.sharp` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.repeat` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_repeat(
  self_ : Value,
  repetitions_ : @syntax.Spanned[USize],
  mirror_ : Bool,
) -> Value raise SourceError {
  ignore(self_)
  ignore(repetitions_)
  ignore(mirror_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Gradient.repeat` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Gradient.kind` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_kind(self_ : Value) -> Func raise HintedError {
  ignore(self_)
  bail("`Gradient.kind` is not yet ported")
}

///|
/// TODO: port `Gradient.stops` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_stops(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Gradient.stops` is not yet ported")
}

///|
/// TODO: port `Gradient.space` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_space(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Gradient.space` is not yet ported")
}

///|
/// TODO: port `Gradient.relative` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_relative(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Gradient.relative` is not yet ported")
}

///|
/// TODO: port `Gradient.angle` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_angle(self_ : Value) -> Angle? raise HintedError {
  ignore(self_)
  bail("`Gradient.angle` is not yet ported")
}

///|
/// TODO: port `Gradient.center` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_center(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Gradient.center` is not yet ported")
}

///|
/// TODO: port `Gradient.radius` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_radius(self_ : Value) -> Ratio? raise HintedError {
  ignore(self_)
  bail("`Gradient.radius` is not yet ported")
}

///|
/// TODO: port `Gradient.focal-center` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_focal_center(self_ : Value) -> Value raise HintedError {
  ignore(self_)
  bail("`Gradient.focal-center` is not yet ported")
}

///|
/// TODO: port `Gradient.focal-radius` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_focal_radius(self_ : Value) -> Ratio? raise HintedError {
  ignore(self_)
  bail("`Gradient.focal-radius` is not yet ported")
}

///|
/// TODO: port `Gradient.sample` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_sample(self_ : Value, t_ : Value) -> Value raise HintedError {
  ignore(self_)
  ignore(t_)
  bail("`Gradient.sample` is not yet ported")
}

///|
/// TODO: port `Gradient.samples` (typst-library/src/visualize/gradient.rs).
fn impl_gradient_samples(
  self_ : Value,
  ts_ : Array[Value],
) -> Arr raise HintedError {
  ignore(self_)
  ignore(ts_)
  bail("`Gradient.samples` is not yet ported")
}

///|
/// TODO: port default `Em::one().into()`.
fn impl_polygon_elem_regular__size_default() -> Length raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `polygon_elem_regular.size` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `PolygonElem.regular` (typst-library/src/visualize/polygon.rs).
fn impl_polygon_elem_regular(
  span : @syntax.Span,
  fill_ : Value?,
  stroke_ : Value?,
  size_ : Length,
  vertices_ : U64,
) -> Content raise HintedError {
  ignore(span)
  ignore(fill_)
  ignore(stroke_)
  ignore(size_)
  ignore(vertices_)
  bail("`PolygonElem.regular` is not yet ported")
}

///|
/// TODO: port `Stroke.construct` (typst-library/src/visualize/stroke.rs).
fn impl_stroke_construct(args : Args) -> Value raise SourceError {
  ignore(args)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Stroke.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Smart::Auto)`.
fn impl_tiling_construct__size_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.size` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Axes::splat(Length::zero()))`.
fn impl_tiling_construct__spacing_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.spacing` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::new(Axes::splat(Rel::zero()), Span::detached())`.
fn impl_tiling_construct__offset_default() -> @syntax.Spanned[Value] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.offset` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Angle::zero())`.
fn impl_tiling_construct__angle_default() -> @syntax.Spanned[Angle] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.angle` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Smart::Auto`.
fn impl_tiling_construct__relative_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.relative` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `Tiling.construct` (typst-library/src/visualize/tiling.rs).
fn impl_tiling_construct(
  engine : Engine,
  span : @syntax.Span,
  size_ : @syntax.Spanned[Value],
  spacing_ : @syntax.Spanned[Value],
  offset_ : @syntax.Spanned[Value],
  angle_ : @syntax.Spanned[Angle],
  relative_ : Value,
  body_ : Content,
) -> Value raise SourceError {
  ignore(engine)
  ignore(span)
  ignore(size_)
  ignore(spacing_)
  ignore(offset_)
  ignore(angle_)
  ignore(relative_)
  ignore(body_)
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "`Tiling.construct` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `PdfFormat.table-summary` (typst-pdf/src/format.rs).
fn impl_pdf_format_table_summary(
  summary_ : String?,
  table_ : Value,
) -> Content raise HintedError {
  ignore(summary_)
  ignore(table_)
  bail("`PdfFormat.table-summary` is not yet ported")
}

///|
/// TODO: port default `NonZeroU32::ONE`.
fn impl_pdf_format_header_cell__level_default() -> NonZeroU32 raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `pdf_format_header_cell.level` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Default::default()`.
fn impl_pdf_format_header_cell__scope_default() -> Value raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `pdf_format_header_cell.scope` is not yet ported",
    ),
  ])
}

///|
/// TODO: port `PdfFormat.header-cell` (typst-pdf/src/format.rs).
fn impl_pdf_format_header_cell(
  level_ : NonZeroU32,
  scope_ : Value,
  cell_ : Value,
) -> Content raise HintedError {
  ignore(level_)
  ignore(scope_)
  ignore(cell_)
  bail("`PdfFormat.header-cell` is not yet ported")
}

///|
/// TODO: port `PdfFormat.data-cell` (typst-pdf/src/format.rs).
fn impl_pdf_format_data_cell(cell_ : Value) -> Content raise HintedError {
  ignore(cell_)
  bail("`PdfFormat.data-cell` is not yet ported")
}

///|
/// TODO: port constant `f64::INF`.
fn impl_f64_const_inf() -> Value {
  None
}

///|
/// TODO: port constant `f64::NAN`.
fn impl_f64_const_nan() -> Value {
  None
}

///|
/// TODO: port constant `i64::MAX`.
fn impl_i64_const_max() -> Value {
  None
}

///|
/// TODO: port constant `i64::MIN`.
fn impl_i64_const_min() -> Value {
  None
}

///|
/// TODO: port constant `Alignment::START`.
fn impl_alignment_const_start() -> Value {
  None
}

///|
/// TODO: port constant `Alignment::END`.
fn impl_alignment_const_end() -> Value {
  None
}

///|
/// TODO: port constant `Alignment::LEFT`.
fn impl_alignment_const_left() -> Value {
  None
}

///|
/// TODO: port constant `Alignment::CENTER`.
fn impl_alignment_const_center() -> Value {
  None
}

///|
/// TODO: port constant `Alignment::RIGHT`.
fn impl_alignment_const_right() -> Value {
  None
}

///|
/// TODO: port constant `Alignment::TOP`.
fn impl_alignment_const_top() -> Value {
  None
}

///|
/// TODO: port constant `Alignment::HORIZON`.
fn impl_alignment_const_horizon() -> Value {
  None
}

///|
/// TODO: port constant `Alignment::BOTTOM`.
fn impl_alignment_const_bottom() -> Value {
  None
}

///|
/// TODO: port constant `Dir::LTR`.
fn impl_dir_const_ltr() -> Value {
  None
}

///|
/// TODO: port constant `Dir::RTL`.
fn impl_dir_const_rtl() -> Value {
  None
}

///|
/// TODO: port constant `Dir::TTB`.
fn impl_dir_const_ttb() -> Value {
  None
}

///|
/// TODO: port constant `Dir::BTT`.
fn impl_dir_const_btt() -> Value {
  None
}

///|
/// TODO: port constant `Color::BLACK`.
fn impl_color_const_black() -> Value {
  None
}

///|
/// TODO: port constant `Color::GRAY`.
fn impl_color_const_gray() -> Value {
  None
}

///|
/// TODO: port constant `Color::WHITE`.
fn impl_color_const_white() -> Value {
  None
}

///|
/// TODO: port constant `Color::SILVER`.
fn impl_color_const_silver() -> Value {
  None
}

///|
/// TODO: port constant `Color::NAVY`.
fn impl_color_const_navy() -> Value {
  None
}

///|
/// TODO: port constant `Color::BLUE`.
fn impl_color_const_blue() -> Value {
  None
}

///|
/// TODO: port constant `Color::AQUA`.
fn impl_color_const_aqua() -> Value {
  None
}

///|
/// TODO: port constant `Color::TEAL`.
fn impl_color_const_teal() -> Value {
  None
}

///|
/// TODO: port constant `Color::EASTERN`.
fn impl_color_const_eastern() -> Value {
  None
}

///|
/// TODO: port constant `Color::PURPLE`.
fn impl_color_const_purple() -> Value {
  None
}

///|
/// TODO: port constant `Color::FUCHSIA`.
fn impl_color_const_fuchsia() -> Value {
  None
}

///|
/// TODO: port constant `Color::MAROON`.
fn impl_color_const_maroon() -> Value {
  None
}

///|
/// TODO: port constant `Color::RED`.
fn impl_color_const_red() -> Value {
  None
}

///|
/// TODO: port constant `Color::ORANGE`.
fn impl_color_const_orange() -> Value {
  None
}

///|
/// TODO: port constant `Color::YELLOW`.
fn impl_color_const_yellow() -> Value {
  None
}

///|
/// TODO: port constant `Color::OLIVE`.
fn impl_color_const_olive() -> Value {
  None
}

///|
/// TODO: port constant `Color::GREEN`.
fn impl_color_const_green() -> Value {
  None
}

///|
/// TODO: port constant `Color::LIME`.
fn impl_color_const_lime() -> Value {
  None
}

///|
/// TODO: port constant `Color::MAP`.
fn impl_color_const_map() -> Value {
  None
}

///|
/// TODO: port `#[defs]` of `HtmlFormat` (typst-html/src/format.rs).
fn defs_html_format(scope : Scope) -> Unit {
  ignore(scope)
}
