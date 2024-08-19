# FluentCI Purescript SDK

The FluentCI Purescript SDK is a library that provides a Purescript interface to the FluentCI API.

## 🚚 Installation

Add `fluentci` to your `spago.dhall` dependencies:

```dhall
{ name = "demo"
, dependencies = [ "aff", "console", "effect", "prelude", "fluentci" ]
, packages = ./packages.dhall
, sources = [ "src/**/*.purs", "test/**/*.purs" ]
}
```

And add the following to your `packages.dhall`:

```dhall
let upstream =
      https://github.com/purescript/package-sets/releases/download/psc-0.15.15-20240812/packages.dhall
        sha256:557dc416167543923d0f944fdc0c7bc3e0466b9467a8fc2fba0460f8d5425725

in  upstream
  with fluentci =
    { dependencies =
       [ "aff"
       , "console"
       , "effect"
       , "prelude"
       ]
    , repo =
        "https://github.com/fluentci-io/purescript-fluentci.git"
    , version =
        "eb4d502740c94c9026a96528d8f61b5228d5507c"
    }
```

Then install the package:

```bash
spago install
```

## 🚀 Quick Start

This is a quick start guide to get you up and running with the FluentCI Purescript SDK.

```purescript

module Main where

import Prelude

import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Class (liftEffect)
import Effect.Class.Console as Console
import FluentCI.Class (stdout, withExec)
import FluentCI.Client (dag, git)
import FluentCI.Git (branch, tree)

main :: Effect Unit
main = launchAff_ do
  repo <- liftEffect $ do
   g <- git dag "https://github.com/tsirysndr/me"
   g1 <- branch g "main"
   g2 <- tree g1
   withExec g2 ["ls", "-ltr"]
    
  stdout repo >>= Console.log
```
