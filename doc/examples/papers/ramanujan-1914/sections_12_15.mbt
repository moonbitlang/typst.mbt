// Sections 12 to 15: geometrical constructions, series for 1/pi, and the
// perimeter of an ellipse.

///|
/// The first construction of section 12, drawn from its text: the square on
/// BX is 355/113 times the square on the radius.
fn figure_1() -> Canvas {
  let canvas : Canvas = {
    width: 190,
    height: 158,
    scale: 68,
    ox: 95,
    oy: 76,
    items: [],
  }
  let o = (0.0, 0.0)
  let a = (-1.0, 0.0)
  let b = (1.0, 0.0)
  // Bisect AO at M and trisect OB at T.
  let m_ = between(a, o, 0.5)
  let t = between(o, b, 2.0 / 3.0)
  // TP perpendicular to AB, meeting the circumference at P.
  let p_ = (t.0, (1.0 - t.0 * t.0).sqrt())
  // A chord BQ equal to PT (drawn on the other side of AB).
  let theta = 2.0 * @math.asin(distance(p_, t) / 2.0)
  let q = (@math.cos(theta), -@math.sin(theta))
  // OS and TR parallel to BQ, meeting AQ at S and R.
  let s = between(a, q, 0.5)
  let r_ = between(a, q, distance(a, t) / 2.0)
  // A chord AD equal to AS and a tangent AC = RS.
  let phi = 2.0 * @math.asin(distance(a, s) / 2.0)
  let d = (-@math.cos(phi), @math.sin(phi))
  let c = (-1.0, -distance(r_, s))
  // Cut off BE = BM, and draw EX parallel to CD, meeting BC at X.
  let ratio = distance(b, m_) / distance(b, d)
  let e = between(b, d, ratio)
  let x = between(b, c, ratio)
  canvas.circle(o, 1.0)
  for
    segment in [
      (a, b),
      (t, p_),
      (b, q),
      (a, q),
      (o, s),
      (t, r_),
      (a, d),
      (a, c),
      (b, c),
      (b, d),
      (c, d),
      (e, x),
    ] {
    canvas.segment(segment.0, segment.1)
  }
  canvas.label(a, "A", -8, 0)
  canvas.label(b, "B", 8, 0)
  canvas.label(o, "O", -6, -7)
  canvas.label(m_, "M", -8, -7)
  canvas.label(t, "T", 8, 7)
  canvas.label(p_, "P", 4, -7)
  canvas.label(q, "Q", 6, 6)
  canvas.label(s, "S", -3, 9)
  canvas.label(r_, "R", -2, 9)
  canvas.label(d, "D", -6, -6)
  canvas.label(c, "C", -7, 5)
  canvas.label(e, "E", 3, -8)
  canvas.label(x, "X", -1, 9)
  canvas
}

///|
/// The second construction: the square on the mean proportional between OS
/// and OB is (9^2 + 19^2/22)^(1/2) / 9 times the square on the radius.
fn figure_2() -> Canvas {
  let canvas : Canvas = {
    width: 190,
    height: 160,
    scale: 68,
    ox: 95,
    oy: 84,
    items: [],
  }
  let o = (0.0, 0.0)
  let a = (-1.0, 0.0)
  let b = (1.0, 0.0)
  // Bisect the arc ACB at C and trisect AO at T.
  let c = (0.0, 1.0)
  let t = between(a, o, 1.0 / 3.0)
  // From BC cut off CM and MN equal to AT.
  let step = distance(a, t) / distance(c, b)
  let m_ = between(c, b, step)
  let n = between(c, b, 2.0 * step)
  // From AN cut off AP equal to AM.
  let p_ = between(a, n, distance(a, m_) / distance(a, n))
  // PQ parallel to MN, meeting AM at Q.
  let q = between(a, m_, distance(a, p_) / distance(a, n))
  // TR parallel to OQ, meeting AQ at R.
  let r_ = between(a, q, distance(a, t) / distance(a, o))
  // AS perpendicular to AO and equal to AR.
  let s = (-1.0, -distance(a, r_))
  canvas.circle(o, 1.0)
  for
    segment in [
      (a, b),
      (b, c),
      (a, m_),
      (a, n),
      (p_, q),
      (o, q),
      (t, r_),
      (a, s),
      (o, s),
    ] {
    canvas.segment(segment.0, segment.1)
  }
  canvas.label(a, "A", -7, -3)
  canvas.label(b, "B", 7, 0)
  canvas.label(o, "O", 2, 7)
  canvas.label(c, "C", 0, -8)
  canvas.label(t, "T", 1, 7)
  canvas.label(m_, "M", 6, -5)
  canvas.label(n, "N", 7, -3)
  canvas.label(p_, "P", 5, 6)
  canvas.label(q, "Q", -2, -8)
  canvas.label(r_, "R", -3, -8)
  canvas.label(s, "S", -7, 3)
  canvas
}

