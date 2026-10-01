// Generated stubs for native functions that are not ported yet.

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
/// TODO: port `Label.construct` (typst-library/src/foundations/label.rs).
fn impl_label_construct(name_ : String) -> Label raise HintedError {
  ignore(name_)
  bail("`Label.construct` is not yet ported")
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
fn impl_str_construct__base_default() -> @syntax.Spanned[Base] raise SourceError {
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
  base_ : @syntax.Spanned[Base],
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
/// TODO: port `layout` (typst-library/src/layout/layout.rs).
fn impl_layout(span : @syntax.Span, func_ : Func) -> Content raise HintedError {
  ignore(span)
  ignore(func_)
  bail("`layout` is not yet ported")
}

///|
/// TODO: port `measure` (typst-library/src/layout/measure.rs).
fn impl_measure(
  engine : Engine,
  context : Context,
  span : @syntax.Span,
  width_ : Smart[Length],
  height_ : Smart[Length],
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
  path_ : @syntax.Spanned[PathOrStr],
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
/// TODO: port `#[defs]` of `HtmlFormat` (typst-html/src/format.rs).
fn defs_html_format(scope : Scope) -> Unit {
  ignore(scope)
}
