{- | Section 113's subcommand set. Stage 14: run splits into run hash
(SaltedSha256) and run file PATH (FileContent, against a
user-supplied file). resume/inspect omitted per the earlier Section
5.9 note -- unchanged.
-}
module CLI.Command (
  Command (..),
  parseCommand,
) where

data Command = Validate | Analyze | Plan | RunHash | RunFile FilePath
  deriving (Eq, Show)

parseCommand :: [String] -> Either String Command
parseCommand ["validate"] = Right Validate
parseCommand ["analyze"] = Right Analyze
parseCommand ["plan"] = Right Plan
parseCommand ["run", "hash"] = Right RunHash
parseCommand ["run", "file", path] = Right (RunFile path)
parseCommand args =
  Left ("usage: akshara (validate|analyze|plan|run hash|run file PATH), got: " <> show args)
