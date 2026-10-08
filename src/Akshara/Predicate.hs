{- | §14: symbolic predicates, inspectable unlike a -> Bool. Only the
propositional connectives §14 names explicitly — no atomic domain
predicate until a verifier (Stage 12) genuinely needs one (0.7).

/Known limitation, recorded rather than hidden/: no constructor here
inspects a value of type @a@, so 'evalP' is currently constant in
its second argument. The laws below are stated point-wise so they
stay correct once an atomic leaf predicate is added.
-}
module Akshara.Predicate (
  Predicate (..),
  evalP,
) where

data Predicate a where
  TrueP :: Predicate a
  FalseP :: Predicate a
  And :: Predicate a -> Predicate a -> Predicate a
  Or :: Predicate a -> Predicate a -> Predicate a
  Not :: Predicate a -> Predicate a

{- | Structural, not derived: 'Predicate' stores no value of type @a@
at any constructor, so no 'Show a' constraint is needed or wanted.
Lives here, next to the type, so it is not an orphan instance (1.7).
-}
instance Show (Predicate a) where
  show TrueP = "TrueP"
  show FalseP = "FalseP"
  show (And p q) = "(And " <> show p <> " " <> show q <> ")"
  show (Or p q) = "(Or " <> show p <> " " <> show q <> ")"
  show (Not p) = "(Not " <> show p <> ")"

-- | ⟦P⟧ : a -> Bool. Total: structural recursion on a closed predicate.
evalP :: Predicate a -> a -> Bool
evalP TrueP _ = True
evalP FalseP _ = False
evalP (And p q) x = evalP p x && evalP q x
evalP (Or p q) x = evalP p x || evalP q x
evalP (Not p) x = not (evalP p x)
