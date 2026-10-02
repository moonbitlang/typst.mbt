// Generated from yaml-rust 0.4.5 tests/specexamples.rs.inc + tests/spec_test.rs.inc by a conversion script; do not edit.

///|
let ex2_1 : String = "- Mark McGwire\n- Sammy Sosa\n- Ken Griffey"

///|
let ex2_2 : String = "hr:  65    # Home runs\navg: 0.278 # Batting average\nrbi: 147   # Runs Batted In"

///|
let ex2_3 : String = "american:\n- Boston Red Sox\n- Detroit Tigers\n- New York Yankees\nnational:\n- New York Mets\n- Chicago Cubs\n- Atlanta Braves"

///|
let ex2_4 : String = "-\n  name: Mark McGwire\n  hr:   65\n  avg:  0.278\n-\n  name: Sammy Sosa\n  hr:   63\n  avg:  0.288"

///|
let ex2_5 : String = "- [name        , hr, avg  ]\n- [Mark McGwire, 65, 0.278]\n- [Sammy Sosa  , 63, 0.288]"

///|
let ex2_6 : String = "Mark McGwire: {hr: 65, avg: 0.278}\nSammy Sosa: {\n    hr: 63,\n    avg: 0.288\n  }"

///|
let ex2_7 : String = "# Ranking of 1998 home runs\n---\n- Mark McGwire\n- Sammy Sosa\n- Ken Griffey\n\n# Team ranking\n---\n- Chicago Cubs\n- St Louis Cardinals"

///|
let ex2_8 : String = "---\ntime: 20:03:20\nplayer: Sammy Sosa\naction: strike (miss)\n...\n---\ntime: 20:03:47\nplayer: Sammy Sosa\naction: grand slam\n..."

///|
let ex2_9 : String = "---\nhr: # 1998 hr ranking\n  - Mark McGwire\n  - Sammy Sosa\nrbi:\n  # 1998 rbi ranking\n  - Sammy Sosa\n  - Ken Griffey"

///|
let ex2_10 : String = "---\nhr:\n  - Mark McGwire\n  # Following node labeled SS\n  - &SS Sammy Sosa\nrbi:\n  - *SS # Subsequent occurrence\n  - Ken Griffey"

///|
let ex2_11 : String = "? - Detroit Tigers\n  - Chicago cubs\n:\n  - 2001-07-23\n\n? [ New York Yankees,\n    Atlanta Braves ]\n: [ 2001-07-02, 2001-08-12,\n    2001-08-14 ]"

///|
let ex2_12 : String = "---\n# Products purchased\n- item    : Super Hoop\n  quantity: 1\n- item    : Basketball\n  quantity: 4\n- item    : Big Shoes\n  quantity: 1"

///|
let ex2_13 : String = "# ASCII Art\n--- |\n  \\//||\\/||\n  // ||  ||__"

///|
let ex2_14 : String = "--- >\n  Mark McGwire's\n  year was crippled\n  by a knee injury."

///|
let ex2_15 : String = ">\n Sammy Sosa completed another\n fine season with great stats.\n \n   63 Home Runs\n   0.288 Batting Average\n \n What a year!"

///|
let ex2_16 : String = "name: Mark McGwire\naccomplishment: >\n  Mark set a major league\n  home run record in 1998.\nstats: |\n  65 Home Runs\n  0.278 Batting Average\n"

///|
let ex2_17 : String = "unicode: \"Sosa did fine.\\u263A\"\ncontrol: \"\\b1998\\t1999\\t2000\\n\"\nhex esc: \"\\x0d\\x0a is \\r\\n\"\n\nsingle: '\"Howdy!\" he cried.'\nquoted: ' # Not a ''comment''.'\ntie-fighter: '|\\-*-/|'"

///|
let ex2_18 : String = "plain:\n  This unquoted scalar\n  spans many lines.\n\nquoted: \"So does this\n  quoted scalar.\\n\""

///|
let ex2_23 : String = "---\nnot-date: !!str 2002-04-28\n\npicture: !!binary |\n R0lGODlhDAAMAIQAAP//9/X\n 17unp5WZmZgAAAOfn515eXv\n Pz7Y6OjuDg4J+fn5OTk6enp\n 56enmleECcgggoBADs=\n\napplication specific tag: !something |\n The semantics of the tag\n above may be different for\n different documents."

