import
  std/[sequtils, strformat, tables, times],
  chroma, fidget2, fidget2/common, jsony, pixie, vmath

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

find "/UI/MainScreen":
  onShow:
    var req = startHttpRequest("https://forum.nim-lang.org/threads.json")
    req.onResponse = proc(response: HttpResponse) =
      threadPage = fromJson(response.body, ThreadPage)

      var
        threadRowMaster = find("/UI/ThreadRow/State=Default")
        threadList = find("/UI/MainScreen/ThreadList")

      threadList.removeChildren()

      for thread in threadPage.threads:
        let threadRow = threadRowMaster.newInstance()

        threadRow.find("Topic").text = thread.topic
        threadRow.find("Category").text = thread.category.name
        threadRow.find("Replies").text = $thread.replies
        threadRow.find("Views").text = $thread.views
        threadRow.find("Time").text = formatActivity(thread.activity)

        for i, userIcon in threadRow.findAll("Users/*"):
          if i >= thread.users.len:
            userIcon.visible = false
          else:
            userIcon.visible = true
            userIcon.fills[0].imageUrl = thread.users[i].avatarUrl

        threadRow.find("CategoryMark").fills[0].color = thread.category.getColor
        threadList.addChild(threadRow)

    req.onError = proc(msg: string) =
      echo "Error fetching threads: ", msg

startFidget(
  figmaUrl = "https://www.figma.com/file/KbOeyQXdW9FzZBqy9loS7C",
  windowTitle = "Nim Forum",
  entryFrame = "/UI/MainScreen",
  windowStyle = DecoratedResizable
)
while isRunning():
  tickFidget()
closeFidget()
