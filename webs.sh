#!/bin/sh
# Run the octopus web server
# Usage: webs $port

# NOTE: sudo is required to run on ports lower than 1000, 
# so it is used here.

sudo lua octopus.lua $1
