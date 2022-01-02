import tables
export tables

# Advantages of entity component systems:
# * Not all entities need to have all components.
# * You only pass entity ID's around as entity is its ID, no pointers or refs.
# * You can iterate over all components instead of all entities, this is great
# because you might have a very large number of entities but very small number
# of a particular component.
# * You can choose to use seq backed storage for components (for fairly common)
# or choose hash table (for uncommon components).

# Entity Component System in 10 lines
type
  Entity* = uint32

var newCount = 0
proc newEntity*(): Entity =
  inc newCount
  return newCount.uint32

proc clear*(t: typedesc[Entity]) =
  newCount = 0

template attachAs*(componentType: typedesc, name: untyped, ) =

  var `name Seq`* {.inject.} = newSeq[(bool, componentType)](1000)

  proc name* (entity: Entity): var componentType {.inject.} =
    `name Seq`[entity][1]

  proc `name=`* (entity: Entity, component: componentType) {.inject.} =
    if `name Seq`.len <= entity.int:
      `name Seq`.setLen(entity + 1)
    `name Seq`[entity] = (true, component)

  proc `has componentType`* (entity: Entity): bool {.inject.} =
    `name Seq`[entity][0]

  iterator `mpairs`*(t: typedesc[componentType]): (Entity, var componentType) {.inject.} =
    for (e, hc) in `name Seq`.mpairs:
      if hc[0]:
        yield (e.Entity, hc[1])

  proc `init componentType`* (entity: Entity): var componentType =
    if `name Seq`.len <= entity.int:
      `name Seq`.setLen(entity + 1)
    `name Seq`[entity][0] = true
    `name Seq`[entity][1]

  proc `clear`* (t: typedesc[componentType]) =
    `name Seq`.setLen(0)

proc initKey*[K, V](t: var Table[K, V] , k: K): var V =
  #echo "ouch"
  t[k] = V()
  return t[k]

template attachUncommonAs*(componentType: typedesc, name: untyped) =

  var `name Hash`* {.inject.}: Table[Entity, componentType]

  proc name* (entity: Entity): var componentType {.inject.} =
    `name Hash`[entity]

  proc `name=`* (entity: Entity, component: componentType) {.inject.} =
    `name Hash`[entity] = component

  proc `has componentType`* (entity: Entity): bool {.inject.} =
    entity in `name Hash`

  iterator `mpairs`*(t: typedesc[componentType]): (Entity, var componentType) {.inject.} =
    for (e, c) in `name Hash`.mpairs():
      yield (e, c)

  proc `init componentType`* (entity: Entity): var componentType =
    # `name Hash`[entity] = componentType()
    `name Hash`.initKey(entity)

  proc `clear`* (t: typedesc[componentType]) =
    `name Hash`.clear()
