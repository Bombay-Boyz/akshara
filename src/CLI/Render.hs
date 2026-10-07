{-# LANGUAGE DataKinds #-}

-- | Section 50: human-readable rendering only -- no search logic
-- lives here (that stays in Runtime.Engine / Akshara.Analysis /
-- Akshara.Plan). Concise text (Section 179); JSON output deferred
-- (Section 5.9 ADR -- no automation caller exists yet to need it).
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
import Verify.Errors (VerificationFailure)

-- | Section 114: validate reports construction success; it does not
-- execute the search.
renderValidate :: Bool -> String
renderValidate True  = "validate: OK (domain and target hash constructed)"
renderValidate False = "validate: FAILED (see error above)"

-- | Section 115: "Unknown values must be reported as unknown; never
-- fabricate precision." Both values here happen to be exact, by
-- Stage 7's own honest limitation (nothing in the kernel can yet
-- produce an inexact one) -- there is nothing to round down to
-- Unknown yet, not an oversight.
renderAnalyze :: AksharaExpr a -> String
renderAnalyze e =
  "analyze: cardinality = " <> show (unExactly (analyzeCardinality e))
    <> ", depth = " <> show (unDepth (analyzeDepth e))

-- | Section 116's full wishlist (partitioning, workers, checkpoint
-- capability, verifier) is honestly narrower here: 'AksharaPlan'
-- (Stage 8) deliberately carries only cardinality and depth so far --
-- see Akshara.Plan's own Section 5.9 note.
renderPlan :: AksharaExpr a -> String
renderPlan e =
  let p = derivePlan e
   in "plan: cardinality = " <> show (unExactly (planCardinality p))
        <> ", depth = " <> show (unDepth (planDepth p))

-- | Section 178: Failed, Exhausted, and Found stay visibly distinct
-- all the way to this final rendering -- never collapsed into each
-- other.
renderRun :: Show a => Either VerificationFailure (AksharaResult 'AnySolve a) -> String
renderRun (Left err)           = "run: verifier FAILED: " <> show err
renderRun (Right (FoundAny x)) = "run: FOUND " <> show x
renderRun (Right Exhausted)    = "run: EXHAUSTED (no candidate accepted)"
