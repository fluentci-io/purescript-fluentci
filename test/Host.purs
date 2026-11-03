module Test.Host (tests) where

import Prelude
import Data.Array as Array
import Data.Argonaut.Decode (decodeJson, JsonDecodeError)
import Data.Argonaut.Parser (jsonParser)
import Data.Maybe (Maybe(..))
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Aff (Aff, Milliseconds(..), bracket, delay, forkAff, killFiber)
import Effect.Class (liftEffect)
import Effect.Console (log)
import Effect.Exception (throw, error)
import FluentCI.Host.Client as Host
import FluentCI.Host.Local as Local
import FluentCI.Host.Plan as Plan

foreign import configuration :: Effect { baseUrl :: String, token :: String, cwd :: String, binary :: String, packageManager :: String, packageExecutable :: String }
foreign import localChildStarted :: Effect Boolean
foreign import localChildAlive :: Effect Boolean
foreign import inspectPackages :: String -> Boolean
foreign import inspectWorkspace :: String -> Effect Boolean
foreign import inspectPlan :: String -> Boolean

assert :: String -> Boolean -> Effect Unit
assert label condition = unless condition (throw label)
require :: forall e a. Show e => Either e a -> Aff a
require (Left error) = liftEffect (throw (show error))
require (Right value) = pure value

awaitRun :: Host.Client -> Host.Run -> Int -> Aff Host.RunState
awaitRun engine run attempts = do
  state <- Host.status run engine >>= require
  if state.status /= Host.Running && state.status /= Host.Queued then pure state
  else if attempts <= 0 then liftEffect (throw "run did not finish")
  else delay (Milliseconds 20.0) *> awaitRun engine run (attempts - 1)

withRun :: forall a. Host.Client -> Plan.Plan -> (Host.Run -> Aff a) -> Aff a
withRun engine plan = bracket (Host.submit plan engine >>= require) (\run -> void (Host.cancel run engine))

waitForChild :: Int -> Aff Unit
waitForChild attempts = do
  started <- liftEffect localChildStarted
  if started then pure unit
  else if attempts <= 0 then liftEffect (throw "local child did not start")
  else delay (Milliseconds 20.0) *> waitForChild (attempts - 1)

