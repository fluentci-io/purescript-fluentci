module Test.Plugin (tests) where

import Prelude
import Data.Either (Either(..))
import Effect (Effect)
import Effect.Exception (throw)
import FluentCI.Plugin as P

foreign import installGuest :: Effect Unit
foreign import removeGuest :: Effect Unit
foreign import callCount :: Effect Int

assert :: String -> Boolean -> Effect Unit
assert message condition = unless condition (throw message)

tests :: Effect Unit
tests = do
  installGuest
  let
    source = P.pipeline "compile"
    build = source
      # P.using (P.Nix { impure: true })
      # P.withWorkdir "/workspace"
      # P.withEnv "CI" "true"
      # P.withCache "target" (P.cache "cargo")
      # P.withSecret "TOKEN" (P.secret "TOKEN" "sensitive")
      # P.exec ["printf", "%s", "héllo 世界"]
    service = P.pipeline "database" # P.exec ["database"] # P.asService "db"
    client = build # P.withService service # P.waitOn 8080 10
  before <- callCount
  assert "guest construction must not invoke the engine" (before == 0)
  assert "pure validation accepts the complete pipeline" (P.validate client == Right unit)
  assert "invalid argv is a typed argument error" case P.validate (source # P.exec []) of
    Left (P.InvalidArgument _) -> true
    _ -> false
  result <- P.stdout client
  assert "terminal execution returns a typed result" (result == Right "guest output")
  empty <- P.stdout source
  assert "the original pipeline remains reusable" (empty == Right "guest output")
  manager <- P.secretManager (P.Aws { region: "eu-west-1" })
  case manager of
    Left error -> throw (P.errorMessage error)
    Right value -> do
      secrets <- P.getSecrets value "database"
      case secrets of
        Left error -> throw (P.errorMessage error)
        Right values -> assert "secret retrieval is typed" (case values of
          [] -> true
          _ -> false)
  removeGuest
  missing <- P.stdout source
  assert "missing guest runtime has a distinct error constructor" case missing of
    Left (P.MissingHostFunction _) -> true
    _ -> false
