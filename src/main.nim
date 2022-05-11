from htmlgen import nil
from os import getEnv
from strutils import parseUInt
import asynchttpserver
import asyncdispatch
from xmltree import escape

type Todo = tuple[desc: string, done: bool]

proc render_todo(todo: Todo): string =
  htmlgen.li(escape(todo.desc))

proc render_todos(todos: seq[Todo]): string =
  var todoHtml = "";
  for todo in todos: todoHtml.add(render_todo(todo))
  "<! DOCTYPE html>" &
  htmlgen.html(
    htmlgen.head(
      htmlgen.title("todo")
    ),
    htmlgen.body(
      htmlgen.h1("todo"),
      htmlgen.ul(todoHtml)
    )
  )

proc read_todos(): seq[Todo] {.raises: [IOError].} =
  let path = getEnv("TODO_TXT_PATH")
  let file = open(path)
  defer: file.close()
  var todos: seq[Todo] = @[]
  var line = ""
  while file.readLine(line):
    if line[0..1] == "x ":
      todos.add((desc: line[2..^1], done: true))
    else:
      todos.add((desc: line, done: false))
  todos

proc log_error() =
  let msg = getcurrentExceptionMsg()
  echo "Got exception: ", msg

proc handle_req(req: Request): (HttpCode, string) {.raises: [].} =
  case req.url.path:
    of "/":
      if req.reqMethod != HttpGet:
        (Http405, "")
      else:
        let todos =
          try:
            read_todos()
          except:
            log_error()
            return (Http500, "")
        (Http200, render_todos(todos))
    else:
      (Http404, "")

proc main {.async.} =
  let server = newAsyncHttpServer()
  let port = Port(parseUInt(getEnv("PORT", "0")))
  server.listen(port)
  echo "server running on localhost:" & $server.getPort.uint16 & "/"
  proc cb(req: Request) {.async.} =
    let (status, response) = handle_req(req)
    let headers = {"Content-type": "text/html; charset=utf-8"}
    try:
      return req.respond(status, response, headers.newHttpHeaders())
    except Exception:
      log_error()
  while true:
    if server.shouldAcceptRequest():
      await server.acceptRequest(cb)
    else:
      await sleepAsync(500)

waitFor main()
