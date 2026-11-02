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

### Pure host plans (new engine API)

`FluentCI.Host.Plan` builds immutable data. Its receiver-last functions compose
with `#` without `Effect`, `bindFlipped`, or network requests:

```purescript
import Prelude
import FluentCI.Host.Plan as Plan

prepare = Plan.task "prepare" "npm" "/workspace/app"
  # Plan.withArgs [ "ci" ]
  # Plan.withResources [ "checkout:app" ]

lint = Plan.task "lint" "npm" "/workspace/app"
  # Plan.withArgs [ "run", "lint" ]
  # Plan.needs [ prepare ]

test = Plan.task "test" "npm" "/workspace/app"
  # Plan.withArgs [ "test" ]
  # Plan.needs [ prepare ]

build = Plan.plan [ prepare, lint, test ]
  # Plan.withJobs 2
```

Plans use explicit environments (`inherit_env: false`). Set needed variables,
including `PATH` when launching tools by name, with `Plan.withEnv`. Branching from
one task never changes it; dependencies refer to stable task IDs. `Plan.compile`
returns `Either PlanError String`, suitable for storing or sending as the engine's
versioned JSON plan. Structural errors are checked locally; the engine additionally
checks cycles, paths, cache contracts, and service/resource constraints.

For direct execution without a daemon, use the Node adapter:

```purescript
import FluentCI.Host.Local as Local

-- Aff (Either RunError LocalResult)
executeBuild = Local.execute build
  { binary: "/path/to/fluentci-engine/target/release/fluentci-engine"
  , runRoot: "/path/to/pipeline-runs"
  , progress: Local.Auto
  }
```

Each invocation gets a fresh run directory containing the plan and result files.
Relative task/cache/resource paths resolve from the Node process working directory.
Logs use the engine's live progress renderer. Cancelling this `Aff` signals the
engine and waits for child/service cleanup. Failed tasks return a typed report;
configuration, transport, or decoding failures return `Left`.

For server execution, use `FluentCI.Host.Client` with the new authenticated
`serve-runs` command (the legacy GraphQL `serve` endpoint is separate):

```purescript
import FluentCI.Host.Client as Host

engine = Host.client
  { baseUrl: "http://127.0.0.1:6881"
  , token: "read-this-from-your-environment"
  , timeoutMs: 5000
  }

-- Aff (Either RunError Run)
submitBuild = engine # Host.submit build
```

Use `Host.status`, `Host.result`, `Host.cancel`, and `Host.events` with the returned
run handle. `Host.runId` and `Host.resumeRun` support persisted handles. Run/task
statuses are algebraic data types; journal events remain `Json` so newer event
fields can be consumed without an SDK release. `Host.logs` returns exact bytes
(`Array Int`) for stdout/stderr, indexed by the task's position in the plan.
Event/log cursors are strings, preserving offsets beyond the PureScript `Int` range.

HTTP requests have deadlines and abort when their `Aff` is cancelled. Aborting an
HTTP request does not cancel an already accepted remote run: use `Host.cancel` for
that. Submissions are never automatically retried; a connection failure can leave
acceptance uncertain until server-side idempotency is available. Bearer tokens are
not forwarded through redirects. The API requires absolute server paths.

`Plan.withCache`, `Plan.asService`, `Plan.withResources`, and their configuration
helpers encode the same caching, service readiness/health, and cross-run lease
contracts as the host executor. `FluentCI.Pipeline` and the existing SDK remain
available unchanged; migration to host plans is opt-in.

Tests:

```sh
spago build --pedantic-packages
spago test
node --test test/host_transport.mjs
# Build the sibling engine with cargo build --release first, or set this binary:
FLUENTCI_ENGINE_BIN=/path/to/release/fluentci-engine python3 test/e2e_host.py
```

The end-to-end test covers direct local execution and cancellation, a remote
diamond, literal arguments/environment values, typed errors, cache hits, services,
resumable events/raw logs, and remote cancellation. The GitHub SDK workflow runs
pure and transport tests; the cross-repository engine integration test is currently
run locally with an explicitly supplied release engine binary.

### Native package providers

Package managers are explicit plan data too:

```purescript
ports = Plan.provider Plan.MacPortsRust
  # Plan.withProviderExecutable "/usr/local/bin/port"

packages = Plan.install "packages" "/workspace/app" ports [ "jq" ]

check = Plan.task "check" "jq" "/workspace/app"
  # Plan.withArgs [ "--version" ]
  # Plan.needs [ packages ]
  # Plan.withPackageEnvironment [ ports ]

packagePlan = Plan.plan [ packages, check ]
```

Provider kinds are `Homebrew`, `MacPortsNative`, `MacPortsRust`, `FreeBSD`,
`NetBSD`, and `OpenBSD`. The engine enforces the supported host platforms and
requires managers to be provisioned explicitly. Consumer environments are local
to their tasks. Prefix updates take exclusive leases; consumers use shared leases
and can run concurrently. `Plan.withSharedResources` is also available for other
cooperating read-only consumers.

Install tasks are deliberately uncached. Depending on an installation step prevents
cross-run consumer cache hits; use a separately provisioned, explicitly identified
toolchain when caching consumers. Omitting `Plan.needs [ packages ]` does not imply
installation ordering: the dependency graph remains explicit.

The integration test uses a harmless fixture executable for package tasks; real
package installation tests belong on disposable native CI hosts.
