-- | Section 13: closed, named, analyzable functions -- never an
-- opaque Haskell (a -> b) (Section 10). Every constructor traces to a
-- named law (Section 77) or a named downstream use (Section 27).
module Akshara.Transform
  ( Transform (..)
  , applyT
  ) where

import Data.Void (Void, absurd)

data Transform a b where
  -- | The identity function.
  Identity     :: Transform a a
  -- | Sequential composition: apply the first, then the second.
  Compose      :: Transform a b -> Transform b c -> Transform a c
  -- | Either a b -> Either b a.
  SumComm      :: Transform (Either a b) (Either b a)
  -- | Re-associate a nested Either to the right.
  SumAssoc     :: Transform (Either (Either a b) c) (Either a (Either b c))
  -- | 0 + A ≅ A: eliminate an impossible left branch.
  SumUnitElimL :: Transform (Either Void a) a
  -- | A + 0 ≅ A: eliminate an impossible right branch.
  SumUnitElimR :: Transform (Either a Void) a
  -- | Re-associate a nested product to the right.
  ProductAssoc :: Transform ((a, b), c) (a, (b, c))
  -- | x : xs -- folds a Product-of-counted-down-Pures into a flat
  -- list carrier (used by 'Akshara.Domain.replicateE').
  ConsT        :: Transform (a, [a]) [a]
  -- | either id id -- folds a same-typed Either back to its common
  -- type (used by 'Akshara.Domain.sequenceRange').
  UnifyT       :: Transform (Either a a) a

-- | ⟦T⟧ : a -> b. Total: each case is an exhaustive match on a
-- closed value shape; 'absurd' is the one legitimate total eliminator
-- of 'Void' -- it can never actually be called.
applyT :: Transform a b -> a -> b
applyT Identity     x                 = x
applyT (Compose f g) x                = applyT g (applyT f x)
applyT SumComm      (Left x)          = Right x
applyT SumComm      (Right y)         = Left y
applyT SumAssoc     (Left (Left a))   = Left a
applyT SumAssoc     (Left (Right b))  = Right (Left b)
applyT SumAssoc     (Right c)         = Right (Right c)
applyT SumUnitElimL (Left v)          = absurd v
applyT SumUnitElimL (Right a)         = a
applyT SumUnitElimR (Left a)          = a
applyT SumUnitElimR (Right v)         = absurd v
applyT ProductAssoc ((a, b), c)       = (a, (b, c))
applyT ConsT         (x, xs)          = x : xs
applyT UnifyT        (Left x)         = x
applyT UnifyT        (Right x)        = x
