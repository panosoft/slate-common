module Slate.Common.Schema
    exposing
        ( EntitySchema
        , EntitySchemaReference(..)
        , PropertySchema
        , mtEntitySchema
        , mtPropSchema
        )

{-|
    Slate Schema module.

    Slate entity schemas are defined using this module.

@docs EntitySchema , EntitySchemaReference , PropertySchema , mtEntitySchema , mtPropSchema
-}


{-|
    Schema for the entity.
-}
type alias EntitySchema =
    { type_ : String
    , eventNames : List String
    , properties : List PropertySchema
    }


{-| this type is to handle mutually recursive definition between EntitySchema and PropertySchema
-}
type EntitySchemaReference
    = SchemaReference EntitySchema


{-|
    Schema for entity properties.
-}
type alias PropertySchema =
    { name : String
    , entitySchema : Maybe EntitySchemaReference
    , eventNames : List String
    , owned : Bool
    }


{-|
    Null entity schema.
-}
mtEntitySchema : EntitySchema
mtEntitySchema =
    { type_ = ""
    , eventNames = []
    , properties = []
    }


{-|
    Null entity property schema.
-}
mtPropSchema : PropertySchema
mtPropSchema =
    { name = ""
    , entitySchema = Nothing
    , eventNames = []
    , owned = False
    }
