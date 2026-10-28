-- | Builds the AksharaExpr domain for a crack command's chosen
-- CandidateSource. Separate from CLI.Example (the fixed demo
-- domain) and from app/Main.hs (pure wiring) specifically so this
-- logic -- including the wordlist path -- is testable: anything
-- living only in app/Main.hs cannot be exercised by this project's
-- test suite at all.
module CLI.Candidates
  ( buildCandidateDomain
  ) where

import Akshara.Domain (alphabetOf, mkLength, mkRange, sequenceRange)
import Akshara.Syntax (AksharaExpr)
import CLI.Command (CandidateSource (..))
import CLI.Errors (CrackSetupError (..))
import Control.Exception (IOException, try)
import qualified Data.Set as Set

-- | Order-preserving deduplication, O(n log n) via Data.Set --
-- Data.List.nub's O(n^2) behaviour would be untenable for a
-- multi-thousand-entry wordlist. Shared by both CandidateSource
-- variants rather than two different dedup strategies for no
-- reason (Section 0.7): a charset is always tiny, but nothing is
-- lost by using the efficient version there too.
dedupOrdered :: Ord a => [a] -> [a]
dedupOrdered = go Set.empty
  where
    go _ [] = []
    go seen (x : xs)
      | x `Set.member` seen = go seen xs
      | otherwise           = x : go (Set.insert x seen) xs

-- | A duplicate symbol/word would otherwise give that candidate
-- double weight in the search -- wasted work, not an incorrect
-- result, but almost certainly not intended, in either mode.
--
-- /Known limitation, stated explicitly (Section 5.9)/: the wordlist
-- path uses lazy String IO and holds the deduplicated list in
-- memory as boxed Chars. Fine for realistic wordlists (thousands to
-- low millions of entries); a true tens-of-millions-of-entries list
-- would need a streaming, Text/ByteString-based rewrite -- not
-- attempted here, since nothing in this project has demonstrated
-- that need yet.
buildCandidateDomain :: CandidateSource -> IO (Either CrackSetupError (AksharaExpr [Char]))
buildCandidateDomain (CharsetRange charset minLen maxLen) =
  pure $ either (Left . CrackDomainError) Right $ do
    alphabet <- alphabetOf (dedupOrdered charset)
    lo       <- mkLength minLen
    hi       <- mkLength maxLen
    rng      <- mkRange lo hi
    pure (sequenceRange rng alphabet)
buildCandidateDomain (Wordlist path) = do
  result <- try (readFile path) :: IO (Either IOException String)
  pure $ case result of
    Left err -> Left (WordlistUnreadable (show err))
    Right contents ->
      case dedupOrdered (filter (not . null) (lines contents)) of
        []       -> Left WordlistEmpty
        wordList -> either (Left . CrackDomainError) Right (alphabetOf wordList)
