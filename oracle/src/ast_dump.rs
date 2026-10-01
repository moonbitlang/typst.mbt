//! The `ast` stage: a semantic dump of the typed AST plus `Lines` conversions.
//!
//! Every node of the parsed tree that casts to one of the typed AST nodes
//! with semantic accessors gets one line `<start>..<end> <summary>`. Nodes
//! referenced from a summary are printed as `<Kind>@<start>..<end>` (absolute
//! byte offsets, found by pointer identity within the described subtree) or
//! `<Kind>@ph` for placeholders that are not part of the tree.

use std::fmt::Write as _;

use typst_syntax::ast::{self, AstNode};
use typst_syntax::{Lines, SyntaxNode};

pub fn ast_report(text: &str) -> String {
    let root = typst_syntax::parse(text);
    let mut out = String::new();
    walk(&root, 0, &mut out);
    lines_report(text, &mut out);
    out
}

fn walk(node: &SyntaxNode, offset: usize, out: &mut String) {
    let ctx = Ctx { node, offset };
    if let Some(summary) = describe(&ctx) {
        writeln!(out, "{}..{} {}", offset, offset + node.len(), summary).unwrap();
    }
    let mut off = offset;
    for child in node.children() {
        walk(child, off, out);
        off += child.len();
    }
}

/// The subtree a summary is computed for.
struct Ctx<'a> {
    node: &'a SyntaxNode,
    offset: usize,
}

impl Ctx<'_> {
    /// Find the absolute offset of `target` within this subtree.
    fn locate(&self, target: &SyntaxNode) -> Option<usize> {
        fn go(node: &SyntaxNode, offset: usize, target: &SyntaxNode) -> Option<usize> {
            if std::ptr::eq(node, target) {
                return Some(offset);
            }
            let mut off = offset;
            for child in node.children() {
                if let Some(found) = go(child, off, target) {
                    return Some(found);
                }
                off += child.len();
            }
            None
        }
        go(self.node, self.offset, target)
    }

    /// A reference to a node.
    fn r(&self, node: &SyntaxNode) -> String {
        match self.locate(node) {
            Some(start) => format!("{:?}@{}..{}", node.kind(), start, start + node.len()),
            None => format!("{:?}@ph", node.kind()),
        }
    }

    fn n<'a>(&self, node: impl AstNode<'a>) -> String {
        self.r(node.to_untyped())
    }

    fn ident(&self, ident: ast::Ident) -> String {
        format!("{:?}{}", ident.get().as_str(), self.at(ident.to_untyped()))
    }

    fn math_ident(&self, ident: ast::MathIdent) -> String {
        format!("{:?}{}", ident.get().as_str(), self.at(ident.to_untyped()))
    }

    /// Just the `@range` part of a reference.
    fn at(&self, node: &SyntaxNode) -> String {
        match self.locate(node) {
            Some(start) => format!("@{}..{}", start, start + node.len()),
            None => "@ph".into(),
        }
    }

    fn pattern(&self, pattern: ast::Pattern) -> String {
        match pattern {
            ast::Pattern::Normal(v) => format!("Normal({})", self.n(v)),
            ast::Pattern::Placeholder(v) => format!("Placeholder({})", self.n(v)),
            ast::Pattern::Parenthesized(v) => format!("Parenthesized({})", self.n(v)),
            ast::Pattern::Destructuring(v) => format!("Destructuring({})", self.n(v)),
        }
    }

    fn arg(&self, arg: ast::Arg) -> String {
        match arg {
            ast::Arg::Pos(v) => format!("Pos({})", self.n(v)),
            ast::Arg::Named(v) => format!("Named({})", self.n(v)),
            ast::Arg::Spread(v) => format!("Spread({})", self.n(v)),
        }
    }

    fn param(&self, param: ast::Param) -> String {
        match param {
            ast::Param::Pos(v) => format!("Pos({})", self.pattern(v)),
            ast::Param::Named(v) => format!("Named({})", self.n(v)),
            ast::Param::Spread(v) => format!("Spread({})", self.n(v)),
        }
    }

    fn math_access(&self, access: ast::MathAccess) -> String {
        match access {
            ast::MathAccess::MathIdent(v) => format!("MathIdent({})", self.math_ident(v)),
            ast::MathAccess::MathFieldAccess(v) => {
                format!("MathFieldAccess({})", self.n(v))
            }
        }
    }

    fn idents<'a>(&self, idents: impl IntoIterator<Item = ast::Ident<'a>>) -> String {
        list(idents.into_iter().map(|i| self.ident(i)))
    }

    fn opt_expr(&self, expr: Option<ast::Expr>) -> String {
        opt(expr.map(|e| self.n(e)))
    }
}

