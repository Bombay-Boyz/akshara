-- | Section 113's subcommand set, restricted to what the project
-- actually backs. 'resume'/'inspect' are not constructors here --
-- neither checkpoint serialisation nor normalisation exists yet.
module CLI.Command
  ( Command (..)
  , parseCommand
  ) where

-- | The four subcommands this CLI actually implements.
data Command
  = -- | Check the example specification constructs successfully.
    Validate
  | -- | Report cardinality and depth of the example domain.
    Analyze
  | -- | Show the derived plan for the example domain.
    Plan
  | -- | Run findAny against the salted-hash example verifier.
    RunHash
  | -- | Run findAny against a user-supplied reference file.
    RunFile FilePath
  deriving (Eq, Show)

-- | Parse command-line arguments into a 'Command', or a usage message.
parseCommand :: [String] -> Either String Command
parseCommand ["validate"]          = Right Validate
parseCommand ["analyze"]           = Right Analyze
parseCommand ["plan"]              = Right Plan
parseCommand ["run", "hash"]       = Right RunHash
parseCommand ["run", "file", path] = Right (RunFile path)
parseCommand args                  =
  Left ("usage: akshara (validate|analyze|plan|run hash|run file PATH), got: " <> show args)
