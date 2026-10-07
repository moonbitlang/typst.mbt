// Sections 6 and 7: Table I (values of G_n and g_n) and Table II
// (approximate formulae). Both tables are set across the two columns.

///|
/// A delimiter of a group that is continued on the next line of a display,
/// where Typst cannot size it from its contents.
fn big(delimiter : String, percent : Int) -> String {
  "stretch(\{delimiter}, size: #\{percent}%)"
}

///|
fn section_6() -> Array[Item] {
  let open = big("bracket.l", 320)
  let close = big("bracket.r", 320)
  [
    wide(
      sec(
        (
          $|I have calculated the values of \{m("G_n")} and \{m("g_n")} for a
          $|large number of values of \{m("n")}. Many of these results are
          $|equivalent to results given by Weber; for example,
        ),
      ),
    ),
    wide(
      ueq(
        rows([
          "G_(13)^4 &= (3 + sqrt(13))/2, quad G_(25) = (1 + sqrt(5))/2,", "g_(30)^6 &= (2 + sqrt(5)) (3 + sqrt(10)), quad G_(37)^4 = 6 + sqrt(37),",
          "G_(49) &= (7^(1/4) + sqrt((4 + sqrt(7))))/2, quad g_(58)^2 = (5 + sqrt(29))/2,",
          "g_(70)^2 &= ((3 + sqrt(5)) (1 + sqrt(2)))/2,", "G_(73) &= sqrt(((9 + sqrt(73))/8)) + sqrt(((1 + sqrt(73))/8)),",
          "G_(85) &= ((1 + sqrt(5))/2) ((9 + sqrt(85))/2)^(1/4),", "G_(97) &= sqrt(((13 + sqrt(97))/8)) + sqrt(((5 + sqrt(97))/8)),",
          "g_(190)^2 &= (2 + sqrt(5)) (3 + sqrt(10)),", "G_(385)^2 &= 1/8 (3 + sqrt(11)) (sqrt(5) + sqrt(7)) (sqrt(7) + sqrt(11)) (3 + sqrt(5)),",
        ]),
      ),
    ),
    wide(
      p(
        (
          $|and so on. I have also many results not given by Weber. I give a
          $|complete table of new results. In Weber's notation,
          $|\{m("G_n = 2^(-1/4) f{sqrt((-n))}")} and
          $|\{m("g_n = 2^(-1/4) f_1{sqrt((-n))}")}.
        ),
      ),
    ),
    table_title("table1"),
    table_rows(
      rows([
        "g_(62) + 1/g_(62) &= 1/2 {sqrt((1 + sqrt(2))) + sqrt((9 + 5 sqrt(2)))},",
        "G_(65)^2 &= sqrt({((1 + sqrt(5))/2) ((3 + sqrt(13))/2)}) {sqrt(((1 + sqrt(65))/8)) + sqrt(((9 + sqrt(65))/8))},",
        "g_(66)^2 &= sqrt((sqrt(2) + sqrt(3))) (7 sqrt(2) + 3 sqrt(11))^(1/6) {sqrt(((7 + sqrt(33))/8)) + sqrt(((sqrt(33) - 1)/8))},",
        "G_(69)^2 &= (3 sqrt(3) + sqrt(23))^(1/4) ((5 + sqrt(23))/4)^(1/6) {sqrt(((6 + 3 sqrt(3))/4)) + sqrt(((2 + 3 sqrt(3))/4))},",
        "G_(77)^2 &= {1/2 (sqrt(7) + sqrt(11)) (8 + 3 sqrt(7))}^(1/4) {sqrt(((6 + sqrt(11))/4)) + sqrt(((2 + sqrt(11))/4))},",
        "G_(81)^3 &= ((2 sqrt(3) + 2)^(1/3) + 1)/((2 sqrt(3) - 2)^(1/3) - 1),", "g_(90) &= {(2 + sqrt(5)) (sqrt(5) + sqrt(6))}^(1/6) {sqrt(((3 + sqrt(6))/4)) + sqrt(((sqrt(6) - 1)/4))},",
        "g_(94) + 1/g_(94) &= 1/2 {sqrt((7 + sqrt(2))) + sqrt((7 + 5 sqrt(2)))},",
        "g_(98) + 1/g_(98) &= 1/2 {sqrt(2) + sqrt((14 + 4 sqrt(14)))},", "g_(114)^2 &= sqrt((sqrt(2) + sqrt(3))) (3 sqrt(2) + sqrt(19))^(1/6) {sqrt(((23 + 3 sqrt(57))/8)) + sqrt(((15 + 3 sqrt(57))/8))},",
        "G_(117) &= 1/2 ((3 + sqrt(13))/2)^(1/4) (2 sqrt(3) + sqrt(13))^(1/6) {3^(1/4) + sqrt((4 + sqrt(3)))},",
      ]),
    ),
    wide(
      ueq(
        braced([
          "G_(121) + 1/G_(121) &= (11/2)^(1/6) {(3 + 1/(3 sqrt(3)))^(1/3) + (3 - 1/(3 sqrt(3)))^(1/3)}",
          "1/G_(121) &= 1/(3 sqrt(2)) [(11 - 3 sqrt(11))^(1/3) {(3 sqrt(11) + 3 sqrt(3) - 4)^(1/3) + (3 sqrt(11) - 3 sqrt(3) - 4)^(1/3)} - 2]",
        ]) +
        ",",
      ),
    ),
    table_rows(
      rows([
        "g_(126) &= sqrt(((sqrt(3) + sqrt(7))/2)) (sqrt(6) + sqrt(7))^(1/6) {sqrt(((3 + sqrt(2))/4)) + sqrt(((sqrt(2) - 1)/4))}^2,",
        "g_(138)^2 &= sqrt(((3 sqrt(3) + sqrt(23))/2)) (78 sqrt(2) + 23 sqrt(23))^(1/6) times {sqrt(((5 + 2 sqrt(6))/4)) + sqrt(((1 + 2 sqrt(6))/4))},",
        "G_(141)^2 &= (4 sqrt(3) + sqrt(47))^(1/4) ((7 + sqrt(47))/sqrt(2))^(1/6) {sqrt(((18 + 9 sqrt(3))/4)) + sqrt(((14 + 9 sqrt(3))/4))},",
        "G_(145)^2 &= sqrt({((2 + sqrt(5)) (5 + sqrt(29)))/2}) {sqrt(((17 + sqrt(145))/8)) + sqrt(((9 + sqrt(145))/8))},",
        "1/G_(147) &= 2^(-1/12) [1/2 + 1/sqrt(3) {sqrt((7/4) - (28)^(1/6))}],", "G_(153) &= {sqrt(((5 + sqrt(17))/8)) + sqrt(((sqrt(17) - 3)/8))}^2",
        "& quad times {sqrt(((37 + 9 sqrt(17))/4)) + sqrt(((33 + 9 sqrt(17))/4))}^(1/3),",
        "g_(154)^2 &= sqrt({(2 sqrt(2) + sqrt(7)) ((sqrt(7) + sqrt(11))/2)})", "& quad times {sqrt(((13 + 2 sqrt(22))/4)) + sqrt(((9 + 2 sqrt(22))/4))},",
        "g_(158) + 1/g_(158) &= 1/2 {sqrt((9 + sqrt(2))) + sqrt((17 + 13 sqrt(2)))},",
      ]),
    ),
    wide(
      ueq(
        braced([
          "G_(169) + 1/G_(169) &= (13/4)^(1/6) {(1 + 1/(3 sqrt(3)))^(1/3) + (1 - 1/(3 sqrt(3)))^(1/3)}^2",
          "1/G_(169) &= 1/3 \{open}(sqrt(13) - 2) + ((13 - 3 sqrt(13))/2)^(1/3)",
          "& quad times {(3 sqrt(3) - (11 - sqrt(13))/2)^(1/3) - (3 sqrt(3) + (11 - sqrt(13))/2)^(1/3)}\{close}",
        ]) +
        ",",
      ),
    ),
    table_rows(
      rows([
        "g_(198) &= sqrt((1 + sqrt(2))) (4 sqrt(2) + sqrt(33))^(1/6) {sqrt(((9 + sqrt(33))/8)) + sqrt(((1 + sqrt(33))/8))},",
        "G_(205) &= ((1 + sqrt(5))/2) ((3 sqrt(5) + sqrt(41))/2)^(1/4) {sqrt(((7 + sqrt(41))/8)) + sqrt(((sqrt(41) - 1)/8))},",
        "G_(213)^2 &= (5 sqrt(3) + sqrt(71))^(1/4) ((59 + 7 sqrt(71))/4)^(1/6)",
        "& quad times {sqrt(((21 + 12 sqrt(3))/2)) + sqrt(((19 + 12 sqrt(3))/2))},",
        "G_(217)^2 &= {sqrt(((9 + 4 sqrt(7))/2)) + sqrt(((11 + 4 sqrt(7))/2))}",
        "& quad times {sqrt(((12 + 5 sqrt(7))/4)) + sqrt(((16 + 5 sqrt(7))/4))},",
        "G_(225) &= ((1 + sqrt(5))/4) (2 + sqrt(3))^(1/3) {sqrt((4 + sqrt(15))) + 15^(1/4)},",
        "g_(238) &= {sqrt(((1 + 2 sqrt(2))/4)) + sqrt(((5 + 2 sqrt(2))/4))}", "& quad times {sqrt(((1 + 3 sqrt(2))/4)) + sqrt(((5 + 3 sqrt(2))/4))},",
        "G_(265)^2 &= sqrt({(2 + sqrt(5)) ((7 + sqrt(53))/2)}) {sqrt(((89 + 5 sqrt(265))/8)) + sqrt(((81 + 5 sqrt(265))/8))},",
        "G_(289) &= [sqrt({(17 + sqrt(17) + 17^(1/4) (5 + sqrt(17)))/16}) + sqrt({(1 + sqrt(17) + 17^(1/4) (5 + sqrt(17)))/16})]^2,",
        "G_(301)^2 &= {(8 + 3 sqrt(7)) ((23 sqrt(43) + 57 sqrt(7))/2)}^(1/4)", "& quad times {sqrt(((46 + 7 sqrt(43))/4)) + sqrt(((42 + 7 sqrt(43))/4))},",
        "g_(310) &= ((1 + sqrt(5))/2) sqrt((1 + sqrt(2))) {sqrt(((7 + 2 sqrt(10))/4)) + sqrt(((3 + 2 sqrt(10))/4))},",
      ]),
    ),
    wide(
      ueq(
        braced([
          "G_(325) &= ((3 + sqrt(13))/2)^(1/4) t comma \"where\"", "& t^3 + t^2 ((1 - sqrt(13))/2)^2 + t ((1 + sqrt(13))/2)^2 + 1",
          "&= sqrt(5) {t^3 - t^2 ((1 + sqrt(13))/2) + t ((1 - sqrt(13))/2) - 1}",
        ]) +
        ",",
      ),
    ),
    wide(
      ueq(
        "G_(333) = 1/2 (6 + sqrt(37))^(1/4) (7 sqrt(3) + 2 sqrt(37))^(1/6) {sqrt((7 + 2 sqrt(3))) + sqrt((3 + 2 sqrt(3)))},",
      ),
    ),
    wide(
      ueq(
        braced([
          "G_(363) &= 2^(5/12) t comma \"where\"", "& 2 t^3 - t^2 {(4 + sqrt(33)) + sqrt((11 + 2 sqrt(33)))}",
          "& - med t {1 + sqrt((11 + 2 sqrt(33)))} - 1 = 0",
        ]) +
        ",",
      ),
    ),
    table_rows(
      rows([
        "G_(441)^2 &= ((sqrt(3) + sqrt(7))/2) (2 + sqrt(3))^(1/3) {(2 + sqrt(7) + sqrt((7 + 4 sqrt(7))))/2} {(sqrt((3 + sqrt(7))) + (6 sqrt(7))^(1/4))/(sqrt((3 + sqrt(7))) - (6 sqrt(7))^(1/4))},",
        "G_(445) &= sqrt((2 + sqrt(5))) ((21 + sqrt(445))/2)^(1/4) sqrt({((13 + sqrt(89))/8) + sqrt(((5 + sqrt(89))/8))}),",
        "G_(465)^2 &= sqrt({(2 + sqrt(3)) ((1 + sqrt(5))/2) ((3 sqrt(3) + sqrt(31))/2)}) (5 sqrt(5) + 2 sqrt(31))^(1/6)",
        "& quad times {sqrt(((2 + sqrt(31))/4)) + sqrt(((6 + sqrt(31))/4))}",
        "& quad times {sqrt(((11 + 2 sqrt(31))/2)) + sqrt(((13 + 2 sqrt(31))/2))},",
        "G_(505)^2 &= (2 + sqrt(5)) sqrt({((1 + sqrt(5))/2) (10 + sqrt(101))})",
        "& quad times {((5 sqrt(5) + sqrt(101))/4) + sqrt(((105 + sqrt(505))/8))},",
        "g_(522) &= sqrt(((5 + sqrt(29))/2)) (5 sqrt(29) + 11 sqrt(6))^(1/6) {sqrt(((9 + 3 sqrt(6))/4)) + sqrt(((5 + 3 sqrt(6))/4))},",
        "G_(553)^2 &= {sqrt(((96 + 11 sqrt(79))/4)) + sqrt(((100 + 11 sqrt(79))/4))}",
        "& quad times {sqrt(((141 + 16 sqrt(79))/2)) + sqrt(((143 + 16 sqrt(79))/2))},",
        "g_(630) &= (sqrt(14) + sqrt(15))^(1/6) sqrt({(1 + sqrt(2)) ((3 + sqrt(5))/2) ((sqrt(3) + sqrt(7))/2)})",
        "& quad times {sqrt(((sqrt(15) + sqrt(7) + 2)/4)) + sqrt(((sqrt(15) + sqrt(7) - 2)/4))}",
        "& quad times {sqrt(((sqrt(15) + sqrt(7) + 4)/8)) + sqrt(((sqrt(15) + sqrt(7) - 4)/8))},",
        "G_(765)^2 &= ((3 + sqrt(5))/2) (16 + sqrt(255))^(1/6) sqrt({(4 + sqrt(15)) ((9 + sqrt(85))/2)})",
        "& quad times {sqrt(((6 + sqrt(51))/4)) + sqrt(((10 + sqrt(51))/4))}",
        "& quad times {sqrt(((18 + 3 sqrt(51))/4)) + sqrt(((22 + 3 sqrt(51))/4))},",
        "G_(777)^2 &= sqrt({(2 + sqrt(3)) (6 + sqrt(37)) ((sqrt(3) + sqrt(7))/2)}) (246 sqrt(7) + 107 sqrt(37))^(1/6)",
        "& quad times {sqrt(((6 + 3 sqrt(7))/4)) + sqrt(((10 + 3 sqrt(7))/4))}",
        "& quad times {sqrt(((15 + 6 sqrt(7))/2)) + sqrt(((17 + 6 sqrt(7))/2))},",
        "G_(1225) &= ((1 + sqrt(5))/2) (6 + sqrt(35))^(1/4) {(7^(1/4) + sqrt((4 + sqrt(7))))/2}^(3/2)",
        "& quad times \{open}sqrt({(43 + 15 sqrt(7) + (8 + 3 sqrt(7)) sqrt((10 sqrt(7))))/8})",
        "& quad quad + sqrt({(35 + 15 sqrt(7) + (8 + 3 sqrt(7)) sqrt((10 sqrt(7))))/8})\{close},",
        "G_(1353)^2 &= sqrt({(3 + sqrt(11)) (5 + 3 sqrt(3)) ((11 + sqrt(123))/2)})",
        "& quad times ((6817 + 321 sqrt(451))/4)^(1/6)",
        "& quad times {sqrt(((17 + 3 sqrt(33))/8)) + sqrt(((25 + 3 sqrt(33))/8))}",
        "& quad times {sqrt(((561 + 99 sqrt(33))/8)) + sqrt(((569 + 99 sqrt(33))/8))},",
        "G_(1645)^2 &= (2 + sqrt(5)) sqrt({(3 + sqrt(7)) ((7 + sqrt(47))/2)}) ((73 sqrt(5) + 9 sqrt(329))/2)^(1/4)",
        "& quad times {sqrt(((119 + 7 sqrt(329))/8)) + sqrt(((127 + 7 sqrt(329))/8))}",
        "& quad times {sqrt(((743 + 41 sqrt(329))/8)) + sqrt(((751 + 41 sqrt(329))/8))}.",
      ]),
    ),
  ]
}

