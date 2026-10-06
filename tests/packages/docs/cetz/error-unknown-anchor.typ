// cetz 0.5.2: an error raised inside the package while it resolves a
// coordinate (an anchor name that the element does not have). Compares the
// message, which lists the valid anchors, and the trace through nested
// groups, closures and the canvas.

#import "@preview/cetz:0.5.2"

#set page(width: 10cm, height: 6cm)

A valve symbol, with a label that hangs on a corner the circle lacks:

#cetz.canvas({
  import cetz.draw: *
  group(name: "valve", {
    line((-1, -0.5), (1, 0.5), (1, -0.5), (-1, 0.5), close: true, name: "body")
    circle((0, 0), radius: 0.2, fill: white, name: "stem")
  })
  group({
    rotate(15deg)
    content("valve.stem.top-left", [V-101], anchor: "south-east")
  })
})
