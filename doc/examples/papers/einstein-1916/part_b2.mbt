// Part B, § 9 to § 12. `chr(a, b)` is Christoffel's symbol of the second
// kind (braces), `chf(a, b)` the one of the first kind (brackets); both are
// defined in `main.mbt`.

///|
fn sec_9() -> Array[&IntoContent] {
  [
    sec("Equation of the geodetic line (or of point-motion).", 9),
    Prose(
      (
        $|As the "line element" \{m("d s")} is a definite magnitude
        $|independent of the co-ordinate system, we have also between two
        $|points \{m("P_1")} and \{m("P_2")} of a four dimensional continuum a
        $|line for which \{m("integral d s")} is an extremum (geodetic line),
        $|\{em("i.e.")}, one which has got a significance independent of the
        $|choice of co-ordinates.
        $|
        $|Its equation is
      ),
    ),
    eq("delta {limits(integral)_(P_1)^(P_2) d s} = 0", "20"),
    Prose(
      (
        $|From this equation, we can in a well-known way deduce 4 total
        $|differential equations which define the geodetic line; this
        $|deduction is given here for the sake of completeness.
        $|
        $|Let \{m("lambda")}, be a function of the co-ordinates
        $|\{m("x_nu")}; this defines a series of surfaces which cut the
        $|geodetic line sought-for as well as all neighbouring lines from
        $|\{m("P_1")} to \{m("P_2")}. We can suppose that all such curves are
        $|given when the value of its co-ordinates \{m("x_nu")} are given in
        $|terms of \{m("lambda")}. The sign \{m("delta")} corresponds to a
        $|passage from a point of the geodetic curve sought for to a point of
        $|the contiguous curve, both lying on the same surface
        $|\{m("lambda")}.
        $|
        $|Then \{r("20")} can be replaced by
      ),
    ),
    eq(
      (
        #|cases(gap: #0.9em,
        #|  display(limits(integral)_(lambda_1)^(lambda_2) delta w med d lambda = 0),
        #|  display(w^2 = g_(mu nu) (d x_mu)/(d lambda) (d x_nu)/(d lambda)))
      ),
      "20a",
    ),
    Prose("But"),
    dm(
      (
        #|delta w = 1/w {1/2 (partial g_(mu nu))/(partial x_sigma) (d x_mu)/(d lambda) (d x_nu)/(d lambda) delta x_sigma
        #|  + g_(mu nu) (d x_mu)/(d lambda) delta ((d x_nu)/(d lambda))}
      ),
    ),
    Prose(
      "So we get by the substitution of \{m("delta w")} in \{r("20a")}, remembering that",
    ),
    dm("delta ((d x_nu)/(d lambda)) = (d delta x_nu)/(d lambda)"),
    Prose("after partial integration,"),
    eq(
      (
        #|cases(gap: #0.9em,
        #|  display(limits(integral)_(lambda_1)^(lambda_2) d lambda med kappa.alt_sigma delta x_sigma = 0),
        #|  display(kappa.alt_sigma = d/(d lambda) {g_(mu nu)/w (d x_mu)/(partial lambda)}
        #|    - 1/(2 w) (partial g_(mu nu))/(partial x_sigma) (d x_mu)/(partial lambda) (d x_nu)/(partial lambda)))
      ),
      "20b",
    ),
    Prose(
      (
        $|From which it follows, since the choice of \{m("delta x_sigma")} is
        $|perfectly arbitrary that \{m("kappa.alt_sigma")} should vanish; Then
      ),
    ),
    eq("kappa.alt_sigma = 0", "20c"),
    Prose(
      (
        $|are the equations of geodetic line; since along the geodetic line
        $|considered we have \{m("d s = 0")}, we can choose the parameter
        $|\{m("lambda")}, as the length of the arc measured along the geodetic
        $|line. Then \{m("w = 1")}, and we would get in place of \{r("20c")}
      ),
    ),
    dm(
      (
        #|g_(mu nu) (d^2 x_mu)/(d s^2)
        #|  + (partial g_(mu nu))/(partial x_sigma) (d x_sigma)/(partial lambda) (d x_mu)/(partial lambda)
        #|  - 1/2 (partial g_(mu nu))/(partial x_sigma) (d x_mu)/(partial lambda) (d x_nu)/(partial lambda) = 0
      ),
    ),
    Prose("Or by merely changing the notation suitably,"),
    eq(
      "g_(alpha sigma) (d^2 x_alpha)/(d s^2) + chf(mu nu, sigma) (d x_mu)/(d s) (d x_nu)/(d s) = 0",
      "20d",
    ),
    Prose("where we have put, following \{sc("Christoffel")},"),
    eq(
      (
        #|chf(mu nu, sigma) = 1/2 ((partial g_(mu sigma))/(partial x_nu)
        #|  + (partial g_(nu sigma))/(partial x_mu) - (partial g_(mu nu))/(partial x_sigma))
      ),
      "21",
    ),
    Prose(
      (
        $|Multiply finally \{r("20d")} with \{m("g^(sigma tau)")} (outer
        $|multiplication with reference to \{m("tau")}, and inner with respect
        $|to \{m("sigma")}) we get at last the final form of the equation of
        $|the geodetic line —
      ),
    ),
    eq(
      "(d^2 x_tau)/(d s^2) + chr(mu nu, tau) (d x_mu)/(d s) (d x_nu)/(d s) = 0",
      "22",
    ),
    Prose("Here we have put, following \{sc("Christoffel")},"),
    eq("chr(mu nu, tau) = g^(tau alpha) chf(mu nu, alpha)", "23"),
  ]
}

