import fidget2, strutils, sequtils

type
  TermKind = enum
    Operator
    Number

  Term = object
    kind: TermKind
    number: string
    operator: string

var
  terms: seq[Term] ## List of currently entered terms.
  repeat: seq[Term] ## Used to repeat prev operation

proc inNumber() =
  ## Entering a number, make sure everything is setup for it.
  ## It always makes sense to enter in a number.
  if terms.len == 0 or terms[^1].kind == Operator:
    terms.add(Term(kind:Number))

proc inOperator(): bool =
  ## Entering operator, make sure everything is setup for it.
  ## Returns true if operator now makes sense.
  if terms.len == 0:
    return false
  if terms[^1].kind == Number:
    if terms[^1].number == "-":
      return false
    terms.add(Term(kind:Operator))
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
  ## Compute current terms and produce an answer (also a term).

  if terms.len > 2:
    # If there is more then 2 terms remember the last operation.
    repeat = terms[^2 .. ^1]

  if terms.len == 0:
    return
  if terms.len == 1:
    # If there is only 1 term, repeat previous operation.
    terms.add repeat
  if terms[^1].kind == Operator:
    # Not complete.
    return

  var i: int # Used to count where we are in the terms array.

  proc left(): float =
    ## Grabs the left parameter for the operation.
    toFloat(terms[i-1].number)

  proc right(): float =
    ## Grabs the right parameter for the operation.
    toFloat(terms[i+1].number)

  proc operate(number: float) =
    ## Saves the operation back as a term.
    terms[i-1].number = fromFloat(number)
    terms.delete(i, i+1)
    dec i

  # Runs the terms, × and ÷ first then + and -.
  i = 0
  while i < terms.len:
    let t = terms[i]
    if t.operator == "×": operate left() * right()
    if t.operator == "÷": operate left() / right()
    inc i
  i = 0
  while i < terms.len:
    let t = terms[i]
    if t.operator == "+": operate left() + right()
    if t.operator == "-": operate left() - right()
    inc i

find "/UI/Main":

  find "Button?":
    # Selects all buttons: Button0 - Button9
    onClick:
      inNumber()
      terms[^1].number.add(thisNode.name[^1])

  find "ButtonPeriod":
    onClick:
      inNumber()
      if "." notin terms[^1].number:
        terms[^1].number.add(".")

  find "ButtonAdd":
    onClick:
      if inOperator():
        terms[^1].operator = "+"

  find "ButtonSubtract":
    onClick:
      # Subtract can be an operator or start of a number
      if inOperator():
        terms[^1].operator = "-"
      else:
        inNumber()
        if terms.len > 0 and terms[^1].number == "":
          terms[^1].number = "-"

  find "ButtonMultiply":
    onClick:
      if inOperator():
        terms[^1].operator = "×"

  find "ButtonDivide":
    onClick:
      if inOperator():
        terms[^1].operator = "÷"

  find "ButtonClear":
    onClick:
      if terms.len > 0:
        # Clear only clears the last term.
        repeat.setLen(0)
        terms.setLen(terms.len - 1)

  find "ButtonEquals":
    onClick:
      compute()

  find "ButtonPercentage":
    onClick:
      if terms.len > 0 and terms[^1].kind == Number:
        var number = toFloat(terms[^1].number)
        terms[^1].number = fromFloat(number / 100)

  find "ButtonPlusMinus":
    onClick:
      if terms.len > 0 and terms[^1].kind == Number:
        var number = toFloat(terms[^1].number)
        terms[^1].number = fromFloat(number / -1)

  find "Display":
    onDisplay:
      var formula = ""
      for t in terms:
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
