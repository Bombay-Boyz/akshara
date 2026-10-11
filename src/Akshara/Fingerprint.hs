-- | Section 5.9 hardening: genuine structural content-identity for
-- AksharaExpr/Transform.
--
-- Section 126 bans a universal
-- @same :: AksharaExpr a -> AksharaExpr a -> Bool@ -- and that ban
-- still holds, for a reason worth being precise about: writing
-- @instance Eq (AksharaExpr a)@ directly is not merely banned, it is
-- actually IMPOSSIBLE in general for this GADT, because 'MapT''s
-- wrapped Transform hides an existential input type that Transform's
-- own constructors don't fix from MapT's output type alone -- two
-- MapT values can share an output type while their hidden input
-- types genuinely differ, and Haskell cannot compare values of two
-- different types with a homogeneous (==).
--
-- The fix is not to compare AksharaExpr values directly at all: each
-- one renders itself into a plain, non-GADT value (an
-- 'ExprFingerprint') first, and THOSE are compared with ordinary
-- derived Eq. A fingerprint never needs to compare across two
-- different hidden types, because by the time two fingerprints are
-- compared, both have already been erased to the same concrete type.
--
-- The only place an arbitrary leaf value enters the structure is
-- 'Pure'. Akshara.Syntax's 'Pure' now carries (Eq a, Show a) as a
-- per-constructor constraint for exactly this reason: whenever
-- 'fingerprint' pattern-matches a Pure value, at any nesting depth,
-- that dictionary is freshly available right there -- which is why
-- 'fingerprint' itself needs no constraint of its own.
module Akshara.Fingerprint
  ( ExprFingerprint
  , fingerprint
  , TransformFingerprint
  , fingerprintTransform
  ) where

import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (Transform (..))

-- | A type-erased, canonical rendering of a Transform's structure. No
-- constraint needed: Transform's constructors never store a bare
-- leaf value, only nested Transforms.
data TransformFingerprint
  = FIdentity
  | FCompose TransformFingerprint TransformFingerprint
  | FSumComm
  | FSumAssoc
  | FSumUnitElimL
  | FSumUnitElimR
  | FProductAssoc
  | FConsT
  | FUnifyT
  deriving (Eq, Show)

-- | Total: structural recursion over Transform's constructors.
fingerprintTransform :: Transform a b -> TransformFingerprint
fingerprintTransform Identity      = FIdentity
fingerprintTransform (Compose f g) = FCompose (fingerprintTransform f) (fingerprintTransform g)
fingerprintTransform SumComm       = FSumComm
fingerprintTransform SumAssoc      = FSumAssoc
fingerprintTransform SumUnitElimL  = FSumUnitElimL
fingerprintTransform SumUnitElimR  = FSumUnitElimR
fingerprintTransform ProductAssoc  = FProductAssoc
fingerprintTransform ConsT         = FConsT
fingerprintTransform UnifyT        = FUnifyT

-- | A type-erased, canonical rendering of an AksharaExpr's structure,
-- including each Pure leaf's value (rendered via the Show dictionary
-- Pure itself carries). Comparing two ExprFingerprints with ordinary
-- (==) is a sound structural-equality check for the expressions they
-- came from.
data ExprFingerprint
  = FEmpty
  | FPure String
  | FSum ExprFingerprint ExprFingerprint
  | FProduct ExprFingerprint ExprFingerprint
  | FMapT TransformFingerprint ExprFingerprint
  deriving (Eq, Show)

-- | Total: structural recursion over AksharaExpr's five constructors.
fingerprint :: AksharaExpr a -> ExprFingerprint
fingerprint Empty         = FEmpty
fingerprint (Pure x)      = FPure (show x)
fingerprint (Sum l r)     = FSum (fingerprint l) (fingerprint r)
fingerprint (Product l r) = FProduct (fingerprint l) (fingerprint r)
fingerprint (MapT t e)    = FMapT (fingerprintTransform t) (fingerprint e)
