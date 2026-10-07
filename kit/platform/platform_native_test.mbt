// Tests of what only the native backend has: files that are read in ranges
// through a descriptor.

///|
test "ranged file: a file that gets shorter while it is open" {
  let dir = "_build/kit_platform_test"
  @platform.create_dir_all(dir)
  let path = @platform.join(dir, "shrinking.bin")
  let data = Bytes::makei(100000, i => (i % 251).to_byte())
  @platform.write_file(path, data)
  let file = @platform.RangedFile::open(path)
  inspect(file.size(), content="100000")
  inspect(file.read(99990L, 10).length(), content="10")
  // Truncated in place (the same file): reads end where the file now ends,
  // and nothing faults, which a mapping of the file would.
  @platform.write_file(path, data[:100].to_owned())
  inspect(file.size(), content="100")
  inspect(file.read(50L, 100) == data[50:100].to_owned(), content="true")
  inspect(file.read(99990L, 10).length(), content="0")
  // And when it grows again.
  @platform.write_file(path, data[:200].to_owned())
  inspect(file.read(50L, 1000).length(), content="150")
  file.close()
}

///|
test "ranged file: closed files give their descriptors back" {
  let dir = "_build/kit_platform_test"
  @platform.create_dir_all(dir)
  let path = @platform.join(dir, "many.bin")
  @platform.write_file(path, b"0123456789")
  let mut sum = 0
  for _ in 0..<20000 {
    let file = @platform.RangedFile::open(path)
    sum += file.read(3L, 1)[0].to_int()
    file.close()
  }
  inspect(sum, content="1020000")
}
