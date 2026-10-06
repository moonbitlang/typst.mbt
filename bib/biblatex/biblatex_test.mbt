///|
test "parse basic" {
  let src =
    #|@article{netwok,
    #|  title={At-scale impact of the {Net Wok}: A culinarically holistic investigation of distributed dumplings},
    #|  author={Astley, Rick and Morris, Linda},
    #|  journal={Armenian Journal of Proceedings},
    #|  volume={61},
    #|  pages={192--219},
    #|  year={2020},
    #|  publisher={Automattic Inc.}
    #|}
    #|@book{tolkien54,
    #|    maintitle = {The Lord of the Rings},
    #|    title = {The Fellowship of the Ring},
    #|    author = {J. R. R. Tolkien},
    #|    date = {1954-07-29},
    #|    publisher = {Allen & Unwin},
    #|    location = {London},
    #|    volume = {1},
    #|}
  let bib = @biblatex.Bibliography::parse(src).unwrap()
  let e = bib.get("netwok").unwrap()
  debug_inspect(
    e.title().unwrap().map(c => c.v),
    content=(
      #|[
      #|  Normal("At-scale impact of the "),
      #|  Verbatim("Net Wok"),
      #|  Normal(": A culinarically holistic investigation of distributed dumplings"),
      #|]
    ),
  )
  @debug.debug_inspect(
    e.author().unwrap().map(p => p.to_string()),
    content=(
      #|["Rick Astley", "Linda Morris"]
    ),
  )
  debug_inspect(e.pages().unwrap(), content="Typed([IntRange(192, 219)])")
  let t = bib.get("tolkien54").unwrap()
  inspect(t.author().unwrap()[0].name, content="Tolkien")
  inspect(t.author().unwrap()[0].given_name, content="J. R. R.")
  debug_inspect(
    t.date().unwrap(),
    content=(
      #|Typed(
      #|  {
      #|    value: At({ year: 1954, month: Some(6), day: Some(28), time: None }),
      #|    uncertain: false,
      #|    approximate: false,
      #|  },
      #|)
    ),
  )
  inspect(
    @biblatex.format_verbatim(t.publisher().unwrap()[0]),
    content="Allen & Unwin",
  )
}

///|
test "commands" {
  let src =
    #|@book{a, title = {\"{A}ther und {"\LaTeX "} {\relax for you\}}}, author={L\^{e} D\~{u}ng Tr\'{a}ng}, note = {- Knitting A--Z --- A practical guide -----}}
  let bib = @biblatex.Bibliography::parse(src).unwrap()
  let e = bib.get("a").unwrap()
  debug_inspect(
    e.title().unwrap().map(c => c.v),
    content=(
      #|[
      #|  Normal("Äther und "),
      #|  Verbatim("\"LaTeX\""),
      #|  Normal(" "),
      #|  Verbatim("\\relax for you}"),
      #|]
    ),
  )
  inspect(e.author().unwrap()[0].to_string(), content="Lê Dũng Tráng")
  inspect(
    @biblatex.format_verbatim(e.note().unwrap()),
    content="- Knitting A–Z — A practical guide —–",
  )
}

///|
test "errors" {
  inspect(
    @biblatex.Bibliography::parse("@article{a, title = {x}").unwrap_err(),
    content=(
      #|expected comma: 23-23
    ),
  )
  inspect(
    @biblatex.Bibliography::parse("@article{a, title {x}}").unwrap_err(),
    content="expected equals: 18-18",
  )
}