///|
fn section_12() -> Array[Item] {
  [
    sec("Another curious approximation to \{m("pi")} is"),
    ueq("(9^2 + 19^2/22)^(1/4) = 3.14159265262 dots.h"),
    p(
      (
        $|This value was obtained empirically, and it has no connection with
        $|the preceding theory. The actual value of \{m("pi")}, which I have
        $|used for purposes of calculation, is
      ),
    ),
    ueq("355/113 (1 - (.0003)/3533) = 3.1415926535897943 dots.h,"),
    p(
      (
        $|which is greater than \{m("pi")} by about \{m("10^(-15)")}. This is
        $|obtained by simply taking the reciprocal of
        $|\{m("1 - (113 pi slash 355)")}. In this connection it may be
        $|interesting to note the following simple geometrical constructions
        $|for \{m("pi")}. The first merely gives the ordinary value
        $|\{m("355 slash 113")}. The second gives the value
        $|\{m("(9^2 + 19^2 slash 22)^(1/4)")} mentioned above.
      ),
    ),
    p(
      (
        $|(1) Let \{m("A B")} [\{Ref("fig1")}] be a diameter of a circle whose
        $|centre is \{m("O")}. Bisect \{m("A O")} at \{m("M")} and trisect
        $|\{m("O B")} at \{m("T")}. Draw \{m("T P")} perpendicular to
        $|\{m("A B")} and meeting the circumference at \{m("P")}. Draw a chord
        $|\{m("B Q")} equal to \{m("P T")} and join \{m("A Q")}. Draw
        $|\{m("O S")} and \{m("T R")} parallel to \{m("B Q")} and meeting
        $|\{m("A Q")} at \{m("S")} and \{m("R")} respectively. Draw a chord
        $|\{m("A D")} equal to \{m("A S")} and a tangent \{m("A C = R S")}.
        $|Join \{m("B C")}, \{m("B D")}, and \{m("C D")}; cut off
        $|\{m("B E = B M")}, and draw \{m("E X")}, parallel to \{m("C D")},
        $|meeting \{m("B C")} at \{m("X")}.
      ),
    ),
    figure(figure_1(), "fig1"),
    p(
      (
        $|Then the square on \{m("B X")} is very nearly equal to the area of
        $|the circle, the error being less than a tenth of an inch when the
        $|diameter is 40 miles long.
      ),
    ),
    p(
      (
        $|(2) Let \{m("A B")} (\{Ref("fig2")}) be a diameter of a circle whose
        $|centre is \{m("O")}. Bisect the arc \{m("A C B")} at \{m("C")} and
        $|trisect \{m("A O")} at \{m("T")}. Join \{m("B C")} and cut off from
        $|it \{m("C M")} and \{m("M N")} equal to \{m("A T")}. Join
        $|\{m("A M")} and \{m("A N")} and cut off from the latter \{m("A P")}
        $|equal to \{m("A M")}. Through \{m("P")} draw \{m("P Q")} parallel to
        $|\{m("M N")} and meeting \{m("A M")} at \{m("Q")}. Join \{m("O Q")}
        $|and through \{m("T")} draw \{m("T R")}, parallel to \{m("O Q")} and
        $|meeting \{m("A Q")} at \{m("R")}. Draw \{m("A S")} perpendicular to
        $|\{m("A O")} and equal to \{m("A R")}, and join \{m("O S")}.
      ),
    ),
    figure(figure_2(), "fig2"),
    p(
      (
        $|Then the mean proportional between \{m("O S")} and \{m("O B")} will
        $|be very nearly equal to a sixth of the circumference, the error being
        $|less than a twelfth of an inch when the diameter is 8000 miles long.
      ),
    ),
  ]
}

