// Parts D and E, § 19 to § 22.

///|
fn part_d_intro() -> Array[&IntoContent] {
  [
    part("D. The “Material” Phenomena."),
    Prose(
      (
        $|The Mathematical auxiliaries developed under B at once enable us to
        $|generalise, according to the generalised theory of relativity, the
        $|physical laws of matter (Hydrodynamics, \{sc("Maxwell")}'s
        $|Electro-dynamics) as they lie already formulated according to the
        $|special-relativity-theory. The generalised Relativity Principle
        $|leads us to no further limitation of possibilities; but it enables
        $|us to know exactly the influence of gravitation on all processes
        $|without the introduction of any new hypothesis.
        $|
        $|It is owing to this, that as regards the physical nature of matter
        $|(in a narrow sense) no definite necessary assumptions are to be
        $|introduced. The question may lie open whether the theories of the
        $|electro-magnetic field and the gravitational-field together, will
        $|form a sufficient basis for the theory of matter. The general
        $|relativity postulate can teach us no new principle. But by building
        $|up the theory it must be shown whether electro-magnetism and
        $|gravitation together can achieve what the former alone did not
        $|succeed in doing.
      ),
    ),
  ]
}

///|
fn sec_19() -> Array[&IntoContent] {
  [
    sec("Euler’s equations for frictionless adiabatic liquid.", 19),
    Prose(
      (
        $|Let \{m("p")} and \{m("rho.alt")}, be two scalars, of which the
        $|first denotes the "pressure" and the last the "density" of the
        $|liquid; between them there is a relation. Let the contravariant
        $|symmetrical tensor
      ),
    ),
    eq(
      "T^(alpha beta) = -g^(alpha beta) p + rho.alt (d x_alpha)/(d s) (d x_beta)/(d s)",
      "58",
    ),
    Prose(
      (
        $|be the contravariant energy-tensor of the liquid. To it also belongs
        $|the covariant tensor
      ),
    ),
    eq(
      "T_(mu nu) = -g_(mu nu) p + g_(mu alpha) (d x_alpha)/(d s) g_(mu beta) (d x_beta)/(d s) rho.alt",
      "58a",
    ),
    Prose("as well as the mixed tensor"),
    eq(
      "T_sigma^alpha = -delta_sigma^alpha p + g_(sigma beta) (d x_beta)/(d s) (d x_alpha)/(d s) rho.alt",
      "58b",
    ),
    Prose(
      (
        $|If we put the right-hand side of \{r("58b")} in \{r("57a")}, we get
        $|the general hydrodynamical equations of \{sc("Euler")} according to
        $|the generalised relativity theory. This in principle completely
        $|solves the problem of motion; for the four equations \{r("57a")}
        $|together with the given equation between \{m("p")} and
        $|\{m("rho.alt")}, and the equation
      ),
    ),
    dm("g_(alpha beta) (d x_alpha)/(d s) (d x_beta)/(d s) = 1"),
    Prose(
      (
        $|are sufficient, with the given values of \{m("g_(alpha beta)")},
        $|for finding out the six unknowns
      ),
    ),
    dm(
      (
        #|p, quad rho.alt, quad (d x_1)/(d s), quad (d x_2)/(d s), quad
        #|  (d x_3)/(d s), quad (d x_4)/(d s)
      ),
    ),
    Prose(
      (
        $|If \{m("g_(mu nu)")} are unknown we have also to take the equations
        $|\{r("53")}. There are now 11 equations for finding out 10 functions
        $|\{m("g_(mu nu)")}, so that the number is more than sufficient. Now
        $|it is be noticed that the equation \{r("57a")} is already contained
        $|in \{r("53")}, so that the latter only represents (7) independent
        $|equations. This indefiniteness is due to the wide freedom in the
        $|choice of co-ordinates, so that mathematically the problem is
        $|indefinite in the sense that three of the Space-functions can be
        $|arbitrarily chosen.
      ),
    ),
  ]
}

