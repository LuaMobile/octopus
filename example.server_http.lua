#!/usr/bin/env lua5.1

local http_server = require 'octopus'

if arg[1] == 'start' then
  -- invoke program starting point:
  -- parameter is command-line argument for port number
  http_server.start(arg[2])
elseif arg[1] == 'stop' then
  http_server.stop(arg[2])
end
