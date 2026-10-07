-- | Section 113's subcommand set, restricted to what Stages 1-13
-- actually back (Section 5.9 ADR). 'resume' needs checkpoint
-- serialisation (Section 150, deferred); 'inspect' needs
-- normalisation (Section 120, deferred). Neither is a constructor
-- here -- Section 1.11 bans a command with no real implementation
-- behind it.
module CLI.Command
  ( Command (..)
  , parseCommand
  ) where

data Command = Validate | Analyze | Plan | Run
  deriving (Eq, Show)

parseCommand :: [String] -> Either String Command
parseCommand ["validate"] = Right Validate
parseCommand ["analyze"]  = Right Analyze
parseCommand ["plan"]     = Right Plan
parseCommand ["run"]      = Right Run
parseCommand args         =
  Left ("usage: akshara (validate|analyze|plan|run), got: " <> show args)
