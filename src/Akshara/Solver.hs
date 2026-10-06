{-# LANGUAGE DataKinds #-}

-- | Section 34: findAny / findCanonical, kept as two functions with
-- two different contracts (Section 83) rather than one that quietly
-- picks a mode -- that collapse is exactly what Section 90's
-- phantom-indexed 'AksharaResult' exists to make a type error instead
-- of a convention.
--
-- /Deliberate scope limit (Section 5.9 ADR, continuing Akshara.Domain's)/:
-- restricted to the currently-only-finite domains the kernel can
-- construct. Over a finite solution set, Section 35's well-
-- foundedness holds automatically, so Section 37's lower-bound/
-- partition machinery is not needed here -- it becomes necessary only
-- once 'findCanonical' must answer without first fully materialising
-- the solution set (Stage 10, parallel runtime).
module Akshara.Solver
  ( findAny
  , findCanonical
  ) where

import Akshara.Enumeration (enumerate)
import Akshara.Order (Order)
import Akshara.Predicate (Predicate, evalP)
import Akshara.Result (AksharaResult (..), SolverKind (..), findMinimalWithProof)
import Akshara.Syntax (AksharaExpr)

-- | Any member of Sol(D,P) (Section 4), or 'Exhausted' if none exists.
-- Which member is returned may vary with implementation; Section 83
-- permits that for 'findAny' specifically.
findAny :: Predicate a -> AksharaExpr a -> AksharaResult 'AnySolve a
findAny p e = case filter (evalP p) (enumerate e) of
  []      -> Exhausted
  (x : _) -> FoundAny x

-- | min_prec(Sol(D,P)) (Section 34), with the minimality proof
-- Section 90's 'FoundCanonical' requires.
findCanonical
  :: Order a -> Predicate a -> AksharaExpr a -> AksharaResult 'CanonicalSolve a
findCanonical ord p e =
  case findMinimalWithProof ord (filter (evalP p) (enumerate e)) of
    Nothing         -> Exhausted
    Just (x, proof) -> FoundCanonical x proof
