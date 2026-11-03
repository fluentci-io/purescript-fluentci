module FluentCI.Plugin
  ( Pipeline, pipeline, exec, shell, withWorkdir, withEnv, stdout, stderr ) where

import Data.Either (Either(..))
import Effect (Effect)

-- Guest-only values. Execution calls FluentCI's exposed PDK functions.
foreign import data Pipeline :: Type
foreign import pipeline :: String -> Pipeline
foreign import exec :: Array String -> Pipeline -> Pipeline
foreign import shell :: String -> Pipeline -> Pipeline
foreign import withWorkdir :: String -> Pipeline -> Pipeline
foreign import withEnv :: String -> String -> Pipeline -> Pipeline
foreign import runImpl
  :: (String -> Either String String)
  -> (String -> Either String String)
  -> Boolean
  -> Pipeline
  -> Effect (Either String String)

stdout :: Pipeline -> Effect (Either String String)
stdout = runImpl Left Right false

stderr :: Pipeline -> Effect (Either String String)
stderr = runImpl Left Right true
