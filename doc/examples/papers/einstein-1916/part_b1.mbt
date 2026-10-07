// Part B, § 5 to § 8.

///|
fn part_b_intro() -> Array[&IntoContent] {
  [
    part(
      "B. Mathematical Auxiliaries for Establishing the General Covariant Equations.",
    ),
    Prose(
      (
        $|We have seen before that the general relativity-postulate leads to
        $|the condition that the system of equations for Physics, must be
        $|Covariants for any possible substitution of co-ordinates
        $|\{m("x_1 thin dots thin x_4")}; we have now to see how such general covariant
        $|equations can be obtained. We shall now turn our attention to these
        $|purely mathematical propositions. It will be shown that in the
        $|solution, the invariant \{m("d s")}, given in equation \{r("3")}
        $|plays a fundamental role, which we, following \{sc("Gauss")}'s
        $|Theory of Surfaces, style as the "line-element".
        $|
        $|The fundamental idea of the general covariant theory is this: —
        $|With reference to any co-ordinate system, let certain things
        $|("tensors") be defined by a number of functions of co-ordinates
        $|which are called the components of the tensor. There are now certain
        $|rules according to which the components can be calculated in a new
        $|system of co-ordinates, when these are known for the original
        $|system, and when the transformation connecting the two systems is
        $|known. The things herefrom designated as Tensors have further the
        $|property that the transformation equation of their components are
        $|linear and homogeneous; so that all the components in the new system
        $|vanish if they are all zero in the original system. Thus a law of
        $|Nature can be formulated by putting all the components of a tensor
        $|equal to zero so that it is a general covariant equation; thus while
        $|we seek the laws of formation of the tensors, we also reach the
        $|means of establishing general Covariant laws.
      ),
    ),
  ]
}

///|
fn sec_5() -> Array[&IntoContent] {
  [
    sec("Contravariant and covariant Four-vector.", 5),
    Prose(
      (
        $|\{em("Contravariant Four-vector")}. The line-element is defined by
        $|the four components \{m("d x_nu")} whose transformation law is
        $|expressed by the equation
      ),
    ),
    eq("d x'_sigma = sum_nu (partial x'_sigma)/(partial x_nu) d x_nu", "5"),
    Prose(
      (
        $|The \{m("d x'_sigma")} are expressed as linear and homogeneous
        $|function of \{m("d x_nu")}; we can look upon the differentials of
        $|the co-ordinates \{m("d x_nu")} as the components of a tensor, which
        $|we designate specially as a contravariant Four-vector. Everything
        $|which is defined by Four quantities \{m("A^nu")}, with reference to
        $|a co-ordinate system, and transforms according to the same law,
      ),
    ),
    eq("A'^sigma = sum_nu (partial x'_sigma)/(partial x_nu) A^nu", "5a"),
    Prose(
      (
        $|we may call a contravariant Four-vector. From \{r("5a")}, it follows
        $|at once that the sums \{m("(A^sigma plus.minus B^sigma)")} are also
        $|components of a four-vector, when \{m("A^sigma")} and
        $|\{m("B^sigma")} are so; corresponding relations hold also for all
        $|systems afterwards introduced as "tensors" (Rule of addition and
        $|subtraction of Tensors).
        $|
        $|\{em("Covariant Four-vector")}. We call four quantities
        $|\{m("A_nu")} as the components of a covariant four-vector, when for
        $|any choice of the contravariant four-vector \{m("B^nu")}
      ),
    ),
    eq("sum_nu A_nu B^nu = \"invariant\"", "6"),
    Prose(
      (
        $|From this definition follows the law of transformation of the
        $|covariant four-vectors. If we substitute in the right band side of
        $|the equation
      ),
    ),
    dm("sum_sigma A'_sigma B'^sigma = sum_nu A_nu B^nu"),
    Prose("the expressions"),
    dm("sum_sigma (partial x_nu)/(partial x'_sigma) B'^sigma"),
    Prose(
      "for \{m("B^nu")} following from the inversion of the equation \{r("5a")} we get",
    ),
    dm(
      "sum_sigma B'^sigma sum_nu (partial x_nu)/(partial x'_sigma) A_nu = sum_sigma B'^sigma A'_sigma",
    ),
    Prose(
      (
        $|As in the above equation \{m("B'^sigma")} are independent of one
        $|another and perfectly arbitrary, it follows that the transformation
        $|law is: —
      ),
    ),
    eq("A'_sigma = sum (partial x_nu)/(partial x'_sigma) A_nu", "7"),
    indent(),
    Prose(
      (
        $|\{em("Remarks on the simplification of the mode of writing the expressions")}.
        $|A glance at the equations of this paragraph will show that the
        $|indices which appear twice within the sign of summation [for example
        $|\{m("nu")} in \{r("5")}] are those over which the summation is to be
        $|made and that \{em("only")} over the indices which appear twice. It
        $|is therefore possible, without loss of clearness, to leave off the
        $|summation sign; so that we introduce the rule: wherever the index in
        $|any term of an expression appears twice, it is to be summed over all
        $|of them except when it is not expressedly said to the contrary.
        $|
        $|The difference between the covariant and the contravariant
        $|four-vector lies in the transformation laws [\{r("7")} and
        $|\{r("5")}]. Both the quantities are tensors according to the above
        $|general remarks; in it lies its significance. In accordance with
        $|\{sc("Ricci")} and \{sc("Levi-Civita")}, the contravariants and
        $|covariants are designated by the over and under indices.
      ),
    ),
  ]
}

