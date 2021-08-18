import fidget2, puppy, jsony, print, vmath, strformat, pixie, fidget2/common, tables, chroma, times

type
  Category = ref object
    id: int
    name: string
    description: string
    color: string
    numTopics: int

  User = ref object
    name: string
    avatarUrl: string
    lastOnline: int
    previousVisitAt: int
    rank: string
    isDeleted: bool

  Thread = ref object
    id: int
    topic: string
    category: Category
    author: User
    users: seq[User]
    replies: int
    views: int
    activity: int
    creation: int
    isLocked: bool
    isSolved: bool

  ThreadPage = ref object
    threads: seq[Thread]
    moreCount: int

var threadPage: ThreadPage

proc getColor(category: Category): Color =
  parseHtmlColor(
    case category.name:
    of "Announcements": "#000000"
    of "Questions": "#F7941D"
    of "Docs": "#B4D0F7"
    of "Meta": "#FFE0C6"
    of "Design": "#FFFFBF"
    else: #of "Default":
      "#A3A3A3"
  )

proc formatActivity(activity: int): string =
  let
    age = epochTime() - activity.float64
  if age / 60 < 60:
    $(age / 60).int & "m"
  elif age / 60 / 60 < 24:
    $(age / 60 / 60).int & "h"
  else:
    $(age / 60 / 60 / 24).int & "d"

var loaded: bool
proc displayCb() {.cdecl.} =
  if loaded == false:
    loaded = true
    var data = fetch("https://forum.nim-lang.org/threads.json")
    threadPage = fromJson(data, ThreadPage)

    var
      threadRow = find("/MainScreen/ThreadList/ThreadRow")
      threadList = find("/MainScreen/ThreadList")

    for node in findAll("/MainScreen/ThreadList/ThreadRow"):
      node.remove()

    var y = 0
    for thread in threadPage.threads:
      threadRow = threadRow.copy()
      threadRow.name = $thread.id
      threadRow.position = vec2(0, y.float32)
      y += 51
      threadList.addChild(threadRow)

      threadRow.children[0].characters = thread.topic
      threadRow.children[1].characters = thread.category.name
      threadRow.children[2].characters = $thread.replies
      threadRow.children[3].characters = $thread.views
      threadRow.children[4].characters = formatActivity(thread.activity)

      var users = threadRow.children[5]
      for i in 0 ..< 5:
        if i >= thread.users.len:
          users.children[i].visible = false
        else:
          users.children[i].visible = true
          let
            url = thread.users[i].avatarUrl
            imageData = fetch(url)
            avatarImage = decodeImage(imageData)
          imageCache[url] = avatarImage
          users.children[i].fills[0].imageRef = url

      threadRow.children[6].fills[0].color = thread.category.getColor

      #threadRow.find("Topic").characters = thread.topic

      #let topic = find(&"/MainScreen/ThreadList/{thread.id}/Topic")
      #topic.characters = thread.topic


    print threadList.children.len

    var mainScreen = find("/MainScreen")
    mainScreen.markTreeDirty()


addCb(eOnDisplay, 100, "/MainScreen", displayCb)




startFidget(
  figmaUrl = "https://www.figma.com/file/KbOeyQXdW9FzZBqy9loS7C",
  windowTitle = "Nim Forum",
  entryFrame = "MainScreen",
  resizable = true
)
