module Slate.Common.Mutation
    exposing
        ( MutationTagger
        , CascadingDeletionErrorTagger
        , CascadingDeletionTaggers
        , CascadingDelete
        , buildCascadingDeleteMsg
        , processMutationResult
        , processCascadingMutationResult
        , buildCascadingDelete
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
        )

{-|
    Slate Projection helpers.

    This module contains helpers for projection processing.

@docs MutationTagger, CascadingDeletionErrorTagger, CascadingDeletionTaggers, CascadingDelete, buildCascadingDeleteMsg, processMutationResult, processCascadingMutationResult, buildCascadingDelete, getConvertedValue, getIntValue, getFloatValue, getDateValue, getStringValue, getReference, updatePropertyValue, updatePropertyReference, updatePropertyList, positionPropertyList

-}

import String exposing (..)
import Date exposing (..)
import Dict exposing (Dict)
import Maybe.Extra as MaybeE exposing (isNothing)
import Slate.Common.Entity exposing (..)
import Slate.Common.Event exposing (..)
import Slate.Common.Schema exposing (..)
import Utils.Ops exposing (..)
import Slate.Common.Event exposing (..)


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



----------------------------------------------------------
-- Event Procesing Helpers
----------------------------------------------------------


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
                    Debug.crash "BUG -- Non-mutating events cannot create cascading deletes"
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


{-|
    Helper for processing a non-cascading delete Mutation result from an Entity's handleMutation function that returns:
        Result String (EntityDict entity)
-}
processMutationResult : model -> (model -> EntityDict entity -> model) -> (model -> (String -> ( model, Cmd msg ))) -> Result String (EntityDict entity) -> ( model, Cmd msg )
processMutationResult model modelMutator errorHandler result =
    result
        |??> (\newDict -> modelMutator model newDict ! [])
        ??= errorHandler model


{-|
    Helper for processing a Cascading Delete Mutation result from an Entity's handleMutation function that returns:
        ( Result String (EntityDict entity), Maybe CascadingDelete )
-}
processCascadingMutationResult : model -> CascadingDeletionTaggers msg -> CascadingDeletionErrorTagger msg -> (msg -> model -> ( model, Cmd msg )) -> EventRecord -> (model -> EntityDict entity -> model) -> (model -> (String -> ( model, Cmd msg ))) -> ( Result String (EntityDict entity), Maybe CascadingDelete ) -> ( model, Cmd msg )
processCascadingMutationResult model deleteTaggers errorTagger update eventRecord modelMutator errorHandler ( mutationResult, maybeDelete ) =
    mutationResult
        |??>
            (\newDict ->
                let
                    newModel =
                        modelMutator model newDict

                    ( finalModel, cmd ) =
                        maybeDelete
                            |?> (\delete ->
                                    buildCascadingDeleteMsg eventRecord deleteTaggers errorTagger delete
                                        |?> (\msg -> update msg newModel)
                                        ?= (model ! [])
                                )
                            ?= (newModel ! [])
                in
                    newModel ! [ cmd ]
            )
        ??= errorHandler model



----------------------------------------------------------
-- Entity Mutation Helpers
----------------------------------------------------------


{-|
    Build cascading delete structure based on the `owned` field of the property schema.
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
    Convert value from event with specified function.
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
   Get Int value from event.
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
    Update Entire Entity property value.
-}
updatePropertyValue : (Event -> Result String value) -> (Maybe value -> entireEntity -> entireEntity) -> Event -> entireEntity -> Result String entireEntity
updatePropertyValue getter updater event entireEntity =
    let
        value =
            getter event
    in
        case value of
            Ok val ->
                Ok (updater (Just val) entireEntity)

            Err msg ->
                Err msg


{-|
    Update Entire Entity property reference.
-}
updatePropertyReference : (Maybe EntityReference -> entireEntity -> entireEntity) -> Event -> entireEntity -> Result String entireEntity
updatePropertyReference =
    updatePropertyValue getReference


{-|
    Update Entire Entity property list. Typically this is done by appending since positioning is done by another event.
-}
updatePropertyList : (Event -> Result String listValue) -> (listValue -> entireEntity -> entireEntity) -> Event -> entireEntity -> Result String entireEntity
updatePropertyList getter updater event entireEntity =
    let
        listValue =
            getter event
    in
        case listValue of
            Ok listVal ->
                Ok (updater listVal entireEntity)

            Err msg ->
                Err msg


{-|
    Position Entire Entity property list where the property at `event.data.oldPosition` is FIRST removed and then inserted to `event.data.newPosition`, e.g.:

    	A B [C] D E F G
    	oldPosition = 2
    	A B D E F G
    	newPosition = 3
    	A B D [C] E F G
-}
positionPropertyList : Maybe (List value) -> (Maybe (List value) -> entireEntity -> entireEntity) -> Event -> entireEntity -> Result String entireEntity
positionPropertyList maybeList updater event entireEntity =
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
                    ( mutatingEventData.oldPosition ?= -1, mutatingEventData.newPosition ?= -1 )

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
                            Ok <| updater (Just inserted) entireEntity

                    False ->
                        Err <| String.join "\n" errors

        NonMutating _ ->
            Err "Non-mutating events don't have properties"