///|
fn sec_20() -> Array[&IntoContent] {
  [
    sec("Maxwell’s Electro-Magnetic field-equations for the vacuum.", 20),
    Prose(
      (
        $|Let \{m("phi_nu")} be the components of a covariant four-vector,
        $|the electro-magnetic potential; from it let us form according to
        $|\{r("36")} the Components \{m("F_(rho.alt sigma)")} of the covariant
        $|six-vector of the electro-magnetic field according to the system of
        $|equations
      ),
    ),
    eq(
      (
        #|F_(rho.alt sigma) = (partial phi_(rho.alt))/(partial x_sigma)
        #|  - (partial phi_sigma)/(partial x_(rho.alt))
      ),
      "59",
    ),
    Prose("From \{r("59")} it follows that the system of equations"),
    eq(
      (
        #|(partial F_(rho.alt sigma))/(partial x_tau) + (partial F_(sigma tau))/(partial x_(rho.alt))
        #|  + (partial F_(tau rho.alt))/(partial x_(rho.alt)) = 0
      ),
      "60",
    ),
    Prose(
      (
        $|is satisfied of which the left-hand side, according to \{r("37")},
        $|is an anti-symmetrical tensor of the third kind. This system
        $|\{r("60")} contains essentially four equations, which can be thus
        $|written: —
      ),
    ),
    eq(
      (
        #|cases(gap: #0.9em,
        #|  display((partial F_23)/(partial x_4) + (partial F_34)/(partial x_2) + (partial F_42)/(partial x_3)) &= 0,
        #|  display((partial F_34)/(partial x_1) + (partial F_41)/(partial x_3) + (partial F_13)/(partial x_4)) &= 0,
        #|  display((partial F_41)/(partial x_2) + (partial F_12)/(partial x_4) + (partial F_24)/(partial x_1)) &= 0,
        #|  display((partial F_12)/(partial x_3) + (partial F_23)/(partial x_1) + (partial F_31)/(partial x_2)) &= 0)
      ),
      "60a",
    ),
    Prose(
      (
        $|This system of equations corresponds to the second system of
        $|equations of \{sc("Maxwell")}. We see it at once if we put
      ),
    ),
    eq(
      (
        #|mat(delim: #("{", none), column-gap: #2.4em, row-gap: #0.5em,
        #|  F_23 = frak(h)_x, F_14 = frak(e)_x;
        #|  F_31 = frak(h)_y, F_24 = frak(e)_y;
        #|  F_12 = frak(h)_z, F_34 = frak(e)_z)
      ),
      "61",
    ),
    Prose(
      (
        $|Instead of \{r("60a")} we can therefore write according to the usual
        $|notation of three-dimensional vector-analysis: —
      ),
    ),
    eq(
      (
        #|sys((partial frak(h))/(partial t) + op("rot") frak(e) = 0,
        #|  op("div") frak(h) = 0)
      ),
      "60b",
    ),
    Prose(
      (
        $|The first \{sc("Maxwell")}ian system is obtained by a generalisation
        $|of the form given by \{sc("Minkowski")}.
        $|
        $|We introduce the contravariant six-vector \{m("F_(alpha beta)")} by
        $|the equation
      ),
    ),
    eq("F^(mu nu) = g^(mu alpha) q^(nu beta) F_(alpha beta)", "62"),
    Prose(
      (
        $|and also a contravariant four-vector \{m("J^mu")}, which is the
        $|electrical current-density in vacuum. Then remembering \{r("40")} we
        $|can establish the system of equations, which remains invariant for
        $|any substitution with determinant 1 (according to our choice of
        $|co-ordinates)
      ),
    ),
    eq("(partial F^(mu nu))/(partial x_nu) = J^mu", "63"),
    Prose("If we put"),
    eq(
      (
        #|mat(delim: #("{", none), column-gap: #2.4em, row-gap: #0.5em,
        #|  F^23 = frak(h)'_x, F^14 = frak(e)'_x;
        #|  F^31 = frak(h)'_y, F^24 = frak(e)'_y;
        #|  F^12 = frak(h)'_z, F^34 = frak(e)'_z)
      ),
      "64",
    ),
    Prose(
      (
        $|which quantities become equal to
        $|\{m("h_x thin dots thin frak(e)_z")}, in the case of the special
        $|relativity theory, and besides
      ),
    ),
    dm(
      "J^1 = frak(i)_x, quad J^2 = frak(i)_y, quad J^3 = frak(i)_z, quad J^4 = rho.alt",
    ),
    Prose("we get instead of \{r("63")}"),
    eq(
      (
        #|sys(op("rot") frak(h) - (partial frak(e)')/(partial t) = frak(i),
        #|  op("div") frak(e)' = rho.alt)
      ),
      "63a",
    ),
    Prose(
      (
        $|The equations \{r("60")}, \{r("62")} and \{r("63")} give thus a
        $|generalisation of \{sc("Maxwell")}'s field-equations in vacuum,
        $|which remains true in our chosen system of co-ordinates.
        $|
        $|\{em("The energy-components of the electromagnetic field.")} Let us
        $|form the inner-product
      ),
    ),
    eq("kappa.alt_sigma = F_(sigma mu) J^mu", "65"),
    Prose(
      (
        $|According to \{r("61")} its components can be written down in the
        $|three-dimensional notation.
      ),
    ),
    eq(
      (
        #|cases(gap: #0.6em,
        #|  kappa.alt_1 = rho.alt frak(e)_x + [frak(i)\, frak(h)]_x,
        #|  dots thin dots,
        #|  dots thin dots,
        #|  kappa.alt_4 = -(frak(i)\, frak(e)))
      ),
      "65a",
    ),
    Prose(
      (
        $|\{m("kappa.alt_sigma")} is a covariant four-vector whose components
        $|are equal to the negative impulse and energy which are transferred
        $|to the electro-magnetic field per unit of time, and per unit of
        $|volume, by the electrical masses. If the electrical masses be free,
        $|that is, under the influence of the electromagnetic field only, then
        $|the covariant four-vector \{m("kappa.alt_sigma")} will vanish.
        $|
        $|In order to get the energy components \{m("T_sigma^nu")} of the
        $|electro-magnetic field, we require only to give to the equation
        $|\{m("kappa.alt_sigma = 0")}, the form of the equation \{r("57")}.
        $|
        $|From \{r("63")} and \{r("65")} we get first,
      ),
    ),
    dm(
      (
        #|kappa.alt_sigma = F_(sigma mu) (partial F^(mu nu))/(partial x_nu)
        #|  = partial/(partial x_nu) (F_(sigma mu) F^(mu nu))
        #|  - F^(mu nu) (partial F_(sigma mu))/(partial x_nu)
      ),
    ),
    Prose(
      (
        $|On account of \{r("60")} the second member on the right-hand side
        $|admits of the transformation —
      ),
    ),
    dm(
      (
        #|F^(mu nu) (partial F_(sigma mu))/(partial x_nu)
        #|  = -1/2 F^(mu nu) (partial F_(mu nu))/(partial x_sigma)
        #|  = -1/2 g^(mu alpha) g^(nu beta) F_(alpha beta) (partial F_(mu nu))/(partial x_sigma)
      ),
    ),
    Prose("Owing to symmetry, this expression can also be written in the form"),
    dm(
      (
        #|-1/4 [g^(mu alpha) g^(nu beta) F_(alpha beta) (partial F_(mu nu))/(partial x_sigma)
        #|  + g^(mu alpha) g^(nu beta) (partial F_(alpha beta))/(partial x_sigma) F_(mu nu)]
      ),
    ),
    Prose("which can also be put in the form"),
    dm(
      (
        #|-1/4 partial/(partial x_sigma) (g^(mu alpha) g^(nu beta) F_(alpha beta) F_(mu nu))
        #|  + 1/4 F_(alpha beta) F_(mu nu) partial/(partial x_sigma) (g^(mu alpha) g^(nu beta))
      ),
    ),
    Prose("The first of these terms can be written shortly as"),
    dm("-1/4 partial/(partial x_sigma) (F^(mu nu) F_(mu nu))"),
    Prose("and the second after differentiation can be transformed in the form"),
    dm(
      "-1/2 F^(mu tau) F_(mu nu) g^(nu rho.alt) (partial g_(sigma tau))/(partial x_sigma)",
    ),
    Prose("If we take all the three terms together, we get the relation"),
    eq(
      (
        #|kappa.alt_sigma = (partial T_sigma^nu)/(partial x_nu)
        #|  - 1/2 g^(tau mu) (partial g_(mu nu))/(partial x_sigma) T_tau^nu
      ),
      "66",
    ),
    Prose("where"),
    eq(
      (
        #|T_tau^nu = -F_(sigma alpha) F^(nu alpha)
        #|  + 1/4 delta_sigma^nu F_(alpha beta) F^(alpha beta)
      ),
      "66a",
    ),
    Prose(
      (
        $|On account of \{r("30")} the equation \{r("66")} becomes equivalent
        $|to \{r("57")} and \{r("57a")} when \{m("kappa.alt_sigma")} vanishes.
        $|Thus \{m("T_sigma^nu")} are the energy-components of the
        $|electro-magnetic field. With the help of \{r("61")} and \{r("64")}
        $|we can easily show that the energy-components of the
        $|electro-magnetic field, in the case of the special relativity
        $|theory, give rise to the well-known \{sc("Maxwell-Poynting")}
        $|expressions.
        $|
        $|We have now deduced the most general laws which the
        $|gravitation-field and matter satisfy when we use a co-ordinate
        $|system for which \{m("sqrt(-g) = 1")}. Thereby we achieve an
        $|important simplification in all our formulas and calculations,
        $|without renouncing the conditions of general covariance, as we have
        $|obtained the equations through a specialisation of the co-ordinate
        $|system from the general covariant-equations. Still the question is
        $|not without formal interest, whether, when the energy-components of
        $|the gravitation-field and matter is defined in a generalised manner
        $|without any specialisation of co-ordinates, the laws of conservation
        $|have the form of the equation \{r("56")}, and the field-equations of
        $|gravitation hold in the form \{r("52")} or \{r("52a")}; such that on
        $|the left-hand side, we have a divergence in the usual sense, and on
        $|the right-hand side, the sum of the energy-components of matter and
        $|gravitation. I have found out that this is indeed the case. But I am
        $|of opinion that the communication of my rather comprehensive work on
        $|this subject will not pay, for nothing essentially new comes out of
        $|it.
      ),
    ),
  ]
}

