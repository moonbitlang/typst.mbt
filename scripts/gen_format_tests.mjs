#!/usr/bin/env node
// Generates the reference tables of `doc/format`'s tests:
//
//   node scripts/gen_format_tests.mjs
//
// writes `doc/format/js_cases_test.mbt` and
// `doc/format/decimal_cases_wbtest.mbt` (run `moon fmt` afterwards; the
// output is deterministic, the random inputs come from a seeded generator).
//
// Two references are used, and checked against each other here:
//
// - JavaScript itself: `Number.prototype.toFixed` for every finite input
//   below 1e21 (`fixed`, and `grouped` with the separators put into its
//   result), `BigInt.prototype.toLocaleString("en-US")` for `grouped_int`.
// - `exactRound` below: the rounding contract of the package written with
//   BigInt fractions (round half away from zero of the exact value of the
//   double times a power of ten). It is the reference where JavaScript has
//   no function for the contract: values of 1e21 and above (where `toFixed`
//   switches to exponent notation), `percent` (the exact value times 100,
//   not the double `100 * x`), `compact`, and the exact decimal expansions.
//   The package does not divide big integers (it expands the double in
//   decimal and rounds the digits), so this is a second method, not a copy.
//
// The script fails if `exactRound` and `toFixed` disagree on any input
// below 1e21; it prints the counts it compared.
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

// --- doubles -----------------------------------------------------------------

const view = new DataView(new ArrayBuffer(8));

function bitsOf(x) {
  view.setFloat64(0, x);
  return view.getBigUint64(0);
}

function fromBits(bits) {
  view.setBigUint64(0, bits);
  return view.getFloat64(0);
}

function hex(x) {
  return '0x' + bitsOf(x).toString(16).padStart(16, '0') + 'UL';
}

function nextUp(x) {
  return fromBits(bitsOf(x) + 1n);
}

function nextDown(x) {
  return fromBits(bitsOf(x) - 1n);
}

// |x| = m × 2^e with integers m, e.
function decompose(x) {
  const bits = bitsOf(Math.abs(x));
  const biased = Number((bits >> 52n) & 0x7ffn);
  const fraction = bits & ((1n << 52n) - 1n);
  return biased === 0
    ? { m: fraction, e: -1074 }
    : { m: fraction | (1n << 52n), e: biased - 1075 };
}

// The integer nearest to |x| × 10^scale, a tie going to the larger one.
function exactRound(x, scale) {
  const { m, e } = decompose(x);
  let num = m;
  let den = 1n;
  if (e >= 0) num <<= BigInt(e);
  else den <<= BigInt(-e);
  if (scale >= 0) num *= 10n ** BigInt(scale);
  else den *= 10n ** BigInt(-scale);
  return (2n * num + den) / (2n * den);
}

// The integer `n` with its last `digits` digits as decimals and `sep`
// between groups of three digits of the integer part.
function place(n, digits, sep) {
  let s = n.toString().padStart(digits + 1, '0');
  let whole = s.slice(0, s.length - digits);
  const frac = s.slice(s.length - digits);
  if (sep !== '') whole = whole.replace(/\B(?=(\d{3})+(?!\d))/g, sep);
  return digits > 0 ? whole + '.' + frac : whole;
}

function sign(x) {
  return x < 0 ? '-' : '';
}

function refFixed(x, digits) {
  return sign(x) + place(exactRound(x, digits), digits, '');
}

function refGrouped(x, digits, sep) {
  return sign(x) + place(exactRound(x, digits), digits, sep);
}

function refPercent(x, digits) {
  return sign(x) + place(exactRound(x, digits + 2), digits, '') + '%';
}

function refCompact(x, digits) {
  const units = ['', 'k', 'M', 'B'];
  for (let unit = 0; ; unit++) {
    const n = exactRound(x, digits - 3 * unit);
    if (unit === units.length - 1 || n < 10n ** BigInt(digits + 3)) {
      return sign(x) + place(n, digits, '') + units[unit];
    }
  }
}

// --- inputs ------------------------------------------------------------------

