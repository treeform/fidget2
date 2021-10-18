import fidget2, strutils, sequtils

type
  SymbolKind = enum
    Operator
    Number

  Symbol = object
    kind: SymbolKind
    number: string
    operator: string

var
  symbols: seq[Symbol] ## List of currently entered symbols.
  repeat: seq[Symbol] ## Used to repeat prev operation

proc inNumber() =
  ## Entering a number, make sure everything is setup for it.
  ## It always makes sense to enter in a number.
  if symbols.len == 0 or symbols[^1].kind == Operator:
    symbols.add(Symbol(kind:Number))

proc inOperator(): bool =
  ## Entering operator, make sure everything is setup for it.
  ## Returns true if operator now makes sense.
  if symbols.len == 0:
    return false
  if symbols[^1].kind == Number:
    if symbols[^1].number == "-":
      return false
    symbols.add(Symbol(kind:Operator))
  return true

proc fromFloat(number: float): string =
  ## Formats number as float or integer.
  result = $number
  result.removeSuffix(".0")

proc toFloat(s: string): float =
  ## Parses floats without errors.
  try:
    parseFloat(s)
  except ValueError:
    0

proc compute() =
  ## Compute current symbols and produce an answer (also a symbol).

  if symbols.len > 2:
    # If there is more then 2 symbols remember the last operation.
    repeat = symbols[^2 .. ^1]

  if symbols.len == 0:
    return
  if symbols.len == 1:
    # If there is only 1 symbol, repeat previous operation.
    symbols.add repeat
  if symbols[^1].kind == Operator:
    # Not complete.
    return

  var i: int # Used to count where we are in the symbols array.

  proc left(): float =
    ## Grabs the left parameter for the operation.
    toFloat(symbols[i-1].number)

  proc right(): float =
    ## Grabs the right parameter for the operation.
    toFloat(symbols[i+1].number)

  proc operate(number: float) =
    ## Saves the operation back as a symbol.
    symbols[i-1].number = fromFloat(number)
    symbols.delete(i, i+1)
    dec i

  # Runs the symbols, × and ÷ first then + and -.
  i = 0
  while i < symbols.len:
    let t = symbols[i]
    if t.operator == "×": operate left() * right()
    if t.operator == "÷": operate left() / right()
    inc i
  i = 0
  while i < symbols.len:
    let t = symbols[i]
    if t.operator == "+": operate left() + right()
    if t.operator == "-": operate left() - right()
    inc i

find "/UI/Main":

  find "Button?":
    # Selects all buttons: Button0 - Button9
    onClick:
      inNumber()
      symbols[^1].number.add(thisNode.name[^1])

  find "ButtonPeriod":
    onClick:
      inNumber()
      if "." notin symbols[^1].number:
        symbols[^1].number.add(".")

  find "ButtonAdd":
    onClick:
      if inOperator():
        symbols[^1].operator = "+"

  find "ButtonSubtract":
    onClick:
      # Subtract can be an operator or start of a number
      if inOperator():
        symbols[^1].operator = "-"
      else:
        inNumber()
        if symbols.len > 0 and symbols[^1].number == "":
          symbols[^1].number = "-"

  find "ButtonMultiply":
    onClick:
      if inOperator():
        symbols[^1].operator = "×"

  find "ButtonDivide":
    onClick:
      if inOperator():
        symbols[^1].operator = "÷"

  find "ButtonClear":
    onClick:
      if symbols.len > 0:
        # Clear only clears the last symbol.
        repeat.setLen(0)
        symbols.setLen(symbols.len - 1)

  find "ButtonEquals":
    onClick:
      compute()

  find "ButtonPercentage":
    onClick:
      if symbols.len > 0 and symbols[^1].kind == Number:
        var number = toFloat(symbols[^1].number)
        symbols[^1].number = fromFloat(number / 100)

  find "ButtonPlusMinus":
    onClick:
      if symbols.len > 0 and symbols[^1].kind == Number:
        var number = toFloat(symbols[^1].number)
        symbols[^1].number = fromFloat(number / -1)

  find "Display":
    onDisplay:
      var formula = ""
      for t in symbols:
        formula.add(t.number)
        formula.add(t.operator)
      # Fix negative numbers: [a][-][-b] and [a][+][-b]
      formula = formula.replace("--", "+").replace("+-", "-")
      thisNode.setText(formula)

startFidget(
  figmaUrl = "https://www.figma.com/file/0R8RlgLgwX8R7cG7FczrHO",
  windowTitle = "Neumorphic Calculator",
  entryFrame = "UI/Main",
  resizable = false
)
