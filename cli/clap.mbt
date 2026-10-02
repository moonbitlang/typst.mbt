// A small command line parser in the style of `clap` (which upstream
// typst-cli uses): long and short options, `--opt=value` / `--opt value` /
// `-oVALUE` / `-o value`, flags, options with optional values (that
// require `=`), environment variable fallbacks, value delimiters, `--` and
// positional arguments. Errors and help are formatted like clap's (the
// wording of clap's messages is approximated; they are not Typst messages).

///|
/// How an argument takes values.
priv enum ArgKind {
  /// A flag without a value (counted).
  Flag
  /// An option with a value.
  Value
  /// An option whose value is optional and must be attached with `=`
  /// (`num_args = 0..=1, require_equals = true`); a bare occurrence takes
  /// `missing` as its value.
  OptionalValue(String)
  /// An option whose value is optional but may also be the next argument
  /// (`num_args = 0..=1` without `require_equals`, like `--color`).
  LooseValue(String)
}

///|
/// How an empty value (`--opt ''`, `--opt=` or an empty environment
/// variable) is treated, like clap's value parsers.
priv enum EmptyMode {
  /// Rejected ("a value is required ... but none was supplied"), like
  /// clap's `PathBufValueParser` and `ValueEnum` parsers.
  Required
  /// Passed to the option's own parser.
  Pass
}

///|
/// An option or flag.
priv struct ArgSpec {
  id : String
  long : String
  short : Char?
  kind : ArgKind
  env : String?
  delimiter : Char?
  value_name : String
  help : String
  possible : Array[String]
  hidden : Bool
  empty : EmptyMode
  /// The option's value parser, run when a value is consumed.
  validate : ((String) -> Unit raise CliError)?
}

///|
fn flag(
  id : String,
  short? : Char,
  env? : String,
  hidden? : Bool = false,
  help~ : String,
) -> ArgSpec {
  {
    id,
    long: id,
    short,
    kind: Flag,
    env,
    delimiter: None,
    value_name: "",
    help,
    possible: [],
    hidden,
    empty: Required,
    validate: None,
  }
}

///|
fn opt(
  id : String,
  value_name : String,
  short? : Char,
  env? : String,
  delimiter? : Char,
  possible? : Array[String] = [],
  hidden? : Bool = false,
  empty? : EmptyMode = Required,
  validate? : (String) -> Unit raise CliError,
  help~ : String,
) -> ArgSpec {
  {
    id,
    long: id,
    short,
    kind: Value,
    env,
    delimiter,
    value_name,
    help,
    possible,
    hidden,
    empty,
    validate,
  }
}

///|
fn opt_optional(
  id : String,
  value_name : String,
  missing : String,
  hidden? : Bool = false,
  help~ : String,
) -> ArgSpec {
  {
    id,
    long: id,
    short: None,
    kind: OptionalValue(missing),
    env: None,
    delimiter: None,
    value_name,
    help,
    possible: ["true", "false"],
    hidden,
    empty: Required,
    validate: None,
  }
}

///|
/// A positional argument.
priv struct PosSpec {
  name : String
  required : Bool
  help : String
}

///|
/// A command: its options and positional arguments.
priv struct CommandSpec {
  /// The subcommand name (empty for the main command), to look up its help.
  key : String
  /// The full command path for usage lines (e.g. `typst compile`).
  path : String
  about : String
  args : Array[ArgSpec]
  positionals : Array[PosSpec]
  /// Subcommands: name, aliases, about.
  subcommands : Array[(String, Array[String], String, Bool)]
}

///|
/// The result of parsing.
priv struct Matches {
  values : Map[String, Array[String]]
  counts : Map[String, Int]
  positionals : Array[String]
  /// The subcommand name and its remaining arguments.
  subcommand : (String, Array[String])?
  /// Separate values of optional-value options that are not validated yet
  /// (see `Matches::resolve_pending`).
  pending : Array[(ArgSpec, String)]
}

///|
/// Validates and records the pending values (clap does this after parsing a
/// following subcommand).
fn Matches::resolve_pending(self : Matches) -> Unit raise CliError {
  for entry in self.pending {
    let (spec, value) = entry
    if value == "" && spec.empty is Required {
      raise Invalid(
        "a value is required for '\{spec.display()}' but none was supplied\{possible_values(spec)}",
      )
    }
    if spec.possible.length() > 0 && !spec.possible.contains(value) {
      raise Invalid(
        "invalid value '\{value}' for '\{spec.display()}'\n  [possible values: \{spec.possible.join(", ")}]",
      )
    }
    match self.values.get(spec.id) {
      Some(list) => list.push(value)
      None => self.values[spec.id] = [value]
    }
  }
  self.pending.clear()
}

