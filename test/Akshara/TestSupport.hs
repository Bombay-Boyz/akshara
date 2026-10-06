module Akshara.TestSupport (withRight) where

import Test.Hspec (Expectation, expectationFailure)

-- | Total discharge of a smart constructor's Either inside a test:
-- Left reports via the framework rather than a partial pattern match
-- (Section 1.1). either leftHandler k :: Either e a -> Expectation
-- already has the args in (handler, continuation, either) order;
-- flip swaps it to the (either, continuation) order callers want.
withRight :: Show e => Either e a -> (a -> Expectation) -> Expectation
withRight = flip (either (expectationFailure . show))
