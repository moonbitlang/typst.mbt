///|
test "minimal independent style" {
  let xml =
    #|<?xml version="1.0" encoding="utf-8"?>
    #|<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
    #|  <info>
    #|    <title>Test</title>
    #|    <id>test</id>
    #|  </info>
    #|  <citation collapse="citation-number">
    #|    <layout>
    #|      <text variable="citation-number"/>
    #|    </layout>
    #|  </citation>
    #|  <bibliography>
    #|    <layout>
    #|      <text variable="title" font-style="italic" />
    #|      <text variable="citation-number" display="left-margin" prefix="|" suffix="|" />
    #|      <group display="indent">
    #|        <text term="by" suffix=" " />
    #|        <!-- This left-margin attribute is ignored because it is in a container. -->
    #|        <names variable="author" display="left-margin" />
    #|      </group>
    #|      <group display="block" prefix="(" suffix=")">
    #|        <text term="edition" suffix=" " text-case="capitalize-first" />
    #|        <date variable="issued"><date-part name="year"/></date>
    #|      </group>
    #|    </layout>
    #|  </bibliography>
    #|</style>
  let res = match @citationberg.IndependentStyle::from_xml(xml) {
    Ok(_) => "ok"
    Err(e) => e.to_string()
  }
  inspect(res, content="ok")
}
