// Port of typst-syntax/src/kind.rs, items in upstream's order (`SyntaxMode`
// is upstream's lib.rs; `index`, `from_index` and `debug_name` stand for
// `#[repr(u8)]` and the derived `Debug`).

///|
/// The syntax mode of a portion of Typst code.
pub(all) enum SyntaxMode {
  /// Text and markup, as in the top level.
  Markup
  /// Math atoms, operators, etc., as in equations.
  Math
  /// Keywords, literals and operators, as after hashes.
  Code
} derive(Eq, Hash, Debug)

///|
/// A syntactical building block of a Typst file.
///
/// Can be created by the lexer or by the parser.
pub(all) enum SyntaxKind {
  /// The end of token stream.
  End
  /// An invalid sequence of characters.
  Error
  /// A shebang: `#! ...`
  Shebang
  /// A line comment: `// ...`.
  LineComment
  /// A block comment: `/* ... */`.
  BlockComment
  /// The contents of a file or content block.
  Markup
  /// Plain text without markup.
  Text
  /// Whitespace with no newlines.
  SpaceNoNewline
  /// Whitespace with _exactly one_ newline in Markup (more would be a `ParBreak`) and _at least one_ newline in Code/Math.
  SpaceWithNewline
  /// A forced line break: `\`.
  Linebreak
  /// A paragraph break, indicated by contiguous whitespace containing at least two newlines. Only produced in Markup.
  Parbreak
  /// An escape sequence: `\#`, `\u{1F5FA}`.
  Escape
  /// A shorthand for a unicode codepoint. For example, `~` for non-breaking space or `-?` for a soft hyphen.
  Shorthand
  /// A smart quote: `'` or `"`.
  SmartQuote
  /// Strong content: `*Strong*`.
  Strong
  /// Emphasized content: `_Emphasized_`.
  Emph
  /// Raw text with optional syntax highlighting: `` `...` ``.
  Raw
  /// A language tag at the start of raw text: ``typ ``.
  RawLang
  /// A raw delimiter consisting of 1 or 3+ backticks: `` ` ``.
  RawDelim
  /// A sequence of whitespace to ignore in a raw text: `    `.
  RawTrimmed
  /// A hyperlink: `https://typst.org`.
  Link
  /// A label: `<intro>`.
  Label
  /// A reference: `@target`, `@target[..]`.
  Ref
  /// Introduces a reference: `@target`.
  RefMarker
  /// A section heading: `= Introduction`.
  Heading
  /// Introduces a section heading: `=`, `==`, ...
  HeadingMarker
  /// An item in a bullet list: `- ...`.
  ListItem
  /// Introduces a list item: `-`.
  ListMarker
  /// An item in an enumeration (numbered list): `+ ...` or `1. ...`.
  EnumItem
  /// Introduces an enumeration item: `+`, `1.`.
  EnumMarker
  /// An item in a term list: `/ Term: Details`.
  TermItem
  /// Introduces a term item: `/`.
  TermMarker
  /// A mathematical equation: `$x$`, `$ x^2 $`.
  Equation
  /// The contents of a mathematical equation: `x^2 + 1`.
  Math
  /// A lone text fragment in math: `x`, `25`, `3.1415`, `=`, `|`, `[`.
  MathText
  /// An identifier in math: `pi`.
  MathIdent
  /// A field access in math: `arrow.r.long.double.bar`.
  MathFieldAccess
  /// A shorthand for a unicode codepoint in math: `a <= b`.
  MathShorthand
  /// An alignment point in math: `&`.
  MathAlignPoint
  /// A function call in math: `mat(delim: "[", a, b; ..#($c$,), d)`.
  MathCall
  /// Function arguments in math: `(delim: "[", a, b; ..#($c$,), d)`.
  MathArgs
  /// Matched delimiters in math: `[x + y]`.
  MathDelimited
  /// A base with optional attachments in math: `a_1^2`.
  MathAttach
  /// Grouped primes in math: `a'''`.
  MathPrimes
  /// A fraction in math: `x/2`.
  MathFrac
  /// A root in math: `√x`, `∛x` or `∜x`.
  MathRoot
  /// A hash that switches into code mode: `#`.
  Hash
  /// A left curly brace, starting a code block: `{`.
  LeftBrace
  /// A right curly brace, terminating a code block: `}`.
  RightBrace
  /// A left square bracket, starting a content block: `[`.
  LeftBracket
  /// A right square bracket, terminating a content block: `]`.
  RightBracket
  /// A left round parenthesis, starting a grouped expression, collection, argument or parameter list: `(`.
  LeftParen
  /// A right round parenthesis, terminating a grouped expression, collection, argument or parameter list: `)`.
  RightParen
  /// A comma separator in a sequence: `,`.
  Comma
  /// A semicolon terminating an expression: `;`.
  Semicolon
  /// A colon between name/key and value in a dictionary, argument or parameter list, or between the term and body of a term list term: `:`.
  Colon
  /// The strong text toggle, multiplication operator, and wildcard import symbol: `*`.
  Star
  /// Toggles emphasized text and indicates a subscript in math: `_`.
  Underscore
  /// Starts and ends a mathematical equation: `$`.
  Dollar
  /// The unary plus and binary addition operator: `+`.
  Plus
  /// The unary negation and binary subtraction operator: `-`.
  Minus
  /// The division operator and fraction operator in math: `/`.
  Slash
  /// The superscript operator in math: `^`.
  Hat
  /// The field access and method call operator: `.`.
  Dot
  /// The assignment operator: `=`.
  Eq
  /// The equality operator: `==`.
  EqEq
  /// The inequality operator: `!=`.
  ExclEq
  /// The less-than operator: `<`.
  Lt
  /// The less-than or equal operator: `<=`.
  LtEq
  /// The greater-than operator: `>`.
  Gt
  /// The greater-than or equal operator: `>=`.
  GtEq
  /// The add-assign operator: `+=`.
  PlusEq
  /// The subtract-assign operator: `-=`.
  HyphEq
  /// The multiply-assign operator: `*=`.
  StarEq
  /// The divide-assign operator: `/=`.
  SlashEq
  /// Indicates a spread or sink: `..`.
  Dots
  /// An arrow between a closure's parameters and body: `=>`.
  Arrow
  /// A root: `√`, `∛` or `∜`.
  Root
  /// An exclamation mark; groups with directly preceding text in math: `!`.
  Bang
  /// The `not` operator.
  Not
  /// The `and` operator.
  And
  /// The `or` operator.
  Or
  /// The `none` literal.
  None
  /// The `auto` literal.
  Auto
  /// The `let` keyword.
  Let
  /// The `set` keyword.
  Set
  /// The `show` keyword.
  Show
  /// The `context` keyword.
  Context
  /// The `if` keyword.
  If
  /// The `else` keyword.
  Else
  /// The `for` keyword.
  For
  /// The `in` keyword.
  In
  /// The `while` keyword.
  While
  /// The `break` keyword.
  Break
  /// The `continue` keyword.
  Continue
  /// The `return` keyword.
  Return
  /// The `import` keyword.
  Import
  /// The `include` keyword.
  Include
  /// The `as` keyword.
  As
  /// The contents of a code block.
  Code
  /// An identifier: `it`.
  Ident
  /// A boolean: `true`, `false`.
  Bool
  /// An integer: `120`.
  Int
  /// A floating-point number: `1.2`, `10e-4`.
  Float
  /// A numeric value with a unit: `12pt`, `3cm`, `2em`, `90deg`, `50%`.
  Numeric
  /// A quoted string: `"..."`.
  Str
  /// A code block: `{ let x = 1; x + 2 }`.
  CodeBlock
  /// A content block: `[*Hi* there!]`.
  ContentBlock
  /// A grouped expression: `(1 + 2)`.
  Parenthesized
  /// An array: `(1, "hi", 12cm)`.
  Array
  /// A dictionary: `(thickness: 3pt, dash: "solid")`.
  Dict
  /// A named pair: `thickness: 3pt`.
  Named
  /// A keyed pair: `"spacy key": true`.
  Keyed
  /// A unary operation: `-x`.
  Unary
  /// A binary operation: `a + b`.
  Binary
  /// A field access: `properties.age`.
  FieldAccess
  /// An invocation of a function or method: `f(x, y)`.
  FuncCall
  /// A function call's argument list: `(12pt, y)`.
  Args
  /// Spread arguments or an argument sink: `..x`.
  Spread
  /// A closure: `(x, y) => z`.
  Closure
  /// A closure's parameters: `(x, y)`.
  Params
  /// A let binding: `let x = 1`.
  LetBinding
  /// A set rule: `set text(...)`.
  SetRule
  /// A show rule: `show heading: it => emph(it.body)`.
  ShowRule
  /// A contextual expression: `context text.lang`.
  Contextual
  /// An if-else conditional: `if x { y } else { z }`.
  Conditional
  /// A while loop: `while x { y }`.
  WhileLoop
  /// A for loop: `for x in y { z }`.
  ForLoop
  /// A module import: `import "utils.typ": a, b, c`.
  ModuleImport
  /// Items to import from a module: `a, b, c`.
  ImportItems
  /// A path to an imported name from a submodule: `a.b.c`.
  ImportItemPath
  /// A renamed import item: `a as d`.
  RenamedImportItem
  /// A module include: `include "chapter1.typ"`.
  ModuleInclude
  /// A break from a loop: `break`.
  LoopBreak
  /// A continue in a loop: `continue`.
  LoopContinue
  /// A return from a function: `return`, `return x + 1`.
  FuncReturn
  /// A destructuring pattern: `(x, _, ..y)`.
  Destructuring
  /// A destructuring assignment expression: `(x, y) = (1, 2)`.
  DestructAssignment
} derive(Eq, Hash, Compare, Debug)

