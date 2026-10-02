///|
test "canonicalize_svg_ids" {
  let svg =
    #|<svg>
    #|  <use xlink:href="#g1A" x="0"/>
    #|  <g clip-path="url(#c3F)"/>
    #|  <use xlink:href="#gB2"/>
    #|  <use xlink:href="#g1A"/>
    #|  <a href="#gZ"/>
    #|  <defs>
    #|    <symbol id="gB2"/>
    #|    <symbol id="g1A"/>
    #|  </defs>
    #|  <defs>
    #|    <clipPath id="c3F"/>
    #|  </defs>
    #|</svg>
  inspect(
    canonicalize_svg_ids(svg),
    content=(
      #|<svg>
      #|  <use xlink:href="#g_1" x="0"/>
      #|  <g clip-path="url(#c_1)"/>
      #|  <use xlink:href="#g_2"/>
      #|  <use xlink:href="#g_1"/>
      #|  <a href="#gZ"/>
      #|  <defs>
      #|    <symbol id="g_2"/>
      #|    <symbol id="g_1"/>
      #|  </defs>
      #|  <defs>
      #|    <clipPath id="c_1"/>
      #|  </defs>
      #|</svg>
    ),
  )
}
