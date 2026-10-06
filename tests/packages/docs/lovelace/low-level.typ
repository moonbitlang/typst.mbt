// lovelace 0.3.1: the low-level `pseudocode` function with indent,
// no-number and with-line-label, preset configurations via `.with`, a long
// listing that breaks across pages (repeated title header), a list of
// algorithms and line references across pages.
// Stresses grid header/footer repetition, rowspan cells split at page
// breaks, references to figures inside boxes in grid cells.
#import "@preview/lovelace:0.3.1": *

#set page(width: 12cm, height: 15cm, margin: 1.3cm, header: align(right, text(size: 8pt)[Kitchen procedures]))
#set text(size: 9.5pt)
#set heading(numbering: "1")

#let recipe = pseudocode.with(
  booktabs: true,
  booktabs-stroke: 1.5pt + olive.darken(30%),
  stroke: (paint: olive, thickness: 0.8pt, dash: "dotted"),
  indentation: 1.5em,
  line-number-supplement: "step",
)

#outline(title: [Procedures], target: figure.where(kind: "algorithm"))

= Stock

#figure(
  kind: "algorithm",
  supplement: [Procedure],
  caption: [Brown stock.],
  recipe(
    numbered-title: [],
    no-number[*needs:* bones, onions, carrots, time],
    [roast the bones until dark],
    with-line-label(<step:deglaze>)[deglaze the tray with water],
    [*for each* vegetable],
    indent(
      [cut it roughly],
      [brown it in the pot],
    ),
    [cover with cold water],
    [*while* less than six hours have passed],
    indent(
      [keep at a bare simmer],
      [*if* scum rises],
      indent(
        with-line-label(<step:skim>)[skim it off],
      ),
      no-number[_(do not stir)_],
    ),
    [strain],
  ),
) <proc:stock>

The flavour comes from @step:deglaze of @proc:stock, the clarity from
@step:skim.

= Service

The evening service is one long listing. It does not fit on a page, so its
title is repeated at the top of the continuation.

#let course(name, ..steps) = (
  [*course* #name],
  indent(..steps),
)

#recipe(
  title: [*Service*, from the first ticket to the last],
  line-numbering: "1.",
  ..course[soup][warm the bowls][ladle][garnish with chives][wipe the rim],
  ..course[fish][
    pat the fillets dry
  ][
    *if* the pan is not smoking
  ][
    wait
  ][
    skin side down, three minutes
  ][
    turn, baste, one minute
  ],
  with-line-label(<step:pass>)[call the pass],
  ..course[roast][carve against the grain][sauce the plate first][arrange][check the temperature],
  [*repeat*],
  indent(
    [read the next ticket],
    [*for each* course on it],
    indent(
      [fire the course],
      [*if* the table is not ready],
      indent(
        [hold under the lamp],
        [tell the floor],
      ),
      [send],
    ),
    [spike the ticket],
  ),
  [*until* the rail is empty],
  ..course[cheese][take it out of the fridge an hour early][cut to order],
  ..course[dessert][unmould][sauce][dust with sugar][send at once],
  with-line-label(<step:close>)[scrub down],
  no-number[*end of service*],
)

Everything waits for @step:pass; nobody leaves before @step:close.

= Unframed

#pseudocode(
  line-numbering: none,
  stroke: none,
  hooks: 0pt,
  [taste],
  indent([season], indent([taste again])),
)
