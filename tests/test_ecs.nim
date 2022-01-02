import fidget2/ecs

# Here is how to create a component.
type
  Physical = object
    pos: (float32, float32)
    vec: (float32, float32)
    radius: float32
    height: float32

  Network = object
    address: string
    authToken: string

Physical.attachAs(physical)
Network.attachUncommonAs(network)

# Here is how to create a entity and use its components.
var e: Entity = newEntity()

e.physical = Physical() # Attach a component to entity
# We can now use it as if its part of the object:
echo e.physical.pos
e.physical.pos = (100'f32, 100'f32)
echo e.hasPhysical
# No Network component so this will be false.
echo e.hasNetwork
# We can iterate over all physics components directly.
for (entity, p) in Physical.pairs:
  echo entity, ": ", p
# We can iterate over all network components directly.
for (entity, p) in Network.pairs:
  echo entity, ": ", p
