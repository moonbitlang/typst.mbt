// Sections 8 to 11: approximations in terms of surds only, and Table III.

///|
/// The series of (17) and (18), in sqrt(n) and in 1/sqrt(n).
const SERIES_N : String = "{1 - 24 (1/(e^(2 pi sqrt(n)) - 1) + 2/(e^(4 pi sqrt(n)) - 1) + dots.c)}"

///|
const SERIES_1N : String = "{1 - 24 (1/(e^(2 pi slash sqrt(n)) - 1) + 2/(e^(4 pi slash sqrt(n)) - 1) + dots.c)}"

///|
fn section_8() -> Array[Item] {
  [
    sec(
      (
        $|Thus we have seen how to approximate to \{m("pi")} by means of
        $|logarithms of surds. I shall now shew how to obtain approximations in
        $|terms of surds only. If
      ),
    ),
    ueq("n (K')/K = (L')/L,"),
    p("we have"),
    ueq("(n d k)/(k k'^2 K^2) = (d l)/(l l'^2 L^2)."),
    p(
      (
        $|But, by means of the modular equation connecting \{m("k")} and
        $|\{m("l")}, we can express \{m("d k slash d l")} as an algebraic
        $|function of \{m("k")}, a function moreover in which all coefficients
        $|which occur are algebraic numbers. Again,
      ),
    ),
    ueq("q = e^(-pi K' slash K), quad q^n = e^(-pi L' slash L),"),
    wide(
      eq(
        "(q^(1/12) (1 - q^2) (1 - q^4) (1 - q^6) dots.c)/(q^(1/12 n) (1 - q^(2 n)) (1 - q^(4 n)) (1 - q^(6 n)) dots.c) = ((k k')/(l l'))^(1/6) sqrt((K/L)).",
        n=15,
      ),
    ),
    p(
      (
        $|Differentiating this equation logarithmically, and using the formula
      ),
    ),
    ueq("(d q)/(d k) = (pi^2 q)/(2 k k'^2 K^2),"),
    p("we see that"),
    wide(
      eq(
        "n {1 - 24 (q^(2 n)/(1 - q^(2 n)) + (2 q^(4 n))/(1 - q^(4 n)) + dots.c)} - {1 - 24 (q^2/(1 - q^2) + (2 q^4)/(1 - q^4) + dots.c)} = (K L)/pi^2 A(k),",
        n=16,
      ),
    ),
    p(
      (
        $|where \{m("A(k)")} denotes an algebraic function of the special class
        $|described above. I shall use the letter \{m("A")} generally to denote
        $|a function of this type.
      ),
    ),
    p(
      (
        $|Now, if we put \{m("k = l'")} and \{m("k' = l")} in \{r(16)}, we
        $|have
      ),
    ),
    eq(
      rows(["& n \{SERIES_N}", "& - med \{SERIES_1N}", "& = (K/pi)^2 A(k)."]),
      n=17,
    ),
    p(
      (
        $|The algebraic function \{m("A(k)")} of course assumes a purely
        $|numerical form when we substitute the value of \{m("k")} deduced from
        $|the modular equation. But by substituting \{m("k = l'")} and
        $|\{m("k' = l")} in \{r(15)} we have
      ),
    ),
    wide(
      ueq(
        rows([
          "& n^(1/4) e^(-pi sqrt(n) slash 12) (1 - e^(-2 pi sqrt(n))) (1 - e^(-4 pi sqrt(n))) (1 - e^(-6 pi sqrt(n))) dots.c",
          "&= e^(-pi slash (12 sqrt(n))) (1 - e^(-2 pi slash sqrt(n))) (1 - e^(-4 pi slash sqrt(n))) (1 - e^(-6 pi slash sqrt(n))) dots.c",
        ]),
      ),
    ),
    p("Differentiating the above equation logarithmically we have"),
    eq(
      rows(["& n \{SERIES_N}", "& + med \{SERIES_1N}", "& = (6 sqrt(n))/pi."]),
      n=18,
    ),
    p("Now, adding \{r(17)} and \{r(18)}, we have"),
    eq(
      hang([
        "1 - 3/(pi sqrt(n)) - 24 (1/(e^(2 pi sqrt(n)) - 1) + 2/(e^(4 pi sqrt(n)) - 1) + dots.c)",
        "= (K/pi)^2 A(k).",
      ]),
      n=19,
    ),
    p("But it is known that"),
    ueq(
      hang([
        "1 - 24 (q/(1 + q) + (3 q^3)/(1 + q^3) + (5 q^5)/(1 + q^5) + dots.c)", "= ((2 K)/pi)^2 (1 - 2 k^2),",
      ]),
    ),
    p("so that"),
    eq(
      hang([
        "1 - 24 (1/(e^(pi sqrt(n)) + 1) + 3/(e^(3 pi sqrt(n)) + 1) + dots.c)", "= (K/pi)^2 A(k).",
      ]),
      n=20,
    ),
    p("Hence, dividing \{r(19)} by \{r(20)}, we have"),
    wide(
      eq(
        "(display(1 - 3/(pi sqrt(n)) - 24 (1/(e^(2 pi sqrt(n)) - 1) + 2/(e^(4 pi sqrt(n)) - 1) + dots.c)))/(display(1 - 24 (1/(e^(pi sqrt(n)) + 1) + 3/(e^(3 pi sqrt(n)) + 1) + dots.c))) = R,",
        n=21,
      ),
    ),
    p(
      (
        $|where \{m("R")} can always be expressed in radicals if \{m("n")} is
        $|any rational number. Hence we have
      ),
    ),
    eq("pi = 3/((1 - R) sqrt(n)),", n=22),
    p(
      (
        $|nearly, the error being about
        $|\{m("8 pi e^(-pi sqrt(n)) (pi sqrt(n) - 3).")}
      ),
    ),
  ]
}

