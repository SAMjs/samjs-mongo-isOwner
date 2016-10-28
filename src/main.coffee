# out: ../lib/main.js

module.exports = (samjs) ->
  debug = samjs.debug("mongo-auth")
  throw new Error "samjs-mongo not found - must be loaded before samjs-mongo-isOwner" unless samjs.mongo
  throw new Error "samjs-auth not found - must be loaded before samjs-mongo-isOwner" unless samjs.auth
  throw new Error "samjs-mongo-auth not found - must be loaded before samjs-mongo-isOwner" unless samjs.mongoAuth

  samjs.mongo.plugins isOwner: (options) ->
    options ?= {}
    prop = if samjs.authMongo then '_id' else samjs.options.username
    isAllowed = (user,mode,model) =>
      model = @
      perm = model.schema.path("owner").options[mode] || model.access[mode]
      return samjs.auth.getAllowance(user,perm,model.permissionChecker) == ""

    @addHook "afterCreate", ->
      unless @schema.path "owner"
        owner = owner:
          required: true
          read: options.read
          write: options.write
        if samjs.authMongo
          owner.owner.type = samjs.mongo.mongoose.Schema.Types.ObjectId
          owner.owner.ref = 'users'
        else
          owner.owner.type = String
        @schema.add owner
      # add hooks after auth hooks
      @addHook "beforeFind", ((obj) ->
        unless isAllowed(obj.socket.client.auth.user,"read")
          obj.query.find = $and: [
            obj.query.find
            owner: obj.socket.client.auth.user[prop]
            ]
        return obj), true

      @addHook "beforePopulate", ((obj) ->
        for populate in obj.populate
          modelname = populate.model || @schema.path(populate.path).options.ref
          unless isAllowed(obj.socket.client.auth.user,"read",samjs.models[modelname])
            query = owner: obj.socket.client.auth.user[prop]
            if populate.select?
              populate.select = $and: [populate.select,query]
            else
              populate.select = query
        return obj), true

      @addHook "beforeInsert", ((obj) ->
        if @plugins.users? # new users automatically own own objects
          id = samjs.mongo.mongoose.Types.ObjectId()
          obj.query.owner = id
          obj.query._id = id
        else
          unless isAllowed(obj.socket.client.auth.user,"write") # cannot set ownership
            obj.query.owner = obj.socket.client.auth.user[prop]
          else
            obj.query.owner ?= obj.socket.client.auth.user[prop]
        return obj), true

      @addHook "beforeUpdate", ((obj) ->
        unless isAllowed(obj.socket.client.auth.user,"write") # only allow updating owned documents
          obj.query.cond = $and: [
            obj.query.cond
            owner: obj.socket.client.auth.user[prop]
            ]
        return obj), true

      @addHook "beforeDelete", ((obj) ->
        unless isAllowed(obj.socket.client.auth.user,"write") # only allow deleting owned documents
          obj.query = $and: [
            obj.query
            owner: obj.socket.client.auth.user[prop]
            ]
        return obj), true
