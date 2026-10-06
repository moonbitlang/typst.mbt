#!/usr/bin/env python3
"""Make the promotion of impl methods explicit.

MoonBit is retiring the rule that makes the methods of `impl Trait for T`
callable as methods of `T` (`x.m()`, `T::m()`). Every public impl, and every
trait derived for a public type, needs a `pub extend T with Trait::{..}` that
names its methods (the compiler reports the ones that lack it as
`implicit_impl_as_method`). The rule of this repository:

- the declaration sits directly after the impl (after the type, for a
  derive), one declaration per trait;
- if code calls a method of the impl through the type, the declaration is
  plain, and the methods are methods of the type;
- otherwise it is

      #deprecated("<MESSAGE>")
      #doc(hidden)
      pub extend T with Trait::{..}

  so that a call through the type, in any package, is a warning.

This script inserts the declarations that are missing. It works in a
throwaway copy of the checkout to find them (the checkout is only changed by
the insertion itself, which also puts the declarations after a `derive(..)`
in the order of its list):

    scripts/promotions.py [--only=pkg,pkg] [--dry] [--jobs N]

1. copy; remove moon.mod's `-implicit_impl_as_method`; `moon check` on
   native, wasm-gc and wasm lists the impls without a complete `extend`;
2. give each a hidden `extend` deprecated with a tag; a second `moon check`
   reports the tag at every call through the type, in every package: those
   impls get the plain form, the others the deprecated one;
3. insert into the checkout, for the packages of `--only` (default: all).
   Impls in `*_gen.mbt` are listed instead: their generator must emit the
   declaration.

Besides the declarations, the checkout changes in two ways: a trait of a core
package that the package does not import yet (`@debug.Debug` for a derived
`Debug`) gets its import added to the package's `moon.pkg`, and `--save FILE`
writes the analysis of steps 1 and 2 to `FILE` (`--load FILE` reuses it).
Traits of other packages are spelled with the alias of the package's import.

A method name can be a method of a type only once, so where a name is shared
one declaration must leave it out (with a comment that says who has it):

- a regular method of the type wins: the `extend` leaves the name out;
- between two impls of a type, the one whose method upstream calls as a
  method of the type names it (`UPSTREAM_METHOD` below, with the upstream
  reference);
- if neither or both: a core trait (`Show`, `Eq`, ..) yields to a trait of
  the port;
- only then: the impl that comes first in the file.
"""
import argparse
import collections
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SWITCH = 'warnings = "-implicit_impl_as_method"\n'
TARGETS = ["native", "wasm-gc", "wasm"]
TAG = "PROMOTION-PROBE"
PROBE = "zz_promotion_probe%s.mbt"

# (package, method) -> the trait whose method upstream calls as a method of
# the type; it names the method where another impl of the type has one of the
# same name.
UPSTREAM_METHOD = {
    # `T::output()` of `Reflect` (typst-library/src/foundations/cast.rs:38,
    # called as a method of the type throughout, e.g. :80); MoonBit's
    # `Show::output` has no upstream counterpart (`Display::fmt`).
    ("library", "output"): "Reflect",
}

# Traits of core that a package can name without a package prefix.
BUILTIN_TRAITS = {
    "Eq", "Compare", "Hash", "Show", "Default", "ToJson", "Logger", "Add", "Sub", "Mul", "Div",
    "Mod", "Neg", "BitAnd", "BitOr", "BitXOr", "Shl", "Shr",
}


# The methods of the core traits (the port's traits are read from the source).
CORE_METHODS = {
    "Eq": ["not_equal", "equal"],
    "Hash": ["hash", "hash_combine"],
    "Compare": ["op_lt", "op_le", "op_ge", "compare", "op_gt"],
    "Show": ["to_string", "output"],
    "Default": ["default"],
    "Debug": ["to_repr"],
    "Add": ["add"],
    "Sub": ["sub"],
    "Mul": ["mul"],
    "Div": ["div"],
    "Neg": ["neg"],
    "BitOr": ["lor"],
}

_sources = {}


