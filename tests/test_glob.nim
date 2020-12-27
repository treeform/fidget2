import fidget2/globs, sequtils

assert globMatch("foo", "foo") == true
assert globMatch("foo", "foz") == false
assert globMatch("foo", "fo?") == true
assert globMatch("foo", "f??") == true
assert globMatch("foo", "???") == true
assert globMatch("fooo", "fo?") == false

assert globMatch("foo", "fo*") == true
assert globMatch("foo", "foo*") == true
assert globMatch("fooo", "fo*") == true
assert globMatch("fooo", "f*???") == true

assert globMatch("foobarbaz", "f*z") == true
assert globMatch("foobarbaz", "foo*baz") == true
assert globMatch("foobarbaz", "*baz") == true
assert globMatch("foobarbaz", "f*b*z") == true
assert globMatch("foobarbaz", "f*b?z") == true
assert globMatch("foobarbaz", "f*b????z") == true

assert globMatch("foobarbaz", "f*b*g") == false
assert globMatch("foobarbaz", "*g") == false
assert globMatch("foobarbaz", "z*z") == false

assert globMatch("foo", "f[o]o") == true
assert globMatch("foo", "f[ophjkl]o") == true
assert globMatch("foo", "f[phjklo]o") == true
assert globMatch("foo", "f[phjkl]o") == false

doAssertRaises GlobError:
  discard globMatch("foo", "f[phjklo")

doAssertRaises GlobError:
  discard globMatch("foo", "f[]")

doAssertRaises GlobError:
  discard globMatch("foo", "f[[]")

assert globMatch("foo", "f[a-z]o") == true
assert globMatch("foo5", "foo[0-9]") == true
assert globMatch("fooA", "foo[0-9]") == false
assert globMatch("fooA", "foo[A-Z]") == true
assert globMatch("fooa", "foo[A-Z]") == false

doAssertRaises GlobError:
  discard globMatch("foo", "f[a-")

doAssertRaises GlobError:
  discard globMatch("foo", "f[a-z")

assert globMatch("foo/bar", "foo/bar") == true
assert globMatch("foz/bar", "foo/bar") == false
assert globMatch("foo/bar", "foo/baz") == false

assert globMatch("foo/bar/baz", "foo/bar/*") == true
assert globMatch("foo/bar/baz", "foo/*/baz") == true
assert globMatch("foo/bar/baz", "*/bar/baz") == true
assert globMatch("foo/baz/baz", "foo/bar/*") == false
assert globMatch("foo/baz/baz", "foz/*/bar") == false
assert globMatch("foo/baz/baz", "*/bar/baz") == false

assert globMatch("foo/bar/baz/1", "**/1") == true
assert globMatch("foo/bar/baz/1", "**/baz/1") == true
assert globMatch("foo/bar/baz/1", "**/bar/baz/1") == true
assert globMatch("foo/bar/baz/1", "foo/**/baz/1") == true
assert globMatch("foo/bar/baz/1", "foo/**/1") == true
assert globMatch("foo/bar/baz/2", "foo/**/baz/1") == false

assert globMatch("foo/bar/baz", "foo/bar/baz/**") == false
assert globMatch("foo/bar/baz", "foo/bar/baz**") == true
assert globMatch("foo/bar/baz/1", "foo/bar/baz/**") == true
assert globMatch("foo/bar/baz/1", "foo/bar/**") == true
assert globMatch("foo/bar/baz/1", "foo/**") == true
assert globMatch("foo/bar/baz/1", "**") == true

assert globMatch("foo/bar/baz/at1", "**/*/???/at*") == true
assert globMatch("foo/bar/baz/at1", "**/*/baz/at*") == true
assert globMatch("foo/bar/baz/at1", "foo/*/???/at*") == true
assert globMatch("foo/bar/baz/at1", "**/bar*/???/at*") == true

assert globMatch("foo/bar", "foo/bar.text") == false

assert globMatch("foo/bar", "foo/bar/../bar") == true
assert globMatch("foo/bar", "foo/zzz/../bar") == true
assert globMatch("foo/bar/baz", "foo/bar/../bar/baz") == true
assert globMatch("foo/bar/baz", "foo/zzz/../bar/baz") == true
assert globMatch("foo", "foo/bar/../../foo") == true
assert globMatch("foo", "foo/zzz/../../foo") == true

var tree = GlobTree[int]()

tree.add("foo/bar/baz", 0)
tree.add("foo/bar/baz/1", 1)
tree.add("foo/bar/baz/2", 2)
tree.add("foo/bar/baz/z", 3)
tree.add("foo/bar/baz/z", 4)

assert tree.len == 5

assert tree.find("foo/bar/baz/z") == 3
assert toSeq(tree.findAll("foo/bar/baz/z")).len == 2
tree.del("foo/bar/baz/z", 3)
assert tree.len == 4
assert tree.find("foo/bar/baz/z") == 4
assert toSeq(tree.findAll("foo/bar/baz/z")).len == 1

assert tree.find("foo/bar/baz/1") == 1
assert tree.find("foo/bar/*/1") == 1
assert tree.find("foo/**/1") == 1
assert tree.find("???/**/1") == 1

assert toSeq(tree.findAll("something/*")).len == 0
assert toSeq(tree.findAll("foo/bar/baz/*")).len == 3
assert toSeq(tree.findAll("foo/bar/baz/?")).len == 3
assert toSeq(tree.findAll("foo/bar/baz/[0-9]")).len == 2

tree.del("foo/bar/baz/*")
assert tree.len == 1

tree.del("something/*")
assert tree.len == 1

tree.del("**")
assert tree.len == 0