///|
fn sec_10() -> Array[&IntoContent] {
  [
    sec("Formation of Tensors through Differentiation.", 10),
    Prose(
      (
        $|Relying on the equation of the geodetic line, we can now easily
        $|deduce laws according to which new tensors can be formed from given
        $|tensors by differentiation. For this purpose, we would first
        $|establish the general covariant differential equations. We achieve
        $|this through a repeated application of the following simple law. If
        $|a certain curve be given in our continuum whose points are
        $|characterised by the arc-distances \{m("s")} measured from a fixed
        $|point on the curve, and if further \{m("phi")}, be an invariant
        $|space function, then \{m("d phi slash d s")} is also an invariant.
        $|The proof follows from the fact that \{m("d phi")} as well as
        $|\{m("d s")}, are both invariants.
        $|
        $|Since
      ),
    ),
    dm("(d phi)/(d s) = (partial phi)/(partial x_mu) (d x_mu)/(d s)"),
    Prose("so that"),
    dm("psi = (partial phi)/(partial x_mu) (d x_mu)/(d s)"),
    Prose(
      (
        $|is also an invariant for all curves which go out from a point in the
        $|continuum, \{em("i.e.")}, for any choice of the vector
        $|\{m("d x_mu")}. From which follows immediately that
      ),
    ),
    eq("A_mu = (partial phi)/(partial x_mu)", "24"),
    Prose(
      (
        $|is a covariant four-vector (gradient of \{m("phi")}).
        $|
        $|According to our law, the differential-quotient
      ),
    ),
    dm("chi = (d psi)/(d s)"),
    Prose(
      (
        $|taken along any curve is likewise an invariant. Substituting the
        $|value of \{m("phi")}, we get
      ),
    ),
    dm(
      (
        #|chi = (partial^2 phi)/(partial x_mu partial x_nu) (d x_mu)/(d s) (d x_nu)/(d s)
        #|  + (partial phi)/(partial x_mu) (d^2 x_mu)/(d s^2)
      ),
    ),
    Prose(
      (
        $|Here however we can not at once deduce the existence of any tensor.
        $|If we however take that the curves along which we are
        $|differentiating are geodesics, we get from it by replacing
        $|\{m("d^2 x_nu slash d s^2")} according to \{r("22")}
      ),
    ),
    dm(
      (
        #|chi = {(partial^2 phi)/(partial x_mu partial x_nu)
        #|  - chr(mu nu, tau) (partial phi)/(partial x_tau)} (d x_mu)/(d s) (d x_nu)/(d s)
      ),
    ),
    Prose(
      (
        $|Prom the interchangeability of the differentiation with regard to
        $|\{m("mu")} and \{m("nu")}, and also according to \{r("23")} and
        $|\{r("21")} we see that the bracket \{m("chr(mu nu, tau)")} is
        $|symmetrical with respect to \{m("mu")} and \{m("nu")}.
        $|
        $|As we can draw a geodetic line in any direction from any point in
        $|the continuum, \{m("d x_mu slash d s")} is thus a four-vector, with
        $|an arbitrary ratio of components, so that it follows from the
        $|results of \{s(7)} that
      ),
    ),
    eq(
      (
        #|A_(mu nu) = (partial^2 phi)/(partial x_mu partial x_nu)
        #|  - chr(mu nu, tau) (partial phi)/(partial x_tau)
      ),
      "25",
    ),
    Prose(
      (
        $|is a covariant tensor of the second rank. We have thus got the
        $|result that out of the covariant tensor of the first rank
      ),
    ),
    dm("A_mu = (partial phi)/(partial x_mu)"),
    Prose("we can get by differentiation a covariant tensor of 2nd rank"),
    eq(
      "A_(mu nu) = (partial A_mu)/(partial x_nu) - chr(mu nu, tau) A_tau", "26",
    ),
    Prose(
      (
        $|We call the tensor \{m("A_(mu nu)")} the "\{em("extension")}" of the
        $|tensor \{m("A_mu")}. Then we can easily show that this combination
        $|also leads to a tensor, when the vector \{m("A_mu")} is not
        $|representable as a gradient. In order to see this we first remark
        $|that
      ),
    ),
    dm("psi (partial phi)/(partial x_mu)"),
    Prose(
      (
        $|is a covariant four-vector when \{m("psi")} and \{m("phi")} are
        $|scalars. This is also the case for a sum of four such terms: —
      ),
    ),
    dm(
      (
        #|S_mu = psi^((1)) (partial phi^((1)))/(partial x_mu) + dot.c + dot.c
        #|  + psi^((4)) (partial phi^((4)))/(partial x_mu)
      ),
    ),
    Prose(
      (
        $|when \{m("psi^((1)) phi^((1)) thin dots thin psi^((4)) phi^((4))")} are
        $|scalars. Now it is however clear that every covariant four-vector is
        $|representable in the form of \{m("S_mu")}.
        $|
        $|If for example \{m("A_mu")} is a four-vector whose components are
        $|any given functions of \{m("x_nu")}, we have, (with reference to the
        $|chosen co-ordinate system) only to put
      ),
    ),
    dm(
      (
        #|psi^((1)) &= A_1, & quad phi^((1)) &= x_1, \
        #|psi^((2)) &= A_2, & quad phi^((2)) &= x_2, \
        #|psi^((3)) &= A_3, & quad phi^((3)) &= x_3, \
        #|psi^((4)) &= A_4, & quad phi^((4)) &= x_4,
      ),
    ),
    Prose(
      (
        $|in order to arrive at the result that \{m("S_mu")} is equal to
        $|\{m("A_mu")}.
        $|
        $|In order to prove then that \{m("A_(mu nu)")} in a tensor when on
        $|the right side of \{r("26")} we substitute any covariant four-vector
        $|for \{m("A_mu")} we have only to show that this is true for the
        $|four-vector \{m("S_mu")}. For this latter case, however, a glance on
        $|the right hand side of \{r("26")} will show that we have only to
        $|bring forth the proof for the case when
      ),
    ),
    dm("A_mu = psi (partial phi)/(partial x_mu)"),
    Prose("Now the right hand side of \{r("25")} multiplied by \{m("psi")} is"),
    dm(
      (
        #|psi (partial^2 phi)/(partial x_mu partial x_nu)
        #|  - chr(mu nu, tau) psi (partial phi)/(partial x_tau)
      ),
    ),
    Prose("which has a tensor character. Similarly,"),
    dm("(partial psi)/(partial x_mu) (partial phi)/(partial x_nu)"),
    Prose(
      (
        $|is also a tensor (outer product of two four-vectors). Through
        $|addition follows the tensor character of
      ),
    ),
    dm(
      (
        #|partial/(partial x_nu) (psi (partial phi)/(partial x_mu))
        #|  - chr(mu nu, tau) (psi (partial phi)/(partial x_tau))
      ),
    ),
    Prose("Thus we get the desired proof for the four-vector,"),
    dm("psi (partial phi)/(partial x_mu)"),
    Prose(
      (
        $|hence for any four-vectors \{m("A_mu")} as shown above. —
        $|
        $|With the help of the extension of the four-vector, we can easily
        $|define "extension" of a covariant tensor of any rank. This is a
        $|generalisation of the extension of the four-vector. We confine
        $|ourselves to the case of the extension of the tensors of the 2nd
        $|rank for which the law of formation can be clearly seen.
        $|
        $|As already remarked every covariant tensor of the 2nd rank can be
        $|represented as a sum of the tensors of the type
        $|\{m("A_mu B_nu")}. It would therefore be sufficient to deduce the
        $|expression of extension, for one such special tensor. According to
        $|\{r("26")} we have the expressions
      ),
    ),
    dm(
      (
        #|(partial A_mu)/(partial x_sigma) - chr(sigma mu, tau) A_tau \
        #|(partial B_nu)/(partial x_sigma) - chr(sigma nu, tau) B_tau
      ),
    ),
    Prose(
      (
        $|are tensors. Through outer multiplication of the first with
        $|\{m("B_nu")} and the 2nd with \{m("A_mu")} we get tensors of the
        $|third rank. Their addition gives the tensor of the third rank
      ),
    ),
    eq(
      (
        #|A_(mu nu sigma) = (partial A_(mu nu))/(partial x_sigma)
        #|  - chr(sigma mu, tau) A_(tau nu) - chr(sigma nu, tau) A_(mu tau)
      ),
      "27",
    ),
    Prose(
      (
        $|where \{m("A_(mu nu) = A_mu B_nu")}. The right hand side of
        $|\{r("27")} is linear and homogeneous with reference to
        $|\{m("A_(mu nu)")}, and its first differential co-efficient so that
        $|this law of formation leads to a tensor not only in the case of a
        $|tensor of the type \{m("A_mu B_nu")} but also in the case of a
        $|summation for all such tensors, \{em("i.e")}, in the case of any
        $|covariant tensor of the second rank. We call
        $|\{m("A_(mu nu sigma)")} the extension of the tensor
        $|\{m("A_(mu nu)")}.
        $|
        $|It is clear that \{r("26")} and \{r("24")} are only special cases of
        $|\{r("27")} (extension of the tensors of the first and zero rank). In
        $|general we can get all special laws of formation of tensors from
        $|\{r("27")} combined with tensor multiplication.
      ),
    ),
  ]
}

