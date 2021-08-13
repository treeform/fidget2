import asynchttpserver, asyncdispatch

proc main {.async.} =
  var server = newAsyncHttpServer()
  proc cb(req: Request) {.async.} =
    echo "here"
    if req.reqMethod == HttpOptions:
      let headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*"
      }
      await req.respond(Http200, "ok", headers.newHttpHeaders())
    else:
      echo req.reqMethod
      echo req.headers
      writeFile("figma.json", req.body)
      let headers = {
        "Date": "Tue, 29 Apr 2014 23:40:08 GMT",
        "Content-type": "text/plain; charset=utf-8",
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "*"
      }
      await req.respond(Http200, "Hello World", headers.newHttpHeaders())

  server.listen Port(9080)
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      poll()

asyncCheck main()
runForever()
