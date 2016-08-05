# samjs-mongo-isOwner

Plugin for managing user owned documents in [samjs-mongo](https://github.com/SAMjs/samjs-mongo).

## Getting Started
```sh
npm install --save samjs-mongo-isOwner
```

## Usage
```js
samjs.plugins([
  // samjs-auth and samjs-mongo are needed before samjs-mongo-isOwner
  require("samjs-auth"),
  require("samjs-mongo"),
  require("samjs-mongo-isOwner")
])
.options()
.configs()
.models({
  name: "someModel",
  db: "mongo",
  plugins: {
    isOwner:
      read: "root" // right to read documents of other users, defaults to root
      write: "root" // right to change and delete documents of other users, defaults to root
  },
  schema: {
    someProp: {
      type: String
      }
    },
}).startup(server)

// client side
var model = new client.Mongo("testModel")
// will set owner to current user
model.insert({someProp:"test"})
// will only find documents of the current user
model.find({find:{someProp:"test"}})
// will only update documents of the current user
model.update(cond:{someProp:"test"},doc:{someProp:"test2"})
// not possible to change owner / only for rootroot
model.update(cond:{someProp:"test2"},doc:{owner:"user2"})
// will only delete documents of the current user
model.remove({someProp:"test2"})
```

## in conjunction with samjs-mongo-auth
insert and remove access for documents changes a bit and can be controlled
```js
.models({
  name: "someModel",
  db: "mongo",
  plugins: {
    isOwner:{
      read: "root" // right to read documents of other users, defaults to root
      write: "root" // right to change and delete documents of other users, defaults to root
    },
    auth:{
      // allows user to create documents even when access to parts of it are forbidden (like the owner prop)
      // defaults to true
      // meaning users can create new owned documents
      // set to false if you can't trust user and need a more controlled mechanismn to create user owned documents
      insertable: true,
      // allows user to delete documents even when access to parts of it are forbidden (like the owner prop)
      // defaults to false
      // meaning users can't delete their own documents
      // set to true if you can trust user and need to allow to delete their own documents
      deletable: false
    }
  },
  schema: {
    someProp: {
      type: String,
      read: true,
      write: true // give user access to write the 'someProp' properties of owned documents
      }
    }
})

```
