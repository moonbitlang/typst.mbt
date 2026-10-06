// Note F (Scientific Memoirs, vol. 3, pages 720 to 722), verbatim from the
// Wikisource transcription.

///|
fn note_f() -> Array[&IntoContent] {
  let ops = "(times, times, -)"
  let first = numbered("a x_0 + b x_1 + c x_2 + d x_3 + . dots.h . = p", "f1")
  let second = numbered(
    "a^1 x_0 + b^1 x_1 + c^1 x_2 + d^1 x_3 + . dots.h . = p^1", "f2",
  )
  let more = disp("\{etc} quad \{etc} quad \{etc} quad \{etc}")
  let eliminated = disp(
    (
      #|& (a^1 a - a a^1) x_0 + (a^1 b - a b^1) x_1 + (a^1 c - a c^1) x_2 + \
      #|+ & (a^1 d - a d^1) x_3 + dots.h dots.h dots.h dots.h dots.h dots.h dots.h = a^1 p - a p^1,
    ),
  )
  let twenty = disp("10\{ops}, 10\{ops}, = 20\{ops}.")
  let ninety = disp("9.10\{ops} = 90\{ops}.")
  let seventy_two = disp("8.9\{ops} = 72\{ops}.")
  let fifty_six = disp("7.8\{ops} = 56\{ops},")
  let total = disp(
    "9.10 + 8.9 + 7.8 + 6.7. + 5.6 + 4.5 + 3.4 + 2.3 + 1.2 = 330.",
  )
  let clausen = cited("clausen-406")
  let ten = m("10\{ops}")
  [
    (
      $|There is in existence a beautiful woven portrait of Jacquard, in the
      $|fabrication of which 24,000 cards were required.
    )
    |> indented,
    (
      $|The power of \{i("repeating")} the cards, alluded to by M. Menabrea in page
      $|680, and more fully explained in Note C, reduces to an immense extent the
      $|number of cards required. It is obvious that this mechanical improvement is
      $|especially applicable wherever \{i("cycles")} occur in the mathematical
      $|operations, and that, in preparing data for calculations by the engine, it is
      $|desirable to arrange the order and combination of the processes with a view to
      $|obtain them as much as possible \{i("symmetrically")} and in cycles, in order
      $|that the mechanical advantages of the \{i("backing")} system may be applied to
      $|the utmost. It is here interesting to observe the manner in which the value of
      $|an \{i("analytical")} resource is met and enhanced by an ingenious
      $|\{i("mechanical")} contrivance. We see in it an instance of one of those mutual
      $|\{i("adjustments")} between the purely mathematical and the mechanical
      $|departments, mentioned in Note A. as being a main and essential condition of
      $|success in the invention of a calculating engine. The nature of the resources
      $|afforded by such adjustments would be of two principal kinds. In some cases, a
      $|difficulty (perhaps in itself insurmountable) in the one department, would be
      $|overcome by facilities in the other; and sometimes (as in the present case) a
      $|strong point in the one, would be rendered still stronger and more available,
      $|by combination with a corresponding strong point in the other.
    )
    |> par,
    (
      $|As a mere example of the degree to which the combined systems of cycles and of
      $|backing can diminish the \{i("number")} of cards requisite, we shall choose a
      $|case which places it in strong evidence, and which has likewise the advantage
      $|of being a perfectly different \{i("kind")} of problem from those that are
      $|mentioned in any of the other Notes. Suppose it be required to eliminate nine
      $|variables from ten simple equations of the form— \{first} \{second} \{more}
    )
    |> par,
    (
      $|We should explain, before proceeding, that it is not our object to consider
      $|this problem with reference to the actual arrangement of the data on the
      $|Variables of the engine, but simply as an abstract question of the
      $|\{i("nature")} and \{i("number")} of the \{i("operations")} required to be
      $|performed during its complete solution.
    )
    |> indented,
    (
      $|The first step would be the elimination of the first unknown quantity
      $|\{m("x_0")} between the two first equations. This would be obtained by the
      $|form— \{eliminated} for which the operations \{ten} would be needed.
      $|The second step would be the elimination of \{m("x_0")}, between the second
      $|and third equations, for which the operations would be precisely the same. We
      $|should then have had altogether the following operations:— \{twenty}
      $|Continuing in the same manner, the total number of operations for the complete
      $|elimination of \{m("x_0")} between all the successive pairs of equations,
      $|would be— \{ninety} We should then be left with nine simple equations of nine
      $|variables from which to eliminate the next variable \{m("x_1")}; for which the
      $|total of the processes would be— \{seventy_two} We should then be left with
      $|eight simple equations of eight variables from which to eliminate \{m("x_2")},
      $|for which the processes would be— \{fifty_six} and so on. The total operations
      $|for the elimination of all the variables would thus be— \{total} So that
      $|\{i("three")} Operation-cards would perform the office of 330 such cards.
    )
    |> par,
    (
      $|If we take \{m("n")} simple equations containing \{m("n - 1")} variables,
      $|\{m("n")} being a number unlimited in magnitude, the case becomes still more
      $|obvious, as the same three cards might then take the place of thousands or
      $|millions of cards.
    )
    |> par,
    (
      $|We shall now draw further attention to the fact, already noticed, of its being
      $|by no means necessary that a formula proposed for solution should ever have
      $|been actually worked out, as a condition for enabling the engine to solve it.
      $|Provided we know the \{i("series of operations")} to be gone through, that is
      $|sufficient. In the foregoing instance this will be obvious enough on a slight
      $|consideration. And it is a circumstance which deserves particular notice, since
      $|herein may reside a latent value of such an engine almost incalculable in its
      $|possible ultimate results. We already know that there are functions whose
      $|numerical value it is of importance for the purposes both of abstract and of
      $|practical science to ascertain, but whose determination requires processes so
      $|lengthy and so complicated, that, although it is possible to arrive at them
      $|through great expenditure of time, labour and money, it is yet on these
      $|accounts practically almost unattainable; and we can conceive there being some
      $|results which it may be \{i("absolutely impossible")} in practice to attain
      $|with any accuracy, and whose precise determination it may prove highly
      $|important for some of the future wants of science in its manifold, complicated
      $|and rapidly-developing fields of inquiry, to arrive at.
    )
    |> par,
    (
      $|Without, however, stepping into the region of conjecture, we will mention a
      $|particular problem which occurs to us at this moment as being an apt
      $|illustration of the use to which such an engine may be turned for determining
      $|that which human brains find it difficult or impossible to work out unerringly.
      $|In the solution of the famous problem of the Three Bodies, there are, out of
      $|about 295 coefficients of lunar perturbations given by M. Clausen
      $|(Astro\{Super("e")}. Nachrichten, No. 406\{clausen}) as the result of the
      $|calculations by Burg, of two by Damoiseau, and of one by Burckhardt, fourteen
      $|coefficients that differ in the nature of their algebraic sign; and out of the
      $|remainder there are only 101 (or about one-third) that agree precisely both in
      $|signs and in amount. These discordances, which are generally small in
      $|individual magnitude, may arise either from an erroneous determination of the
      $|abstract coefficients in the development of the problem, or from discrepancies
      $|in the data deduced from observation, or from both causes combined. The former
      $|is the most ordinary source of error in astronomical computations, and this the
      $|engine would entirely obviate.
    )
    |> par,
    (
      $|We might even invent laws for series or formulæ in an arbitrary manner, and set
      $|the engine to work upon them, and thus deduce numerical results which we might
      $|not otherwise have thought of obtaining. But this would hardly perhaps in any
      $|instance be productive of any great practical utility, or calculated to rank
      $|higher than as a kind of philosophical amusement.
    )
    |> par,
    signature("A. A. L."),
  ]
}
