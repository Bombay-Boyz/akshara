-- | Section 50: the CLI parses, type-checks (via smart-constructor
-- validation), and dispatches -- it implements no search algorithm
-- itself.
module Main (main) where

import Akshara.Domain (alphabetOf, mkLength, mkRange, sequenceRange)
import Akshara.Errors (DomainError)
import Akshara.Syntax (AksharaExpr)
import CLI.Command (Command (..), parseCommand)
import CLI.Example (exampleDomain, exampleTargetHash)
import CLI.Render (renderAnalyze, renderPlan, renderRun, renderValidate)
import Data.List (nub)
import qualified Data.ByteString.Char8 as BSC
import Runtime.Engine (verifiedFindAny)
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

-- | Deduplicates the charset: a typo'd repeated symbol would
-- otherwise give that symbol double weight in the search (more
-- duplicate candidates enumerated, not an incorrect result, just
-- wasted work) -- almost certainly not what was intended.
buildCrackDomain :: String -> Int -> Int -> Either DomainError (AksharaExpr [Char])
buildCrackDomain charset minLen maxLen = do
  alphabet <- alphabetOf (nub charset)
  lo       <- mkLength minLen
  hi       <- mkLength maxLen
  rng      <- mkRange lo hi
  pure (sequenceRange rng alphabet)

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
runCommand (Crack path charset minLen maxLen) =
  case buildCrackDomain charset minLen maxLen of
    Left err -> putStrLn ("crack: FAILED (domain): " <> show err)
    Right domain -> do
      targetResult <- loadZipTarget path
      case targetResult of
        Left err -> putStrLn ("crack: FAILED (zip): " <> show err)
        Right target -> do
          result <- verifiedFindAny (zipPkzipVerifierHandle target) BSC.pack domain
          putStrLn (renderRun result)