// mulberry32
let state = 0x2545f491;
function rand32() {
  state = (state + 0x6d2b79f5) | 0;
  let t = state;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return (t ^ (t >>> 14)) >>> 0;
}
function rand() {
  return rand32() / 4294967296;
}
function randInt(n) {
  return Math.floor(rand() * n);
}
function randBits() {
  return (BigInt(rand32()) << 32n) | BigInt(rand32());
}
function randSign() {
  return rand() < 0.3 ? -1 : 1;
}

const DIGITS = [0, 1, 2, 3, 4, 6, 10, 15, 17, 20];

// (x, digits) pairs.
const pairs = [];
function add(x, digits) {
  if (Number.isFinite(x)) pairs.push([x, digits]);
}

// The well-known cases and the edges of the format.
const edges = [
  0, -0, 1, -1, 0.5, -0.5, 1.5, -1.5, 2.5, -2.5, 3.5, 0.25, 0.75, 0.125, 0.375,
  0.05, 0.15, 0.25, 0.35, 0.45, 0.55, 0.65, 0.75, 0.85, 0.95,
  1.005, 1.015, 1.025, 1.045, 1.255, 2.675, 8.345, 8.575, 10.235, 1.45, 1.55,
  0.045, 0.145, 0.285, 0.575, 0.615, 4.35, 0.1, 0.2, 0.3, 0.1 + 0.2, 0.7, 1.1,
  -0.001, -0.004, -0.005, -0.006, -0.049, -0.05, 0.001, 0.004, 0.005, 0.006,
  0.049, 0.0001, 0.00049, 0.0005, 0.00051,
  9.5, 9.95, 9.995, 99.5, 99.95, 99.995, 999.5, 999.95, 999.995, 0.9995,
  0.99995, 9999.5, 99999.5, 999999.5, 0.999999999999,
  123.456, -123.456, 1234.5678, 1234567.891, 0.956, 95.6, 3.14159265358979,
  2 / 3, 1 / 3, 1e-7, 1.5e-7, 1e-10, 1e-20, 1e-21, 5e-21, 1e-100, 1e-300,
  5e-324, 2.2250738585072014e-308, 2.225073858507201e-308,
  4.35, 4.345, 4.355, 1e3, 1e6, 1e9, 1e12, 1e15, 1e16, 1e17, 1e20,
  123456789012345680000, 999999999999999900000, 9.999999999999999e20,
  9007199254740991, 9007199254740992, 9007199254740993, 4503599627370496.5,
  4503599627370495.5, 2251799813685247.8, 1125899906842623.9,
  0.1 + 0.7, 1.0000000000000002, 0.9999999999999999, 0.49999999999999994,
  0.5000000000000001, 1.4999999999999998, 2.4999999999999996,
  1e21, 1.5e21, 1e22, 1e23, 1.2345678901234567e25, 1e100, 1e300,
  1.7976931348623157e308, -1e21, -1e30, 2 ** 70, 2 ** 100 + 2 ** 60,
];
for (const x of edges) {
  for (const d of DIGITS) add(x, d);
}
for (const x of [0, 1, 0.5, 123.456, 1e-7, 5e-324, 1.7976931348623157e308, 1e21, 2 / 3]) {
  for (const d of [50, 99, 100]) add(x, d);
}

// Decimals as a report has them: k / 10^j, rounded to fewer than j
// decimals, half of them ending in 5 (the ones that look like ties).
for (let i = 0; i < 260; i++) {
  const j = 1 + randInt(5);
  let k = randInt(10 ** (j + randInt(4)));
  if (i % 2 === 0) k = k - (k % 10) + 5;
  const x = (randSign() * k) / 10 ** j;
  add(x, randInt(j));
  add(x, j - 1);
}

// Real ties, odd / 2^j at j - 1 decimals, and the doubles next to them.
for (let i = 0; i < 80; i++) {
  const j = 1 + randInt(12);
  const odd = 2 * randInt(2 ** (j + randInt(8))) + 1;
  const x = (randSign() * odd) / 2 ** j;
  add(x, j - 1);
  add(nextUp(x), j - 1);
  add(nextDown(x), j - 1);
  if (j > 1) add(x, j - 2);
}

// Uniform values of several magnitudes.
for (let i = 0; i < 240; i++) {
  const scale = [1, 100, 1e4, 1e6, 1e9, 1e15, 1e-3, 1e-6][i % 8];
  add(randSign() * rand() * scale, DIGITS[randInt(DIGITS.length)]);
}

