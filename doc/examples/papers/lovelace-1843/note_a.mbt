// Note A (Scientific Memoirs, vol. 3, pages 691 to 701), verbatim from the
// Wikisource transcription. Misprints of 1843 that the transcription marks
// ("tho" on page 696) are kept.

///|
fn note_a() -> Array[&IntoContent] {
  let delta7 = disp("Delta^7 u_z = 0.")
  let delta7_bare = disp("Delta^7 u_z = 0")
  let integral = disp("u_z = a + b x + c x^2 + d x^3 + e x^4 + f x^5 + g x^6,")
  let general = disp("upright(F)(x, y, z, log x, sin y, x^p, \{etc}),")
  let special = disp("upright(F)(x, y, z, \{etc} \{etc})")
  let delta_n = disp("Delta^n u_z = 0")
  let series_n = disp("u_z = a + b x + c x^2 + dots.h m x^(n-1),")
  let cards = Footnote(
    Prose(
      (
        $|We do not mean to imply that the \{i("only")} use made of the Jacquard cards is
        $|that of regulating the algebraical \{i("operations")}. But we mean to explain
        $|that \{i("those")} cards and portions of mechanism which regulate these
        $|\{i("operations")}, are wholly independent of those which are used for other
        $|purposes. M. Menabrea explains that there are \{i("three")} classes of cards
        $|used in the engine for three distinct sets of objects, viz.
        $|\{i("Cards of the Operations")}, \{i("Cards of the Variables")}, and certain
        $|\{i("Cards of Numbers")}. (See pages 678 and 687.)
      ),
    ),
  )
  let product = disp("a + b x + c x^2 + dots.h p x^n.")
  let signs = Footnote(
    Prose(
      (
        $|In fact such an extension as we allude to, would merely constitute a further
        $|and more perfected development of any system introduced for making the proper
        $|combinations of the signs \{i("plus")} and \{i("minus")}. How ably M. Menabrea
        $|has touched on this restricted case is pointed out in Note B.
      ),
    ),
  )
  let delta_n_semi = disp("Delta^n u_z = 0;")
  let seven = Footnote(
    Prose(
      (
        $|The machine might have been constructed so as to tabulate for a higher value
        $|of \{m("n")} than seven. Since, however, every unit added to the value of
        $|\{m("n")} increases the extent of the mechanism requisite, there would on this
        $|account be a limit beyond which it could not be practically carried. Seven is
        $|sufficiently high for the calculation of all ordinary tables.
        $|
        $|The fact that, in the Analytical Engine, the same extent of mechanism suffices
        $|for the solution of \{m("Delta^n u_z = 0")}, whether \{m("n = 7")},
        $|\{m("n = 100,000")}, or \{m("n =")} any number whatever, at once suggests how
        $|entirely distinct must be the \{i("nature of the principles")} through whose
        $|application matter has been enabled to become the working agent of abstract
        $|mental operations in each of these engines respectively; and it affords an
        $|equally obvious presumption, that in the case of the Analytical Engine, not
        $|only are those principles in themselves of a higher and more comprehensive
        $|description, but also such as must vastly extend the \{i("practical")} value of
        $|the engine whose basis they constitute.
      ),
    ),
  )
  let occasion = Footnote(Prose("This subject is further noticed in Note F."))
  [
    (
      $|The particular function whose integral the Difference Engine was constructed
      $|to tabulate, is \{delta7} The purpose which that engine has been specially
      $|intended and adapted to fulfil, is the computation of nautical and astronomical
      $|tables. The integral of \{delta7_bare} being \{integral} the constants
      $|\{m("a")}, \{m("b")}, \{m("c")}, &c. are represented on the seven columns of
      $|discs, of which the engine consists. It can therefore tabulate
      $|\{i("accurately")} and to an \{i("unlimited extent")}, all series whose general
      $|term is comprised in the above formula; and it can also tabulate
      $|\{i("approximatively")} between \{i("intervals of greater or less extent")}, all
      $|other series which are capable of tabulation by the Method of Differences.
    )
    |> indented,
    (
      $|The Analytical Engine, on the contrary, is not merely adapted for
      $|\{i("tabulating")} the results of one particular function and of no other, but
      $|for \{i("developing and tabulating")} any function whatever. In fact the engine
      $|may be described as being the material expression of any indefinite function of
      $|any degree of generality and complexity, such as for instance, \{general} which
      $|is, it will be observed, a function of all other possible functions of any
      $|number of quantities.
    )
    |> par,
    (
      $|In this, which we may call the \{i("neutral")} or \{i("zero state")} of the
      $|engine, it is ready to receive at any moment, by means of cards constituting a
      $|portion of its mechanism (and applied on the principle of those used in the
      $|Jacquard-loom), the impress of whatever \{i("special")} function we may desire
      $|to develope or to tabulate. These cards contain within themselves (in a manner
      $|explained in the Memoir itself, pages 677 and 678) the law of development of
      $|the particular function that may be under consideration, and they compel the
      $|mechanism to act accordingly in a certain corresponding order. One of the
      $|simplest cases would be, for example, to suppose that \{special} is the
      $|particular function \{delta_n} which the Difference Engine tabulates for values
      $|of \{m("n")} only up to 7. In this case the cards would order the mechanism to
      $|go through that succession of operations which would tabulate \{series_n}
      $|where \{m("n")} might be any number whatever.
    )
    |> par,
    (
      $|These cards, however, have nothing to do with the regulation of the particular
      $|\{i("numerical")} data. They merely determine the \{i("operations")}\{cards} to
      $|be effected, which operations may of course be performed on an infinite variety
      $|of particular numerical values, and do not bring out any definite numerical
      $|results unless the numerical data of the problem have been impressed on the
      $|requisite portions of the train of mechanism. In the above example, the first
      $|essential step towards an arithmetical result, would be the substitution of
      $|specific numbers for \{m("n")}, and for the other primitive quantities which
      $|enter into the function.
    )
    |> par,
    (
      $|Again, let us suppose that for \{m("bold(upright(F))")} we put two complete equations of
      $|the fourth degree between \{m("x")} and \{m("y")}. We must then express on the
      $|cards the law of elimination for such equations. The engine would follow out
      $|those laws, and would ultimately give the equation of one variable which
      $|results from such elimination. Various \{i("modes")} of elimination might be
      $|selected; and of course the cards must be made out accordingly. The following
      $|is one mode that might be adopted. The engine is able to multiply together any
      $|two functions of the form \{product} This granted, the two equations may be
      $|arranged according to the powers of \{m("y")}, and the coefficients of the
      $|powers of \{m("y")} may be arranged according to powers of \{m("x")}. The
      $|elimination of \{m("y")} will result from the successive multiplications and
      $|subtractions of several such functions. In this, and in all other instances, as
      $|was explained above, the particular \{i("numerical")} data and the
      $|\{i("numerical")} results are determined by means and by portions of the
      $|mechanism which act quite independently of those that regulate the
      $|\{i("operations")}.
    )
    |> par,
    (
      $|In studying the action of the Analytical Engine, we find that the peculiar and
      $|independent nature of the considerations which in all mathematical analysis
      $|belong to \{i("operations")}, as distinguished from
      $|\{i("the objects operated upon")} and from the \{i("results")} of the
      $|operations performed upon those objects, is very strikingly defined and
      $|separated.
    )
    |> par,
    (
      $|It is well to draw attention to this point, not only because its full
      $|appreciation is essential to the attainment of any very just and adequate
      $|general comprehension of the powers and mode of action of the Analytical
      $|Engine, but also because it is one which is perhaps too little kept in view in
      $|the study of mathematical science in general. It is, however, impossible to
      $|confound it with other considerations, either when we trace the manner in which
      $|that engine attains its results, or when we prepare the data for its attainment
      $|of those results. It were much to be desired, that when mathematical processes
      $|pass through the human brain instead of through the medium of inanimate
      $|mechanism, it were equally a necessity of things that the reasonings connected
      $|with \{i("operations")} should hold the same just place as a clear and
      $|well-defined branch of the subject of analysis, a fundamental but yet
      $|independent ingredient in the science, which they must do in studying the
      $|engine. The confusion, the difficulties, the contradictions which, in
      $|consequence of a want of accurate distinctions in this particular, have up to
      $|even a recent period encumbered mathematics in all those branches involving the
      $|consideration of negative and impossible quantities, will at once occur to the
      $|reader who is at all versed in this science, and would alone suffice to justify
      $|dwelling somewhat on the point, in connexion with any subject so peculiarly
      $|fitted to give forcible illustration of it, as the Analytical Engine. It may be
      $|desirable to explain, that by the word \{i("operation")}, we mean
      $|\{i("any process which alters the mutual relation of two or more things")}, be
      $|this relation of what kind it may. This is the most general definition, and
      $|would include all subjects in the universe. In abstract mathematics, of course
      $|operations alter those particular relations which are involved in the
      $|considerations of number and space, and the \{i("results")} of operations are
      $|those peculiar results which correspond to the nature of the subjects of
      $|operation. But the science of operations, as derived from mathematics more
      $|especially, is a science of itself, and has its own abstract truth and value;
      $|just as logic has its own peculiar truth and value, independently of the
      $|subjects to which we may apply its reasonings and processes. Those who are
      $|accustomed to some of the more modern views of the above subject, will know
      $|that a few fundamental relations being true, certain other combinations of
      $|relations must of necessity follow; combinations unlimited in variety and
      $|extent if the deductions from the primary relations be carried on far enough.
      $|They will also be aware that one main reason why the separate nature of the
      $|science of operations has been little felt, and in general little dwelt on, is
      $|the \{i("shifting")} meaning of many of the symbols used in mathematical
      $|notation. First, the symbols of \{i("operation")} are frequently \{i("also")}
      $|the symbols of the \{i("results")} of operations. We may say that these symbols
      $|are apt to have both a \{i("retrospective")} and a \{i("prospective")}
      $|signification. They may signify either relations that are the consequence of a
      $|series of processes already performed, or relations that are yet to be effected
      $|through certain processes. Secondly, figures, the symbols of
      $|\{i("numerical magnitude")}, are frequently \{i("also")} the symbols of
      $|\{i("operations")}, as when they are the indices of powers. Wherever terms have
      $|a shifting meaning, independent sets of considerations are liable to become
      $|complicated together, and reasonings and results are frequently falsified. Now
      $|in the Analytical Engine the operations which come under the first of the above
      $|heads, are ordered and combined by means of a notation and of a train of
      $|mechanism which belong exclusively to themselves; and with respect to the
      $|second head, whenever numbers meaning \{i("operations")} and not
      $|\{i("quantities")} (such as the indices of powers), are inscribed on any column
      $|or set of columns, those columns immediately act in a wholly separate and
      $|independent manner, becoming connected with the \{i("operating mechanism")}
      $|exclusively, and re-acting upon this. They never come into combination with
      $|numbers upon any other columns meaning \{i("quantities")}; though, of course,
      $|if there are numbers meaning operations upon \{m("n")} columns, these may
      $|\{i("combine amongst each other")}, and will often be required to do so, just
      $|as numbers meaning \{i("quantities")} combine with each other in any variety.
      $|It might have been arranged that all numbers meaning \{i("operations")} should
      $|have appeared on some separate portion of the engine from that which presents
      $|numerical \{i("quantities")}; but the present mode is in some cases more
      $|simple, and offers in reality quite as much distinctness when understood.
    )
    |> par,
    (
      $|The operating mechanism can even be thrown into action independently of any
      $|object to operate upon (although of course no \{i("result")} could then be
      $|developed). Again, it might act upon other things besides \{i("number")}, were
      $|objects found whose mutual fundamental relations could be expressed by those of
      $|the abstract science of operations, and which should be also susceptible of
      $|adaptations to the action of the operating notation and mechanism of the
      $|engine. Supposing, for instance, that the fundamental relations of pitched
      $|sounds in the science of harmony and of musical composition were susceptible of
      $|such expression and adaptations, the engine might compose elaborate and
      $|scientific pieces of music of any degree of complexity or extent.
    )
    |> par,
    (
      $|The Analytical Engine is an \{i("embodying of the science of operations")},
      $|constructed with peculiar reference to abstract number as the subject of those
      $|operations. The Difference Engine is the embodying of
      $|\{i("one particular and very limited set of operations")}, which (see the
      $|notation used in note B) may be expressed thus,
      $|\{m("(+, thick +, thick +, thick +, thick +, thick +)")}, or thus,
      $|\{m("6(+)")}. Six repetitions of the one operation, \{m("+")}, is, in fact,
      $|the whole sum and object of that engine. It has seven columns, and a number on
      $|any column can add itself to a number on the next column to its
      $|\{i("right-hand")}. So that, beginning with the column furthest to the left,
      $|six additions can be effected, and the result appears on the seventh column,
      $|which is the last on the right-hand. The \{i("operating")} mechanism of this
      $|engine acts in as separate and independent a manner as that of the Analytical
      $|Engine; but being susceptible of only one unvarying and restricted combination,
      $|it has little force or interest in illustration of the distinct nature of the
      $|\{i("science of operations")}. The importance of regarding the Analytical
      $|Engine under this point of view will, we think, become more and more obvious,
      $|as the reader proceeds with M. Menabrea's clear and masterly article. The
      $|calculus of operations is likewise in itself a topic of so much interest, and
      $|has of late years been so much more written on and thought on than formerly,
      $|that any bearing which that engine, from its mode of constitution, may possess
      $|upon the illustration of this branch of mathematical science, should not be
      $|overlooked. Whether the inventor of this engine had any such views in his mind
      $|while working out the invention, or whether he may subsequently ever have
      $|regarded it under this phase, we do not know; but it is one that forcibly
      $|occurred to ourselves on becoming acquainted with the means through which
      $|analytical combinations are actually attained by the mechanism. We cannot
      $|forbear suggesting one practical result which it appears to us must be greatly
      $|facilitated by the independent manner in which the engine orders and combines
      $|its \{i("operations")}: we allude to the attainment of those combinations into
      $|which \{i("imaginary quantities")} enter. This is a branch of its processes
      $|into which we have not had the opportunity of inquiring, and our conjecture
      $|therefore as to the principle on which we conceive the accomplishment of such
      $|results may have been made to depend, is very probably not in accordance with
      $|the fact, and less subservient for the purpose than some other principles, or
      $|at least requiring the cooperation of others. It seems to us obvious, however,
      $|that where operations are so independent in their mode of acting, it must be
      $|easy by means of a few simple provisions and additions in arranging the
      $|mechanism, to bring out a \{i("double")} set of \{i("results")}, viz.—1st, the
      $|\{i("numerical magnitudes")} which are the results of operations performed on
      $|\{i("numerical data")}. (These results are the \{i("primary")} object of the
      $|engine). 2ndly, the \{i("symbolical results")} to be attached to those
      $|numerical results, which symbolical results are not less the necessary and
      $|logical consequences of operations performed upon \{i("symbolical data")}, than
      $|are numerical results when the data are numerical\{signs}.
    )
    |> par,
    (
      $|If we compare together the powers and the principles of construction of the
      $|Difference and of the Analytical Engines, we shall perceive that the
      $|capabilities of the latter are immeasurably more extensive than those of the
      $|former, and that they in fact hold to each other the same relationship as that
      $|of analysis to arithmetic. The Difference Engine can effect but one particular
      $|series of operations, viz. that required for tabulating the integral of the
      $|special function \{delta_n_semi} and as it can only do this for values of
      $|\{m("n")} up to 7\{seven}, it cannot be considered as being the most
      $|\{i("general")} expression even of \{i("one particular")} function, much less
      $|as being the expression of any and all possible functions of all degrees of
      $|generality. The Difference Engine can in reality (as has been already partly
      $|explained) do nothing but \{i("add")}; and any other processes, not excepting
      $|those of simple subtraction, multiplication and division, can be performed by
      $|it only just to that extent in which it is possible, by judicious mathematical
      $|arrangement and artifices, to reduce them to a \{i("series of additions")}. The
      $|method of differences is, in fact, a method of additions; and as it includes
      $|within its means a larger number of results attainable by \{i("addition")}
      $|simply, than any other mathematical principle, it was very appropriately
      $|selected as the basis on which to construct \{i("an Adding Machine")}, so as to
      $|give to the powers of such a machine the widest possible range. The Analytical
      $|Engine, on the contrary, can either add, subtract, multiply or divide with
      $|equal facility; and performs each of these four operations in a direct manner,
      $|without the aid of any of the other three. This one fact implies everything;
      $|and it is scarcely necessary to point out, for instance, that while the
      $|Difference Engine can merely \{i("tabulate")}, and is incapable of
      $|\{i("developing")}, tho Analytical Engine can
      $|\{i("either tabulate or develope")}.
    )
    |> par,
    (
      $|The former engine is in its nature strictly \{i("arithmetical")}, and the
      $|results it can arrive at lie within a very clearly defined and restricted
      $|range, while there is no finite line of demarcation which limits the powers of
      $|the Analytical Engine. These powers are co-extensive with our knowledge of the
      $|laws of analysis itself, and need be bounded only by our acquaintance with the
      $|latter. Indeed we may consider the engine as the
      $|\{i("material and mechanical representative")} of analysis, and that our actual
      $|working powers in this department of human study will be enabled more
      $|effectually than heretofore to keep pace with our theoretical knowledge of its
      $|principles and laws, through the complete control which the engine gives us
      $|over the \{i("executive manipulation")} of algebraical and numerical symbols.
    )
    |> par,
    (
      $|Those who view mathematical science not merely as a vast body of abstract and
      $|immutable truths, whose intrinsic beauty, symmetry and logical completeness,
      $|when regarded in their connexion together as a whole, entitle them to a
      $|prominent place in the interest of all profound and logical minds, but as
      $|possessing a yet deeper interest for the human race, when it is remembered that
      $|this science constitutes the language through which alone we can adequately
      $|express the great facts of the natural world, and those unceasing changes of
      $|mutual relationship which, visibly or invisibly, consciously or unconsciously
      $|to our immediate physical perceptions, are interminably going on in the
      $|agencies of the creation we live amidst: those who thus think on mathematical
      $|truth as the instrument through which the weak mind of man can most effectually
      $|read his Creator's works, will regard with especial interest all that can tend
      $|to facilitate the translation of its principles into explicit practical forms.
    )
    |> par,
    (
      $|The distinctive characteristic of the Analytical Engine, and that which has
      $|rendered it possible to endow mechanism with such extensive faculties as bid
      $|fair to make this engine the executive right-hand of abstract algebra, is the
      $|introduction into it of the principle which Jacquard devised for regulating, by
      $|means of punched cards, the most complicated patterns in the fabrication of
      $|brocaded stuffs. It is in this that the distinction between the two engines
      $|lies. Nothing of the sort exists in the Difference Engine. We may say most
      $|aptly that the Analytical Engine \{i("weaves algebraical patterns")} just as
      $|the Jacquard-loom weaves flowers and leaves. Here, it seems to us, resides much
      $|more of originality than the Difference Engine can be fairly entitled to claim.
      $|We do not wish to deny to this latter all such claims. We believe that it is
      $|the only proposal or attempt ever made to construct a calculating machine
      $|\{i("founded on the principle of successive orders of differences")}, and
      $|capable of \{i("printing off its own results")}; and that this engine surpasses
      $|its predecessors, both in the extent of the calculations which it can perform,
      $|in the facility, certainty and accuracy with which it can effect them, and in
      $|the absence of all necessity for the intervention of human intelligence
      $|\{i("during the performance of its calculations")}. Its nature is, however,
      $|limited to the strictly arithmetical, and it is far from being the first or
      $|only scheme for constructing \{i("arithmetical")} calculating machines with
      $|more or less of success.
    )
    |> par,
    (
      $|The bounds of \{i("arithmetic")} were however outstepped the moment the idea of
      $|applying the cards had occurred; and the Analytical Engine does not occupy
      $|common ground with mere "calculating machines." It holds a position wholly its
      $|own; and the considerations it suggests are most interesting in their nature.
      $|In enabling mechanism to combine together \{i("general")} symbols, in
      $|successions of unlimited variety and extent, a uniting link is established
      $|between the operations of matter and the abstract mental processes of the
      $|\{i("most abstract")} branch of mathematical science. A new, a vast, and a
      $|powerful language is developed for the future use of analysis, in which to
      $|wield its truths so that these may become of more speedy and accurate practical
      $|application for the purposes of mankind than the means hitherto in our
      $|possession have rendered possible. Thus not only the mental and the material,
      $|but the theoretical and the practical in the mathematical world, are brought
      $|into more intimate and effective connexion with each other. We are not aware of
      $|its being on record that anything partaking in the nature of what is so well
      $|designated the \{i("Analytical")} Engine has been hitherto proposed, or even
      $|thought of, as a practical possibility, any more than the idea of a thinking or
      $|of a reasoning machine.
    )
    |> par,
    (
      $|We will touch on another point which constitutes an important distinction in
      $|the modes of operating of the Difference and Analytical Engines. In order to
      $|enable the former to do its business, it is necessary to put into its columns
      $|the series of numbers constituting the first terms of the several orders of
      $|differences for whatever is the particular table under consideration. The
      $|machine then works \{i("upon")} these as its data. But these data must
      $|themselves have been already computed through a series of calculations by a
      $|human head. Therefore that engine can only produce results depending on data
      $|which have been arrived at by the explicit and actual working out of processes
      $|that are in their nature different from any that come within the sphere of its
      $|own powers. In other words, an \{i("analysing")} process must have been gone
      $|through by a human mind in order to obtain the data upon which the engine then
      $|\{i("synthetically")} builds its results. The Difference Engine is in its
      $|character exclusively \{i("synthetical")}, while the Analytical Engine is
      $|equally capable of analysis or of synthesis.
    )
    |> par,
    (
      $|It is true that the Difference Engine can calculate to a much greater extent
      $|with these few preliminary data, than the data themselves required for their
      $|own determination. The table of squares, for instance, can be calculated to any
      $|extent whatever, when the numbers \{i("one")} and \{i("two")} are furnished;
      $|and a very few differences computed at any part of a table of logarithms would
      $|enable the engine to calculate many hundreds or even thousands of logarithms.
      $|Still the circumstance of its requiring, as a previous condition, that any
      $|function whatever shall have been numerically worked out, makes it very
      $|inferior in its nature and advantages to an engine which, like the Analytical
      $|Engine, requires merely that we should know the
      $|\{i("succession and distribution of the operations")} to be performed; without
      $|there being any occasion\{occasion}, in order to obtain data on which it can
      $|work, for our ever having gone through either the same particular operations
      $|which it is itself to effect, or any others. Numerical data must of course be
      $|given it, but they are mere arbitrary ones; not data that could only be arrived
      $|at through a systematic and necessary series of previous numerical
      $|calculations, which is quite a different thing.
    )
    |> par,
    (
      $|To this it may be replied that an analysing process must equally have been
      $|performed in order to furnish the Analytical Engine with the necessary
      $|\{i("operative")} data; and that herein may also lie a possible source of
      $|error. Granted that the actual mechanism is unerring in its processes, the
      $|\{i("cards")} may give it wrong orders. This is unquestionably the case; but
      $|there is much less chance of error, and likewise far less expenditure of time
      $|and labour, where operations only, and the distribution of these operations,
      $|have to be made out, than where explicit numerical results are to be attained.
      $|In the case of the Analytical Engine we have undoubtedly to lay out a certain
      $|capital of analytical labour in one particular line; but this is in order that
      $|the engine may bring us in a much larger return in another line. It should be
      $|remembered also that the cards when once made out for any formula, have all the
      $|generality of algebra, and include an infinite number of particular cases.
    )
    |> par,
    (
      $|We have dwelt considerably on the distinctive peculiarities of each of these
      $|engines, because we think it essential to place their respective attributes in
      $|strong relief before the apprehension of the public; and to define with
      $|clearness and accuracy the wholly different nature of the principles on which
      $|each is based, so as to make it self-evident to the reader (the mathematical
      $|reader at least) in what manner and degree the powers of the Analytical Engine
      $|transcend those of an engine, which, like the Difference Engine, can only work
      $|out such results as may be derived from
      $|\{i("one restricted and particular series of processes")}, such as those
      $|included in \{m("Delta^n u_x = 0")}. We think this of importance, because we
      $|know that there exists considerable vagueness and inaccuracy in the mind of
      $|persons in general on the subject. There is a misty notion amongst most of
      $|those who have attended at all to it, that \{i("two")} "calculating machines"
      $|have been successively invented by the same person within the last few years;
      $|while others again have never heard but of the one original "calculating
      $|machine," and are not aware of there being any extension upon this. For either
      $|of these two classes of persons the above considerations are appropriate. While
      $|the latter require a knowledge of the fact that there \{i("are two")} such
      $|inventions, the former are not less in want of accurate and well-defined
      $|information on the subject. No very clear or correct ideas prevail as to the
      $|characteristics of each engine, or their respective advantages or
      $|disadvantages; and, in meeting with those incidental allusions, of a more or
      $|less direct kind, which occur in so many publications of the day, to these
      $|machines, it must frequently be matter of doubt \{i("which")} "calculating
      $|machine" is referred to, or whether \{i("both")} are included in the general
      $|allusion.
    )
    |> par,
    (
      $|We are desirous likewise of removing two misapprehensions which we know obtain,
      $|to some extent, respecting these engines. In the first place it is very
      $|generally supposed that the Difference Engine, after it had been completed up
      $|to a certain point, \{i("suggested")} the idea of the Analytical Engine; and
      $|that the second is in fact the improved offspring of the first, and
      $|\{i("grew out")} of the existence of its predecessor, through some natural or
      $|else accidental combination of ideas suggested by this one. Such a supposition
      $|is in this instance contrary to the facts; although it seems to be almost an
      $|obvious inference, wherever two inventions, similar in their nature and
      $|objects, succeed each other closely in order of \{i("time")}, and strikingly in
      $|order of \{i("value")}; more especially when the same individual is the author
      $|of both. Nevertheless the ideas which led to the Analytical Engine occurred in
      $|a manner wholly independent of any that were connected with the Difference
      $|Engine. These ideas are indeed in their own intrinsic nature independent of the
      $|latter engine, and might equally have occurred had it never existed nor been
      $|even thought of at all.
    )
    |> par,
    (
      $|The second of the misapprehensions above alluded to, relates to the well-known
      $|suspension, during some years past, of all progress in the construction of the
      $|Difference Engine. Respecting the circumstances which have interfered with the
      $|actual completion of either invention, we offer no opinion; and in fact are not
      $|possessed of the data for doing so, had we the inclination. But we know that
      $|some persons suppose these obstacles (be they what they may) to have arisen
      $|\{i("in consequence")} of the subsequent invention of the Analytical Engine
      $|while the former was in progress. We have ourselves heard it even
      $|\{i("lamented")} that an idea should ever have occurred at all, which had
      $|turned out to be merely the means of arresting what was already in a course of
      $|successful execution, without substituting the superior invention in its stead.
      $|This notion we can contradict in the most unqualified manner. The progress of
      $|the Difference Engine had long been suspended, before there were even the least
      $|crude glimmerings of any invention superior to it. Such glimmerings, therefore,
      $|and their subsequent development, were in no way the original cause of that
      $|suspension; although, where difficulties of some kind or other evidently
      $|already existed, it was not perhaps calculated to remove or lessen them that an
      $|invention should have been meanwhile thought of, which, while including all
      $|that the first was capable of, possesses powers so extended as to eclipse it
      $|altogether.
    )
    |> par,
    (
      $|We leave it for the decision of each individual
      $|(\{i("after he has possessed himself")} of competent information as to the
      $|characteristics of each engine), to determine how far it ought to be matter of
      $|regret that such an accession has been made to the powers of human science,
      $|even if it \{i("has")} (which we greatly doubt) increased to a certain limited
      $|extent some already existing difficulties that had arisen in the way of
      $|completing a valuable but lesser work. We leave it for each to satisfy himself
      $|as to the wisdom of desiring the obliteration (were that now possible) of all
      $|records of the more perfect invention, in order that the comparatively limited
      $|one might be finished. The Difference Engine would doubtless fulfil all those
      $|practical objects which it was originally destined for. It would certainly
      $|calculate all the tables that are more directly necessary for the physical
      $|purposes of life, such as nautical and other computations. Those who incline to
      $|very strictly utilitarian views, may perhaps feel that the peculiar powers of
      $|the Analytical Engine bear upon questions of abstract and speculative science,
      $|rather than upon those involving every-day and ordinary human interests. These
      $|persons being likely to possess but little sympathy, or possibly acquaintance,
      $|with any branches of science which they do not find to be \{i("useful")}
      $|(according to \{i("their")} definition of that word), may conceive that the
      $|undertaking of that engine, now that the other one is already in progress,
      $|would be a barren and unproductive laying out of yet more money and labour; in
      $|fact, a work of supererogation. Even in the utilitarian aspect, however, we do
      $|not doubt that very valuable practical results would be developed by the
      $|extended faculties of the Analytical Engine; some of which results we think we
      $|could now hint at, had we the space; and others, which it may not yet be
      $|possible to foresee, but which would be brought forth by the daily increasing
      $|requirements of science, and by a more intimate practical acquaintance with the
      $|powers of the engine, were it in actual existence.
    )
    |> par,
    (
      $|On general grounds, both of an \{i("à priori")} description as well as those
      $|founded on the scientific history and experience of mankind, we see strong
      $|presumptions that such would be the case. Nevertheless all will probably concur
      $|in feeling that the completion of the Difference Engine would be far preferable
      $|to the non-completion of any calculating engine at all. With whomsoever or
      $|wheresoever may rest the present causes of difficulty that apparently exist
      $|towards either the completion of the old engine, or the commencement of the new
      $|one, we trust they will not ultimately result in this generation's being
      $|acquainted with these inventions through the medium of pen, ink and paper
      $|merely; and still more do we hope, that for the honour of our country's
      $|reputation in the future pages of history, these causes will not lead to the
      $|completion of the undertaking by some \{i("other")} nation or government. This
      $|could not but be matter of just regret; and equally so, whether the obstacles
      $|may have originated in private interests and feelings, in considerations of a
      $|more public description, or in causes combining the nature of both such
      $|solutions.
    )
    |> par,
    (
      $|We refer the reader to the 'Edinburgh Review' of July 1834\{edinburgh}, for a
      $|very able account of the Difference Engine. The writer of the article we allude
      $|to, has selected as his prominent matter for exposition, a wholly different
      $|view of the subject from that which M. Menabrea has chosen. The former chiefly
      $|treats it under its mechanical aspect, entering but slightly into the
      $|mathematical principles of which that engine is the representative, but giving,
      $|in considerable length, many details of the mechanism and contrivances by means
      $|of which it tabulates the various orders of differences. M. Menabrea, on the
      $|contrary, exclusively developes the analytical view; taking it for granted that
      $|mechanism is able to perform certain processes, but without attempting to
      $|explain \{i("how")}; and devoting his whole attention to explanations and
      $|illustrations of the manner in which analytical laws can be so arranged and
      $|combined as to bring every branch of that vast subject within the grasp of the
      $|assumed powers of mechanism. It is obvious that, in the invention of a
      $|calculating engine, these two branches of the subject are equally essential
      $|fields of investigation, and that on their mutual adjustment, one to the other,
      $|must depend all success. They must be made to meet each other, so that the weak
      $|points in the powers of either department may be compensated by the strong
      $|points in those of the other. They are indissolubly connected, though so
      $|different in their intrinsic nature that perhaps the same mind might not be
      $|likely to prove equally profound or successful in both. We know those who doubt
      $|whether the powers of mechanism will in practice prove adequate in all respects
      $|to the demands made upon them in the working of such complicated trains of
      $|machinery as those of the above engines, and who apprehend that unforeseen
      $|practical difficulties and disturbances will arise in the way of accuracy and
      $|of facility of operation. The Difference Engine, however, appears to us to be
      $|in a great measure an answer to these doubts. It is complete as far as it goes,
      $|and it does work with all the anticipated success. The Analytical Engine, far
      $|from being more complicated, will in many respects be of simpler construction;
      $|and it is a remarkable circumstance attending it, that with very
      $|\{i("simplified")} means it is so much more powerful.
    )
    |> par,
    (
      $|The article in the 'Edinburgh Review' was written some time previous to the
      $|occurrence of any ideas such as afterwards led to the invention of the
      $|Analytical Engine; and in the nature of the Difference Engine there is much
      $|less that would invite a writer to take exclusively, or even prominently, the
      $|mathematical view of it, than in that of the Analytical Engine; although
      $|mechanism has undoubtedly gone much further to meet mathematics, in the case of
      $|this engine, than of the former one. Some publication embracing the
      $|\{i("mechanical")} view of the Analytical Engine is a desideratum which we
      $|trust will be supplied before long.
    )
    |> par,
    (
      $|Those who may have the patience to study a moderate quantity of rather dry
      $|details, will find ample compensation, after perusing the article of 1834, in
      $|the clearness with which a succinct view will have been attained of the various
      $|practical steps through which mechanism can accomplish certain processes; and
      $|they will also find themselves still further capable of appreciating M.
      $|Menabrea's more comprehensive and generalized memoir. The very difference in
      $|the style and object of these two articles, makes them peculiarly valuable to
      $|each other; at least for the purposes of those who really desire something more
      $|than a merely superficial and popular comprehension of the subject of
      $|calculating engines.
    )
    |> par,
    signature("A. A. L."),
  ]
}
