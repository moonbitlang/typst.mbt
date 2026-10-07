// Note G (Scientific Memoirs, vol. 3, pages 722 to 731), verbatim from the
// Wikisource transcription. Kept as found there: the misprints of 1843 it
// marks ("hovever", "sucessively", "a x_n" for "a x^n"), the unbalanced
// parenthesis in the third line of formula (3.), "to make number", the
// signature "A. L. L.", and the last column of the table of cycles, whose
// cells end with "=".

///|
/// The four columns of page 724 with the quantity their first three give.
fn columns_of(result : String) -> Seq {
  let boxed = (source : String) => {
    Box(Equation(source), stroke=Sides(all=rule), inset=Sides(x=Pt(7), y=Pt(4)))
  }
  in_paragraph(
    Grid(
      [
        mv(0),
        mv(1),
        mv(2),
        mv(3),
        boxed("a"),
        boxed("n"),
        boxed("x"),
        boxed(result),
        GridCell(Equation("underbrace(#h(8em), \{result})"), colspan=3),
      ],
      columns=[Auto, Auto, Auto, Auto],
      align=Cells::all(Center + Horizon),
      column_gutter=[Em(0.9)],
      row_gutter=[Em(0.5)],
    ),
  )
}

///|
/// The operations for each number, in the notation of cycles (page 730).
fn cycles_table() -> Seq {
  let dots = GridCell(
    Line(length=Pct(100), stroke=Stroke(thickness=Pt(0.6), dash=Dotted)),
    colspan=5,
  )
  let row = (
    cards : &IntoContent,
    number : &IntoContent,
    rank : &IntoContent,
    being : &IntoContent,
  ) => {
    let cells : Array[&IntoContent] = [
      cards,
      Align(Right, number),
      rank,
      being,
      "=",
    ]
    cells
  }
  let sigma = Prose(
    "(1…7),(8…12),\{m("Sigma(+1)^(n-2)")}(13…23),(24, 25)",
  )
  in_paragraph(
    Grid(
      [
        ..row(
          "(1…7), (24, 25)",
          Prose("gives \{b("1")}"),
          "= 1st number",
          Prose("; (\{m("n")} being"),
        ),
        ..row(
          "(1…7), (8…12), (24, 25)",
          b("3"),
          "= 2nd",
          Prose("; (\{m("n")}"),
        ),
        ..row(
          "(1…7), (8…12), (13…23), (24, 25)",
          b("5"),
          "= 3rd",
          Prose("; (\{m("n")}"),
        ),
        ..row(
          "(1…7), (8…12), 2(13…23), (24, 25)",
          b("7"),
          "= 4th",
          Prose("; (\{m("n")}"),
        ),
        dots,
        dots,
        ..row(sigma, b("2n-1"), Prose("= \{m("n")}th"), Prose("; (\{m("n")}")),
      ],
      columns=[Auto, Auto, Auto, Auto, Auto],
      align=Cells::all(Left + Horizon),
      column_gutter=[Em(0.7)],
      row_gutter=[Em(0.55)],
    ),
  )
}

