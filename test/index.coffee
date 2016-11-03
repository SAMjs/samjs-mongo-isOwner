chai = require "chai"
should = chai.should()
chai.use require "chai-as-promised"
samjs = require "samjs"
samjsClient = require "samjs-client"
samjsMongo = require "samjs-mongo"
samjsMongoClient = require "samjs-mongo-client"
samjsAuth = require "samjs-auth"
samjsAuthClient = require "samjs-auth-client"
samjsMongoAuth = require "samjs-mongo-auth"
samjsMongoIsOwner = require("../src/main")




fs = samjs.Promise.promisifyAll(require("fs"))
port = 3050
url = "http://localhost:"+port+"/"
testConfigFile = "test/testConfig.json"
mongodb = "mongodb://localhost/test"

describe "samjs", ->
  client = null
  before ->
    fs.unlinkAsync testConfigFile
    .catch -> return true
    .finally ->
      samjs.reset().then ->
        samjs.plugins(samjsAuth(),samjsMongo,samjsMongoAuth,samjsMongoIsOwner)
        .options({config:testConfigFile})
        .configs()
        .models({
          name:"isOwnerModel"
          db:"mongo"
          schema:
            someProp:String
          access:
            read: true
            write: true
          plugins:
            isOwner:
              read: "root"
              write: "root"
        })

  describe "isOwner", ->
    model = null
    it "should startup", ->
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

    it "should auth", ->
      client.io.connect()
      .return client.auth.login {name:"root",pwd:"rootroot"}
      .then (result) ->
        result.name.should.equal "root"

    it "should be possible to add a second user", ->
      client.config.get("users").then (result) ->
        result.push {name:"user",pwd:"useruser"}
        client.config.set("users", result)

    it "should automatically set owner on new documents", ->
      model = client.getMongoModel("isOwnerModel")
      model.insert({someProp:"test"})
      .then (result) ->
        should.exist result.owner
        result.owner.should.equal "root"

    it "should hide content from other users", ->
      client.auth.logout()
      client.auth.login {name:"user",pwd:"useruser"}
      .then (result) ->
        result.name.should.equal "user"
        model.find(find:{someProp:"test"})
      .then (result) ->
        result.length.should.equal 0

    it "should be impossible to change documents of other users", ->
      model.update(cond:{someProp:"test"},doc:{someProp:"test2"})
      .then (result) ->
        result.length.should.equal 0

    it "should be impossible to delete documents of other users", ->
      model.delete({someProp:"test"})
      .then (result) ->
        result.length.should.equal 0

    it "should be possible to create documents", ->
      model.insert({someProp:"test"})
      .then (result) ->
        result.someProp.should.equal "test"
        should.not.exist result.owner

    it "should be possible to find owned documents", ->
      model.find(find:{someProp:"test"})
      .then (result) ->
        result[0].someProp.should.equal "test"
        should.not.exist result[0].owner

    it "should be possible to change owned document", ->
      model.update(cond:{someProp:"test"},doc:{someProp:"test2"})
      .then (result) ->
        result.length.should.equal 1

    it "should be impossible to change owner of documents", ->
      model.update(cond:{someProp:"test2"},doc:{owner:"user2"})
      .should.be.rejected

    it "should be possible to delete owned documents",  ->
      model.delete({someProp:"test2"})
      .then (result) ->
        result.length.should.equal 1
        model.insert({someProp:"test"})
      .then (result) ->
        result.someProp.should.equal "test"

    it "should be possible for root to change owner", ->
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

    it "should be possible for root to delete documents of other users", ->
      model.delete({owner:"user2"})
      .then (result) ->
        result.length.should.equal 1

  after  ->
    if samjs.models.isOwnerModel?
      model1 = samjs.models.isOwnerModel.dbModel
      samjs.Promise.all([model1.remove({})])
      .then ->
        return samjs.shutdown() if samjs.shutdown?
    else if samjs.shutdown?
      samjs.shutdown()
