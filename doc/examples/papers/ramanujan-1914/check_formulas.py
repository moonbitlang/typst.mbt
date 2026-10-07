"""Numerical check of the Typst math strings of the port.

Usage, from the repository root:
  moon run doc/examples/papers/ramanujan-1914 --target native -- --check
  python3 doc/examples/papers/ramanujan-1914/check_formulas.py \\
      _build/papers/ramanujan-1914-math.txt [-v]

Reads the dump written by `--check` (kind <tab> source), evaluates both
sides of every statement that has no free variable but n (the class
invariants G_n and g_n come from their product definitions), and prints the
relative difference. It parses the subset of Typst math the port uses, with
Typst's precedence: attachments, then fractions, then juxtaposition. What it
prints is to be read: a "diff" is expected where the paper says
"approximately" or ends a series with dots, and is a wrong formula (in the
port or in its source) otherwise; "BAD" is a decimal expansion whose printed
digits are not the first digits of the value.

Limits: a statement with n is evaluated at n = 22 only; the arithmetic is
decimal with 60 digits, but sines, tangents and the gamma function go
through binary floats (about 16 digits), so a statement with one of them
that holds is printed as a "diff" of that size.
"""
import re
import sys
import math
from decimal import Decimal as D, getcontext

getcontext().prec = 60
PI = D('3.14159265358979323846264338327950288419716939937510582097494')
N_SAMPLE = D(22)


class Skip(Exception):
    pass


def G(n, sign):
    n = D(n)
    x = PI * n.sqrt()
    prod = D(1)
    k = 1
    while True:
        t = (-(k * x)).exp()
        if t < D(10) ** -58:
            break
        prod *= (1 + sign * t)
        k += 2
    return D(2) ** (D(-1) / 4) * (x / 24).exp() * prod


TOKEN = re.compile(r'''
    (?P<num>\d+\.\d+|\.\d+|\d+)
  | (?P<id>[A-Za-z]+(?:\.[A-Za-z]+)*)
  | (?P<str>"[^"]*")
  | (?P<sym>[(){}\[\]+\-=,;.^_/&'<])
''', re.X)


def tokenize(src):
    out = []
    pos = 0
    while pos < len(src):
        if src[pos].isspace():
            pos += 1
            continue
        mt = TOKEN.match(src, pos)
        if not mt:
            raise Skip('token at %r' % src[pos:pos + 12])
        kind = mt.lastgroup
        text = mt.group()
        if kind == 'id' and len(text) > 1 and '.' not in text and text not in WORDS:
            raise Skip('unknown word %s' % text)
        out.append((kind, text))
        pos = mt.end()
    return out


WORDS = {'sqrt', 'pi', 'log', 'sin', 'tan', 'Gamma', 'times', 'dot', 'quad',
         'med', 'slash', 'comma', 'oo', 'sum', 'epsilon'}
OPEN = {'(': ')', '{': '}', '[': ']'}