///|
/// The cubes of 1/2, 1.3/2.4, ... times powers of 2kk', as in (25) to (27).
const HALF3 : String = "(1/2)^3"

///|
const THREE_EIGHTHS3 : String = "((1 dot 3)/(2 dot 4))^3"

///|
fn section_13() -> Array[Item] {
  [
    sec(
      (
        $|I shall conclude this paper by giving a few series for
        $|\{m("1 slash pi")}. It is known that, when
        $|\{m("k <= 1 slash sqrt(2)")},
      ),
    ),
    eq(
      hang([
        "((2 K)/pi)^2 = 1 + \{HALF3} (2 k k')^2",
        "+ med \{THREE_EIGHTHS3} (2 k k')^4 + dots.c",
      ]),
      n=25,
    ),
    p("Hence we have"),
    wide(
      eq(
        rows([
          "q^(1/3) & (1 - q^2)^4 (1 - q^4)^4 (1 - q^6)^4 dots.c",
          "&= (1/4 k k')^(2/3) {1 + \{HALF3} (2 k k')^2 + \{THREE_EIGHTHS3} (2 k k')^4 + dots.c}.",
        ]),
        n=26,
      ),
    ),
    wide(
      p(
        (
          $|Differentiating both sides in \{r(26)} logarithmically with
          $|respect to \{m("k")}, we can easily shew that
        ),
      ),
    ),
    wide(
      eq(
        rows([
          "1 - 24 & (q^2/(1 - q^2) + (2 q^4)/(1 - q^4) + (3 q^6)/(1 - q^6) + dots.c)",
          "&= (1 - 2 k^2) {1 + 4 \{HALF3} (2 k k')^2 + 7 \{THREE_EIGHTHS3} (2 k k')^4 + dots.c}.",
        ]),
        n=27,
      ),
    ),
    p(
      (
        $|But it follows from \{r(19)} that, when
        $|\{m("q = e^(-pi sqrt(n))")}, \{m("n")} being a rational number, the
        $|left-hand side of \{r(27)} can be expressed in the form
      ),
    ),
    ueq("A ((2 K)/pi)^2 + B/pi,"),
    p(
      (
        $|where \{m("A")} and \{m("B")} are algebraic numbers expressible by
        $|surds. Combining \{r(25)} and \{r(27)} in such a way as to eliminate
        $|the term \{m("(2 K slash pi)^2")}, we are left with a series for
        $|\{m("1 slash pi")}. Thus, for example,
      ),
    ),
    wide(
      eq(
        rows([
          "4/pi = 1 + 7/4 \{HALF3} + 13/4^2 \{THREE_EIGHTHS3} + 19/4^3 ((1 dot 3 dot 5)/(2 dot 4 dot 6))^3 + dots.c,",
          "(q = e^(-pi sqrt(3)), quad 2 k k' = 1/2),",
        ]),
        n=28,
      ),
    ),
    wide(
      eq(
        rows([
          "16/pi = 5 + 47/64 \{HALF3} + 89/64^2 \{THREE_EIGHTHS3} + 131/64^3 ((1 dot 3 dot 5)/(2 dot 4 dot 6))^3 + dots.c,",
          "(q = e^(-pi sqrt(7)), quad 2 k k' = 1/8),",
        ]),
        n=29,
      ),
    ),
    wide(
      eq(
        rows([
          "32/pi = (5 sqrt(5) - 1) &+ (47 sqrt(5) + 29)/64 \{HALF3} ((sqrt(5) - 1)/2)^8",
          "&+ (89 sqrt(5) + 59)/64^2 \{THREE_EIGHTHS3} ((sqrt(5) - 1)/2)^(16) + dots.c,",
          "& [q = e^(-pi sqrt(15)), quad 2 k k' = 1/8 ((sqrt(5) - 1)/2)];",
        ]),
        n=30,
      ),
    ),
    p(
      (
        $|here \{m("5 sqrt(5) - 1")}, \{m("47 sqrt(5) + 29")},
        $|\{m("89 sqrt(5) + 59")}, \{m("dots.h")} are in arithmetical
        $|progression.
      ),
    ),
  ]
}

