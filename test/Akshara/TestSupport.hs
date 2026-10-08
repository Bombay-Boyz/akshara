module Akshara.TestSupport (withRight, withRightSpec) where

import Test.Hspec (Expectation, Spec, expectationFailure, it)

{- | Total discharge of a smart constructor's Either inside a single
test's Expectation (Section 1.1: no partial pattern match).
-}
withRight :: (Show e) => Either e a -> (a -> Expectation) -> Expectation
withRight = flip (either (expectationFailure . show))

{- | Same idea, at the Spec-building level: discharges an Either while
binding its Right value across several 'it' blocks, rather than
reaching for a partial pattern on a 'let' (the bug this standard's
own Section 1.1 has already surfaced twice in this project).
-}
withRightSpec :: (Show e) => Either e a -> (a -> Spec) -> Spec
withRightSpec (Left e) _ = it "setup" $ expectationFailure (show e)
withRightSpec (Right x) k = k x
