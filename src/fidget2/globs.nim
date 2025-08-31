import
  std/[strutils],
  schema

# Globs are used to match paths in the tree.
# Globs style paths are central to the fidget2 library.
# They sort of resemble unix paths or CSS selectors.

type
  GlobbyError* = object of ValueError

  Glob = seq[string]

proc treeLen*(node: Node): int =
  ## Returns the number of nodes in the tree.
  inc result
  for c in node.children:
    result += c.treeLen()

proc scan*(node: Node): seq[Node] =
  ## Iterates the tree and returns a flat list.
  proc visit(node: Node, list: var seq[Node]) =
    list.add(node)
    for c in node.children:
      c.visit(list)
  for c in node.children:
    c.visit(result)

proc walk*(node: Node): seq[(string, Node)] =
  ## Iterates the tree with paths:Node.
  proc visit(node: Node, list: var seq[(string, Node)], path: string) =
    let path = path & "/" & node.name
    list.add((path, node))
    for c in node.children:
      c.visit(list, path)
  for c in node.children:
    c.visit(result, "")

proc globMatchOne(path, glob: string, pathStart = 0, globStart = 0): bool =
  ## Matches a single entry string to glob.

  proc error(glob: string) =
    raise newException(GlobbyError, "Invalid glob: `" & glob & "`")

  var
    i = pathStart
    j = globStart
  while j < glob.len:
    if glob[j] == '?':
      discard
    elif glob[j] == '*':
      while true:
        if j == glob.len - 1: # At the end
          return true
        elif glob[j + 1] == '*':
          inc j
        else:
          break
      for k in i ..< path.len:
        if globMatchOne(path, glob, k, j + 1):
          i = k - 1
          return true
      return false
    elif glob[j] == '[':
      inc j
      if j < glob.len and glob[j] == ']': error(glob)
      if j + 3 < glob.len and glob[j + 1] == '-' and glob[j + 3] == ']':
        # Do [A-z] style match.
        if path[i].ord < glob[j].ord or path[i].ord > glob[j + 2].ord:
          return false
        j += 3
      else:
        # Do [ABC] style match.
        while true:
          if j >= glob.len: error(glob)
          elif glob[j] == path[i]:
            while glob[j] != ']':
              if j + 1 >= glob.len: error(glob)
              inc j
            break
          elif glob[j] == '[': error(glob)
          elif glob[j] == ']':
            return false
          inc j
    elif i >= path.len:
      return false
    elif glob[j] != path[i]:
      return false
    inc i
    inc j

  if i == path.len and j == glob.len:
    return true

proc globSimplify(globParts: seq[string]): seq[string] =
  ## Simplifies backwards ".." and absolute "//".
  for globPart in globParts:
    if globPart == "..":
      if result.len > 0:
        discard result.pop()
    elif globPart == "":
      result.setLen(0)
    else:
      result.add globPart

proc parseGlob(glob: string): Glob =
  ## Parses a glob string into a glob object.
  glob.split('/').globSimplify()

proc findAll*(node: Node, glob: string): seq[Node] =
  ## Finds all nodes that match a glob.
  let glob = parseGlob(glob)
  if glob.len == 0:
    return

  proc visit(node: Node, list: var seq[Node], glob: Glob, globAt = 0) =
    if glob[globAt] == "**":
      if globAt + 1 == glob.len:
        # "**" at last level means all nodes
        list.add(node)
        for c in node.scan:
          list.add(c)
      else:
        # "**" can patch any tree level, branch out the search!
        node.visit(list, glob, globAt + 1)
        for c in node.children:
          c.visit(list, glob, globAt)
    else:
      if globMatchOne(node.name, glob[globAt]):
        if globAt + 1 == glob.len:
          # Glob end
          list.add(node)
        else:
          # Glob path
          for c in node.children:
            c.visit(list, glob, globAt + 1)

  for c in node.children:
    c.visit(result, glob)

proc find*(node: Node, glob: string): Node =
  ## Finds the first node that matches a glob.
  ## It is not an error for glob to not match any nodes.
  ## But only one node is returned.
  let glob = parseGlob(glob)
  echo "find glob: ", glob
  proc visit(node: Node, one: var Node, glob: Glob, globAt = 0) =
    if globMatchOne(node.name, glob[globAt]):
      echo "checking node: ", node.name
      if glob[globAt] == "**":
        if globAt + 1 == glob.len:
          # "**" at last level means this node.
          one = node
        else:
          # "**" can patch any tree level, branch out the search!
          node.visit(one, glob, globAt + 1)
          if one != nil:
            return
          for c in node.children:
            c.visit(one, glob, globAt)
            if one != nil:
              return
      else:
        if globAt + 1 == glob.len:
          # Glob end
          echo "glob end: ", node.name
          one = node
        else:
          # Glob path
          for c in node.children:
            c.visit(one, glob, globAt + 1)
            if one != nil:
              return

  for c in node.children:
    c.visit(result, glob)