///|
let ex2_24 : String = "%TAG ! tag:clarkevans.com,2002:\n--- !shape\n  # Use the ! handle for presenting\n  # tag:clarkevans.com,2002:circle\n- !circle\n  center: &ORIGIN {x: 73, y: 129}\n  radius: 7\n- !line\n  start: *ORIGIN\n  finish: { x: 89, y: 102 }\n- !label\n  start: *ORIGIN\n  color: 0xFFEEBB\n  text: Pretty vector drawing."

///|
let ex2_25 : String = "# Sets are represented as a\n# Mapping where each key is\n# associated with a null value\n--- !!set\n? Mark McGwire\n? Sammy Sosa\n? Ken Griffey"

///|
let ex2_26 : String = "# Ordered maps are represented as\n# A sequence of mappings, with\n# each mapping having one key\n--- !!omap\n- Mark McGwire: 65\n- Sammy Sosa: 63\n- Ken Griffey: 58"

///|
let ex2_27 : String = "--- !<tag:clarkevans.com,2002:invoice>\ninvoice: 34843\ndate   : 2001-01-23\nbill-to: &id001\n    given  : Chris\n    family : Dumars\n    address:\n        lines: |\n            458 Walkman Dr.\n            Suite #292\n        city    : Royal Oak\n        state   : MI\n        postal  : 48046\nship-to: *id001\nproduct:\n    - sku         : BL394D\n      quantity    : 4\n      description : Basketball\n      price       : 450.00\n    - sku         : BL4438H\n      quantity    : 1\n      description : Super Hoop\n      price       : 2392.00\ntax  : 251.42\ntotal: 4443.52\ncomments:\n    Late afternoon is best.\n    Backup contact is Nancy\n    Billsmer @ 338-4338."

///|
let ex2_28 : String = "---\nTime: 2001-11-23 15:01:42 -5\nUser: ed\nWarning:\n  This is an error message\n  for the log file\n---\nTime: 2001-11-23 15:02:31 -5\nUser: ed\nWarning:\n  A slightly different error\n  message.\n---\nDate: 2001-11-23 15:03:17 -5\nUser: ed\nFatal:\n  Unknown variable \"bar\"\nStack:\n  - file: TopClass.py\n    line: 23\n    code: |\n      x = MoreObject(\"345\\n\")\n  - file: MoreClass.py\n    line: 58\n    code: |-\n      foo = bar"

///|
let ex5_3 : String = "sequence:\n- one\n- two\nmapping:\n  ? sky\n  : blue\n  sea : green"

///|
let ex5_4 : String = "sequence: [ one, two, ]\nmapping: { sky: blue, sea: green }"

///|
let ex5_6 : String = "anchored: !local &anchor value\nalias: *anchor"

///|
let ex5_7 : String = "literal: |\n  some\n  text\nfolded: >\n  some\n  text\n"

///|
let ex5_8 : String = "single: 'text'\ndouble: \"text\""

///|
let ex5_11 : String = "|\n  Line break (no glyph)\n  Line break (glyphed)\n"

///|
let ex5_12 : String = "# Tabs and spaces\nquoted: \"Quoted\t\"\nblock:\t|\n  void main() {\n  \tprintf(\"Hello, world!\\n\");\n  }"

///|
let ex5_13 : String = "\"Fun with \\\\\n\\\" \\a \\b \\e \\f \\\n\\n \\r \\t \\v \\0 \\\n\\  \\_ \\N \\L \\P \\\n\\x41 \\u0041 \\U00000041\""

///|
let ex6_1 : String = "  # Leading comment line spaces are\n   # neither content nor indentation.\n    \nNot indented:\n By one space: |\n    By four\n      spaces\n Flow style: [    # Leading spaces\n   By two,        # in flow style\n  Also by two,    # are neither\n  \tStill by two   # content nor\n    ]             # indentation."

///|
let ex6_2 : String = "? a\n: -\tb\n  -  -\tc\n     - d"

///|
let ex6_3 : String = "- foo:\t bar\n- - baz\n  -\tbaz"

///|
let ex6_4 : String = "plain: text\n  lines\nquoted: \"text\n  \tlines\"\nblock: |\n  text\n   \tlines\n"