///|
fn sec_21() -> Array[&IntoContent] {
  [
    part("E."),
    sec("Newton’s Theory as a First Approximation.", 21),
    Prose(
      (
        $|We have already mentioned several times that the special relativity
        $|theory is to be looked upon as a special case of the general, in
        $|which \{m("g_(mu nu)")} have constant values \{r("4")}.
        $|
        $|This signifies, according to what has been said before, a total
        $|neglect of the influence of gravitation. We get a more realistic
        $|approximation if we consider the case when \{m("g_(mu nu)")} differ
        $|from \{r("4")} only by small magnitudes (compared to 1) where we can
        $|neglect small quantities of the second and higher orders (first
        $|aspect of the approximation.)
        $|
        $|Further it should be assumed that within the space-time region
        $|considered, \{m("g_(mu nu)")} at infinite distances (using the word
        $|infinite in a spatial sense) can, by a suitable choice of
        $|co-ordinates, tend to the limiting values \{r("4")}; \{em("i.e.")},
        $|we consider only those gravitational fields which can be regarded as
        $|produced by masses distributed over finite regions.
        $|
        $|We can assume that this approximation should lead to
        $|\{sc("Newton")}'s theory. For it however, it is necessary to treat
        $|the fundamental equations from another point of view. Let us
        $|consider the motion of a particle according to the equation
        $|\{r("46")}. In the case of the special relativity theory, the
        $|components
      ),
    ),
    dm("(d x_1)/(d s), quad (d x_2)/(d s), quad (d x_3)/(d s)"),
    Prose("can take any values; This signifies that any velocity"),
    dm("v = sqrt((d x_1^2)/(d x_4) + (d x_2^2)/(d x_4) + (d x_3^2)/(d x_4))"),
    Prose(
      (
        $|can appear which is less than the velocity of light in vacuum
        $|(\{m("v < 1")}). If we finally limit ourselves to the consideration
        $|of the case when \{m("v")} is small compared to the velocity of
        $|light, it signifies that the components
      ),
    ),
    dm("(d x_1)/(d s), quad (d x_2)/(d s), quad (d x_3)/(d s)"),
    Prose(
      (
        $|can be treated as small quantities, whereas
        $|\{m("d x_4 slash d s")} is equal to 1, up to the second-order
        $|magnitudes (the second point of view for approximation).
        $|
        $|Now we see that, according to the first view of approximation the
        $|magnitudes \{m("Gamma_(mu nu)^tau")} are all small quantities of at
        $|least the first order. A glance at \{r("46")} will also show, that
        $|in this equation according to the second view of approximation, we
        $|are only to take into account those terms for which
        $|\{m("mu = nu = 4")}.
        $|
        $|By limiting ourselves only to terms of the lowest order we get
        $|instead of \{r("46")}, first, the equations : —
      ),
    ),
    dm("(d^2 x_tau)/(d t^2) = Gamma_44^tau"),
    Prose(
      (
        $|where \{m("d x = d x_4 = d t")}, or by limiting ourselves only to
        $|those terms which according to the first stand-point are
        $|approximations of the first order,
      ),
    ),
    dm(
      (
        #|(d^2 x_tau)/(d t^2) &= chf(44, tau) quad (tau = 1, 2, 3) \
        #|(d^2 x_4)/(d t^2) &= -chf(44, tau)
      ),
    ),
    Prose(
      (
        $|If we further assume that the gravitation-field is quasi-static,
        $|\{em("i.e.")}, it is limited only to the case when the matter
        $|producing the gravitation-field is moving slowly (relative to the
        $|velocity of light) we can neglect the differentiations of the
        $|positional co-ordinates on the right-hand side with respect to time,
        $|so that we get
      ),
    ),
    eq(
      "(d^2 x_tau)/(d t^2) = -1/2 (partial g_44)/(partial x_tau) quad (tau = 1, 2, 3)",
      "67",
    ),
    Prose(
      (
        $|This is the equation of motion of a material point according to
        $|\{sc("Newton")}'s theory, where \{m("g_44 slash 2")} plays the part
        $|of gravitational potential. The remarkable thing in the result is
        $|that in the first-approximation of motion of the material pointy
        $|only the component \{m("g_44")} of the fundamental tensor appears.
        $|
        $|Let us now turn to the field-equation \{r("53")}. In this case, we
        $|have to remember that the energy-tensor of matter is exclusively
        $|defined in a narrow sense by the density \{m("rho.alt")} of matter,
        $|\{em("i.e.")}, by the second member on the right-hand side of
        $|\{rb("58")} [(\{rb("58a")}, or \{rb("58b")})]. If we make the
        $|necessary approximations, then all component vanish except
      ),
    ),
    dm("T_44 = rho.alt = T"),
    Prose(
      (
        $|On the left-hand side of \{r("53")} the second term is an
        $|infinitesimal of the second order, so that the first leads to the
        $|following terms in the approximation, which are rather interesting
        $|for us
      ),
    ),
    dm(
      (
        #|+ partial/(partial x_1) chf(mu nu, 1) + partial/(partial_2) chf(mu nu, 2)
        #|  + partial/(partial x_3) chf(mu nu, 3) - partial/(partial x_4) chf(mu nu, 4)
      ),
    ),
    Prose(
      (
        $|neglecting all differentiations with regard to time, this leads,
        $|when \{m("mu = nu = 4")}, to the expression
      ),
    ),
    dm(
      (
        #|-1/2 ((partial^2 g_44)/(partial x_1^2) + (partial^2 g_44)/(partial x_2^2)
        #|  + (partial^2 g_44)/(partial x_3^2)) = -1/2 Delta g_44
      ),
    ),
    Prose("The last of the equations \{r("53")} thus leads to"),
    eq("Delta g_44 = kappa.alt rho.alt", "68"),
    Prose(
      (
        $|The equations \{r("67")} and \{r("68")} together, are equivalent to
        $|\{sc("Newton")}'s law of gravitation.
        $|
        $|For the gravitation-potential we get from \{r("67")} and \{r("68")}
        $|the exp.
      ),
    ),
    eq("-kappa.alt/(8 pi) integral (rho.alt d tau)/r", "68a"),
    Prose(
      (
        $|whereas the \{sc("Newton")}ian theory for the chosen unit of time
        $|gives
      ),
    ),
    dm("-K/c^2 integral (rho.alt d tau)/r"),
    Prose(
      (
        $|where \{m("K")} denotes usually the gravitation-constant
        $|\{decimal("6,7", " dot.c 10^(-8)")}; equating them we get \{r("69")}
      ),
    ),
    eq("kappa.alt = (8 pi K)/c^2 = \"11,87\" dot.c 10^(-27)", "69"),
  ]
}

