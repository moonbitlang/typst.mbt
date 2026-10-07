#import "c.typ": c-value, limit, lookup

#let b-value = c-value * 2
#let b-fn(body) = [#body (b: #c-value of #limit, looked up:
  #lookup("values").map(str).join("+") of #lookup("limit"))]

This is `b`, with #b-value.