///|
let ex6_5 : String = "Folding:\n  \"Empty line\n   \t\n  as a line feed\"\nChomping: |\n  Clipped empty lines\n "

///|
let ex6_6 : String = ">-\n  trimmed\n  \n \n\n  as\n  space"

///|
let ex6_7 : String = ">\n  foo \n \n  \t bar\n\n  baz\n"

///|
let ex6_8 : String = "\"\n  foo \n \n  \t bar\n\n  baz\n\""

///|
let ex6_9 : String = "key:    # Comment\n  value"

///|
let ex6_12 : String = "{ first: Sammy, last: Sosa }:\n# Statistics:\n  hr:  # Home runs\n     65\n  avg: # Average\n   0.278"

///|
let ex6_13 : String = "%FOO  bar baz # Should be ignored\n               # with a warning.\n--- \"foo\""

///|
let ex6_14 : String = "%YAML 1.3 # Attempt parsing\n           # with a warning\n---\n\"foo\""

///|
let ex6_16 : String = "%TAG !yaml! tag:yaml.org,2002:\n---\n!yaml!str \"foo\""

///|
let ex6_18 : String = "# Private\n!foo \"bar\"\n...\n# Global\n%TAG ! tag:example.com,2000:app/\n---\n!foo \"bar\""

///|
let ex6_19 : String = "%TAG !! tag:example.com,2000:app/\n---\n!!int 1 - 3 # Interval, not integer"

///|
let ex6_20 : String = "%TAG !e! tag:example.com,2000:app/\n---\n!e!foo \"bar\""

///|
let ex6_21 : String = "%TAG !m! !my-\n--- # Bulb here\n!m!light fluorescent\n...\n%TAG !m! !my-\n--- # Color here\n!m!light green"

///|
let ex6_22 : String = "%TAG !e! tag:example.com,2000:app/\n---\n- !e!foo \"bar\""

///|
let ex6_23 : String = "!!str &a1 \"foo\":\n  !!str bar\n&a2 baz : *a1"

///|
let ex6_24 : String = "!<tag:yaml.org,2002:str> foo :\n  !<!bar> baz"

///|
let ex6_26 : String = "%TAG !e! tag:example.com,2000:app/\n---\n- !local foo\n- !!str bar\n- !e!tag%21 baz\n"

///|
let ex6_28 : String = "# Assuming conventional resolution:\n- \"12\"\n- 12\n- ! 12"

///|
let ex6_29 : String = "First occurrence: &anchor Value\nSecond occurrence: *anchor"

///|
let ex7_1 : String = "First occurrence: &anchor Foo\nSecond occurrence: *anchor\nOverride anchor: &anchor Bar\nReuse anchor: *anchor"

///|
let ex7_3 : String = "{\n  ? foo :,\n  : bar,\n}\n"

///|
let ex7_4 : String = "\"implicit block key\" : [\n  \"implicit flow key\" : value,\n ]"

///|
let ex7_5 : String = "\"folded \nto a space,\t\n \nto a line feed, or \t\\\n \\ \tnon-content\""

///|
let ex7_6 : String = "\" 1st non-empty\n\n 2nd non-empty \n\t3rd non-empty \""

///|
let ex7_7 : String = " 'here''s to \"quotes\"'"

///|
let ex7_8 : String = "'implicit block key' : [\n  'implicit flow key' : value,\n ]"

///|
let ex7_9 : String = "' 1st non-empty\n\n 2nd non-empty \n\t3rd non-empty '"

///|
let ex7_11 : String = "implicit block key : [\n  implicit flow key : value,\n ]"

///|
let ex7_12 : String = "1st non-empty\n\n 2nd non-empty \n\t3rd non-empty"

///|
let ex7_13 : String = "- [ one, two, ]\n- [three ,four]"

///|
let ex7_14 : String = "[\n\"double\n quoted\", 'single\n           quoted',\nplain\n text, [ nested ],\nsingle: pair,\n]"

///|
let ex7_15 : String = "- { one : two , three: four , }\n- {five: six,seven : eight}"

///|
let ex7_16 : String = "{\n? explicit: entry,\nimplicit: entry,\n?\n}"

