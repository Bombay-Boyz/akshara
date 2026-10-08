-- | Sections 44-45: the planner. Section 29 forbids merging Domain,
-- Predicate, Order and execution policy into one datatype --
-- 'AksharaPlan' deliberately holds only the domain and its derived
-- analysis.
module Akshara.Plan
  ( AksharaPlan
  , planDomain
  , planCardinality
  , planDepth
  , derivePlan
  ) where

import Akshara.Analysis.Cardinality (Cardinality, analyzeCardinality)
import Akshara.Analysis.Depth (Depth, analyzeDepth)
import Akshara.Syntax (AksharaExpr)

-- | Opaque: the only way to obtain one is 'derivePlan', so the
-- cardinality/depth fields are guaranteed to actually describe
-- 'planDomain'.
data AksharaPlan a = AksharaPlan
  { planDomain      :: AksharaExpr a
    -- ^ The original domain, unaltered (Section 44's "must not alter meaning").
  , planCardinality :: Cardinality
    -- ^ The domain's cardinality, as derived by 'derivePlan'.
  , planDepth       :: Depth
    -- ^ The domain's nesting depth, as derived by 'derivePlan'.
  }

-- | Section 44: Specification -> ExecutionPlan. Runs Stage 7's
-- analyses once and bundles the result with the domain unaltered.
derivePlan :: AksharaExpr a -> AksharaPlan a
derivePlan e = AksharaPlan
  { planDomain      = e
  , planCardinality = analyzeCardinality e
  , planDepth       = analyzeDepth e
  }