///|
fn sec_22() -> Array[&IntoContent] {
  [
    sec(
      "Behaviour of measuring rods and clocks in a statical gravitation-field. Curvature of light-rays. Perihelion-motion of the paths of the Planets.",
      22,
    ),
    Prose(
      (
        $|In order to obtain \{sc("Newton")}'s theory as a first approximation
        $|we had to calculate only \{m("g_44")} out of the 10 components of
        $|the gravitation-potential \{m("g_(mu nu)")}, for that is the only
        $|component which conies in the first approximate equations of motion
        $|of a material point in a gravitational field. We see however, that
        $|the other components of \{m("g_(mu nu)")} should also differ from
        $|the values given in \{r("4")} as required by the condition
        $|\{m("g = -1")} .
        $|
        $|For a mass-point at the origin of co-ordinates and generating the
        $|gravitational field, we get as a first approximation the symmetrical
        $|solution of the equation: —
      ),
    ),
    eq(
      (
        #|cases(gap: #0.9em,
        #|  display(g_(rho.alt sigma) = -delta_(rho.alt sigma) - alpha (x_(rho.alt) x_sigma)/r^3
        #|    quad (rho.alt "and" sigma "between 1 and 3")),
        #|  g_(rho.alt 4) = g_(4 rho.alt) = 0 quad (rho.alt "between 1 and 3"),
        #|  display(g_44 = 1 - alpha/r))
      ),
      "70",
    ),
    Prose(
      (
        $|\{m("delta_(rho.alt sigma)")} is 1 or 0, according as
        $|\{m("rho.alt = sigma")} or \{m("rho.alt != sigma")}, and \{m("r")}
        $|is the quantity
      ),
    ),
    dm("+sqrt(x_1^2 + x_2^2 + x_3^2)"),
    Prose("On account of \{r("68a")} we have"),
    eq("alpha = (kappa.alt M)/(8 pi)", "70a"),
    Prose(
      (
        $|where \{m("M")} denotes the mass generating the field. It is easy to
        $|verify that this solution satisfies approximately the
        $|field-equation outside the mass.
        $|
        $|Let us now investigate the influences which the field of mass
        $|\{m("M")} will have upon the metrical properties of the field.
        $|Between the lengths and times \{m("d s")} measured "locally"
        $|(\{s(4)}) on the one hand, and the differences in co-ordinates
        $|\{m("d x_nu")} on the other, we have the relation
      ),
    ),
    dm("d s^2 = g_(mu nu) d x_mu d x_nu"),
    Prose(
      (
        $|For a unit measuring rod, for example, placed "parallel" to the
        $|\{m("x")}-axis, we have to put
      ),
    ),
    dm("d s^2 = -1; quad d x_2 = d x_3 = d x_4 = 0"),
    Prose("then"),
    dm("-1 = g_11 d x_1^2"),
    Prose(
      (
        $|If the unit measuring rod lies on the \{m("x")}-axis, the first of
        $|the equations \{r("70")} gives
      ),
    ),
    dm("g_11 = -(1 + alpha/r)"),
    Prose("From both these relations it follows as a first approximation that"),
    eq("d x = 1 - alpha/(2 r)", "71"),
    Prose(
      (
        $|The unit measuring rod appears, when referred to the
        $|co-ordinate-system, shortened by the calculated magnitude through
        $|the presence of the gravitational field, when we place it radially
        $|in the field.
        $|
        $|Similarly we can get its co-ordinate-length in a tangential
        $|position, if we put for example
      ),
    ),
    dm(
      "d s^2 = -1; quad d x_1 = d x_3 = d x_4 = 0; quad x_1 = r, quad x_2 = x_3 = 0",
    ),
    Prose("we then get"),
    eq("-1 = g_22 d x_2^2 = -d x_2^2", "71a"),
    Prose(
      (
        $|The gravitational field has no influence upon the length of the rod,
        $|when we put it tangentially in the field.
        $|
        $|Thus \{sc("Euclid")}ean geometry does not hold in the gravitational
        $|field even in the first approximation, if we conceive that one and
        $|the same rod independent of its position and its orientation can
        $|serve as the measure of the same extension. But a glance at
        $|\{r("70a")} and \{r("69")} shows that the expected difference is
        $|much too small to be noticeable in the measurement of earth's
        $|surface.
        $|
        $|We would further investigate the rate of going of a unit-clock which
        $|is placed in a statical gravitational field. Here we have for a
        $|period of the clock
      ),
    ),
    dm("d s = 1; quad d x_1 = d x_2 = d x_3 = 0"),
    Prose("then we have"),
    dm(
      (
        #|1 = g_44 d x_4^2; \
        #|d x_4 = 1/sqrt(g_44) = 1/sqrt(1 + (g_44 - 1)) = 1 - (g_44 - 1)/2
      ),
    ),
    Prose("or"),
    eq("d x_4 = 1 + kappa.alt/(8 pi) integral (rho.alt d tau)/r", "72"),
    Prose(
      (
        $|Therefore the clock goes slowly when it is placed in the
        $|neighbourhood of ponderable masses. It follows from this that the
        $|spectral lines in the light coming to us from the surfaces of big
        $|stars should appear shifted towards the red end of the
        $|spectrum.
        $|
        $|Let us further investigate the path of light-rays in a statical
        $|gravitational field. According to the special relativity theory,
        $|the velocity of light is given by the equation
      ),
    ),
    dm("-d x_1^2 - d x_2^2 - d x_3^2 + d x_4^2 = 0"),
    Prose(
      (
        $|thus also according to the generalised relativity theory it is given
        $|by the equation
      ),
    ),
    eq("d s^2 = g_(mu nu) d x_mu d x_nu = 0", "73"),
    Prose(
      (
        $|If the direction, \{em("i.e.")}, the ratio
        $|\{m("d x_1 : d x_2 : d x_3")} is given, the equation \{r("73")}
        $|gives the magnitudes
      ),
    ),
    dm("(d x_1)/(d x_4), quad (d x_2)/(d x_4), quad (d x_3)/(d x_4)"),
    Prose("and with it the velocity,"),
    dm(
      "sqrt(((d x_1)/(d x_4))^2 + ((d x_2)/(d x_4))^2 + ((d x_3)/(d x_4))^2) = gamma",
    ),
    Prose(
      (
        $|in the sense of the \{sc("Euclid")}ean Geometry. We can easily see
        $|that, with reference to the co-ordinate system, the rays of light
        $|must appear curved in case \{m("g_(mu nu)")} are not constant.
        $|
        $|If \{m("n")} be the direction perpendicular to the direction of
        $|propagation, we have, from \{sc("Huygen")}'s principle, that
        $|light-rays [taken in the plane (\{m("gamma, n")})] must suffer a
        $|curvature \{m("-d gamma slash partial n")}.
      ),
    ),
    light_ray_figure(),
    indent(),
    Prose(
      (
        $|Let us find out the curvature which a light-ray suffers when it goes
        $|by a mass \{m("M")} at a distance \{m("Delta")} from it. If we use
        $|the co-ordinate system according to the above scheme, then the total
        $|bending \{m("B")} of light-rays (reckoned positive when it is
        $|concave to the origin) is given as a sufficient approximation by
      ),
    ),
    dm("B = limits(integral)_(-oo)^(+oo) (partial gamma)/(partial x_1) d x_2"),
    Prose("while \{r("73")} and \{r("70")} give"),
    dm("gamma = sqrt(-g_44/g_22) = 1 + alpha/(2 r) (1 + x_2^2/r^2)"),
    Prose("The calculation gives"),
    eq("B = (2 alpha)/Delta = (kappa.alt M)/(4 pi Delta)", "74"),
    Prose(
      (
        $|A ray of light just grazing the sun would suffer a bending of
        $|\{decimal("1,7", "''")} whereas one coming by Jupiter would have a
        $|deviation of about \{decimal("0,02", "''")}.
        $|
        $|If we calculate the gravitation-field to a greater order of
        $|approximation and with it the corresponding path of a material
        $|particle of a relatively small (infinitesimal) mass we set a
        $|deviation of the following kind from the \{sc("Kepler-Newton")}ian
        $|Laws of Planetary motion. The Ellipse of Planetary motion suffers a
        $|slow rotation in the direction of motion, of amount
      ),
    ),
    eq("epsilon = 24 pi^3 a^2/(T^2 c^2 (1 - e^2))", "75"),
    Prose(
      (
        $|In this Formula \{m("a")} signifies the semi-major axis, \{m("c")}
        $|the velocity of light, measured in the usual way, \{m("e")} the
        $|eccentricity, \{m("T")} the time of revolution in
        $|seconds.
        $|
        $|The calculation gives for the planet Mercury, a rotation of path of
        $|amount \{m("43''")} per century, corresponding sufficiently to what
        $|has been found by astronomers (\{sc("Leverrier")}). They found a
        $|residual perihelion motion of this planet of the given magnitude
        $|which can not be explained by the perturbation of the other planets.
      ),
    ),
  ]
}

