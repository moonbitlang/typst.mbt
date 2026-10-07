// The opening paragraph and part A (§ 1 to § 4): the text of the Wikisource
// transcription of S. N. Bose's translation (1920), without its footnotes
// (`colophon` in `main.mbt` and `../README.md` say why, and where the
// translation is in the public domain).

///|
fn opening() -> Array[&IntoContent] {
  [
    Prose(
      (
        $|The theory which is sketched in the following pages forms the most
        $|wide-going generalization conceivable of what is at present known as
        $|"the theory of Relativity;" this latter theory I differentiate from
        $|the former "Special Relativity theory," and suppose it to be known.
        $|The generalization of the Relativity theory has been made much easier
        $|through the form given to the special Relativity theory by
        $|\{em("Minkowski")}, which mathematician was the first to recognize
        $|clearly the formal equivalence of the space like and time-like
        $|co-ordinates, and who made use of it in the building up of the
        $|theory. The mathematical apparatus useful for the general relativity
        $|theory, lay already complete in the "Absolute Differential Calculus",
        $|which were based on the researches of \{sc("Gauss")},
        $|\{sc("Riemann")} and \{sc("Christoffel")} on the non-Euclidean
        $|manifold, and which have been shaped into a system by
        $|\{sc("Ricci")} and \{sc("Levi-Civita")}, and already applied to the
        $|problems of theoretical physics. I have in part B of this
        $|communication developed in the simplest and clearest manner, all the
        $|supposed mathematical auxiliaries, not known to Physicists, which
        $|will be useful for our purpose, so that, a study of the mathematical
        $|literature is not necessary for an understanding of this paper.
        $|Finally in this place I thank my friend \{sc("Grossmann")}, by whose
        $|help I was not only spared the study of the mathematical literature
        $|pertinent to this subject, but who also aided me in the researches on
        $|the field equations of gravitation.
      ),
    ),
  ]
}

