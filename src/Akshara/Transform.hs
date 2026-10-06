-- | §13: closed, named, analyzable functions — never an opaque
-- Haskell (a -> b) (§10). Every constructor traces to a named law
-- (§77) or a named downstream use (ConsT/UnifyT -> Akshara.Domain,
-- §27) — nothing speculative (0.7).
module Akshara.Transform
  ( Transform (..)
  , applyT
  ) where

import Data.Void (Void, absurd)

data Transform a b where
  Identity     :: Transform a a
  Compose      :: Transform a b -> Transform b c -> Transform a c
  SumComm      :: Transform (Either a b) (Either b a)
  SumAssoc     :: Transform (Either (Either a b) c) (Either a (Either b c))
  SumUnitElimL :: Transform (Either Void a) a
  SumUnitElimR :: Transform (Either a Void) a
  ProductAssoc :: Transform ((a, b), c) (a, (b, c))
  -- | x : xs — needed by 'Akshara.Domain.replicateE' to fold a
  -- Product-of-counted-down-Pures into a flat list carrier.
  ConsT        :: Transform (a, [a]) [a]
  -- | either id id — folds a same-typed Either back to its common
  -- type; needed by 'Akshara.Domain.sequenceRange' so Sum of two
  -- length-k branches (both already [a]) collapses to [a] (§27).
  UnifyT       :: Transform (Either a a) a

-- | ⟦T⟧ : a -> b. Total: each case is an exhaustive match on a
-- closed value shape; 'absurd' is the one legitimate total eliminator
-- of 'Void' — it can never actually be called.
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