///|
let all_kinds : ReadOnlyArray[SyntaxKind] = [
  End,
  Error,
  Shebang,
  LineComment,
  BlockComment,
  Markup,
  Text,
  SpaceNoNewline,
  SpaceWithNewline,
  Linebreak,
  Parbreak,
  Escape,
  Shorthand,
  SmartQuote,
  Strong,
  Emph,
  Raw,
  RawLang,
  RawDelim,
  RawTrimmed,
  Link,
  Label,
  Ref,
  RefMarker,
  Heading,
  HeadingMarker,
  ListItem,
  ListMarker,
  EnumItem,
  EnumMarker,
  TermItem,
  TermMarker,
  Equation,
  Math,
  MathText,
  MathIdent,
  MathFieldAccess,
  MathShorthand,
  MathAlignPoint,
  MathCall,
  MathArgs,
  MathDelimited,
  MathAttach,
  MathPrimes,
  MathFrac,
  MathRoot,
  Hash,
  LeftBrace,
  RightBrace,
  LeftBracket,
  RightBracket,
  LeftParen,
  RightParen,
  Comma,
  Semicolon,
  Colon,
  Star,
  Underscore,
  Dollar,
  Plus,
  Minus,
  Slash,
  Hat,
  Dot,
  Eq,
  EqEq,
  ExclEq,
  Lt,
  LtEq,
  Gt,
  GtEq,
  PlusEq,
  HyphEq,
  StarEq,
  SlashEq,
  Dots,
  Arrow,
  Root,
  Bang,
  Not,
  And,
  Or,
  None,
  Auto,
  Let,
  Set,
  Show,
  Context,
  If,
  Else,
  For,
  In,
  While,
  Break,
  Continue,
  Return,
  Import,
  Include,
  As,
  Code,
  Ident,
  Bool,
  Int,
  Float,
  Numeric,
  Str,
  CodeBlock,
  ContentBlock,
  Parenthesized,
  Array,
  Dict,
  Named,
  Keyed,
  Unary,
  Binary,
  FieldAccess,
  FuncCall,
  Args,
  Spread,
  Closure,
  Params,
  LetBinding,
  SetRule,
  ShowRule,
  Contextual,
  Conditional,
  WhileLoop,
  ForLoop,
  ModuleImport,
  ImportItems,
  ImportItemPath,
  RenamedImportItem,
  ModuleInclude,
  LoopBreak,
  LoopContinue,
  FuncReturn,
  Destructuring,
  DestructAssignment,
]

