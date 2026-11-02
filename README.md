# FluentCI PureScript SDK

The FluentCI PureScript SDK provides a PureScript interface to the FluentCI API.

## Development

Use Node.js 22.5 or newer, PureScript 0.15.16 and Spago 1.0.5:

```bash
npm install --global purescript@0.15.16 spago@1.0.5
spago build
spago test
```

Dependencies are configured in `spago.yaml`, with registry package set 81.11.0.
Commit `spago.lock` when dependencies change. Tests use SDK fixtures and do not
require a running FluentCI service.

## Installation

Add `fluentci` to your application's `spago.yaml` dependencies and configure the
Git dependency under `workspace.extraPackages`:

```yaml
package:
  name: demo
  dependencies:
    - aff
    - console
    - effect
    - fluentci
    - prelude
workspace:
  packageSet:
    registry: 81.11.0
  extraPackages:
    fluentci:
      git: https://github.com/fluentci-io/purescript-fluentci.git
      ref: main
```

For reproducible builds, replace `main` with a commit containing this migration.
Then run `spago install`. Execution requires a runtime that provides
`@fluentci/sdk` (and `@fluentci/sdk/dagger` when using the Dagger bindings).

## Quick start

Builder methods in `FluentCI.Class` and `FluentCI.Pipeline` take configuration
arguments first and the receiver last. `Client.git`, `Client.pipeline`, and
`Git.branch` follow the same convention.

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
  repo <- liftEffect $
    git "https://github.com/tsirysndr/me" dag
    >>= branch "main"
    >>= tree
    >>= withExec [ "ls", "-ltr" ]
  repo # stdout >>= Console.log
```

A named pipeline works the same way:

```purescript
import FluentCI.Client (dag, pipeline)
import FluentCI.Pipeline (withEnvVariable, withExec, withWorkdir)

-- Effect Pipeline
build =
  pipeline "build" dag
  >>= withWorkdir "/app"
  >>= withEnvVariable "CI" "true"
  >>= withExec [ "npm", "ci" ]
  >>= withExec [ "npm", "test" ]
```

`>>=` sequences each `Effect` and passes its result to the next builder.
It is exported by `Prelude`, so no additional import is needed.
Use `#` for ordinary value-to-function application. `liftEffect` runs the chain inside `Aff`,
and `stdout` evaluates the pipeline asynchronously.

### Migrating existing calls

The argument order changes are breaking: `withExec receiver args` becomes
`withExec args receiver`, or `receiver # withExec args`. Likewise,
`waitOn receiver port timeout` becomes `receiver # waitOn port timeout`.
Use `FluentCI.Class` for the common receiver-last builder API across environment
types. Other concrete environment modules and the Dagger API retain their
existing argument order.
