type
  Node = ref object
    id: int
    name*: string
    count*: int

echo sizeof(Node())
