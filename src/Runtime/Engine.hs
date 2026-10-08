{-# LANGUAGE DataKinds #-}

{- | Stage 13 (Section 91): the sequential half of the Search Engine
Boundary.

/Design correction, not a patch (Section 5.9)/: the first version
of this module forced the domain's candidate type and the
verifier's candidate type to unify as one @a@. That is exactly the
implicit coupling Section 29 warns against -- it assumed a
domain's natural representation (here, [Char]) and a verifier's
native input format (here, ByteString) would simply coincide, with
no mechanism saying they must. The fix makes that encoding step an
explicit argument instead of an unstated assumption -- Section
0.5's dependency inversion, extended to the translation between
the two, not just to the verifier itself.

/Deliberate scope limit (Section 5.9 ADR)/: Section 91's full
signature also takes an ExecutionPolicy -- still deferred.
-}
module Runtime.Engine (
  verifiedFindAny,
) where

import Akshara.Enumeration (enumerate)
import Akshara.Result (AksharaResult (..), SolverKind (..))
import Akshara.Syntax (AksharaExpr)
import Verify.Class (Verification (..), VerifierHandle (..))

{- | Section 34 findAny, verifier-driven. @encode@ translates a
domain value to the verifier's native candidate representation;
the result, on success, is still the original domain value @a@ --
never the encoded one -- matching Section 36's distinction between
what was searched and what was checked.
-}
verifiedFindAny ::
  VerifierHandle e IO candidate ->
  (a -> candidate) ->
  AksharaExpr a ->
  IO (Either e (AksharaResult 'AnySolve a))
verifiedFindAny verifier encode e = go (enumerate e)
  where
    go [] = pure (Right Exhausted)
    go (x : xs) = do
      outcome <- runVerifier verifier (encode x)
      case outcome of
        Accepted -> pure (Right (FoundAny x))
        Rejected -> go xs
        Failed err -> pure (Left err)