///|
fn sec_6() -> Array[&IntoContent] {
  [
    sec("Tensors of the second and higher ranks.", 6),
    Prose(
      (
        $|\{em("Contravariant tensor")}: — If we now calculate all the 16
        $|products \{m("A^(mu nu)")} of the components \{m("A^mu")} and
        $|\{m("B^nu")}, of two contravariant four-vectors
      ),
    ),
    eq("A^(mu nu) = A^mu B^nu", "8"),
    Prose(
      (
        $|\{m("A^(mu nu)")} will according to \{r("8")} and \{r("5a")} satisfy
        $|the following transformation law.
      ),
    ),
    eq(
      "A'^(sigma tau) = (partial x'_sigma)/(partial x_mu) (partial x'_tau)/(partial x_nu) A^(mu nu)",
      "9",
    ),
    Prose(
      (
        $|We call a thing which, with reference to any reference system is
        $|defined by 16 quantities and fulfils the transformation relation
        $|\{r("9")}, a contravariant tensor of the second rank. Not every such
        $|tensor can be built from two four-vectors, (according to \{rb("8")}). But it
        $|is easy to show that any 16 quantities \{m("A^(mu nu)")}, can be
        $|represented as the sum of \{m("A^mu B^nu")} of properly chosen four
        $|pairs of four-vectors. From it, we can prove in the simplest way all
        $|laws which hold true for the tensor of the second rank defined
        $|through \{r("9")}, by proving it only for the special tensor of the
        $|type \{r("8")}.
        $|
        $|\{em("Contravariant Tensor of any rank")}: — If is clear that
        $|corresponding to \{r("8")} and \{r("9")}, we can define contravariant
        $|tensors of the 3rd and higher ranks, with \{m("4^3")}, etc.
        $|components. Thus it is clear from \{r("8")} and \{r("9")} that in
        $|this sense, we can look upon contravariant four-vectors, as
        $|contravariant tensors of the first rank.
        $|
        $|\{em("Covariant tensor")}. If on the other hand, we take the 16
        $|products \{m("A_(mu nu)")} of the components of two
        $|\{em("covariant")} four-vectors \{m("A_mu")} and \{m("B_nu")},
      ),
    ),
    eq("A_(mu nu) = A_mu B_nu", "10"),
    Prose("for them holds the transformation law"),
    eq(
      "A'_(sigma tau) = (partial x_mu)/(partial x'_sigma) (partial x_nu)/(partial x'_tau) A_(mu nu)",
      "11",
    ),
    Prose(
      (
        $|By means of these transformation laws, the covariant tensor of the
        $|second rank is defined. All remarks which we have already made
        $|concerning the contravariant tensors, hold also for covariant
        $|tensors.
        $|
        $|\{em("Remark")}:— It is convenient to treat the scalar (Invariant)
        $|either as a contravariant or a covariant tensor of zero rank.
        $|
        $|\{em("Mixed tensor")}. We can also define a tensor of the second
        $|rank of the type
      ),
    ),
    eq("A_mu^nu = A_mu B^nu", "12"),
    Prose(
      (
        $|which is covariant with reference to \{m("mu")} and contravariant
        $|with reference to \{m("nu")}. Its transformation law is
      ),
    ),
    eq(
      "A'^tau_sigma = (partial x'_tau)/(partial x_beta) (partial x_alpha)/(partial x'_sigma) A_alpha^beta",
      "13",
    ),
    Prose(
      (
        $|Naturally there are mixed tensors with any number of covariant
        $|indices, and with any number of contravariant indices. The covariant
        $|and contravariant tensors can be looked upon as special cases of
        $|mixed tensors.
        $|
        $|\{em("Symmetrical tensors")}: — A contravariant or a covariant
        $|tensor of the second or higher rank is called \{em("symmetrical")}
        $|when any two components obtained by the mutual interchange of two
        $|indices are equal. The tensor \{m("A^(mu nu)")} or
        $|\{m("A_(mu nu)")} is symmetrical, when we have for any combination
        $|of indices
      ),
    ),
    eq("A^(mu nu) = A^(nu mu)", "14"),
    Prose("or"),
    eq("A_(mu nu) = A_(nu mu)", "14a"),
    Prose(
      (
        $|It must be proved that a symmetry so defined is a property
        $|independent of the system of reference. It follows in fact from
        $|\{r("9")} remembering \{r("14")}
      ),
    ),
    dm(
      (
        #|A'^(sigma tau) = (partial x'_sigma)/(partial x_mu) (partial x'_tau)/(partial x_nu) A^(mu nu)
        #|  = (partial x'_sigma)/(partial x_mu) (partial x'_tau)/(partial x_nu) A^(nu mu)
        #|  = (partial x'_tau)/(partial x_mu) (partial x'_sigma)/(partial x_nu) A^(mu nu)
        #|  = A'^(tau sigma)
      ),
    ),
    indent(),
    Prose(
      (
        $|\{em("Anti-symmetrical tensor")}. A contravariant or covariant
        $|tensor of the 2nd, 3rd or 4th rank is called anti-symmetrical when
        $|the two components got by mutually interchanging any two indices
        $|are \{em("equal and opposite")}. The tensor \{m("A^(mu nu)")} or
        $|\{m("A_(mu nu)")} is thus anti-symmetrical when we have
      ),
    ),
    eq("A^(mu nu) = -A^(nu mu)", "15"),
    Prose("or"),
    eq("A_(mu nu) = -A_(nu mu)", "15a"),
    Prose(
      (
        $|Of the 16 components \{m("A^(mu nu)")}, the four components
        $|\{m("A^(mu mu)")} vanish, the rest are equal and opposite in pairs;
        $|so that there are only 6 numerically different components present
        $|(Six-vector).
        $|
        $|Thus we also see that the anti-symmetrical tensor
        $|\{m("A^(mu nu sigma)")} (3rd rank) has only 4 components
        $|numerically different, and the anti-symmetrical tensor
        $|\{m("A^(mu nu sigma tau)")} only one.
        $|
        $|Symmetrical tensors of ranks higher than the fourth, do not exist in
        $|a continuum of 4 dimensions.
      ),
    ),
  ]
}

