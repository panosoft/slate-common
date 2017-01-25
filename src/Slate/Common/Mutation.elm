module Slate.Common.Mutation
    exposing
        ( MutationTagger
        , CascadingDeletionErrorTagger
        , CascadingDeletionTaggers
        , CascadingDelete
        , buildCascadingDelete
        , buildCascadingDeleteMsg
        , getConvertedValue
        , getIntValue
        , getFloatValue
        , getDateValue
        , getStringValue
        , getReference
        , updatePropertyValue
        , updatePropertyReference
        , updatePropertyList
        , positionPropertyList
        , appendPropertyList
        , setPropertyList
        )

{-|
    Slate Projection helpers.

    This module contains helpers for projection processing.

@docs MutationTagger, CascadingDeletionErrorTagger, CascadingDeletionTaggers, CascadingDelete, buildCascadingDelete, buildCascadingDeleteMsg, getConvertedValue, getIntValue, getFloatValue, getDateValue, getStringValue, getReference, updatePropertyValue, updatePropertyReference, updatePropertyList, positionPropertyList, appendPropertyList, setPropertyList

-}

import String exposing (..)
import Date exposing (..)
import Dict exposing (Dict)
import Maybe.Extra as MaybeE exposing (isNothing)
import Slate.Common.Reference exposing (..)
import Slate.Common.Event exposing (..)
import Slate.Common.Schema exposing (..)
import Utils.Ops exposing (..)
import Slate.Common.Event exposing (EventRecord, EventData(..), MutatingEventData)


{-|
    Mutation tagger.
-}
type alias MutationTagger msg =
    EventRecord -> msg


{-|
    Error tagger during building cascading deletion Msg.
-}
type alias CascadingDeletionErrorTagger msg =
    String -> String -> msg


{-|
    Cascading deletion taggers.
-}
type alias CascadingDeletionTaggers msg =
    Dict String (MutationTagger msg)


{-|
    Helper structure to communicated back from
-}
type alias CascadingDelete =
    { type_ : String
    , eventName : String
    , entityId : Maybe String
    }


{-|
    Build cascading delete structure.
-}
buildCascadingDelete : String -> String -> String -> Maybe String -> List PropertySchema -> Maybe CascadingDelete
buildCascadingDelete type_ deleteEventName eventName referenceId propertiesSchemas =
    let
        eventNames =
            propertiesSchemas
                |> List.filter .owned
                |> List.map .eventNames
                |> List.concat
    in
        case List.member eventName eventNames of
            True ->
                Just <| CascadingDelete type_ deleteEventName referenceId

            False ->
                Nothing


{-|
    Build projection Msg for cascading deletion.
-}
buildCascadingDeleteMsg : EventRecord -> CascadingDeletionTaggers msg -> CascadingDeletionErrorTagger msg -> CascadingDelete -> Maybe msg
buildCascadingDeleteMsg originatingEventRecord deletionTaggers errorTagger cascadingDelete =
    let
        maybeDeletionTagger =
            Dict.get cascadingDelete.type_ deletionTaggers

        mutatingEventData =
            case originatingEventRecord.event.data of
                Mutating mutatingEventData ->
                    mutatingEventData

                NonMutating nonMutatingEventData ->
                    Debug.crash "BUG -- Should never have gotten here"
    in
        cascadingDelete.entityId
            |?> (\entityId ->
                    maybeDeletionTagger
                        |?> (\deletionTagger ->
                                Just <|
                                    deletionTagger
                                        { id = "Cascading:" ++ originatingEventRecord.id
                                        , ts = originatingEventRecord.ts
                                        , event =
                                            { name = cascadingDelete.eventName
                                            , version = Nothing
                                            , data = Mutating <| MutatingEventData entityId Nothing Nothing Nothing Nothing Nothing
                                            , metadata = originatingEventRecord.event.metadata
                                            }
                                        , max = Nothing
                                        }
                            )
                        ?= (Just <| errorTagger cascadingDelete.type_ "Cannot determine Cascading Deletion Msg since deleteingTaggers doesn't support specified type.")
                )
            ?= Nothing



-- Getters from Event Data


{-|
    Convert value from event.
-}
getConvertedValue : (String -> Result String value) -> Event -> Result String value
getConvertedValue convert event =
    let
        value =
            case event.data of
                Mutating mutatingEventData ->
                    mutatingEventData.value

                NonMutating nonMutatingEventData ->
                    nonMutatingEventData.value
    in
        let
            result =
                checkValueExists event <| value
        in
            case result of
                Ok v ->
                    convert v

                Err msg ->
                    Err msg


