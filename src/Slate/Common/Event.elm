module Slate.Common.Event
    exposing
        ( EventRecord
        , Event
        , EventData(..)
        , MutatingEventData
        , NonMutatingEventData
        , Metadata
        , eventRecordDecoder
        )

{-|
    Slate Event module

@docs EventRecord , Event, EventData , MutatingEventData, NonMutatingEventData, Metadata , eventRecordDecoder
-}

import Json.Decode as Json exposing (..)
import Json.Decode.Extra exposing (..)
import Utils.Json as JsonU exposing ((///), (<||))
import Date exposing (Date)


{-|
    Slate Event DB record.
-}
type alias EventRecord =
    { id : String
    , ts : Date
    , event : Event
    , max : Maybe String
    }


{-|
    Slate Event.
-}
type alias Event =
    { name : String
    , version : Maybe Int
    , data : EventData
    , metadata : Metadata
    }


{-|
    Slate Event data.
-}
type EventData
    = Mutating MutatingEventData
    | NonMutating NonMutatingEventData


{-|
    Mutating event data.
-}
type alias MutatingEventData =
    { entityId : String
    , value : Maybe String
    , referenceId : Maybe String
    , propertyId : Maybe String
    , oldPosition : Maybe Int
    , newPosition : Maybe Int
    }


{-|
    Mutating event data.
-}
type alias NonMutatingEventData =
    { value : Maybe String
    }


{-|
    Event metadata.
-}
type alias Metadata =
    { initiatorId : String
    , command : String
    }


{-|
    Event Record decoder.
-}
eventRecordDecoder : Json.Decoder EventRecord
eventRecordDecoder =
    Json.succeed EventRecord
        <|| ("id" := string)
        <|| ("ts" := date)
        <|| ("event" := eventDecoder)
        <|| (maybe ("max" := string))


eventDecoder : Json.Decoder Event
eventDecoder =
    Json.succeed Event
        <|| ("name" := string)
        <|| (maybe ("version" := int))
        <|| ("data" := oneOf [ mutatingEventDataDecoder, nonMutatingEventDataDecoder ])
        <|| ("metadata" := metadataDecoder)


mutatingEventDataDecoder : Json.Decoder EventData
mutatingEventDataDecoder =
    (Json.succeed MutatingEventData
        <|| ("entityId" := string)
        <|| (maybe ("value" := string))
        <|| (maybe ("referenceId" := string))
        <|| (maybe ("propertyId" := string))
        <|| (maybe ("oldPosition" := int))
        <|| (maybe ("newPosition" := int))
    )
        `Json.andThen` (\med -> Json.succeed <| Mutating med)


nonMutatingEventDataDecoder : Json.Decoder EventData
nonMutatingEventDataDecoder =
    (Json.succeed NonMutatingEventData
        <|| (maybe ("value" := string))
    )
        `Json.andThen` (\nmed -> Json.succeed <| NonMutating nmed)


metadataDecoder : Json.Decoder Metadata
metadataDecoder =
    Json.succeed Metadata
        <|| ("initiatorId" := string)
        <|| ("command" := string)
