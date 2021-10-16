import fidget2


find "/UI/Splash":
  onClick:
    echo "me?"
    navigateTo("/UI/MainMenu")

find "/UI/**/Back":
  onClick:
    navigateBack()

# find "**/MainMenu":
#   onClick:
#     navigateTo("/UI/MainMenu")

find "/UI/MainMenu":
  find "Fight":
    onClick:
      navigateTo("/UI/FightMenu")

  find "Design":
    onClick:
      navigateTo("/UI/DesignMenu")

  find "SubMenu":
    find "Profile":
      onClick:
        navigateTo("/UI/Profile")

    find "Settings":
      onClick:
        navigateTo("/UI/Settings")

    find "Friends":
      onClick:
        navigateTo("/UI/Friends")

    find "Kits":
      onClick:
        navigateTo("/UI/Kits")

    find "Quit":
      onClick:
        quit(0)

find "/UI/FightMenu":

  find "PvE":
    onClick:
      navigateTo("/UI/Queued")

  find "PvP":
    onClick:
      navigateTo("/UI/Queued")

  find "1v1":
    onClick:
      navigateTo("/UI/Queued")

  find "Spectate":
    onClick:
      navigateTo("/UI/Spectate")

  find "Custom":
    onClick:
      navigateTo("/UI/CustomGames")

  find "Challenge":
    onClick:
      navigateTo("/UI/Challenge")

find "/UI/Queued":

  find "Mode":
    onClick:
      echo "should go to battle?"
      navigateTo("/UI/GameStarting")

find "/UI/GameStarting":
  onClick:
    navigateTo("/UI/Battle")

find "/UI/Battle":
  onClick:
    navigateTo("/UI/Defeat")

find "/UI/Defeat":
  onClick:
    navigateTo("/UI/WinScreen1")

find "/UI/WinScreen1":
  find "Next":
    onClick:
      navigateTo("/UI/WinScreen2")

find "/UI/WinScreen2":
  onClick:
    navigateTo("/UI/Queued")

find "/UI/DesignMenu":

  find "Design":
    onClick:
      navigateTo("/UI/Design")

  find "Fleet":
    onClick:
      navigateTo("/UI/Fleet")

  find "Workshop":
    onClick:
      navigateTo("/UI/Workshop")

find "/UI/Queued":

  find "Back":
    onClick:
      navigateTo("/UI/DesignMenu")

find "/UI/Profile":

  find "Replays":
    onClick:
      navigateTo("/UI/Replays")

find "/UI/Settings":
  discard

find "/UI/Friends":
  discard

find "/UI/Kits":
  find "Kit":
    onClick:
      navigateTo("/UI/Kit")

find "/UI/Kit":
  find "Back":
    onClick:
      navigateTo("/UI/Kits")

find "/UI/Workshop":
  find "**/Ship":
    onClick:
      navigateTo("/UI/WorkshopShip")

  find "**/Fleet":
    onClick:
      navigateTo("/UI/WorkshopFleet")

find "/UI/Fleet":
  discard

find "/UI/Replays":

  find "**/ReplayRow":
    onClick:
      navigateTo("/UI/ReplayPlayer")

find "/UI/ReplayPlayer":
  discard

find "/UI/Spectate":
  discard

find "/UI/CustomGames":

  find "HostCustomGame":
    onClick:
      navigateTo("/UI/CreateCustomGame")

find "/UI/Challenge":

  find "CreateChallenge":
    onClick:
      navigateTo("/UI/CreateChallenge")

startFidget(
  figmaUrl = "https://www.figma.com/file/HGzoJxEV1CemjT9TgUvbud",
  windowTitle = "Istrolid",
  entryFrame = "/UI/Splash",
  resizable = true
)