///|
fn section_9() -> Array[Item] {
  [
    sec(
      (
        $|We may get a still closer approximation from the following results.
        $|It is known that
      ),
    ),
    ueq(
      hang([
        "1 + 240 sum_(r=1)^(r=oo) (r^3 q^(2 r))/(1 - q^(2 r))", "= ((2 K)/pi)^4 (1 - k^2 k'^2),",
      ]),
    ),
    p("and also that"),
    ueq(
      hang([
        "1 - 504 sum_(r=1)^(r=oo) (r^5 q^(2 r))/(1 - q^(2 r))", "= ((2 K)/pi)^6 (1 - 2 K^2) (1 + 1/2 k^2 k'^2).",
      ]),
    ),
    p("Hence, from \{r(19)}, we see that"),
    wide(
      eq(
        rows([
          "{1 - 3/(pi sqrt(n)) - 24 sum_(r=1)^(r=oo) r/(e^(2 pi r sqrt(n)) - 1)} & {1 + 240 sum_(r=1)^(r=oo) r^3/(e^(2 pi r sqrt(n)) - 1)}",
          "&= R' {1 - 504 sum_(r=1)^(r=oo) r^5/(e^(2 pi r sqrt(n)) - 1)},",
        ]),
        n=23,
      ),
    ),
    p(
      (
        $|where \{m("R'")} can always be expressed in radicals for any rational
        $|value of \{m("n")}. Hence
      ),
    ),
    eq("pi = 3/((1 - R') sqrt(n)),", n=24),
    p(
      (
        $|nearly, the error being about
        $|\{m("24 pi (10 pi sqrt(n) - 31) e^(-2 pi sqrt(n))")} It will be seen
        $|that the error in \{r(24)} is much less than that in \{r(22)}, if
        $|\{m("n")} is at all large.
      ),
    ),
  ]
}

