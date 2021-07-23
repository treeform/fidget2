var ffi = require('ffi-napi');
var Struct = require("ref-struct-napi");

exports.cb = function(f){return ffi.Callback('void', [], f)};

var Fod = Struct({'nimRef': 'pointer'});
var Vector2 = Struct({
  'x': 'float',
  'y': 'float'});
AlignSomething = 'int64'
exports.AS_DEFAULT = 0
exports.AS_TOP = 1
exports.AS_BOTTOM = 2
exports.AS_RIGHT = 3
exports.AS_LEFT = 4

var Node = Struct({'nimRef': 'pointer'});

var dllPath = ""
if(process.platform == "win32") {
  dllPath = 'fidget.dll'
} else if (process.platform == "darwin") {
  dllPath = 'libfidget.dylib'
} else {
  dllPath = __dirname + '/libfidget.so'
}

var fidget = ffi.Library(dllPath, {
  'fidget_call_me_maybe': ['void', ['string']],
  'fidget_flight_club_rule': ['string', ['int64']],
  'fidget_input_code': ['bool', ['int64', 'int64', 'int64', 'int64']],
  'fidget_test_numbers': ['bool', ['int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64', 'int64', 'uint64', 'float', 'double', 'double']],
  'fidget_fod_get_name': ['string', [Fod]],
  'fidget_fod_set_name': ['void', [Fod, 'string']],
  'fidget_fod_get_count': ['int64', [Fod]],
  'fidget_fod_set_count': ['void', [Fod, 'int64']],
  'fidget_create_fod': [Fod, []],
  'fidget_give_vec': ['void', [Vector2]],
  'fidget_take_vec': [Vector2, []],
  'fidget_repeat_enum': [AlignSomething, [AlignSomething]],
  'fidget_call_me_back': ['void', ['pointer']],
  'fidget_on_click_global': ['void', ['pointer']],
  'fidget_node_get_name': ['string', [Node]],
  'fidget_node_set_name': ['void', [Node, 'string']],
  'fidget_node_get_characters': ['string', [Node]],
  'fidget_node_set_characters': ['void', [Node, 'string']],
  'fidget_node_get_dirty': ['bool', [Node]],
  'fidget_node_set_dirty': ['void', [Node, 'bool']],
  'fidget_find_node': [Node, ['string']],
  'fidget_start_fidget': ['void', ['string', 'string', 'string', 'bool']],
});

exports.callMeMaybe = fidget.fidget_call_me_maybe;
exports.flightClubRule = fidget.fidget_flight_club_rule;
exports.inputCode = fidget.fidget_input_code;
exports.testNumbers = fidget.fidget_test_numbers;
exports.Fod = Fod;
Object.defineProperty(Fod.prototype, 'name', {
  get: function() {return fidget.fidget_fod_get_name(this)},
  set: function(v) {fidget.fidget_fod_set_name(this, v)}
});
Object.defineProperty(Fod.prototype, 'count', {
  get: function() {return fidget.fidget_fod_get_count(this)},
  set: function(v) {fidget.fidget_fod_set_count(this, v)}
});
exports.createFod = fidget.fidget_create_fod;
exports.Vector2 = Vector2;
exports.giveVec = fidget.fidget_give_vec;
exports.takeVec = fidget.fidget_take_vec;
exports.repeatEnum = fidget.fidget_repeat_enum;
exports.callMeBack = fidget.fidget_call_me_back;
exports.onClickGlobal = fidget.fidget_on_click_global;
exports.Node = Node;
Object.defineProperty(Node.prototype, 'name', {
  get: function() {return fidget.fidget_node_get_name(this)},
  set: function(v) {fidget.fidget_node_set_name(this, v)}
});
Object.defineProperty(Node.prototype, 'characters', {
  get: function() {return fidget.fidget_node_get_characters(this)},
  set: function(v) {fidget.fidget_node_set_characters(this, v)}
});
Object.defineProperty(Node.prototype, 'dirty', {
  get: function() {return fidget.fidget_node_get_dirty(this)},
  set: function(v) {fidget.fidget_node_set_dirty(this, v)}
});
exports.findNode = fidget.fidget_find_node;
exports.startFidget = fidget.fidget_start_fidget;
