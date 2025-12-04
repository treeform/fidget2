import
  std/[algorithm, random, strformat, times],
  fidget2

const
  speed = 0.2
  friction = 0.05
  playAreaSize = vec2(960, 640)
  keyDirections = [
    vec2(0, -1),
    vec2(-1, 0),
    vec2(0, 1),
    vec2(1, 0)
  ]

type
  Player = ref object
    playerNode: Node
    shadowNode: Node
    scoreNode: Node
    name: string
    pos: Vec2
    z: float32
    vel: Vec2
    zVel: float32
    score: int
    boost: float
    keys: array[4, Button]

  PillKind = enum
    RegularPill
    SlowPill
    FastPill


  Pill = ref object
    pillNode: Node
    shadowNode: Node
    kind: PillKind
    pos: Vec2
    z: float32

var
  players: seq[Player]
  pills: seq[Pill]
  startTime = epochTime()

players.add Player(
  name: "Red",
  pos: vec2(100, 100),
  keys: [KeyW, KeyA, KeyS, KeyD]
)

players.add Player(
  name: "Green",
  pos: vec2(300, 100),
  keys: [KeyI, KeyJ, KeyK, KeyL]
)

for i in 0 ..< 3:
  pills.add Pill(
    kind: RegularPill,
    pos: vec2(
      rand(60f .. playAreaSize.x - 60),
      rand(60f .. playAreaSize.y - 60)
    ),
    z: 500
  )

onFrame:
  var playAreaNode = find("/Main/PlayArea/Players")
  var playShadowsNode = find("/Main/PlayArea/Shadows")

  if rand(0 ..< 60) == 0:
    pills.add Pill(
      kind: RegularPill,
      pos: vec2(
        rand(60f .. playAreaSize.x - 60),
        rand(60f .. playAreaSize.y - 60)
      ),
      z: 500
    )

  for pill in pills:
    if pill.pillNode == nil:
      var p = find("/Main/Pill/Color=Yellow")
      echo p != nil
      pill.pillNode = find("/Main/Pill/Color=Yellow").copy()
      playAreaNode.addChild(pill.pillNode)
      pill.shadowNode = find("/Main/PillShadow").copy()
      playShadowsNode.addChild(pill.shadowNode)
    pill.pillNode.position = pill.pos - pill.pillNode.size / 2 + vec2(0, -pill.z)
    pill.shadowNode.position = pill.pos - pill.shadowNode.size / 2 + vec2(0, 18)

    pill.z -= 11.0
    pill.z = pill.z.clamp(0, 1000)

  for player in players:
    for i in 0 .. 3:
      if window.buttonDown[player.keys[i]]:
        player.vel += keyDirections[i] * speed

    if player.playerNode == nil:
      player.playerNode = find("/Main/PlayArea/Players/" & player.name & "Player")
      player.shadowNode = find("/Main/PlayArea/Shadows/" & player.name & "Shadow")
      player.scoreNode = find("/Main/PlayArea/" & player.name & "Score")

    player.pos += player.vel
    player.pos.x = player.pos.x.clamp(60, playAreaSize.x - 60)
    player.pos.y = player.pos.y.clamp(60, playAreaSize.y - 60)
    player.playerNode.position = player.pos - player.playerNode.size / 2
    player.vel = player.vel * (1 - friction)
    player.playerNode.dirty = true

    player.shadowNode.position = player.pos - player.shadowNode.size / 2 + vec2(0, 40)
    if player.scoreNode.text != $player.score:
      player.scoreNode.text = $player.score
      player.scoreNode.makeTextDirty()

    var i = 0
    while i < pills.len:
      let pill = pills[i]
      if pill.pos.dist(player.pos) < 100:
        echo "eat"
        pill.pillNode.parent.removeChild(pill.pillNode)
        pill.shadowNode.parent.removeChild(pill.shadowNode)
        pills.del(i)
        inc player.score
        continue
      inc i

  let
    player = players[0]
    other = players[1]
    diff = player.pos - other.pos
  if diff.length < 100:
    if diff.length() < 60:
      let
        overlap = 60 - diff.length
        push = diff / diff.length * overlap
      if player.vel.length > 0.1 and other.vel.length < 0.1:
          other.pos -= push
      elif player.vel.length < 0.1 and other.vel.length > 0.1:
          player.pos += push
      else:
          player.pos += push / 2
          other.pos -= push / 2

    player.vel = player.vel * 0.5 + other.vel * 0.5
    other.vel = other.vel * 0.5 + player.vel * 0.5

  # playAreaNode.children.sort proc(a, b: Node): int =
  #   cmp(a.position.y + a.size.y/2, b.position.y + b.size.y/2)

  var timerNode = find("/Main/PlayArea/Timer")
  let
    time = int(epochTime() - startTime)
    min = time div 60
    sec = time mod 60
    timeStr = &"{min}:{sec:02}"
  if timerNode.text != timeStr:
    timerNode.text = timeStr
    timerNode.makeTextDirty()

startFidget(
  figmaUrl = "https://www.figma.com/file/9tysxPLtgKmrmsrwbVSROm/Bubbleats",
  windowTitle = "Bubbleats",
  entryFrame = "Main/PlayArea",
  windowStyle = Decorated
)
while isRunning():
  tickFidget()
closeFidget()
