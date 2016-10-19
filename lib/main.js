(function() {
  module.exports = function(samjs) {
    var MongoIsOwner, debug;
    debug = samjs.debug("mongo-auth");
    if (!samjs.mongo) {
      throw new Error("samjs-mongo not found - must be loaded before samjs-mongo-isOwner");
    }
    if (!samjs.auth) {
      throw new Error("samjs-auth not found - must be loaded before samjs-mongo-isOwner");
    }
    samjs.mongo.plugins({
      isOwner: function(options) {
        var pc;
        if (options == null) {
          options = {};
        }
        pc = this.permissionChecker;
        if (pc == null) {
          pc = samjs.options.permissionChecker;
        }
        if (options.read == null) {
          options.read = this.read;
        }
        if (options.write == null) {
          options.write = this.write;
        }
        if (pc === "inGroup") {
          if (options.read == null) {
            options.read = samjs.options.groupRoot;
          }
          if (options.write == null) {
            options.write = samjs.options.groupRoot;
          }
        } else {
          if (options.read == null) {
            options.read = [samjs.options.rootUser];
          }
          if (options.write == null) {
            options.write = [samjs.options.rootUser];
          }
        }
        return this.addHook("afterCreate", function() {
          var owner, prop;
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
          prop = samjs.authMongo ? '_id' : samjs.options.username;
          this.addHook("beforeFind", (function(_this) {
            return function(obj) {
              if (obj.client.auth == null) {
                throw new Error("invalid socket - no auth");
              }
              if (samjs.auth.getAllowance(obj.client.auth.user, _this.schema.path("owner").options.read, pc) !== "") {
                obj.query.find.owner = obj.client.auth.user[prop];
              }
              return obj;
            };
          })(this));
          this.addHook("beforeInsert", function(obj) {
            var base, id;
            if (this.plugins.users != null) {
              id = samjs.mongo.mongoose.Types.ObjectId();
              obj.query.owner = id;
              obj.query._id = id;
            } else if (samjs.auth.getAllowance(obj.client.auth.user, this.schema.path("owner").options.read, pc) !== "") {
              obj.query.owner = obj.client.auth.user[prop];
            } else {
              if ((base = obj.query).owner == null) {
                base.owner = obj.client.auth.user[prop];
              }
            }
            return obj;
          });
          this.addHook("beforeUpdate", (function(_this) {
            return function(obj) {
              if (samjs.auth.getAllowance(obj.client.auth.user, _this.schema.path("owner").options.write, pc) !== "") {
                obj.query.cond.owner = obj.client.auth.user[prop];
                if (obj.query.doc.owner != null) {
                  delete obj.query.doc.owner;
                }
              }
              return obj;
            };
          })(this));
          return this.addHook("beforeRemove", (function(_this) {
            return function(obj) {
              if (samjs.auth.getAllowance(obj.client.auth.user, _this.schema.path("owner").options.write, pc) !== "") {
                obj.query.owner = obj.client.auth.user[prop];
              }
              return obj;
            };
          })(this));
        });
      }
    });
    return new (MongoIsOwner = (function() {
      function MongoIsOwner() {}

      MongoIsOwner.prototype.name = "mongoIsOwner";

      return MongoIsOwner;

    })());
  };

}).call(this);
