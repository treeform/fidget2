import macros

macro genDirtyGettersAndSetter*(v: typed) =
  ## Adds getters and setters that mark the .dirty field when set.
  let
    typeDesc = getTypeInst(v)
    sym = typeDesc[^1]
  var
    symImpl = sym.getTypeImpl
  if symImpl.kind == nnkRefTy:
    symImpl = symImpl[0].getTypeImpl

  result = newStmtList()
  for field in symImpl[2]:
    if not field[0].isExported:
      echo "*", field[0].treeRepr
      # only add dirty checking for private fields
      let
        fieldName = newIdentNode($field[0])
        fieldType = field[1]
        nameEq = nnkAccQuoted.newTree(
          fieldName,
          newIdentNode("=")
        )
      result.add quote do:
        proc `nameEq`*(x: var `sym`, v: `fieldType`) =
          # Setters should mark the dirty flag.
          if x.`fieldName` != v:
            x.dirty = true
            x.`fieldName` = v

        proc `fieldName`*(x: `sym`): `fieldType` =
          # Getters do nothing and get compiled out.
          x.`fieldName`
