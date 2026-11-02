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


For retryable remote submissions, retain a unique key and the same immutable plan:

```purescript
submitRelease = engine # Host.submitWithKey "release-2026-001" build
```

Retrying this call returns the same run, including after a server restart. A key
used with a different plan returns `HttpError 409`; keys do not expire automatically.
Use a new key only when you intend another execution. The SDK checks the server's
key acknowledgement and rejects responses from older engines that ignore the
header. Such a request may already have started a run, so an acknowledgement error
must not trigger automatic retries. Ordinary `submit` retains its existing behavior
and does not automatically retry ambiguous transport failures.

### Copied run workspaces

Use relative task working directories with an opt-in source copy:

```purescript
isolated = Plan.plan
  [ Plan.task "build" "/bin/sh" "."
      # Plan.withArgs [ "-c", "your-build-command" ]
  ] # Plan.withWorkspace { source: "/workspace/app", inputs: [ "src", "package.json" ] }
```

`Local.execute` resolves a relative source against the caller's current directory;
HTTP submissions require an absolute source on the server. Each run receives a
separate copy of selected paths. Outputs stay in `runDirectory/workspace` locally;
there is no automatic copyback. Task directories must exist in the source.
Symlinks, special files, traversal, and overlapping input roots are rejected.
This requires an engine with workspace support. It is not an OS sandbox: absolute
paths and host services remain accessible. Cache keys include the
physical working directory by default. For commands whose outputs and logs do not
depend on that directory, explicitly use `Plan.withRelocatableCache` instead of
`Plan.withCache` (with the same `{ inputs, outputs, toolchain }` record). This enables
hits across fresh workspaces. Exact arguments/environment and dependency keys
still participate; absolute paths in them are not rewritten. The engine cannot
verify this guarantee: commands embedding or logging source paths should retain
the default cache policy unless configured to produce path-independent results.

### Separate readiness and health probes

Existing `Plan.asService` plans reuse readiness for recurring health checks. Use
`Plan.asServiceWithHealth` when startup and ongoing liveness need different checks:

```purescript
ready = { program: "/tools/check-startup", args: [], interval_ms: 100, timeout_ms: 1000 }
health = { program: "/tools/check-health", args: [], interval_ms: 500, timeout_ms: 200 }
database = Plan.task "db" "/tools/database" "/workspace/app"
  # Plan.asServiceWithHealth health (Plan.service ready)
```

The health probe starts only after readiness succeeds, using its own interval and
timeout. Consecutive health failures use the service's `failure_threshold`, fail
the service, and cancel its consumers. Probe processes are supervised and cleaned
up on timeout or cancellation. The new builder requires an engine supporting
`service.health`; ordinary `asService` plans keep the earlier wire format.

Service probe diagnostics are available as lossless bytes with the same resumable
cursor contract as command logs:

```purescript
probeOutput = Host.logs Host.ProbeStdout 0 "0" run engine
probeErrors = Host.logs Host.ProbeStderr 0 "0" run engine
```

These append-only streams contain readiness and health attempts with phase markers,
separate from daemon stdout/stderr. They require an engine supporting probe logs.
A skipped service or one cancelled before its first probe may have no probe files.
The engine currently retains these files without a disk quota. Current engines also
show probe streams in live plain/TUI output and execution events, labeled separately
from daemon output. Journal text is a lossy UTF-8 display view; use raw streams for
binary diagnostics.

Completed local and remote results now expose `outcome :: Maybe RunOutcome`, with
`RunSucceeded`, `RunFailed`, or `RunCancelled`. `Nothing` means the report came from
an older engine without a persisted outcome. New engines preserve this classification
across restart recovery, including cancellation after some tasks have succeeded.
A fail-fast run is `RunFailed` even if its sibling tasks were cancelled; task
statuses remain available for the detailed breakdown.

Discover persisted runs with `Host.history 50 Nothing engine`, then pass the
returned `next_cursor` to fetch older pages. `RunPage` contains `runs` and
`next_cursor`; each `RunState` includes optional `created_at_ms`. New servers sort
by creation time descending, then run ID. A zero timestamp means a legacy state
with unknown creation time; `Nothing` supports older servers' state responses.
History requires a server supporting `GET /v1/runs`, accepts limits 1–200, and is a
live listing rather than a frozen snapshot. Use `Host.resumeRun` with a returned ID
to inspect its results or logs.
