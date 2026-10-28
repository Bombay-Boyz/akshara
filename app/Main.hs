-- | Section 50: the CLI parses, type-checks, and dispatches -- it
-- implements no search algorithm itself.
module Main (main) where

import Akshara.Partition (mkPartitionCount)
import CLI.Candidates (buildCandidateDomain)
import CLI.Command (Command (..), parseCommand)
import CLI.Example (exampleDomain, exampleTargetHash)
import CLI.Render (renderAnalyze, renderPlan, renderRun, renderValidate)
import qualified Data.ByteString.Char8 as BSC
import GHC.Conc (getNumCapabilities)
import Runtime.Engine (verifiedFindAny, verifiedParallelFindAny)
import System.Environment (getArgs)
import System.Exit (exitFailure)
import Verify.Formats.FileContent (fileContentVerifierHandle, mkReferencePath)
import Verify.Formats.SaltedSha256 (saltedHashVerifierHandle)
import Verify.Formats.ZipPkzip (loadZipTarget, zipPkzipVerifierHandle)

main :: IO ()
main = do
  args <- getArgs
  case parseCommand args of
    Left usage -> putStrLn usage >> exitFailure
    Right cmd  -> runCommand cmd

runCommand :: Command -> IO ()
runCommand Validate =
  putStrLn $
    renderValidate $
      either (const False) (const True) exampleDomain
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
    (_, Left hashErr)   -> putStrLn ("run: FAILED (target hash): " <> show hashErr)
runCommand (RunFile path) =
  case (exampleDomain, mkReferencePath path) of
    (Right domain, Right ref) -> do
      result <- verifiedFindAny (fileContentVerifierHandle ref) BSC.pack domain
      putStrLn (renderRun result)
    (Left domainErr, _) -> putStrLn ("run: FAILED (domain): " <> show domainErr)
    (_, Left refErr)    -> putStrLn ("run: FAILED (reference path): " <> show refErr)
runCommand (Crack path source) = do
  domainResult <- buildCandidateDomain source
  case domainResult of
    Left err -> putStrLn ("crack: FAILED (domain): " <> show err)
    Right domain -> do
      targetResult <- loadZipTarget path
      case targetResult of
        Left err -> putStrLn ("crack: FAILED (zip): " <> show err)
        Right target -> do
          caps <- getNumCapabilities
          case mkPartitionCount caps of
            Left pcErr -> putStrLn ("crack: FAILED (partition count): " <> show pcErr)
            Right pc -> do
              result <- verifiedParallelFindAny pc (zipPkzipVerifierHandle target) BSC.pack domain
              putStrLn (renderRun result)