///|
let ex7_18 : String = "{\n\"adjacent\":value,\n\"readable\":value,\n\"empty\":\n}"

///|
let ex7_19 : String = "[\nfoo: bar\n]"

///|
let ex7_20 : String = "[\n? foo\n bar : baz\n]"

///|
let ex7_23 : String = "- [ a, b ]\n- { a: b }\n- \"a\"\n- 'b'\n- c"

///|
let ex7_24 : String = "- !!str \"a\"\n- 'b'\n- &anchor \"c\"\n- *anchor\n- !!str"

///|
let ex8_1 : String = "- | # Empty header\n literal\n- >1 # Indentation indicator\n  folded\n- |+ # Chomping indicator\n keep\n\n- >1- # Both indicators\n  strip\n"

///|
let ex8_4 : String = "strip: |-\n  text\nclip: |\n  text\nkeep: |+\n  text\n"

///|
let ex8_6 : String = "strip: >-\n\nclip: >\n\nkeep: |+\n\n"

///|
let ex8_7 : String = "|\n literal\n \ttext\n\n"

///|
let ex8_8 : String = "|\n \n  \n  literal\n   \n  \n  text\n\n # Comment\n"

///|
let ex8_9 : String = ">\n folded\n text\n\n"

///|
let ex8_10 : String = ">\n\n folded\n line\n\n next\n line\n   * bullet\n\n   * list\n   * lines\n\n last\n line\n\n# Comment\n"

///|
let ex8_11 : String = ">\n\n folded\n line\n\n next\n line\n   * bullet\n\n   * list\n   * lines\n\n last\n line\n\n# Comment\n"

///|
let ex8_12 : String = ">\n\n folded\n line\n\n next\n line\n   * bullet\n\n   * list\n   * lines\n\n last\n line\n\n# Comment\n"

///|
let ex8_13 : String = ">\n\n folded\n line\n\n next\n line\n   * bullet\n\n   * list\n   * lines\n\n last\n line\n\n# Comment\n"

///|
let ex8_14 : String = "block sequence:\n  - one\n  - two : three\n"

///|
let ex8_15 : String = "- # Empty\n- |\n block node\n- - one # Compact\n  - two # sequence\n- one: two # Compact mapping\n"

///|
let ex8_16 : String = "block mapping:\n key: value\n"

///|
let ex8_17 : String = "? explicit key # Empty value\n? |\n  block key\n: - one # Explicit compact\n  - two # block value\n"

///|
let ex8_18 : String = "plain key: in-line value\n:  # Both empty\n\"quoted key\":\n- entry\n"

///|
let ex8_19 : String = "- sun: yellow\n- ? earth: blue\n  : moon: white\n"

///|
let ex8_20 : String = "-\n  \"flow in block\"\n- >\n Block scalar\n- !!map # Block collection\n  foo : bar\n"

///|
let ex8_22 : String = "sequence: !!seq\n- entry\n- !!seq\n - nested\nmapping: !!map\n foo: bar\n"

