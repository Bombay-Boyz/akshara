-- | Section 2.15: closed error vocabulary for building a crack
-- command's candidate domain -- separate from Akshara.Errors (the
-- kernel's own domain-construction errors), since this layer adds
-- failure modes the kernel knows nothing about (reading a wordlist
-- file).
module CLI.Errors
  ( CrackSetupError (..)
  ) where

import Akshara.Errors (DomainError)

data CrackSetupError
  = -- | The kernel's own domain construction failed (bad length
    -- range, empty charset).
    CrackDomainError DomainError
  | -- | The wordlist file could not be read.
    WordlistUnreadable String
  | -- | The wordlist, after removing blank lines, had no entries.
    WordlistEmpty
  deriving (Eq, Show)