{-|
   Get Int value from event
-}
getIntValue : Event -> Result String Int
getIntValue event =
    getConvertedValue String.toInt event


{-|
    Get Float value from event.
-}
getFloatValue : Event -> Result String Float
getFloatValue event =
    getConvertedValue String.toFloat event


{-|
    Get Date value from event.
-}
getDateValue : Event -> Result String Date
getDateValue event =
    getConvertedValue Date.fromString event


{-|
    Get Float value from event.
-}
getStringValue : Event -> Result String String
getStringValue event =
    getConvertedValue (Ok << identity) event


{-|
    Get Reference from event.
-}
getReference : Event -> Result String EntityReference
getReference event =
    case event.data of
        Mutating mutatingEventData ->
            checkReferenceExists event <| mutatingEventData.referenceId

        NonMutating _ ->
            Err "Non-mutating events don't have references"


{-|
    Check that a specified event item of the specified type exists.
-}
checkExists : String -> Event -> Maybe value -> Result String value
checkExists type_ event value =
    case value of
        Just v ->
            Ok v

        Nothing ->
            Err <| "Event data " ++ type_ ++ " is missing " ++ (toString event)


{-|
    Check value exists in event.
-}
checkValueExists : Event -> Maybe value -> Result String value
checkValueExists =
    checkExists "value"


{-|
    Check reference exists in event.
-}
checkReferenceExists : Event -> Maybe value -> Result String value
checkReferenceExists =
    checkExists "reference"


{-|
    Update entity property value.
-}
updatePropertyValue : (Event -> Result String value) -> (Maybe value -> entity -> entity) -> Event -> entity -> Result String entity
updatePropertyValue get update event entity =
    let
        value =
            get event
    in
        case value of
            Ok val ->
                Ok (update (Just val) entity)

            Err msg ->
                Err msg


{-|
    Update entity property reference.
-}
updatePropertyReference : (Maybe EntityReference -> entity -> entity) -> Event -> entity -> Result String entity
updatePropertyReference =
    updatePropertyValue getReference


{-|
    Update entity property list by appending (positioning is done by another event).
-}
updatePropertyList : (Event -> Result String listValue) -> (listValue -> entity -> entity) -> Event -> entity -> Result String entity
updatePropertyList get update event entity =
    let
        listValue =
            get event
    in
        case listValue of
            Ok listVal ->
                Ok (update listVal entity)

            Err msg ->
                Err msg


{-|
    Position entity property list.
-}
positionPropertyList : Maybe (List value) -> (Maybe (List value) -> entity -> entity) -> Event -> entity -> Result String entity
positionPropertyList maybeList update event entity =
    case event.data of
        Mutating mutatingEventData ->
            let
                list =
                    maybeList ?= []

                invalidMove =
                    newPosition >= length - 1 || oldPosition >= length

                errors =
                    (List.map (((++) " is missing") << snd) <| List.filter (isNothing << fst) [ ( mutatingEventData.oldPosition, "Old Position" ), ( mutatingEventData.newPosition, "New Position" ) ])
                        |> List.append (invalidMove ? ( [ "Positions are out of bounds" ++ (toString event) ], [] ))

                ( oldPosition, newPosition ) =
                    ( mutatingEventData.oldPosition ?= 0, mutatingEventData.newPosition ?= 0 )

                length =
                    List.length list
            in
                case errors == [] of
                    True ->
                        let
                            item =
                                List.take 1 (List.take oldPosition list)

                            removed =
                                List.append (List.take oldPosition list) (List.drop (oldPosition + 1) list)

                            inserted =
                                List.append (List.take oldPosition list) (List.append item <| List.drop oldPosition list)
                        in
                            Ok <| update (Just inserted) entity

                    False ->
                        Err <| String.join "\n" errors

        NonMutating _ ->
            Err "Non-mutating events don't have properties"



-- 1 2 [3] 4 5 6 7
-- old = 2
-- 1 2 4 5 6 7
-- new = 3
-- 1 2 4 [3] 5 6 7


{-|
    Append to a property list.
-}
appendPropertyList : Maybe (List listValue) -> listValue -> Maybe (List listValue)
appendPropertyList list value =
    Just <| List.append (list ?= []) [ value ]


{-|
    Append to a property list.
-}
setPropertyList : Maybe (List listValue) -> listValue -> Maybe (List listValue)
setPropertyList list value =
    Just [ value ]
