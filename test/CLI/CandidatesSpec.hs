module CLI.CandidatesSpec (spec) where

import Akshara.Enumeration (enumerate)
import CLI.Candidates (buildCandidateDomain)
import CLI.Command (CandidateSource (..))
import CLI.Errors (CrackSetupError (..))
import System.IO (hClose, hPutStrLn)
import System.IO.Temp (withSystemTempFile)
import Test.Hspec

spec :: Spec
spec = do
  describe "buildCandidateDomain, CharsetRange mode" $ do
    it "builds exactly the expected sequences for a tiny charset/range" $ do
      result <- buildCandidateDomain (CharsetRange "ab" 1 2)
      case result of
        Right domain -> length (enumerate domain) `shouldBe` (2 + 4)
        Left err     -> expectationFailure ("expected a domain, got: " <> show err)

    it "deduplicates a repeated charset symbol" $ do
      result <- buildCandidateDomain (CharsetRange "aab" 1 1)
      case result of
        Right domain -> length (enumerate domain) `shouldBe` 2
        Left err     -> expectationFailure ("expected a domain, got: " <> show err)

    it "fails with CrackDomainError on an empty charset" $ do
      result <- buildCandidateDomain (CharsetRange "" 1 2)
      case result of
        Left (CrackDomainError _) -> pure ()
        Left otherErr              -> expectationFailure ("expected CrackDomainError, got: " <> show otherErr)
        Right _                    -> expectationFailure "expected CrackDomainError, got a domain"

  describe "buildCandidateDomain, Wordlist mode" $ do
    it "builds a domain containing exactly the wordlist's distinct, non-blank lines, in order" $
      withSystemTempFile "wordlist" $ \path h -> do
        mapM_ (hPutStrLn h) ["alpha", "beta", "", "alpha", "gamma"]
        hClose h
        result <- buildCandidateDomain (Wordlist path)
        case result of
          Right domain -> enumerate domain `shouldBe` ["alpha", "beta", "gamma"]
          Left err     -> expectationFailure ("expected a domain, got: " <> show err)

    it "fails with WordlistEmpty when the file has only blank lines" $
      withSystemTempFile "wordlist" $ \path h -> do
        mapM_ (hPutStrLn h) ["", "", ""]
        hClose h
        result <- buildCandidateDomain (Wordlist path)
        case result of
          Left WordlistEmpty -> pure ()
          Left otherErr       -> expectationFailure ("expected WordlistEmpty, got: " <> show otherErr)
          Right _             -> expectationFailure "expected WordlistEmpty, got a domain"

    it "fails with WordlistUnreadable for a missing file" $ do
      result <- buildCandidateDomain (Wordlist "/nonexistent/path/words.txt")
      case result of
        Left (WordlistUnreadable _) -> pure ()
        Left otherErr                -> expectationFailure ("expected WordlistUnreadable, got: " <> show otherErr)
        Right _                      -> expectationFailure "expected WordlistUnreadable, got a domain"
