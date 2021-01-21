var ffi = require('ffi');

var fidget = ffi.Library('libfidget', {
    'startFidget': [ 'void', [ 'string', 'string', 'string', 'bool' ] ]
});

fidget.startFidget(
    "https://www.figma.com/file/fn8PBPmPXOHAVn3N5TSTGs",
    "JavaScript Layouts",
    "Layout1",
    true
)
