module Slate.Common.Projection
    exposing
        ( ProjectionErrors
        , projectMap
        , successfulProjections
        , failedProjections
        , allFailedProjections
        )

{-|
    Slate Projection helpers.

    This module contains helpers for projection processing.

@docs  ProjectionErrors, projectMap , successfulProjections , failedProjections , allFailedProjections
-}

import Dict exposing (Dict)
import Result.Extra as ResultE exposing (isOk)
import Utils.Dict as DictU
import Utils.Result as ResultU


{-|
    Projection errors.
-}
type alias ProjectionErrors x =
    List (List x)


{-|
    Map function for projections.
-}
projectMap : (a -> b) -> (Dict comparable a -> Dict comparable b)
projectMap f =
    Dict.map (\_ value -> f value)


{-|
    Filter successful projections.
-}
successfulProjections : Dict comparable (Result (List x) a) -> Dict comparable a
successfulProjections dictResult =
    let
        okDict =
            Dict.filter (\_ maybe -> isOk maybe) dictResult
    in
        DictU.zip (Dict.keys okDict)
            (ResultU.filterOk <| Dict.values okDict)


{-|
    Filter failed projections.
-}
failedProjections : Dict comparable (Result (List x) b) -> ProjectionErrors x
failedProjections =
    ResultU.filterErr << Dict.values


{-|
    Filter all failed projections from a list of projection results.
-}
allFailedProjections : List (ProjectionErrors x) -> List x
allFailedProjections =
    List.concat << (List.map List.concat)
