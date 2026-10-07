// Sections 1 to 5: the functions G_n and g_n, and logarithmic
// approximations.

///|
/// The opening of section 1, which the title page sets across both columns.
fn opening() -> Array[Item] {
  [
    wide(sec("If we suppose that")),
    wide(
      eq(
        "(1 + e^(-pi sqrt(n))) (1 + e^(-3 pi sqrt(n))) (1 + e^(-5 pi sqrt(n))) dots.c = 2^(1/4) e^(-pi sqrt(n) slash 24) G_n",
        n=1,
      ),
    ),
    wide(p("and")),
    wide(
      eq(
        "(1 - e^(-pi sqrt(n))) (1 - e^(-3 pi sqrt(n))) (1 - e^(-5 pi sqrt(n))) dots.c = 2^(1/4) e^(-pi sqrt(n) slash 24) g_n,",
        n=2,
      ),
    ),
    wide(
      p(
        (
          $|then \{m("G_n")} and \{m("g_n")} can always be expressed as roots of
          $|algebraical equations when \{m("n")} is any rational number.
        ),
      ),
    ),
  ]
}

///|
fn section_1() -> Array[Item] {
  [
    p("For we know that"),
    eq(
      hang([
        "(1 + q) (1 + q^3) (1 + q^5) dots.h", "= 2^(1/6) q^(1/24) (k k')^(-1/12)",
      ]),
      n=3,
    ),
    p("and"),
    eq(
      hang([
        "(1 - q) (1 - q^3) (1 - q^5) dots.c", "= 2^(1/6) q^(1/24) k^(-1/12) k'^(1/6).",
      ]),
      n=4,
    ),
    p(
      (
        $|Now the relation between the moduli \{m("k")} and \{m("l")}, which
        $|makes
      ),
    ),
    ueq("n (K')/K = (L')/L,"),
    p(
      (
        $|where \{m("n = r slash s")}, \{m("r")} and \{m("s")} being positive
        $|integers, is expressed by the modular equation of the
        $|\{m("r s")}th degree. If we suppose that \{m("k = l'")},
        $|\{m("k' = l")}, so that \{m("K = L'")}, \{m("K' = L")}, then
      ),
    ),
    ueq("q = e^(-pi L' slash L) = e^(-pi sqrt(n)),"),
    p(
      (
        $|and the corresponding value of \{m("k")} may be found by the solution
        $|of an algebraical equation. From \{r(1)}, \{r(2)}, \{r(3)} and
        $|\{r(4)} it may easily be deduced that
      ),
    ),
    eq("g_(4 n) = 2^(1/4) g_n G_n,", n=5),
    eq("G_n = G_(1 slash n), quad 1 slash g_n = g_(4 slash n),", n=6),
    eq("(g_n G_n)^8 (G_n^8 - g_n^8) = 1/4.", n=7),
    p(
      (
        $|I shall consider only integral values of \{m("n")}. It follows from
        $|\{r(7)} that we need consider only one of \{m("G_n")} or
        $|\{m("g_n")} for any given value of \{m("n")}; and from \{r(5)} that
        $|we may suppose \{m("n")} not divisible by 4. It is most convenient to
        $|consider \{m("g_n")} when \{m("n")} is even, and \{m("G_n")} when
        $|\{m("n")} is odd.
      ),
    ),
  ]
}

