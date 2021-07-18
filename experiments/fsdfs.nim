

proc onClick() {.find:"**/Xsdfsdf".}:
    count += 1
    print(count)
    find("../CounterDisplay/text").text = str(count)


# find("**/Xsdfsdf").onClick proc (node):
#     count += 1
#     print(count)
#     find("../CounterDisplay/text").text = str(count)


find("**/Xsdfsdf"):
  proc onClick(node: Node):
  #onClick:
    count += 1
    print(count)
    find("../CounterDis")



onClick("**/Xsdfsdf"):
  count += 1
  print(count)
  find("../CounterDis")


onClick("**/Xsdfsdf") = proc (node: Node) =
  count += 1
  print(count)
  find("../CounterDis
