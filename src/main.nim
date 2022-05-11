from std/base64 import nil
from std/uri import decodeQuery
from std/htmlgen import nil
from std/os import getEnv
from std/strutils import parseUInt
import std/asynchttpserver
import std/asyncdispatch
from std/xmltree import escape

type Todo = tuple[desc: string, done: bool]

proc render_todo(todo: Todo): string =
  let id = base64.encode(todo.desc);
  let input =
    if todo.done:
        htmlgen.input(type = "checkbox", checked = "", value = id)
      else:
        htmlgen.input(type = "checkbox", value = id)
  htmlgen.li(
    htmlgen.label(
      input,
      escape(todo.desc)
    )
  )

proc render_page(todos: seq[Todo]): string =
  var todoHtml = "";
  for todo in todos: todoHtml.add(render_todo(todo))
  "<! DOCTYPE html>" &
  htmlgen.html(
    htmlgen.head(
      htmlgen.title("todo")
    ),
    htmlgen.body(
      htmlgen.h1("todo"),
      htmlgen.form(
        `method` = "post",
        htmlgen.input(type = "text", name = "desc", id = "desc"),
        htmlgen.input(type = "submit", value = "add")
      ),
      htmlgen.ul(todoHtml)
    )
  )

proc read_todos(): seq[Todo] {.raises: [IOError].} =
  let path = getEnv("TODO_TXT_PATH")
  let file = open(path, fmRead)
  defer: close(file)
  var todos: seq[Todo] = @[]
  var line = ""
  while file.readLine(line):
    if line[0..1] == "x ":
      todos.add((desc: line[2..^1], done: true))
    else:
      todos.add((desc: line, done: false))
  todos

proc write_todos(todos: seq[Todo]) {.raises: [IOError].} =
  let path = getEnv("TODO_TXT_PATH")
  let file = open(path, fmWrite)
  defer: close(file)
  for todo in todos:
    if todo.done: file.write("x ")
    file.writeLine(todo.desc)

proc add_todo(new_todo: Todo): seq[Todo] {.raises: [IOError].} =
  var todos = read_todos()
  if new_todo notin todos: todos.add(new_todo)
  write_todos(todos)
  todos

proc log_error() =
  let msg = getcurrentExceptionMsg()
  echo "Got exception: ", msg

proc handle_req(req: Request): (HttpCode, string) {.raises: [].} =
  case req.url.path:
    of "/":
      case req.reqMethod:
        of HttpGet:
          let todos =
            try: read_todos()
            except IOError:
              log_error()
              return (Http500, "")
          (Http200, render_page(todos))
        of HttpPost:
          for (key, value) in decodeQuery(req.body):
            if key == "desc":
              let todos =
                try:
                  add_todo((desc: value, done: false))
                except IOError:
                  log_error()
                  return (Http500, "")
              return (Http200, render_page(todos))
          (Http400, "")
        else:
          (Http405, "")
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
