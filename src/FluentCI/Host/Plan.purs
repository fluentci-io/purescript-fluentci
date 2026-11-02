module FluentCI.Host.Plan
  ( Task, Plan, CachePolicy, Probe, Service, PlanError(..)
  , task, taskId, withArgs, needs, withEnv, withResources, withTimeout
  , withResourceWaitTimeout, withCache, asService, service
  , plan, withJobs, withMaxServices, withFailFast, withCacheDirectory
  , withResourceDirectory, validate, compile
  ) where

import Prelude
import Data.Argonaut.Core (Json, stringify)
import Data.Argonaut.Encode (class EncodeJson, encodeJson)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Maybe (Maybe(..))
import Data.Tuple (Tuple(..))
import Foreign.Object as Object

type CachePolicy = { inputs :: Array String, outputs :: Array String, toolchain :: String }
type Probe = { program :: String, args :: Array String, interval_ms :: Int, timeout_ms :: Int }
type Service = { readiness :: Probe, startup_timeout_ms :: Int, shutdown_timeout_ms :: Int, failure_threshold :: Int }
type Environment = Array { key :: String, value :: String }
newtype Task = Task
  { id :: String, needs :: Array String, program :: String, args :: Array String
  , cwd :: String, env :: Environment, resources :: Array String
  , timeout_ms :: Maybe Int, resource_wait_timeout_ms :: Maybe Int
  , cache :: Maybe CachePolicy, service :: Maybe Service
  }
newtype Plan = Plan
  { version :: Int, tasks :: Array Task, jobs :: Int, max_services :: Int
  , inherit_env :: Boolean, fail_fast :: Boolean
  , cache_dir :: Maybe String, resource_dir :: Maybe String
  }

-- Preserve arbitrary environment keys, including JavaScript prototype names.
foreign import environmentJson :: Environment -> Json
instance encodeTask :: EncodeJson Task where
  encodeJson (Task value) = encodeJson (value { env = environmentJson value.env })
derive newtype instance encodePlan :: EncodeJson Plan

data PlanError = EmptyTaskId | DuplicateTaskIds | MissingDependency String | InvalidCommand String | InvalidLimits

derive instance eqPlanError :: Eq PlanError
instance showPlanError :: Show PlanError where
  show EmptyTaskId = "A task has an empty ID"
  show DuplicateTaskIds = "Task IDs must be unique"
  show (MissingDependency id) = "Missing dependency: " <> id
  show (InvalidCommand id) = "Task requires a program and working directory: " <> id
  show InvalidLimits = "Execution limits must be positive"

task :: String -> String -> String -> Task
task id program cwd = Task
  { id, program, cwd, needs: [], args: [], env: [], resources: []
  , timeout_ms: Nothing, resource_wait_timeout_ms: Nothing, cache: Nothing, service: Nothing
  }
taskId :: Task -> String
taskId (Task value) = value.id
withArgs :: Array String -> Task -> Task
withArgs args (Task value) = Task (value { args = args })
needs :: Array Task -> Task -> Task
needs dependencies (Task value) = Task (value { needs = map taskId dependencies })
withEnv :: String -> String -> Task -> Task
withEnv key value (Task old) = Task (old { env = Array.filter (\entry -> entry.key /= key) old.env <> [{ key, value }] })
withResources :: Array String -> Task -> Task
withResources resources (Task value) = Task (value { resources = resources })
withTimeout :: Int -> Task -> Task
withTimeout milliseconds (Task value) = Task (value { timeout_ms = Just milliseconds })
withResourceWaitTimeout :: Int -> Task -> Task
withResourceWaitTimeout milliseconds (Task value) = Task (value { resource_wait_timeout_ms = Just milliseconds })
withCache :: CachePolicy -> Task -> Task
withCache cache (Task value) = Task (value { cache = Just cache })
asService :: Service -> Task -> Task
asService config (Task value) = Task (value { service = Just config })
service :: Probe -> Service
service readiness = { readiness, startup_timeout_ms: 30000, shutdown_timeout_ms: 5000, failure_threshold: 3 }
plan :: Array Task -> Plan
plan tasks = Plan { version: 1, tasks, jobs: 1, max_services: 8, inherit_env: false, fail_fast: true, cache_dir: Nothing, resource_dir: Nothing }
withJobs :: Int -> Plan -> Plan
withJobs jobs (Plan value) = Plan (value { jobs = jobs })
withMaxServices :: Int -> Plan -> Plan
withMaxServices limit (Plan value) = Plan (value { max_services = limit })
withFailFast :: Boolean -> Plan -> Plan
withFailFast enabled (Plan value) = Plan (value { fail_fast = enabled })
withCacheDirectory :: String -> Plan -> Plan
withCacheDirectory directory (Plan value) = Plan (value { cache_dir = Just directory })
withResourceDirectory :: String -> Plan -> Plan
withResourceDirectory directory (Plan value) = Plan (value { resource_dir = Just directory })

-- Pure structural checks. The engine also validates cycles, filesystem paths,
-- cache contracts, and service/resource constraints before starting commands.
validate :: Plan -> Either PlanError Unit
validate (Plan value) = do
  when (value.jobs <= 0 || value.max_services <= 0) (Left InvalidLimits)
  let ids = map taskId value.tasks
  when (Array.elem "" ids) (Left EmptyTaskId)
  let index = Object.fromFoldable (map (\id -> Tuple ("$" <> id) unit) ids)
  when (Array.length (Object.keys index) /= Array.length ids) (Left DuplicateTaskIds)
  case Array.find (\id -> not (Object.member ("$" <> id) index)) (Array.concatMap (\(Task t) -> t.needs) value.tasks) of
    Just missing -> Left (MissingDependency missing)
    Nothing -> Right unit
  case Array.find (\(Task t) -> t.program == "" || t.cwd == "") value.tasks of
    Just (Task invalid) -> Left (InvalidCommand invalid.id)
    Nothing -> Right unit
  when (not (Array.null (Array.filter (\(Task t) -> maybeInvalid t.timeout_ms || maybeInvalid t.resource_wait_timeout_ms) value.tasks))) (Left InvalidLimits)
  where
  maybeInvalid Nothing = false
  maybeInvalid (Just milliseconds) = milliseconds <= 0

compile :: Plan -> Either PlanError String
compile value = do
  validate value
  pure (stringify (encodeJson value))