///|
fn sec_11() -> Array[&IntoContent] {
  [
    sec("Some special cases of Particular Importance.", 11),
    Prose(
      (
        $|\{em("A few auxiliary lemmas concerning the fundamental tensor")}.
        $|We shall first deduce some of the lemmas much used afterwards.
        $|According to the law of differentiation of determinants, we have
      ),
    ),
    eq("d g = g^(mu nu) g med d g_(mu nu) = -g_(mu nu) g med d g^(mu nu)", "28"),
    Prose(
      (
        $|The last form follows from the first when we remember that
        $|\{m("g_(mu nu) g^(mu' nu) = delta_mu^(mu')")}, and therefore
        $|\{m("g_(mu nu) g^(mu nu) = 4")}. consequently
      ),
    ),
    dm("g_(mu nu) d g^(mu nu) + g^(mu nu) d g_(mu nu) = 0"),
    Prose("From \{r("28")}, it follows that"),
    eq(
      (
        #|1/sqrt(-g) (partial sqrt(-g))/(partial x_sigma)
        #|  = 1/2 (partial lg(-g))/(partial x_sigma)
        #|  = 1/2 g^(mu nu) (partial g_(mu nu))/(partial x_sigma)
        #|  = -1/2 g_(mu nu) (partial g^(mu nu))/(partial x_sigma)
      ),
      "29",
    ),
    Prose("Again, since"),
    dm("g_(mu sigma) g^(nu sigma) = delta_mu^nu"),
    Prose("we have, by differentiation,"),
    eq(
      (
        #|cases(gap: #0.7em,
        #|  quad g_(mu sigma) d g^(nu sigma) = -g^(nu sigma) d g_(mu sigma),
        #|  "bzw.",
        #|  quad display(g_(mu sigma) (partial g^(nu sigma))/(partial x_lambda)
        #|    = -g^(nu sigma) (partial g_(nu sigma))/(partial x_lambda)))
      ),
      "30",
    ),
    Prose(
      (
        $|By mixed multiplication with \{m("g^(sigma tau)")} and
        $|\{m("g_(nu lambda)")} respectively we obtain (changing the mode of
        $|writing the indices).
      ),
    ),
    eq(
      (
        #|cases(gap: #0.9em,
        #|  d g^(mu nu) &= -g^(mu alpha) g^(nu beta) d g_(alpha beta),
        #|  display((partial g^(mu nu))/(partial x_sigma))
        #|    &= display(-g^(mu alpha) g^(nu beta) (d g_(alpha beta))/(partial x_sigma)))
      ),
      "31",
    ),
    Prose("and"),
    eq(
      (
        #|cases(gap: #0.9em,
        #|  d g_(mu nu) &= -g_(mu alpha) g_(nu beta) d g^(alpha beta),
        #|  display((partial g_(mu nu))/(partial x_sigma))
        #|    &= display(-g_(mu alpha) g_(nu beta) (d g^(alpha beta))/(partial x_sigma)))
      ),
      "32",
    ),
    Prose(
      (
        $|The expression \{r("31")} allows a transformation which we shall
        $|often use; according to \{r("21")}
      ),
    ),
    eq(
      "(partial g_(alpha beta))/(partial x_sigma) = chf(alpha sigma, beta) + chf(beta sigma, alpha)",
      "33",
    ),
    Prose(
      (
        $|If we substitute this in the second of the formula \{r("31")}, we
        $|get, remembering \{r("23")},
      ),
    ),
    eq(
      (
        #|(partial g_(mu nu))/(partial x_sigma)
        #|  = -(g^(mu tau) chr(tau sigma, nu) + g^(nu tau) chr(tau sigma, mu))
      ),
      "34",
    ),
    Prose(
      "By substituting the right-hand side of \{r("34")} in \{r("29")}, we get",
    ),
    eq(
      "1/sqrt(-g) (partial sqrt(-g))/(partial x_sigma) = chr(mu sigma, mu)", "29a",
    ),
    indent(),
    Prose(
      (
        $|\{em("Divergence of the contravariant four-vector")}. Let us
        $|multiply \{r("26")} with the contravariant fundamental tensor
        $|\{m("g^(mu nu)")} (inner multiplication), then by a transformation
        $|of the first member, the right-hand side takes the form
      ),
    ),
    dm(
      (
        #|partial/(partial x_nu) (g^(mu nu) A_mu) - A_mu (partial g^(mu nu))/(partial x_nu)
        #|  - 1/2 g^(tau alpha) ((partial g^(mu alpha))/(partial x_nu)
        #|  + (partial g_(nu alpha))/(partial x_mu) - (partial g_(mu nu))/(partial x_alpha)) g^(mu nu) A_tau
      ),
    ),
    Prose(
      "According to \{r("31")} and \{r("29")} the last member can take the form",
    ),
    dm(
      (
        #|1/2 (partial g^(tau nu))/(partial x_nu) A_tau + 1/2 (partial g^(tau mu))/(partial x_mu) A_tau
        #|  + 1/sqrt(-g) (partial sqrt(-g))/(partial x_alpha) g^(mu nu) A_tau
      ),
    ),
    Prose(
      (
        $|Both the first members of that expression, and the second member of
        $|the expression above cancel each other, since the naming of the
        $|summation-indices is immaterial. The last member of that can then be
        $|united with first expression above. If we put
      ),
    ),
    dm("g^(mu nu) A_mu = A^nu"),
    Prose(
      (
        $|where \{m("A^nu")} as well as \{m("A_mu")} are vectors which can be
        $|arbitrarily chosen, we obtain finally
      ),
    ),
    eq("Phi = 1/sqrt(-g) partial/(partial x_nu) (sqrt(-g) A^nu)", "35"),
    Prose(
      (
        $|This scalar is the Divergence of the contravariant four-vector
        $|\{m("A^nu")}.
        $|
        $|\{em("“Rotation” of the (covariant) four-vector.")} The second
        $|member in \{r("26")} is symmetrical in the indices \{m("mu")}, and
        $|\{m("nu")}, Hence \{m("A_(mu nu) - A_(nu mu)")} is an
        $|anti-symmetrical tensor built up in a very simple manner. We obtain
      ),
    ),
    eq(
      "B_(mu nu) = (partial A_mu)/(partial x_nu) - (partial A_nu)/(partial x_mu)",
      "36",
    ),
    indent(),
    Prose(
      (
        $|\{em("Anti-symmetrical Extension of a Six-vector")}. If we apply
        $|the operation \{r("27")} on an anti-symmetrical tensor of the second
        $|rank \{m("A_(mu nu)")}, and form all the equations arising from the
        $|cyclic interchange of the indices \{m("mu, nu, sigma")}, and add all
        $|them, we obtain a tensor of the third rank
      ),
    ),
    eq(
      (
        #|B_(mu nu sigma) = A_(mu nu sigma) + A_(nu sigma mu) + A_(sigma mu nu)
        #|  = (partial A_(mu nu))/(partial x_sigma) + (partial A_(nu sigma))/(partial x_mu)
        #|  + (partial A_(sigma mu))/(partial x_nu)
      ),
      "37",
    ),
    Prose(
      (
        $|from which it in easy to see that the tensor is anti-symmetrical.
        $|
        $|\{em("Divergence of the Six-vector")}. If \{r("27")} is multiplied
        $|by \{m("g^(mu alpha) g^(nu beta)")} (mixed multiplication), then a
        $|tensor is obtained. The first member of the right hand side of
        $|\{r("27")} can be written in the form
      ),
    ),
    dm(
      (
        #|partial/(partial x_sigma) (g^(mu alpha) g^(nu beta) A_(mu nu))
        #|  - g^(mu alpha) (partial g^(nu beta))/(partial x_sigma) A_(mu nu)
        #|  - g^(nu beta) (partial g^(mu alpha))/(partial x_sigma) A_(mu nu)
      ),
    ),
    Prose(
      (
        $|If we replace \{m("g^(mu alpha) g^(nu beta) A_(mu nu sigma)")} by
        $|\{m("A_sigma^(alpha beta)")},
        $|\{m("g^(mu alpha) g^(nu beta) A_(mu nu)")} by
        $|\{m("A^(alpha beta)")} and replace in the transformed first member
      ),
    ),
    dm(
      (
        #|(partial g^(nu beta))/(partial x_sigma) quad "and" quad
        #|  (partial g^(mu alpha))/(partial x_sigma)
      ),
    ),
    Prose(
      (
        $|with the help of \{r("34")}, then from the right-hand side of
        $|\{r("27")} there arises an expression with seven terms, of which
        $|four cancel. There remains
      ),
    ),
    eq(
      (
        #|A_sigma^(alpha beta) = (partial A^(alpha beta))/(partial x_sigma)
        #|  + chr(sigma kappa.alt, alpha) A^(kappa.alt beta)
        #|  + chr(sigma kappa.alt, beta) A^(alpha kappa.alt)
      ),
      "38",
    ),
    Prose(
      (
        $|This is the expression for the extension of a contravariant tensor
        $|of the second rank; extensions can also be formed for corresponding
        $|contravariant tensors of higher and lower ranks.
        $|
        $|We remark that in the same way, we can also form the extension of a
        $|mixed tensor \{m("A_mu^alpha")}:
      ),
    ),
    eq(
      (
        #|A_(mu sigma)^alpha = (partial A_mu^alpha)/(partial x_sigma)
        #|  - chr(sigma mu, tau) A_tau^sigma + chr(sigma tau, alpha) A_mu^tau
      ),
      "39",
    ),
    Prose(
      (
        $|By the reduction of \{r("38")} with reference to the indices
        $|\{m("beta")} and \{m("sigma")} (inner multiplication with
        $|\{m("delta_beta^sigma")}), we get a contravariant four-vector
      ),
    ),
    dm(
      (
        #|A^alpha = (partial A^(alpha beta))/(partial x_beta)
        #|  + chr(beta kappa.alt, beta) A^(alpha kappa.alt)
        #|  + chr(beta kappa.alt, alpha) A^(kappa.alt beta)
      ),
    ),
    Prose(
      (
        $|On the account of the symmetry of \{m("chr(beta kappa.alt, alpha)")}
        $|with reference to the indices \{m("beta")}, and \{m("kappa.alt")},
        $|the third member of the right hand side vanishes when
        $|\{m("A^(alpha beta)")} is an anti-symmetrical tensor, which we
        $|assume here; the second member can be transformed according to
        $|\{r("29a")}; we therefore get
      ),
    ),
    eq(
      "A^alpha = 1/sqrt(-g) (partial (sqrt(-g) A^(alpha beta)))/(partial x_beta)",
      "40",
    ),
    Prose(
      (
        $|This is the expression of the divergence of a contravariant
        $|six-vector.
        $|
        $|\{em("Divergence of the mixed tensor of the second rank.")} Let us
        $|form the reduction of \{r("39")} with reference to the indices
        $|\{m("alpha")} and \{m("sigma")}, we obtain remembering \{r("29a")}
      ),
    ),
    eq(
      (
        #|sqrt(-g) A_mu = (partial (sqrt(-g) A_mu^sigma))/(partial z_sigma)
        #|  - chr(sigma mu, tau) sqrt(-g) A_tau^sigma
      ),
      "41",
    ),
    Prose(
      (
        $|If we introduce into the last term the contravariant tensor
        $|\{m("A^(rho.alt sigma) = g^(rho.alt tau) A_tau^sigma")}, it takes
        $|the form
      ),
    ),
    dm("-chf(sigma mu, rho.alt) sqrt(-g) A^(rho.alt sigma)"),
    Prose(
      "If further \{m("A^(rho.alt sigma)")} is symmetrical it is reduced to",
    ),
    dm(
      "-1/2 sqrt(-g) (partial g_(rho.alt sigma))/(partial x_mu) A^(rho.alt sigma)",
    ),
    Prose(
      (
        $|If instead of \{m("A^(rho.alt sigma)")}, we introduce in a similar
        $|way the symmetrical covariant tensor
        $|\{m("A_(rho.alt sigma) = g_(rho.alt alpha) g_(sigma beta) A^(alpha beta)")},
        $|then owing to \{r("31")} the last member can take the form
      ),
    ),
    dm(
      "1/2 sqrt(-g) (partial g^(rho.alt sigma))/(partial x_mu) A_(rho.alt sigma)",
    ),
    Prose(
      "In the symmetrical case treated, \{r("41")} can be replaced by either of the forms",
    ),
    eq(
      (
        #|sqrt(-g) A_mu = (partial (sqrt(-g) A_mu^sigma))/(partial x_sigma)
        #|  - 1/2 (partial g_(rho.alt sigma))/(partial x_mu) sqrt(-g) A^(rho.alt sigma)
      ),
      "41a",
    ),
    Prose("or"),
    eq(
      (
        #|sqrt(-g) A_mu = (partial (sqrt(-g) A_mu^sigma))/(partial x_sigma)
        #|  + 1/2 (partial g^(rho.alt sigma))/(partial x_mu) sqrt(-g) A_(sigma rho.alt)
      ),
      "41b",
    ),
    Prose("which we shall have to make use of afterwards."),
  ]
}

