# Octopus web server

Octopus is a minimalist web server library for embedded and mobile devices. It
serves as the foundation of the [LuaMobile project](https://github.com/LuaMobile).

One can launch a fully functional web server with a few lines of code. See
example.server_http.lua for reference.


# Compatibility

Octopus is written in the Lua programming language, compatible with Lua 5.1 and
Luajit (recommended).

The ideal is to support iOS, Android and Windows phone. Currently it is being
tested on Android only.


# Dependencies

* Luajit (recommended) or Lua 5.1
* LuaSocket 2.0.2+


# How to start/stop Octopus web server

## Start

1. Open up a shell prompt
2. Navigate to directory containing octopus.lua
3. Run: $ lua5.1 example.server_http.lua start

Make sure that the Lua intepreter is in your PATH
or you will have to type the full path to the Lua interpeter
e.g. /path/to/lua5.1 octopus.lua

The server runs by default on port 80 and can be accessed in
a web browser with http://localhost

Files served by the server should be placed in folder docroot

## Stop

1. Open up a shell prompt
2. Navigate to directory containing octopus.lua
3. Run: $ lua5.1 example.server_http.lua stop

## Credits

This project started as a fork of Sam(uel) [Saint-Pettersen's ladle](),
including some improvements backported from [Daniel Rempel's ladle fork](https://github.com/danielrempel/ladle).