///|
/// The numeric index of the kind (its declaration order).
pub fn SyntaxKind::index(self : SyntaxKind) -> Int {
  match self {
    End => 0
    Error => 1
    Shebang => 2
    LineComment => 3
    BlockComment => 4
    Markup => 5
    Text => 6
    SpaceNoNewline => 7
    SpaceWithNewline => 8
    Linebreak => 9
    Parbreak => 10
    Escape => 11
    Shorthand => 12
    SmartQuote => 13
    Strong => 14
    Emph => 15
    Raw => 16
    RawLang => 17
    RawDelim => 18
    RawTrimmed => 19
    Link => 20
    Label => 21
    Ref => 22
    RefMarker => 23
    Heading => 24
    HeadingMarker => 25
    ListItem => 26
    ListMarker => 27
    EnumItem => 28
    EnumMarker => 29
    TermItem => 30
    TermMarker => 31
    Equation => 32
    Math => 33
    MathText => 34
    MathIdent => 35
    MathFieldAccess => 36
    MathShorthand => 37
    MathAlignPoint => 38
    MathCall => 39
    MathArgs => 40
    MathDelimited => 41
    MathAttach => 42
    MathPrimes => 43
    MathFrac => 44
    MathRoot => 45
    Hash => 46
    LeftBrace => 47
    RightBrace => 48
    LeftBracket => 49
    RightBracket => 50
    LeftParen => 51
    RightParen => 52
    Comma => 53
    Semicolon => 54
    Colon => 55
    Star => 56
    Underscore => 57
    Dollar => 58
    Plus => 59
    Minus => 60
    Slash => 61
    Hat => 62
    Dot => 63
    Eq => 64
    EqEq => 65
    ExclEq => 66
    Lt => 67
    LtEq => 68
    Gt => 69
    GtEq => 70
    PlusEq => 71
    HyphEq => 72
    StarEq => 73
    SlashEq => 74
    Dots => 75
    Arrow => 76
    Root => 77
    Bang => 78
    Not => 79
    And => 80
    Or => 81
    None => 82
    Auto => 83
    Let => 84
    Set => 85
    Show => 86
    Context => 87
    If => 88
    Else => 89
    For => 90
    In => 91
    While => 92
    Break => 93
    Continue => 94
    Return => 95
    Import => 96
    Include => 97
    As => 98
    Code => 99
    Ident => 100
    Bool => 101
    Int => 102
    Float => 103
    Numeric => 104
    Str => 105
    CodeBlock => 106
    ContentBlock => 107
    Parenthesized => 108
    Array => 109
    Dict => 110
    Named => 111
    Keyed => 112
    Unary => 113
    Binary => 114
    FieldAccess => 115
    FuncCall => 116
    Args => 117
    Spread => 118
    Closure => 119
    Params => 120
    LetBinding => 121
    SetRule => 122
    ShowRule => 123
    Contextual => 124
    Conditional => 125
    WhileLoop => 126
    ForLoop => 127
    ModuleImport => 128
    ImportItems => 129
    ImportItemPath => 130
    RenamedImportItem => 131
    ModuleInclude => 132
    LoopBreak => 133
    LoopContinue => 134
    FuncReturn => 135
    Destructuring => 136
    DestructAssignment => 137
  }
}