///|
fn section_2() -> Array[Item] {
  [
    sec(
      (
        $|Suppose then that \{m("n")} is odd. The values of \{m("G_n")} and
        $|\{m("g_(2 n)")} are got from the same modular equation. For example,
        $|let us take the modular equation of the 5th degree, viz.
      ),
    ),
    eq("(u/v)^3 + (v/u)^3 = 2 (u^2 v^2 - 1/(u^2 v^2)),", n=8),
    p("where"),
    ueq("2^(1/4) q^(1/24) u = (1 + q) (1 + q^3) (1 + q^5) dots.c"),
    p("and"),
    ueq("2^(1/4) q^(5/24) v = (1 + q^5) (1 + q^(15)) (1 + q^(25)) dots.c"),
    p(
      (
        $|By changing \{m("q")} to \{m("-q")} the above equation may also be
        $|written as
      ),
    ),
    eq("(v/u)^3 - (u/v)^3 = 2 (u^2 v^2 + 1/(u^2 v^2)),", n=9),
    p("where"),
    ueq("2^(1/4) q^(1/24) u = (1 - q) (1 - q^3) (1 - q^5) dots.c"),
    p("and"),
    ueq("2^(1/4) q^(5/24) v = (1 - q^5) (1 - q^(15)) (1 - q^(25)) dots.c"),
    p(
      (
        $|If we put \{m("q = e^(-pi slash sqrt(5))")} in \{r(8)}, so that
        $|\{m("u = G_(1/5)")} and \{m("v = G_5")}, and hence \{m("u = v")}, we
        $|see that
      ),
    ),
    ueq("v^4 - v^(-4) = 1."),
    p("Hence"),
    ueq("v^4 = (1 + sqrt(5))/2, quad G_5 = ((1 + sqrt(5))/2)^(1/4)."),
    p(
      (
        $|Similarly, by putting \{m("q = e^(-pi sqrt(2/5))")}, so that
        $|\{m("u = g_(2/5)")} and \{m("v = g_(10)")}, and hence
        $|\{m("u = 1 slash v")}, we see that
      ),
    ),
    ueq("v^6 - v^(-6) = 4."),
    p("Hence"),
    ueq("v^2 = (1 + sqrt(5))/2, quad g_(10) = sqrt((1 + sqrt(5))/2)."),
    p("Similarly it can be shewn that"),
    ueq(
      rows([
        "G_9 &= ((1 + sqrt(3))/sqrt(2))^(1/3), quad g_(18) = (sqrt(2) + sqrt(3))^(1/3),",
        "G_(17) &= sqrt(((5 + sqrt(17))/8)) + sqrt(((sqrt(17) - 3)/8)),", "g_(34) &= sqrt(((7 + sqrt(17))/8)) + sqrt(((sqrt(17) - 1)/8)),",
      ]),
    ),
    p("and so on."),
  ]
}

///|
fn section_3() -> Array[Item] {
  [
    sec(
      (
        $|In order to obtain approximations for \{m("pi")} we take logarithms
        $|of \{r(1)} and \{r(2)}. Thus
      ),
    ),
    eq(
      braced([
        "pi = 24/sqrt(n) log(2^(1/4) G_n)", "pi = 24/sqrt(n) log(2^(1/4) g_n)",
      ]) +
      ",",
      n=10,
    ),
    p(
      (
        $|approximately, the error being nearly
        $|\{m("24/sqrt(n) e^(-pi sqrt(n))")} in both cases. These equations
        $|may also be written as
      ),
    ),
    eq(
      rows([
        "e^(pi sqrt(n) slash 24) = 2^(1/4) G_n,", "e^(pi sqrt(n) slash 24) = 2^(1/4) g_n",
      ]),
      n=11,
    ),
    p(
      (
        $|In those cases in which \{m("G_n^(12)")} and \{m("g_n^(12)")} are
        $|simple quadratic surds we may use the forms
      ),
    ),
    ueq("(G_n^(12) + G_n^(-12))^(1/12), quad (g_n^(12) + g_n^(-12))^(1/12),"),
    p("instead of \{m("G_n")} and \{m("g_n")}, for we have"),
    ueq("g_n^(12) = 1/8 e^(1/2 pi sqrt(n)) - 3/2 e^(-1/2 pi sqrt(n)),"),
    p("approximately, and so"),
    ueq(
      "g_n^(12) + g_n^(-12) = 1/8 e^(1/2 pi sqrt(n)) + 13/2 e^(-1/2 pi sqrt(n)),",
    ),
    p("approximately, so that"),
    eq("pi = 2/sqrt(n) log{8 (g_n^(12) + g_n^(-12))},", n=12),
    p(
      (
        $|the error being about \{m("104/sqrt(n) e^(-pi sqrt(n))")}, which is
        $|of the same order as the error in the formulæ \{r(10)}. The formula
        $|\{r(12)} often leads to simpler results. Thus the second of formulæ
        $|\{r(10)} gives
      ),
    ),
    ueq("e^(pi sqrt(18) slash 24) = 2^(1/4) g_(18)"),
    p("or"),
    ueq("e^(1/4 pi sqrt(18)) = 10 sqrt(2) + 8 sqrt(3)."),
    p("But if we use the formula \{r(12)}, or"),
    ueq("e^(pi sqrt(n) slash 24) = 2^(1/4) (g_n^(12) + g_n^(-12))^(1/12),"),
    p("we get a simpler form, viz."),
    ueq("e^(1/8 pi sqrt(18)) = 2 sqrt(7)."),
  ]
}