///|
/// The factors that every term of (35) to (44) repeats.
const Q1_FIRST : String = "1/2 (1 dot 3)/4^2"

///|
const Q1_SECOND : String = "(1 dot 3)/(2 dot 4) (1 dot 3 dot 5 dot 7)/(4^2 dot 8^2)"

///|
/// A series of the theory of q_1: `lead = first ± second ± third ± ...`.
fn q1_series(
  lead : String,
  first : String,
  second : String,
  third : String,
  sign : String,
  stop : String,
) -> String {
  let last = if sign == "-" { "-" } else { "+" }
  "\{lead} = \{first} \{sign} \{second} \{Q1_FIRST} + \{third} \{Q1_SECOND} \{last} dots.c\{stop}"
}

///|
fn section_14() -> Array[Item] {
  let q2_second = "(1 dot 3)/(2 dot 4) (1 dot 4)/(3 dot 6) (2 dot 5)/(3 dot 6)"
  let q3_second = "(1 dot 3)/(2 dot 4) (1 dot 7)/(6 dot 12) (5 dot 11)/(6 dot 12)"
  [
    sec(
      (
        $|The ordinary modular equations express the relations which hold
        $|between \{m("k")} and \{m("l")} when
        $|\{m("n K' slash K = L' slash L,")} or \{m("q^n = Q")}, where
      ),
    ),
    ueq("q = e^(-pi K' slash K), quad Q = e^(-pi L' slash L),"),
    ueq(rows(["K = 1 + (1/2)^2 k^2 + ((1 dot 3)/(2 dot 4))^2 k^4 + dots.c ."])),
    p(
      (
        $|There are corresponding theories in which \{m("q")} is replaced by
        $|one or other of the functions
      ),
    ),
    ueq(
      rows([
        "q_1 = e^(-pi K'_1 sqrt(2) slash K_1), quad q_2 = e^(-2 pi K'_2 slash (K_2 sqrt(3))),",
        "q_3 = e^(-2 pi K'_3 slash K_3),",
      ]),
    ),
    p("where"),
    wide(
      ueq(
        rows([
          "K_1 &= 1 + (1 dot 3)/4^2 k^2 + (1 dot 3 dot 5 dot 7)/(4^2 dot 8^2) k^4 + (1 dot 3 dot 5 dot 7 dot 9 dot 11)/(4^2 dot 8^2 dot 12^2) k^6 + dots.c,",
          "K_2 &= 1 + (1 dot 2)/3^2 k^2 + (1 dot 2 dot 4 dot 5)/(3^2 dot 6^2) k^4 + (1 dot 2 dot 4 dot 5 dot 7 dot 8)/(3^2 dot 6^2 dot 9^2) k^6 + dots.c",
          "K_3 &= 1 + (1 dot 5)/6^2 k^2 + (1 dot 5 dot 7 dot 11)/(6^2 dot 12^2) k^4 + (1 dot 5 dot 7 dot 11 dot 13 dot 17)/(6^2 dot 12^2 dot 18^2) k^6 + dots.c .",
        ]),
      ),
    ),
    wide(
      p(
        (
          $|From these theories we can deduce further series for
          $|\{m("1 slash pi")}, such as
        ),
      ),
    ),
    wide(
      eq(
        "27/(4 pi) = 2 + 17 1/2 1/3 2/3 (2/27) + 32 \{q2_second} (2/27)^2 + dots.c,",
        n=31,
      ),
    ),
    wide(
      eq(
        "(15 sqrt(3))/(2 pi) = 4 + 37 1/2 1/3 2/3 (4/125) + 70 \{q2_second} (4/125)^2 + dots.c,",
        n=32,
      ),
    ),
    wide(
      eq(
        "(5 sqrt(5))/(2 pi sqrt(3)) = 1 + 12 1/2 1/6 5/6 (4/125) + 23 \{q3_second} (4/125)^2 + dots.c,",
        n=33,
      ),
    ),
    wide(
      eq(
        "(85 sqrt(85))/(18 pi sqrt(3)) = 8 + 141 1/2 1/6 5/6 (4/85)^3 + 274 \{q3_second} (4/85)^6 + dots.c,",
        n=34,
      ),
    ),
    wide(eq(q1_series("4/pi", "3/2", "23/2^3", "43/2^5", "-", " ,"), n=35)),
    wide(
      eq(
        q1_series(
          "4/(pi sqrt(3))", "3/4", "31/(3 dot 4^3)", "59/(3^2 dot 4^5)", "-", " ,",
        ),
        n=36,
      ),
    ),
    wide(
      eq(q1_series("4/pi", "23/18", "283/18^3", "543/18^5", "-", " ,"), n=37),
    ),
    wide(
      eq(
        q1_series(
          "4/(pi sqrt(5))", "41/72", "685/(5 dot 72^3)", "1329/(5^2 dot 72^5)", "-",
          " ,",
        ),
        n=38,
      ),
    ),
    wide(
      eq(
        q1_series("4/pi", "1123/882", "22583/882^3", "44043/882^5", "-", " ,"),
        n=39,
      ),
    ),
    wide(eq(q1_series("(2 sqrt(3))/pi", "1", "9/9", "17/9^2", "+", " ,"), n=40)),
    wide(
      eq(
        q1_series("1/(2 pi sqrt(2))", "1/9", "11/9^3", "21/9^5", "+", " ,"),
        n=41,
      ),
    ),
    wide(
      eq(
        q1_series("1/(3 pi sqrt(3))", "3/49", "43/49^3", "83/49^5", "+", " ,"),
        n=42,
      ),
    ),
    wide(
      eq(
        q1_series("2/(pi sqrt(11))", "19/99", "299/99^3", "579/99^5", "+", " ,"),
        n=43,
      ),
    ),
    wide(
      eq(
        q1_series(
          "1/(2 pi sqrt(2))", "1103/99^2", "27493/99^6", "53883/99^(10)", "+", " .",
        ),
        n=44,
      ),
    ),
    p(
      (
        $|In all these series the first factors in each term form an
        $|arithmetical progression; e.g. 2, 17, 32, 47, \{m("dots.h")}, in
        $|\{r(31)}, and 4, 37, 70, 103, \{m("dots.h")}, in \{r(32)}. The
        $|first two series belong to the theory of \{m("q_2")}, the next two to
        $|that of \{m("q_3")}, as the rest to that of \{m("q_1")}. The last
        $|series \{r(44)} is extremely rapidly convergent. Thus, taking only
        $|the first term, we see that
      ),
    ),
    ueq("1103/99^2 = .11253953678 dots.h,"),
    ueq("1/(2 pi sqrt(2)) = .11253953951 dots.h ."),
  ]
}