fn list(items: impl IntoIterator<Item = String>) -> String {
    let items: Vec<String> = items.into_iter().collect();
    format!("[{}]", items.join(", "))
}

fn opt(v: Option<String>) -> String {
    match v {
        Some(s) => format!("Some({s})"),
        None => "None".into(),
    }
}

fn float(v: f64) -> String {
    format!("{:?} bits={:016x}", v, v.to_bits())
}

fn describe(c: &Ctx) -> Option<String> {
    let node = c.node;
    if let Some(expr) = node.cast::<ast::Expr>() {
        let summary = describe_expr(c, expr);
        return Some(format!(
            "{summary} hash={} literal={}",
            expr.hash(),
            expr.is_literal()
        ));
    }
    if let Some(v) = node.cast::<ast::Markup>() {
        return Some(format!("Markup exprs={}", list(v.exprs().map(|e| c.n(e)))));
    }
    if let Some(v) = node.cast::<ast::Code>() {
        return Some(format!("Code exprs={}", list(v.exprs().map(|e| c.n(e)))));
    }
    if let Some(v) = node.cast::<ast::Args>() {
        return Some(format!(
            "Args items={} trailing_comma={}",
            list(v.items().map(|a| c.arg(a))),
            v.trailing_comma()
        ));
    }
    if let Some(v) = node.cast::<ast::Params>() {
        return Some(format!(
            "Params children={}",
            list(v.children().map(|p| c.param(p)))
        ));
    }
    if let Some(v) = node.cast::<ast::Named>() {
        return Some(format!(
            "Named name={} expr={} pattern={}",
            c.ident(v.name()),
            c.n(v.expr()),
            c.pattern(v.pattern())
        ));
    }
    if let Some(v) = node.cast::<ast::Keyed>() {
        return Some(format!("Keyed key={} expr={}", c.n(v.key()), c.n(v.expr())));
    }
    if let Some(v) = node.cast::<ast::Spread>() {
        return Some(format!(
            "Spread expr={} sink_ident={} sink_expr={}",
            c.n(v.expr()),
            opt(v.sink_ident().map(|i| c.ident(i))),
            c.opt_expr(v.sink_expr())
        ));
    }
    if let Some(v) = node.cast::<ast::Destructuring>() {
        let items = v.items().map(|item| match item {
            ast::DestructuringItem::Pattern(p) => format!("Pattern({})", c.pattern(p)),
            ast::DestructuringItem::Named(n) => format!("Named({})", c.n(n)),
            ast::DestructuringItem::Spread(s) => format!("Spread({})", c.n(s)),
        });
        return Some(format!(
            "Destructuring items={} bindings={}",
            list(items),
            c.idents(v.bindings())
        ));
    }
    if let Some(v) = node.cast::<ast::ImportItems>() {
        let items = v.iter().map(|item| {
            let head = match item {
                ast::ImportItem::Simple(p) => format!("Simple({})", c.n(p)),
                ast::ImportItem::Renamed(r) => format!("Renamed({})", c.n(r)),
            };
            format!(
                "{head} path={} original_name={} bound_name={}",
                c.n(item.path()),
                c.ident(item.original_name()),
                c.ident(item.bound_name())
            )
        });
        return Some(format!("ImportItems iter={}", list(items)));
    }
    if let Some(v) = node.cast::<ast::ImportItemPath>() {
        return Some(format!(
            "ImportItemPath iter={} name={}",
            c.idents(v.iter()),
            c.ident(v.name())
        ));
    }
    if let Some(v) = node.cast::<ast::RenamedImportItem>() {
        return Some(format!(
            "RenamedImportItem path={} original_name={} new_name={}",
            c.n(v.path()),
            c.ident(v.original_name()),
            c.ident(v.new_name())
        ));
    }
    if let Some(v) = node.cast::<ast::MathArgs>() {
        let args = v.arg_items().map(|a| {
            format!("{} semicolon={}", c.arg(a.arg), a.ends_in_semicolon)
        });
        let items = v.content_items().map(|item| match item {
            ast::MathArgItem::Arg(a) => format!("Arg({})", c.arg(a)),
            ast::MathArgItem::Space(s) => format!("Space({})", c.n(s)),
            ast::MathArgItem::Comma(ch, n) => format!("Comma({ch:?}, {})", c.r(n)),
            ast::MathArgItem::Semicolon(ch, n) => {
                format!("Semicolon({ch:?}, {})", c.r(n))
            }
            ast::MathArgItem::LeftParen(ch, n) => {
                format!("LeftParen({ch:?}, {})", c.r(n))
            }
            ast::MathArgItem::RightParen(ch, n) => {
                format!("RightParen({ch:?}, {})", c.r(n))
            }
        });
        return Some(format!(
            "MathArgs arg_items={} content_items={}",
            list(args),
            list(items)
        ));
    }
    if let Some(v) = node.cast::<ast::RawLang>() {
        return Some(format!("RawLang {:?}", v.get().as_str()));
    }
    if let Some(v) = node.cast::<ast::LineComment>() {
        return Some(format!("LineComment {:?}", v.text()));
    }
    if let Some(v) = node.cast::<ast::BlockComment>() {
        return Some(format!("BlockComment {:?}", v.text()));
    }
    None
}

