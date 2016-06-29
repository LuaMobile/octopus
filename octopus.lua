-----------------------------------------------------
-- Octopus web server
-- Version 0.1.1
-----------------------------------------------------

-- load required modules
socket = require("socket")
mimetypes = require 'mimetypes'

-- detect operating system
if os.getenv("WinDir") ~= nil then
        _ = "Windows"
else
        _ = "Other OS"  -- !
end

-- start web server
function main(arg1) 
    port = arg1 -- set first argument as port

    -- display initial program information
    print 'Octopus web server v0.1.1'

    -- if no port is specified, use port 80
    if port == nil then port = 80 end

    -- create tcp socket on $hostname:$port
    server = assert(socket.tcp())
    hostname = server:getsockname()
    assert(server:bind(hostname, port))
    if not server
    then
      print(("Failed to bind to given %s:%s"):format(hostname, port))
      os.exit(1)
    end

    -- display message to web server is running
    print(("\nRunning on %s:%s"):format(hostname, port))

    -- max connections to queue before start rejecting connections
    server:listen(100)

    waitReceive() -- begin waiting for client requests

    server:close() -- close server
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
        local request, err = client:receive()
        -- if there's no error, begin serving content or kill server
        if not err then
            -- if request is kill (via telnet), stop the server
            if request == "kill" then
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
-- serve requested content
function serve(request)
    -- resolve requested file from client request
    local file = string.match(request, "%w+%\/?.?%l+")
    -- if no file mentioned in request, assume root file is index.html.
    if file == nil then
        file = "index.html"
    end
        
    -- retrieve mime type for file based on extension
    local ext = string.match(file, "%\.%l%l%l%l?")
    local mime = mimetypes.getMime(ext)

    -- reply with a response, which includes relevant mime type
    if mime ~= nil then
        client:send("HTTP/1.1 200/OK\r\nServer: Octopus\r\n")
        client:send("Content-Type:" .. mime .. "\r\n\r\n")
    end

    -- determine if file is in binary or ASCII format
    local binary = mimetypes.isBinary(mime)

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
    served = io.open("www/" .. file, flags)
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
-- display error message and server information
function err(message)
    client:send(message)
  -- ...
end
-- invoke program starting point:
-- parameter is command-line argument for port number
main(arg[1])
