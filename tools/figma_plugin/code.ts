var text = ""
function isObject(obj) {
  return obj === Object(obj);
}
function isFunction(functionToCheck) {
  return functionToCheck && {}.toString.call(functionToCheck) === '[object Function]';
}
function isString(obj) {
  return typeof obj === 'string' || obj instanceof String
}
function visit(obj) {
  if (isString(obj) || obj === null) {
    text += JSON.stringify(obj)
  } else if (typeof obj.length !== "undefined") {
    text += "["
    for(var i = 0; i < obj.length; i ++){
      if (i != 0) text += ", "
      visit(obj[i])
    }
    text += "]"
  } else if (isFunction(obj)) {
    text += "-->"
    visit(obj())
  } else if(isObject(obj)) {
    text += "{"
    var keys = Object.keys(Object.getPrototypeOf(obj))
    if (keys.length == 0){
      var keys = Object.keys(obj)
    }
    var i = 0
    for(const k of keys){
      if (k == "parent") continue
      if (i != 0) text += ", "
      text += JSON.stringify(k)
      text += ": "
      visit(obj[k])
      i ++
    }
    text += "}"
  } else {
    text += JSON.stringify(obj)
  }
}
visit(figma.root)

figma.showUI(`
<script>
var xhttp = new XMLHttpRequest();
xhttp.open("POST", "http://localhost:9080/", true);
xhttp.setRequestHeader("Content-type", "application/json");
xhttp.send('${text}');
</script>
<span style="white-space:pre-wrap;font-family:monospace">posting...</span>
`, { width: 500, height: 600 });
