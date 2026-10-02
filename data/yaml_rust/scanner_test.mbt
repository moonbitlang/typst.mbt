// Generated from yaml-rust 0.4.5 src/scanner.rs (mod test) by a conversion script; do not edit.

///|
test "test_empty" {
  let s = ""
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_scalar" {
  let s = "a scalar"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is Scalar(Plain, _))
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_explicit_scalar" {
  let s = "---\n'a scalar'\n...\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is DocumentStart)
  next(p, t => t is Scalar(SingleQuoted, _))
  next(p, t => t is DocumentEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_multiple_documents" {
  let s = "\n'a scalar'\n---\n'a scalar'\n---\n'a scalar'\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is Scalar(SingleQuoted, _))
  next(p, t => t is DocumentStart)
  next(p, t => t is Scalar(SingleQuoted, _))
  next(p, t => t is DocumentStart)
  next(p, t => t is Scalar(SingleQuoted, _))
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_a_flow_sequence" {
  let s = "[item 1, item 2, item 3]"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is FlowSequenceStart)
  next_scalar(p, Plain, "item 1")
  next(p, t => t is FlowEntry)
  next(p, t => t is Scalar(Plain, _))
  next(p, t => t is FlowEntry)
  next(p, t => t is Scalar(Plain, _))
  next(p, t => t is FlowSequenceEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_a_flow_mapping" {
  let s = "\n{\n    a simple key: a value, # Note that the KEY token is produced.\n    ? a complex key: another value,\n}\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is FlowMappingStart)
  next(p, t => t is Key)
  next(p, t => t is Scalar(Plain, _))
  next(p, t => t is Value)
  next(p, t => t is Scalar(Plain, _))
  next(p, t => t is FlowEntry)
  next(p, t => t is Key)
  next_scalar(p, Plain, "a complex key")
  next(p, t => t is Value)
  next(p, t => t is Scalar(Plain, _))
  next(p, t => t is FlowEntry)
  next(p, t => t is FlowMappingEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_block_sequences" {
  let s = "\n- item 1\n- item 2\n-\n  - item 3.1\n  - item 3.2\n-\n  key 1: value 1\n  key 2: value 2\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is BlockSequenceStart)
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 1")
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 2")
  next(p, t => t is BlockEntry)
  next(p, t => t is BlockSequenceStart)
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 3.1")
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 3.2")
  next(p, t => t is BlockEnd)
  next(p, t => t is BlockEntry)
  next(p, t => t is BlockMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "key 1")
  next(p, t => t is Value)
  next_scalar(p, Plain, "value 1")
  next(p, t => t is Key)
  next_scalar(p, Plain, "key 2")
  next(p, t => t is Value)
  next_scalar(p, Plain, "value 2")
  next(p, t => t is BlockEnd)
  next(p, t => t is BlockEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_block_mappings" {
  let s = "\na simple key: a value   # The KEY token is produced here.\n? a complex key\n: another value\na mapping:\n  key 1: value 1\n  key 2: value 2\na sequence:\n  - item 1\n  - item 2\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is BlockMappingStart)
  next(p, t => t is Key)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Value)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Key)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Value)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Key)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Value)
  // libyaml comment seems to be wrong
  next(p, t => t is BlockMappingStart)
  next(p, t => t is Key)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Value)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Key)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Value)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is BlockEnd)
  next(p, t => t is Key)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is Value)
  next(p, t => t is BlockSequenceStart)
  next(p, t => t is BlockEntry)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is BlockEntry)
  next(p, t => t is Scalar(_, _))
  next(p, t => t is BlockEnd)
  next(p, t => t is BlockEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_no_block_sequence_start" {
  let s = "\nkey:\n- item 1\n- item 2\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is BlockMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "key")
  next(p, t => t is Value)
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 1")
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 2")
  next(p, t => t is BlockEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_collections_in_sequence" {
  let s = "\n- - item 1\n  - item 2\n- key 1: value 1\n  key 2: value 2\n- ? complex key\n  : complex value\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is BlockSequenceStart)
  next(p, t => t is BlockEntry)
  next(p, t => t is BlockSequenceStart)
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 1")
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 2")
  next(p, t => t is BlockEnd)
  next(p, t => t is BlockEntry)
  next(p, t => t is BlockMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "key 1")
  next(p, t => t is Value)
  next_scalar(p, Plain, "value 1")
  next(p, t => t is Key)
  next_scalar(p, Plain, "key 2")
  next(p, t => t is Value)
  next_scalar(p, Plain, "value 2")
  next(p, t => t is BlockEnd)
  next(p, t => t is BlockEntry)
  next(p, t => t is BlockMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "complex key")
  next(p, t => t is Value)
  next_scalar(p, Plain, "complex value")
  next(p, t => t is BlockEnd)
  next(p, t => t is BlockEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_collections_in_mapping" {
  let s = "\n? a sequence\n: - item 1\n  - item 2\n? a mapping\n: key 1: value 1\n  key 2: value 2\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is BlockMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "a sequence")
  next(p, t => t is Value)
  next(p, t => t is BlockSequenceStart)
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 1")
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "item 2")
  next(p, t => t is BlockEnd)
  next(p, t => t is Key)
  next_scalar(p, Plain, "a mapping")
  next(p, t => t is Value)
  next(p, t => t is BlockMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "key 1")
  next(p, t => t is Value)
  next_scalar(p, Plain, "value 1")
  next(p, t => t is Key)
  next_scalar(p, Plain, "key 2")
  next(p, t => t is Value)
  next_scalar(p, Plain, "value 2")
  next(p, t => t is BlockEnd)
  next(p, t => t is BlockEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_spec_ex7_3" {
  let s = "\n{\n    ? foo :,\n    : bar,\n}\n"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is FlowMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "foo")
  next(p, t => t is Value)
  next(p, t => t is FlowEntry)
  next(p, t => t is Value)
  next_scalar(p, Plain, "bar")
  next(p, t => t is FlowEntry)
  next(p, t => t is FlowMappingEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_plain_scalar_starting_with_indicators_in_flow" {
  // "Plain scalars must not begin with most indicators, as this would cause ambiguity with
  // other YAML constructs. However, the “:”, “?” and “-” indicators may be used as the first
  // character if followed by a non-space “safe” character, as this causes no ambiguity."
  let s = "{a: :b}"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is FlowMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "a")
  next(p, t => t is Value)
  next_scalar(p, Plain, ":b")
  next(p, t => t is FlowMappingEnd)
  next(p, t => t is StreamEnd)
  end(p)
  let s = "{a: ?b}"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is FlowMappingStart)
  next(p, t => t is Key)
  next_scalar(p, Plain, "a")
  next(p, t => t is Value)
  next_scalar(p, Plain, "?b")
  next(p, t => t is FlowMappingEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_plain_scalar_starting_with_indicators_in_block" {
  let s = ":a"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next_scalar(p, Plain, ":a")
  next(p, t => t is StreamEnd)
  end(p)
  let s = "?a"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next_scalar(p, Plain, "?a")
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_plain_scalar_containing_indicators_in_block" {
  let s = "a:,b"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next_scalar(p, Plain, "a:,b")
  next(p, t => t is StreamEnd)
  end(p)
  let s = ":,b"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next_scalar(p, Plain, ":,b")
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_scanner_cr" {
  let s = "---\r\n- tok1\r\n- tok2"
  let p = @yaml_rust.Scanner::new(s)
  next(p, t => t is StreamStart(_))
  next(p, t => t is DocumentStart)
  next(p, t => t is BlockSequenceStart)
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "tok1")
  next(p, t => t is BlockEntry)
  next_scalar(p, Plain, "tok2")
  next(p, t => t is BlockEnd)
  next(p, t => t is StreamEnd)
  end(p)
}

///|
test "test_uri" {
  // TODO
}

///|
test "test_uri_escapes" {
  // TODO
}
