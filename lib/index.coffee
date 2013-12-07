require './config'

{EventEmitter} = require('events')
W = require 'when'
nodefn = require 'when/node/function'
keys = require 'when/keys'
fs = require 'fs'
path = require 'path'
_ = require 'lodash'
async = require 'async'

FSParser = require './fs_parser'
Compiler = require './compiler'

class Roots extends EventEmitter

  compile: (@root) ->
    config.setup(@root)

    (new FSParser(@root)).parse()
    .then(create_folders)
    .then(process_files.bind(@))
    # .then(precompile_templates.bind(@))
    .done (=> @emit('done')), ((err) => @emit('error', err))

    return @

  # @api private

  create_folders = (ast) ->
    output = config.path('output')
    ast.dirs = _(ast.dirs).uniq().compact().value().map((d) => path.join(output, d))
    try fs.mkdirSync(output)
    nodefn.call(async.mapSeries, ast.dirs, fs.mkdir).yield(ast)

  process_files = (ast) ->
    compiler = new Compiler(@root)

    keys.all
      compile:
        W.map(ast.dynamic, compiler.compile_dynamic.bind(compiler))
        .then(-> W.map(ast.compiled, compiler.compile.bind(compiler)))
      copy:
        W.map(ast.static, compiler.copy.bind(compiler))

module.exports = new Roots

# What's Going On Here?
# ---------------------

# Welcome to the main entry point to roots! Through this very file, all the magic happens.
# Roots' code is somewhat of a work of art for me, something I strive to make as beautiful
# as functional, and consequently something I am hardly ever totally happy with because as
# soon as I learn or improve, I start seeing more details that could be smoothed out.

# Anyway, let's pick this apart. This file represents roots' API, which really is quite
# simple - it's mostly comprised of a single `compile` function that does all the work.
# It is organized as a class for code clarity, but as you can see by quickly browsing
# through, this particular file does not bank heavily on object orientation, as I don't see
# a lot of benefits to exposing a raw class as the API. What it exposes instead is an event
# emitter that fires a few events you can listen for.

# There is a pretty compressed chunk of promise logic in the `process_files` method which also
# merits explaining. What' happening here is that two compile processes are being fired off
# asynchronously. In the first, the dynamic files are compiled followed by the compiled files.
# In the second, any static assets are copied over. Both of these fire at once, and once they have both finished, the whole promise returns.