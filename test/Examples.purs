-- Compile the documented pipelines without requiring the FluentCI runtime.
module Test.Examples where

import Prelude

import Control.Bind (bindFlipped)
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
  repo <- dag
    # git "https://github.com/tsirysndr/me"
    # bindFlipped (branch "main")
    # bindFlipped tree
    # bindFlipped (withExec [ "ls", "-ltr" ])
    # liftEffect
  repo # stdout >>= Console.log

build :: Effect Pipeline
build = dag
  # pipeline "build"
  # bindFlipped (Pipeline.withWorkdir "/app")
  # bindFlipped (Pipeline.withEnvVariable "CI" "true")
  # bindFlipped (withExec [ "npm", "ci" ])
  # bindFlipped (withExec [ "npm", "test" ])
