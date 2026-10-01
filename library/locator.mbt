// Port of `typst-library/src/introspection/locator.rs`.
//
// See upstream for the full design discussion. In short: every layout (or
// realization) operation receives a [Locator]. To produce locators for
// multiple children, a locator is [split](Locator::split); to lay out the same
// content again (e.g. for measurement), it is [relayout](Locator::relayout)ed.
// Locations are hierarchical hashes: each layer combines a per-layer key and
// disambiguator with the hash of the layers above.
//
// Upstream links locators across memoization boundaries with
// [LocatorLink]s, so that outer layers are only observed on demand. We keep
// the same structure (and the cached resolution of links), even though there
// is no memoization yet, because it determines the hashes.

///|
/// Provides locations for elements in the document.
///
/// A [Location] is a unique ID for an element generated during realization.
///
/// The `Locator` should only be used once: whenever we are layouting multiple
/// things, we make an explicit decision whether we want to split or relayout.
pub struct Locator {
  /// A local hash that incorporates all layers since the last memoization
  /// boundary.
  priv local_hash : U128
  /// A pointer to an outer cached locator, which contributes the information
  /// for all the layers beyond the memoization boundary on-demand.
  priv outer : LocatorLink?
}

///|
/// Create a new root-level locator.
///
/// Should typically only be created at the document level, though there are
/// a few places where we use it as well that just don't support
/// introspection (e.g. tilings).
pub fn Locator::root() -> Locator {
  { local_hash: u128_zero, outer: None, }
}

///|
/// Creates a new synthetic locator.
///
/// This can be used to create a new dependent layout based on an element.
/// This is used for layouting footnote entries based on the location of the
/// associated footnote.
pub fn Locator::synthesize(location : Location) -> Locator {
  { local_hash: location.hash(), outer: None, }
}

///|
/// Creates a new locator that points to the given link.
pub fn Locator::link(link : LocatorLink) -> Locator {
  { local_hash: u128_zero, outer: Some(link), }
}

///|
/// Returns a type that can be used to generate `Locator`s for multiple child
/// elements. See the type-level docs for more details.
pub fn Locator::split(self : Locator) -> SplitLocator {
  { local_hash: self.local_hash, outer: self.outer, disambiguators: {}, }
}

///|
/// Creates a copy of this locator for measurement or relayout of the same
/// content. See the type-level docs for more details.
///
/// This is effectively just `Clone`, but the `Locator` doesn't implement
/// `Clone` to make this operation explicit.
pub fn Locator::relayout(self : Locator) -> Locator {
  { local_hash: self.local_hash, outer: self.outer, }
}

///|
/// Resolves the locator based on its local and the outer information.
fn Locator::resolve(self : Locator) -> Resolved {
  match self.outer {
    None => Hash(self.local_hash)
    Some(outer) =>
      match outer.resolve() {
        Hash(outer) => Hash(hash128((self.local_hash, outer)))
        Measure(base, span) => Measure(base, span)
      }
  }
}

///|
/// Upstream `Debug for Locator`.
pub impl Show for Locator with fn output(self, logger) {
  logger.write_string("Locator(")
  match self.resolve() {
    Hash(hash) => logger.write_string("Hash(\{hash})")
    Measure(base, span) =>
      logger.write_string("Measure(\{base}, Span(\{span.0}))")
  }
  logger.write_string(")")
}

///|
/// The fully resolved value of a locator.
priv enum Resolved {
  /// The full hash, incorporating the local_hash and all outer information.
  Hash(U128)
  /// Indicates that the locator is in measurement mode, with the given base
  /// location.
  Measure(Location, @syntax.Span)
}

///|
/// A type that generates unique sublocators.
pub struct SplitLocator {
  /// A local hash that incorporates all layers since the last memoization
  /// boundary.
  priv local_hash : U128
  /// A pointer to an outer cached locator, which contributes the information
  /// for all the layers beyond the memoization boundary on-demand.
  priv outer : LocatorLink?
  /// Simply counts up the number of times we've seen each local_hash hash.
  priv disambiguators : Map[U128, Int]
}

