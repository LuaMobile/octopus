-----------------------------------------------------
-- Octopus web server
-- Version 0.1.1
-----------------------------------------------------
local _M = {}
local server, client
local locations = {}

-- load required modules
local socket = require("socket")
socket.url = require 'socket.url'
local seawolf = require 'seawolf'.__build('text', 'variable', 'fs')
local mimetypes = require 'mimetypes'

local explode, unescape = seawolf.text.explode, socket.url.unescape
local empty = seawolf.variable.empty

-- detect operating system
if os.getenv("WinDir") ~= nil then
  _ = "Windows"
else
  _ = "Other OS" -- !
end

-- Bind to a TCP port on all local interfaces
function _M.bind(port)
  local hostname

  -- display initial program information
  print 'Octopus web server v0.1.1'

  -- if no port is specified, use ephemeral port
  if port == nil then port = 0 end

  -- create tcp socket on $hostname:$port
  server = assert(socket.tcp())

  hostname = server:getsockname()

  local status, err = server:bind('*', port)
  if err then
    print(("Failed to bind to %s:%s. \nERROR: %s"):format(hostname, port, err))
    os.exit(1)
  end


  return hostname, port
end

-- Attach to document root and start listening to incoming connections
-- Make sure you called bind() previously.
function _M.attach(docroot)
  docroot = empty(docroot) and "docroot/" or seawolf.text.rtrim(docroot, "/") .. "/"

  -- max connections to queue before start rejecting connections
  server:listen(100)

  waitReceive(docroot) -- begin waiting for client requests

  server:close() -- close server
end

-- start web server
function _M.start(arg1, arg2)
  local hostname, port = _M.bind(arg1)

  -- display message to web server is running
  print(("\nRunning on %s:%s"):format(hostname, port))

  local docroot = _M.attach(arg2)
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
      if key then
        request_table[key] = value
      end
    end
  end

  local query_string = (request_table.url or ""):match("^/[^?]*%??(.*)$") or ""
  query_string = unescape(query_string)

  local uri = (request_table.url or ""):match("^/([^?]*)%??.*$") or ""

  request_table.query_string = query_string
  request_table.query = _M.parse_query_string(query_string)
  request_table.uri = uri

  return request_table
end

-- Attach given callback to a desired uri
function _M.location(uri, callback, mime)
  if type(callback) == 'function' and type(uri) == 'string' then
    locations[uri] = {callback = callback, mime = mime or [[text/html; charset=utf-8]]}
  else
    print(("ERROR: Failed to attach callback to location: %s.\n"):format(uri))
    os.exit(1)
  end
end

-- wait for and receive client requests
function waitReceive(docroot)
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
      -- parse request_text
      xpcall(function()
        request = _M.parse_request(request_text)
      end,
      function ()
        -- Some error when parsing, just keep going!
      end)
    end

    -- if there's no error, begin serving content or KILL server
    if not err then
      -- if request is KILL (via telnet), stop the server
      if request_text == "KILL" then
        client:send("Octopus has stopped\n")
        print("Stopped")
        break
      else
        -- begin serving content
        serve(request, docroot)
      end
    end
  end
end

function _M.error404(URL)
  _M.errorPage('404 Not Found', '404 Not Found', ([[<h1>Not Found</h1>
<p>The requested URL <span class="url">%s</span> was not found on this server.</p>]]):format(URL or ''))
end

-- serve requested content
function serve(request, docroot)
  local filepath, location_type, mime, content
  local location = request.uri

  -- if no location is set in request, assume root location is index.html.
  if empty(location) then
    location = 'index.html'
  end

  filepath = docroot .. location

  -- check whether location is a file or a callback
  if os.rename(filepath, filepath) then
    location_type = 'file'
      -- retrieve mime type for file based on extension
    mime = mimetypes.guess(file)
  elseif locations[request.uri] then
    location_type = 'callback'
    mime = locations[request.uri].mime
  else
    _M.error404(request.url)
    return
  end

  -- reply with a response, which includes relevant mime type
  if location_type == 'callback' then
    -- Get content provided by callback
    content = locations[request.uri].callback(request) or ''
    -- Always cast content to string
    content = [[string]] == type(content) and content or tostring(content)
  elseif location_type == 'file' then
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
      -- Get file contents
      content = served:read("*all")
    else
      -- display not found error
      _M.error404(request.url)
    end
  end

  local headers = ([[HTTP/1.1 200/OK
Server: Octopus
Content-Length: %s
Connection: close
]]):format(content:len())

  if mime ~= nil then
    headers = headers .. 'Content-Type:' .. mime .. "\n"
  end

  client:send(headers)
  client:send "\n"
  client:send(content)

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
function _M.errorPage(error_code, title, message)
  title = title or 'Unknown error!'
  message = message or title
  error_code = error_code or '500'

  local content = ([[<!DOCTYPE html>
<html><head>
<title>%s</title>
<style>
.url {
  background-color: gray;
  padding: 0 0.5em 0 0.5em;
}
body {
  background-color: black;
}
* {
  color: white;
}
</style>
</head><body>
%s
<hr />
<p><i>Octopus web server</i></p>
</body></html>]]):format(title, message)

  local headers = ([[HTTP/1.1 %s
Server: Octopus
Content-Length: %s
Content-Type: text/html; charset=utf8
Connection: close

]]):format(error_code, content:len())

  client:send(headers)
  client:send(content)

  client:close()
end

return _M
