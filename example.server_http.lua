#!/usr/bin/env lua5.1

local http_server = require 'octopus'

-- invoke program starting point:
-- parameter is command-line argument for port number
http_server.start(arg[2])
