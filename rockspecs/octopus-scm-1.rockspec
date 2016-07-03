package = 'octopus'
version = 'scm-1'
source = {
  url = 'git://github.com/LuaMobile/octopus.git',
  tag = 'master',
}
description = {
  summary = 'Octopus web server library.',
  detailed = 'Current master branch. Octopus is a minimalist web server library for embedded and mobile devices.',
  homepage = 'https://github.com/LuaMobile/octopus',
  license = 'MIT',
  maintainer = 'Fernando Paredes Garcia <fernando@develcuy.com>',
}
dependencies = {
  'lua = 5.1',
  'luasocket',
}
build = {
  type = 'builtin',
  modules = {
    ['octopus'] = 'octopus.lua',
  },
}