// Any bit pattern (every exponent, subnormal numbers included).
for (let i = 0; i < 240; i++) {
  add(fromBits(randBits()), DIGITS[randInt(DIGITS.length)]);
}

// --- tables ------------------------------------------------------------------

function str(s) {
  return JSON.stringify(s);
}

const seen = new Set();
const fixedJs = [];
const fixedLarge = [];
const grouped = [];
let groupedSeparated = 0;
let groupedPlain = 0;
let compared = 0;
for (const [x, d] of pairs) {
  const key = hex(x) + '/' + d;
  if (seen.has(key)) continue;
  seen.add(key);
  const ref = refFixed(x, d);
  if (Math.abs(x) < 1e21) {
    const js = x.toFixed(d);
    compared++;
    if (js !== ref) {
      throw new Error(`exactRound differs from toFixed: ${x} at ${d}: ${ref} / ${js}`);
    }
    fixedJs.push(`  (${hex(x)}, ${d}, ${str(js)}),`);
    // Not for the longest ones, and mostly values of a thousand and more
    // (the others have no separator): the table is big enough.
    if (js.length < 40) {
      const parts = js.split('.');
      parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ',');
      const text = parts.join('.');
      if (text !== refGrouped(x, d, ',')) throw new Error(`grouping of ${js}`);
      const separated = text.includes(',');
      if (separated ? groupedSeparated++ < 500 : groupedPlain++ < 100) {
        grouped.push(`  (${hex(x)}, ${d}, ${str(text)}),`);
      }
    }
  } else {
    // An integer: its digits, then zeros.
    const whole = (x < 0 ? '-' : '') + BigInt(Math.abs(x)).toString();
    const text = d > 0 ? whole + '.' + '0'.repeat(d) : whole;
    if (text !== ref) throw new Error(`large value ${x} at ${d}`);
    fixedLarge.push(`  (${hex(x)}, ${d}, ${str(text)}, ${str(x.toFixed(d))}),`);
  }
}

// grouped_int: any Int64, and the edges.
const ints = [
  0n, 1n, -1n, 9n, 10n, 99n, 100n, 999n, 1000n, -999n, -1000n, 9999n, 10000n,
  99999n, 100000n, 999999n, 1000000n, -1000000n, 1234567n, -1234567n,
  2147483647n, -2147483648n, 9223372036854775807n, -9223372036854775808n,
  1000000000000n, -100000000000000000n,
];
for (let i = 0; i < 100; i++) {
  ints.push(BigInt.asIntN(64, randBits()) >> BigInt(randInt(64)));
}
const groupedInt = ints.map(
  n => `  (0x${BigInt.asUintN(64, n).toString(16).padStart(16, '0')}UL, ${str(n.toLocaleString('en-US'))}),`,
);

// percent and compact: the report-like inputs and the edges of the units.
const percent = [];
const percentInputs = [
  0, -0, 0.956, 0.5, 1, 1.5, -0.0412, 0.045, 0.145, 0.285, 0.575, 1.005, 0.0005,
  0.00049, 0.00051, 0.99995, 0.9995, 0.995, 1e-7, 123.456, -0.00001, 2 / 3,
  1 / 3, 0.1 + 0.2, 1e300, 5e-324, 1.7976931348623157e308, 0.07, 0.29, 0.57, 0.58,
];
for (let i = 0; i < 200; i++) {
  const j = 2 + randInt(4);
  percentInputs.push((randSign() * randInt(10 ** j + 1)) / 10 ** j);
}
for (let i = 0; i < 60; i++) percentInputs.push(randSign() * rand());
for (const x of percentInputs) {
  for (const d of [0, 1, 2]) {
    percent.push(`  (${hex(x)}, ${d}, ${str(refPercent(x, d))}),`);
  }
}

