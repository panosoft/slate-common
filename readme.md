# Slate Common Modules

> Common Slate modules that are used by multiple Slate libraries and Slate Apps.

## Install

### Elm

Since the Elm Package Manager doesn't allow for Native code and most everything we write at Panoramic Software has some native code in it,
you have to install this library directly from GitHub, e.g. via [elm-github-install](https://github.com/gdotdesign/elm-github-install) or some equivalent mechanism. It's just not worth the hassle of putting libraries into the Elm package manager until it allows native code.

## Example code

Many of the examples shown in the documentation uses infix operators from [elm-utils](https://github.com/panosoft/elm-utils#operators).

## Slate.Common.Entity

An `Entity` is similar to an Elm record or a Javascript Object without all the baggage. Entities have `Properties` which have values.

There are 2 versions of every `Entity` in Slate. The `Entire Entity` and the `Partial Entity`.

An `Entire Entity` is a record where every field is a `Maybe`, (except Lists since they can be empty) e.g.:

```elm
type alias EntirePerson =
    { name : Maybe Name
    , age : Maybe Int
    , address : Maybe EntityReference
    }
```

This is typically defined in the `Entity's` module.

A `Partial Entity` is the concrete subset of the `Entire Entity` that contains only the things of interest, e.g. a possible partial for the canonical entire might be:

```elm
type alias Person =
    { name : PersonEntity.Name
    , address : Address
    }
```

Notice that `Maybe's` are no longer needed since all of the `Partial Entity's` fields are expected to exist.

The following are helpful definitions.

### EntityReference

A reference to an Entity which is actually just the Entity's Id.

```elm
type alias EntityReference =
    String
```

### EntityDict

A Dictionary of Entites.

```elm
type alias EntityDict entity =
    Dict EntityReference entity
```

## Slate.Common.Event

Since `Slate` is an Event Sourced DB, it stores `Events`.

### Event Record

A Slate `EventRecord` represents a single row of a `Query Result` from `SQL Query` on the `events` table in the Slate Database:

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
* `version` - The OPTIONAL version of the `Event` used to aid in `Entity Schema Migration`.
* `data` - The data that's specific to the `Event` (see [EventData](#eventdata))

#### eventRecordDecoder

Event Record decoder.

```elm
eventRecordDecoder : JD.Decoder EventRecord
eventRecordDecoder
```
This is for decoding a full Event Record when it's retrieved from the database.

#### encodeMutatingEvent

Event encoder.

```elm
encodeMutatingEvent : Event -> String
encodeMutatingEvent event =
```

This is for encoding an event before it's written to the database.

### EventData

It is worth noting that there are 2 types of Events in Slate, `Mutating Events` and `Non-mutating Events`.

`Mutating Events` are events that mutate `Entities`.

`Non-mutating Events` are events where a user performs an operation worth noting, e.g. for security reasons.

They only differ in the `EventData`.

```elm
type EventData
    = Mutating MutatingEventData
    | NonMutating NonMutatingEventData
```

`MutatingEventData` supports `Entities` with `Properties`. Each `Property` can be a primitive type, a `Value Object` or a list of either.

A `Value Object` is a JSON string and is atomic, i.e. the whole object is mutated by a SINGLE event. In contrast, parts of an `Entity` can be mutated independently.

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
* `value` - An OPTIONAL String value. If this event involves adding or changing a property's value that's a `Value Object`, then this is a JSON string.
* `referenceId` - If the event involves a relationship between this `Entity` and another, then this is the globally unique id of the other `Entity`.
* `propertyId` - The id of a list property.
* `oldPosition` - The Old Position of a property within a list for events that reorder a list of `Properties`.
* `newPosition` - The New Position of a property within a list for events that reorder a list of `Properties`.

`NonMutatingEventData` is a simple event with an optional JSON String `value` allowing for future flexibility of the structure. They do not relate to `Entities` like `Mutating Events` do.

And therefore, these types of `Events` will not be queried using [slate-query-engine](https://github.com/panosoft/slate-query-engine).

They merely provide information about Operational Events.

```elm
type alias NonMutatingEventData =
    { value : Maybe String
    }
```

* `value` - An optional JSON String.

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

Slate `Schemas` define `Entities` and their `Properties`.

### EntitySchema

An `Entity` has an `EntitySchema` that contains information about the `Events` that affect the life-cycle of the `Entity`. It also contains the `Schemas` for its `Properties`.

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

It contains information about the `Events` that affect the life-cycle of the `Property`.

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
* `entitySchema` - An OPTIONAL `Reference` to another `EntitySchema`.
* `eventNames` - Names of events that affect the life-cylce of this `Entity`.
* `owned` - Flag to denote ownership (must be `True` to support Cascading Deletes in the `Query Engine`, [slate-query-engine](https://github.com/panosoft/slate-query-engine))

### Empty Schema Records

The following are empty Schema records to make defining schema more terse (see their usage in [slate-test-entities](https://github/panosoft/slate-test-entities))

```elm
mtEntitySchema : EntitySchema
mtEntitySchema =
    { type_ = ""
    , eventNames = []
    , properties = []
    }

mtPropSchema : PropertySchema
mtPropSchema =
    { name = ""
    , entitySchema = Nothing
    , eventNames = []
    , owned = False
    }
```

## Slate.Common.Mutation

This module contains many helpers for doing mutations. There are 2 types of helpers. Ones that aid in the writing of Entity mutations and ones that are used during Event Processing.

### Entity Dictionary Mutation

`Event Processing` is the process of reading events from the Slate database and creating or destroying `Entities` or mutating existing ones.

During the `Entity Dictionary Mutation`, a single `Entity` will be mutated. If an `Entity` has been created, it will be inserted into the `Entity Dictionary`. If an `Entity` has been destroyed it will be removed from the `Entity Dictionary`. If an `Entity` has been mutated then `Entity` will be replaced with the mutated one.

The following functions reduce the code necessary to process these `Entity` events to build an `Entire Entity`.

Most `Entity Dictionary Mutation` code will be written using either `processMutationResult` or `processCascadingMutationResult` where `processMutationResult` will be used 95% of the time.

For details on `Entity Mutation` see [Entity Mutation](#entity-mutation).

#### buildCascadingDeleteMsg

Build projection Msg for cascading deletion. This is usually not called directly by code that uses [slate-query-engine](https://github.com/panosoft/slate-query-engine). It is part of the API for code that processes events without it.

```elm
buildCascadingDeleteMsg : EventRecord -> CascadingDeletionTaggers msg -> CascadingDeletionErrorTagger msg -> CascadingDelete -> Maybe msg
buildCascadingDeleteMsg originatingEventRecord deletionTaggers errorTagger cascadingDelete
```

__Usage__

```elm
buildCascadingDeleteMsg eventRecord deleteTaggers errorTagger delete
```
See implementation for [processCascadingMutationResult](#processCascadingMutationResult) for usage in context.

#### processMutationResult

Helper for processing a non-cascading delete Mutation result from an Entity's handleMutation function that returns:
	Result String (EntityDict entity)

```elm
processMutationResult : model -> (model -> EntityDict entity -> model) -> (model -> (String -> ( model, Cmd msg ))) -> Result String (EntityDict entity) -> ( model, Cmd msg )
processMutationResult model modelMutator errorHandler result
```

This function should be used to process `Entity` events for `Entities` that do NOT own other `Entities` because this function does NOT support cascading deletes (see [processCascadingMutationResult](#processCascadingMutationResult)).

__Usage__

```elm
import Slate.Common.Mutation as Mutation

mutationError : String -> Model -> (String -> ( Model, Cmd Msg ))
mutationError type_ model =
    (\err -> update (MutationError type_ err) model)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        updateEngine : Engine.Msg -> Model -> ( Model, Cmd Msg )
        updateEngine =
            ParentChildUpdate.updateChildApp (Engine.update engineConfig) update .engineModel SlateEngine (\model engineModel -> { model | engineModel = engineModel })

        processMutationResult =
            Mutation.processMutationResult model
    in
		case msg of
			MutateAddress eventRecord ->
				AddressEntity.handleMutation model.entireAddresses eventRecord.event
					|> processMutationResult
						(\model newDict -> { model | entireAddresses = newDict })
						(mutationError "Address")
```

#### processCascadingMutationResult

Helper for processing a Cascading Delete Mutation result from an Entity's handleMutation function that returns:
	( Result String (EntityDict entity), Maybe CascadingDelete )

```elm
processCascadingMutationResult : model -> CascadingDeletionTaggers msg -> CascadingDeletionErrorTagger msg -> (msg -> model -> ( model, Cmd msg )) -> EventRecord -> (model -> EntityDict entity -> model) -> (model -> (String -> ( model, Cmd msg ))) -> ( Result String (EntityDict entity), Maybe CascadingDelete ) -> ( model, Cmd msg )
processCascadingMutationResult model deleteTaggers errorTagger update eventRecord modelMutator errorHandler ( mutationResult, maybeDelete )
```

This function should be used to process `Entity` events for `Entities` that do own other `Entities`.

__Usage__

```elm
import Slate.Common.Mutation as Mutation exposing (CascadingDeletionTaggers)

mutationError : String -> Model -> (String -> ( Model, Cmd Msg ))
mutationError type_ model =
    (\err -> update (MutationError type_ err) model)

deleteTaggers : CascadingDeletionTaggers Msg
deleteTaggers =
    Dict.fromList [ ( "Address", MutateAddress ) ]

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        updateEngine : Engine.Msg -> Model -> ( Model, Cmd Msg )
        updateEngine =
            ParentChildUpdate.updateChildApp (Engine.update engineConfig) update .engineModel SlateEngine (\model engineModel -> { model | engineModel = engineModel })

        processCascadingMutationResult =
            Mutation.processCascadingMutationResult model
                deleteTaggers
                MutationError
                update
    in
		case msg of
			MutatePerson eventRecord ->
				PersonEntity.handleMutation model.entirePersons model.entireAddresses eventRecord.event
					|> processCascadingMutationResult
						eventRecord
						(\model newDict -> { model | entirePersons = newDict })
						(mutationError "Person")
```

#### MutationTagger

Mutation tagger.

```elm
type alias MutationTagger msg =
    EventRecord -> msg
```

This is the definition of a tagger that will create a mutation Msg.

#### CascadingDeletionErrorTagger

Error tagger during building cascading deletion Msg.

```elm
type alias CascadingDeletionErrorTagger msg =
    String -> String -> msg
```

#### CascadingDeletionTaggers

Cascading deletion taggers.

```elm
type alias CascadingDeletionTaggers msg =
    Dict String (MutationTagger msg)
```

A dictionary of `Entity Type` and the appropriate tagger for that type. This is used in Cascading Deletes. (see `deleteTaggers` in the Usage section of [processCascadingMutationResult](#processcascadingmutationresult)).

#### CascadingDelete

Cascading Delete definition.

```elm
type alias CascadingDelete =
    { type_ : String
    , eventName : String
    , entityId : Maybe String
    }
```

This defines a Cascading Delete that must be performed.

* `type_` - This is the Entity type.
* `eventName` - Event name to trigger the deletion, usually in the form "<entity-type> destroyed", e.g. "Address destroyed".
* `entityId` - Specific entity to delete.


### Entity Mutation

During `Event Processing`, each `Event` will mutate an `Entity`.

Every `Entity's` implementation must support 2 functions, `handleMutation` and `mutate`. These functions will take a single `Event` and an `Entity` and mutate it.

To see how these functions should be implemented see [slate-test-entities](https://github.com/panosoft/slate-test-entities), specifically `PersonEntity.elm` and `AddressEntity.elm`.

The `mutate` function can leverage the following Mutation helper functions:

#### buildCascadingDelete

Build cascading delete structure based on the `owned` field of the property schema.

```elm
buildCascadingDelete : String -> String -> String -> Maybe String -> List PropertySchema -> Maybe CascadingDelete
buildCascadingDelete type_ deleteEventName eventName referenceId propertiesSchemas
```
This is used within an Entity's standard `mutation` function (see [slate-test-entities](https://github.com/panosoft/slate-test-entities) implementation for the `Person Entity`).

__Usage__

```elm
buildCascadingDelete "Address" "Address destroyed" event.name entity.address personProperties
```

See [slate-test-entities](https://github/panosoft/slate-test-entities) for usage in context.

#### getConvertedValue

Convert value from event with specified function.

```elm
getConvertedValue : (String -> Result String value) -> Event -> Result String value
getConvertedValue convert event
```

__Usage__

```elm
getIntValue : Event -> Result String Int
getIntValue event =
    getConvertedValue String.toInt event
```

#### getIntValue

Get Int value from event.

```elm
getIntValue : Event -> Result String Int
getIntValue event
```

#### getFloatValue

Get Float value from event.

```elm
getFloatValue : Event -> Result String Float
getFloatValue event
```

#### getDateValue

Get Date value from event.

```elm
getDateValue : Event -> Result String Date
getDateValue event
```

#### getStringValue

Get Float value from event.

```elm
getStringValue : Event -> Result String String
getStringValue event
```

#### getReference

Get Reference from event.

```elm
getReference : Event -> Result String EntityReference
getReference event
```

#### checkExists

Check that a specified event item of the specified type exists.

```elm
checkExists : String -> Event -> Maybe value -> Result String value
checkExists type_ event value
```

#### checkValueExists

Check value exists in event.

```elm
checkValueExists : Event -> Maybe value -> Result String value
checkValueExists event value
```


#### checkReferenceExists

Check reference exists in event.

```elm
checkReferenceExists : Event -> Maybe value -> Result String value
checkReferenceExists event value
```

#### updatePropertyValue

Update Entire Entity property value.

```elm
updatePropertyValue : (Event -> Result String value) -> (Maybe value -> entireEntity -> entireEntity) -> Event -> entireEntity -> Result String entireEntity
updatePropertyValue getter updater event entireEntity
```

__Usage__

See [slate-test-entities](https://github/panosoft/slate-test-entities) for usage in context.

#### updatePropertyReference

Update Entire Entity property reference.

```elm
updatePropertyReference : (Maybe EntityReference -> entireEntity -> entireEntity) -> Event -> entireEntity -> Result String entireEntity
updatePropertyReference updater event entireEntity
```

__Usage__

See [slate-test-entities](https://github/panosoft/slate-test-entities) for usage in context.

#### updatePropertyList

Update Entire Entity property list. Typically this is done by appending since positioning is done by another event.

```elm
updatePropertyList : (Event -> Result String listValue) -> (listValue -> entireEntity -> entireEntity) -> Event -> entireEntity -> Result String entireEntity
updatePropertyList getter updater event entireEntity
```

__Usage__

See [slate-test-entities](https://github/panosoft/slate-test-entities) for usage in context.

#### positionPropertyList

Position Entire Entity property list where the property at `event.data.oldPosition` is FIRST removed and then inserted to `event.data.newPosition`, e.g.:

	A B [C] D E F G
	oldPosition = 2
	A B D E F G
	newPosition = 3
	A B D [C] E F G

```elm
positionPropertyList : Maybe (List value) -> (Maybe (List value) -> entireEntity -> entireEntity) -> Event -> entireEntity -> Result String entireEntity
positionPropertyList maybeList updater event entireEntity
```

__Usage__

See [slate-test-entities](https://github/panosoft/slate-test-entities) for usage in context.


## Slate.Common.Projection

Projection in Slate is the process of mapping from an `Entire Entity` to a `Partial Entity`.

During `Event` Processing, all `Events` mutate an `Entire Entity Dictionary` and when that process is complete, a projection from the `Entire Entity Dictionary` to a `Partial Entity Dictionary` can be performed.

Since the `Query Engine` was designed with `Entity Dictionaries` in mind (as will most code that performs similar functions as the Engine), these helper functions work with Dictionaries.

#### getValidEntity

Get a valid entity or errors depending on the supplied errorChecks.

```elm
getValidEntity : List ( Bool, String ) -> entity -> Result (ProjectionErrors) entity
getValidEntity errorChecks entity
```

__Usage__

```elm
import Maybe.Extra as MaybeE exposing (isNothing)

type alias Address =
    { street : String
    }

defaultAddress : Address
defaultAddress =
    { street = defaultEntireAddress.street
    }

toAddress : EntireAddress -> Result (List String) Address
toAddress entireAddress =
    getValidEntity
        [ ( isNothing entireAddress.street, "street is missing" )
        ]
        { street = entireAddress.street ?= defaultAddress.street
        }
```

#### projectMap

Creates a Dictionary map function for projections from an `Entity Projection` function.

```elm
projectMap : (entireEntity -> partialEntity) -> (Dict comparable entireEntity -> Dict comparable partialEntity)
projectMap f
```

__Usage__

```elm
addresses : Model -> Dict String (Result (List String) Address)
addresses model =
	projectMap toAddress model.entireAddresses
```
In this example, `toAddress` is the `Entity Projection` function. See [getValidEntity's Usage](#getvalidentity) for implementation of `toAddress`.

#### successfulProjections

Filter successful projections.

```elm
successfulProjections : Dict comparable (Result (ProjectionErrors) a) -> Dict comparable a
successfulProjections dictResult
```

__Usage__

```elm
{-|
	Project entire addresses to addresses.
-}
addresses : Model -> Dict String (Result (ProjectionErrors) Address)
addresses =
	projectMap toAddress model.entireAddresses

{-|
	Project entire persons to persons.
-}
persons : Model -> Dict String (Result (ProjectionErrors) Person
persons =
	projectMap (toPerson <| successfulProjections addresses) model.entirePersons

{-|
	Update model with persons and addresses from their projects from their entire counterparts.
-}
newModel : Model -> Dict String (Result (ProjectionErrors) Person -> Dict String (Result (ProjectionErrors) Address) -> Model
newModel model persons addresses =
	{ model | persons = successfulProjections persons, addresses = successfulProjections addresses }
```

#### failedProjections

Filter failed projections.

```elm
failedProjections : Dict comparable (Result (ProjectionErrors) b) -> DictProjectionErrors
failedProjections
```

__Usage__

```elm
addressProjectionErrors : DictProjectionErrors
addressProjectionErrors =
	failedProjections addresses
```

#### allFailedProjections

Filter all failed projections from a list of dictionary projection results.

```elm
allFailedProjections : List (DictProjectionErrors) -> ProjectionErrors
allFailedProjections
```

__Usage__

```elm
allErrors : ProjectionErrors
allErrors =
	allFailedProjections [ failedProjections addresses, failedProjections persons ]
```

## Slate.Common.Reference

An `Entity Reference` is simply an `entityId`. This is used for the `key` in the `Entity Dictionaries`.

The following are helper functions for dealing with references and their dictionaries.

#### lookupEntity

Lookup an event's referenced entity in an entity dictionary.

```elm
lookupEntity : EntityDict entity -> Event -> entity -> entity
lookupEntity entities event default
```

__Usage__

See [slate-test-entities](https://github/panosoft/slate-test-entities) for usage in context.

#### dereferenceEntity

Lookup an referenced entity in an `Entity Dictionary`.

```elm
dereferenceEntity : EntityDict entity -> Maybe EntityReference -> entity -> entity
dereferenceEntity entities ref default
```

#### entityReferenceEncode

EntityReference JSON encoder.

```elm
entityReferenceEncode : EntityReference -> Json.Encode.Value
entityReferenceEncode
```

#### entityReferenceDecoder

EntityReference JSON decoder.

```elm
entityReferenceDecoder : Decoder EntityReference
entityReferenceDecoder
```