///|
fn section_15() -> Array[Item] {
  let gamma = (x : String, y : String) => "(Gamma(\{x}))/(Gamma(\{y}))"
  let g14 = gamma("1/4", "3/4")
  let g34 = gamma("3/4", "5/4")
  [
    sec("In concluding this paper I have to remark that the series"),
    ueq(
      "1 - 24 (q^2/(1 - q^2) + (2 q^4)/(1 - q^4) + (3 q^6)/(1 - q^6) + dots.c),",
    ),
    p(
      (
        $|which has been discussed in §§ 8-13, is very closely connected with
        $|the perimeter of an ellipse whose eccentricity is \{m("k")}. For, if
        $|\{m("a")} and \{m("b")} be the semi-major and the semi-minor axes, it
        $|is known that
      ),
    ),
    eq(
      hang([
        "p = 2 pi a \{big("brace.l", 240)}1 - 1/2^2 k^2 - (1^2 dot 3)/(2^2 dot 4^2) k^4",
        "- med (1^2 dot 3^2 dot 5)/(2^2 dot 4^4 dot 6^2) k^6 - dots.c \{big("brace.r", 240)},",
      ]),
      n=45,
    ),
    p(
      (
        $|where \{m("p")} is the perimeter and \{m("k")} the eccentricity. It
        $|can easily be seen from \{r(45)} that
      ),
    ),
    eq("p = 4 a k'^2 {K + k (d K)/(d k)}.", n=46),
    p("But, taking the equation"),
    ueq(
      hang([
        "q^(1/12) (1 - q^2) (1 - q^4) (1 - q^6) dots.c", "= (2 k k')^(1/6) sqrt((K slash pi)),",
      ]),
    ),
    p(
      (
        $|and differentiating both sides logarithmically with respect to
        $|\{m("k")}, and combining the result with \{r(46)} in such a way as to
        $|eliminate \{m("d K slash d k")}, we can shew that
      ),
    ),
    wide(
      eq(
        "p = (4 a)/(3 K) [K^2 (1 + k'^2) + (1/2 pi)^2 {1 - 24 (q^2/(1 - q^2) + (2 q^4)/(1 - q^4) + dots.c)}].",
        n=47,
      ),
    ),
    p(
      (
        $|But we have shewn already that the right-hand side of \{r(47)} can
        $|be expressed in terms of \{m("K")} if \{m("q = e^(-pi sqrt(n)),")}
        $|where \{m("n")} is any rational number. It can also be shewn that
        $|\{m("K")} can be expressed in terms of \{m("Gamma")}-functions if
        $|\{m("q")} be of the forms \{m("e^(-pi n)")},
        $|\{m("e^(-pi n sqrt(2))")} and \{m("e^(-pi n sqrt(3))")}, where
        $|\{m("n")} is rational. Thus, for example, we have
      ),
    ),
    wide(
      eq(
        braced(
          [
            "k = sin pi/4 comma quad & q = e^(-pi) comma",
            "& p = a sqrt((pi/2)) {\{g14} + \{g34}} comma",
            "k = tan pi/8 comma quad & q = e^(-pi sqrt(2)) comma",
            "& p = a sqrt((pi/4)) {\{gamma("1/8", "5/8")} + \{gamma("5/8", "9/8")}} comma",
            "k = sin pi/12 comma quad & q = e^(-pi sqrt(3)) comma",
            "& p = a sqrt((pi/sqrt(3))) {(1 + 1/sqrt(3)) \{gamma("1/3", "5/6")} + 2 \{gamma("5/6", "1/3")}} comma",
            "b/a = tan^2 pi/8 comma quad & q = e^(-2 pi)",
            "& p = (a + b) sqrt((pi/2)) {1/2 \{g14} + \{g34}} comma",
          ],
          gap="0.55em",
        ),
        n=48,
      ),
    ),
    p("and so on."),
    p("The following approximations for \{m("p")} were obtained empirically:"),
    eq("p = pi [3 (a + b) - sqrt({(a + 3 b) (3 a + b)}) + epsilon.alt],", n=49),
    p("where \{m("epsilon.alt")} is about \{m("a k^(12) slash 1048576")};"),
    wide(
      eq(
        "p = pi {(a + b) + (3 (a - b)^2)/(10 (a + b) + sqrt((a^2 + 14 a b + b^2))) + epsilon.alt},",
        n=50,
      ),
    ),
    p(
      "where \{m("epsilon.alt")} is about \{m("3 a k^(20) slash 68719476736.")}",
    ),
  ]
}
