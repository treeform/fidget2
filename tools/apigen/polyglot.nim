import macros, strutils, langauges/internal,
  langauges/c, langauges/python, langauges/ruby, langauges/nim, langauges/javascript

## Generates .h and py files for nim exports

macro exportProc*(def: typed) =
  exportProcH(def)
  exportProcPy(def)
  exportProcJs(def)
  exportProcRuby(def)
  exportProcNim(def)
  exportProcInternal(def)

macro exportRefObject*(def: typed) =
  exportRefObjectH(def)
  exportRefObjectPy(def)
  exportRefObjectJs(def)
  exportRefObjectRuby(def)
  exportRefObjectNim(def)
  exportRefObjectInternal(def)

macro exportObject*(def: typed) =
  exportObjectH(def)
  exportObjectPy(def)
  exportObjectJs(def)
  exportObjectRuby(def)
  exportObjectNim(def)

macro exportSeq*(def: typed) =
  # exportSeqH(def)
  exportSeqPy(def)
  # exportSeqJs(def)
  # exportSeqRuby(def)
  # exportSeqNim(def)
  exportSeqInternal(def)

macro exportEnum*(def: typed) =
  exportEnumH(def)
  exportEnumPy(def)
  exportEnumJs(def)
  exportEnumRuby(def)
  exportEnumNim(def)

macro writeAll*(def: typed) =
  writeH(def.repr)
  writePy(def.repr)
  writeJs(def.repr)
  writeRuby(def.repr)
  writeNim(def.repr)
  writeInternal(def.repr)
