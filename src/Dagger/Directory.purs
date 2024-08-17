module Dagger.Directory where

import Dagger.Container (Container)
import Dagger.File (File)
import Dagger.Module (Module)
import Effect (Effect)
import Effect.Aff.Compat (EffectFnAff)
  
data Directory

foreign import _id :: Directory -> EffectFnAff String

foreign import asModule :: Directory -> Effect Module

foreign import diff :: Directory -> Directory -> Effect Directory

foreign import directory :: Directory -> String -> Effect Directory

foreign import dockerBuild :: Directory -> Effect Container

foreign import _entries :: Directory -> EffectFnAff (Array String)

foreign import _export ::  Directory -> EffectFnAff String

foreign import file :: Directory -> String -> Effect File

foreign import _glob :: Directory -> String -> EffectFnAff (Array String)

foreign import pipeline :: Directory ->  String -> Effect Directory

foreign import sync :: Directory -> Effect Directory

foreign import terminal :: Directory -> Effect Directory

foreign import withDirectory :: Directory -> String -> Directory -> Effect Directory

foreign import withFile :: Directory -> File -> Effect Directory

foreign import withFiles :: Directory -> Array File -> Effect Directory

foreign import withNewDirectory :: Directory -> String -> Effect Directory

foreign import withNewFile :: Directory -> String -> String -> Effect File

foreign import withTimestamps :: Directory -> Int -> Effect Directory

foreign import withoutDirectory :: Directory -> String -> Effect Directory

foreign import withoutFile :: Directory -> String -> Effect Directory