///|
test "test_ex2_1_seq_scalars" {
  assert_next(str_to_test_events(ex2_1), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_2_mapping_scalars_to_scalars" {
  assert_next(str_to_test_events(ex2_2), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_3_mapping_scalars_to_sequences" {
  assert_next(str_to_test_events(ex2_3), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_4_sequence_of_mappings" {
  assert_next(str_to_test_events(ex2_4), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_5_sequence_of_sequences" {
  assert_next(str_to_test_events(ex2_5), [
    OnDocumentStart,
    OnSequenceStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_6_mapping_of_mappings" {
  assert_next(str_to_test_events(ex2_6), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_7_two_documents_in_a_stream" {
  assert_next(str_to_test_events(ex2_7), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_8_play_by_play_feed" {
  assert_next(str_to_test_events(ex2_8), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_9_single_document_with_two_comments" {
  assert_next(str_to_test_events(ex2_9), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_10_simple_anchor" {
  assert_next(str_to_test_events(ex2_10), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnScalar,
    OnSequenceStart,
    OnAlias,
    OnScalar,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_11_mapping_between_sequences" {
  assert_next(str_to_test_events(ex2_11), [
    OnDocumentStart,
    OnMapStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceStart,
    OnScalar,
    OnSequenceEnd,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_12_compact_nested_mapping" {
  assert_next(str_to_test_events(ex2_12), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_13_in_literals_newlines_are_preserved" {
  assert_next(str_to_test_events(ex2_13), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_14_in_folded_scalars_newlines_become_spaces" {
  assert_next(str_to_test_events(ex2_14), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_15_folded_newlines_are_preserved_for_more_indented_and_blank_lines" {
  assert_next(str_to_test_events(ex2_15), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_16_indentation_determines_scope" {
  assert_next(str_to_test_events(ex2_16), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_17_quoted_scalars" {
  assert_next(str_to_test_events(ex2_17), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_18_multi_line_flow_scalars" {
  assert_next(str_to_test_events(ex2_18), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_23_various_explicit_tags" {
  assert_next(str_to_test_events(ex2_23), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_24_global_tags" {
  assert_next(str_to_test_events(ex2_24), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnAlias,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnAlias,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_25_unordered_sets" {
  assert_next(str_to_test_events(ex2_25), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnNull,
    OnScalar,
    OnNull,
    OnScalar,
    OnNull,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_26_ordered_mappings" {
  assert_next(str_to_test_events(ex2_26), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_27_invoice" {
  assert_next(str_to_test_events(ex2_27), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnScalar,
    OnAlias,
    OnScalar,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex2_28_log_file" {
  assert_next(str_to_test_events(ex2_28), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex5_3_block_structure_indicators" {
  assert_next(str_to_test_events(ex5_3), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex5_4_flow_structure_indicators" {
  assert_next(str_to_test_events(ex5_4), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex5_6_node_property_indicators" {
  assert_next(str_to_test_events(ex5_6), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnAlias,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex5_7_block_scalar_indicators" {
  assert_next(str_to_test_events(ex5_7), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex5_8_quoted_scalar_indicators" {
  assert_next(str_to_test_events(ex5_8), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex5_11_line_break_characters" {
  assert_next(str_to_test_events(ex5_11), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex5_12_tabs_and_spaces" {
  assert_next(str_to_test_events(ex5_12), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex5_13_escaped_characters" {
  assert_next(str_to_test_events(ex5_13), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_1_indentation_spaces" {
  assert_next(str_to_test_events(ex6_1), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnMapEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_2_indentation_indicators" {
  assert_next(str_to_test_events(ex6_2), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_3_separation_spaces" {
  assert_next(str_to_test_events(ex6_3), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_4_line_prefixes" {
  assert_next(str_to_test_events(ex6_4), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_5_empty_lines" {
  assert_next(str_to_test_events(ex6_5), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_6_line_folding" {
  assert_next(str_to_test_events(ex6_6), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_7_block_folding" {
  assert_next(str_to_test_events(ex6_7), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_8_flow_folding" {
  assert_next(str_to_test_events(ex6_8), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_9_separated_comment" {
  assert_next(str_to_test_events(ex6_9), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_12_separation_spaces_ii" {
  assert_next(str_to_test_events(ex6_12), [
    OnDocumentStart,
    OnMapStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_13_reserved_directives" {
  assert_next(str_to_test_events(ex6_13), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_14_yaml_directive" {
  assert_next(str_to_test_events(ex6_14), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_16_tag_directive" {
  assert_next(str_to_test_events(ex6_16), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_18_primary_tag_handle" {
  assert_next(str_to_test_events(ex6_18), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_19_secondary_tag_handle" {
  assert_next(str_to_test_events(ex6_19), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_20_tag_handles" {
  assert_next(str_to_test_events(ex6_20), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_21_local_tag_prefix" {
  assert_next(str_to_test_events(ex6_21), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_22_global_tag_prefix" {
  assert_next(str_to_test_events(ex6_22), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_23_node_properties" {
  assert_next(str_to_test_events(ex6_23), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnAlias,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_24_verbatim_tags" {
  assert_next(str_to_test_events(ex6_24), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_26_tag_shorthands" {
  assert_next(str_to_test_events(ex6_26), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_28_non_specific_tags" {
  assert_next(str_to_test_events(ex6_28), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex6_29_node_anchors" {
  assert_next(str_to_test_events(ex6_29), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnAlias,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_1_alias_nodes" {
  assert_next(str_to_test_events(ex7_1), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnAlias,
    OnScalar,
    OnScalar,
    OnScalar,
    OnAlias,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_3_completely_empty_nodes" {
  assert_next(str_to_test_events(ex7_3), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnNull,
    OnNull,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_4_double_quoted_implicit_keys" {
  assert_next(str_to_test_events(ex7_4), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_5_double_quoted_line_breaks" {
  assert_next(str_to_test_events(ex7_5), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_6_double_quoted_lines" {
  assert_next(str_to_test_events(ex7_6), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_7_single_quoted_characters" {
  assert_next(str_to_test_events(ex7_7), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_8_single_quoted_implicit_keys" {
  assert_next(str_to_test_events(ex7_8), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_9_single_quoted_lines" {
  assert_next(str_to_test_events(ex7_9), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_11_plain_implicit_keys" {
  assert_next(str_to_test_events(ex7_11), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_12_plain_lines" {
  assert_next(str_to_test_events(ex7_12), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_13_flow_sequence" {
  assert_next(str_to_test_events(ex7_13), [
    OnDocumentStart,
    OnSequenceStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_14_flow_sequence_entries" {
  assert_next(str_to_test_events(ex7_14), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnSequenceEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_15_flow_mappings" {
  assert_next(str_to_test_events(ex7_15), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_16_flow_mapping_entries" {
  assert_next(str_to_test_events(ex7_16), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnNull,
    OnNull,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_18_flow_mapping_adjacent_values" {
  assert_next(str_to_test_events(ex7_18), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnNull,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_19_single_pair_flow_mappings" {
  assert_next(str_to_test_events(ex7_19), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_20_single_pair_explicit_entry" {
  assert_next(str_to_test_events(ex7_20), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_23_flow_content" {
  assert_next(str_to_test_events(ex7_23), [
    OnDocumentStart,
    OnSequenceStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex7_24_flow_nodes" {
  assert_next(str_to_test_events(ex7_24), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnAlias,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_1_block_scalar_header" {
  assert_next(str_to_test_events(ex8_1), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_4_chomping_final_line_break" {
  assert_next(str_to_test_events(ex8_4), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_6_empty_scalar_chomping" {
  assert_next(str_to_test_events(ex8_6), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_7_literal_scalar" {
  assert_next(str_to_test_events(ex8_7), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_8_literal_content" {
  assert_next(str_to_test_events(ex8_8), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_9_folded_scalar" {
  assert_next(str_to_test_events(ex8_9), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_10_folded_lines" {
  assert_next(str_to_test_events(ex8_10), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_11_more_indented_lines" {
  assert_next(str_to_test_events(ex8_11), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_12_empty_separation_lines" {
  assert_next(str_to_test_events(ex8_12), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_13_final_empty_lines" {
  assert_next(str_to_test_events(ex8_13), [
    OnDocumentStart,
    OnScalar,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_14_block_sequence" {
  assert_next(str_to_test_events(ex8_14), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_15_block_sequence_entry_types" {
  assert_next(str_to_test_events(ex8_15), [
    OnDocumentStart,
    OnSequenceStart,
    OnNull,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_16_block_mappings" {
  assert_next(str_to_test_events(ex8_16), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_17_explicit_block_mapping_entries" {
  assert_next(str_to_test_events(ex8_17), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnNull,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_18_implicit_block_mapping_entries" {
  assert_next(str_to_test_events(ex8_18), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnNull,
    OnNull,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnSequenceEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_19_compact_block_mappings" {
  assert_next(str_to_test_events(ex8_19), [
    OnDocumentStart,
    OnSequenceStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_20_block_node_types" {
  assert_next(str_to_test_events(ex8_20), [
    OnDocumentStart,
    OnSequenceStart,
    OnScalar,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnSequenceEnd,
    OnDocumentEnd,
  ])
}

///|
test "test_ex8_22_block_collection_nodes" {
  assert_next(str_to_test_events(ex8_22), [
    OnDocumentStart,
    OnMapStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnSequenceStart,
    OnScalar,
    OnSequenceEnd,
    OnSequenceEnd,
    OnScalar,
    OnMapStart,
    OnScalar,
    OnScalar,
    OnMapEnd,
    OnMapEnd,
    OnDocumentEnd,
  ])
}
