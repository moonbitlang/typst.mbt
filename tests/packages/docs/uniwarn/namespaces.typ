// uniwarn 0.1.1: custom warnings by namespace: default namespace, a
// registered namespace with a bound prefix, disabling and re-enabling,
// a second registration reported as a warning (panic: false), messages with
// non-ASCII text, warnings raised from inside a function used in a table.
// Stresses `unknown font family` warnings whose family name carries control
// characters (backspaces) and long text, state per namespace, deduplication
// of equal warnings.
#import "@preview/uniwarn:0.1.1" as uwarn

#set page(width: 12cm, height: 14cm, margin: 1.2cm)
#set text(size: 10pt)

= Unit conversions for the galley

#let ns = "galley"
#uwarn.register-namespace(ns)
#let galley-warning = uwarn.warning.with(namespace: ns, prefix: "[galley] ")

// A helper that warns about doubtful input and still returns a value.
#let to-grams(amount, unit) = {
  let factors = (g: 1, kg: 1000, oz: 28.35, lb: 453.6)
  if unit in factors {
    [#calc.round(amount * factors.at(unit), digits: 1) g]
  } else {
    galley-warning("Unknown unit \"" + unit + "\" for " + str(amount) + "; the amount is printed as it was given.")
    [#amount #unit]
  }
}

#table(
  columns: (1fr, auto, auto),
  table.header[Ingredient][Given][In grams],
  [Flour], [2 lb], to-grams(2, "lb"),
  [Butter], [6 oz], to-grams(6, "oz"),
  [Sugar], [3 cups], to-grams(3, "cups"),
  [Salt], [1 pinch], to-grams(1, "pinch"),
  [Salt again], [1 pinch], to-grams(1, "pinch"),
)

The two rows with a pinch of salt raise the same message from the same
place, so only one warning is reported for them.

#uwarn.warning("A warning in the default namespace.")
#uwarn.warning(prefix: "[küche] ", "Maßeinheit „Prise“ ist nicht genormt — naïve Schätzung: ½ g.")

== Switched off

#uwarn.disable-warnings(ns)
#table(
  columns: (1fr, auto, auto),
  [Yeast], [1 cube], to-grams(1, "cube"),
)
Nothing is reported for the cube of yeast.
#uwarn.warning("The default namespace is not affected by disabling another one.")

#uwarn.disable("cstm")
#uwarn.warning("This one is silent.")
#uwarn.enable("cstm")

== Switched on again

#uwarn.enable-warnings(ns)
#table(
  columns: (1fr, auto, auto),
  [Milk], [1 jug], to-grams(1, "jug"),
)

#uwarn.register-namespace(ns, panic: false)

Registering the namespace a second time, without panicking, is reported as
a warning too.
