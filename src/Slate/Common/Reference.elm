module Slate.Common.Reference
    exposing
        ( lookupEntity
        , dereferenceEntity
        , entityReferenceEncode
        , entityReferenceDecoder
        )

{-|
    Slate Reference module.

    Slate relationships are stored internally as References.

@docs lookupEntity , dereferenceEntity , entityReferenceEncode , entityReferenceDecoder
-}

import Dict exposing (Dict)
import Json.Encode as JE exposing (..)
import Json.Decode as JD exposing (..)
import Slate.Common.Entity exposing (..)
import Slate.Common.Event exposing (..)
import Utils.Ops exposing ((?=))


{-|
    Lookup an event's referenced entity in an entity dictionary.
-}
lookupEntity : EntityDict entity -> Event -> entity -> entity
lookupEntity entities event default =
    case event.data of
        Mutating mutatingEventData ->
            dereferenceEntity entities (Just mutatingEventData.entityId) default

        NonMutating _ ->
            default


{-|
    Lookup an referenced entity in an entity dictionary.
-}
dereferenceEntity : EntityDict entity -> Maybe EntityReference -> entity -> entity
dereferenceEntity entities ref default =
    Dict.get (ref ?= "") entities ?= default


{-|
    EntityReference Json encoder.
-}
entityReferenceEncode : EntityReference -> JE.Value
entityReferenceEncode =
    JE.string


{-|
    EntityReference Json decoder.
-}
entityReferenceDecoder : Decoder EntityReference
entityReferenceDecoder =
    JD.string