///|
fn section_7() -> Array[Item] {
  let open = big("bracket.l", 320)
  let close = big("bracket.r", 320)
  [
    wide(sec("Hence we deduce the following approximate formulæ")),
    table_title("table2"),
    table_rows(
      rows([
        "e^(1/8 pi sqrt(18)) &= 2 sqrt(7), quad e^(pi sqrt(22 slash 12)) = 2 + sqrt(2), quad e^(1/4 pi sqrt(30)) = 20 sqrt(3) + 16 sqrt(6),",
        "e^(1/4 pi sqrt(34)) &= 12 (4 + sqrt(17)), quad e^(1/2 pi sqrt(46)) = 144 (147 + 104 sqrt(2))",
        "e^(1/4 pi sqrt(42)) &= 84 + 32 sqrt(6), quad e^(pi sqrt(58 slash 12)) = (5 + sqrt(29))/sqrt(2),",
        "e^(1/4 pi sqrt(70)) &= 60 sqrt(35) + 96 sqrt(14), quad e^(1/4 pi sqrt(78)) = 300 sqrt(3) + 208 sqrt(6),",
        "e^(pi sqrt(55 slash 24)) &= (1 + sqrt((3 + 2 sqrt(5))))/sqrt(2), quad e^(1/4 pi sqrt(102)) = 800 sqrt(3) + 196 sqrt(51),",
        "e^(1/4 pi sqrt(130)) &= 12 (323 + 40 sqrt(65)), quad e^(pi sqrt(190 slash 12)) = (2 sqrt(2) + sqrt(10)) (3 + sqrt(10)),",
        "pi &= 12/sqrt(130) log{((2 + sqrt(5)) (3 + sqrt(13)))/sqrt(2)},",
        "pi &= 24/sqrt(142) log{sqrt(((10 + 11 sqrt(2))/4)) + sqrt(((10 + 7 sqrt(2))/4))},",
        "pi &= 12/sqrt(190) log{(2 sqrt(2) + sqrt(10)) (3 + sqrt(10))},",
        "pi &= 12/sqrt(310) log[1/4 (3 + sqrt(5)) (2 + sqrt(2)) {(5 + 2 sqrt(10)) + sqrt((61 + 20 sqrt(10)))}],",
        "pi &= 4/sqrt(522) log \{open}((5 + sqrt(29))/sqrt(2))^3 (5 sqrt(29) + 11 sqrt(6))",
        "& quad times {sqrt(((9 + 3 sqrt(6))/4)) + sqrt(((5 + 3 sqrt(6))/4))}^6\{close}.",
      ]),
    ),
    wide(
      p(
        (
          $|The last five formulæ are correct to 15, 16, 18, 22 and 31 places
          $|of decimals respectively.
        ),
      ),
    ),
  ]
}