class Parser:
    def __init__(self, toks):
        self.t = toks
        self.i = 0

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else (None, None)

    def take(self):
        tok = self.peek()
        self.i += 1
        return tok

    def expr(self):
        kind, text = self.peek()
        if text == '-':
            self.take()
            v = -self.term()
        elif text == '+':
            self.take()
            v = self.term()
        else:
            v = self.term()
        while True:
            kind, text = self.peek()
            if text == '+':
                self.take()
                v = v + self.term()
            elif text == '-':
                self.take()
                v = v - self.term()
            else:
                return v

    def starts_item(self):
        kind, text = self.peek()
        if kind in ('num',):
            return True
        if kind == 'id':
            return text not in ('quad',)
        return text in OPEN

    def term(self):
        v = self.frac()
        while True:
            kind, text = self.peek()
            if text in ('times', 'dot', 'med'):
                self.take()
                if text == 'med':
                    continue
                v = v * self.frac()
            elif text == 'slash':
                self.take()
                v = v / self.frac()
            elif self.starts_item():
                v = v * self.frac()
            else:
                return v

    def frac(self):
        v = self.attach()
        while self.peek()[1] == '/':
            self.take()
            v = v / self.attach()
        return v

    def script(self):
        kind, text = self.peek()
        if text in OPEN:
            return self.group()
        if kind == 'num':
            self.take()
            return D(text)
        if kind == 'id':
            self.take()
            return self.ident(text)
        raise Skip('script %r' % text)

    def attach(self):
        kind, text = self.peek()
        # functions written without parentheses: sin x, tan^2 x
        if text in ('sin', 'tan'):
            self.take()
            pw = D(1)
            if self.peek()[1] == '^':
                self.take()
                pw = self.script()
            arg = self.frac()
            f = math.sin if text == 'sin' else math.tan
            return D(repr(f(float(arg)))) ** pw
        if text in ('G', 'g') and self.t[self.i + 1][1] == '_':
            self.take()
            self.take()
            sub = self.script()
            base = G(sub, 1 if text == 'G' else -1)
        else:
            base = self.primary()
        while True:
            kind, text = self.peek()
            if text == '^':
                self.take()
                base = power(base, self.script())
            elif text == '_':
                raise Skip('subscript')
            elif text == "'":
                raise Skip('prime')
            else:
                return base

    def group(self):
        kind, text = self.take()
        close = OPEN[text]
        v = self.expr()
        kind, text = self.take()
        if text != close:
            raise Skip('expected %s, got %r' % (close, text))
        return v

    def ident(self, text):
        if text == 'pi':
            return PI
        if text == 'e':
            return D(1).exp()
        if text == 'n':
            return N_SAMPLE
        raise Skip('free variable %s' % text)

    def primary(self):
        kind, text = self.peek()
        if kind == 'num':
            self.take()
            return D(text)
        if text in OPEN:
            return self.group()
        if kind == 'id':
            self.take()
            if text == 'sqrt':
                return self.group().sqrt()
            if text == 'log':
                return self.group().ln()
            if text == 'Gamma':
                return D(repr(math.gamma(float(self.group()))))
            return self.ident(text)
        raise Skip('primary %r' % (text,))


def power(base, exp):
    if exp == exp.to_integral_value():
        return base ** int(exp)
    if base <= 0:
        raise Skip('root of a negative number')
    return (exp * base.ln()).exp()


def top_split(src, seps, opens='({[', closes=')}]'):
    """Split at top-level occurrences of any separator string."""
    out = []
    depth = 0
    cur = ''
    i = 0
    while i < len(src):
        c = src[i]
        if c in opens:
            depth += 1
        elif c in closes:
            depth -= 1
        hit = None
        if depth == 0:
            for sep in seps:
                if src.startswith(sep, i):
                    hit = sep
                    break
        if hit:
            out.append(cur)
            cur = ''
            i += len(hit)
        else:
            cur += c
            i += 1
    out.append(cur)
    return out


def clean(src):
    src = re.sub(r'stretch\(bracket\.l, size: #\d+%\)', '[', src)
    src = re.sub(r'stretch\(bracket\.r, size: #\d+%\)', ']', src)
    src = re.sub(r'stretch\(brace\.l, size: #\d+%\)', '{', src)
    src = re.sub(r'stretch\(brace\.r, size: #\d+%\)', '}', src)
    src = re.sub(r'#hide\(\$[^$]*\$\)', '', src)
    while 'display(' in src:
        i = src.index('display(')
        j = i + len('display(')
        depth = 1
        while depth:
            if src[j] == '(':
                depth += 1
            elif src[j] == ')':
                depth -= 1
            j += 1
        src = src[:i] + src[i + len('display('):j - 1] + src[j:]
    src = src.replace('sqrt("")', 'sqrt')
    return src


