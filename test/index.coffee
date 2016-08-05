chai = require "chai"
should = chai.should()
samjs = require "samjs"
samjsClient = require "samjs-client"
samjsMongo = require "samjs-mongo"
samjsMongoClient = require "samjs-mongo-client"
samjsAuth = require "samjs-auth"
samjsAuthClient = require "samjs-auth-client"
samjsMongoIsOwner = require("../src/main")




fs = samjs.Promise.promisifyAll(require("fs"))
port = 3050
url = "http://localhost:"+port+"/"
testConfigFile = "test/testConfig.json"
mongodb = "mongodb://localhost/test"

describe "samjs", ->
  client = null
  before (done) ->
    fs.unlinkAsync testConfigFile
    .catch -> return true
    .finally ->
      samjs.reset()
      .plugins(samjsAuth,samjsMongo,samjsMongoIsOwner)
      .options({config:testConfigFile})
      .configs()
      .models({
        name:"isOwnerModel"
        db:"mongo"
        schema:
          someProp:String
        read: "root"
        write: "root"
        plugins:
          isOwner: null
      })
      done()

  describe "isOwner", ->
    model = null
    it "should startup", (done) ->
      samjs.startup().io.listen(port)
      client = samjsClient({
        url: url
        ioOpts:
          reconnection: false
          autoConnect: false
        })()
      client.plugins(samjsAuthClient,samjsMongoClient)
      client.install.onceConfigure
      .return client.install.set "mongoURI", mongodb
      .return client.auth.createRoot "rootroot"
      .return samjs.state.onceStarted
      .then -> done()
      .catch done

    it "should auth", (done) ->
      client.io.connect()
      .return client.auth.login {name:"root",pwd:"rootroot"}
      .then (result) ->
        result.name.should.equal "root"
        done()
      .catch done

    it "should be possible to add a second user", (done) ->
      client.config.get("users").then (result) ->
        result.push {name:"user",pwd:"useruser"}
        client.config.set("users", result)
      .then -> done()
      .catch done
    it "should automatically set owner on new documents", (done) ->
      model = new client.Mongo("isOwnerModel")
      model.insert({someProp:"test"})
      .then (result) ->
        should.exist result.owner
        result.owner.should.equal "root"
        done()
      .catch done
    it "should hide content from other users", (done) ->
      client.auth.logout()
      client.auth.login {name:"user",pwd:"useruser"}
      .then (result) ->
        result.name.should.equal "user"
        model.find(find:{someProp:"test"})
      .then (result) ->
        result.length.should.equal 0
        done()
      .catch done
    it "should be impossible to change documents of other users", (done) ->
      model.update(cond:{someProp:"test"},doc:{someProp:"test2"})
      .then (result) ->
        result.length.should.equal 0
        done()
      .catch done
    it "should be impossible to delete documents of other users", (done) ->
      model.remove({someProp:"test"})
      .then (result) ->
        result.length.should.equal 0
        done()
      .catch done
    it "should be possible to create documents", (done) ->
      model.insert({someProp:"test"})
      .then (result) ->
        result.someProp.should.equal "test"
        result.owner.should.equal "user"
        done()
      .catch done
    it "should be possible to find owned documents", (done) ->
      model.find(find:{someProp:"test"})
      .then (result) ->
        result[0].someProp.should.equal "test"
        result[0].owner.should.equal "user"
        done()
      .catch done
    it "should be possible to change owned document", (done) ->
      model.update(cond:{someProp:"test"},doc:{someProp:"test2"})
      .then (result) ->
        result.length.should.equal 1
        done()
      .catch done
    it "should be impossible to change owner of documents", (done) ->
      model.update(cond:{someProp:"test2"},doc:{owner:"user2"})
      .then (result) ->
        result.length.should.equal 1
        should.exist result[0]._id
        model.find(find:{_id:result[0]._id})
      .then (result) ->
        result.length.should.equal 1
        result[0].someProp.should.equal "test2"
        result[0].owner.should.equal "user"
        done()
      .catch done
    it "should be possible to delete owned documents", (done) ->
      model.remove({someProp:"test2"})
      .then (result) ->
        result.length.should.equal 1
        model.insert({someProp:"test"})
      .then (result) ->
        result.someProp.should.equal "test"
        result.owner.should.equal "user"
        done()
      .catch done
    it "should be possible for root to change owner", (done) ->
      client.auth.logout()
      client.auth.login {name:"root",pwd:"rootroot"}
      .then (result) ->
        result.name.should.equal "root"
        model.update(cond:{someProp:"test",owner:"user"},doc:{owner:"user2"})
      .then (result) ->
        result.length.should.equal 1
        should.exist result[0]._id
        model.find(find:{_id:result[0]._id,owner:"user2"})
      .then (result) ->
        result.length.should.equal 1
        result[0].someProp.should.equal "test"
        result[0].owner.should.equal "user2"
        done()
      .catch done
    it "should be possible for root to delete documents of other users", (done) ->
      model.remove({owner:"user2"})
      .then (result) ->
        result.length.should.equal 1
        done()
      .catch done
  after (done) ->
    if samjs.models.isOwnerModel?
      model1 = samjs.models.isOwnerModel.dbModel
      samjs.Promise.all([model1.remove({})])
      .then ->
        return samjs.shutdown() if samjs.shutdown?
      .then -> done()
    else if samjs.shutdown?
      samjs.shutdown().then -> done()
    else
      done()
