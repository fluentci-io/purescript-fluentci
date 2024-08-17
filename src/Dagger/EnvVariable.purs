module Dagger.EnvVariable where

import Effect.Aff.Compat (EffectFnAff)

data EnvVariable

foreign import _id :: EnvVariable -> EffectFnAff String

foreign import _name :: EnvVariable -> EffectFnAff String

foreign import _value :: EnvVariable -> EffectFnAff String