module Test.Main where

import Prelude

import Control.Bind (bindFlipped)

import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Console (log)
import Effect.Exception (throw)
import FluentCI.Cache (Cache)
import FluentCI.Git as Git
import FluentCI.Pipeline as Pipeline
import FluentCI.Secret (Secret)
import FluentCI.Service (Service)

foreign import fixture :: Effect Pipeline.Pipeline
foreign import calls :: Effect (Array String)
foreign import cache :: Cache
foreign import secret :: Secret
foreign import service :: Service
foreign import git :: Git.Git

assert :: String -> Boolean -> Effect Unit
assert message condition = unless condition (throw message)

main :: Effect Unit
main = launchAff_ do
  initial <- liftEffect fixture
  let
    build = initial
      # Pipeline.withWorkdir "/app"
      # bindFlipped (Pipeline.withEnvVariable "CI" "true")
      # bindFlipped (Pipeline.withExec [ "echo", "hello" ])
      # bindFlipped (Pipeline.waitOn 8080 30)
      # bindFlipped (Pipeline.withCache cache)
      # bindFlipped (Pipeline.withSecretVariable "TOKEN" secret)
      # bindFlipped (Pipeline.withService service)
  liftEffect do
    before <- calls
    assert "Constructing a chain must not execute its effects" (before == [])
  result <- liftEffect build
  output <- result # Pipeline.stdout
  liftEffect do
    assert "Each step must receive the preceding pipeline" (output == "stage 7")
    actual <- calls
    assert "Arguments and execution order must be preserved"
      (actual == [ "workdir:/app", "env:CI=true", "exec:echo,hello", "wait:8080:30", "cache:cache", "secret:TOKEN=secret", "service:service" ])
    void $ result # Pipeline.nix { impure: true }
    void $ result # Pipeline.asService "web"
    void $ git # Git.branch "main" # bindFlipped Git.tree
    final <- calls
    assert "Nix options, service names and Git branches must reach the SDK"
      (final == actual <> [ "nix:true", "asService:web", "branch:main", "tree:main" ])
    log "Pipeline chaining tests passed."