///|
fn Matches::value(self : Matches, id : String) -> String? {
  match self.values.get(id) {
    Some(values) if values.length() > 0 => Some(values[values.length() - 1])
    _ => None
  }
}

///|
fn Matches::all(self : Matches, id : String) -> Array[String] {
  self.values.get(id).unwrap_or([])
}

///|
fn Matches::flag(self : Matches, id : String) -> Bool {
  self.counts.get(id).unwrap_or(0) > 0
}

///|
fn Matches::positional(self : Matches, i : Int) -> String? {
  if i < self.positionals.length() {
    Some(self.positionals[i])
  } else {
    None
  }
}

///|
/// A command line error (clap's `Error`): the message and whether it is
/// help or version output (printed to stdout with exit code 0).
priv suberror CliError {
  /// A usage error: message (without `error: `) and usage line.
  Usage(String, String)
  /// An invalid value error (no usage line).
  Invalid(String)
  /// Help or version text to print to stdout.
  Display(String)
  /// No subcommand was given (clap's
  /// `DisplayHelpOnMissingArgumentOrSubcommand`).
  MissingSubcommand
}

///|
fn CommandSpec::usage(self : CommandSpec) -> String {
  // The usage line of the upstream help.
  if help_text(self.key, false) is Some(text) {
    for line in text.split("\n") {
      if line.has_prefix("Usage: ") {
        return line[7:].to_owned()
      }
    }
  }
  let buf = StringBuilder()
  buf.write_string(self.path)
  if self.args.length() > 0 {
    buf.write_string(" [OPTIONS]")
  }
  for pos in self.positionals {
    if pos.required {
      buf.write_string(" <\{pos.name}>")
    } else {
      buf.write_string(" [\{pos.name}]")
    }
  }
  if self.subcommands.length() > 0 {
    buf.write_string(" <COMMAND>")
  }
  buf.to_string()
}

///|
fn ArgSpec::display(self : ArgSpec) -> String {
  match self.kind {
    Flag => "--\{self.long}"
    Value | LooseValue(_) => "--\{self.long} <\{self.value_name}>"
    OptionalValue(_) => "--\{self.long}[=<\{self.value_name}>]"
  }
}

///|
/// The usage line with only the required arguments (clap's required usage,
/// shown when arguments are missing). `output_required` marks `[OUTPUT]` as
/// required (for input from stdin).
fn CommandSpec::required_usage(
  self : CommandSpec,
  output_required? : Bool = false,
) -> String {
  let buf = StringBuilder()
  buf.write_string(self.path)
  for pos in self.positionals {
    if pos.required || (output_required && pos.name == "OUTPUT") {
      buf.write_string(" <\{pos.name}>")
    } else {
      buf.write_string(" [\{pos.name}]")
    }
  }
  buf.to_string()
}

///|
/// The upstream help text of a command (see `help_gen.mbt`).
fn help_text(key : String, long : Bool) -> String? {
  for entry in help_texts {
    if entry.0 == key && entry.1 == long {
      return Some(entry.2 + "\n")
    }
  }
  None
}

///|
/// The help of a command: upstream's text, or a rendering of the spec.
fn CommandSpec::help(self : CommandSpec, long? : Bool = true) -> String {
  match help_text(self.key, long) {
    Some(text) => text
    None => self.render_help()
  }
}

///|
/// Renders the help of a command.
fn CommandSpec::render_help(self : CommandSpec) -> String {
  let buf = StringBuilder()
  if self.about != "" {
    buf.write_string("\{self.about}\n\n")
  }
  buf.write_string("Usage: \{self.usage()}\n")
  if self.subcommands.length() > 0 {
    buf.write_string("\nCommands:\n")
    let mut width = 4
    for sub in self.subcommands {
      if !sub.3 && sub.0.length() > width {
        width = sub.0.length()
      }
    }
    for sub in self.subcommands {
      if sub.3 {
        continue
      }
      let (name, aliases, about, _) = sub
      buf.write_string("  \{name}")
      buf.write_string(" ".repeat(width - name.length() + 2))
      buf.write_string(about)
      if aliases.length() > 0 {
        buf.write_string(" [aliases: \{aliases.join(", ")}]")
      }
      buf.write_char('\n')
    }
    buf.write_string("  help")
    buf.write_string(" ".repeat(width - 4 + 2))
    buf.write_string(
      "Print this message or the help of the given subcommand(s)\n",
    )
  }
  if self.positionals.length() > 0 {
    buf.write_string("\nArguments:\n")
    for pos in self.positionals {
      let name = if pos.required { "<\{pos.name}>" } else { "[\{pos.name}]" }
      buf.write_string("  \{name}\n          \{pos.help}\n\n")
    }
  }
  buf.write_string("\nOptions:\n")
  for arg in self.args {
    if arg.hidden {
      continue
    }
    let short = match arg.short {
      Some(c) => "-\{c}, "
      None => ""
    }
    buf.write_string("  \{short}\{arg.display()}\n          \{arg.help}\n")
    if arg.possible.length() > 0 {
      buf.write_string(
        "          \n          [possible values: \{arg.possible.join(", ")}]\n",
      )
    }
    if arg.env is Some(env) {
      buf.write_string("          \n          [env: \{env}=]\n")
    }
    buf.write_char('\n')
  }
  buf.write_string(
    "  -h, --help\n          Print help (see a summary with '-h')\n",
  )
  if self.subcommands.length() > 0 {
    buf.write_string("\n  -V, --version\n          Print version\n")
  }
  buf.to_string()
}

