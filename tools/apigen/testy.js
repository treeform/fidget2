var ffi = require('ffi-napi');
var Struct = require("ref-struct-napi");

exports.cb = function(f){return ffi.Callback('void', [], f)};

var Vector2 = Struct({
  'x': 'float',
  'y': 'float'});
var Address = Struct({
  'state': 'int64',
  'zip': 'int64'});
var Contact = Struct({
  'firstName': 'int64',
  'lastName': 'int64',
  'address': object
  state
  zip
});
var Fod = Struct({'nimRef': 'pointer'});
var Boz = Struct({'nimRef': 'pointer'});
AlignSomething = 'int64'
exports.AS_DEFAULT = 0
exports.AS_TOP = 1
exports.AS_BOTTOM = 2
exports.AS_RIGHT = 3
exports.AS_LEFT = 4

TextCase = 'int64'
exports.TC_NORMAL = 0
exports.TC_UPPER = 1
exports.TC_LOWER = 2
exports.TC_TITLE = 3

PaintKind = 'int64'
exports.PK_SOLID = 0
exports.PK_IMAGE = 1
exports.PK_IMAGE_TILED = 2
exports.PK_GRADIENT_LINEAR = 3
exports.PK_GRADIENT_RADIAL = 4
exports.PK_GRADIENT_ANGULAR = 5

BlendMode = 'int64'
exports.BM_NORMAL = 0
exports.BM_DARKEN = 1
exports.BM_MULTIPLY = 2
exports.BM_COLOR_BURN = 3
exports.BM_LIGHTEN = 4
exports.BM_SCREEN = 5
exports.BM_COLOR_DODGE = 6
exports.BM_OVERLAY = 7
exports.BM_SOFT_LIGHT = 8
exports.BM_HARD_LIGHT = 9
exports.BM_DIFFERENCE = 10
exports.BM_EXCLUSION = 11
exports.BM_HUE = 12
exports.BM_SATURATION = 13
exports.BM_COLOR = 14
exports.BM_LUMINOSITY = 15
exports.BM_MASK = 16
exports.BM_OVERWRITE = 17
exports.BM_SUBTRACT_MASK = 18
exports.BM_EXCLUDE_MASK = 19

var ColorRGBX = Struct({
  'r': 'uint8',
  'g': 'uint8',
  'b': 'uint8',
  'a': 'uint8'});
var ColorStop2 = Struct({
  'color': object
  r
  g
  b
  a
,
  'position': 'float'});
var Paint2 = Struct({
  'kind': enum
  pkSolid, pkImage, pkImageTiled, pkGradientLinear, pkGradientRadial,
  pkGradientAngular,
  'blendMode': enum
  bmNormal, bmDarken, bmMultiply, bmColorBurn, bmLighten, bmScreen,
  bmColorDodge, bmOverlay, bmSoftLight, bmHardLight, bmDifference, bmExclusion,
  bmHue, bmSaturation, bmColor, bmLuminosity, bmMask, bmOverwrite,
  bmSubtractMask, bmExcludeMask,
  'gradientStops': ColorStop2});
var Typeface2 = Struct({'nimRef': 'pointer'});
var Font2 = Struct({'nimRef': 'pointer'});

var dllPath = ""
if(process.platform == "win32") {
  dllPath = 'fidget.dll'
} else if (process.platform == "darwin") {
  dllPath = __dirname + '/libfidget.dylib'
} else {
  dllPath = __dirname + '/libfidget.so'
}

var fidget = ffi.Library(dllPath, {
  'fidget_input_code': ['bool', ['int64', 'int64', 'int64', 'int64']],
  'fidget_test_numbers': ['bool', ['int8', 'uint8', 'int16', 'uint16', 'int32', 'uint32', 'int64', 'uint64', 'int64', 'uint64', 'float', 'double', 'double']],
  'fidget_call_me_maybe': ['void', ['string']],
  'fidget_flight_club_rule': ['string', ['int64']],
  'fidget_cat_str': ['string', ['string', 'string', 'string', 'string', 'string']],
  'fidget_give_vec': ['void', [Vector2]],
  'fidget_take_vec': [Vector2, []],
  'fidget_take_contact': [Contact, []],
  'fidget_fod_get_name': ['string', [Fod]],
  'fidget_fod_set_name': ['void', [Fod, 'string']],
  'fidget_fod_get_count': ['int64', [Fod]],
  'fidget_fod_set_count': ['void', [Fod, 'int64']],
  'fidget_take_fod': [Fod, []],
  'fidget_boz_get_name': ['string', [Boz]],
  'fidget_boz_set_name': ['void', [Boz, 'string']],
  'fidget_boz_get_fod': [Fod, [Boz]],
  'fidget_boz_set_fod': ['void', [Boz, Fod]],
  'fidget_take_boz': [Boz, []],
  'fidget_repeat_enum': [AlignSomething, [AlignSomething]],
  'fidget_call_me_back': ['void', ['pointer']],
  'fidget_take_seq': [uint64, []],
  'fidget_give_seq': ['void', [uint64]],
  'fidget_give_seq_of_vector2': ['void', [Vector2]],
  'fidget_take_seq_of_vector2': [Vector2, []],
  'fidget_give_seq_of_boz': ['void', [Boz]],
  'fidget_take_seq_of_boz': [Boz, []],
  'fidget_typeface2_get_file_path': ['string', [Typeface2]],
  'fidget_typeface2_set_file_path': ['void', [Typeface2, 'string']],
  'fidget_font2_get_typeface': [Typeface2, [Font2]],
  'fidget_font2_set_typeface': ['void', [Font2, Typeface2]],
  'fidget_font2_get_size': ['float', [Font2]],
  'fidget_font2_set_size': ['void', [Font2, 'float']],
  'fidget_font2_get_line_height': ['float', [Font2]],
  'fidget_font2_set_line_height': ['void', [Font2, 'float']],
  'fidget_font2_get_paint': [object
  kind
  blendMode
  gradientStops
, [Font2]],
  'fidget_font2_set_paint': ['void', [Font2, object
  kind
  blendMode
  gradientStops
]],
  'fidget_font2_get_text_case': [enum
  tcNormal, tcUpper, tcLower, tcTitle, [Font2]],
  'fidget_font2_set_text_case': ['void', [Font2, enum
  tcNormal, tcUpper, tcLower, tcTitle]],
  'fidget_font2_get_underline': ['bool', [Font2]],
  'fidget_font2_set_underline': ['void', [Font2, 'bool']],
  'fidget_font2_get_strikethrough': ['bool', [Font2]],
  'fidget_font2_set_strikethrough': ['void', [Font2, 'bool']],
  'fidget_font2_get_no_kerning_adjustments': ['bool', [Font2]],
  'fidget_font2_set_no_kerning_adjustments': ['void', [Font2, 'bool']],
  'fidget_read_font2': [Font2, ['string']],
});

