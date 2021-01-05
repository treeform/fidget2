import chroma, chrono, fidget2

type
  FlightType = enum
    ftReturn, ftOneWay

var
  flightType = ftOneWay
  departStr = "02.09.2021"
  departCal: Calendar
  returnStr = "03.09.2021"
  returnCal: Calendar

proc setVariant(node: Node, name, value: string) =
  if name == "State":
    if value == "Default":
      node.fills[0].color = parseHtmlColor("#FFFFFF")
    elif value == "Error":
      node.fills[0].color = parseHtmlColor("#FFDAC5")

find "BookingFrame":

  find "Picker":
    find "Return":
      onClick:
        if find("/BookingFrame/Picker").visible:
          flightType = ftReturn
          find("..").visible = false
    find "OneWay":
      onClick:
        if find("/BookingFrame/Picker").visible:
          flightType = ftOneWay
          find("..").visible = false

  find "Inner":
    find "FlightType":
      find "text":
        onDisplay:
          if flightType == ftOneWay:
            thisNode.characters = "one-way flight"
          else:
            thisNode.characters = "return flight"
      onClick:
        find("/BookingFrame/Picker").visible = true

    find "DepartInput":
      find "text":
        onEdit:
          departStr = thisNode.characters
          try:
            departCal = parseCalendar("{day/2}.{month/2}.{year/4}", departStr)
            find("../bg").setVariant("State", "Default")
          except ValueError:
            find("../bg").setVariant("State", "Error")

    find "ReturnInput":
      find "text":
        onEdit:
          returnStr = thisNode.characters
          try:
            returnCal = parseCalendar("{day/2}.{month/2}.{year/4}", returnStr)
            find("../bg").setVariant("State", "Default")
          except ValueError:
            find("../bg").setVariant("State", "Error")

    find "BookButton":
      onClick:
        echo "book: ", flightType
        echo "depart: ", departCal
        if flightType == ftReturn:
          echo "return:", returnCal

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Booking",
  entryFrame = "BookingFrame",
  resizable = false
)