///|
fn section_4() -> Array[Item] {
  [
    sec(
      (
        $|The values of \{m("g_(2 n)")} and \{m("G_n")} are obtained from the
        $|same equation. The approximation by means of \{m("g_(2 n)")} is
        $|preferable to that by \{m("G_n")} for the following reasons.
      ),
    ),
    p(
      (
        $|(a) It is more accurate. Thus the error when we use \{m("G_(65)")}
        $|contains a factor \{m("e^(-pi sqrt(65))")}, whereas that when we use
        $|\{m("g_(130)")} contains a factor \{m("e^(-pi sqrt(130))")}.
      ),
    ),
    p(
      (
        $|(b) For many values of \{m("n")}, \{m("g_(2 n)")} is simpler in form
        $|than \{m("G_n")}; thus
      ),
    ),
    ueq("g_(130) = sqrt({(2 + sqrt(5)) ((3 + sqrt(13))/2)}),"),
    p("while"),
    ueq(
      hang([
        "G_(65) = {((1 + sqrt(5))/2) ((3 + sqrt(13))/2)}^(1/4)", "times sqrt({sqrt(((9 + sqrt(65))/8)) + sqrt(((1 + sqrt(65))/8))}).",
      ]),
    ),
    p(
      (
        $|(c) For many values of \{m("n")}, \{m("g_(2 n)")} involves quadratic
        $|surds only, even when \{m("G_n")} is a root of an equation of higher
        $|order. Thus \{m("G_(23)")}, \{m("G_(29)")}, \{m("G_(31)")} are roots
        $|of cubic equations, \{m("G_(47)")}, \{m("G_(79)")} are those of
        $|quintic equations, and \{m("G_(71)")} is that of a septic equation,
        $|while \{m("g_(46)")}, \{m("g_(58)")}, \{m("g_(62)")},
        $|\{m("g_(94)")}, \{m("g_(142)")} and \{m("g_(158)")} are all
        $|expressible by quadratic surds.
      ),
    ),
  ]
}