///|
/// The kind with the given index.
pub fn SyntaxKind::from_index(i : Int) -> SyntaxKind {
  all_kinds[i]
}

///|
/// The variant name, as printed by Rust's `Debug`.
pub fn SyntaxKind::debug_name(self : SyntaxKind) -> String {
  match self {
    End => "End"
    Error => "Error"
    Shebang => "Shebang"
    LineComment => "LineComment"
    BlockComment => "BlockComment"
    Markup => "Markup"
    Text => "Text"
    SpaceNoNewline => "SpaceNoNewline"
    SpaceWithNewline => "SpaceWithNewline"
    Linebreak => "Linebreak"
    Parbreak => "Parbreak"
    Escape => "Escape"
    Shorthand => "Shorthand"
    SmartQuote => "SmartQuote"
    Strong => "Strong"
    Emph => "Emph"
    Raw => "Raw"
    RawLang => "RawLang"
    RawDelim => "RawDelim"
    RawTrimmed => "RawTrimmed"
    Link => "Link"
    Label => "Label"
    Ref => "Ref"
    RefMarker => "RefMarker"
    Heading => "Heading"
    HeadingMarker => "HeadingMarker"
    ListItem => "ListItem"
    ListMarker => "ListMarker"
    EnumItem => "EnumItem"
    EnumMarker => "EnumMarker"
    TermItem => "TermItem"
    TermMarker => "TermMarker"
    Equation => "Equation"
    Math => "Math"
    MathText => "MathText"
    MathIdent => "MathIdent"
    MathFieldAccess => "MathFieldAccess"
    MathShorthand => "MathShorthand"
    MathAlignPoint => "MathAlignPoint"
    MathCall => "MathCall"
    MathArgs => "MathArgs"
    MathDelimited => "MathDelimited"
    MathAttach => "MathAttach"
    MathPrimes => "MathPrimes"
    MathFrac => "MathFrac"
    MathRoot => "MathRoot"
    Hash => "Hash"
    LeftBrace => "LeftBrace"
    RightBrace => "RightBrace"
    LeftBracket => "LeftBracket"
    RightBracket => "RightBracket"
    LeftParen => "LeftParen"
    RightParen => "RightParen"
    Comma => "Comma"
    Semicolon => "Semicolon"
    Colon => "Colon"
    Star => "Star"
    Underscore => "Underscore"
    Dollar => "Dollar"
    Plus => "Plus"
    Minus => "Minus"
    Slash => "Slash"
    Hat => "Hat"
    Dot => "Dot"
    Eq => "Eq"
    EqEq => "EqEq"
    ExclEq => "ExclEq"
    Lt => "Lt"
    LtEq => "LtEq"
    Gt => "Gt"
    GtEq => "GtEq"
    PlusEq => "PlusEq"
    HyphEq => "HyphEq"
    StarEq => "StarEq"
    SlashEq => "SlashEq"
    Dots => "Dots"
    Arrow => "Arrow"
    Root => "Root"
    Bang => "Bang"
    Not => "Not"
    And => "And"
    Or => "Or"
    None => "None"
    Auto => "Auto"
    Let => "Let"
    Set => "Set"
    Show => "Show"
    Context => "Context"
    If => "If"
    Else => "Else"
    For => "For"
    In => "In"
    While => "While"
    Break => "Break"
    Continue => "Continue"
    Return => "Return"
    Import => "Import"
    Include => "Include"
    As => "As"
    Code => "Code"
    Ident => "Ident"
    Bool => "Bool"
    Int => "Int"
    Float => "Float"
    Numeric => "Numeric"
    Str => "Str"
    CodeBlock => "CodeBlock"
    ContentBlock => "ContentBlock"
    Parenthesized => "Parenthesized"
    Array => "Array"
    Dict => "Dict"
    Named => "Named"
    Keyed => "Keyed"
    Unary => "Unary"
    Binary => "Binary"
    FieldAccess => "FieldAccess"
    FuncCall => "FuncCall"
    Args => "Args"
    Spread => "Spread"
    Closure => "Closure"
    Params => "Params"
    LetBinding => "LetBinding"
    SetRule => "SetRule"
    ShowRule => "ShowRule"
    Contextual => "Contextual"
    Conditional => "Conditional"
    WhileLoop => "WhileLoop"
    ForLoop => "ForLoop"
    ModuleImport => "ModuleImport"
    ImportItems => "ImportItems"
    ImportItemPath => "ImportItemPath"
    RenamedImportItem => "RenamedImportItem"
    ModuleInclude => "ModuleInclude"
    LoopBreak => "LoopBreak"
    LoopContinue => "LoopContinue"
    FuncReturn => "FuncReturn"
    Destructuring => "Destructuring"
    DestructAssignment => "DestructAssignment"
  }
}

