(function() {
  module.exports = function(samjs) {
    var debug;
    debug = samjs.debug("mongo-auth");
    if (!samjs.mongo) {
      throw new Error("samjs-mongo not found - must be loaded before samjs-mongo-isOwner");
    }
    if (!samjs.auth) {
      throw new Error("samjs-auth not found - must be loaded before samjs-mongo-isOwner");
    }
    if (!samjs.mongoAuth) {
      throw new Error("samjs-mongo-auth not found - must be loaded before samjs-mongo-isOwner");
    }
    return samjs.mongo.plugins({
      isOwner: function(options) {
        var isAllowed, prop;
        if (options == null) {
          options = {};
        }
        prop = samjs.authMongo ? '_id' : samjs.options.username;
        isAllowed = (function(_this) {
          return function(user, mode, model) {
            var perm;
            model = _this;
            perm = model.schema.path("owner").options[mode] || model.access[mode];
            return samjs.auth.getAllowance(user, perm, model.permissionChecker) === "";
          };
        })(this);
        return this.addHook("afterCreate", function() {
          var owner;
          if (!this.schema.path("owner")) {
            owner = {
              owner: {
                required: true,
                read: options.read,
                write: options.write
              }
            };
            if (samjs.authMongo) {
              owner.owner.type = samjs.mongo.mongoose.Schema.Types.ObjectId;
              owner.owner.ref = 'users';
            } else {
              owner.owner.type = String;
            }
            this.schema.add(owner);
          }
          this.addHook("beforeFind", (function(obj) {
            if (!isAllowed(obj.socket.client.auth.user, "read")) {
              obj.query.find = {
                $and: [
                  obj.query.find, {
                    owner: obj.socket.client.auth.user[prop]
                  }
                ]
              };
            }
            return obj;
          }), true);
          this.addHook("beforePopulate", (function(obj) {
            var i, len, modelname, populate, query, ref;
            ref = obj.populate;
            for (i = 0, len = ref.length; i < len; i++) {
              populate = ref[i];
              modelname = populate.model || this.schema.path(populate.path).options.ref;
              if (!isAllowed(obj.socket.client.auth.user, "read", samjs.models[modelname])) {
                query = {
                  owner: obj.socket.client.auth.user[prop]
                };
                if (populate.select != null) {
                  populate.select = {
                    $and: [populate.select, query]
                  };
                } else {
                  populate.select = query;
                }
              }
            }
            return obj;
          }), true);
          this.addHook("beforeInsert", (function(obj) {
            var base, id;
            if (this.plugins.users != null) {
              id = samjs.mongo.mongoose.Types.ObjectId();
              obj.query.owner = id;
              obj.query._id = id;
            } else {
              if (!isAllowed(obj.socket.client.auth.user, "write")) {
                obj.query.owner = obj.socket.client.auth.user[prop];
              } else {
                if ((base = obj.query).owner == null) {
                  base.owner = obj.socket.client.auth.user[prop];
                }
              }
            }
            return obj;
          }), true);
          this.addHook("beforeUpdate", (function(obj) {
            if (!isAllowed(obj.socket.client.auth.user, "write")) {
              obj.query.cond = {
                $and: [
                  obj.query.cond, {
                    owner: obj.socket.client.auth.user[prop]
                  }
                ]
              };
            }
            return obj;
          }), true);
          return this.addHook("beforeDelete", (function(obj) {
            if (!isAllowed(obj.socket.client.auth.user, "write")) {
              obj.query = {
                $and: [
                  obj.query, {
                    owner: obj.socket.client.auth.user[prop]
                  }
                ]
              };
            }
            return obj;
          }), true);
        });
      }
    });
  };

}).call(this);