const compact = [];
const compactInputs = [
  0, -0, 0.25, 1, 12, 950, 999, 999.4, 999.5, 999.94, 999.95, 999.96, 1000, 1234,
  1500, -1500, 9999, 99999, 999499, 999500, 999949, 999950, 999999, 1e6, 5.4e6,
  999949999, 999950000, 999499999, 999500000, 1e9, 2e9, 2.5e13, 1e12, 1e21, 1e100,
  1.7976931348623157e308, 5e-324, 0.04, 0.05, 0.5, 0.95, -0.04, -999.95, -999950,
  123456, 1234567, 12345678, 123456789, 1234567890, 12345678901,
];
for (let i = 0; i < 200; i++) {
  compactInputs.push(randSign() * Math.floor(rand() * 10 ** (1 + randInt(12))));
}
for (let i = 0; i < 60; i++) {
  compactInputs.push(randSign() * rand() * 10 ** randInt(13));
}
for (const x of compactInputs) {
  for (const d of [0, 1, 2]) {
    compact.push(`  (${hex(x)}, ${d}, ${str(refCompact(x, d))}),`);
  }
}

// Exact decimal expansions: |x| = 0.digits × 10^point.
const decimals = [];
for (const x of [
  1, 0.1, 0.5, 1.005, 123.456, 1e21, 1e23, 5e-324, 2.2250738585072014e-308,
  2.225073858507201e-308, 1.7976931348623157e308, 9007199254740993, 1e-7,
  2 ** -30, 2 ** 29, 2 ** 58, 5 ** 13, 2 ** -13, 2 ** -14, 2 ** -26, 2 ** -27, 1e9,
  1e18, 999999999, 1000000001, 0.3, 1 / 3,
]) {
  const { m, e } = decompose(x);
  const whole = e >= 0 ? m << BigInt(e) : m * 5n ** BigInt(-e);
  const digits = whole.toString();
  decimals.push(`  (${hex(x)}, ${str(digits)}, ${digits.length + Math.min(e, 0)}),`);
}

const header = name =>
  `// Generated by scripts/gen_format_tests.mjs with node ${process.version}; the
// references and the regeneration command are described there. Do not edit.
// ${name}
`;

function table(doc, name, type, rows) {
  return `\n///|\n${doc}\nlet ${name} : ReadOnlyArray[${type}] = [\n${rows.join('\n')}\n]\n`;
}

writeFileSync(
  join(root, 'doc/format/js_cases_test.mbt'),
  header('Doubles are given by their bits.') +
    table(
      "/// `(x, digits, x.toFixed(digits))` for finite `|x| < 1e21`: JavaScript's\n/// own result.",
      'fixed_js_cases',
      '(UInt64, Int, String)',
      fixedJs,
    ) +
    table(
      "/// `(x, digits, expected, x.toFixed(digits))` for `|x| >= 1e21`, where\n/// JavaScript writes an exponent: expected are the digits of the integer\n/// `BigInt(x)` and `digits` zeros.",
      'fixed_large_cases',
      '(UInt64, Int, String, String)',
      fixedLarge,
    ) +
    table(
      '/// `(x, digits, text)`: `x.toFixed(digits)` with "," between groups of\n/// three digits of its integer part.',
      'grouped_cases',
      '(UInt64, Int, String)',
      grouped,
    ) +
    table(
      '/// `(n as bits, n.toLocaleString("en-US"))` for `Int64` values `n`.',
      'grouped_int_cases',
      '(UInt64, String)',
      groupedInt,
    ) +
    table(
      "/// `(x, digits, text)` by the generator's `exactRound`: the exact value of\n/// `x` times 100, half away from zero.",
      'percent_cases',
      '(UInt64, Int, String)',
      percent,
    ) +
    table(
      "/// `(x, digits, text)` by the generator's `exactRound`: the exact value of\n/// `x` in the unit chosen after rounding.",
      'compact_cases',
      '(UInt64, Int, String)',
      compact,
    ),
);

writeFileSync(
  join(root, 'doc/format/decimal_cases_wbtest.mbt'),
  header('Doubles are given by their bits.') +
    table(
      '/// `(x, digits, point)`: `|x|` is exactly `0.digits × 10^point` (BigInt\n/// arithmetic on the mantissa and exponent of the double).',
      'decimal_cases',
      '(UInt64, String, Int)',
      decimals,
    ),
);

console.error(
  `fixed: ${fixedJs.length} cases below 1e21 (toFixed and exactRound agree on all ${compared}), ` +
    `${fixedLarge.length} of 1e21 and above; grouped: ${grouped.length} ` +
    `(${Math.min(groupedSeparated, 500)} with separators); grouped_int: ${groupedInt.length}; ` +
    `percent: ${percent.length}; compact: ${compact.length}; decimal expansions: ${decimals.length}`,
);