def package_source(pkg):
    """The text of the package's files, by file name."""
    if pkg not in _sources:
        out = {}
        d = os.path.join(ROOT, pkg)
        for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
            if f.endswith(".mbt") and not f.startswith("zz_promotion_probe"):
                out[f] = open(os.path.join(d, f), encoding="utf-8").read()
        _sources[pkg] = out
    return _sources[pkg]


def trait_methods(it):
    """All method names of the impl's trait, or None where they are unknown."""
    full = it.get("full_trait", it["trait"])
    name = full.split(".")[-1]
    if is_core_trait(it):
        return CORE_METHODS.get(name)
    pkg = os.path.dirname(it["path"])
    m = re.match(r"@([\w/]+)\.", full)
    if m:
        parts = m.group(1).split("/")
        while parts and not os.path.isdir(os.path.join(ROOT, *parts)):
            parts.pop(0)
        pkg = "/".join(parts)
    for text in package_source(pkg).values():
        m = re.search(r"^(?:pub(?:\(\w+\))? |priv )?trait %s\b[^{]*\{\n(.*?)^\}" % re.escape(name), text, re.M | re.S)
        if m:
            return re.findall(r"^  (?:async )?(?:fn )?(\w+)(?:\[[^\]]*\])?\(", m.group(1), re.M)
    return None


def absent_names(it, suggested):
    """The methods of the impl that the compiler does not ask for: something
    else already makes the name a method of the type. Returns (`left_out`
    entries for names that the `extend` of another trait has, names of regular
    methods, names that an older `extend` of the same trait has)."""
    left_out, regular, partial = [], [], []
    pkg = os.path.dirname(it["path"])
    short = it["trait"].split(".")[-1]
    for m in trait_methods(it) or []:
        if m in suggested:
            continue
        other = None
        for text in package_source(pkg).values():
            for x in re.finditer(r"^pub extend %s with ([@\w./]+)::\{([^}]*)\}" % re.escape(it["ty"]), text, re.M):
                if m in [n.strip() for n in x.group(2).split(",")]:
                    other = x.group(1).split(".")[-1]
        if other == short:
            partial.append(m)
        elif other:
            left_out.append((m, other))
        else:
            regular.append(m)
    return left_out, regular, partial


def is_core_trait(it):
    full = it.get("full_trait", it["trait"])
    return full.startswith(("@builtin.", "@moonbitlang/core/")) or full in BUILTIN_TRAITS


def message(trait):
    short = trait.split(".")[-1]
    return "call as `%s::m(x)`, or un-deprecate this `extend` to make it a method" % short


def deprecated_extend(ty, trait, methods):
    """The declaration, as a block of MoonBit source, of an impl whose methods
    are not methods of the type (for generators that emit public impls or
    derives; `trait` as the generated file names it, e.g. `@debug.Debug`)."""
    return '///|\n#deprecated("%s")\n#doc(hidden)\npub extend %s with %s::{%s}\n' % (
        message(trait), ty, trait, ", ".join(methods))


