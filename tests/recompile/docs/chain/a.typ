#import "b.typ": b-fn, b-value

#let a-value = b-value + 1
#let a-show(body) = block(fill: luma(235), inset: 4pt, b-fn(body))

This is `a`, with #a-value.
