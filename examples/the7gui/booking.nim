import chroma, chrono, fidget2

type
  FlightType = enum
    ReturnFlight, OneWayFlight

var
  flightType = OneWayFlight
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
    elif value == "Disabled":
      node.fills[0].color = parseHtmlColor("#B7B7B7")

find "/UI/BookingFrame":

  find "Picker":
    find "Return":
      onClick:
        if find("/UI/BookingFrame/Picker").visible:
          flightType = ReturnFlight
          find("/UI/BookingFrame/Picker").visible = false

          var n = find("/UI/BookingFrame/Inner/ReturnInput/bg")
          n.setVariant("State", "Default")

    find "OneWay":
      onClick:
        if find("/UI/BookingFrame/Picker").visible:
          flightType = OneWayFlight
          find("/UI/BookingFrame/Picker").visible = false

          var n = find("/UI/BookingFrame/Inner/ReturnInput/bg")
          n.setVariant("State", "Disabled")

  find "Inner":
    find "FlightType":
      find "text":
        onDisplay:
          if flightType == OneWayFlight:
            thisNode.characters = "one-way flight"
          else:
            thisNode.characters = "return flight"
      onClick:
        find("/UI/BookingFrame/Picker").visible = true

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
        if flightType == ReturnFlight:
          echo "return:", returnCal

startFidget(
  figmaUrl = "https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa",
  windowTitle = "Booking",
  entryFrame = "/UI/BookingFrame",
  windowStyle = Decorated
)
