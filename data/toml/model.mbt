// The subset of `toml_edit`'s document model that parsing and deserializing
// need: decor and reprs are irrelevant for `toml::from_str` and are dropped;
// keys are represented by their (unescaped) string value (`Key::get`).

///|
/// `toml_edit::Value`.
priv enum TValue {
  VString(String)
  VInteger(Int64)
  VFloat(Double)
  VBoolean(Bool)
  VDatetime(Datetime)
  VArray(Array[TValue])
  VInlineTable(InlineTable)
}

///|
/// `Value::type_name`.
fn TValue::type_name(self : TValue) -> String {
  match self {
    VString(_) => "string"
    VInteger(_) => "integer"
    VFloat(_) => "float"
    VBoolean(_) => "boolean"
    VDatetime(_) => "datetime"
    VArray(_) => "array"
    VInlineTable(_) => "inline table"
  }
}

///|
/// `toml_edit::InlineTable` (an insertion-ordered map).
priv struct InlineTable {
  items : Map[String, TValue]
  mut implicit : Bool
  mut dotted : Bool
}

///|
fn InlineTable::new() -> InlineTable {
  { items: Map([]), implicit: false, dotted: false, }
}

///|
/// `toml_edit::Item` (without `Item::None`, which parsing never stores).
priv enum Item {
  IValue(TValue)
  ITable(Table)
  IArrayOfTables(Array[Table])
}

///|
/// `toml_edit::Table` (an insertion-ordered map; `shift_remove` keeps the
/// order of the remaining entries, as MoonBit's `Map::remove` does).
priv struct Table {
  items : Map[String, Item]
  mut implicit : Bool
  mut dotted : Bool
}

///|
fn Table::new() -> Table {
  { items: Map([]), implicit: false, dotted: false, }
}
