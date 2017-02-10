module Slate.Common.Utils
    exposing
        ( validateEntityEventName
        , validatePropertyEventName
        )

{-|
    Common utils for Slate code.

@docs validateEntityEventName, validatePropertyEventName
-}

import StringUtils exposing (..)
import Slate.Common.Event exposing (..)
import Slate.Common.Schema exposing (..)
import Utils.Ops exposing (..)


{-|
    Validate Entity Event Name (crashes if code is wrong to prevent bad events in DB)
-}
validateEntityEventName : EntitySchema -> Event -> Event
validateEntityEventName schema event =
    List.member event.name schema.eventNames ?! ( (\_ -> event), (\_ -> Debug.crash <| "Invalid event name:" +-+ event.name) )


{-|
    Validate Property Event Name (crashes if code is wrong to prevent bad events in DB)
-}
validatePropertyEventName : PropertySchema -> Event -> Event
validatePropertyEventName schema event =
    List.member event.name schema.eventNames ?! ( (\_ -> event), (\_ -> Debug.crash <| "Invalid event name:" +-+ event.name) )
