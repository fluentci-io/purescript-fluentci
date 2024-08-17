module Dagger.CacheVolume where

import Effect.Aff.Compat (EffectFnAff)

data CacheVolume

foreign import _id :: CacheVolume -> EffectFnAff String