///|
fn part_a() -> Array[&IntoContent] {
  [
    part("A. Principal considerations about the Postulate of Relativity."),
    sec("Remarks on the Special Relativity Theory.", 1),
    Prose(
      (
        $|The special relativity theory rests on the following postulate which
        $|also holds valid for the \{sc("Galileo-Newton")}ian mechanics.
        $|
        $|If a co-ordinate system \{m("K")} be so chosen that when referred to
        $|it the physical laws hold in their simplest forms, \{em("these")}
        $|laws would be also valid when referred to another system of
        $|co-ordinates \{m("K'")} which is subjected to an uniform
        $|translational motion relative to \{m("K")}. We call this postulate
        $|"The Special Relativity Principle". By the word special, it is
        $|signified that the principle is limited to the case, when
        $|\{m("K'")} has \{em("uniform translatory motion")} with reference to
        $|\{m("K")}, but the equivalence of \{m("K")} and \{m("K'")} does not
        $|extend to the case of \{em("non-uniform")} motion of \{m("K'")}
        $|relative to \{m("K")}.
        $|
        $|The Special Relativity Theory does not differ from the classical
        $|mechanics through the assumption of this postulate, but only through
        $|the postulate of the constancy of light-velocity in vacuum which,
        $|when combined with the special relativity postulate, gives in a
        $|well-known way, the relativity of synchronism as well as the Lorentz
        $|transformation, with all the relations between moving rigid bodies
        $|and clocks.
        $|
        $|The modification which the theory of space and time has undergone
        $|through the special relativity theory, is indeed a profound one, but
        $|\{em("a")} weightier point remains untouched. According to the
        $|special relativity theory, the theorems of geometry are to be looked
        $|upon as the laws about any possible relative positions of solid
        $|bodies at rest, and more generally the theorems of kinematics, as
        $|theorems which describe the relation between measurable bodies and
        $|clocks. Consider two material points of a solid body at rest; then
        $|according to these conceptions there corresponds to these points a
        $|wholly definite extent of length, independent of kind, position,
        $|orientation and time of the body.
        $|
        $|Similarly let us consider two positions of the pointers of a clock
        $|which is at rest with reference to a co-ordinate system; then to
        $|these positions, there always corresponds a time-interval of a
        $|definite length, independent of time and place. It would be soon
        $|shown that the general relativity theory can not hold fast to this
        $|simple physical significance of space and time.
      ),
    ),
    sec(
      "About the reasons which explain the extension of the relativity-postulate.",
      2,
    ),
    Prose(
      (
        $|To the classical mechanics (no less than) to the special relativity
        $|theory, is attached an epistemological defect, which was perhaps
        $|first clearly pointed out by E. \{sc("Mach")}. We shall illustrate it
        $|by the following example; Let two fluid bodies of equal kind and
        $|magnitude swim freely in space at such a great distance from one
        $|another (and from all other masses) that only that sort of
        $|gravitational forces are to be taken into account which the parts of
        $|\{em("any")} of these bodies exert upon each other. The distance of
        $|the bodies from one another is invariable. The relative motion of
        $|the different parts of each body is not to occur. But each mass is
        $|seen to rotate by an observer at rest relative to the other mass
        $|round the connecting line of the masses with a constant angular
        $|velocity (definite relative motion for both the masses). Now let us
        $|think that the surfaces of both the bodies (\{m("S_1")} and
        $|\{m("S_2")}) are measured with the help of measuring rods
        $|(relatively at rest); it is then found that the surface of
        $|\{m("S_1")} is a sphere and the surface of the other is an ellipsoid
        $|of rotation. We now ask, why is this difference between the two
        $|bodies? An answer to this question can only then be regarded as
        $|satisfactory from the epistemological standpoint when the
        $|thing adduced as the cause is an
        $|\{em("observable fact of experience")}. The law of causality has the
        $|sense of a definite statement about the world of experience only
        $|when \{em("observable facts")} alone appear as causes and effects.
        $|
        $|The Newtonian mechanics does not give to this question any
        $|satisfactory answer. For example, it says:— The laws of mechanics
        $|hold true for a space \{m("R_1")} relative to which the body
        $|\{m("S_1")} is at rest, not however for a space relative to which
        $|\{m("S_2")} is at rest.
        $|
        $|The \{sc("Galili")}ean space, which is here introduced is however
        $|only a \{em("purely imaginary")} cause, not an observable thing. It
        $|is thus clear that the \{sc("Newton")}ian mechanics does not, in the
        $|case treated here, actually fulfil the requirements of causality,
        $|but produces on the mind a fictitious complacency, in that it makes
        $|responsible a wholly imaginary cause \{m("R_1")} for the different
        $|behaviours of the bodies \{m("S_1")} and \{m("S_2")} which are
        $|actually observable.
        $|
        $|A satisfactory explanation to the question put forward above can
        $|only be thus given:— that the physical system composed of
        $|\{m("S_1")} and \{m("S_2")} shows for itself alone no conceivable
        $|cause to which the different behaviour of \{m("S_1")} and
        $|\{m("S_2")} can be attributed. The cause must thus lie
        $|\{em("outside")} the system. We are therefore led to the conception
        $|that the general laws of motion which determine specially the forms
        $|of \{m("S_1")} and \{m("S_2")} must be of such a kind, that the
        $|mechanical behaviour of \{m("S_1")} and \{m("S_2")} must be
        $|essentially conditioned by the distant masses, which we had not
        $|brought into the system considered. These distant masses, (and
        $|their relative motion as regards the bodies under consideration) are
        $|then to be looked upon as the seat of the principal observable
        $|causes for the different behaviours of the bodies under
        $|consideration. They take the place of the imaginary cause
        $|\{m("R_1")}. Among all the conceivable spaces \{m("R_1")} and
        $|\{m("R_2")} etc. moving in any manner relative to one another, there
        $|is a priori, no one set which can be regarded as affording greater
        $|advantages, against which the objection which was already raised
        $|from the standpoint of the theory of knowledge cannot be again
        $|revived.
        $|\{em("The laws of physics must be so constituted that they should remain valid for any system of co-ordinates moving in any manner")}.
        $|We thus arrive at an extension of the relativity postulate.
        $|
        $|Besides this momentous epistemological argument, there is also a
        $|well-known physical fact which speaks in favour of an extension of
        $|the relativity theory. Let there be a \{sc("Galili")}ean co-ordinate
        $|system \{m("K")} relative to which (at least in the four-dimensional
        $|region considered) a mass at a sufficient distance from other masses
        $|move uniformly in a line. Let \{m("K'")} be a second co-ordinate
        $|system which has a \{em("uniformly accelerated")} motion relative to
        $|\{m("K")}. Relative to \{m("K'")} any mass at a sufficiently great
        $|distance experiences an accelerated motion such that its
        $|acceleration and its direction of acceleration is independent of its
        $|material composition and its physical conditions.
        $|
        $|Can any observer, at rest relative to \{m("K'")}, then conclude that
        $|he is in an actually accelerated reference-system? This is to be
        $|answered in the negative; the above-named behaviour of the freely
        $|moving masses relative to \{m("K'")} can be explained in as good a
        $|manner in the following way. The reference-system \{m("K'")} has no
        $|acceleration. In the space-time region considered there is a
        $|gravitation-field which generates the accelerated motion relative to
        $|\{m("K'")}.
        $|
        $|This conception is feasible, because to us the experience of the
        $|existence of a field of force (namely the gravitation field) has
        $|shown that it possesses the remarkable property of imparting the
        $|same acceleration to all bodies. The mechanical
        $|behaviour of the bodies relative to \{m("K'")} is the same as
        $|experience would expect of them with reference to systems which we
        $|assume from habit as stationary; thus it explains why from the
        $|physical stand-point it can be assumed that the systems \{m("K")}
        $|and \{m("K'")} can both with the same legitimacy be taken as at
        $|rest, that is, they will be equivalent as systems of reference for a
        $|description of physical phenomena.
        $|
        $|From these discussions we see, that the working out of the general
        $|relativity theory must, at the same time, lead to a theory of
        $|gravitation; for we can "create" a gravitational field by a simple
        $|variation of the co-ordinate system. Also we see immediately that
        $|the principle of the constancy of light-velocity must be modified,
        $|for we recognise easily that the path of a ray of light with
        $|reference to \{m("K'")} must be, in general, curved, when light
        $|travels with a definite and constant velocity in a straight line
        $|with reference to \{m("K")}.
      ),
    ),
    sec(
      "The time-space continuum. Requirements of the general Co-variance for the equations expressing the laws of Nature in general.",
      3,
    ),
    Prose(
      (
        $|In the classical mechanics as well as in the special relativity
        $|theory, the co-ordinates of time and space have an immediate
        $|physical significance; when we say that any arbitrary point has
        $|\{m("x_1")} as its \{m("X_1")} co-ordinate, it signifies that the
        $|projection of the point-event on the \{m("X_1")}-axis ascertained by
        $|means of a solid rod according to the rules of Euclidean Geometry is
        $|reached when a definite measuring rod, the unit rod, can be carried
        $|\{m("x_1")} times from the origin of co-ordinates along the
        $|\{m("X_1")} axis. A point having \{m("x_4 = t")} as the
        $|\{m("X_1")} co-ordinate signifies that a unit clock which is
        $|adjusted to be at rest relative to the system of co-ordinates, and
        $|coinciding in its spatial position, with the point-event and set
        $|according to some definite standard has gone over \{m("x_4 = t")}
        $|periods before the occurrence of the point-event.
        $|
        $|This conception of time and space is continually present in the mind
        $|of the physicist, though often in an unconscious way, as is clearly
        $|recognised from the role which this conception has played in
        $|physical measurements. This conception must also appear to the
        $|reader to be lying at the basis of the second consideration of the
        $|last paragraph and imparting a sense to these conceptions. But we
        $|wish to show that we are to abandon it and in general to replace it
        $|by more general conceptions in order to be able to work out
        $|thoroughly the postulate of general relativity,— the case of special
        $|relativity appearing as a limiting case when there is no gravitation.
        $|
        $|We introduce in a space, which is free from Gravitation-field, a
        $|\{sc("Galili")}ean Co-ordinate System \{m("K(x, y, z, t)")} and
        $|also, another system \{m("K'(x', y', z', t')")} rotating uniformly
        $|relative to \{m("K")}. The origin of both the systems as well as
        $|their \{m("Z")}-axes might continue to coincide. We will show that
        $|for a space-time measurement in the system \{m("K'")}, the above
        $|established rules for the physical significance of time and space
        $|can not be maintained. On grounds of symmetry it is clear that a
        $|circle round the origin in the \{m("X")}-\{m("Y")} plane of
        $|\{m("K")}, can also be looked upon as a circle in the
        $|\{m("X'")}-\{m("Y'")} plane of \{m("K'")}. Let us now think of
        $|measuring the circumference and the diameter of these circles, with
        $|a unit measuring rod (infinitely small compared with the radius) and
        $|take the quotient of both the results of measurement. If this
        $|experiment be carried out with a measuring rod at rest relatively to
        $|the \{sc("Galili")}ean system \{m("K")} we would get \{m("pi")}, as
        $|the quotient. The result of measurement with a rod relatively at
        $|rest as regards \{m("K'")} would be a number which is greater than
        $|\{m("pi")}. This can be seen easily when we regard the whole
        $|measurement-process from the system \{m("K")} and remember that the
        $|rod placed on the periphery suffers a Lorentz-contraction, not
        $|however when the rod is placed along the radius. Euclidean Geometry
        $|therefore does not hold for the system \{m("K'")}; the above fixed
        $|conceptions of co-ordinates which assume the validity of
        $|\{sc("Euclid")}ean Geometry fail with regard to the system
        $|\{m("K'")}. We cannot similarly introduce in \{m("K'")} a time
        $|corresponding to physical requirements, which will be shown by all
        $|similarly prepared clocks at rest relative to the system
        $|\{m("K'")}. In order to see this we suppose that two similarly made
        $|clocks are arranged one at the centre and one at the periphery of
        $|the circle, and considered from the stationary system \{m("K")}.
        $|According to the well-known results of the special relativity
        $|theory it follows — (as viewed from \{m("K")}) — that the clock
        $|placed at the periphery will go slower than the second one which is
        $|at rest. The observer at the common origin of co-ordinates who is
        $|able to see the clock at the periphery by means of light will see
        $|the clock at the periphery going slower than the clock beside him.
        $|Since he cannot allow the velocity of light to depend explicitly
        $|upon the time in the way under consideration he will interpret his
        $|observation by saying that the clock on the periphery "actually"
        $|goes slower than the clock at the origin. He cannot therefore do
        $|otherwise than define time in such a way that the rate of going of a
        $|clock depends on its position.
        $|
        $|We therefore arrive at this result. In the general relativity theory
        $|time and space magnitudes cannot be so defined that the difference
        $|in spatial co-ordinates can be immediately measured by the
        $|unit-measuring rod, and time-like co-ordinate difference with the
        $|aid of a normal clock.
        $|
        $|The means hitherto at our disposal, for placing our co-ordinate
        $|system in the time-space continuum, in a definite way, therefore
        $|completely fail and it appears that there is no \{em("other")} way
        $|which will enable us to fit the co-ordinate system to the
        $|four-dimensional world in such a way, that by it we can expect to
        $|get a specially simple formulation of the laws of Nature. So that
        $|nothing remains for us but to regard all conceivable
        $|co-ordinate systems as equally suitable for the description of
        $|natural phenomena. This amounts to the following law:—
        $|
        $|\{em("That in general, Laws of Nature are expressed by means of equations which are valid for all co-ordinate systems, that is, which are covariant for all possible transformations.")}
        $|It is clear that a physics which satisfies this postulate will be
        $|unobjectionable from the standpoint of the general relativity
        $|postulate. Because among \{em("all")} substitutions there are, in
        $|every case, contained those, which correspond to all relative
        $|motions of the co-ordinate system (in three dimensions). This
        $|condition of general covariance which takes away the last remnants
        $|of physical objectivity from space and time, is a natural
        $|requirement, as seen from the following considerations. All our
        $|well-substantiated space-time propositions amount to the
        $|determination of space-time coincidences. If, for example, the event
        $|consisted in the motion of material points, then, for this last
        $|case, nothing else are really observable except the encounters
        $|between two or more of these material points. The results of our
        $|measurements are nothing else than well-proved theorems about such
        $|coincidences of material points, of our measuring rods with other
        $|material points, coincidences between the hands of a clock,
        $|dial-marks and point-events occurring at the same position and at
        $|the same time.
        $|
        $|The introduction of a system of co-ordinates serves no other purpose
        $|than an easy description of totality of such coincidences. We fit to
        $|the world our space-time variables \{m("x_1, x_2, x_3, x_4")} such
        $|that to any and every point-event corresponds a system of values of
        $|\{m("x_1 thin dots thin x_4")}. Two coincident point-events correspond to the
        $|same value of the variables \{m("x_1 thin dots thin x_4")}; \{em("i.e.")}, the
        $|coincidence is characterised by the equality of the co-ordinates. If
        $|we now introduce any four functions \{m("x'_1, x'_2, x'_3, x'_4")}
        $|as coordinates, so that there is an unique correspondence between
        $|them, the equality of all the four co-ordinates in the new system
        $|will still be the expression of the space-time coincidence of two
        $|material points. As the purpose of all physical laws is to allow us
        $|to remember such coincidences, there is a priori no reason present,
        $|to prefer a certain co-ordinate system to another; \{em("i.e.")}, we
        $|get the condition of general covariance.
      ),
    ),
    sec(
      "Relation of four co-ordinates to spatial and temporal measurements. Analytical expression for the Gravitation-field.",
      4,
    ),
    Prose(
      (
        $|I am not trying in this communication to deduce the general
        $|Relativity-theory as the simplest logical system possible, with a
        $|minimum of axioms. But it is my chief aim to develop the theory in
        $|such a manner that the reader perceives the psychological
        $|naturalness of the way proposed, and the fundamental assumptions
        $|appear to be most reasonable according to the light of experience.
        $|In this sense, we shall now introduce the following supposition;
        $|that for an infinitely small four-dimensional region, the relativity
        $|theory is valid in the special sense when the axes are suitably
        $|chosen.
        $|
        $|The nature of acceleration of an infinitely small (positional)
        $|co-ordinate system is hereby to be so chosen, that the gravitational
        $|field does not appear; this is possible for an infinitely small
        $|region. \{m("X_1, X_2, X_3")} are the spatial co-ordinates;
        $|\{m("X_4")} is the corresponding time-co-ordinate
        $|measured by some suitable measuring clock. These
        $|coordinates have, with a given orientation of the system, an
        $|immediate physical significance in the sense of the special
        $|relativity theory (when we take a rigid rod as our unit of measure),
        $|The expression
      ),
    ),
    eq("d s^2 = -d X_1^2 - d X_2^2 - d X_3^2 + d X_4^2", "1"),
    Prose(
      (
        $|had then, according to the special relativity theory, a value which
        $|may be obtained by space-time measurement, and which is independent
        $|of the orientation of the local co-ordinate system. Let us take
        $|\{m("d s")} as the magnitude of the line-element belonging to two
        $|infinitely near points in the four-dimensional region. If
        $|\{m("d s^2")} belonging to the element \{m("(d X_1 thin dots thin d X_4)")}
        $|be positive we call it with \{sc("Minkowski")}, time-like, and in
        $|the contrary case space-like.
        $|
        $|To the line-element considered, \{em("i.e.")}, to both the
        $|infinitely near point-events belong also definite differentials
        $|\{m("d x_1 thin dots thin d x_4")}, of the four-dimensional co-ordinates of
        $|any chosen system of reference. If there be also a local system of
        $|the above kind given for the case under consideration,
        $|\{m("d X_nu")} would then be represented by definite linear
        $|homogeneous expressions of \{m("d x_sigma")}
      ),
    ),
    eq("d X_nu = sum_sigma alpha_(nu sigma) d x_sigma", "2"),
    Prose("If we substitute the expression in \{r("1")} we get"),
    eq("d s^2 = sum_(sigma tau) g_(sigma tau) d x_sigma d x_tau", "3"),
    Prose(
      (
        $|where \{m("g_(sigma tau)")} will be functions of \{m("x_sigma")},
        $|but will no longer depend upon the orientation and motion of the
        $|"local" co-ordinates; for \{m("d s^2")} is a definite magnitude
        $|belonging to two point-events infinitely near in space and time and
        $|can be got by measurements with rods and clocks. The
        $|\{m("g_(sigma tau)")} are hereto be so chosen, that
        $|\{m("g_(sigma tau) = g_(tau sigma)")}; the summation is to be
        $|extended over all values of \{m("sigma")} and \{m("tau")}, so that
        $|the sum is to be extended, over 4×4 terms, of which 12 are equal in
        $|pairs.
        $|
        $|From the method adopted here, the case of the usual relativity
        $|theory comes out when owing to the special behaviour of
        $|\{m("g_(sigma tau)")} in a finite region it is possible to choose
        $|the system of co-ordinates in such a way that
        $|\{m("g_(sigma tau)")} assumes constant values —
      ),
    ),
    eq(
      (
        #|mat(delim: #("{", none), column-gap: #1.8em, row-gap: #0.5em,
        #|  -1, 0, 0, 0;
        #|  0, -1, 0, 0;
        #|  0, 0, -1, 0;
        #|  0, 0, 0, +1)
      ),
      "4",
    ),
    Prose(
      (
        $|We would afterwards see that the choice of such a system of
        $|co-ordinates for a finite region is in general not possible.
        $|
        $|From the considerations in \{s(2)} and \{s(3)} it is clear, that
        $|from the physical stand-point the quantities \{m("g_(sigma tau)")}
        $|are to be looked upon as magnitudes which describe the
        $|gravitation-field with reference to the chosen system of axes. We
        $|assume firstly, that in a certain four-dimensional region
        $|considered, the special relativity theory is true for some
        $|particular choice of co-ordinates. The \{m("g_(sigma tau)")} then
        $|have the values given in \{r("4")}. A free material point moves with
        $|reference to such a system uniformly in a straight line. If we now
        $|introduce, by any substitution, the space-time co-ordinates
        $|\{m("x_1 thin dots thin x_4")}, then in the new system \{m("g_(mu nu)")} are
        $|no longer constants, but functions of space and time. At the same
        $|time, the motion of a free point-mass in the new co-ordinates, will
        $|appear as curvilinear, and not uniform, in which the law of motion,
        $|will be independent of the nature of the moving mass-points. We can
        $|thus signify this motion as one under the influence of a gravitation
        $|field. We see that the appearance of a gravitation-field is
        $|connected with space-time variability of \{m("g_(sigma tau)")}. In
        $|the general case, we can not by any suitable choice of axes, make
        $|special relativity theory valid throughout any finite region. We
        $|thus deduce the conception that \{m("g_(sigma tau)")} describe the
        $|gravitational field. According to the general relativity theory,
        $|gravitation thus plays an exceptional role as distinguished from the
        $|others, specially the electromagnetic forces, in as much as the 10
        $|functions \{m("g_(sigma tau)")} representing gravitation, define
        $|immediately the metrical properties of the four-dimensional region.
      ),
    ),
  ]
}
