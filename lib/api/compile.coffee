W        = require 'when'
nodefn   = require 'when/node/function'
guard    = require 'when/guard'
keys     = require 'when/keys'
sequence = require 'when/sequence'
mkdirp   = require 'mkdirp'

FSParser = require '../fs_parser'
Compiler = require '../compiler'


###*
 * @class Compile
 * @classdesc Compiles a project
###

class Compile

  ###*
   * Creates a new instance of the compile class.
   * 
   * - makes a new fs parser instance
   * - makes a new compiler instance
   * - makes a new instance of each extension, with error detection.
   *   this must happen every compile pass to clear lingering context
   * 
   * @param  {Function} roots - instance of the base roots class
  ###
  
  constructor: (@roots) ->
    @extensions = @roots.extensions.instantiate()
    @fs_parser = new FSParser(@roots, @extensions)
    @compiler = new Compiler(@roots, @extensions)

  ###*
   * Compiles the project. This process includes the following steps:
   *
   * - execute user before hooks if present
   * - parse the project, sort files into categories
   * - create the folder structure
   * - compile and write each of the files
   * - execute user after hooks if present
   * - emit finished events
  ###

  exec: ->
    @roots.emit('start')

    before_hook.call(@)
      .then(@fs_parser.parse.bind(@fs_parser))
      .tap(create_folders.bind(@))
      .then(process_files.bind(@))
      .then(after_hook.bind(@))
      .done (=> @roots.emit('done')), ((err) => @roots.emit('error', err))

  ###*
   * Calls any user-provided before hooks with the roots context.
   *
   * @private
  ###

  before_hook = ->
    hook_method.call(@, @roots.config.before)

  ###*
   * Calls any user-provided after hooks with the roots context.
   *
   * @private
  ###

  after_hook = (ast) ->
    hook_method.call(@, @roots.config.after)

  ###*
   * Checks to ensure the requested hook(s) is/are present, then calls them,
   * whether there was an array of hooks provided or just a single hook.
   *
   * @private
   * 
   * @param  {Array|Function} hook - a function or array of functions
   * @return {Promise} promise for resolved hooks
  ###

  hook_method = (hook) ->
    if not hook then return W.resolve()

    if Array.isArray(hook)
      hooks = hook.map((h) => nodefn.call(h.bind(@roots)))
    else if typeof hook == 'function'
      hooks = [nodefn.call(hook.bind(@roots))]
    else
      return W.reject('before hook should be a function or array')

    W.all(hooks)

  ###*
   * Given a roots ast, create the nested folder structure for the project.
   * 
   * @param  {Object} ast - roots ast
  ###

  create_folders = (ast) ->
    nodefn.call(mkdirp, @roots.config.output_path())
      .then(-> W.map(ast.dirs, guard(guard.n(1), nodefn.lift(mkdirp))))

  ###*
   * Files are processed by category, and each category can be processed in
   * One of two ways: parallel or ordered. Parallel processed categories will
   * crunch through their files as quickly as possible, starting immediately.
   * Ordered categories will parallel compile all the files in the category, but
   * wait until one category is finished before moving to the next one.
   *
   * An example use for each of these is client templates and dynamic content.
   * With client templates, they do not depend on any other compile process so
   * they are a great fit for parallel. For dynamic content, the front matter must
   * be parsed then available in normal templates, which means all dynamic content
   * must be finished parsing before normal content starts. For this reason, dynamic
   * content has to be ordered so it is placed before the normal compiles.
   *
   * So what this function does is first distinguishes ordered or parallel for each
   * extension, then pushes a compile task for that extension onto the appropriate
   * stack. The compile task just grabs the files from the category and runs them
   * each through the compiler's `compile` method. Then when they are finished, it
   * runs the after category hook.
   *
   * Once the ordered and parallel stacks are full of tasks, they are run. Ordered
   * gets sequenced so they run in order, and parallel runs (surprise) in parallel.
   * 
   * @param  {Object} ast - roots ast
  ###

  process_files = (ast) ->
    ordered = []
    parallel = []

    compile_task = (category) =>
      W.map(ast[category] || [], @compiler.compile.bind(@compiler, category))
        .then(=> sequence(@extensions.hooks('category_hooks.after'), @, category))

    for ext in @extensions
      extfs = if ext.fs then ext.fs() else {}
      if extfs.ordered
        ordered.push(((c) => compile_task.bind(@, c))(extfs.category))
      else
        parallel.push(compile_task.call(@, extfs.category))

    keys.all
      ordered: sequence(ordered)
      parallel: W.all(parallel)

module.exports = Compile
