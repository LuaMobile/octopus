-----------------------------------------------------
-- Octopus web server
-- Version 0.1.1
-----------------------------------------------------
local _M = {}
local server, client

-- load required modules
local socket = require("socket")
socket.url = require 'socket.url'
local seawolf = require 'seawolf'.__build('text', 'variable')
local mimetypes = require 'mimetypes'

local explode, unescape = seawolf.text.explode, socket.url.unescape
local empty = seawolf.variable.empty

-- detect operating system
if os.getenv("WinDir") ~= nil then
  _ = "Windows"
else
  _ = "Other OS" -- !
end

-- start web server
function _M.start(arg1)
  local hostname
  local port = arg1 -- set first argument as port

  -- display initial program information
  print 'Octopus web server v0.1.1'

  -- if no port is specified, use port 80
  if port == nil then port = 80 end

  -- create tcp socket on $hostname:$port
  server = assert(socket.tcp())
  hostname = server:getsockname()
  local status, err = server:bind(hostname, port)
  if err then
    print(("Failed to bind to %s:%s. \nERROR: %s"):format(hostname, port, err))
    os.exit(1)
  end

  -- display message to web server is running
  print(("\nRunning on %s:%s"):format(hostname, port))

  -- max connections to queue before start rejecting connections
  server:listen(100)

  waitReceive() -- begin waiting for client requests

  server:close() -- close server
end

-- stop web server
function _M.stop(arg1)
  local hostname
  local port = arg1

  -- if no port is specified, use port 80
  if port == nil then port = 80 end

  -- create tcp client for $hostname:$port
  client = assert(socket.tcp())
  hostname = client:getsockname()
  local status, err = client:connect(hostname, port)
  if err then
    print(("Failed to connect to %s:%s. \nERROR: %s"):format(hostname, port, err))
    os.exit(1)
  end

  print(("\nStopping server at %s:%s"):format(hostname, port))

  -- Send KILL signal
  client:send "KILL\n"
  client:close()
end

-- Adapted from danielrempel's ladleutil.lua
function _M.receive_request(client)
  local buffer = {}
  local line, err = ''
  repeat
    local line, err = client:receive('*l')
    if line
    then
      rawset(buffer, #buffer + 1, line)
    end
  until not line or line:len() == 0 or err
  return table.concat(buffer, "\r\n"), err
end

function _M.parse_query_string(query_string)
  local parsed = {}
  local list = explode('&', query_string or '')
  if list then
    local tmp, key, value
    for _, v in pairs(list) do
      if #v > 0 then
        tmp = explode('=', v)
        key = unescape((tmp[1] or ''):gsub('+', ' '))
        value = unescape((tmp[2] or ''):gsub('+', ' '))
        parsed[key] = value
      end
    end
  end

  return parsed
end

-- Adapted from danielrempel's ladleutil.lua
function _M.parse_request(request)
  local request_table = {}
  local request_text = request

  local line = ""

  local a,b = request_text:find("\r*\n")
  if not a or not b
  then
    print 'Suspicious request:'
    print(request)
    print '======================================================='
    print 'Newlines (\\r\\n) not found'

    return {}
  end

  repeat
    local a,b = request_text:find("\r*\n")
    line = request_text:sub(0,a-1)
    request_text = request_text:sub(b+1)
  until line:len() > 0

  request_table.method, request_table.url, request_table.protocol = line:match("^([^ ]-) +([^ ]-) +([^ ]-)$")

  while request_text:len() > 0 do
    local a,b = request_text:find("\r*\n")
    local line = request_text:sub(0,a-1)
    request_text = request_text:sub(b+1)

    if line:len()>0
    then
      local key, value = line:match("^([^:]*): +(.+)$")
      request_table[key] = value
    end
  end

  local query_string = (request_table.url):match("^/[^?]*%??(.*)$") or ""
  query_string = unescape(query_string)

  local uri = (request_table.url):match("^/([^?]*)%??.*$") or ""

  request_table.query_string = query_string
  request_table.query = _M.parse_query_string(query_string)
  request_table.uri = uri

  return request_table
end


-- wait for and receive client requests
function waitReceive()
  -- loop while waiting for a client request
  while 1 do
    -- accept a client request
    client = server:accept()
    -- set timeout - 1 minute.
    client:settimeout(60)
    -- receive request from client
    local request
    local request_text, err = _M.receive_request(client)

    if not err then
      -- parse request
      request = _M.parse_request(request_text)
    end

    -- if there's no error, begin serving content or KILL server
    if not err then
      -- if request is KILL (via telnet), stop the server
      if request == "KILL" then
        client:send("Octopus has stopped\n")
        print("Stopped")
        break
      else
        -- begin serving content
        serve(request)
      end
    end
  end
end

function _M.error404(URL)
  content = [[<!DOCTYPE html>
<html><head>
<title>404 Not Found</title>
</head><body>
<h1>Not Found</h1>
<p>The requested URL ]] .. URL .. [[ was not found on this server.</p>
<hr />
<p><i>Octopus web server</i></p>
</body></html>]]

  client:send [[HTTP/1.1 404 Not Found
Server: Octopus
Content-Length: ]]; client:send(content:len()); client:send [[
Connection: close
Content-Type: text/html; charset=utf8

]];
  client:send(content)
  client:close()
  err("Not found!")
end

-- serve requested content
function serve(request)
  local file = request.uri

  -- if no file mentioned in request, assume root file is index.html.
  if empty(file) then
    file = 'index.html'
  end

  filepath = 'docroot/' .. file

  -- check file exists
  if not os.rename(filepath, filepath) then
    _M.error404(request.url)
    return
  end

  -- retrieve mime type for file based on extension
  local mime = mimetypes.guess(file)

  -- reply with a response, which includes relevant mime type
  if mime ~= nil then
    client:send("HTTP/1.1 200/OK\r\nServer: Octopus\r\n")
    client:send("Content-Type:" .. mime .. "\r\n\r\n")
  end

  -- determine if file is in binary or ASCII format
  local binary = mimetypes.is_binary(filepath)

  -- load requested file in browser
  local served, flags
  if binary == false then
    -- if file is ASCII, use just read flag
    flags = "r"
  else
    -- otherwise file is binary, so also use binary flag (b)
    -- note: this is for operating systems which read binary
    -- files differently to plain text such as Windows
    flags = "rb"
  end
  served = io.open(filepath, flags)
  if served ~= nil then
    local content = served:read("*all")
    client:send(content)
  else
    -- display not found error
    err("Not found!")
  end

  -- done with client, close request
  client:close()
end

-- Adapted from: http://code.interfaceware.com/code?file=mime.lua&format=view
-- Given a filespec, open it up and see if it is a
-- "binary" file or not. This is a best guess.
-- Tweak the pattern to suit.
function mimetypes.is_binary(filename)
  local input = assert(io.open(filename, "rb"))

  local isbin = false
  local chunk_size = 2^12 -- 4k bytes

  repeat
    local chunk = input.read(input, chunk_size)
    if not chunk then break end

    if (string.find(chunk, "[^\f\n\r\t\032-\128]")) then
      isbin = true
      break
    end
  until false
  input:close()

  return isbin
end

-- display error message and server information
function err(message)
  client:send(message)
  -- ...
end

return _M
