{-# LANGUAGE DataKinds #-}

-- | Section 50: human-readable rendering only -- no search logic
-- lives here.
module CLI.Render
  ( renderValidate
  , renderAnalyze
  , renderPlan
  , renderRun
  ) where

import Akshara.Analysis.Cardinality (analyzeCardinality, unExactly)
import Akshara.Analysis.Depth (analyzeDepth, unDepth)
import Akshara.Plan (derivePlan, planCardinality, planDepth)
import Akshara.Result (AksharaResult (..), SolverKind (AnySolve))
import Akshara.Syntax (AksharaExpr)

renderValidate :: Bool -> String
renderValidate True  = "validate: OK (domain and target hash constructed)"
renderValidate False = "validate: FAILED (see error above)"

renderAnalyze :: AksharaExpr a -> String
renderAnalyze e =
  "analyze: cardinality = " <> show (unExactly (analyzeCardinality e))
    <> ", depth = " <> show (unDepth (analyzeDepth e))

renderPlan :: AksharaExpr a -> String
renderPlan e =
  let p = derivePlan e
   in "plan: cardinality = " <> show (unExactly (planCardinality p))
        <> ", depth = " <> show (unDepth (planDepth p))

-- | Section 178: Failed, Exhausted, and Found stay visibly distinct.
--
-- /Corrected design (Section 5.9)/: generalised over any verifier's
-- error type @e@ (Section 33: the CLI shouldn't need to know which
-- adapter produced the result). The previous version hard-coded one
-- shared error type across both adapters, which silently assumed
-- something the type signatures never actually required -- see
-- 'Verify.Errors''s own Section 2.15 note.
renderRun :: (Show e, Show a) => Either e (AksharaResult 'AnySolve a) -> String
renderRun (Left err)           = "run: verifier FAILED: " <> show err
renderRun (Right (FoundAny x)) = "run: FOUND " <> show x
renderRun (Right Exhausted)    = "run: EXHAUSTED (no candidate accepted)"
