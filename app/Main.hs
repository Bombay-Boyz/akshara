module Main (main) where

import CLI.Command (Command (..), parseCommand)
import CLI.Example (exampleDomain, exampleTargetHash)
import CLI.Render (renderAnalyze, renderPlan, renderRun, renderValidate)
import Data.ByteString.Char8 qualified as BSC
import Runtime.Engine (verifiedFindAny)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import Verify.Formats.FileContent (fileContentVerifierHandle, mkReferencePath)
import Verify.Formats.SaltedSha256 (saltedHashVerifierHandle)

main :: IO ()
main = do
  args <- getArgs
  case parseCommand args of
    Left usage -> putStrLn usage >> exitFailure
    Right cmd -> runCommand cmd

runCommand :: Command -> IO ()
runCommand Validate =
  putStrLn
    $ renderValidate
    $ either (const False) (const True) exampleDomain
      && either (const False) (const True) exampleTargetHash
runCommand Analyze =
  either (putStrLn . ("analyze: FAILED: " <>) . show) (putStrLn . renderAnalyze) exampleDomain
runCommand Plan =
  either (putStrLn . ("plan: FAILED: " <>) . show) (putStrLn . renderPlan) exampleDomain
runCommand RunHash =
  case (exampleDomain, exampleTargetHash) of
    (Right domain, Right target) -> do
      result <- verifiedFindAny (saltedHashVerifierHandle target) BSC.pack domain
      putStrLn (renderRun result)
    (Left domainErr, _) -> putStrLn ("run: FAILED (domain): " <> show domainErr)
    (_, Left hashErr) -> putStrLn ("run: FAILED (target hash): " <> show hashErr)
runCommand (RunFile path) =
  case (exampleDomain, mkReferencePath path) of
    (Right domain, Right ref) -> do
      result <- verifiedFindAny (fileContentVerifierHandle ref) BSC.pack domain
      putStrLn (renderRun result)
    (Left domainErr, _) -> putStrLn ("run: FAILED (domain): " <> show domainErr)
    (_, Left refErr) -> putStrLn ("run: FAILED (reference path): " <> show refErr)
