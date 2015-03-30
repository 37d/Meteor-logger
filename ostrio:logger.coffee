###
@description Add 'ostrioLoggerUserId' Session value, to use in client when Meteor.userId() or this.userId isn't available
###
if Meteor.isClient
  Session.set "ostrioLoggerUserId", Meteor.userId()

###
@class
@name Logger
@description Simple logger class, which passing incoming data to Client and Server via method
###
class Logger

  constructor: () ->
    undefined

  _emitters: []
  _rules: {}

  ###
  @function
  @class Logger
  @name  log
  @param level    {String} - Log level Accepts 'ERROR', 'FATAL', 'WARN', 'DEBUG', 'INFO', 'TRACE', 'LOG' and '*'
  @param message  {String} - Text human-readable message
  @param data     {Object} - [optional] Any additional info as object
  @param userId   {Object} - [optional] Current user id
  @description Pass log's data to Server or/and Client
  ###
  logit: (level, message, data, userId) -> 
    for i, em of Logger::_emitters
      if Logger::_rules[em.name] and Logger::_rules[em.name].allow.indexOf('*') isnt -1 or Logger::_rules[em.name] and Logger::_rules[em.name].allow.indexOf(level) isnt -1
          
        if typeof userId == "undefined" or !userId
          userId = this.userId

        userId = if Meteor.isClient then Session.get("ostrioLoggerUserId") else userId

        if Meteor.isClient and em.denyClient is true
          Meteor.call em.method, level, message, data, userId
          undefined
        else if Logger::_rules[em.name].client is true and Logger::_rules[em.name].server is true and em.denyClient is false
          em.emitter level, message, data, userId
          if Meteor.isClient
            Meteor.call em.method, level, message, data, userId
            undefined
        else if Meteor.isClient and Logger::_rules[em.name].client is false and Logger::_rules[em.name].server is true
          Meteor.call em.method, level, message, data, userId
          undefined
        else
          em.emitter level, message, data, userId
          
    return undefined

  ###
  @function
  @class Logger
  @name  rule
  @param name    {String} - Adapter name
  @param options {Object} - Settings object, accepts next properties:
            enable {Boolean} - Enable/disable adapter
            filter {Array}   - Array of strings, accepts: 
                               'ERROR', 'FATAL', 'WARN', 'DEBUG', 'INFO', 'TRACE', 'LOG' and '*'
                               in lowercase or uppercase
                               default: ['*'] - Accept all
            client {Boolean} - Allow execution on Client
            server {Boolean} - Allow execution on Server
  @description Enable/disable adapter and set it's settings
  ###
  rule: (name, options) ->
    if !name or !options or !options.enable
      throw new Meteor.Error '500', '"name", "options" and "options.enable" is require on Meteor.log.rule(), when creating rule for "' + name + '"'

    if options.allow
      for k of options.allow
        options.allow[k] = options.allow[k].toUpperCase()

    Logger::_rules[name] = 
      enable: options.enable
      allow: if options.allow || options.filter then options.allow || options.filter else ['*']
      client: if options.client then options.client else false
      server: if options.server then options.server else true

  ###
  @function
  @class Logger
  @name  add
  @param name        {String}    - Adapter name
  @param emitter     {Function}  - Function called on Meteor.log...
  @param init        {Function}  - Adapter initialization function
  @param denyClient  {Boolean}   - Strictly deny execution on client, only pass via Meteor.methods
  @description Register new adapter to be used within ostrio:logger package
  ###
  add: (name, emitter, init, denyClient = false) ->
    init and init()

    Logger::_emitters.push
      name: name
      emitter: emitter
      method: "logger_emit_#{name}"
      denyClient: denyClient

    if Meteor.isServer
      methFunc = {}
      methFunc["logger_emit_#{name}"] = (level, message, data, userId) =>
        emitter level, message, data, userId
      
      Meteor.methods methFunc

  ###
  @function
  @class Logger
  @name  info; debug; error; fatal; warn; trace; _
  @param message {String} - Any text message
  @param data    {Object} - [optional] Any additional info as object
  @param userId  {String} - [optional] Current user id
  @description Functions below is shortcuts for logit() method
  ###
  info: (message, data, userId) ->
    @logit "INFO", message, data, userId
  debug: (message, data, userId) ->
    @logit "DEBUG", message, data, userId
  error: (message, data, userId) ->
    @logit "ERROR", message, data, userId
  fatal: (message, data, userId) ->
    @logit "FATAL", message, data, userId
  warn: (message, data, userId) ->
    @logit "WARN", message, data, userId
  trace: (message, data, userId) ->
    @logit "TRACE", message, data, userId
  log: (message, data, userId) ->
    @logit "LOG", message, data, userId
  _: (message, data, userId) ->
    @logit "LOG", message, data, userId

  ###
  @function
  @class Logger
  @name  antiCircular
  @param data {Object} - Circular or any other object which needs to be non-circular
  ###
  antiCircular: (obj) ->
    _cache = [];
    _wrap = (obj) ->
      for v, k of obj
        if typeof v is "object" and v isnt null 
          if _cache.indexOf(v) isnt -1
            obj[k] = "[Circular]"
            return undefined
          _cache.push v
          return _wrap v
    _wrap obj
    return obj

Meteor.log = new Logger()