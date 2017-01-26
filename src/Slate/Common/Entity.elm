module Slate.Common.Entity
    exposing
        ( EntityReference
        , EntityDict
        )

{-|
    Slate Entity module

@docs EntityReference, EntityDict
-}

import Dict exposing (Dict)


{-|
    EntityReference type.
-}
type alias EntityReference =
    String


{-|
    Entity Dictionary.
-}
type alias EntityDict entity =
    Dict EntityReference entity
