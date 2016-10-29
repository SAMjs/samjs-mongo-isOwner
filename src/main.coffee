# out: ../lib/main.js

module.exports = (samjs) ->
  debug = samjs.debug("mongo-auth")
  throw new Error "samjs-mongo not found - must be loaded before samjs-mongo-isOwner" unless samjs.mongo
  throw new Error "samjs-auth not found - must be loaded before samjs-mongo-isOwner" unless samjs.auth
  throw new Error "samjs-mongo-auth not found - must be loaded before samjs-mongo-isOwner" unless samjs.mongoAuth

  samjs.mongo.plugins isOwner: (options) ->
    options ?= {}
    name = options.name or "owner"
    prop = if samjs.authMongo then '_id' else samjs.options.username
    isAllowed = (user,mode,model) =>
      model = @
      perm = model.schema.path("owner").options[mode] || model.access[mode]
      return samjs.auth.getAllowance(user,perm,model.permissionChecker) == ""
    getQuery = (user,query) ->
      owner = {}
      owner[name] = user[prop]
      if query
        return {$and:[query,owner]}
      else
        return owner
    @addHook "afterCreate", ->
      unless @schema.path name
        owner = {}
        owner[name] =
          required: true
          read: options.read
          write: options.write
        if samjs.authMongo
          owner[name].type = samjs.mongo.mongoose.Schema.Types.ObjectId
          owner[name].ref = 'users'
        else
          owner[name].type = String
        @schema.add owner
      # add hooks after auth hooks
      @addHook "beforeFind", ((obj) ->
        user = obj.socket.client.auth.user
        unless isAllowed(user,"read")
          obj.query.find = getQuery(user, obj.query.find)
        return obj), true

      @addHook "beforePopulate", ((obj) ->
        user = obj.socket.client.auth.user
        for populate in obj.populate
          modelname = populate.model || @schema.path(populate.path).options.ref
          unless isAllowed(user,"read",samjs.models[modelname])
            populate.select = getQuery(user, populate.select)
        return obj), true

      @addHook "beforeInsert", ((obj) ->
        if @plugins.users? # new users automatically own own objects
          id = samjs.mongo.mongoose.Types.ObjectId()
          obj.query.owner = id
          obj.query._id = id
        else
          user = obj.socket.client.auth.user
          unless isAllowed(user,"write") # cannot set ownership
            obj.query[name] = user[prop]
          else
            obj.query[name] ?= user[prop]
        return obj), true

      @addHook "beforeUpdate", ((obj) ->
        user = obj.socket.client.auth.user
        unless isAllowed(user,"write") # only allow updating owned documents
          obj.query.cond = getQuery(user, obj.query.cond)
        return obj), true

      @addHook "beforeDelete", ((obj) ->
        user = obj.socket.client.auth.user
        unless isAllowed(user,"write") # only allow deleting owned documents
          obj.query = getQuery(user, obj.query)
        return obj), true