///|
pub impl Show for SyntaxKind with fn output(self, logger) {
  logger.write_string(self.debug_name())
}

///|
/// Is this a bracket, brace, or parenthesis?
pub fn SyntaxKind::is_grouping(self : SyntaxKind) -> Bool {
  self
  is (LeftBracket
  | LeftBrace
  | LeftParen
  | RightBracket
  | RightBrace
  | RightParen)
}

///|
/// Does this node terminate a preceding expression?
pub fn SyntaxKind::is_terminator(self : SyntaxKind) -> Bool {
  self is (End | Semicolon | RightBrace | RightParen | RightBracket)
}

///|
/// Is this a code or content block.
pub fn SyntaxKind::is_block(self : SyntaxKind) -> Bool {
  self is (CodeBlock | ContentBlock)
}

///|
/// Does this node need termination through a semicolon or linebreak?
pub fn SyntaxKind::is_stmt(self : SyntaxKind) -> Bool {
  self is (LetBinding | SetRule | ShowRule | ModuleImport | ModuleInclude)
}

///|
/// Is this node a keyword.
pub fn SyntaxKind::is_keyword(self : SyntaxKind) -> Bool {
  self
  is (Not
  | And
  | Or
  | None
  | Auto
  | Let
  | Set
  | Show
  | Context
  | If
  | Else
  | For
  | In
  | While
  | Break
  | Continue
  | Return
  | Import
  | Include
  | As)
}