def copy_checkout(dst):
    files = subprocess.run(["git", "-C", ROOT, "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
                           check=True, capture_output=True).stdout.decode().split("\0")
    files += ["typst_assets/fonts/fonts_gen.c", "typst_assets/fonts/fonts_wasm_gen.mbt"]
    for f in files:
        src = os.path.join(ROOT, f)
        if not f or not os.path.isfile(src):
            continue
        out = os.path.join(dst, f)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        shutil.copy2(src, out)


def check(copy, target, jobs):
    r = subprocess.run(["moon", "check", "--target", target, "-j", str(jobs), "--output-json"],
                       cwd=copy, capture_output=True, text=True)
    out = []
    seen = set()
    real = os.path.realpath(copy)
    for line in r.stdout.split("\n"):
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if d.get("$message_type") != "diagnostic":
            continue
        path = os.path.relpath(os.path.realpath(d["path"]), real) if d.get("path") else ""
        loc = d["loc"]
        if isinstance(loc, dict):
            sl, sc = loc["start"]["line"], loc["start"]["col"]
        else:
            sl, sc = (int(x) for x in loc.split("-")[0].split(":"))
        key = (path, sl, sc, d["error_code"], d["message"])
        if key in seen:
            continue
        seen.add(key)
        out.append({"path": path, "line": sl, "col": sc, "code": d["error_code"],
                    "level": d["level"], "message": d["message"]})
    if r.returncode != 0 and not any(d["level"] == "error" for d in out):
        sys.exit("promotions: `moon check --target %s` failed without a diagnostic:\n%s" % (
            target, (r.stderr or r.stdout)[-2000:]))
    return out


_aliases = {}


def aliases(pkg):
    """Package path -> the alias under which `pkg` imports it (main block)."""
    if pkg in _aliases:
        return _aliases[pkg]
    out = {}
    try:
        text = open(os.path.join(ROOT, pkg, "moon.pkg")).read()
    except OSError:
        text = ""
    m = re.search(r"^import \{\n((?:  [^\n]*\n)*)\}\n", text, re.M)
    for path, alias in re.findall(r'"([^"]+)"(?:\s+@(\w+))?', m.group(1) if m else ""):
        out[path] = alias or path.split("/")[-1]
    _aliases[pkg] = out
    return out


def spell(trait, pkg):
    """The compiler names a trait of another package by the full package
    path; the declaration uses the alias of the package's import (core
    packages that are not imported yet get their default alias, and the
    import is added)."""
    m = re.match(r"@([\w/]+)\.(\w+)$", trait)
    if not m or m.group(1) == "builtin":
        return trait
    path, name = m.groups()
    alias = aliases(pkg).get(path)
    if alias is None and path.startswith("moonbitlang/core/"):
        alias = path.split("/")[-1]
    return "@%s.%s" % (alias, name) if alias else trait


def find_impls(copy, jobs):
    """The impls without a complete `extend`, over all targets."""
    impls = {}
    for target in TARGETS:
        diags = check(copy, target, jobs)
        errors = [d for d in diags if d["level"] == "error"]
        if errors:
            sys.exit("promotions: the checkout does not check on %s: %s:%d %s" % (
                target, errors[0]["path"], errors[0]["line"], errors[0]["message"][:200]))
        for d in diags:
            if d["code"] != 79:
                continue
            m = re.search(r"The methods (.+?) from `impl (.+?) for (.+?)` are", d["message"])
            m2 = re.search(r"Add a `pub extend (.+?) with (.+?)::\{(.+?)\}` declaration", d["message"])
            if not m or not m2:
                sys.exit("promotions: unexpected message: " + d["message"][:200])
            key = (d["path"], d["line"], d["col"])
            trait = spell(m2.group(2), os.path.dirname(d["path"]))
            full = m2.group(2)
            impls.setdefault(key, {
                "path": d["path"], "line": d["line"], "col": d["col"],
                "ty": m2.group(1), "trait": trait, "full_trait": full,
                "methods": [x.strip() for x in m2.group(3).split(",")],
                "targets": [],
            })["targets"].append(target)
    out = sorted(impls.values(), key=lambda it: (it["path"], it["line"], it["col"]))
    # A name is a method of a type once: see the rule in the docstring.
    sharers = collections.defaultdict(list)
    for it in out:
        pkg = os.path.dirname(it["path"])
        for m in it["methods"]:
            sharers[(pkg, it["ty"], m)].append(it)
        it["left_out"], it["clash"], it["partial"] = absent_names(it, it["methods"])

    def rank(it, m):
        pkg = os.path.dirname(it["path"])
        upstream = UPSTREAM_METHOD.get((pkg, m)) == it["trait"].split(".")[-1]
        return (0 if upstream else 1, 1 if is_core_trait(it) else 0, it["path"], it["line"], it["col"])

    for (pkg, ty, m), items in sharers.items():
        if len(items) < 2:
            continue
        winner = min(items, key=lambda it: rank(it, m))
        for it in items:
            if it is not winner:
                it["methods"].remove(m)
                it["left_out"].append((m, winner["trait"]))
    for i, it in enumerate(out):
        it["id"] = i
    return out


def write_probes(copy, impls):
    for d, _, files in os.walk(copy):
        for f in files:
            if f.startswith("zz_promotion_probe"):
                os.remove(os.path.join(d, f))
    per_file = collections.defaultdict(list)
    for it in impls:
        it.pop("probe", None)
        if not it["probe_methods"]:
            continue
        pkg = os.path.dirname(it["path"])
        base = os.path.basename(it["path"])
        kind = "_wbtest" if base.endswith("_wbtest.mbt") else ("_test" if base.endswith("_test.mbt") else "")
        per_file[os.path.join(pkg, PROBE % kind)].append(it)
    for rel, items in per_file.items():
        lines = []
        for it in items:
            lines += ["///|", "#doc(hidden)", '#deprecated("%s|%d")' % (TAG, it["id"])]
            it["probe"] = (rel, len(lines) + 1)
            lines += ["pub extend %s with %s::{%s}" % (it["ty"], it["probe_trait"], ", ".join(it["probe_methods"])), ""]
        with open(os.path.join(copy, rel), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")


def find_calls(copy, impls, jobs):
    """Marks each impl with the number of calls through the type."""
    for it in impls:
        it["probe_methods"] = list(it["methods"])
        it["probe_trait"] = it["trait"]
        it["calls"] = []
    for attempt in range(12):
        write_probes(copy, impls)
        all_diags = []
        errors = []
        for target in TARGETS:
            diags = check(copy, target, jobs)
            all_diags += diags
            errors += [d for d in diags if d["level"] == "error"]
        if not errors:
            break
        by_loc = {it["probe"]: it for it in impls if "probe" in it}
        fixed = 0
        real = os.path.realpath(copy)
        for d in errors:
            it = by_loc.get((d["path"], d["line"]))
            if it is None:
                m = re.search(r"defined at (\S*?zz_promotion_probe\w*\.mbt):(\d+)", d["message"])
                if m:
                    it = by_loc.get((os.path.relpath(os.path.realpath(m.group(1)), real), int(m.group(2))))
            if it is None:
                continue
            m = re.search(r"The method (\w+) for type", d["message"])
            if m and m.group(1) in it["probe_methods"]:
                it["probe_methods"].remove(m.group(1))
                it.setdefault("clash", []).append(m.group(1))
                fixed += 1
                continue
            m = re.search(r"The type (\w+) is not a trait", d["message"])
            if m and not it["probe_trait"].startswith("@"):
                it["probe_trait"] = "@builtin." + it["probe_trait"]
                it["trait"] = it["probe_trait"]
                fixed += 1
        if not fixed:
            sys.exit("promotions: the probe declarations do not check: %s:%d %s" % (
                errors[0]["path"], errors[0]["line"], errors[0]["message"][:300]))
    else:
        sys.exit("promotions: the probe declarations still clash after 12 rounds")
    by_id = {it["id"]: it for it in impls}
    seen = set()
    for d in all_diags:
        msg = re.sub(r"^Warning \(\w+\): ", "", d["message"]).strip()
        if not msg.startswith(TAG + "|") or os.path.basename(d["path"]).startswith("zz_promotion_probe"):
            continue
        site = "%s:%d:%d" % (d["path"], d["line"], d["col"])
        if site in seen:
            continue
        seen.add(site)
        by_id[int(msg.split("|")[1])]["calls"].append(site)
    # core packages that the declarations name and the package does not import
    need_import = collections.defaultdict(set)
    for it in impls:
        m = re.match(r"@moonbitlang/core/(\w+)\.", it.get("full_trait", ""))
        pkg = os.path.dirname(it["path"])
        if m and "moonbitlang/core/" + m.group(1) not in aliases(pkg):
            need_import[pkg].add("moonbitlang/core/" + m.group(1))
    return need_import


def declaration(it):
    lines = []
    # A name can be a method of a type once.
    for m, trait in it["left_out"]:
        lines.append("// `%s` is not named here: the `extend` of `%s` makes it a method of the type." % (
            m, trait.split(".")[-1]))
    for m in it.get("clash", []):
        lines.append("// `%s` is not named here: the type already has a method of this name." % m)
    if it.get("partial"):
        # One declaration per trait: merge the two by hand.
        print("NOTE %s:%d: an older `extend` of `%s` for `%s` names %s" % (
            it["path"], it["line"], it["trait"], it["ty"], ", ".join(it["partial"])))
    if not it["calls"]:
        lines.append('#deprecated("%s")' % message(it["trait"]))
        lines.append("#doc(hidden)")
    methods = [m for m in it["methods"] if m not in it.get("clash", [])]
    lines.append("pub extend %s with %s::{%s}" % (it["ty"], it["trait"], ", ".join(methods)))
    return lines, methods


def insert(impls, only, dry):
    todo = collections.defaultdict(list)
    generated = []
    for it in impls:
        pkg = os.path.dirname(it["path"])
        if only is not None and pkg not in only:
            continue
        if it["path"].endswith("_gen.mbt"):
            generated.append(it)
        else:
            todo[it["path"]].append(it)
    n_plain = n_dep = n_meth = 0
    for f, items in sorted(todo.items()):
        path = os.path.join(ROOT, f)
        lines = open(path, encoding="utf-8").read().split("\n")
        starts = [i for i, l in enumerate(lines) if l == "///|"]

        def next_start(i):
            later = [s for s in starts if s > i]
            return later[0] if later else len(lines)

        inserts = []
        for it in items:
            b = max(s for s in starts if s <= it["line"] - 1)
            e = next_start(b)
            if lines[it["line"] - 1][it["col"] - 1:].startswith(("impl", "pub impl")):
                head = re.compile(r"^(?:pub )?impl(?:\[[^\]]*\])? (?:@[\w/]+\.)?%s for %s\b" % (
                    re.escape(it["trait"].split(".")[-1]), re.escape(it["ty"])))
                while e < len(lines):
                    body = [l for l in lines[e + 1:next_start(e)] if l and not l.startswith(("//", "#"))]
                    if body and head.match(body[0]):
                        e = next_start(e)
                    else:
                        break
            while e - 1 > b and (lines[e - 1].strip() == "" or lines[e - 1].lstrip().startswith("//")) \
                    and not lines[e - 1].startswith("///|"):
                e -= 1
            inserts.append((e, it))
        # same position: keep source order (derive order) top to bottom
        for e, it in sorted(inserts, key=lambda x: (-x[0], -x[1]["line"], -x[1]["col"])):
            decl, methods = declaration(it)
            if not methods:
                continue
            lines[e:e] = ["", "///|"] + decl + [""]
            n_meth += len(methods)
            if it["calls"]:
                n_plain += 1
            else:
                n_dep += 1
        lines = order_derive_groups(lines)
        if not dry:
            open(path, "w", encoding="utf-8").write("\n".join(lines))
    return n_plain, n_dep, n_meth, generated


def order_derive_groups(lines):
    """After a type with `derive(A, B, ..)`, the declarations of its derived
    traits follow in the order of that list (declarations of other traits of
    the type that sit in the same run keep their place after them)."""
    starts = [i for i, l in enumerate(lines) if l == "///|"] + [len(lines)]
    blocks = [lines[starts[i]:starts[i + 1]] for i in range(len(starts) - 1)]
    head = lines[:starts[0]]

    def extend_of(block):
        for l in block:
            m = re.match(r"pub extend (\w+) with ([@\w./]+)::\{", l)
            if m:
                return m.group(1), m.group(2).split(".")[-1]
            if l and not l.startswith(("///|", "#", "//")):
                return None
        return None

    def derived_type(block):
        text = "\n".join(block)
        m = re.search(r"^(?:pub(?:\([a-z]+\))? |priv )?(?:struct|enum|suberror|type) (\w+)", text, re.M)
        d = re.search(r"\bderive\(([^)]*)\)\s*$", text.rstrip())
        if not m or not d:
            return None
        return m.group(1), [x.strip().split(".")[-1].split("(")[0] for x in d.group(1).split(",")]

    i = 0
    while i < len(blocks):
        dt = derived_type(blocks[i])
        if dt:
            ty, order = dt
            j = i + 1
            while j < len(blocks) and (extend_of(blocks[j]) or (None,))[0] == ty:
                j += 1
            run = blocks[i + 1:j]
            if len(run) > 1:
                def key(item):
                    k, block = item
                    trait = extend_of(block)[1]
                    return (order.index(trait) if trait in order else len(order), k)
                # the last block of the run carries the spacing to what follows
                tails = [len(b) - len("\n".join(b).rstrip("\n").split("\n")) for b in run]
                bodies = [b[:len(b) - t] if t else b for b, t in zip(run, tails)]
                ordered = [b for _, b in sorted(enumerate(bodies), key=key)]
                blocks[i + 1:j] = [b + [""] * t for b, t in zip(ordered, tails)]
            i = j
        else:
            i += 1
    out = list(head)
    for b in blocks:
        out += b
    return out


def add_imports(need_import, only, dry):
    """Adds the core packages that the declarations name (`@debug.Debug`) to
    the package's main import block."""
    done = []
    for pkg, names in sorted(need_import.items()):
        if only is not None and pkg not in only:
            continue
        p = os.path.join(ROOT, pkg, "moon.pkg")
        s = open(p).read() if os.path.exists(p) else ""
        for name in sorted(names):
            m = re.search(r"^import \{\n((?:  [^\n]*\n)*)\}\n", s, re.M)
            if m and '"%s"' % name in m.group(1):
                continue
            if m:
                s = s[:m.end(1)] + '  "%s",\n' % name + s[m.end(1):]
            else:
                s = 'import {\n  "%s",\n}\n\n' % name + s
            done.append((pkg, name))
        if not dry:
            open(p, "w").write(s)
    return done


def main():
    global ROOT
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--only", help="comma separated package paths (default: all)")
    ap.add_argument("--dry", action="store_true", help="report only")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    ap.add_argument("--keep", action="store_true", help="keep the copy and print its path")
    ap.add_argument("--save", help="write the analysis (impls and their calls) to this file")
    ap.add_argument("--load", help="use a saved analysis instead of analysing (the files of the "
                    "packages to insert into must be unchanged since)")
    ap.add_argument("--list-generated", action="store_true",
                    help="print the declarations for impls in generated files")
    ap.add_argument("--root", default=ROOT, help=argparse.SUPPRESS)
    args = ap.parse_args()
    ROOT = os.path.abspath(args.root)
    only = set(args.only.split(",")) if args.only else None

    if args.load:
        saved = json.load(open(args.load))
        impls = saved["impls"]
        need_import = {k: set(v) for k, v in saved["need_import"].items()}
    else:
        copy = tempfile.mkdtemp(prefix="promotions-")
        try:
            copy_checkout(copy)
            mod = os.path.join(copy, "moon.mod")
            text = open(mod).read()
            open(mod, "w").write(text.replace(SWITCH, ""))
            impls = find_impls(copy, args.jobs)
            need_import = find_calls(copy, impls, args.jobs)
        finally:
            if args.keep:
                print("copy kept at", copy)
            else:
                shutil.rmtree(copy, ignore_errors=True)
        for it in impls:
            it.pop("probe", None)
    if args.save:
        json.dump({"impls": impls, "need_import": {k: sorted(v) for k, v in need_import.items()}},
                  open(args.save, "w"), indent=1)
    total = len(impls)
    called = sum(1 for it in impls if it["calls"])
    print("impls without a complete `extend`: %d (%d called through the type)" % (total, called))
    n_plain, n_dep, n_meth, generated = insert(impls, only, args.dry)
    imports = add_imports(need_import, only, args.dry)
    print("%s: %d plain and %d deprecated declarations (%d methods)" % (
        "would insert" if args.dry else "inserted", n_plain, n_dep, n_meth))
    for pkg, name in imports:
        print("import added: %s <- %s" % (pkg, name))
    by_gen = collections.Counter(it["path"] for it in generated)
    for path, n in sorted(by_gen.items()):
        print("GENERATED %s: %d impls; its generator must emit the declarations" % (path, n))
    if args.list_generated:
        for it in generated:
            print("  %s:%d %s" % (it["path"], it["line"], "\n      ".join(declaration(it)[0])))


if __name__ == "__main__":
    main()