fn describe_expr(c: &Ctx, expr: ast::Expr) -> String {
    use ast::Expr as E;
    match expr {
        E::Text(v) => format!("Text {:?}", v.get().as_str()),
        E::Space(v) => format!("Space had_newline={}", v.had_newline()),
        E::Linebreak(_) => "Linebreak".into(),
        E::Parbreak(_) => "Parbreak".into(),
        E::Escape(v) => format!("Escape {:?}", v.get()),
        E::Shorthand(v) => format!("Shorthand {:?}", v.get()),
        E::SmartQuote(v) => format!("SmartQuote double={}", v.double()),
        E::Strong(v) => format!("Strong body={}", c.n(v.body())),
        E::Emph(v) => format!("Emph body={}", c.n(v.body())),
        E::Raw(v) => format!(
            "Raw block={} lang={} lines={}",
            v.block(),
            opt(v.lang().map(|l| format!("{:?}{}", l.get().as_str(), c.at(l.to_untyped())))),
            list(v.lines().map(|t| format!("{:?}", t.get().as_str())))
        ),
        E::Link(v) => format!("Link {:?}", v.get().as_str()),
        E::Label(v) => format!("Label {:?}", v.get()),
        E::Ref(v) => format!(
            "Ref target={:?} supplement={}",
            v.target(),
            opt(v.supplement().map(|s| c.n(s)))
        ),
        E::Heading(v) => format!("Heading depth={} body={}", v.depth(), c.n(v.body())),
        E::ListItem(v) => format!("ListItem body={}", c.n(v.body())),
        E::EnumItem(v) => {
            format!("EnumItem number={:?} body={}", v.number(), c.n(v.body()))
        }
        E::TermItem(v) => format!(
            "TermItem term={} description={}",
            c.n(v.term()),
            c.n(v.description())
        ),
        E::Equation(v) => format!("Equation block={} body={}", v.block(), c.n(v.body())),
        E::Math(v) => format!(
            "Math exprs={} was_deparenthesized={}",
            list(v.exprs().map(|e| c.n(e))),
            v.was_deparenthesized()
        ),
        E::MathText(v) => match v.get() {
            ast::MathTextKind::Grapheme(s) => format!("MathText Grapheme({:?})", s.as_str()),
            ast::MathTextKind::Number(s) => format!("MathText Number({:?})", s.as_str()),
        },
        E::MathIdent(v) => format!("MathIdent {:?}", v.get().as_str()),
        E::MathFieldAccess(v) => format!(
            "MathFieldAccess target={} field={}",
            c.math_access(v.target()),
            c.math_ident(v.field())
        ),
        E::MathShorthand(v) => format!("MathShorthand {:?}", v.get()),
        E::MathAlignPoint(_) => "MathAlignPoint".into(),
        E::MathCall(v) => format!(
            "MathCall callee={} args={}",
            c.math_access(v.callee()),
            c.n(v.args())
        ),
        E::MathDelimited(v) => format!(
            "MathDelimited open={} body={} close={}",
            c.n(v.open()),
            c.n(v.body()),
            c.n(v.close())
        ),
        E::MathAttach(v) => format!(
            "MathAttach base={} bottom={} top={} primes={}",
            c.n(v.base()),
            c.opt_expr(v.bottom()),
            c.opt_expr(v.top()),
            opt(v.primes().map(|p| c.n(p)))
        ),
        E::MathPrimes(v) => format!("MathPrimes count={}", v.count()),
        E::MathFrac(v) => {
            format!("MathFrac num={} denom={}", c.n(v.num()), c.n(v.denom()))
        }
        E::MathRoot(v) => format!(
            "MathRoot index={:?} radicand={}",
            v.index(),
            c.n(v.radicand())
        ),
        E::Ident(v) => format!("Ident {:?}", v.get().as_str()),
        E::None(_) => "None".into(),
        E::Auto(_) => "Auto".into(),
        E::Bool(v) => format!("Bool {}", v.get()),
        E::Int(v) => match v.get() {
            Ok(i) => format!("Int Ok({i})"),
            Err(ast::IntLiteralError::PosOverflow { base, max_plus_one }) => format!(
                "Int Err(PosOverflow base={} max_plus_one={max_plus_one})",
                opt(base.map(|b| b.name().to_string()))
            ),
            Err(ast::IntLiteralError::InvalidDigit(base, digits)) => {
                format!("Int Err(InvalidDigit {} {:?})", base.name(), digits)
            }
        },
        E::Float(v) => format!("Float {}", float(v.get())),
        E::Numeric(v) => {
            let (value, unit) = v.get();
            format!("Numeric {} {:?}", float(value), unit)
        }
        E::Str(v) => format!("Str {:?}", v.get().as_str()),
        E::CodeBlock(v) => format!("CodeBlock body={}", c.n(v.body())),
        E::ContentBlock(v) => format!("ContentBlock body={}", c.n(v.body())),
        E::Parenthesized(v) => format!(
            "Parenthesized expr={} pattern={}",
            c.n(v.expr()),
            c.pattern(v.pattern())
        ),
        E::Array(v) => {
            let items = v.items().map(|item| match item {
                ast::ArrayItem::Pos(e) => format!("Pos({})", c.n(e)),
                ast::ArrayItem::Spread(s) => format!("Spread({})", c.n(s)),
            });
            format!("Array items={}", list(items))
        }
        E::Dict(v) => {
            let items = v.items().map(|item| match item {
                ast::DictItem::Named(n) => format!("Named({})", c.n(n)),
                ast::DictItem::Keyed(k) => format!("Keyed({})", c.n(k)),
                ast::DictItem::Spread(s) => format!("Spread({})", c.n(s)),
            });
            format!("Dict items={}", list(items))
        }
        E::Unary(v) => format!("Unary op={:?} expr={}", v.op(), c.n(v.expr())),
        E::Binary(v) => format!(
            "Binary op={:?} lhs={} rhs={}",
            v.op(),
            c.n(v.lhs()),
            c.n(v.rhs())
        ),
        E::FieldAccess(v) => format!(
            "FieldAccess target={} field={}",
            c.n(v.target()),
            c.ident(v.field())
        ),
        E::FuncCall(v) => {
            format!("FuncCall callee={} args={}", c.n(v.callee()), c.n(v.args()))
        }
        E::Closure(v) => format!(
            "Closure name={} params={} body={}",
            opt(v.name().map(|i| c.ident(i))),
            c.n(v.params()),
            c.n(v.body())
        ),
        E::LetBinding(v) => {
            let kind = match v.kind() {
                ast::LetBindingKind::Normal(p) => format!("Normal({})", c.pattern(p)),
                ast::LetBindingKind::Closure(i) => format!("Closure({})", c.ident(i)),
            };
            format!(
                "LetBinding kind={kind} init={} bindings={}",
                c.opt_expr(v.init()),
                c.idents(v.kind().bindings())
            )
        }
        E::DestructAssignment(v) => format!(
            "DestructAssignment pattern={} value={}",
            c.pattern(v.pattern()),
            c.n(v.value())
        ),
        E::SetRule(v) => format!(
            "SetRule target={} args={} condition={}",
            c.n(v.target()),
            c.n(v.args()),
            c.opt_expr(v.condition())
        ),
        E::ShowRule(v) => format!(
            "ShowRule selector={} transform={}",
            c.opt_expr(v.selector()),
            c.n(v.transform())
        ),
        E::Contextual(v) => format!("Contextual body={}", c.n(v.body())),
        E::Conditional(v) => format!(
            "Conditional condition={} if_body={} else_body={}",
            c.n(v.condition()),
            c.n(v.if_body()),
            c.opt_expr(v.else_body())
        ),
        E::WhileLoop(v) => format!(
            "WhileLoop condition={} body={}",
            c.n(v.condition()),
            c.n(v.body())
        ),
        E::ForLoop(v) => format!(
            "ForLoop pattern={} iterable={} body={}",
            c.pattern(v.pattern()),
            c.n(v.iterable()),
            c.n(v.body())
        ),
        E::ModuleImport(v) => {
            let imports = match v.imports() {
                None => "None".to_string(),
                Some(ast::Imports::Wildcard) => "Some(Wildcard)".to_string(),
                Some(ast::Imports::Items(items)) => format!("Some(Items({}))", c.n(items)),
            };
            let bare = match v.bare_name() {
                Ok(name) => format!("Ok({:?})", name.as_str()),
                Err(err) => format!("Err({err:?})"),
            };
            format!(
                "ModuleImport source={} imports={imports} bare_name={bare} new_name={}",
                c.n(v.source()),
                opt(v.new_name().map(|i| c.ident(i)))
            )
        }
        E::ModuleInclude(v) => format!("ModuleInclude source={}", c.n(v.source())),
        E::LoopBreak(_) => "LoopBreak".into(),
        E::LoopContinue(_) => "LoopContinue".into(),
        E::FuncReturn(v) => format!("FuncReturn body={}", c.opt_expr(v.body())),
    }
}