tests :: Aff Unit
tests = do
  queuedJson <- require (jsonParser "{\"id\":\"queued-run\",\"status\":\"queued\",\"error\":null}")
  queued <- require (decodeJson queuedJson :: Either JsonDecodeError Host.RunState)
  liftEffect $ assert "Queued runs must decode as nonterminal admission state" (queued.status == Host.Queued)
  legacyJson <- require (jsonParser "{\"tasks\":[]}")
  legacy <- require (decodeJson legacyJson :: Either JsonDecodeError Host.RunResult)
  liftEffect $ assert "Older reports without run outcomes must remain readable" (legacy.outcome == Nothing)
  oldStateJson <- require (jsonParser "{\"id\":\"old\",\"status\":\"succeeded\",\"error\":null}")
  oldState <- require (decodeJson oldStateJson :: Either JsonDecodeError Host.RunState)
  liftEffect $ assert "Older states without creation time must remain readable" (oldState.created_at_ms == Nothing)

  let
    base = Plan.task "base" "/bin/echo" "/tmp"
    baseSnapshot = Plan.compile (Plan.plan [base])
    prepare = base # Plan.withArgs ["literal; $VALUE", "two words"] # Plan.withEnv "__proto__" "preserved"
    left = Plan.task "left" "/bin/true" "/tmp" # Plan.needs [prepare]
    right = Plan.task "right" "/bin/true" "/tmp" # Plan.needs [prepare]
    join = Plan.task "join" "/bin/true" "/tmp" # Plan.needs [left, right]
    diamond = Plan.plan [prepare, left, right, join] # Plan.withJobs 2
  compiled <- require (Plan.compile diamond)
  liftEffect do
    assert "Pure branches must not mutate their source task" (baseSnapshot == Plan.compile (Plan.plan [base]))
    assert "Plan serialization preserves argv, environment keys, dependency edges and safe defaults" (inspectPlan compiled)
    assert "Environment inheritance is an explicit immutable plan option"
      (Plan.compile (Plan.plan [base] # Plan.withInheritedEnv true # Plan.withInheritedEnv false) == baseSnapshot)
    assert "Duplicate task IDs must fail locally" (Plan.compile (Plan.plan [base, base]) == Left Plan.DuplicateTaskIds)
    assert "Missing dependencies must fail locally" (Plan.compile (Plan.plan [left]) == Left (Plan.MissingDependency "base"))
    assert "Invalid limits must fail locally" (Plan.compile (diamond # Plan.withJobs 0) == Left Plan.InvalidLimits)
  let selected = Plan.provider Plan.MacPortsRust # Plan.withProviderExecutable "/tools/port"
  packages <- require (Plan.compile (Plan.plan [Plan.install "packages" "/tmp" selected ["jq"]]))
  liftEffect $ assert "Package providers remain pure serializable data" (inspectPackages packages)
  config <- liftEffect configuration
  when (config.binary /= "") do
    let localPlan = Plan.plan [Plan.task "local" "/bin/sh" config.cwd # Plan.withArgs ["-c", "printf local"]]
    local <- Local.execute localPlan { binary: config.binary, runRoot: config.cwd <> "/local-runs", progress: Local.Plain } >>= require
    liftEffect $ assert "Local execution must expose its durable outcome" (local.result.outcome == Just Host.RunSucceeded)
    liftEffect $ assert "Direct execution must use the same typed result contract" (map (\t -> t.status) local.result.tasks == [Host.TaskSucceeded])
    let isolated = Plan.plan [Plan.task "isolated" "/bin/sh" "." # Plan.withArgs ["-c", "printf isolated > workspace-artifact"]]
          # Plan.withWorkspace { source: config.cwd, inputs: [] }
    copied <- Local.execute isolated { binary: config.binary, runRoot: config.cwd <> "/local-runs", progress: Local.Plain } >>= require
    separated <- liftEffect (inspectWorkspace copied.runDirectory)
    liftEffect $ assert "Workspace artifacts must stay under their run directory" (separated && map (\t -> t.status) copied.result.tasks == [Host.TaskSucceeded])
    let long = Plan.plan [Plan.task "cancel-local" "/bin/sh" config.cwd # Plan.withArgs ["-c", "echo $$ > local-child.pid; while :; do /bin/sleep 0.02; done"]]
    fiber <- forkAff (Local.execute long { binary: config.binary, runRoot: config.cwd <> "/local-runs", progress: Local.Plain })
    waitForChild 500
    killFiber (error "cancel local execution") fiber
    alive <- liftEffect localChildAlive
    liftEffect $ assert "Aff cancellation must wait for local process cleanup" (not alive)

  when (config.baseUrl /= "") do
    let
      engine = Host.client { baseUrl: config.baseUrl, token: config.token, timeoutMs: 3000 }
      command id script = Plan.task id "/bin/sh" config.cwd # Plan.withArgs ["-c", script] # Plan.withTimeout 3000
      root = command "prepare" "printf prepare"
      a = command "left" "printf '%s' \"$VALUE\"" # Plan.withEnv "VALUE" "literal; $VALUE" # Plan.needs [root]
      b = command "right" "printf right" # Plan.needs [root]
      c = command "join" "printf joined" # Plan.needs [a, b]
    withRun engine (Plan.plan [root, a, b, c] # Plan.withJobs 2) \run -> do
      final <- awaitRun engine run 500
      report <- Host.result run engine >>= require
      page <- Host.events "0" run engine >>= require
      tail <- Host.events page.nextCursor run engine >>= require
      output <- Host.logs Host.Stdout 1 "0" run engine >>= require
      resumed <- Host.status (Host.resumeRun (Host.runId run)) engine >>= require
      liftEffect do
        assert "Remote diamond must succeed" (final.status == Host.Succeeded && Array.length report.tasks == 4)
        assert "Typed task statuses must decode" (Array.null (Array.filter (\t -> t.status /= Host.TaskSucceeded) report.tasks))
        assert "Events must resume without replay" (not (Array.null page.events) && Array.null tail.events)
        assert "Raw log bytes must preserve literal environment data" (output.bytes == [108,105,116,101,114,97,108,59,32,36,86,65,76,85,69])
        assert "Saved run IDs can be resumed" (resumed.status == Host.Succeeded)
      let unauthorized = Host.client { baseUrl: config.baseUrl, token: "incorrect", timeoutMs: 1000 }
      rejected <- Host.status run unauthorized
      liftEffect $ assert "HTTP errors must be typed" case rejected of
        Left (Host.HttpError 401 _) -> true
        _ -> false
    let retryPlan = Plan.plan [command "idempotent" "printf once >> idempotent-count"]
    original <- Host.submitWithKey "sdk-retry" retryPlan engine >>= require
    void (awaitRun engine original 500)
    replayed <- Host.submitWithKey "sdk-retry" retryPlan engine >>= require
    liftEffect $ assert "Idempotent submissions must return the same run" (Host.runId original == Host.runId replayed)
    conflict <- Host.submitWithKey "sdk-retry" (Plan.plan [command "different" "exit 0"]) engine
    liftEffect $ assert "Reusing a key with another plan must report a conflict" case conflict of
      Left (Host.HttpError 409 _) -> true
      _ -> false
    when (config.packageManager /= "") do
      let
        kind = case config.packageManager of
          "macports" -> Plan.MacPortsRust
          "homebrew" -> Plan.Homebrew
          "freebsd" -> Plan.FreeBSD
          "netbsd" -> Plan.NetBSD
          _ -> Plan.OpenBSD
        runtimeProvider = Plan.provider kind # Plan.withProviderExecutable config.packageExecutable
        installation = Plan.install "packages" config.cwd runtimeProvider ["fixture@1"]
        consumer = command "package-consumer" "printf package-consumer" # Plan.needs [installation] # Plan.withPackageEnvironment [runtimeProvider]
      withRun engine (Plan.plan [installation, consumer] # Plan.withResourceDirectory (config.cwd <> "/package-locks")) \run -> do
        final <- awaitRun engine run 500
        liftEffect $ assert "SDK package installation/environment tasks must execute" (final.status == Host.Succeeded)
    let
      cached = command "cached" "printf artifact > artifact" # Plan.withResources ["sdk-checkout"] # Plan.withCache { inputs: [], outputs: ["artifact"], toolchain: "purescript-e2e" } # Plan.withToolchainFiles ["/bin/sh"]
      cachedPlan = Plan.plan [cached] # Plan.withCacheDirectory (config.cwd <> "/cache") # Plan.withResourceDirectory (config.cwd <> "/locks")
    withRun engine cachedPlan \run -> void (awaitRun engine run 500)
    withRun engine cachedPlan \run -> do
      void (awaitRun engine run 500)
      report <- Host.result run engine >>= require
      liftEffect $ assert "PureScript plans must use the real action cache" (map (\t -> t.cache.outcome) report.tasks == ["hit"])
    let
      relocated = Plan.task "relocated" "/bin/sh" "."
        # Plan.withArgs ["-c", "printf portable > artifact"]
        # Plan.withRelocatableCache { inputs: [], outputs: ["artifact"], toolchain: "sdk-relocatable-v1" }
      relocatedPlan = Plan.plan [relocated]
        # Plan.withWorkspace { source: config.cwd, inputs: [] }
        # Plan.withCacheDirectory (config.cwd <> "/cache")
    withRun engine relocatedPlan \run -> do
      final <- awaitRun engine run 500
      liftEffect $ assert "First relocatable workspace run succeeds" (final.status == Host.Succeeded)
    withRun engine relocatedPlan \run -> do
      void (awaitRun engine run 500)
      report <- Host.result run engine >>= require
      liftEffect $ assert "Explicit relocatable cache restores in a fresh server workspace" (map (\t -> t.cache.outcome) report.tasks == ["hit"])
    let
      db = command "db" "while :; do /bin/sleep 0.02; done" # Plan.asService (Plan.service { program: "/bin/sh", args: ["-c", "exit 0"], interval_ms: 10, timeout_ms: 100 })
      consumer = command "consumer" "printf consumer" # Plan.needs [db]
    withRun engine (Plan.plan [db, consumer]) \run -> do
      final <- awaitRun engine run 500
      liftEffect $ assert "Service plans must gate consumers and shut down" (final.status == Host.Succeeded)
    let
      startup = { program: "/bin/sh", args: ["-c", "test ! -f sdk-ready && touch sdk-ready"], interval_ms: 10, timeout_ms: 100 }
      health = { program: "/bin/sh", args: ["-c", "test -f sdk-ready || exit 1; printf '\\377'; printf health-error >&2; touch sdk-health"], interval_ms: 10, timeout_ms: 100 }
      separate = command "separate-db" "while :; do /bin/sleep 0.02; done" # Plan.asServiceWithHealth health (Plan.service startup)
      checked = command "health-consumer" "while test ! -f sdk-health; do /bin/sleep 0.01; done; /bin/sleep 0.1" # Plan.needs [separate]
    withRun engine (Plan.plan [separate, checked]) \run -> do
      final <- awaitRun engine run 500
      liftEffect $ assert "Separate recurring health checks must replace one-time readiness checks" (final.status == Host.Succeeded)
      stdout <- Host.logs Host.ProbeStdout 0 "0" run engine >>= require
      stderr <- Host.logs Host.ProbeStderr 0 "0" run engine >>= require
      rest <- Host.logs Host.ProbeStdout 0 stdout.nextCursor run engine >>= require
      liftEffect do
        assert "Probe API must preserve binary stdout" (Array.elem 255 stdout.bytes)
        assert "Probe API must retain diagnostic stderr" (Array.any (\start -> Array.slice start (start + 12) stderr.bytes == [104,101,97,108,116,104,45,101,114,114,111,114]) (Array.range 0 (Array.length stderr.bytes)))
        assert "Probe byte cursors must resume without replay" (Array.null rest.bytes)

    withRun engine (Plan.plan [command "cancel" "/bin/sleep 20"]) \run -> do
      void (Host.cancel run engine >>= require)
      final <- awaitRun engine run 500
      liftEffect $ assert "Remote cancellation must persist a cancelled state" (final.status == Host.Cancelled)
      report <- Host.result run engine >>= require
      liftEffect $ assert "Cancelled outcome must be present in the durable result" (report.outcome == Just Host.RunCancelled)
    page <- Host.history 2 Nothing engine >>= require
    liftEffect $ assert "History returns typed persisted runs" (Array.length page.runs == 2 && Array.all (\run -> run.created_at_ms /= Nothing) page.runs)
    case page.next_cursor of
      Nothing -> liftEffect (throw "expected another history page")
      Just cursor -> do
        next <- Host.history 2 (Just cursor) engine >>= require
        liftEffect $ assert "History cursors must advance without duplicate runs" (Array.all (\run -> not (Array.elem run.id (map _.id page.runs))) next.runs)
    liftEffect (log "Host SDK server integration tests passed.")
  liftEffect (log "Pure host plan tests passed.")
