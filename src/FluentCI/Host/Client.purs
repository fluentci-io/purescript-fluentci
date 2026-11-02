module FluentCI.Host.Client
  ( Client, Config, Run, RunStatus(..), RunState, RunError(..), TaskResult, RunResult, EventPage, LogStream(..), LogPage, TaskStatus(..)
  , client, runId, resumeRun, submit, status, result, cancel, events, logs
  ) where

import Prelude
import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode (class DecodeJson, decodeJson, JsonDecodeError(..))
import Data.Argonaut.Parser (jsonParser)
import Data.Either (Either(..))
import Data.Maybe (Maybe)
import Effect.Aff (Aff, attempt)
import Effect.Aff.Compat (EffectFnAff, fromEffectFnAff)
import Effect.Exception (message)
import FluentCI.Host.Plan as Plan

type Config = { baseUrl :: String, token :: String, timeoutMs :: Int }
newtype Client = Client Config
newtype Run = Run String
type RunState = { id :: String, status :: RunStatus, error :: Maybe String }
data RunStatus = Running | Succeeded | Failed | Cancelled | Interrupted
derive instance eqRunStatus :: Eq RunStatus
instance showRunStatus :: Show RunStatus where
  show Running = "running"
  show Succeeded = "succeeded"
  show Failed = "failed"
  show Cancelled = "cancelled"
  show Interrupted = "interrupted"
instance decodeRunStatus :: DecodeJson RunStatus where
  decodeJson json = do
    value <- decodeJson json
    case value of
      "running" -> Right Running
      "succeeded" -> Right Succeeded
      "failed" -> Right Failed
      "cancelled" -> Right Cancelled
      "interrupted" -> Right Interrupted
      other -> Left (TypeMismatch ("unknown run status: " <> other))

data TaskStatus = TaskPending | TaskRunning | TaskReady | TaskStopping | TaskSucceeded | TaskFailed | TaskSkipped | TaskCancelled | TaskTimedOut
derive instance eqTaskStatus :: Eq TaskStatus
instance decodeTaskStatus :: DecodeJson TaskStatus where
  decodeJson json = do
    value <- decodeJson json
    case value of
      "pending" -> Right TaskPending
      "running" -> Right TaskRunning
      "ready" -> Right TaskReady
      "stopping" -> Right TaskStopping
      "succeeded" -> Right TaskSucceeded
      "failed" -> Right TaskFailed
      "skipped" -> Right TaskSkipped
      "cancelled" -> Right TaskCancelled
      "timed_out" -> Right TaskTimedOut
      other -> Left (TypeMismatch ("unknown task status: " <> other))

data LogStream = Stdout | Stderr
type LogPage = { nextCursor :: String, bytes :: Array Int }
type TaskResult =
  { id :: String, status :: TaskStatus, exit_code :: Maybe Int, error :: Maybe String
  , duration_ms :: Number, stdout :: String, stderr :: String
  , cache :: { outcome :: String, key :: Maybe String, reason :: String }
  , wait_reason :: Maybe String
  }
type RunResult = { tasks :: Array TaskResult }
type EventPage = { nextCursor :: String, events :: Array Json }
data RunError = InvalidPlan Plan.PlanError | HttpError Int String | TransportError String | DecodeError String
instance showRunError :: Show RunError where
  show (InvalidPlan error) = show error
  show (HttpError code body) = "HTTP " <> show code <> ": " <> body
  show (TransportError error) = "Transport error: " <> error
  show (DecodeError error) = "Invalid engine response: " <> error

type Response = { status :: Int, body :: String, nextCursor :: String, bytes :: Array Int }
foreign import requestImpl :: Config -> Boolean -> String -> String -> String -> EffectFnAff Response
foreign import encodeSegment :: String -> String
foreign import parseEvents :: (String -> Either RunError (Array Json)) -> (Array Json -> Either RunError (Array Json)) -> String -> Either RunError (Array Json)

client :: Config -> Client
client = Client
runId :: Run -> String
runId (Run id) = id
resumeRun :: String -> Run
resumeRun = Run

request :: Boolean -> String -> String -> String -> Client -> Aff (Either RunError Response)
request binary method route body (Client config) = do
  response <- attempt (fromEffectFnAff (requestImpl config binary method route body))
  pure case response of
    Left error -> Left (TransportError (message error))
    Right value | value.status >= 200 && value.status < 300 -> Right value
    Right value -> Left (HttpError value.status value.body)

decode :: forall a. DecodeJson a => String -> Either RunError a
decode body = case jsonParser body of
  Left error -> Left (DecodeError error)
  Right json -> case decodeJson json of
    Left error -> Left (DecodeError (show error))
    Right value -> Right value

submit :: Plan.Plan -> Client -> Aff (Either RunError Run)
submit plan engine = case Plan.compile plan of
  Left error -> pure (Left (InvalidPlan error))
  Right body -> do
    response <- request false "POST" "/v1/runs" body engine
    pure do
      value <- response
      state <- decode value.body :: Either RunError RunState
      pure (Run state.id)

path :: Run -> String
path (Run id) = "/v1/runs/" <> encodeSegment id
status :: Run -> Client -> Aff (Either RunError RunState)
status run engine = do
  response <- request false "GET" (path run) "" engine
  pure (response >>= \value -> decode value.body)
result :: Run -> Client -> Aff (Either RunError RunResult)
result run engine = do
  response <- request false "GET" (path run <> "/result") "" engine
  pure (response >>= \value -> decode value.body)
cancel :: Run -> Client -> Aff (Either RunError Unit)
cancel run engine = map (map (const unit)) (request false "POST" (path run <> "/cancel") "" engine)
events :: String -> Run -> Client -> Aff (Either RunError EventPage)
events cursor run engine = do
  response <- request false "GET" (path run <> "/events?cursor=" <> encodeSegment cursor) "" engine
  pure do
    value <- response
    decoded <- parseEvents (Left <<< DecodeError) Right value.body
    pure { nextCursor: value.nextCursor, events: decoded }

-- Bytes are lossless, unlike the UTF-8 display text in journal events.
logs :: LogStream -> Int -> String -> Run -> Client -> Aff (Either RunError LogPage)
logs stream index cursor run engine = do
  let name = case stream of
        Stdout -> "stdout"
        Stderr -> "stderr"
  response <- request true "GET" (path run <> "/logs/" <> show index <> "/" <> name <> "?cursor=" <> encodeSegment cursor) "" engine
  pure (map (\value -> { nextCursor: value.nextCursor, bytes: value.bytes }) response)
