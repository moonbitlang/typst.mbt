// `toml_edit::parser::state::ParseState`.

///|
priv struct ParseState {
  mut root : Table
  mut current_table : Table
  mut current_is_array : Bool
  mut current_table_path : Array[String]
}

///|
fn ParseState::new() -> ParseState {
  {
    root: Table::new(),
    current_table: Table::new(),
    current_is_array: false,
    current_table_path: [],
  }
}

///|
/// `ParseState::into_document`: returns the root table.
fn ParseState::into_document(self : ParseState) -> Table raise TomlError {
  match self.finalize_table() {
    Ok(_) => self.root
    Err(message) => raise TomlError(message~, span=None)
  }
}

///|
/// `ParseState::on_keyval`
fn ParseState::on_keyval(
  self : ParseState,
  path : Array[String],
  key : String,
  value : TValue,
) -> Result[Unit, String] {
  let table = match descend_path(self.current_table, path, true) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  // "Likewise, using dotted keys to redefine tables already defined in
  // [table] form is not allowed"
  let mixed_table_types = table.dotted == path.is_empty()
  if mixed_table_types {
    return Err(duplicate_key_error(key, None))
  }
  if table.items.contains(key) {
    // "Since tables cannot be defined more than once, redefining such tables
    // using a [table] header is not allowed"
    return Err(duplicate_key_error(key, Some(self.current_table_path.copy())))
  }
  table.items[key] = IValue(value)
  Ok(())
}

///|
/// `ParseState::start_array_table`
fn ParseState::start_array_table(
  self : ParseState,
  path : Array[String],
) -> Result[Unit, String] {
  // Look up the table on start to ensure the duplicate_key error points to
  // the right line
  let n = path.length()
  let parent_table = match
    descend_path(self.root, path[:n - 1].to_owned(), false) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let key = path[n - 1]
  let entry = match parent_table.items.get(key) {
    Some(e) => e
    None => {
      let e = IArrayOfTables([])
      parent_table.items[key] = e
      e
    }
  }
  guard entry is IArrayOfTables(_) else {
    return Err(duplicate_key_at(path, n - 1))
  }
  self.current_table.implicit = false
  self.current_table.dotted = false
  self.current_is_array = true
  self.current_table_path = path
  Ok(())
}

///|
/// `ParseState::start_table`
fn ParseState::start_table(
  self : ParseState,
  path : Array[String],
) -> Result[Unit, String] {
  // 1. Look up the table on start to ensure the duplicate_key error points to
  //    the right line
  // 2. Ensure any child tables from an implicit table are preserved
  let n = path.length()
  let parent_table = match
    descend_path(self.root, path[:n - 1].to_owned(), false) {
    Ok(t) => t
    Err(e) => return Err(e)
  }
  let key = path[n - 1]
  if parent_table.items.get(key) is Some(entry) {
    parent_table.items.remove(key)
    match entry {
      ITable(t) if t.implicit && !t.dotted => self.current_table = t
      // Since tables cannot be defined more than once, redefining such tables
      // using a [table] header is not allowed. Likewise, using dotted keys to
      // redefine tables already defined in [table] form is not allowed.
      _ => return Err(duplicate_key_at(path, n - 1))
    }
  }
  self.current_table.implicit = false
  self.current_table.dotted = false
  self.current_is_array = false
  self.current_table_path = path
  Ok(())
}

///|
/// `ParseState::finalize_table`
fn ParseState::finalize_table(self : ParseState) -> Result[Unit, String] {
  let table = self.current_table
  self.current_table = Table::new()
  let path = self.current_table_path
  self.current_table_path = []
  let n = path.length()
  if n == 0 {
    self.root = table
  } else if self.current_is_array {
    let parent_table = match
      descend_path(self.root, path[:n - 1].to_owned(), false) {
      Ok(t) => t
      Err(e) => return Err(e)
    }
    let key = path[n - 1]
    let entry = match parent_table.items.get(key) {
      Some(e) => e
      None => {
        let e = IArrayOfTables([])
        parent_table.items[key] = e
        e
      }
    }
    guard entry is IArrayOfTables(array) else {
      return Err(duplicate_key_at(path, n - 1))
    }
    array.push(table)
  } else {
    let parent_table = match
      descend_path(self.root, path[:n - 1].to_owned(), false) {
      Ok(t) => t
      Err(e) => return Err(e)
    }
    let key = path[n - 1]
    match parent_table.items.get(key) {
      // if [a.b.c] header preceded [a.b]
      Some(ITable(t)) if t.implicit => parent_table.items[key] = ITable(table)
      Some(_) => return Err(duplicate_key_at(path, n - 1))
      None => parent_table.items[key] = ITable(table)
    }
  }
  Ok(())
}

///|
/// `ParseState::descend_path`
fn descend_path(
  table : Table,
  path : Array[String],
  dotted : Bool,
) -> Result[Table, String] {
  let mut table = table
  for i, key in path {
    let entry = match table.items.get(key) {
      Some(e) => e
      None => {
        let new_table = Table::new()
        new_table.implicit = true
        new_table.dotted = dotted
        let e = ITable(new_table)
        table.items[key] = e
        e
      }
    }
    match entry {
      IValue(v) => return Err(extend_wrong_type(path, i, v.type_name()))
      IArrayOfTables(array) => table = array[array.length() - 1]
      ITable(child) => {
        // Since tables cannot be defined more than once, redefining such
        // tables using a [table] header is not allowed. Likewise, using
        // dotted keys to redefine tables already defined in [table] form is
        // not allowed.
        if dotted && !child.implicit {
          return Err(duplicate_key_error(key, None))
        }
        table = child
      }
    }
  }
  Ok(table)
}

///|
/// `ParseState::on_std_header`
fn ParseState::on_std_header(
  self : ParseState,
  path : Array[String],
) -> Result[Unit, String] {
  match self.finalize_table() {
    Ok(_) => self.start_table(path)
    Err(e) => Err(e)
  }
}

///|
/// `ParseState::on_array_header`
fn ParseState::on_array_header(
  self : ParseState,
  path : Array[String],
) -> Result[Unit, String] {
  match self.finalize_table() {
    Ok(_) => self.start_array_table(path)
    Err(e) => Err(e)
  }
}