/// Exhaustive `Lines` conversions for every position of every line.
fn lines_report(text: &str, out: &mut String) {
    let lines = Lines::new(text);
    writeln!(
        out,
        "lines len_bytes={} len_utf16={} len_lines={}",
        lines.len_bytes(),
        lines.len_utf16(),
        lines.len_lines()
    )
    .unwrap();
    let n = lines.len_lines();
    let o = |v: Option<usize>| v.map_or("-".to_string(), |v| v.to_string());
    for i in 0..=n {
        let Some(range) = lines.line_to_range(i) else {
            writeln!(out, "L{i} -").unwrap();
            continue;
        };
        let last = i + 1 == n;
        writeln!(out, "L{i} {}..{}", range.start, range.end).unwrap();

        // Byte positions (including non-char boundaries).
        let end = if last { range.end + 1 } else { range.end };
        let mut items = Vec::new();
        for b in range.start..=end {
            let u = lines.byte_to_utf16(b);
            let l = lines.byte_to_line(b);
            let c = lines.byte_to_column(b);
            let lc = lines.byte_to_line_column(b);
            let check = if lc == l.zip(c) { "" } else { "!" };
            items.push(format!("{}:{}:{}{check}", o(u), o(l), o(c)));
        }
        writeln!(out, "  b {}", items.join(" ")).unwrap();

        // UTF-16 positions.
        let (Some(u_start), Some(u_end)) =
            (lines.byte_to_utf16(range.start), lines.byte_to_utf16(range.end))
        else {
            continue;
        };
        let u_end = if last { u_end + 1 } else { u_end };
        let items: Vec<String> = (u_start..=u_end).map(|u| o(lines.utf16_to_byte(u))).collect();
        writeln!(out, "  u {}", items.join(" ")).unwrap();

        // Columns.
        let chars = text[range.clone()].chars().count();
        let items: Vec<String> =
            (0..=chars + 1).map(|c| o(lines.line_column_to_byte(i, c))).collect();
        writeln!(out, "  c {}", items.join(" ")).unwrap();
    }
}
