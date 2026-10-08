{- | Layer B (Section 20): enumeration as an operational
interpretation, distinct from denotation.

/Hardening fix, confirmed by benchmark (Section 4.11)/: the
original definition used map/(++) at every Sum -- O(n^2) on a
right-nested chain, confirmed by timing (depth 20,000 -> 40,000:
19s -> 124s, a 6.5x increase for a 2x depth increase). Rewritten
as a CPS/difference-list: every element consed exactly once, never
appended. Order unchanged -- confirmed by the existing oracle
tests against Akshara.Semantics.denote (Stage 4) passing
unmodified.
-}
module Akshara.Enumeration (
  enumerate,
) where

import Akshara.Syntax (AksharaExpr (..))
import Akshara.Transform (applyT)

{- | cons x rest : "x, followed by whatever rest represents" -- a
continuation-passing generalisation of (:), threaded so every
Sum/Product/MapT layer adds O(1) work.
-}
enumerateWith :: AksharaExpr a -> (a -> [r] -> [r]) -> [r] -> [r]
enumerateWith Empty _ rest = rest
enumerateWith (Pure x) cons rest = cons x rest
enumerateWith (Sum l r) cons rest =
  enumerateWith l (cons . Left) (enumerateWith r (cons . Right) rest)
enumerateWith (Product l r) cons rest =
  enumerateWith l (\x -> enumerateWith r (\y -> cons (x, y))) rest
enumerateWith (MapT t e) cons rest =
  enumerateWith e (cons . applyT t) rest

enumerate :: AksharaExpr a -> [a]
enumerate e = enumerateWith e (:) []