///|
fn sec_7() -> Array[&IntoContent] {
  [
    sec("Multiplication of Tensors.", 7),
    Prose(
      (
        $|\{em("Outer multiplication of Tensors")}:— We get from the
        $|components of a tensor of rank \{m("z")} and another of a rank
        $|\{m("z'")}, the components of a tensor of rank \{m("z + z'")} for
        $|which we multiply all the components of the first with all the
        $|components of the second in pairs. For example, we obtain the tensor
        $|\{m("T")} from the tensors \{m("A")} and \{m("B")} of different
        $|kinds: —
      ),
    ),
    dm(
      (
        #|T_(mu nu sigma) &= A_(mu nu) B_sigma \
        #|T^(alpha beta gamma delta) &= A^(alpha beta) B^(gamma delta) \
        #|T_(alpha beta)^(gamma delta) &= A_(alpha beta) B^(gamma delta)
      ),
    ),
    Prose(
      (
        $|The proof of the tensor character of \{m("T")}, follows immediately
        $|from the expressions \{r("8")}, \{r("10")} or \{r("12")}, or the
        $|transformation equations \{r("9")}, \{r("11")}, \{r("13")};
        $|equations \{r("8")}, \{r("10")} and \{r("12")} are themselves
        $|examples of the outer multiplication of tensors of the first rank.
        $|
        $|\{em("Reduction in rank of a mixed Tensor")}. From every mixed
        $|tensor we can get a tensor which is two ranks lower, when we put an
        $|index of covariant character equal to an index of the contravariant
        $|character and sum according to these indices ("Reduction"). We get
        $|for example, out of the mixed tensor of the fourth rank
        $|\{m("A_(alpha beta)^(gamma delta)")}, the mixed tensor of the second
        $|rank
      ),
    ),
    dm(
      "A_beta^delta = T_(alpha beta)^(alpha delta) (= sum_alpha A_(alpha beta)^(alpha delta))",
    ),
    Prose(
      (
        $|and from it again by reduction, the tensor of the zero rank
        $|\{m("A = A_beta^beta = A_(alpha beta)^(alpha beta)")}.
        $|
        $|The proof that the result of reduction retains a truly tensorial
        $|character, follows either from the representation of tensor
        $|according to the generalisation of \{r("12")} in combination with
        $|\{r("6")} or out of the generalisation of \{r("13")}.
        $|
        $|\{em("Inner and mixed multiplication of Tensors")}. This consists
        $|in the combination of outer multiplication with reduction.
        $|Examples: — From the covariant tensor of the second rank
        $|\{m("A_(mu nu)")} and the contravariant tensor of the first rank
        $|\{m("B^sigma")} we get by outer multiplication the mixed tensor
      ),
    ),
    dm("D_(mu nu)^sigma = A_(mu nu) B^sigma"),
    Prose(
      "Through reduction according to indices \{m("nu, sigma")}, the covariant four vector",
    ),
    dm("D_mu = D_(mu nu)^nu = A_(mu nu) B^nu"),
    Prose("is generated."),
    Parbreak(),
    Prose(
      (
        $|These we denote as the inner product of the tensor
        $|\{m("A_(mu nu)")} and \{m("B^sigma")}. Similarly we get from the
        $|tensors \{m("A_(mu nu)")} and \{m("B^(sigma tau)")} through outer
        $|multiplication and two-fold reduction the inner product
        $|\{m("A_(mu nu) B^(mu nu)")}. Through outer multiplication and
        $|one-fold reduction we get out of \{m("A_(mu nu)")} and
        $|\{m("B^(sigma tau)")}, the mixed tensor of the second rank
        $|\{m("D_mu^tau = A_(mu nu) B^(nu tau)")}. We can fitly call this
        $|operation a mixed one; for it is outer with reference to the indices
        $|\{m("mu")} and \{m("tau")}, and inner with respect to the indices
        $|\{m("nu")} and \{m("sigma")}.
        $|
        $|We now prove a law, which will be often applicable for proving the
        $|tensor-character of certain quantities. According to the above
        $|representation, \{m("A_(mu nu) B^(mu nu)")} is a scalar, when
        $|\{m("A_(mu nu)")} and \{m("B^(sigma tau)")} are tensors. We also
        $|remark that when \{m("A_(mu nu) B^(mu nu)")} is an invariant for
        $|every choice of \{em("the tensor")} \{m("B^(mu nu)")}, then
        $|\{m("A_(mu nu)")} has a tensorial character.
        $|
        $|Proof: — According to the above assumption, for any substitution we
        $|have
      ),
    ),
    dm("A'_(sigma tau) B'^(sigma tau) = A_(mu nu) B^(mu nu)"),
    Prose("From the inversion of \{r("9")} we have however"),
    dm(
      "B^(mu nu) = (partial x_mu)/(partial x'_sigma) (partial x_nu)/(partial x'_tau) B'^(sigma tau)",
    ),
    Prose("Substitution of this in the above equation gives"),
    dm(
      "(A'_(sigma tau) - (partial x_mu)/(partial x'_sigma) (partial x_nu)/(partial x'_tau) A_(mu nu)) B'^(sigma tau) = 0",
    ),
    Prose(
      (
        $|This can be true, for any choice of \{m("B'^(sigma tau)")} only when
        $|the term within the bracket vanishes. From which by referring to
        $|\{r("11")}, the theorem at once follows. This law correspondingly
        $|holds for tensors of any rank and character. The proof is quite
        $|similar. The law can also be put in the following form. If
        $|\{m("B^mu")} and \{m("C^nu")} are any two vectors, and if for every
        $|choice of them the inner product
      ),
    ),
    dm("A_(mu nu) B^mu C^nu"),
    Prose(
      (
        $|is a scalar, then \{m("A_(mu nu)")} is a covariant tensor. The last
        $|law holds even when there is the more special formulation, that with
        $|any arbitrary choice of the four-vector \{m("B^mu")} alone the
        $|scalar product
      ),
    ),
    dm("A_(mu nu) B^mu B^nu"),
    Prose(
      (
        $|is a scalar, in which case we have the additional condition that
        $|\{m("A_(mu nu)")} satisfies the symmetry condition
        $|\{m("A_(mu nu) = A_(nu mu)")}. According to the method given above,
        $|we prove the tensor character of \{m("(A_(mu nu) + A_(nu mu))")},
        $|from which on account of symmetry follows the tensor-character of
        $|\{m("A_(mu nu)")}. This law can easily be generalized in the case of
        $|covariant and contravariant tensors of any rank.
        $|
        $|Finally, from what has been proved, we can deduce the following law
        $|which can be easily generalized for any kind of tensor: If the
        $|quantities \{m("A_(mu nu) B^nu")} form a tensor of the first rank,
        $|when \{m("B^nu")} is any arbitrarily chosen four-vector, then
        $|\{m("A_(mu nu)")} is a tensor of the second rank. If for example,
        $|\{m("C^mu")} is any four-vector, then owing to the tensor character
        $|of \{m("A_(mu nu) B^nu")}, the inner product
        $|\{m("A_(mu nu) C^mu B^nu")} is a scalar, both the four-vectors
        $|\{m("C^mu")} and \{m("B^nu")} being arbitrarily chosen. Hence the
        $|proposition follows at once.
      ),
    ),
  ]
}

