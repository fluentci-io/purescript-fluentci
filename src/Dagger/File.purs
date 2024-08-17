module Dagger.File where

import Effect (Effect)
import Effect.Aff.Compat (EffectFnAff)
  
data File

foreign import _id :: File -> EffectFnAff String

foreign import _contents :: File -> EffectFnAff String

foreign import _digest :: File -> EffectFnAff String

foreign import _export :: File -> String -> EffectFnAff String

foreign import _name :: File -> EffectFnAff String

foreign import _size :: File -> EffectFnAff Int

foreign import _sync :: File -> EffectFnAff File

foreign import withName :: File -> String -> Effect File

foreign import withTimestamps :: File -> Int-> Effect File


