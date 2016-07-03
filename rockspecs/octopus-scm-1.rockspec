package = 'octopus'
version = 'scm-1'
source = {
  url = 'git://github.com/develCuy/octopus.git',
  tag = 'master',
}
description = {
  summary = 'Octopus web server.',
  detailed = 'Current master branch of Octopus.',
  homepage = 'https://github.com/develCuy/octopus',
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