///|
/// Whether this kind of node is automatically skipped by the parser in code
/// and math mode.
pub fn SyntaxKind::is_trivia(self : SyntaxKind) -> Bool {
  self
  is (Shebang
  | LineComment
  | BlockComment
  | SpaceNoNewline
  | SpaceWithNewline
  | Parbreak)
}

///|
/// Whether this is an error.
pub fn SyntaxKind::is_error(self : SyntaxKind) -> Bool {
  self is Error
}

///|
/// A human-readable name for the kind.
pub fn SyntaxKind::name(self : SyntaxKind) -> String {
  match self {
    End => "end of tokens"
    Error => "syntax error"
    Shebang => "shebang"
    LineComment => "line comment"
    BlockComment => "block comment"
    Markup => "markup"
    Text => "text"
    SpaceNoNewline => "space"
    SpaceWithNewline => "space"
    Linebreak => "line break"
    Parbreak => "paragraph break"
    Escape => "escape sequence"
    Shorthand => "shorthand"
    SmartQuote => "smart quote"
    Strong => "strong content"
    Emph => "emphasized content"
    Raw => "raw block"
    RawLang => "raw language tag"
    RawDelim => "raw delimiter"
    RawTrimmed => "raw trimmed"
    Link => "link"
    Label => "label"
    Ref => "reference"
    RefMarker => "reference marker"
    Heading => "heading"
    HeadingMarker => "heading marker"
    ListItem => "list item"
    ListMarker => "list marker"
    EnumItem => "enum item"
    EnumMarker => "enum marker"
    TermItem => "term list item"
    TermMarker => "term marker"
    Equation => "equation"
    Math => "math"
    MathText => "math text"
    MathIdent => "math identifier"
    MathFieldAccess => "math field access"
    MathShorthand => "math shorthand"
    MathAlignPoint => "math alignment point"
    MathCall => "math function call"
    MathArgs => "math call arguments"
    MathDelimited => "delimited math"
    MathAttach => "math attachments"
    MathPrimes => "math primes"
    MathFrac => "math fraction"
    MathRoot => "math root"
    Hash => "hash"
    LeftBrace => "opening brace"
    RightBrace => "closing brace"
    LeftBracket => "opening bracket"
    RightBracket => "closing bracket"
    LeftParen => "opening paren"
    RightParen => "closing paren"
    Comma => "comma"
    Semicolon => "semicolon"
    Colon => "colon"
    Star => "star"
    Underscore => "underscore"
    Dollar => "dollar sign"
    Plus => "plus"
    Minus => "minus"
    Slash => "slash"
    Hat => "hat"
    Dot => "dot"
    Eq => "equals sign"
    EqEq => "equality operator"
    ExclEq => "inequality operator"
    Lt => "less-than operator"
    LtEq => "less-than or equal operator"
    Gt => "greater-than operator"
    GtEq => "greater-than or equal operator"
    PlusEq => "add-assign operator"
    HyphEq => "subtract-assign operator"
    StarEq => "multiply-assign operator"
    SlashEq => "divide-assign operator"
    Dots => "dots"
    Arrow => "arrow"
    Root => "root"
    Bang => "exclamation mark"
    Not => "operator `not`"
    And => "operator `and`"
    Or => "operator `or`"
    None => "`none`"
    Auto => "`auto`"
    Let => "keyword `let`"
    Set => "keyword `set`"
    Show => "keyword `show`"
    Context => "keyword `context`"
    If => "keyword `if`"
    Else => "keyword `else`"
    For => "keyword `for`"
    In => "keyword `in`"
    While => "keyword `while`"
    Break => "keyword `break`"
    Continue => "keyword `continue`"
    Return => "keyword `return`"
    Import => "keyword `import`"
    Include => "keyword `include`"
    As => "keyword `as`"
    Code => "code"
    Ident => "identifier"
    Bool => "boolean"
    Int => "integer"
    Float => "float"
    Numeric => "numeric value"
    Str => "string"
    CodeBlock => "code block"
    ContentBlock => "content block"
    Parenthesized => "group"
    Array => "array"
    Dict => "dictionary"
    Named => "named pair"
    Keyed => "keyed pair"
    Unary => "unary expression"
    Binary => "binary expression"
    FieldAccess => "field access"
    FuncCall => "function call"
    Args => "call arguments"
    Spread => "spread"
    Closure => "closure"
    Params => "closure parameters"
    LetBinding => "`let` expression"
    SetRule => "`set` expression"
    ShowRule => "`show` expression"
    Contextual => "`context` expression"
    Conditional => "`if` expression"
    WhileLoop => "while-loop expression"
    ForLoop => "for-loop expression"
    ModuleImport => "`import` expression"
    ImportItems => "import items"
    ImportItemPath => "imported item path"
    RenamedImportItem => "renamed import item"
    ModuleInclude => "`include` expression"
    LoopBreak => "`break` expression"
    LoopContinue => "`continue` expression"
    FuncReturn => "`return` expression"
    Destructuring => "destructuring pattern"
    DestructAssignment => "destructuring assignment expression"
  }
}

