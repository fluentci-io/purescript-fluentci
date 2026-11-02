-- Compile the documented pipelines without requiring the FluentCI runtime.
module Test.Examples where

import Prelude

import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console as Console
import FluentCI.Class (stdout, withExec)
import FluentCI.Client (dag, git, pipeline)
import FluentCI.Git (branch, tree)
import FluentCI.Pipeline (Pipeline)
import FluentCI.Pipeline as Pipeline

quickStart :: Effect Unit
quickStart = launchAff_ do
  repo <- liftEffect $
    git "https://github.com/tsirysndr/me" dag
    >>= branch "main"
    >>= tree
    >>= withExec [ "ls", "-ltr" ]
  repo # stdout >>= Console.log

build :: Effect Pipeline
build =
  pipeline "build" dag
  >>= Pipeline.withWorkdir "/app"
  >>= Pipeline.withEnvVariable "CI" "true"
  >>= withExec [ "npm", "ci" ]
  >>= withExec [ "npm", "test" ]