exports.inputCode = fidget.fidget_input_code;
exports.testNumbers = fidget.fidget_test_numbers;
exports.callMeMaybe = fidget.fidget_call_me_maybe;
exports.flightClubRule = fidget.fidget_flight_club_rule;
exports.catStr = fidget.fidget_cat_str;
exports.Vector2 = Vector2;
exports.giveVec = fidget.fidget_give_vec;
exports.takeVec = fidget.fidget_take_vec;
exports.Address = Address;
exports.Contact = Contact;
exports.takeContact = fidget.fidget_take_contact;
exports.Fod = Fod;
Object.defineProperty(Fod.prototype, 'name', {
  get: function() {return fidget.fidget_fod_get_name(this)},
  set: function(v) {fidget.fidget_fod_set_name(this, v)}
});
Object.defineProperty(Fod.prototype, 'count', {
  get: function() {return fidget.fidget_fod_get_count(this)},
  set: function(v) {fidget.fidget_fod_set_count(this, v)}
});
exports.takeFod = fidget.fidget_take_fod;
exports.Boz = Boz;
Object.defineProperty(Boz.prototype, 'name', {
  get: function() {return fidget.fidget_boz_get_name(this)},
  set: function(v) {fidget.fidget_boz_set_name(this, v)}
});
Object.defineProperty(Boz.prototype, 'fod', {
  get: function() {return fidget.fidget_boz_get_fod(this)},
  set: function(v) {fidget.fidget_boz_set_fod(this, v)}
});
exports.takeBoz = fidget.fidget_take_boz;
exports.repeatEnum = fidget.fidget_repeat_enum;
exports.callMeBack = fidget.fidget_call_me_back;
exports.takeSeq = fidget.fidget_take_seq;
exports.giveSeq = fidget.fidget_give_seq;
exports.giveSeqOfVector2 = fidget.fidget_give_seq_of_vector2;
exports.takeSeqOfVector2 = fidget.fidget_take_seq_of_vector2;
exports.giveSeqOfBoz = fidget.fidget_give_seq_of_boz;
exports.takeSeqOfBoz = fidget.fidget_take_seq_of_boz;
exports.ColorRGBX = ColorRGBX;
exports.ColorStop2 = ColorStop2;
exports.Paint2 = Paint2;
exports.Typeface2 = Typeface2;
Object.defineProperty(Typeface2.prototype, 'filePath', {
  get: function() {return fidget.fidget_typeface2_get_file_path(this)},
  set: function(v) {fidget.fidget_typeface2_set_file_path(this, v)}
});
exports.Font2 = Font2;
Object.defineProperty(Font2.prototype, 'typeface', {
  get: function() {return fidget.fidget_font2_get_typeface(this)},
  set: function(v) {fidget.fidget_font2_set_typeface(this, v)}
});
Object.defineProperty(Font2.prototype, 'size', {
  get: function() {return fidget.fidget_font2_get_size(this)},
  set: function(v) {fidget.fidget_font2_set_size(this, v)}
});
Object.defineProperty(Font2.prototype, 'lineHeight', {
  get: function() {return fidget.fidget_font2_get_line_height(this)},
  set: function(v) {fidget.fidget_font2_set_line_height(this, v)}
});
Object.defineProperty(Font2.prototype, 'paint', {
  get: function() {return fidget.fidget_font2_get_paint(this)},
  set: function(v) {fidget.fidget_font2_set_paint(this, v)}
});
Object.defineProperty(Font2.prototype, 'textCase', {
  get: function() {return fidget.fidget_font2_get_text_case(this)},
  set: function(v) {fidget.fidget_font2_set_text_case(this, v)}
});
Object.defineProperty(Font2.prototype, 'underline', {
  get: function() {return fidget.fidget_font2_get_underline(this)},
  set: function(v) {fidget.fidget_font2_set_underline(this, v)}
});
Object.defineProperty(Font2.prototype, 'strikethrough', {
  get: function() {return fidget.fidget_font2_get_strikethrough(this)},
  set: function(v) {fidget.fidget_font2_set_strikethrough(this, v)}
});
Object.defineProperty(Font2.prototype, 'noKerningAdjustments', {
  get: function() {return fidget.fidget_font2_get_no_kerning_adjustments(this)},
  set: function(v) {fidget.fidget_font2_set_no_kerning_adjustments(this, v)}
});
exports.readFont2 = fidget.fidget_read_font2;