///|
/// How to determine the [SyntaxMode] we will be in when immediately after a
/// node of this kind.
priv enum ModeAfter {
  /// The mode is known!
  Known(SyntaxMode)
  /// The syntax mode after this kind is based on its parent.
  Parent
  /// Comments and the bodies of raw text do not produce any syntax mode.
  NoMode
  /// Text under `Raw` is `None`, otherwise it is markup.
  Text
  /// After the opening raw delimiter is `None`, but after the closing one is
  /// the same as the parent `Raw`.
  RawDelim
  /// Dollar signs in an equation.
  Dollar
  /// Spaces depend on their parent, with an edge case for equations.
  Space
  /// Kinds that can be embedded in markup or math with a hash, but can also
  /// be used without a hash in other contexts.
  Embeddable
}

///|
/// How to determine the [SyntaxMode] after a node of this kind.
fn SyntaxKind::mode_after(self : SyntaxKind) -> ModeAfter {
  match self {
    End => ModeAfter::NoMode
    Error => ModeAfter::Parent
    Shebang => ModeAfter::NoMode
    LineComment => ModeAfter::NoMode
    BlockComment => ModeAfter::NoMode
    Markup => ModeAfter::Known(Markup)
    Text => ModeAfter::Text
    SpaceNoNewline => ModeAfter::Space
    SpaceWithNewline => ModeAfter::Space
    Linebreak => ModeAfter::Parent
    Parbreak => ModeAfter::Known(Markup)
    Escape => ModeAfter::Parent
    Shorthand => ModeAfter::Known(Markup)
    SmartQuote => ModeAfter::Known(Markup)
    Strong => ModeAfter::Known(Markup)
    Emph => ModeAfter::Known(Markup)
    Raw => ModeAfter::Embeddable
    RawLang => ModeAfter::NoMode
    RawDelim => ModeAfter::RawDelim
    RawTrimmed => ModeAfter::NoMode
    Link => ModeAfter::Known(Markup)
    Label => ModeAfter::Embeddable
    Ref => ModeAfter::Known(Markup)
    RefMarker => ModeAfter::Known(Markup)
    Heading => ModeAfter::Known(Markup)
    HeadingMarker => ModeAfter::Known(Markup)
    ListItem => ModeAfter::Known(Markup)
    ListMarker => ModeAfter::Known(Markup)
    EnumItem => ModeAfter::Known(Markup)
    EnumMarker => ModeAfter::Known(Markup)
    TermItem => ModeAfter::Known(Markup)
    TermMarker => ModeAfter::Known(Markup)
    Equation => ModeAfter::Embeddable
    Math => ModeAfter::Known(Math)
    MathText => ModeAfter::Known(Math)
    MathIdent => ModeAfter::Known(Math)
    MathFieldAccess => ModeAfter::Known(Math)
    MathShorthand => ModeAfter::Known(Math)
    MathAlignPoint => ModeAfter::Known(Math)
    MathCall => ModeAfter::Known(Math)
    MathArgs => ModeAfter::Known(Math)
    MathDelimited => ModeAfter::Known(Math)
    MathAttach => ModeAfter::Known(Math)
    MathPrimes => ModeAfter::Known(Math)
    MathFrac => ModeAfter::Known(Math)
    MathRoot => ModeAfter::Known(Math)
    Hash => ModeAfter::Known(Code)
    LeftBrace => ModeAfter::Known(Code)
    RightBrace => ModeAfter::Known(Code)
    LeftBracket => ModeAfter::Known(Markup)
    RightBracket => ModeAfter::Parent
    LeftParen => ModeAfter::Parent
    RightParen => ModeAfter::Parent
    Comma => ModeAfter::Parent
    Semicolon => ModeAfter::Parent
    Colon => ModeAfter::Parent
    Star => ModeAfter::Parent
    Underscore => ModeAfter::Parent
    Dollar => ModeAfter::Dollar
    Plus => ModeAfter::Known(Code)
    Minus => ModeAfter::Known(Code)
    Slash => ModeAfter::Parent
    Hat => ModeAfter::Known(Math)
    Dot => ModeAfter::Parent
    Eq => ModeAfter::Known(Code)
    EqEq => ModeAfter::Known(Code)
    ExclEq => ModeAfter::Known(Code)
    Lt => ModeAfter::Known(Code)
    LtEq => ModeAfter::Known(Code)
    Gt => ModeAfter::Known(Code)
    GtEq => ModeAfter::Known(Code)
    PlusEq => ModeAfter::Known(Code)
    HyphEq => ModeAfter::Known(Code)
    StarEq => ModeAfter::Known(Code)
    SlashEq => ModeAfter::Known(Code)
    Dots => ModeAfter::Parent
    Arrow => ModeAfter::Known(Code)
    Root => ModeAfter::Known(Math)
    Bang => ModeAfter::Known(Math)
    Not => ModeAfter::Known(Code)
    And => ModeAfter::Known(Code)
    Or => ModeAfter::Known(Code)
    None => ModeAfter::Known(Code)
    Auto => ModeAfter::Known(Code)
    Let => ModeAfter::Known(Code)
    Set => ModeAfter::Known(Code)
    Show => ModeAfter::Known(Code)
    Context => ModeAfter::Known(Code)
    If => ModeAfter::Known(Code)
    Else => ModeAfter::Known(Code)
    For => ModeAfter::Known(Code)
    In => ModeAfter::Known(Code)
    While => ModeAfter::Known(Code)
    Break => ModeAfter::Known(Code)
    Continue => ModeAfter::Known(Code)
    Return => ModeAfter::Known(Code)
    Import => ModeAfter::Known(Code)
    Include => ModeAfter::Known(Code)
    As => ModeAfter::Known(Code)
    Code => ModeAfter::Known(Code)
    Ident => ModeAfter::Embeddable
    Bool => ModeAfter::Known(Code)
    Int => ModeAfter::Known(Code)
    Float => ModeAfter::Known(Code)
    Numeric => ModeAfter::Known(Code)
    Str => ModeAfter::Embeddable
    CodeBlock => ModeAfter::Known(Code)
    ContentBlock => ModeAfter::Embeddable
    Parenthesized => ModeAfter::Known(Code)
    Array => ModeAfter::Known(Code)
    Dict => ModeAfter::Known(Code)
    Named => ModeAfter::Parent
    Keyed => ModeAfter::Known(Code)
    Unary => ModeAfter::Known(Code)
    Binary => ModeAfter::Known(Code)
    FieldAccess => ModeAfter::Known(Code)
    FuncCall => ModeAfter::Known(Code)
    Args => ModeAfter::Known(Code)
    Spread => ModeAfter::Parent
    Closure => ModeAfter::Known(Code)
    Params => ModeAfter::Known(Code)
    LetBinding => ModeAfter::Known(Code)
    SetRule => ModeAfter::Known(Code)
    ShowRule => ModeAfter::Known(Code)
    Contextual => ModeAfter::Known(Code)
    Conditional => ModeAfter::Known(Code)
    WhileLoop => ModeAfter::Known(Code)
    ForLoop => ModeAfter::Known(Code)
    ModuleImport => ModeAfter::Known(Code)
    ImportItems => ModeAfter::Known(Code)
    ImportItemPath => ModeAfter::Known(Code)
    RenamedImportItem => ModeAfter::Known(Code)
    ModuleInclude => ModeAfter::Known(Code)
    LoopBreak => ModeAfter::Known(Code)
    LoopContinue => ModeAfter::Known(Code)
    FuncReturn => ModeAfter::Known(Code)
    Destructuring => ModeAfter::Known(Code)
    DestructAssignment => ModeAfter::Known(Code)
  }
}
