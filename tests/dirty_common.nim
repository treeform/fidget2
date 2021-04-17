import fidget2/dirty

type
  Foo* = object
    dirty: bool
    name: string
    a: int

  FooRef* = ref object
    dirty: bool
    name: string
    a: int

genDirtyGettersAndSetter(Foo)
genDirtyGettersAndSetter(FooRef)