def statements(src):
    src = clean(src)
    mc = re.match(r'cases\(reverse: #true, gap: #0\.9em, (.*)\)(,?)$', src)
    if mc:
        lines = top_split(mc.group(1), [', '], '(', ')')
    else:
        lines = top_split(src, [' \\ '], '(', ')')
    merged = []
    for line in lines:
        line = line.replace('&', ' ').strip()
        line = re.sub(r'^(quad\s+)+', '', line)
        starts = re.match(r'(=|\+|-|times)', line)
        has_eq = len(top_split(line, ['='])) > 1
        if merged and (starts or not has_eq):
            merged[-1] += ' ' + line
        else:
            merged.append(line)
    out = []
    for line in merged:
        for part in top_split(line, [', quad', ' comma quad', ',  quad']):
            part = part.strip()
            part = re.sub(r',\s*[(\[]q = .*$', '', part)
            part = re.sub(r'(\s*(comma|[,.;]))+$', '', part).strip()
            if part:
                out.append(part)
    return out


def value(side):
    """Value of one side and how exact it claims to be."""
    side = side.strip()
    note = 'exact'
    md = re.match(r'^(\d*\.\d+) dots\.h$', side)
    if md:
        digits = len(md.group(1).split('.')[1])
        return D(md.group(1)), ('digits', digits)
    ms = re.match(r'^(.*\S)\s*([+-])\s*dots\.c$', side)
    if ms:
        side = ms.group(1)
        note = 'series'
    if 'dots.c' in side:
        side = re.sub(r'[+-]\s*dots\.c', '', side).replace('dots.c', '')
        note = 'series'
    if 'dots' in side:
        raise Skip('dots inside')
    parser = Parser(tokenize(side))
    v = parser.expr()
    if parser.i != len(parser.t):
        raise Skip('trailing %r' % (parser.peek()[1],))
    return v, note


def main(path):
    counts = {'exact': 0, 'approx': 0, 'skip': 0, 'bad': 0}
    seen = set()
    for row in open(path, encoding='utf8'):
        kind, src = row.rstrip('\n').split('\t', 1)
        for st in statements(src):
            if st in seen:
                continue
            seen.add(st)
            sides = top_split(st, ['='])
            if len(sides) < 2 or sides[0].strip() in ('n', 'k', 'q', 'u', 'v'):
                continue
            try:
                vals = [value(s) for s in sides]
            except Skip as why:
                counts['skip'] += 1
                if '-v' in sys.argv:
                    print('skip  [%s] %s  (%s)' % (kind, st[:90], why))
                continue
            except Exception as why:
                counts['skip'] += 1
                print('ERROR [%s] %s  (%r)' % (kind, st[:90], why))
                continue
            ref, _ = vals[0]
            worst = D(0)
            claim = 'exact'
            for v, note in vals[1:] + vals[:1]:
                if note != 'exact':
                    claim = note
                diff = abs(v - ref)
                rel = diff / max(abs(ref), D(10) ** -50)
                worst = max(worst, rel)
            if isinstance(claim, tuple):
                # a decimal expansion: the digits shown must be the first ones
                digits = claim[1]
                shown = [v for v, note in vals if isinstance(note, tuple)][0]
                other = [v for v, note in vals if not isinstance(note, tuple)][0]
                # (truncated, not rounded: 3.14160 is not how pi begins)
                excess = other - shown if shown >= 0 else shown - other
                ok = 0 <= excess < D(10) ** -digits
                tag = 'ok   ' if ok else 'BAD  '
                counts['exact' if ok else 'bad'] += 1
                if not ok or '-v' in sys.argv:
                    print('%s [%s] %s  (value %s)' % (tag, kind, st[:100], str(other)[:digits + 6]))
            elif worst < D(10) ** -40:
                counts['exact'] += 1
                if '-v' in sys.argv:
                    print('ok    [%s] %s' % (kind, st[:100]))
            else:
                counts['approx'] += 1
                print('diff %.2e (%s) [%s] %s' % (worst, claim, kind, st[:150]))
    print(counts)


main(sys.argv[1])
