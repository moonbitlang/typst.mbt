#import "c.typ": c-value
#import "c.typ" as shared-module

#let d-value = c-value - 1
#let shared = shared-module.limit

This is `d`, with #d-value.
