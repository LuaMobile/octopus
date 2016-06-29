# Octopus web server

Octopus (formally just known as "lua web server") is an experimental web server
written in the Lua programming language, compatible with Lua 5.1.


# Dependencies

* Lua 5.1
* LuaSocket 2.0.2+


# How to start/stop Octopus web server

## Start

1. Open up a shell prompt
2. Navigate to directory containing octopus.lua
3. Run: $ lua5.1 octopus.lua

Make sure that the Lua intepreter is in your PATH
or you will have to type the full path to the Lua interpeter
e.g. /path/to/lua5.1 octopus.lua

The server runs by default on port 80 and can be accessed in
a web browser with http://localhost

Files served by the server should be placed in folder docroot


## Stop

1. Open up a shell prompt
2. Navigate to directory containing octopus.lua
3. Run "telin" script followed by port number. Example: "telin 80" or
   "./telin.sh 80" if you ran the server on port 80
4. Type "kill" and hit return
