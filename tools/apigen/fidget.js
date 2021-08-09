var ffi = require('ffi-napi');
var Struct = require("ref-struct-napi");

exports.cb = function(f){return ffi.Callback('void', [], f)};

var Node = Struct({'nimRef': 'pointer'});
EventCbKind = 'int64'
exports.E_ON_CLICK = 0
exports.E_ON_FRAME = 1
exports.E_ON_EDIT = 2
exports.E_ON_DISPLAY = 3
exports.E_ON_FOCUS = 4
exports.E_ON_UNFOCUS = 5


var dllPath = ""
if(process.platform == "win32") {
  dllPath = 'fidget.dll'
} else if (process.platform == "darwin") {
  dllPath = __dirname + '/libfidget.dylib'
} else {
  dllPath = __dirname + '/libfidget.so'
}

var fidget = ffi.Library(dllPath, {
  'fidget_on_click_global': ['void', ['pointer']],
  'fidget_node_get_name': ['string', [Node]],
  'fidget_node_set_name': ['void', [Node, 'string']],
  'fidget_node_get_characters': ['string', [Node]],
  'fidget_node_set_characters': ['void', [Node, 'string']],
  'fidget_node_get_dirty': ['bool', [Node]],
  'fidget_node_set_dirty': ['void', [Node, 'bool']],
  'fidget_find_node': [Node, ['string']],
  'fidget_add_cb': ['void', [EventCbKind, 'int64', 'string', 'pointer']],
  'fidget_start_fidget': ['void', ['string', 'string', 'string', 'bool']],
});

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
exports.addCb = fidget.fidget_add_cb;
exports.startFidget = fidget.fidget_start_fidget;