///|
fn sec_8() -> Array[&IntoContent] {
  [
    sec(Prose("A few words about the Fundamental Tensor \{m("g_(mu nu)")}."), 8),
    Prose(
      (
        $|\{em("The covariant fundamental tensor")}. In the invariant
        $|expression of the square of the linear element
      ),
    ),
    dm("d s^2 = g_(mu nu) d x_mu d x_nu"),
    Prose(
      (
        $|\{m("d x_mu")} plays the role of any arbitrarily chosen
        $|contravariant vector, since further
        $|\{m("g_(mu nu) = g_(nu mu)")}, it follows from the considerations
        $|of the last paragraph that \{m("g_(mu nu)")} is a symmetrical
        $|covariant tensor of the second rank. We call it the "fundamental
        $|tensor". Afterwards we shall deduce some properties of this tensor,
        $|which will also be true for any tensor of the second rank. But the
        $|special role of the fundamental tensor in our Theory, which has its
        $|physical basis on the particularly exceptional character of
        $|gravitation makes it clear that those relations are to be developed
        $|which will be required only in the case of the fundamental tensor.
        $|
        $|\{em("The contravariant fundamental tensor")}. If we form from the
        $|determinant scheme \{m("g_(mu nu)")} the minors of
        $|\{m("g_(mu nu)")} and divide them by the determinant
        $|\{m("g = abs(g_(mu nu))")} of \{m("g_(mu nu)")}, we get certain
        $|quantities \{m("g^(mu nu) (= g^(nu mu))")}, which as we shall prove
        $|generates a contravariant tensor.
        $|
        $|According to the well-known law of Determinants
      ),
    ),
    eq("g_(mu sigma) g^(nu sigma) = delta_mu^nu", "16"),
    Prose(
      (
        $|where \{m("delta_mu^nu")} is 1, or 0, depending on \{m("mu = nu")}
        $|or \{m("mu != nu")}. Instead of the above expression for
        $|\{m("d s^2")} we can also write
      ),
    ),
    dm("g_(mu sigma) delta_nu^sigma d x_mu d x_nu"),
    Prose("or according to \{r("16")} also in the form"),
    dm("g_(mu sigma) g_(nu tau) g^(sigma tau) d x_mu d x_nu"),
    Prose(
      "Now according to the rules of multiplication, of the foregoing paragraph, the magnitudes",
    ),
    dm("d xi_sigma = g_(mu sigma) d x_mu"),
    Prose(
      (
        $|forms a covariant four-vector, and in fact (on account of the
        $|arbitrary choice of \{m("d x_mu")}) any arbitrary four-vector.
        $|
        $|If we introduce it in our expression, we get
      ),
    ),
    dm("d s^2 = g^(sigma tau) d xi_sigma d xi_tau"),
    Prose(
      (
        $|For any choice of the vectors \{m("d xi_sigma")} this is scalar, and
        $|\{m("g^(sigma tau)")}, according to its definition is a symmetrical
        $|thing in \{m("sigma")} and \{m("tau")}, so it follows from the above
        $|results, that \{m("g^(sigma tau)")} is a contravariant tensor. Out
        $|of \{r("16")} it also follows that \{m("delta_mu^nu")} is a tensor
        $|which we may call the mixed fundamental tensor.
        $|
        $|\{em("Determinant of the fundamental tensor")}. According to the law
        $|of multiplication of determinants, we have
      ),
    ),
    dm(
      "abs(g_(mu alpha) g^(alpha nu)) = abs(g_(mu alpha)) thin abs(g^(alpha nu))",
    ),
    Prose("On the other hand we have"),
    dm("abs(g_(mu alpha) g^(alpha nu)) = abs(delta_mu^nu) = 1"),
    Prose("So that it follows"),
    eq("abs(g_(mu nu)) thin abs(g^(mu nu)) = 1", "17"),
    indent(),
    Prose(
      (
        $|\{em("Invariant of volume.")} We seek first the transformation law
        $|for the determinant \{m("g = abs(g_(mu nu))")}. According to
        $|\{r("11")}
      ),
    ),
    dm(
      "g' = abs((partial x_mu)/(partial x'_sigma) (partial x_nu)/(partial x'_tau) g_(mu nu))",
    ),
    Prose("From this by applying the law of multiplication twice, we obtain."),
    dm(
      (
        #|g' = abs((partial x_mu)/(partial x'_sigma)) thin abs((partial x_nu)/(partial x'_tau)) thin abs(g_(mu nu))
        #|   = abs((partial x_mu)/(partial x'_sigma))^2 g
      ),
    ),
    Prose("or"),
    dm("sqrt(g') = abs((partial x_mu)/(partial x'_sigma)) sqrt(g)"),
    Prose("On the other hand the law of transformation of the volume element"),
    dm("d tau' = integral d x_1 d x_2 d x_3 d x_4"),
    Prose("is according to the well-known law of \{sc("Jacobi")}."),
    dm("d tau' = abs((partial x'_sigma)/(partial x_mu)) d tau"),
    Prose("By multiplication of the two last equations we get"),
    eq("sqrt(g') d tau' = sqrt(g) d tau", "18"),
    Prose(
      (
        $|Instead of \{m("sqrt(g)")}, we shall afterwards introduce
        $|\{m("sqrt(-g)")} which has a real value on account of the
        $|hyperbolic character of the time-space continuum. The invariant
        $|\{m("sqrt(-g) d tau")} is equal in magnitude to the four-dimensional
        $|volume-element measured with solid rods and clocks, in accordance
        $|with the special relativity theory.
        $|
        $|\{em("Remarks on the character of the space-time continuum")} — Our
        $|assumption that in an infinitely small region the special relativity
        $|theory holds, leads us to conclude that \{m("d s^2")} can always,
        $|according to \{r("1")} be expressed in real magnitudes
        $|\{m("d X_1 thin dots thin d X_4")}. If we call \{m("d tau_0")} "natural"
        $|volume element \{m("d X_1 d X_2 d X_3 d X_4")}, we have thus
      ),
    ),
    eq("d tau_0 = sqrt(-g) d tau", "18a"),
    Prose(
      (
        $|Should \{m("sqrt(-g)")} vanish at any point of the four-dimensional
        $|continuum it would signify that to a finite co-ordinate volume at
        $|the place corresponds an infinitely small "natural" volume. This can
        $|never be the case; so that \{m("g")} can never change its sign; we
        $|would, according to the special relativity theory assume that
        $|\{m("g")} has a finite negative value. It is a hypothesis about the
        $|physical nature of the continuum considered, and also a
        $|pre-established rule for the choice of co-ordinates.
        $|
        $|If however \{m("-g")} remains positive and finite, it is clear that
        $|the choice of co-ordinates can be so made that this quantity becomes
        $|equal to one. We would afterwards see that such a limitation of the
        $|choice of co-ordinates would produce a significant simplification in
        $|expressions for laws of nature.
        $|
        $|In place of \{r("18")} it follows then simply that
      ),
    ),
    dm("d tau' = d tau"),
    Prose("from this it follows, remembering the law of \{sc("Jacobi")},"),
    eq("abs((partial x'_sigma)/(partial x_mu)) = 1", "19"),
    Prose(
      (
        $|With this choice of co-ordinates, only substitutions with
        $|determinant 1, are allowable.
        $|
        $|It would however be erroneous to think that this step signifies a
        $|partial renunciation of the general relativity postulate. We do not
        $|seek those laws of nature which are covariants with regard to the
        $|transformations having the determinant 1, but we ask: what are the
        $|\{em("general")} covariant laws of nature? First we get the law, and
        $|then we simplify its expression by a special choice of the system of
        $|reference.
        $|
        $|\{em("Building up of new tensors with the help of the fundamental tensor.")}
        $|Through inner, outer and mixed multiplications of a tensor with the
        $|fundamental tensor, tensors of other kinds and of other ranks can be
        $|formed.
        $|
        $|Example:—
      ),
    ),
    dm(
      (
        #|A^mu &= g^(mu sigma) A_sigma \
        #|A &= g_(mu nu) A^(mu nu)
      ),
    ),
    Prose("We would point out specially the following combinations:"),
    dm(
      (
        #|A^(mu nu) &= g^(mu alpha) g^(nu beta) A_(alpha beta) \
        #|A_(mu nu) &= g_(mu alpha) g_(nu beta) A^(alpha beta)
      ),
    ),
    Prose("(\"complement\" to the covariant or contravariant tensors) and,"),
    dm("B_(mu nu) = g_(mu nu) g^(alpha beta) A_(alpha beta)"),
    Prose(
      (
        $|We can call \{m("B_(mu nu)")} the reduced tensor related to
        $|\{m("A_(mu nu)")}.
        $|
        $|Similarly
      ),
    ),
    dm("B^(mu nu) = g^(mu nu) g_(alpha beta) A^(alpha beta)"),
    Prose(
      (
        $|It is to be remarked that \{m("g^(mu nu)")} is no other than the
        $|complement of \{m("g_(mu nu)")}, for we have —
      ),
    ),
    dm(
      "g^(mu alpha) g^(nu beta) g_(alpha beta) = g^(mu alpha) delta_alpha^nu = g^(mu nu)",
    ),
  ]
}
