from std/os import getEnv
from std/strutils import parseUInt
import std/asynchttpserver
import std/asyncdispatch

proc handle_req(req: Request) {.async.} =
  echo (req.reqMethod, req.url, req.headers)
  let headers = {"Content-type": "text/plain; charset=utf-8"}
  await req.respond(Http200, "Hello, World!", headers.newHttpHeaders())

proc main {.async.} =
  let server = newAsyncHttpServer()
  let port = Port(parseUInt(getEnv("PORT", "0")))
  server.listen(port)
  echo "server running on localhost:" & $server.getPort.uint16 & "/"
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(handle_req)
    else:
      await sleepAsync(500)

waitFor main()