///|
/// Produces a sublocator for a subtree keyed by `key`. The keys do *not*
/// need to be unique among the `next()` calls on this split locator. (They
/// can even all be `()`.)
///
/// However, stable & mostly unique keys lead to more stable locations
/// throughout edits, improving incremental compilation performance.
///
/// A common choice for a key is the span of the content that will be
/// layouted with this locator.
pub fn[K : Fingerprint] SplitLocator::next(
  self : SplitLocator,
  key : K,
) -> Locator {
  self.next_inner(hash128(key))
}

///|
/// Produces a sublocator for a subtree.
pub fn SplitLocator::next_inner(self : SplitLocator, key : U128) -> Locator {
  // Produce a locator disambiguator, for elements with the same key within
  // this `SplitLocator`.
  let disambiguator = self.disambiguators.get(key).unwrap_or(0)
  self.disambiguators[key] = disambiguator + 1

  // Combine the key, disambiguator and local_hash hash into a sub-local hash. The
  // outer information is not yet merged into this, it is added on-demand in
  // `Locator::resolve`.
  let local_hash = hash128((key, disambiguator, self.local_hash))
  { outer: self.outer, local_hash, }
}

///|
/// Produces a unique location for an element.
pub fn SplitLocator::next_location(
  self : SplitLocator,
  engine : Engine,
  key : U128,
  elem_span : @syntax.Span,
) -> Location {
  match self.next_inner(key).resolve() {
    Hash(hash) => Location::new(hash)
    Measure(base, measure_span) => {
      let introspection = measure_introspection(
        key, base, measure_span, elem_span,
      )

      // If we aren't able to find a matching element in the document,
      // default to the base location, so that it's at least remotely in the
      // right area (so that counters can be resolved).
      engine.introspect(introspection).unwrap_or(base)
    }
  }
}

///|
/// Tries to find the closest matching element in the document during
/// measurement (upstream `MeasureIntrospection`).
fn measure_introspection(
  key : U128,
  base : Location,
  measure_span : @syntax.Span,
  elem_span : @syntax.Span,
) -> Introspect[Location?] {
  Introspect::new((_, introspector) => introspector.locator(key, base), _ => {
    let diag = SourceDiagnostic::warning_at(
      measure_span, "a measured element did not stabilize",
    ).with_hint(
      "measurement tries to resolve introspections by finding the closest matching elements in the real document",
    )
    if !elem_span.is_detached() {
      diag.spanned_hint(
        "the closest match for this element did not stabilize",
        @syntax.DiagSpan::from_span(elem_span),
      )
    }
    diag
  })
}

///|
/// A locator can be linked to this type to only access information across
/// the memoization boundary on-demand, improving the cache hit chance.
pub struct LocatorLink {
  /// The link itself.
  priv kind : LinkKind
  /// The cached resolved link.
  priv mut resolved : Resolved?
}

///|
/// The different kinds of locator links.
priv enum LinkKind {
  /// An outer `Locator`, which we can resolved if necessary.
  Outer(Locator)
  /// A link which indicates that we are in measurement mode.
  Measure(Location, @syntax.Span)
}

///|
/// Create a locator link.
pub fn LocatorLink::new(outer : Locator) -> LocatorLink {
  { kind: Outer(outer), resolved: None, }
}

///|
/// Creates a link that puts any linked downstream locator into measurement
/// mode.
///
/// Read the "Dealing with measurement" section of the [Locator] docs for
/// more details.
pub fn LocatorLink::measure(
  base : Location,
  span : @syntax.Span,
) -> LocatorLink {
  { kind: Measure(base, span), resolved: None, }
}

///|
/// Resolve the link.
///
/// The result is cached in this link, so that we don't traverse the link
/// chain over and over again.
fn LocatorLink::resolve(self : LocatorLink) -> Resolved {
  match self.resolved {
    Some(resolved) => resolved
    None => {
      let resolved : Resolved = match self.kind {
        Outer(outer) => outer.resolve()
        Measure(base, span) => Measure(base, span)
      }
      self.resolved = Some(resolved)
      resolved
    }
  }
}