///|
/// The diagram of § 22, drawn again from the text (the source shows an
/// image): the mass at the origin, and a ray of light that runs parallel to
/// the axis of x_2 at the distance Δ.
fn light_ray_figure() -> Align {
  let thin = Stroke(thickness=Pt(0.5))
  let at = (x : Double, y : Double, body : &IntoContent) => {
    Place(body, dx=Pt(x), dy=Pt(y))
  }
  let line = (x0 : Double, y0 : Double, x1 : Double, y1 : Double) => {
    Place(Line(start=(Pt(x0), Pt(y0)), end_=(Pt(x1), Pt(y1)), stroke=thin))
  }
  Align(
    Center,
    Block(
      Seq([
        // The axes and the origin.
        line(10, 80, 200, 80),
        line(70, 125, 70, 8),
        Place(Circle(radius=Pt(1.6), fill=Luma(0)), dx=Pt(68.4), dy=Pt(78.4)),
        at(203, 76, m("x_1")),
        at(66, -4, m("x_2")),
        // The ray, with its arrow, and its distance from the origin.
        line(140, 125, 140, 14),
        Place(
          Polygon(
            [(Pt(140), Pt(8)), (Pt(137.4), Pt(17)), (Pt(142.6), Pt(17))],
            fill=Luma(0),
          ),
        ),
        at(101, 84, m("Delta")),
        at(146, 34, Text("Light-ray", size=Pt(8.5), style="italic")),
      ]),
      width=Pt(220),
      height=Pt(128),
      breakable=false,
      above=Em(1.2),
      below=Em(1.2),
    ),
  )
}
