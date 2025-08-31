import chroma, chrono, fidget2

find "/UI/CrudFrame":

  find "PrefixInput/text":
    onEdit:
      discard

  find "NameInput/text":
    onEdit:
      discard

  find "SurnameInput/text":
    onEdit:
      discard

  find "List/ListItem":
    onClick:
      echo "click item"

  find "Buttons":

      find "Create":
        onClick:
          echo "create"

      find "Update":
        onClick:
          echo "update"

      find "Delete":
        onClick:
          echo "delete"

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Crud",
  entryFrame = "/UI/CrudFrame",
  windowStyle = Decorated
)
