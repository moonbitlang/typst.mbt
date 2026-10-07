#let data = json("data.json")
#let c-value = data.values.sum()
#let limit = data.limit

// A function that reads the file when it is called: the same call gives
// another value after the file changed.
#let lookup(key) = json("data.json").at(key)

This is `c`, with #c-value.
