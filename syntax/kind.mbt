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
} derive(Eq)

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