///|
fn section_10() -> Array[Item] {
  let open = big("bracket.l", 240)
  let close = big("bracket.r", 240)
  let open_brace = big("brace.l", 240)
  let close_brace = big("brace.r", 240)
  [
    sec(
      (
        $|In order to find \{m("R")} and \{m("R'")} the series in \{r(16)}
        $|must be calculated in finite terms. I shall give the final results
        $|for a few values of \{m("n")}.
      ),
    ),
    table_title("table3"),
    wide(ueq("q = e^(-pi K' slash K), quad q^n = e^(-pi L' slash L),")),
    wide(
      ueq(
        "f(q) = n (1 - 24 sum_1^oo q^(2 m n)/(1 - q^(2 m n))) - (1 - 24 sum_1^oo q^(2 m)/(1 - q^(2 m))),",
      ),
    ),
    table_rows(
      rows([
        "f(2) &= (4 K L)/pi^2 (k' + l),",
        "f(3) &= (4 K L)/pi^2 (1 + k l + k' l'),",
        "f(4) &= (4 K L)/pi^2 (sqrt(k') + sqrt(l))^2,",
        "f(5) &= (4 K L)/pi^2 (3 + k l + k' l') sqrt(((1 + k l + k' l')/2)),",
        "f(7) &= (12 K L)/pi^2 (1 + k l + k' l'),",
        "f(11) &= (8 K L)/pi^2 {2 (1 + k l + k' l') + sqrt((k l)) + sqrt((k' l')) - sqrt((k k' l l'))},",
        "f(15) &= (4 K L)/pi^2 [{1 + (k l)^(1/4) + (k' l')^(1/4)}^4 - {1 + k l + k' l'}],",
        "f(17) &= (4 K L)/pi^2 sqrt(\"\") \{open_brace}44 (1 + k^2 l^2 + k'^2 l'^2) + 168 (k l + k' l' - k k' l l')",
        "& quad - med 102 (1 - k l - k' l') (4 k k' l l')^(1/3) - 192 (4 k k' l l')^(2/3)\{close_brace},",
        "f(19) &= (24 K L)/pi^2 {(1 + k l + k' l') + sqrt((k l)) + sqrt((k' l')) - sqrt((k k' l l'))},",
        "f(23) &= (4 K L)/pi^2 [11 (1 + k l + k' l') - 16 (4 k k' l l')^(1/6) {1 + sqrt((k l)) + sqrt((k' l'))} - 20 (4 k k' l l')^(1/3)],",
        "f(31) &= (12 K L)/pi^2 \{open}3 (1 + k l + k' l') + 4 {sqrt((k l)) + sqrt((k' l')) + sqrt((k k' l l'))}",
        "& quad - med 4 (k k' l l')^(1/4) {1 + (k l)^(1/4) + (k' l')^(1/4)}\{close},",
        "f(35) &= (4 K L)/pi^2 \{open}2 {sqrt((k l)) + sqrt((k' l')) - sqrt((k k' l l'))}",
        "& quad + med (4 k k' l l')^(-1/6) {1 - sqrt((k l)) - sqrt((k' l'))}^3\{close}.",
      ]),
    ),
    p(
      (
        $|Thus the sum of the series \{r(19)} can be found in finite terms,
        $|when \{m("n = 2, 3, 4, 5, dots.h,")} from the equations in
        $|\{table_ref("table3")}. We can use the same table to find the sum of \{r(19)}
        $|when \{m("n = 9, 25, 49, dots.h;")} but then we have also to use the
        $|equation
      ),
    ),
    ueq(
      hang([
        "3/pi = 1 - 24 (1/(e^(2 pi) - 1) + 2/(e^(4 pi) - 1)", "+ med 3/(e^(6 pi) - 1) + dots.c),",
      ]),
    ),
    p(
      (
        $|which is got by putting \{m("k = k' = 1 slash sqrt(2)")} and
        $|\{m("n = 1")} in \{r(18)}. Similarly we can find the sum of \{r(19)}
        $|when \{m("n = 21, 33, 57, 93, dots.h,")} by combining the values of
        $|\{m("f(3)")} and \{m("f(7)")}, \{m("f(3)")} and \{m("f(11)")}, and
        $|so on, obtained from \{table_ref("table3")}.
      ),
    ),
  ]
}

///|
fn section_11() -> Array[Item] {
  [
    sec("The errors in \{r(22)} and \{r(24)} being about"),
    ueq(
      rows([
        "8 pi e^(-pi sqrt(n)) (pi sqrt(n) - 3),", "24 pi (10 pi sqrt(n) - 31) e^(-2 pi sqrt(n)),",
      ]),
    ),
    p(
      (
        $|we cannot expect a high degree of approximation for small values of
        $|\{m("n")}. Thus, if we put \{m("n = 7, 9, 16,")} and 25 in \{r(24)},
        $|we get
      ),
    ),
    ueq(
      rows([
        "19/16 sqrt(7) &= 3.14180 dots.h,", "7/3 (1 + sqrt(3)/5) &= 3.14162 dots.h,",
        "99/80 (7/(7 - 3 sqrt(2))) &= 3.14159274 dots.h,", "63/25 ((17 + 15 sqrt(5))/(7 + 15 sqrt(5))) &= 3.14159265380 dots.h,",
      ]),
    ),
    p("while"),
    ueq("pi = 3.14159265358 dots.h ."),
    p("But if we put \{m("n = 25")} in \{r(22)}, we get only"),
    ueq("9/5 + sqrt(9/5) = 3.14164 dots.h ."),
  ]
}
