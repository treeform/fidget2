import sequtils, strutils, algorithm
include fidget2/globs

proc mk(path: string): Node =
  for p in path.split("/").reversed():
    var n = Node(name: p)
    if result != nil:
      n.children.add(result)
    result = n

  var n = Node(name: "")
  if result != nil:
      n.children.add(result)
  result = n

doAssert globMatchOne("foo", "foo") == true
doAssert globMatchOne("foo", "foz") == false
doAssert globMatchOne("foo", "fo?") == true
doAssert globMatchOne("foo", "f??") == true
doAssert globMatchOne("foo", "???") == true
doAssert globMatchOne("fooo", "fo?") == false

doAssert globMatchOne("foo", "fo*") == true
doAssert globMatchOne("foo", "foo*") == true
doAssert globMatchOne("fooo", "fo*") == true
doAssert globMatchOne("fooo", "f*???") == true

doAssert globMatchOne("foobarbaz", "f*z") == true
doAssert globMatchOne("foobarbaz", "foo*baz") == true
doAssert globMatchOne("foobarbaz", "*baz") == true
doAssert globMatchOne("foobarbaz", "f*b*z") == true
doAssert globMatchOne("foobarbaz", "f*b?z") == true
doAssert globMatchOne("foobarbaz", "f*b????z") == true

doAssert globMatchOne("foobarbaz", "f*b*g") == false
doAssert globMatchOne("foobarbaz", "*g") == false
doAssert globMatchOne("foobarbaz", "z*z") == false

doAssert globMatchOne("foo", "f[o]o") == true
doAssert globMatchOne("foo", "f[ophjkl]o") == true
doAssert globMatchOne("foo", "f[phjklo]o") == true
doAssert globMatchOne("foo", "f[phjkl]o") == false

doAssertRaises GlobbyError:
  discard globMatchOne("foo", "f[phjklo")

doAssertRaises GlobbyError:
  discard globMatchOne("foo", "f[]")

doAssertRaises GlobbyError:
  discard globMatchOne("foo", "f[[]")

doAssert globMatchOne("foo", "f[a-z]o") == true
doAssert globMatchOne("foo5", "foo[0-9]") == true
doAssert globMatchOne("fooA", "foo[0-9]") == false
doAssert globMatchOne("fooA", "foo[A-Z]") == true
doAssert globMatchOne("fooa", "foo[A-Z]") == false

doAssertRaises GlobbyError:
  discard globMatchOne("foo", "f[a-")

doAssertRaises GlobbyError:
  discard globMatchOne("foo", "f[a-z")

doAssert mk("foo/bar").walk().len == 2

doAssert mk("foo/bar").find("/foo").name == "foo"
doAssert mk("foo/bar").find("/foo/bar").name == "bar"
doAssert mk("foo/bar").find("/foo/baz") == nil

doAssert mk("foo/bar/baz").find("foo/bar/*") != nil
doAssert mk("foo/bar/baz").find("foo/*/baz") != nil
doAssert mk("foo/bar/baz").find("*/bar/baz") != nil
doAssert mk("foo/baz/baz").find("foo/bar/*") == nil
doAssert mk("foo/baz/baz").find("foz/*/bar") == nil
doAssert mk("foo/baz/baz").find("*/bar/baz") == nil

doAssert mk("foo/bar").find("foo/bar.text") == nil

doAssert mk("foo/bar").find("foo/bar/../bar") != nil
doAssert mk("foo/bar").find("foo/zzz/../bar") != nil
doAssert mk("foo/bar/baz").find("foo/bar/../bar/baz") != nil
doAssert mk("foo/bar/baz").find("foo/zzz/../bar/baz") != nil
doAssert mk("foo").find("foo/bar/../../foo") != nil
doAssert mk("foo").find("foo/zzz/../../foo") != nil

doAssert mk("foo/bar").find("z//foo/bar") != nil
doAssert mk("foo/bar").find("z/x//foo/bar") != nil
doAssert mk("foo/bar/baz").find("foo/bar//foo/bar/baz") != nil
doAssert mk("foo/bar/baz").find("foo/zzz//foo/bar/baz") != nil
doAssert mk("foo").find("foo/bar/baz//foo") != nil
doAssert mk("foo").find("z/x/y//foo") != nil

doAssert mk("foo/bar/baz/1").findAll("**/1").len == 1
doAssert mk("foo/bar/baz/1").findAll("**/lol").len == 0

doAssert mk("foo/bar/baz/1").find("**/1") != nil
doAssert mk("foo/bar/baz/1").find("**/baz/1") != nil
doAssert mk("foo/bar/baz/1").find("**/bar/baz/1") != nil
doAssert mk("foo/bar/baz/1").find("foo/**/baz/1") != nil
doAssert mk("foo/bar/baz/1").find("foo/**/1") != nil
doAssert mk("foo/bar/baz/2").find("foo/**/baz/1") == nil

doAssert mk("foo/bar/baz").find("foo/bar/baz/**") == nil
doAssert mk("foo/bar/baz").find("foo/bar/baz**") != nil
doAssert mk("foo/bar/baz/1").find("foo/bar/baz/**") != nil
doAssert mk("foo/bar/baz/1").find("foo/bar/**") != nil
doAssert mk("foo/bar/baz/1").find("foo/**") != nil
doAssert mk("foo/bar/baz/1").find("**") != nil

doAssert mk("foo/bar/baz/at1").find("**/*/???/at*") != nil
doAssert mk("foo/bar/baz/at1").find("**/*/baz/at*") != nil
doAssert mk("foo/bar/baz/at1").find("foo/*/???/at*") != nil
doAssert mk("foo/bar/baz/at1").find("**/bar*/???/at*") != nil

block:
  var tree = Node(name: "") # Root node needs to have no name
  var foo = Node(name: "foo")
  var bar = Node(name: "bar")
  var baz = Node(name: "baz")
  tree.children.add(foo)
  foo.children.add(bar)
  bar.children.add(baz)
  baz.children.add Node(name: "1")
  baz.children.add Node(name: "2")
  baz.children.add Node(name: "z")
  baz.children.add Node(name: "z")

  doAssert tree.treeLen == 8
  doAssert baz.treeLen == 5
  doAssert tree.walk == @[
    ("/foo", foo),
    ("/foo/bar", bar),
    ("/foo/bar/baz", baz),
    ("/foo/bar/baz/1", baz.children[0]),
    ("/foo/bar/baz/2", baz.children[1]),
    ("/foo/bar/baz/z", baz.children[2]),
    ("/foo/bar/baz/z", baz.children[3])
  ]

  doAssert tree.findAll("").len == 0

  doAssert tree.findAll("foo/bar/baz/z").len == 2
  doAssert tree.findAll("foo/bar/baz/1").len == 1
  doAssert tree.findAll("foo/bar/*/1").len == 1
  doAssert tree.findAll("???/bar/*/1").len == 1

  doAssert tree.findAll("something/*").len == 0
  doAssert tree.findAll("foo/bar/baz/*").len == 4
  doAssert tree.findAll("foo/bar/baz/?").len == 4
  doAssert tree.findAll("foo/bar/baz/[0-9]").len == 2

  doAssert tree.findAll("foo/**/1").len == 1
  doAssert tree.findAll("???/**/1").len == 1
  doAssert tree.findAll("???/**/z").len == 2

  doAssert tree.findAll("**").len == 7
  doAssert tree.findAll("foo/**").len == 6
  doAssert tree.findAll("foo/bar/**").len == 5
  doAssert tree.findAll("foo/bar/baz/**").len == 4