///|
fn section_5() -> Array[Item] {
  [
    sec(
      (
        $|Since \{m("G_n")} and \{m("g_n")} can be expressed as roots of
        $|algebraical equations with rational coefficients, the same is true
        $|of \{m("G_n^(24)")} or \{m("g_n^(24)")}. So let us suppose that
      ),
    ),
    ueq("1 = a g_n^(-24) - b g_n^(-48) + dots.c,"),
    p("or"),
    ueq("g_n^(24) = a - b g_n^(-24) + dots.c ."),
    p("But we know that"),
    wide(
      ueq(
        rows([
          "64 e^(-pi sqrt(n)) g_n^(24) &= 1 - 24 e^(-pi sqrt(n)) + 276 e^(-2 pi sqrt(n)) - dots.c,",
          "64 g_n^(24) &= e^(pi sqrt(n)) - 24 + 276 e^(-pi sqrt(n)) - dots.c,", "64 a - 64 b g_n^(-24) + dots.c &= e^(pi sqrt(n)) - 24 + 276 e^(-pi sqrt(n)) - dots.c,",
          "64 a - 4096 b e^(-pi sqrt(n)) + dots.c &= e^(pi sqrt(n)) - 24 + 276 e^(-pi sqrt(n)) - dots.c,",
        ]),
      ),
    ),
    p("that is"),
    eq(
      hang([
        "e^(pi sqrt(n)) = (64 a + 24)", "- med (4096 b + 276) e^(-pi sqrt(n)) + dots.c",
      ]),
      n=13,
    ),
    p("Similarly, if"),
    ueq("1 = a G_n^(-24) - b G_n^(-48) + dots.c,"),
    p("then"),
    eq(
      hang([
        "e^(pi sqrt(n)) = (64 a - 24)", "- med (4096 b + 276) e^(-pi sqrt(n)) + dots.c",
      ]),
      n=14,
    ),
    p(
      (
        $|From \{r(13)} and \{r(14)} we can find whether
        $|\{m("e^(pi sqrt(n))")} is very nearly an integer for given values of
        $|\{m("n")}, and ascertain also the number of 9’s or 0’s in the decimal
        $|part. But if \{m("G_n")} and \{m("g_n")} be simple quadratic surds we
        $|may work independently as follows. We have, for example,
      ),
    ),
    ueq("g_(22) = sqrt((1 + sqrt(2)))."),
    p("Hence"),
    ueq(
      rows([
        "64 g_(22)^(24) &= e^(pi sqrt(22)) - 24 + 276 e^(-pi sqrt(22)) - dots.c,",
        "64 g_(22)^(-24) &= #hide($e^(pi sqrt(22)) - 24 +$) 4096 e^(-pi sqrt(22)) + dots.c,",
      ]),
    ),
    p("so that"),
    ueq(
      hang([
        "64 (g_(22)^(24) + g_(22)^(-24))", "= e^(pi sqrt(22)) - 24 + 4372 e^(-pi sqrt(22)) + dots.c",
        "= 64 {(1 + sqrt(2))^(12) + (1 - sqrt(2))^(12)}.",
      ]),
    ),
    p("Hence"),
    ueq("e^(pi sqrt(22)) = 2508951.9982 dots.h ."),
    p("Again"),
    ueq("G_(37) = (6 + sqrt(37))^(1/4),"),
    ueq(
      rows([
        "64 G_(37)^(24) &= e^(pi sqrt(37)) + 24 + 276 e^(-pi sqrt(37)) + dots.c,",
        "64 G_(37)^(-24) &= #hide($e^(pi sqrt(37)) + 24 +$) 4096 e^(-pi sqrt(37)) - dots.c,",
      ]),
    ),
    p("so that"),
    ueq(
      hang([
        "64 (G_(37)^(24) + G_(37)^(-24))", "= e^(pi sqrt(37)) + 24 + 4372 e^(-pi sqrt(37)) - dots.c",
        "= 64 {(6 + sqrt(37))^6 + (6 - sqrt(37))^6}.",
      ]),
    ),
    p("Hence"),
    ueq("e^(pi sqrt(37)) = 199148647.999978 dots.h ."),
    p("Similarly, from"),
    ueq("g_(58) = sqrt(((5 + sqrt(29))/2)),"),
    p("we obtain"),
    ueq(
      hang([
        "64 (g_(58)^(24) + g_(58)^(-24))", "= e^(pi sqrt(58)) - 24 + 4372 e^(-pi sqrt(58)) + dots.c",
        "= 64 {((5 + sqrt(29))/2)^(12) + ((5 - sqrt(29))/2)^(12)}.",
      ]),
    ),
    p("Hence"),
    ueq("e^(pi sqrt(58)) = 24591257751.99999982 dots.h ."),
  ]
}
