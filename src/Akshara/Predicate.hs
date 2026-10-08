-- | Section 14: symbolic predicates, inspectable unlike a -> Bool.
-- Only the propositional connectives Section 14 names explicitly --
-- no atomic domain predicate until a verifier (Stage 12) genuinely
-- needs one (Section 0.7).
--
-- /Known limitation, recorded rather than hidden/: no constructor
-- here inspects a value of type @a@, so 'evalP' is currently constant
-- in its second argument.
module Akshara.Predicate
  ( Predicate (..)
  , evalP
  ) where

data Predicate a where
  -- | Always satisfied.
  TrueP  :: Predicate a
  -- | Never satisfied.
  FalseP :: Predicate a
  -- | Conjunction: satisfied iff both operands are.
  And    :: Predicate a -> Predicate a -> Predicate a
  -- | Disjunction: satisfied iff either operand is.
  Or     :: Predicate a -> Predicate a -> Predicate a
  -- | Negation.
  Not    :: Predicate a -> Predicate a

-- | Structural, not derived: no constructor stores a value of type
-- @a@, so no 'Show a' constraint is needed. Lives next to the type
-- (Section 1.7: never an orphan instance).
instance Show (Predicate a) where
  show TrueP      = "TrueP"
  show FalseP     = "FalseP"
  show (And p q)  = "(And " <> show p <> " " <> show q <> ")"
  show (Or p q)   = "(Or " <> show p <> " " <> show q <> ")"
  show (Not p)    = "(Not " <> show p <> ")"

-- | ⟦P⟧ : a -> Bool. Total: structural recursion on a closed predicate.
evalP :: Predicate a -> a -> Bool
evalP TrueP     _ = True
evalP FalseP    _ = False
evalP (And p q) x = evalP p x && evalP q x
evalP (Or p q)  x = evalP p x || evalP q x
evalP (Not p)   x = not (evalP p x)
