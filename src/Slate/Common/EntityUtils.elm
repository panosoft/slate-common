module Slate.Common.EntityUtils exposing (getValidEntity)

{-|
    Slate Entity Utility functions.

@docs getValidEntity
-}

import Utils.Ops exposing (..)


{-|
    Get a valid entity or errors depending on the supplied errorChecks.
-}
getValidEntity : List ( Bool, String ) -> entity -> Result (List String) entity
getValidEntity errorChecks entity =
    let
        errors =
            errorChecks
                |> List.filter fst
                |> List.map snd
    in
        (errors == []) ? ( Ok entity, Err errors )
