module Slate.Common.Event
    exposing
        ( EventRecord
        , Event
        , EventData(..)
        , MutatingEventData
        , NonMutatingEventData
        , InitiatorId
        , Metadata
        , eventRecordDecoder
        , encodeMutatingEvent
        )

{-|
    Slate Event module

@docs EventRecord , Event, EventData , MutatingEventData, NonMutatingEventData, InitiatorId, Metadata , eventRecordDecoder, encodeMutatingEvent
-}

import Json.Encode as JE exposing (..)
import Json.Decode as JD exposing (..)
import Json.Decode.Extra as JDE exposing (..)
import Utils.Json as JsonU exposing (..)
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
    Initiator id.
-}
type alias InitiatorId =
    String


{-|
    Event metadata.
-}
type alias Metadata =
    { initiatorId : InitiatorId
    , command : String
    }


{-|
    Event Record decoder.
-}
eventRecordDecoder : JD.Decoder EventRecord
eventRecordDecoder =
    JD.succeed EventRecord
        <|| (field "id" JD.string)
        <|| (field "ts" JDE.date)
        <|| (field "event" eventDecoder)
        <|| (maybe (field "max" JD.string))


eventDecoder : JD.Decoder Event
eventDecoder =
    JD.succeed Event
        <|| (field "name" JD.string)
        <|| (maybe (field "version" JD.int))
        <|| (field "data" <| JD.oneOf [ mutatingEventDataDecoder, nonMutatingEventDataDecoder ])
        <|| (field "metadata" metadataDecoder)


{-|
    Event encoder.
-}
encodeMutatingEvent : Event -> String
encodeMutatingEvent event =
    case event.data of
        Mutating mutatingEventData ->
            JE.encode 0 <|
                JE.object
                    [ ( "name", JE.string event.name )
                    , ( "data", mutatingEventDataEncoder mutatingEventData )
                    , ( "metadata", metadataEncoder event.metadata )
                    ]

        NonMutating _ ->
            Debug.crash "Cannot encode NonMutating events"


mutatingEventDataDecoder : JD.Decoder EventData
mutatingEventDataDecoder =
    (JD.succeed MutatingEventData
        <|| (field "entityId" JD.string)
        <|| (maybe (field "value" JD.string))
        <|| (maybe (field "referenceId" JD.string))
        <|| (maybe (field "propertyId" JD.string))
        <|| (maybe (field "oldPosition" JD.int))
        <|| (maybe (field "newPosition" JD.int))
    )
        |> JD.andThen (\med -> JD.succeed <| Mutating med)


mutatingEventDataEncoder : MutatingEventData -> JE.Value
mutatingEventDataEncoder mutatingEventData =
    JE.object <|
        List.filter (\( _, value ) -> value /= JE.null)
            [ ( "entityId", JE.string mutatingEventData.entityId )
            , ( "value", encMaybe JE.string mutatingEventData.value )
            , ( "referenceId", encMaybe JE.string mutatingEventData.referenceId )
            , ( "propertyId", encMaybe JE.string mutatingEventData.propertyId )
            , ( "oldPosition", encMaybe JE.int mutatingEventData.oldPosition )
            , ( "newPosition", encMaybe JE.int mutatingEventData.newPosition )
            ]


nonMutatingEventDataDecoder : JD.Decoder EventData
nonMutatingEventDataDecoder =
    (JD.succeed NonMutatingEventData
        <|| (maybe (field "value" JD.string))
    )
        |> JD.andThen (\nmed -> JD.succeed <| NonMutating nmed)


metadataDecoder : JD.Decoder Metadata
metadataDecoder =
    JD.succeed Metadata
        <|| (field "initiatorId" JD.string)
        <|| (field "command" JD.string)


metadataEncoder : Metadata -> JE.Value
metadataEncoder metadata =
    JE.object
        [ ( "command", JE.string metadata.command )
        , ( "initiatorId", JE.string metadata.initiatorId )
        ]
