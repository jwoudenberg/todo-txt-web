from std/uri import decodeQuery
from std/algorithm import sorted
from std/htmlgen import nil
from std/os import getEnv
from std/strutils import parseUInt
import std/asynchttpserver
import std/asyncdispatch
from std/xmltree import escape

type Todo = tuple[desc: string, done: bool]

type Config = tuple[todo_txt_file: string, port: Port, title: string]

proc read_config(): Config =
  let todo_txt_file = getEnv("TODO_TXT_PATH")
  let port = Port(parseUInt(getEnv("PORT", "0")))
  let title = getEnv("TITLE", "Todo")
  (todo_txt_file, port, title)

proc render_todo(todo: Todo): string =
  let input =
    if todo.done:
        htmlgen.input(
          type = "checkbox",
          checked = "",
          name = "check",
          value = todo.desc,
          id = todo.desc
        )
      else:
        htmlgen.input(
          type = "checkbox",
          name = "check",
          value = todo.desc,
          id = todo.desc
        )
  htmlgen.li(
    htmlgen.form(
      `method` = "post",
      onchange = "event.currentTarget.submit()",
      input,
      htmlgen.label(`for` = todo.desc, escape(todo.desc)),
      htmlgen.input(type = "hidden", name = "uncheck", value = todo.desc)
    )
  )

proc render_page(config: Config, todos: seq[Todo]): string =
  var todoHtml = "";
  const styles = staticRead("styles.css")
  let sorted_todos =
    todos.sorted do (x, y: Todo) -> int:
      cmp(x.done, y.done)
  for todo in sorted_todos: todoHtml.add(render_todo(todo))
  "<! DOCTYPE html>" &
  htmlgen.html(
    htmlgen.head(
      htmlgen.title(config.title)
    ),
    htmlgen.body(
      htmlgen.h1(config.title),
      htmlgen.form(
        id = "new-todo",
        `method` = "post",
        htmlgen.input(type = "text", name = "new", id = "desc")
      ),
      htmlgen.ul(id = "todos", todoHtml),
      htmlgen.style(styles)
    )
  )

proc read_todos(config: Config): seq[Todo] {.raises: [IOError].} =
  let file = open(config.todo_txt_file, fmRead)
  defer: close(file)
  var todos: seq[Todo] = @[]
  var line = ""
  while file.readLine(line):
    if line == "": continue
    if len(line) >= 2 and line[0..1] == "x ":
      todos.add((desc: line[2..^1], done: true))
    else:
      todos.add((desc: line, done: false))
  todos

proc write_todos(config: Config, todos: seq[Todo]) {.raises: [IOError].} =
  let file = open(config.todo_txt_file, fmWrite)
  defer: close(file)
  for todo in todos:
    if todo.done: file.write("x ")
    file.writeLine(todo.desc)

proc add_todo(config: Config, new_todo: Todo): seq[Todo] {.raises: [IOError].} =
  var todos = read_todos(config)
  if (new_todo notin todos) and (new_todo.desc != ""): todos.add(new_todo)
  write_todos(config, todos)
  todos

proc set_todo(config: Config, changed_todo: Todo): seq[Todo] {.raises: [IOError].} =
  var todos = read_todos(config)
  for todo in todos.mitems:
    if todo.desc == changed_todo.desc: todo.done = changed_todo.done
  write_todos(config, todos)
  todos

proc log_error() =
  let msg = getcurrentExceptionMsg()
  echo "Got exception: ", msg

proc handle_req(config: Config, req: Request): (HttpCode, string) {.raises: [].} =
  case req.reqMethod:
    of HttpGet:
      let todos =
        try: read_todos(config)
        except IOError:
          log_error()
          return (Http500, "")
      (Http200, render_page(config, todos))
    of HttpPost:
      for (key, value) in decodeQuery(req.body):
        case key:
          of "new":
            let todos =
              try: add_todo(config, (desc: value, done: false))
              except IOError:
                log_error()
                return (Http500, "")
            return (Http200, render_page(config, todos))
          of "check", "uncheck":
            let todos =
              try: set_todo(config, (desc: value, done: key == "check"))
              except IOError:
                log_error()
                return (Http500, "")
            return (Http200, render_page(config, todos))
      (Http400, "")
    else:
      (Http405, "")

proc main {.async.} =
  let config = read_config()
  let server = newAsyncHttpServer()
  server.listen(config.port)
  echo "server running on localhost:" & $server.getPort.uint16 & "/"
  proc cb(req: Request) {.async.} =
    let (status, response) = handle_req(config, req)
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
