# out: ../lib/main.js

module.exports = (samjs) ->
  debug = samjs.debug("mongo-auth")
  throw new Error "samjs-mongo not found - must be loaded before samjs-mongo-isOwner" unless samjs.mongo
  throw new Error "samjs-auth not found - must be loaded before samjs-mongo-isOwner" unless samjs.auth

  samjs.mongo.plugins isOwner: (options) ->
    options ?= {}
    pc = @permissionChecker
    pc ?= samjs.options.permissionChecker
    # default to model read/write
    options.read ?= @read
    options.write ?= @write
    # second default application wide read/write
    if pc == "inGroup"
      options.read ?= samjs.options.groupRoot
      options.write ?= samjs.options.groupRoot
    else
      options.read ?= [samjs.options.rootUser]
      options.write ?= [samjs.options.rootUser]

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
      prop = if samjs.authMongo then '_id' else samjs.options.username
      # add hooks after auth hooks
      @addHook "beforeFind", (obj) =>
        throw new Error "invalid socket - no auth" unless obj.client.auth?
        if samjs.auth.getAllowance(obj.client.auth.user,@schema.path("owner").options.read,pc) != ""
          obj.query.find.owner = obj.client.auth.user[prop]
        return obj


      @addHook "beforeInsert", (obj) ->
        if @plugins.users?
          id = samjs.mongo.mongoose.Types.ObjectId()
          obj.query.owner = id
          obj.query._id = id
        else if samjs.auth.getAllowance(obj.client.auth.user,@schema.path("owner").options.read,pc) != ""
          obj.query.owner = obj.client.auth.user[prop]
        else
          obj.query.owner ?= obj.client.auth.user[prop]
        return obj

      @addHook "beforeUpdate", (obj) =>
        if samjs.auth.getAllowance(obj.client.auth.user,@schema.path("owner").options.write,pc) != ""
          obj.query.cond.owner = obj.client.auth.user[prop]
          delete obj.query.doc.owner if obj.query.doc.owner?
        return obj

      @addHook "beforeRemove", (obj) =>
        if samjs.auth.getAllowance(obj.client.auth.user,@schema.path("owner").options.write,pc) != ""
          obj.query.owner = obj.client.auth.user[prop]
        return obj

  return new class MongoIsOwner
    name: "mongoIsOwner"
