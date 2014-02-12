require 'colors'
{EventEmitter} = require('events')
fs             = require 'fs'
Config         = require './config'
Extensions     = require './extensions'

###*
 * @class
 * @classdesc main roots class, public api for roots
###

class Roots extends EventEmitter

  ###*
   * Given a path to a project, set up the configuration and return a roots instance
   * @param  {[type]} root - path to a folder
   * @return {Function} - instance of the Roots class
  ###

  constructor: (@root) ->
    if not fs.existsSync(@root) then throw new Error("path does not exist")
    @extensions = new Extensions(@)
    @config = new Config(@)

  @new: (opts) ->
    n = new (require('./api/new'))(@)
    n.exec(opts).on('done', (root) => if opts.done then opts.done(new @(root)))
    return n

  @template: require('./api/template')

  compile: ->
    # TODO: does this actually provide a speed boost?
    Compile = require('./api/compile')
    (new Compile(@)).exec()
    return @

  watch: ->
    (new (require('./api/watch'))(@)).exec()
    return @

  ###*
   * If an irrecoverable error has occurred, exit the application with
   * as clear an error as possible and a specific exit code.
   *
   * @param {Integer} code - numeric error code
   * @param {String} details - any additional details to be printed
  ###

  bail: (code, details) ->
    switch code
      when 125 then msg = "malformed extension error"

    console.error "\nFLAGRANT ERROR!\n".red.bold
    console.error "It looks like there was a " + "#{msg}".bold + "."
    console.error "Check out " + "http://roots.cx/errors##{code}".green + " for more help\n"

    if details
      console.error "DETAILS:".yellow.bold
      console.error details

    process.exit(code)

module.exports = Roots

###

What's Going On Here?
---------------------

Welcome to the main entry point to roots! Through this very file, all the
magic happens. Roots' code is somewhat of a work of art for me, something I
strive to make as beautiful as functional, and consequently something I am
hardly ever totally happy with because as soon as I learn or improve, I start
seeing more details that could be smoothed out.

Anyways, let's jump into it. This file exposes the main roots class and public
API to roots. Everything within roots is loaded as lazily as possible, and
uses dependency injection to share context between the different classes that
make up roots. This allows a pretty significant speed boost, since for
example, none of the deps for watch are loaded. The only code loaded is the
code you need, which not only is good for performance, but also forces a very
clean and separated API design. You can find all the individual method classes
in the api folder.

All roots' public API methods expose event emitters. Compile and watch expose
the same emitter, while new exposes a slightly different one.

The new class method is a bit of an anomaly. Since you do not technically have
a roots project if you are running new, it is exposed as a class method and
can optionally be an alternate constructor as well -- if you pass in a
callback, it will not only initialize your project, but also pass you back a
fully loaded roots instance configured to your new project.

The compile and watch methods do more or less what you would expect - compile
the project, and watch the project for changes then compile. The compile
function runs once off, while the watch function will hang until you exit the
process somehow.

###