///|
/// Parses arguments for a command. Subcommand dispatch stops at the first
/// positional when the command has subcommands.
fn CommandSpec::parse(
  self : CommandSpec,
  argv : Array[String],
) -> Matches raise CliError {
  let values : Map[String, Array[String]] = Map([])
  let counts : Map[String, Int] = Map([])
  let positionals = []
  let mut subcommand = None
  let mut i = 0
  let pending : Array[(ArgSpec, String)] = []
  let used : Array[String] = []
  let unexpected = (arg : String) => {
    let tip = if self.positionals.is_empty() {
      ""
    } else {
      "\n\n  tip: to pass '\{arg}' as a value, use '-- \{arg}'"
    }
    Usage(
      "unexpected argument '\{arg}' found\{tip}",
      self.smart_usage(used, positionals.length()),
    )
  }
  let mut only_positional = false
  let find_long = (name : String) => self.args.search_by(a => a.long == name)
  let find_short = (c : Char) => self.args.search_by(a => a.short == Some(c))
  let push_value = (spec : ArgSpec, value : String) => {
    if value == "" && spec.empty is Required {
      raise Invalid(
        "a value is required for '\{spec.display()}' but none was supplied\{possible_values(spec)}",
      )
    }
    if spec.validate is Some(validate) {
      validate(value)
    }
    if spec.possible.length() > 0 && !spec.possible.contains(value) {
      raise Invalid(
        "invalid value '\{value}' for '\{spec.display()}'\n  [possible values: \{spec.possible.join(", ")}]",
      )
    }
    match values.get(spec.id) {
      Some(list) => list.push(value)
      None => values[spec.id] = [value]
    }
  }
  let push_values = (spec : ArgSpec, value : String) => {
    match spec.delimiter {
      Some(d) =>
        for part in value.split(d.to_string()) {
          push_value(spec, part.to_owned())
        }
      None => push_value(spec, value)
    }
  }
  while i < argv.length() {
    let arg = argv[i]
    i += 1
    if only_positional || arg == "-" || !arg.has_prefix("-") {
      if self.subcommands.length() > 0 && !only_positional {
        let known = arg == "help" ||
          self.subcommands.iter().any(s => s.0 == arg || s.1.contains(arg))
        if !known {
          raise Usage("unrecognized subcommand '\{arg}'", self.usage())
        }
        subcommand = Some((arg, argv[i:].to_owned()))
        break
      }
      positionals.push(arg)
      continue
    }
    if arg == "--" {
      only_positional = true
      continue
    }
    // A pending value is resolved before the next option.
    for entry in pending {
      push_value(entry.0, entry.1)
    }
    pending.clear()
    if arg.has_prefix("--") {
      let body = arg[2:].to_owned()
      let (name, attached) = match body.find("=") {
        Some(eq) => (body[:eq].to_owned(), Some(body[eq + 1:].to_owned()))
        None => (body, None)
      }
      if name == "help" {
        raise Display(self.help(long=true))
      }
      if name == "version" && self.subcommands.length() > 0 {
        raise Display(version_line() + "\n")
      }
      guard find_long(name) is Some(index) else { raise unexpected(arg) }
      let spec = self.args[index]
      if !used.contains(spec.id) {
        used.push(spec.id)
      }
      match spec.kind {
        Flag => {
          if attached is Some(_) {
            raise Usage(
              "unexpected value '\{attached.unwrap()}' for '\{spec.display()}' found; no more were expected",
              self.usage(),
            )
          }
          counts[spec.id] = counts.get(spec.id).unwrap_or(0) + 1
        }
        OptionalValue(missing) => push_value(spec, attached.unwrap_or(missing))
        LooseValue(missing) =>
          match attached {
            Some(value) => push_value(spec, value)
            None =>
              if i < argv.length() &&
                !(argv[i].has_prefix("-") && argv[i] != "-") {
                // Like clap, a separate value is only validated once the
                // command's arguments are parsed.
                pending.push((spec, argv[i]))
                i += 1
              } else {
                ignore(missing)
                raise Invalid(
                  "a value is required for '\{spec.display()}' but none was supplied\{possible_values(spec)}",
                )
              }
          }
        Value =>
          match attached {
            Some(value) => push_values(spec, value)
            None => {
              if i >= argv.length() ||
                (argv[i].has_prefix("-") && argv[i] != "-") {
                raise Invalid(
                  "a value is required for '\{spec.display()}' but none was supplied\{possible_values(spec)}",
                )
              }
              push_values(spec, argv[i])
              i += 1
            }
          }
      }
      continue
    }
    // Short options.
    let chars = arg[1:].to_owned().to_array()
    let mut k = 0
    while k < chars.length() {
      let c = chars[k]
      k += 1
      if c == 'h' {
        raise Display(self.help(long=false))
      }
      if c == 'V' && self.subcommands.length() > 0 {
        raise Display(version_line() + "\n")
      }
      guard find_short(c) is Some(index) else { raise unexpected("-\{c}") }
      let spec = self.args[index]
      if !used.contains(spec.id) {
        used.push(spec.id)
      }
      match spec.kind {
        Flag | OptionalValue(_) | LooseValue(_) =>
          counts[spec.id] = counts.get(spec.id).unwrap_or(0) + 1
        Value => {
          let rest = String::from_array(chars[k:])
          if rest.has_prefix("=") {
            push_values(spec, rest[1:].to_owned())
          } else if rest != "" {
            push_values(spec, rest)
          } else {
            if i >= argv.length() || (argv[i].has_prefix("-") && argv[i] != "-") {
              raise Invalid(
                "a value is required for '\{spec.display()}' but none was supplied\{possible_values(spec)}",
              )
            }
            push_values(spec, argv[i])
            i += 1
          }
          break
        }
      }
    }
  }

  if subcommand is None {
    for entry in pending {
      push_value(entry.0, entry.1)
    }
    pending.clear()
  }

  // Environment variable fallbacks.
  for spec in self.args {
    guard spec.env is Some(env) else { continue }
    guard @platform.env_var(env) is Some(value) else { continue }
    match spec.kind {
      Flag =>
        if !counts.contains(spec.id) {
          // clap's `BoolValueParser`.
          match value {
            "true" => counts[spec.id] = 1
            "false" => ()
            "" =>
              raise Invalid(
                "a value is required for '\{spec.display()}' but none was supplied\n  [possible values: true, false]",
              )
            _ =>
              raise Invalid(
                "invalid value '\{value}' for '\{spec.display()}'\n  [possible values: true, false]",
              )
          }
        }
      _ => if !values.contains(spec.id) { push_values(spec, value) }
    }
  }
  if positionals.length() > self.positionals.length() {
    raise Usage(
      "unexpected argument '\{positionals[self.positionals.length()]}' found",
      self.usage(),
    )
  }
  { values, counts, positionals, subcommand, pending, }
}

///|
/// The possible values line of an error (empty if there are none).
fn possible_values(spec : ArgSpec) -> String {
  if spec.possible.is_empty() {
    ""
  } else {
    "\n  [possible values: \{spec.possible.join(", ")}]"
  }
}

///|
/// Raises a missing-argument error.
fn missing(spec : CommandSpec, name : String) -> CliError {
  Usage(
    "the following required arguments were not provided:\n  <\{name}>",
    spec.required_usage(),
  )
}

///|
/// clap's usage for errors once arguments were used: the used options and
/// the required (or already given) positionals.
fn CommandSpec::smart_usage(
  self : CommandSpec,
  used : Array[String],
  num_positionals : Int,
) -> String {
  if used.is_empty() && num_positionals == 0 {
    return self.usage()
  }
  let buf = StringBuilder()
  buf.write_string(self.path)
  for arg in self.args {
    if used.contains(arg.id) {
      buf.write_string(" \{arg.display()}")
    }
  }
  for i, pos in self.positionals {
    if pos.required || i < num_positionals {
      buf.write_string(" <\{pos.name}>")
    }
  }
  buf.to_string()
}
