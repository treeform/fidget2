import dirty_common

block:
  # Objects start out not dirty.
  var f = Foo()
  assert f.dirty == false

  # But if you set some thing they get dirty.
  f.name = "hi"
  echo f.name
  assert f.dirty == true

  # After you handle the dirty you can clean them.
  f.dirty = false
  assert f.dirty == false

  # Though, a change will mark them dirty again.
  f.a = 1
  echo f.a
  assert f.dirty == true

block:
  # test RefObjects

  # Objects start out not dirty.
  var f = FooRef()
  assert f.dirty == false

  # But if you set some thing they get dirty.
  f.name = "hi"
  echo f.name
  assert f.dirty == true

  # After you handle the dirty you can clean them.
  f.dirty = false
  assert f.dirty == false

  # Though, a change will mark them dirty again.
  f.a = 1
  echo f.a
  assert f.dirty == true

import fidget2/schema
block:
  var n = Node()
  assert n.dirty == false
  n.characters = "hi there"
  assert n.dirty == true
