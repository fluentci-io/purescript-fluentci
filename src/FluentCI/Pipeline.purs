module FluentCI.Pipeline where

import Prelude

import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Compat (EffectFnAff, fromEffectFnAff)
import FluentCI.Cache (Cache)
import FluentCI.Devbox (Devbox)
import FluentCI.Devenv (Devenv)
import FluentCI.Envhub (Envhub)
import FluentCI.Flox (Flox)
import FluentCI.Hermit (Hermit)
import FluentCI.Mise (Mise)
import FluentCI.Nix (Nix, NixArgs)
import FluentCI.Pixi (Pixi)
import FluentCI.Pkgx (Pkgx)
import FluentCI.Proto (Proto)
import FluentCI.Secret (Secret)
import FluentCI.Service (Service)

data Pipeline

foreign import _id :: Pipeline -> EffectFnAff String

foreign import _stderr :: Pipeline -> EffectFnAff String

foreign import _stdout :: Pipeline -> EffectFnAff String

id :: Pipeline -> Aff String
id pipeline = fromEffectFnAff $ _id pipeline

stderr :: Pipeline -> Aff String
stderr pipeline = fromEffectFnAff $ _stderr pipeline

stdout :: Pipeline -> Aff String
stdout pipeline = fromEffectFnAff $ _stdout pipeline

foreign import asService :: Pipeline -> String -> Effect Service

foreign import waitOn :: Pipeline -> Int -> Int -> Effect Pipeline

foreign import devbox :: Pipeline -> Effect Devbox

foreign import devenv :: Pipeline -> Effect Devenv

foreign import envhub :: Pipeline -> Effect Envhub

foreign import mise :: Pipeline -> Effect Mise

foreign import nix :: Pipeline -> NixArgs -> Effect Nix

foreign import pixi :: Pipeline -> Effect Pixi

foreign import pkgx :: Pipeline -> Effect Pkgx

foreign import proto :: Pipeline -> Effect Proto

foreign import hermit :: Pipeline -> Effect Hermit

foreign import flox :: Pipeline -> Effect Flox


foreign import withCache :: Pipeline -> Cache -> Effect Pipeline

foreign import withEnvVariable :: Pipeline -> String -> String -> Effect Pipeline

foreign import withSecretVariable :: Pipeline -> String -> Secret -> Effect Pipeline

foreign import withExec :: Pipeline -> Array String -> Effect Pipeline

foreign import withService :: Pipeline -> Service -> Effect Pipeline

foreign import withWorkdir :: Pipeline -> String -> Effect Pipeline