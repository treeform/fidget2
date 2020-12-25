import fidget2, strutils, chroma, strformat, chrono

use("https://www.figma.com/file/Km8Hvdw4wZwEk6L1bN4RLa")

# type
#   InputState = enum
#     isEmpty, isNumber, isError

# var
#   # TODO empty state?
#   celsiusState = isEmpty
#   celsius = 0.0
#   fahrenheitState = isEmpty
#   fahrenheit = 0.0

# onDisplay "CelsiusInput/text":
#   if celsiusState == isEmpty:
#     thisNode.characters = ""
#   elif celsiusState == isNumber:
#     thisNode.characters = &"{celsius:0.2f}"
# onDisplay "CelsiusInput/bg":
#   if celsiusState == isError:
#     thisNode.fills[0].color = parseHtmlColor("#FFDAC5")
#   else:
#     thisNode.fills[0].color = parseHtmlColor("#FFFFFF")
# onFocus "CelsiusInput/text":
#   textBox.endOfLine()
# onEdit "CelsiusInput/text":
#   if thisNode.characters == "":
#     celsiusState = isEmpty
#   else:
#     try:
#       celsius = parseFloat(thisNode.characters)
#       celsiusState = isNumber
#     except ValueError:
#       celsiusState = isError
#     fahrenheit = celsius * (9/5) + 32.0
#     fahrenheitState = isNumber

# onDisplay "FahrenheitInput/text":
#   if fahrenheitState == isEmpty:
#     thisNode.characters = ""
#   elif fahrenheitState == isNumber:
#     thisNode.characters = &"{fahrenheit:0.2f}"
# onDisplay "FahrenheitInput/bg":
#   if fahrenheitState == isError:
#     thisNode.fills[0].color = parseHtmlColor("#FFDAC5")
#   else:
#     thisNode.fills[0].color = parseHtmlColor("#FFFFFF")
# onFocus "FahrenheitInput/text":
#   textBox.endOfLine()
# onEdit "FahrenheitInput/text":
#   if thisNode.characters == "":
#     fahrenheitState = isEmpty
#   else:
#     try:
#       fahrenheit = parseFloat(thisNode.characters)
#       fahrenheitState = isNumber
#     except ValueError:
#       fahrenheitState = isError
#     celsius = (fahrenheit - 32.0) * (5/9)
#     celsiusState = isNumber

type
  FlightType = enum
    ftReturn, ftOneWay

var
  flightType = ftOneWay
  departStr = "02.09.2021"
  departCal: Calendar
  returnStr = "03.09.2021"
  returnCal: Calendar

onDisplay "**/FlightType/text":
  if flightType == ftOneWay:
    thisNode.characters = "one-way flight"
  else:
    thisNode.characters = "return flight"
onClick "**/FlightType":
  echo thisNode.name
  find("**/Picker").visible = true
  discard

onClick "**/Return":
  flightType = ftReturn
  find("**/Picker").visible = false
onClick "**/OneWay":
  flightType = ftOneWay
  find("**/Picker").visible = false

onFocus "**/DepartInput/text":
  textBox.endOfLine()
onDisplay "**/DepartInput/text":
  thisNode.characters = departStr
onEdit "**/DepartInput/text":
  departStr = textBox.text
  try:
    departCal = parseCalendar("{day/2}.{month/2}.{year/4}", departStr)
    find("**/DepartInput/bg").fills[0].color = parseHtmlColor("#FFFFFF")
  except ValueError:
    find("**/DepartInput/bg").fills[0].color = parseHtmlColor("#FFDAC5")

onFocus "**/ReturnInput/text":
  textBox.endOfLine()
onDisplay "**/ReturnInput/text":
  thisNode.characters = returnStr
onEdit "**/ReturnInput/text":
  if flightType != ftReturn:
    # TODO: unfocus node
    return
  returnStr = textBox.text
  try:
    returnCal = parseCalendar("{day/2}.{month/2}.{year/4}", returnStr)
    find("**/ReturnInput/bg").fills[0].color = parseHtmlColor("#FFFFFF")
  except ValueError:
    find("**/ReturnInput/bg").fills[0].color = parseHtmlColor("#FFDAC5")


onClick "**/BookButton":
  echo "book: ", flightType
  echo "depart: ", departCal
  if flightType == ftReturn:
     echo "return:", returnCal

startFidget(
  windowTitle = "Booking",
  entryFrame = "Booking",
  resizable = false
)
