import chrono, fidget2


const
  CalendarFormat = "{day/2}.{month/2}.{year/4}"

type
  FlightType = enum
    ReturnFlight, 
    OneWayFlight

var
  flightType = OneWayFlight
  departCal = Calendar(year: 2026, month: 9, day: 2)
  returnCal = Calendar(year: 2026, month: 9, day: 3)

find "/UI/BookingFrame":

  find "Picker":
    find "Return":
      onClick:
        flightType = ReturnFlight
        thisNode.parent.visible = false
        find("/UI/BookingFrame/Inner/ReturnInput").setVariant("State", "Default")

    find "OneWay":
      onClick:
        flightType = OneWayFlight
        thisNode.parent.visible = false
        find("/UI/BookingFrame/Inner/ReturnInput").setVariant("State", "Disabled")

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
        onShow:
          thisNode.text = departCal.format(CalendarFormat)
        onEdit:
          try:
            departCal = parseCalendar(CalendarFormat, thisNode.text)
            thisNode.parent.setVariant("State", "Default")
            find("/UI/BookingFrame/Inner/BookButton").setVariant("State", "Default")
          except ValueError:
            thisNode.parent.setVariant("State", "Error")
            find("/UI/BookingFrame/Inner/BookButton").setVariant("State", "Disabled")

    find "ReturnInput":
      find "text":
        onShow:
          thisNode.text = returnCal.format(CalendarFormat)
        onEdit:
          try:
            returnCal = parseCalendar(CalendarFormat, thisNode.text)
            thisNode.parent.setVariant("State", "Default")
            find("/UI/BookingFrame/Inner/BookButton").setVariant("State", "Default")
          except ValueError:
            thisNode.parent.setVariant("State", "Error")
            find("/UI/BookingFrame/Inner/BookButton").setVariant("State", "Disabled")

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