///|
fn note_g() -> Array[&IntoContent] {
  let cosp = "op(\"cos.\")"
  let substituted = m(
    "(1/2 \{cosp} overline(n+1) thick theta + 1/2 \{cosp} overline(n-1) thick theta)",
  )
  let product = m("(\{cosp} n theta . \{cosp} theta)")
  let limits = Footnote(
    Prose(
      (
        $|The engine cannot of course compute limits for perfectly \{i("simple")} and
        $|\{i("uncompounded")} functions, except in this manner. It is obvious that it
        $|has no power of representing or of manipulating with any but \{i("finite")}
        $|increments or decrements; and consequently that wherever the computation of
        $|limits (or of any other functions) depends upon the \{i("direct")}
        $|introduction of quantities which either increase or decrease
        $|\{i("indefinitely")}, we are absolutely beyond the sphere of its powers. Its
        $|nature and arrangements are remarkably adapted for taking into account all
        $|\{i("finite")} increments or decrements (however small or large), and for
        $|developing the true and logical modifications of form or value dependent upon
        $|differences of this nature. The engine may indeed be considered as including
        $|the whole Calculus of Finite Differences; many of whose theorems would be
        $|especially and beautifully fitted for development by its processes, and would
        $|offer peculiarly interesting considerations. We may mention, as an example,
        $|the calculation of the Numbers of Bernoulli by means of the
        $|\{i("Differences of Nothing")}.
      ),
    ),
  )
  let axn = m("a x^n")
  let derivative = disp("a n x^(n-1).")
  let integrated = m("a/n x^((n+1))")
  let reduction = disp("integral (x^n thick d x)/(sqrt(a^2 - x^2)),")
  let arbogast = cited("arbogast")
  let expansion = numbered(
    "x/(e^x - 1) = 1/(1 + x/2 + x^2/(2.3) + x^3/(2.3.4) + \{etc})",
    "g1",
  )
  let quotient = disp(
    "(a + b x + c x^2 + \{etc})/(a' + b' x + c' x^2 + \{etc})",
  )
  let well_known = numbered(
    "B_(2n-1) = 2. (1.2.3 dots.h 2n)/((2 pi)^(2n)) dot {1 + 1/(2^(2n)) + 1/(3^(2n)) + dots.h}",
    "g2",
  )
  let third = numbered(
    (
      #|B_(2n-1) = (plus.minus 2n)/((2^(2n) - 1) 2^(n-1)) mat(delim: #("{", "}"), row-gap: #0.8em,
      #|  & display(1/2 n^(2n-1));
      #|  display(-(n-1)) & display(zws^(2n-1) {1 + 1/2 dot (2n)/1});
      #|  display(+(n-2)) & display(zws^(2n-1) {1 + (2n)/1 + 1/2 dot (2n.\(2n-1)/(1.2)});
      #|  display(-(n-3)) & display(zws^(2n-1) mat(delim: #("{", "}"), row-gap: #0.5em, & display(1 + (2n)/1 + (2n.2n-1)/(1.2) +); & display(+ 1/2 dot (2n.(2n-1).(2n-2))/(1.2.3))));
      #|  display(+ dots.c) & display(quad dots.c quad dots.c quad dots.c)
      #|)
    ),
    "g3",
  )
  let fourth = numbered(
    "x/(e^x - 1) = 1 - x/2 + B_1 x^2/2 + B_3 x^4/(2.3.4) + B_5 x^6/(2.3.4.5.6) + dots.h",
    "g4",
  )
  let fifth = numbered(
    "1 = (1 - x/2 + B_1 x^2/2 + B_3 x^4/(2.3.4) + dots.h) (1 + x/2 + x^2/(2.3) + x^3/(2.3.4) dots.h)",
    "g5",
  )
  let sixth = numbered("1 + D_1 x + D_2 x^2 + D_3 x^3 dots.h dots.h", "g6")
  let seventh = numbered(
    (
      #|mat(delim: #(none, "}"), row-gap: #0.9em,
      #|  display(1/(2.3 dots.h 2n+1)) & display(- 1/2 dot 1/(2.3. dots.h 2n) + B_1/2 dot 1/(2.3 dots.h 2n-1) + B_3/(2.3.4) dot 1/(2.3 dots.h 2n-3) +);
      #|  & display(+ B_5/(2.3.4.5.6) dot 1/(2.3 dots.h 2n-5) + dots.c + B_(2n-1)/(2.3 dots.h 2n) dot 1 = 0)
      #|)
    ),
    "g7",
  )
  let eighth = numbered(
    (
      #|mat(delim: #(none, "}"), row-gap: #0.9em,
      #|  display(0 = -) & display(1/2 dot (2n-1)/(2n+1) + B_1 ((2n)/2) + B_3 ((2n.2n-1.2n-2)/(2.3.4)) +);
      #|  & display(+ B_5 ((2n.2n-1 dots.h dots.h dots.h 2n-4)/(2.3.4.5.6)) + dots.h + B_(2n-1))
      #|)
    ),
    "g8",
  )
  let ninth = numbered(
    "0 = A_0 + A_1 B_1 + A_3 B_3 + A_5 B_5 + dots.h + B_(2n-1)", "g9",
  )
  let even = disp(
    (
      #|2n + 1 = d, " and " n = (d-1)/2 " (for any " italic("even") " power of " x.
    ),
  )
  let odd = disp(
    (
      #|2n = d, " and " n = d/2 " (for any " italic("odd") " power of " x.)
    ),
  )
  let see_diagram = Footnote(
    Prose("See the diagram at the end of these Notes."),
  )
  let prepared = m("-1/2 dot (2n-1)/(2n+1)")
  let produced = m("-1/2 dot (2n-1)/(2n+1) + B_1 (2n)/2")
  let alterations = disp(
    (
      #|bold(upright(V))_6 &= 2n - 4 " instead of " 2n - 2. \
      #|bold(upright(V))_7 &= 6 dots.h dots.h dots.h dots.h 4. \
      #|bold(upright(V))_10 &= 0 dots.h dots.h dots.h dots.h 1. \
      #|bold(upright(V))_13 &= A_0 + A_1 B_1 + A_3 B_3 + A_5 B_5 " instead of " A_0 + A_1 B_1 + A_3 B_3
    ),
  )
  let millions = Footnote(
    Prose(
      (
        $|It is interesting to observe, that so complicated a case as this calculation
        $|of the Bernoullian Numbers, nevertheless, presents a remarkable simplicity in
        $|one respect; viz., that during the processes for the computation of
        $|\{i("millions")} of these Numbers, no other arbitrary modification would be
        $|requisite in the arrangements, excepting the above simple and uniform
        $|provision for causing one of the data periodically to receive the finite
        $|increment unity.
      ),
    ),
  )
  let every_number = disp(
    (
      #|(1 dots.h 7), (24, 25), limits(Sigma(+1)^n)_("limits " 1 " to " n) lr({ (1 dots.h 7), (8 dots.h 12), limits(Sigma(n+2)(13 dots.h 23)\, (24, 25))_("limits " 0 " to " (n+2)) })
    ),
  )
  let mixed = disp("(d^2)/(d x^2) (z_(n+1) x^(2n+2)) = (2n+1)(2n+2) z^n x^(2n)")
  let general = disp(
    "z_n = f(n) dot x + f_1(n) + f_2(n) dot x^(-1) + f_3(n) dot x^(-3) + dots.c",
  )
  let bold_b = (index : Int) => m("bold(upright(B))_(\{index})")
  let bold_a = (index : Int) => m("bold(upright(A))_(\{index})")
  [
    (
      $|It is desirable to guard against the possibility of exaggerated ideas that
      $|might arise as to the powers of the Analytical Engine. In considering any new
      $|subject, there is frequently a tendency, first, to \{i("overrate")} what we
      $|find to be already interesting or remarkable; and, secondly, by a sort of
      $|natural reaction, to \{i("undervalue")} the true state of the case, when we do
      $|discover that our notions have surpassed those that were really tenable.
    )
    |> indented,
    (
      $|The Analytical Engine has no pretensions whatever to \{i("originate")} any
      $|thing. It can do whatever \{i("we know how to order it")} to perform. It can
      $|\{i("follow")} analysis; but it has no power of \{i("anticipating")} any
      $|analytical relations or truths. Its province is to assist us in making
      $|\{i("available")} what we are already acquainted with. This it is calculated
      $|to effect primarily and chiefly of course, through its executive faculties; but
      $|it is likely to exert an \{i("indirect")} and reciprocal influence on science
      $|itself in another manner. For, in so distributing and combining the truths and
      $|the formulæ of analysis, that they may become most easily and rapidly amenable
      $|to the mechanical combinations of the engine, the relations and the nature of
      $|many subjects in that science are necessarily thrown into new lights, and more
      $|profoundly investigated. This is a decidedly indirect, and a somewhat
      $|\{i("speculative")}, consequence of such an invention. It is however pretty
      $|evident, on general principles, that in devising for Mathematical truths a new
      $|form in which to record and throw themselves out for actual use, views are
      $|likely to be induced, which should again react on the more theoretical phase of
      $|the subject. There are in all extensions of human power, or additions to human
      $|knowledge, various \{i("collateral")} influences, besides the main and primary
      $|object attained.
    )
    |> par,
    (
      $|To return to the executive faculties of this engine: the question must arise
      $|in every mind, are they \{i("really")} even able to \{i("follow")} analysis in
      $|its whole extent? No reply, entirely satisfactory to all minds, can be given to
      $|this query, excepting the actual existence of the engine, and actual
      $|experience of its practical results. We will however sum up for each reader's
      $|consideration the chief elements with which the engine works:—
    )
    |> par,
    Enum([
      Prose(
        "It performs the four operations of simple arithmetic upon any numbers whatever.",
      ),
      Prose(
        (
          $|By means of certain artifices and arrangements (upon which we cannot enter
          $|within the restricted space which such a publication as the present may
          $|admit of), there is no limit either to the \{i("magnitude")} of the
          $|\{i("numbers")} used, or to the \{i("number")} of \{i("quantities")}
          $|(either variables or constants) that may be employed.
        ),
      ),
      Prose(
        (
          $|It can combine these numbers and these quantities either algebraically or
          $|arithmetically, in relations unlimited as to variety, extent, or
          $|complexity.
        ),
      ),
      Prose(
        (
          $|It uses algebraic \{i("signs")} according to their proper laws, and
          $|developes the logical consequences of these laws.
        ),
      ),
      Prose(
        (
          $|It can arbitrarily substitute any formula for any other; effacing the first
          $|from the columns on which it is represented, and making the second appear
          $|in its stead.
        ),
      ),
      Prose(
        (
          $|It can provide for singular values. Its power of doing this is referred to
          $|in M. Menabrea's memoir, page 685, where he mentions the passage of values
          $|through zero and infinity. The practicability of causing it arbitrarily to
          $|change its processes at any moment, on the occurrence of any specified
          $|contingency (of which its substitution of \{substituted} for \{product}
          $|explained in Note E., is in some degree an illustration), at once secures
          $|this point.
        ),
      ),
    ]),
    (
      $|The subject of integration and of differentiation demands some notice. The
      $|engine can effect these processes in either of two ways:—
    )
    |> indented,
    (
      $|First. We may order it, by means of the Operation and of the Variable-cards,
      $|to go through the various steps by which the required \{i("limit")} can be
      $|worked out for whatever function is under consideration.
    )
    |> par,
    (
      $|Secondly. It may (if we know the form of the limit for the function in
      $|question) effect the integration or differentiation by direct\{limits}
      $|substitution. We remarked in Note B., that any \{i("set")} of columns on which
      $|numbers are inscribed, represents merely a \{i("general")} function of the
      $|several quantities, until the special function have been impressed by means of
      $|the Operation and Variable-cards. Consequently, if instead of requiring the
      $|value of the function, we require that of its integral, or of its differential
      $|coefficient, we have merely to order whatever particular combination of the
      $|ingredient quantities may constitute that integral or that coefficient. In
      $|\{axn}, for instance, instead of the quantities \{columns_of("a x^n")} being
      $|ordered to appear on \{mv(3)} in the combination \{axn}, they would be ordered
      $|to appear in that of \{derivative}
    )
    |> par,
    (
      $|They would then stand thus:— \{columns_of("a n x^(n-1)")}
    )
    |> indented,
    (
      $|Similarly, we might have \{integrated}, the integral of \{m("a x_n")}.
    )
    |> par,
    (
      $|An interesting example for following out the processes of the engine would be
      $|such a form as \{reduction} or any other cases of integration by successive
      $|reductions, where an integral which contains an operation repeated \{m("n")}
      $|times can be made to depend upon another which contains the same
      $|\{m("n - 1")} or \{m("n - 2")} times, and so on until by continued reduction
      $|we arrive at a certain \{i("ultimate")} form, whose value has then to be
      $|determined.
    )
    |> par,
    (
      $|The methods in Arbogast's \{i("Calcul des Dérivations")}\{arbogast} are
      $|peculiarly fitted for the notation and the processes of the engine. Likewise
      $|the whole of the Combinatorial Analysis, which consists first in a purely
      $|numerical calculation of indices, and secondly in the distribution and
      $|combination of the quantities according to laws prescribed by these indices.
    )
    |> par,
    (
      $|We will terminate these Notes by following up in detail the steps through
      $|which the engine could compute the Numbers of Bernoulli, this being (in the
      $|form in which we shall deduce it) a rather complicated example of its powers.
      $|The simplest manner of computing these numbers would be from the direct
      $|expansion of \{expansion} which is in fact a particular case of the
      $|development of \{quotient} mentioned in Note E. Or again, we might compute
      $|them from the well-known form \{well_known} or from the form \{third} or from
      $|many others. As however our object is not simplicity or facility of
      $|computation, but the illustration of the powers of the engine, we prefer
      $|selecting the formula below, marked \{eq("g8")}. This is derived in the
      $|following manner:—
    )
    |> par,
    (
      $|If in the equation \{fourth} (in which \{b("1")}, \{b("3")}…, &c. are the
      $|Numbers of Bernoulli), we expand the denominator of the first side in powers
      $|of \{m("x")}, and then divide both numerator and denominator by \{m("x")}, we
      $|shall derive \{fifth}
    )
    |> par,
    (
      $|If this latter multiplication be actually performed, we shall have a series of
      $|the general form \{sixth} in which we see, first, that all the coefficients of
      $|the powers of \{m("x")} are severally equal to zero; and secondly, that the
      $|general form for \{m("D_(2n)")} the co-efficient of the \{m("2n + 1")}th
      $|\{i("term")}, (that is of \{m("x^(2n)")} any \{i("even")} power of
      $|\{m("x")}), is the following:— \{seventh}
    )
    |> indented,
    (
      $|Multiplying every term by (\{m("2.3 dots.h 2n")}), we have \{eighth} which it
      $|may be convenient to write under the general form:— \{ninth} \{m("A_1")},
      $|\{m("A_3")}, &c. being those functions of \{m("n")} which respectively belong
      $|to \{b("1")}, \{b("3")}, &c.
    )
    |> indented,
    (
      $|We might have derived a form nearly similar to \{eq("g8")}, from
      $|\{m("D_(2n-1)")} the coefficient of any \{i("odd")} power of \{m("x")} in
      $|\{eq("g6")}; but the general form is a little different for the coefficients
      $|of the \{i("odd")} powers, and not quite so convenient.
    )
    |> par,
    (
      $|On examining \{eq("g7")} and \{eq("g8")}, we perceive that, when these formulæ
      $|are isolated from \{eq("g6")} whence they are derived, and considered in
      $|themselves separately and independently, \{m("n")} may be any whole number
      $|whatever; although when \{eq("g7")} occurs \{i("as one of the")}
      $|\{m("D")}’s in \{eq("g6")}, it is obvious that \{m("n")} is then not
      $|arbitrary, but is always a certain function of the \{i("distance of that")}
      $|\{m("D")} \{i("from the beginning")}. If that distance be \{m("= d")}, then
      $|\{even} \{odd} It is with the \{i("independent")} formula \{eq("g8")} that we
      $|have to do. Therefore it must be remembered that the conditions for the value
      $|of \{m("n")} are now modified, and that \{m("n")} is a perfectly
      $|\{i("arbitrary")} whole number. This circumstance, combined with the fact
      $|(which we may easily perceive) that whatever \{m("n")} is, every term of
      $|\{eq("g8")} after the \{m("(n + 1)")}th is \{m("= 0")}, and that the
      $|(\{m("n + 1")})th term itself is always
      $|\{m("= B_(2n-1) dot 1/1 = B_(2n-1)")}, enables us to find the value (either
      $|numerical or algebraical) of any \{m("n")}th Number of Bernoulli
      $|\{b("2n-1")}, \{i("in terms of all the preceding ones")}, if we but know the
      $|values of \{b("1")}, \{m("B_3 dots.h B_(2n-3)")}. We append to this Note a
      $|Diagram and Table, containing the details of the computation for \{b("7")},
      $|(\{b("1")}, \{b("3")}, \{b("5")} being supposed given).
    )
    |> par,
    (
      $|On attentively considering \{eq("g8")}, we shall likewise perceive that we may
      $|derive from it the numerical value of \{i("every")} Number of Bernoulli in
      $|succession, from the very beginning, \{i("ad infinitum")}, by the following
      $|series of computations:—
    )
    |> par,
    (
      $|1st Series.—Let \{m("n = 1")}, and calculate \{eq("g8")} for this value of
      $|\{m("n")}. The result is \{b("1")}.
    )
    |> par,
    (
      $|2nd Series.—Let \{m("n = 2")}. Calculate \{eq("g8")} for this value of
      $|\{m("n")}, substituting the value of \{b("1")} just obtained. The result is
      $|\{b("3")}.
    )
    |> par,
    (
      $|3rd Series.—Let \{m("n = 3")}. Calculate \{eq("g8")} for this value of
      $|\{m("n")}, substituting the values of \{b("1")}, \{b("3")} before obtained.
      $|The result is \{b("5")}. And so on, to any extent.
    )
    |> par,
    (
      $|The diagram\{see_diagram} represents the columns of the engine when just
      $|prepared for computing \{b("2n-1")}, (in the case of \{m("n = 4")}); while the
      $|table beneath them presents a complete simultaneous view of all the successive
      $|changes which these columns then severally pass through in order to perform
      $|the computation. (The reader is referred to Note D, for explanations
      $|respecting the nature and notation of such tables.)
    )
    |> par,
    (
      $|Six numerical \{i("data")} are in this case necessary for making the requisite
      $|combinations. These data are 1, 2, \{m("n(= 4)")}, \{b("1")}, \{b("3")},
      $|\{b("5")}. Were \{m("n = 5")}, the additional datum \{b("7")} would be needed.
      $|Were \{m("n = 6")}, the datum \{b("9")} would be needed; and so on. Thus the
      $|actual \{i("number of data")} needed will always be \{m("n + 2")}, for
      $|\{m("n = n")}; and out of these \{m("n + 2")} data,
      $|(\{m("overline(n + 2) - 3")}) of them are successive Numbers of Bernoulli. The
      $|reason why the Bernoulli Numbers used as data, are nevertheless placed on
      $|\{i("Result")}-columns in the diagram, is because they may properly be supposed
      $|to have been previously computed in succession by the \{i("engine")} itself;
      $|under which circumstances each \{m("B")} will appear as a \{i("result")},
      $|previous to being used as a \{i("datum")} for computing the succeeding
      $|\{m("B")}. Here then is an instance (of the kind alluded to in Note D.) of the
      $|same Variables filling more than one office in turn. It is true that if we
      $|consider our computation of \{b("7")} as a perfectly \{i("isolated")}
      $|calculation, we may conclude \{b("1")}, \{b("3")}, \{b("5")} to have been
      $|arbitrarily placed on the columns; and it would then perhaps be more consistent
      $|to put them on \{mv(4)}, \{mv(5)}, \{mv(6)} as data and not results. But we are
      $|not taking this view. On the contrary, we suppose the engine to be
      $|\{i("in the course of")} computing the Numbers to an indefinite extent, from
      $|the very beginning; and that we merely single out, by way of example,
      $|\{i("one amongst")} the successive but distinct series’ of computations it is
      $|thus performing. Where the \{m("B")}’s are fractional, it must be understood
      $|that they are computed and appear in the notation of \{i("decimal")} fractions.
      $|Indeed this is a circumstance that should be noticed with reference to all
      $|calculations. In any of the examples already given in the translation and in
      $|the Notes, some of the \{i("data")}, or of the temporary or permanent results,
      $|might be fractional, quite as probably as whole numbers. But the arrangements
      $|are so made, that the nature of the processes would be the same as for whole
      $|numbers.
    )
    |> par,
    (
      $|In the above table and diagram we are not considering the \{i("signs")} of any
      $|of the \{m("B")}’s, merely their numerical magnitude. The engine would bring
      $|out the sign for each of them correctly of course, but we cannot enter on
      $|\{i("every")} additional detail of this kind, as we might wish to do. The
      $|circles for the signs are therefore intentionally left blank in the diagram.
    )
    |> par,
    (
      $|Operation-cards 1, 2, 3, 4, 5, 6 prepare \{prepared}. Thus, Card 1 multiplies
      $|\{i("two")} into \{m("n")}, and the three \{i("Receiving")} Variable-cards
      $|belonging respectively to \{mv(4)}, \{mv(5)}, \{mv(6)}, allow the result
      $|\{m("2n")} to be placed on each of these latter columns (this being a case in
      $|which a triple receipt of the result is needed for subsequent purposes); we
      $|see that the upper indices of the two Variables used, during Operation 1,
      $|remain unaltered.
    )
    |> par,
    (
      $|We shall not go through the details of every operation singly, since the table
      $|and diagram sufficiently indicate them; we shall merely notice some few
      $|peculiar cases.
    )
    |> par,
    (
      $|By Operation 6, a \{i("positive")} quantity is turned into a \{i("negative")}
      $|quantity, by simply subtracting the quantity from a column which has only zero
      $|upon it. (The sign at the top of \{mv(3)} would become—during this process.)
    )
    |> par,
    (
      $|Operation 7 will be unintelligible, unless it be remembered that if we were
      $|calculating for \{m("n = 1")} instead of \{m("n = 4")}, Operation 6 would have
      $|completed the computation of \{b("1")} itself; in which case the engine,
      $|instead of continuing its processes, would have to put \{b("1")} on \{mv(21)};
      $|and then either to stop altogether, or to begin Operations 1, 2.…7 all over
      $|again for value of \{m("n(= 2)")}, in order to enter on the computation of
      $|\{b("3")}; (having hovever taken care, previous to this recommencement, to make
      $|number on \{mv(3)} equal to \{i("two")}, by the addition of unity to the former
      $|\{m("n = 1")} on that column). Now Operation 7 must either bring out a result
      $|equal to zero (if \{m("n = 1")}); or a result \{i("greater")} than
      $|\{i("zero")}, as in the present case; and the engine follows the one or the
      $|other of the two courses just explained, contingently on the one or the other
      $|result of Operation 7. In order fully to perceive the necessity of this
      $|\{i("experimental")} operation, it is important to keep in mind what was
      $|pointed out, that we are not treating a perfectly isolated and independent
      $|computation, but one out of a series of antecedent and prospective
      $|computations.
    )
    |> par,
    (
      $|Cards 8, 9, 10 produce \{produced}. In Operation 9 we see an example of an
      $|upper index which again becomes a value after having passed from preceding
      $|values to zero. \{mv(11)} has sucessively been \{mpv(0, 11)}, \{mpv(1, 11)},
      $|\{mpv(2, 11)}, \{mpv(0, 11)}, \{mpv(3, 11)}; and, from the nature of the office
      $|which \{mv(11)} performs in the calculation, its index will continue to go
      $|through further changes of the same description, which, if examined, will be
      $|found to be regular and periodic.
    )
    |> par,
    (
      $|Card 12 has to perform the same office as Card 7 did in the preceding section;
      $|since, if \{m("n")} had been \{m("= 2")}, the 11th operation would have
      $|completed the computation of \{b("3")}.
    )
    |> par,
    (
      $|Cards 13 to 20 make \{m("A_3")}. Since \{m("A_(2n-1)")} always consists of
      $|\{m("2n - 1")} factors, \{m("A_3")} has three factors; and it will be seen
      $|that Cards 13, 14, 15, 16 make the second of these factors, and then multiply
      $|it with the first; and that 17, 18, 19, 20 make the third factor, and then
      $|multiply this with the product of the two former factors.
    )
    |> par,
    (
      $|Card 23 has the office of Cards 11 and 7 to perform, since if \{m("n")} were
      $|\{m("= 3")}, the 21st and 22nd operations would complete the computation of
      $|\{b("5")}. As our case is \{b("7")}, the computation will continue one more
      $|stage; and we must now direct attention to the fact, that in order to compute
      $|\{m("A_7")} it is merely necessary precisely to repeat the group of Operations
      $|13 to 20; and then, in order to complete the computation of \{b("7")}, to
      $|repeat Operations 21, 22.
    )
    |> par,
    (
      $|It will be perceived that every unit added to \{m("n")} in \{b("2n-1")},
      $|entails an additional repetition of operations (13…23) for the computation of
      $|\{b("2n-1")}. Not only are all the \{i("operations")} precisely the same
      $|however for every such repetition, but they require to be respectively supplied
      $|with numbers from the very \{i("same pairs of columns")}; with only the one
      $|exception of Operation 21; which will of course need \{b("5")} (from
      $|\{mv(23)}) instead of \{b("3")} (from \{mv(22)}). This identity in the
      $|\{i("columns")} which supply the requisite numbers, must not be confounded with
      $|identity in the \{i("values")} those columns have upon them and give out to
      $|the mill. Most of those values undergo alterations during a performance of the
      $|operations (13.…23), and consequently the columns present a new set of values
      $|for the \{i("next")} performance of (13….23) to work on.
    )
    |> par,
    (
      $|At the termination of the \{i("repetition")} of operations (13…23) in computing
      $|\{b("7")}, the alterations in the values on the Variables are, that
      $|\{alterations} In this state the only remaining processes are first: to
      $|transfer the value which is on \{mv(13)}, to \{mv(24)}; and secondly to reduce
      $|\{mv(6)}, \{mv(7)}, \{mv(13)} to zero, and to add\{millions} \{i("one")} to
      $|\{mv(3)}, in order that the engine may be ready to commence computing
      $|\{b("9")}. Operations 24 and 25 accomplish these purposes. It may be thought
      $|anomalous that Operation 25 is represented as leaving the upper index of
      $|\{mv(3)} still = unity. But it must be remembered that these indices always
      $|begin anew for a separate calculation, and that Operation 25 places upon
      $|\{mv(3)} the \{i("first")} value \{i("for the new calculation")}.
    )
    |> par,
    (
      $|It should be remarked, that when the group (13…23) is \{i("repeated")}, changes
      $|occur in some of the upper indices during the course of the repetition: for
      $|example, \{mpv(3, 6)} would become \{mpv(4, 6)} and \{mpv(5, 6)}.
    )
    |> par,
    (
      $|We thus see that when \{m("n = 1")}, nine Operation-cards are used; that when
      $|\{m("n = 2")}, fourteen Operation-cards are used; and that when
      $|\{m("n > 2")}, twenty-five Operation-cards are used; but that no \{i("more")}
      $|are needed, however great \{m("n")} may be; and not only this, but that these
      $|same twenty-five cards suffice for the successive computation of all the
      $|Numbers from \{b("1")} to \{b("2n-1")} inclusive. With respect to the number
      $|of \{i("Variable")}-cards, it will be remembered, from the explanations in
      $|previous Notes, that an average of three such cards to each \{i("operation")}
      $|(not however to each Operation-\{i("card")}) is the estimate. According to this
      $|the computation of \{b("1")} will require twenty-seven Variable-cards;
      $|\{b("3")} forty-two such cards; \{b("5")} seventy-five; and for every
      $|succeeding \{m("B")} after \{b("5")}, there would be thirty-three additional
      $|Variable-cards (since each repetition of the group (13…23) adds eleven to the
      $|number of operations required for computing the previous \{m("B")}). But we
      $|must now explain, that whenever there is a \{i("cycle of operations")}, and if
      $|these merely require to be supplied with numbers
      $|\{i("from the same pairs of columns")} and likewise each operation to place its
      $|\{i("result")} on the \{i("same")} column for every repetition of the whole
      $|group, the process then admits of a \{i("cycle of Variable-cards")} for
      $|effecting its purposes. There is obviously much more symmetry and simplicity in
      $|the arrangements, when cases do admit of repeating the Variable as well as the
      $|Operation-cards. Our present example is of this nature. The only exception to a
      $|\{i("perfect identity")} in \{i("all")} the processes and columns used, for
      $|every repetition of Operations (13…23) is, that Operation 21 always requires
      $|one of its factors from a new column, and Operation 24 always puts its result
      $|on a new column. But as these variations follow the same law at each
      $|repetition, (Operation 21 always requiring its factor from a column
      $|\{i("one")} in advance of that which it used the previous time, and Operation
      $|24 always putting its result on the column \{i("one")} in advance of that which
      $|received the previous result), they are easily provided for in arranging the
      $|recurring group (or cycle) of Variable-cards.
    )
    |> par,
    (
      $|We may here remark that the average estimate of three Variable-cards coming
      $|into use to each operation, is not to be taken as an absolutely and literally
      $|correct amount for all cases and circumstances. Many special circumstances,
      $|either in the nature of a problem, or in the arrangements of the engine under
      $|certain contingencies, influence and modify this average to a greater or less
      $|extent. But it is a very safe and correct \{i("general")} rule to go upon. In
      $|the preceding case it will give us seventy-five Variable-cards as the total
      $|number which will be necessary for computing any \{m("B")} after \{b("3")}.
      $|This is very nearly the precise amount really used, but we cannot here enter
      $|into the minutiæ of the few particular circumstances which occur in this
      $|example (as indeed at some one stage or other of probably most computations) to
      $|modify slightly this number.
    )
    |> par,
    (
      $|It will be obvious that the very \{i("same")} seventy-five Variable-cards may
      $|be repeated for the computation of every succeeding Number, just on the same
      $|principle as admits of the repetition of the thirty-three Variable-cards of
      $|Operations (13…23) in the computation of any \{i("one")} Number. Thus there
      $|will be a \{i("cycle of a cycle")} of Variable-cards.
    )
    |> par,
    (
      $|If we now apply the notation for cycles, as explained in Note E, we may
      $|express the operations for computing the Numbers of Bernoulli in the following
      $|manner:— \{cycles_table()}
    )
    |> par,
    (
      $|Again, \{every_number} represents the total operations for computing every
      $|number in succession, from \{b("1")} to \{b("2n-1")} inclusive.
    )
    |> par,
    (
      $|In this formula we see a \{i("varying cycle")} of the \{i("first")} order, and
      $|an ordinary cycle of the \{i("second")} order. The latter cycle in this case
      $|includes in it the varying cycle.
    )
    |> par,
    (
      $|On inspecting the ten Working-Variables of the diagram, it will be perceived,
      $|that although the \{i("value")} on any one of them (excepting \{mv(4)} and
      $|\{mv(5)}) goes through a series of changes, the \{i("office")} which each
      $|performs is in this calculation \{i("fixed")} and \{i("invariable")}. Thus
      $|\{mv(6)} always prepares the \{i("numerators")} of the factors of any
      $|\{m("A")}; \{mv(7)} the \{i("denominators")}. \{mv(8)} always receives the
      $|\{m("(2n - 3)")}th factor of \{m("A_(2n-1)")}, and \{mv(9)} the
      $|\{m("(2n - 1)")}th. \{mv(10)} always decides which of two courses the
      $|succeeding processes are to follow, by feeling for the value of \{m("n")}
      $|through means of a subtraction; and so on; but we shall not enumerate further.
      $|It is desirable in all calculations, so to arrange the processes, that the
      $|\{i("offices")} performed by the Variables may be as uniform and fixed as
      $|possible.
    )
    |> par,
    (
      $|Supposing that it was desired not only to tabulate \{bold_b(1)}, \{bold_b(3)},
      $|&c., but \{bold_a(0)}, \{bold_a(1)}, &c.; we have only then to appoint another
      $|series of Variables, \{mv(41)}, \{mv(42)}, &c., for receiving these latter
      $|results as they are successively produced upon \{mv(11)}. Or again, we may,
      $|instead of this, or in addition to this second series of results, wish to
      $|tabulate the value of each successive \{i("total")} term of the series (8),
      $|viz: \{bold_a(0)}, \{m("bold(upright(A))_1 bold(upright(B))_1")},
      $|\{m("bold(upright(A))_3 bold(upright(B))_3")}, &c. We have then merely to
      $|multiply each \{m("bold(upright(B))")} with each corresponding
      $|\{m("bold(upright(A))")}, as produced; and to place these successive products
      $|on Result-columns appointed for the purpose.
    )
    |> par,
    (
      $|The formula \{eq("g8")} is interesting in another point of view. It is one
      $|particular case of the general Integral of the following Equation of Mixed
      $|Differences:— \{mixed} for certain special suppositions respecting \{m("z")},
      $|\{m("x")} and \{m("n")}.
    )
    |> par,
    (
      $|The \{i("general")} integral itself is of the form, \{general} and it is
      $|worthy of remark, that the engine might (in a manner more or less similar to
      $|the preceding) calculate the value of this formula upon most \{i("other")}
      $|hypotheses for the functions in the integral, with as much, or (in many cases)
      $|with more, ease than it can formula \{eq("g8")}.
    )
    |> par,
    signature("A. L. L."),
  ]
}
