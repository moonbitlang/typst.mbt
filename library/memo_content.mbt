// Results kept by content (not upstream: the part of comemo that needs no
// constraints).
//
// Upstream memoizes some functions that have no tracked argument: pure
// functions of what their arguments hash to. The ones here are those whose
// results are expensive and that a document asks for again and again:
// decoding a raster image (`RasterImage::new_impl`, `image_raster.mbt`) and
// highlighting raw text (`Packed<RawElem>::highlight`, `text_raw.mbt`).
// Unlike the memoized calls of `memo.mbt` they need no world, introspector,
// route or sink, so a result is valid for as long as the process runs,
// within a compilation and in the next one.
//
// - A result is found by the 128-bit fingerprint of the arguments, as
//   comemo finds it by their hash. Large data (the bytes of an image) is
//   hashed once per `Bytes` object ([data_hash]), where upstream keeps the
//   hash in the `Bytes` (`LazyHash`).
// - Lifetime is comemo's: every entry has an age, a hit sets it to zero,
//   [evict] adds one to each and drops those above `max_age`. A process
//   that never calls [evict] keeps everything, as one using comemo does.
//   (The decode caches of `evict`'s own list have no ages and are dropped
//   as a whole.)
// - They are used whenever memoization is on ([set_layout_memo_enabled]),
//   in a compilation and outside of one (an export): the switch exists to
//   compare results with and without memoization, and these are memoized
//   results. With it off nothing is looked up and nothing is stored.
// - Results are immutable objects (images, content) or copied by the caller
//   (the array of highlighted lines), like upstream's, which are behind
//   `Arc`s or cloned out of the cache.
// - Errors are kept like results (comemo caches the `Result`): the second
//   use of a broken image reports what the first did.

///|
/// Whether results are kept by content: with memoization on
/// ([set_layout_memo_enabled]), in and outside of compilations.
pub fn content_memo_enabled() -> Bool {
  memo_enabled.val
}

///|
/// What [evict] calls besides dropping its own caches (comemo's
/// `register_evictor`).
let evictors : Array[(Int) -> Unit] = []

///|
/// Registers a function that [evict] calls with its `max_age` (comemo's
/// `register_evictor`): for caches of packages that `library` does not know.
pub fn register_evictor(f : (Int) -> Unit) -> Unit {
  evictors.push(f)
}

///|
priv struct ContentEntry[T] {
  value : T
  /// The number of [evict] calls since the entry was made or found.
  mut age : Int
}

///|
/// The results of a pure function, by the fingerprint of its arguments
/// (comemo's cache of a memoized function without tracked arguments).
pub struct ContentCache[T] {
  priv entries : Map[U128, ContentEntry[T]]
  /// Whether [evict] knows the cache (it does from the first entry on).
  priv mut registered : Bool
}

///|
pub fn[T] ContentCache::new() -> ContentCache[T] {
  { entries: Map([]), registered: false, }
}

///|
/// The result for a key, if there is one. Finding it makes it young again.
pub fn[T] ContentCache::get(self : ContentCache[T], key : U128) -> T? {
  match self.entries.get(key) {
    Some(entry) => {
      entry.age = 0
      Some(entry.value)
    }
    None => None
  }
}

///|
/// Keeps the result for a key, replacing an earlier one.
pub fn[T] ContentCache::insert(
  self : ContentCache[T],
  key : U128,
  value : T,
) -> Unit {
  if !self.registered {
    self.registered = true
    register_evictor(max_age => self.evict(max_age))
  }
  self.entries[key] = { value, age: 0, }
}

///|
/// comemo's `evict`: every entry gets older by one, and those that were not
/// found for more than `max_age` calls are dropped (all of them for zero).
pub fn[T] ContentCache::evict(self : ContentCache[T], max_age : Int) -> Unit {
  let dropped = []
  for key, entry in self.entries {
    entry.age += 1
    if entry.age > max_age {
      dropped.push(key)
    }
  }
  for key in dropped {
    self.entries.remove(key)
  }
}

///|
/// The number of results.
pub fn[T] ContentCache::length(self : ContentCache[T]) -> Int {
  self.entries.length()
}

// The hash of data.

///|
priv struct DataHashEntry {
  data : Bytes
  hash : U128
  /// Whether the hash was asked for since the last [evict].
  mut used : Bool
}

///|
/// `hash128` of data that was hashed before, by the identity of the `Bytes`
/// (upstream: the `LazyHash` inside `Bytes`, so data is hashed once however
/// often it is part of a key). There is no map by identity, so the objects
/// are filed under what is cheap to read of them ([data_probe]).
///
/// An entry keeps its data alive, and an object that the world has replaced
/// (a file is read again after `World::reset`) is never asked for again:
/// [evict] drops the entries that were not used since its last call.
let data_hashes : Map[Int, Array[DataHashEntry]] = Map([])

///|
/// Data below this length is hashed on every call: that costs less than
/// finding it.
let data_hash_min_length : Int = 256

///|
/// Where an object is filed in [data_hashes]: its length and a few of its
/// bytes (at least [data_hash_min_length] of them exist).
fn data_probe(data : Bytes) -> Int {
  let n = data.length()
  let mut h = n
  let step = n / 16
  for i in 0..<16 {
    h = h * 31 + data[i * step].to_int()
  }
  for i in (n - 16)..<n {
    h = h * 31 + data[i].to_int()
  }
  h
}

///|
/// `hash128` of data (upstream `Bytes` hashes as the `u128` of its
/// `LazyHash`): computed once per object and kept by its identity.
pub fn data_hash(data : Bytes) -> U128 {
  if data.length() < data_hash_min_length {
    return data_hash_uncached(data)
  }
  let probe = data_probe(data)
  match data_hashes.get(probe) {
    Some(bucket) => {
      for entry in bucket {
        if physical_equal(entry.data, data) {
          entry.used = true
          return entry.hash
        }
      }
      let hash = data_hash_uncached(data)
      bucket.push({ data, hash, used: true, })
      hash
    }
    None => {
      let hash = data_hash_uncached(data)
      data_hashes[probe] = [{ data, hash, used: true, }]
      hash
    }
  }
}

///|
fn data_hash_uncached(data : Bytes) -> U128 {
  let h = SipHasher128::new()
  // `[u8]`: a length prefix, then the bytes.
  h.write_usize(data.length())
  h.write_bytes(data[:])
  h.finish128()
}

///|
/// Drops the hashes of the objects that were not asked for since the last
/// call (see [data_hashes]).
fn evict_data_hashes() -> Unit {
  let dropped = []
  for probe, bucket in data_hashes {
    bucket.retain(entry => entry.used)
    if bucket.is_empty() {
      dropped.push(probe)
    }
    for entry in bucket {
      entry.used = false
    }
  }
  for probe in dropped {
    data_hashes.remove(probe)
  }
}