///|
fn sec_12() -> Array[&IntoContent] {
  [
    sec("The Riemann-Christoffel Tensor.", 12),
    Prose(
      (
        $|We now seek only those tensors, which can be obtained from the
        $|fundamental tensor \{m("g_(mu nu)")} by differentiation
        $|\{em("alone")}. It is found easily. We put in \{r("27")} instead of
        $|any tensor \{m("A_(mu nu)")} the fundamental tensor
        $|\{m("g_(mu nu)")} and get from it a new tensor, namely the extension
        $|of the fundamental tensor. We can easily convince ourselves that
        $|this vanishes identically. We prove it in the following way; we
        $|substitute in \{r("27")}
      ),
    ),
    dm(
      "A_(mu nu) = (partial A_mu)/(partial x_nu) - chr(mu nu, rho.alt) A_(rho.alt)",
    ),
    Prose(
      (
        $|\{em("i.e.")}, the extension of a four-vector \{m("A_nu")}.
        $|
        $|Thus we get (by slightly changing the indices) the tensor of the
        $|third rank
      ),
    ),
    dm(
      (
        #|A_(mu sigma tau) &= (partial^2 A_mu)/(partial x_sigma partial x_tau) \
        #|  &- chr(mu sigma, rho.alt) (partial A_(rho.alt))/(partial x_tau)
        #|    - chr(mu tau, rho.alt) (partial A_(rho.alt))/(partial x_sigma)
        #|    - chr(sigma tau, rho.alt) (partial A_mu)/(partial x_(rho.alt)) \
        #|  &+ [-partial/(partial x_tau) chr(mu sigma, rho.alt)
        #|    + chr(mu tau, alpha) chr(alpha sigma, rho.alt)
        #|    + chr(sigma tau, alpha) chr(alpha mu, rho.alt)] A_(rho.alt)
      ),
    ),
    Prose(
      (
        $|We use these expressions for the formation of the tensor
        $|\{m("A_(mu sigma tau) - A_(mu tau sigma)")}. Thereby the following
        $|terms in \{m("A_(mu sigma tau)")} cancel the corresponding terms in
        $|\{m("A_(mu tau sigma)")}; the first member, the fourth member, as
        $|well as the member corresponding to the last term within the square
        $|bracket. These are all symmetrical in \{m("sigma")} and
        $|\{m("tau")}. The same is true for the sum of the second and third
        $|members. We thus get
      ),
    ),
    eq(
      "A_(mu sigma tau) - A_(mu tau sigma) = B_(mu sigma tau)^(rho.alt) A_(rho.alt)",
      "42",
    ),
    eq(
      (
        #|cases(gap: #0.9em,
        #|  B_(mu sigma tau)^(rho.alt) = &display(-partial/(partial x_tau) chr(mu sigma, rho.alt)
        #|    + partial/(partial x_sigma) chr(mu tau, rho.alt)),
        #|  &display(-chr(mu sigma, alpha) chr(alpha tau, rho.alt)
        #|    + chr(mu tau, alpha) chr(alpha sigma, rho.alt)))
      ),
      "43",
    ),
    Prose(
      (
        $|The essential thing in this result is that on the right hand side
        $|of \{r("42")} we have only \{m("A_(rho.alt)")}, but not its
        $|differential co-efficients. From the tensor-character of
        $|\{m("A_(mu sigma tau) - A_(mu tau sigma)")}, and from the fact that
        $|\{m("A_(rho.alt)")} is an arbitrary four vector, it follows, on
        $|account of the result of \{s(7)}, that
        $|\{m("B_(mu sigma tau)^(rho.alt)")} is a tensor
        $|(\{sc("Riemann-Christoffel")} Tensor).
        $|
        $|The mathematical significance of this tensor is as follows; when
        $|the continuum is so shaped, that there is a co-ordinate system for
        $|which the \{m("g_(mu nu)")} are constants,
        $|\{m("R_(mu sigma tau)^(rho.alt)")} all vanish.
        $|
        $|If we choose instead of the original co-ordinate system any new
        $|one, so would the \{m("g_(mu nu)")} referred to this last system be
        $|no longer constants. The tensor character of
        $|\{m("R_(mu sigma tau)^(rho.alt)")} shows us, however, that these
        $|components vanish collectively also in any other chosen system of
        $|reference. The vanishing of the \{sc("Riemann")} Tensor is thus a
        $|necessary condition that for some choice of the axis-system the
        $|\{m("g_(mu nu)")} can be taken as constants. In our
        $|problem it corresponds to the case when by a suitable choice of the
        $|co-ordinate system, the special relativity theory holds throughout
        $|any finite region. By the reduction of \{r("43")} with reference to
        $|indices to \{m("tau")} and \{m("rho.alt")}, we get the covariant
        $|tensor of the second rank
      ),
    ),
    eq(
      (
        #|cases(gap: #0.9em,
        #|  B_(mu nu) &= R_(mu nu) + S_(mu nu),
        #|  R_(mu nu) &= display(-partial/(partial x_alpha) chr(mu nu, alpha)
        #|    + chr(mu alpha, beta) chr(nu beta, alpha)),
        #|  S_(mu nu) &= display((partial lg sqrt(-g))/(partial x_mu partial x_nu)
        #|    - chr(mu nu, alpha) (partial lg sqrt(-g))/(partial x_alpha)))
      ),
      "44",
    ),
    indent(),
    Prose(
      (
        $|\{em("Remarks upon the choice of co-ordinates")}. — It has already
        $|been remarked in \{s(8)}, with reference to the equation
        $|\{r("18a")}, that the co-ordinates can with advantage be so chosen
        $|that \{m("sqrt(-g) = 1")}. A glance at the equations got in the last
        $|two paragraphs shows that, through such a choice, the law of
        $|formation of the tensors suffers a significant simplification. It is
        $|specially true for the tensor \{m("B_(mu nu)")}, which plays a
        $|fundamental role in the theory. By this simplification,
        $|\{m("S_(mu nu)")} vanishes of itself so that tensor
        $|\{m("B_(mu nu)")} reduces to \{m("R_(mu nu)")}.
        $|
        $|I shall give in the following pages all relations in the simplified
        $|form, with the above-named specialisation of the co-ordinates. It is
        $|then very easy to go back to the \{em("general")} covariant
        $|equations, if it appears desirable in any special case.
      ),
    ),
  ]
}
