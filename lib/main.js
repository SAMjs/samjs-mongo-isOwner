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
        var getQuery, isAllowed, name, prop;
        if (options == null) {
          options = {};
        }
        name = options.name || "owner";
        prop = samjs.authMongo ? '_id' : samjs.options.username;
        isAllowed = (function(_this) {
          return function(user, mode, model) {
            var perm;
            model = _this;
            perm = model.schema.path("owner").options[mode] || model.access[mode];
            return samjs.auth.getAllowance(user, perm, model.permissionChecker) === "";
          };
        })(this);
        getQuery = function(user, query) {
          var owner;
          owner = {};
          owner[name] = user[prop];
          if (query) {
            return {
              $and: [query, owner]
            };
          } else {
            return owner;
          }
        };
        return this.addHook("afterCreate", function() {
          var owner;
          if (!this.schema.path(name)) {
            owner = {};
            owner[name] = {
              required: true,
              read: options.read,
              write: options.write
            };
            if (samjs.authMongo) {
              owner[name].type = samjs.mongo.mongoose.Schema.Types.ObjectId;
              owner[name].ref = 'users';
            } else {
              owner[name].type = String;
            }
            this.schema.add(owner);
          }
          this.addHook("beforeFind", (function(obj) {
            var user;
            user = obj.socket.client.auth.user;
            if (!isAllowed(user, "read")) {
              obj.query.find = getQuery(user, obj.query.find);
            }
            return obj;
          }), true);
          this.addHook("beforePopulate", (function(obj) {
            var i, len, modelname, populate, ref, user;
            user = obj.socket.client.auth.user;
            ref = obj.populate;
            for (i = 0, len = ref.length; i < len; i++) {
              populate = ref[i];
              modelname = populate.model || this.schema.path(populate.path).options.ref;
              if (!isAllowed(user, "read", samjs.models[modelname])) {
                populate.select = getQuery(user, populate.select);
              }
            }
            return obj;
          }), true);
          this.addHook("beforeInsert", (function(obj) {
            var base, id, user;
            if (this.plugins.users != null) {
              id = samjs.mongo.mongoose.Types.ObjectId();
              obj.query.owner = id;
              obj.query._id = id;
            } else {
              user = obj.socket.client.auth.user;
              if (!isAllowed(user, "write")) {
                obj.query[name] = user[prop];
              } else {
                if ((base = obj.query)[name] == null) {
                  base[name] = user[prop];
                }
              }
            }
            return obj;
          }), true);
          this.addHook("beforeUpdate", (function(obj) {
            var user;
            user = obj.socket.client.auth.user;
            if (!isAllowed(user, "write")) {
              obj.query.cond = getQuery(user, obj.query.cond);
            }
            return obj;
          }), true);
          return this.addHook("beforeDelete", (function(obj) {
            var user;
            user = obj.socket.client.auth.user;
            if (!isAllowed(user, "write")) {
              obj.query = getQuery(user, obj.query);
            }
            return obj;
          }), true);
        });
      }
    });
  };

}).call(this);
