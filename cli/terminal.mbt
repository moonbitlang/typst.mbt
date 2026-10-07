// Terminal output (upstream `typst-cli/src/terminal.rs`): optionally
// colored output on stderr.

///|
/// The color choice of the command line (set once arguments are parsed).
let color_choice : Ref[ColorChoice] = { val: Auto, }

///|
/// Whether terminal output is colored (`TermOutInner::new`).
fn use_color() -> Bool {
  match color_choice.val {
    Auto if @platform.stderr_is_terminal() => @kit.env_allows_color()
    Always => true
    _ => false
  }
}

///|
/// Returns a handle to the optionally colored terminal output (stderr).
/// Its contents are written with [`flush_terminal`].
fn terminal_out() -> @kit.ColorWriter {
  @kit.ColorWriter::new(use_color())
}

///|
/// Writes buffered terminal output to stderr.
fn flush_terminal(out : @kit.ColorWriter) -> Unit {
  @platform.print_stderr(out.take())
  @platform.flush_stderr()
}

///|
/// Clears the entire screen.
fn clear_screen(out : @kit.ColorWriter) -> Unit {
  // We don't want to clear anything that is not a TTY.
  if out.supports_color() {
    // Clear the screen and then move the cursor to the top left corner.
    out.write("\u{1B}[2J\u{1B}[1;1H")
  }
}

///|
/// The style of an error header (`Styles::header_error`).
fn header_error_style() -> @kit.ColorSpec {
  @kit.ColorSpec::new().with_bold().with_intense().with_fg(Red)
}

///|
/// The style of a warning header (`Styles::header_warning`).
fn header_warning_style() -> @kit.ColorSpec {
  @kit.ColorSpec::new().with_bold().with_intense().with_fg(Yellow)
}

///|
/// The style of a note header (`Styles::header_note`).
fn header_note_style() -> @kit.ColorSpec {
  @kit.ColorSpec::new().with_bold().with_intense().with_fg(Green)
}

///|
/// The style of a hint header (`Styles::header_help`).
fn header_help_style() -> @kit.ColorSpec {
  @kit.ColorSpec::new().with_bold().with_intense().with_fg(Cyan)
}

///|
/// Print an application-level error (independent from a source file).
fn print_error(msg : String) -> Unit {
  let output = terminal_out()
  output.set_color(header_error_style())
  output.write("error")
  output.reset()
  output.writeln(": \{msg}")
  flush_terminal(output)
}

///|
/// Print an application-level hint (independent from a source file).
fn print_hint(msg : String) -> Unit {
  let output = terminal_out()
  output.set_color(header_help_style())
  output.write("hint")
  output.reset()
  output.writeln(": \{msg}")
  flush_terminal(output)
}

///|
/// Aborts like a Rust panic: prints the message to stderr and exits with
/// code 101.
fn panic_exit(message : String) -> Unit {
  @platform.print_stderr(
    "\nthread 'main' panicked:\n\{message}\nnote: run with `RUST_BACKTRACE=1` environment variable to display a backtrace\n",
  )
  @platform.exit(101)
}

///|
/// Prints text to stdout like Rust's `print!`, which panics if writing
/// fails (writing to a closed stdout succeeds).
fn print_out(text : String) -> Unit {
  @platform.print_stdout(text) catch {
    err => panic_exit("failed printing to stdout: \{err}")
  }
}

///|
/// Prints text to stdout ignoring errors (like clap's help output).
fn print_out_lossy(text : String) -> Unit {
  @platform.print_stdout(text) catch {
    _ => ()
  }
}
