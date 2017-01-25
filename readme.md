# Slate Common Modules

> Common Slate modules that are used by multiple Slate libraries and Slate Apps.

## Install

### Elm

Since the Elm Package Manager doesn't allow for Native code and most everything we write at Panoramic Software has some native code in it,
you have to install this library directly from GitHub, e.g. via [elm-github-install](https://github.com/gdotdesign/elm-github-install) or some equivalent mechanism. It's just not worth the hassle of putting libraries into the Elm package manager until it allows native code.

## Slate.Common.Event

Since `Slate` is an Event Sourced DB, it stores `Events`.

### Event Record

A Slate `EventRecord` represents the `Query Result` of a `SQL Query` on the `events` table in the Slate Database:

```elm
type alias EventRecord =
    { id : String
    , ts : Date
    , event : Event
    , max : Maybe String
    }
```
* `id` - The unique record id in the DB.
* `ts` - The timestamp for when the record was written, i.e. the time of the event.
* `event` - The actual `Event` that occurred (see [Event](#event))
* `max` - This is a `Maybe` since it won't always be returned from a `SQL Query`. It's useful to have `max` for getting the `Maximum Event Id` for a Query at a single point in time. This is done by the `Query Engine` [slate-query-engine](https://github.com/panosoft/slate-query-engine).

### Event

A Slate `Event` is as follows:

```elm
type alias Event =
    { name : String
    , version : Maybe Int
    , data : EventData
    , metadata : Metadata
    }
```
* `name` - The name of the event. These are found in the `Entities Schema` for `Mutating Events`.
* `version` - Thhe version of the `Event` used to aid in `Entity Schema Migration`.
* `data` - The data that's specific to the `Event` (see [EventData](#eventdata))

### EventData

It is worth noting that there are 2 types of Events in Slate, `Mutating Events` and `Non-mutating Events`.

`Mutating Events` are events that mutate `Entities`.

`Non-mutating Events` are noteworthy events where a user performs an operation worth noting, e.g. for security reasons.

They only differ in the `EventData`.

```elm
type EventData
    = Mutating MutatingEventData
    | NonMutating NonMutatingEventData
```

`MutatingEventData` supports `Entities` with `Properties`. Each `Property` can be a primitive type, a `Value Object` or a list of either.

A `Value Object` is a JSON string and is atomic, i.e. the whole object is mutated per event.

`Entities` can have relationships with other `Entities` via `References`.

```elm
type alias MutatingEventData =
    { entityId : String
    , value : Maybe String
    , referenceId : Maybe String
    , propertyId : Maybe String
    , oldPosition : Maybe Int
    , newPosition : Maybe Int
    }
```

* `entityId` - The globally unique id for the entityId
* `value` - An optional value as a String. If this event involves adding or changing a property's value that's a `Value Object`, then this is a JSON string
* `referenceId` - If the event involves a relationship between this `Entity` and another, then this is the globally unique id of the other `Entity`.
* `propertyId` - The id of a list property.
* `oldPosition` - The Old Position of a property in a list in an event that is reordering a list of `Properties`.
* `newPosition` - The New Position of a property in a list in an event that is reordering a list of `Properties`.

`NonMutatingEventData` is a simple event with an optional JSON `value`. This allows for future flexibility of the structure.

```elm
type alias NonMutatingEventData =
    { value : Maybe String
    }
```

* `value` - An optional JSON string with parameters for the `Event`.

### Metadata

`Metadata` contains attributes about the `EventData`.

```elm
type alias Metadata =
    { initiatorId : String
	, command : String
    }
```

* `initiatorId` - The globally unique id of the Actor on the system that caused this event. This can be a `User Id` or a `System Id`.
* `command` - This is the command that was executed that caused the event.

## Slate.Common.Schema

Slate `Schemas` define `Entity` events and properties with their events.

### EntitySchema

An `Entity` has an `EntitySchema` that contains information about the `Events` that affect the life cycle of the `Entity`. It also contains the `Schemas` for its `Properties`.

```elm
type alias EntitySchema =
    { type_ : String
    , eventNames : List String
    , properties : List PropertySchema
    }
```

* `type_` - The type of Entity.
* `eventNames` - A list of valid `Entity` event names.
* `properties` - A list of `PropertySchemas` for the `Entity`.

### PropertySchema

A `Property` of an `Entity` has its own `Schema`. A `Property` can be a primitive value, a `Value Object` or a list of either. It can also be another `Entity` to represent relationships.

There are 2 types of relationships, `Ownership` and `Non-ownership`.

```elm
type alias PropertySchema =
    { name : String
    , entitySchema : Maybe EntitySchemaReference
    , eventNames : List String
    , owned : Bool
    }
```

* `name` - `Property` name.
* `entitySchema` - An optional `Reference` to another `EntitySchema`.
* `eventNames` - Names of events that affect the life-cylce of this `Entity`.
* `owned` - Flag to denote ownership 
