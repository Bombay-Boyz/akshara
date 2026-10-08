module CLI.RunFileSpec (spec) where

import Akshara.TestSupport (withRight)
import CLI.Example (exampleDomain)
import CLI.Render (renderRun)
import Data.ByteString.Char8 qualified as BSC
import Runtime.Engine (verifiedFindAny)
import System.IO (hClose)
import System.IO.Temp (withSystemTempFile)
import Test.Hspec
import Verify.Formats.FileContent (fileContentVerifierHandle, mkReferencePath)

{- | Section 110, at CLI level: same engine, FileContent instead of
SaltedSha256, through the same path Main.hs uses.
-}
spec :: Spec
spec =
  describe "run file (Section 110)" $
    it "finds the domain member matching a user-supplied file's content" $
      withSystemTempFile "akshara-secret" $ \path h -> do
        BSC.hPutStr h (BSC.pack "bc")
        hClose h
        withRight exampleDomain $ \domain ->
          withRight (mkReferencePath path) $ \ref -> do
            result <- verifiedFindAny (fileContentVerifierHandle ref) BSC.pack domain
            renderRun result `shouldBe` "run: FOUND \"bc\""
