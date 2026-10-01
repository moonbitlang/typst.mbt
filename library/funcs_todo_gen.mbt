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
fn impl_gradient_linear__dir_default() -> Dir raise SourceError {
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
fn impl_gradient_radial__center_default() -> Axes[Ratio] raise SourceError {
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
  center_ : Axes[Ratio],
  radius_ : @syntax.Spanned[Ratio],
  focal_center_ : Smart[Axes[Ratio]],
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
fn impl_gradient_conic__center_default() -> Axes[Ratio] raise SourceError {
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
  center_ : Axes[Ratio],
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
fn impl_gradient_center(self_ : Value) -> Axes[Ratio]? raise HintedError {
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
fn impl_gradient_focal_center(self_ : Value) -> Axes[Ratio]? raise HintedError {
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
fn impl_tiling_construct__size_default() -> @syntax.Spanned[Smart[Axes[Length]]] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.size` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::detached(Axes::splat(Length::zero()))`.
fn impl_tiling_construct__spacing_default() -> @syntax.Spanned[Axes[Length]] raise SourceError {
  raise SourceError([
    SourceDiagnostic::error_at(
      @syntax.Span::detached(),
      "default of `tiling_construct.spacing` is not yet ported",
    ),
  ])
}

///|
/// TODO: port default `Spanned::new(Axes::splat(Rel::zero()), Span::detached())`.
fn impl_tiling_construct__offset_default() -> @syntax.Spanned[Axes[Rel[Length]]] raise SourceError {
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
  size_ : @syntax.Spanned[Smart[Axes[Length]]],
  spacing_ : @syntax.Spanned[Axes[Length]],
  offset_ : @syntax.Spanned[Axes[Rel[Length]]],
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
