-- | Section 113's subcommand set, restricted to what this project
-- actually backs.
module CLI.Command
  ( Command (..)
  , parseCommand
  ) where

import Text.Read (readMaybe)

data Command
  = Validate
  | Analyze
  | Plan
  | RunHash
  | RunFile FilePath
  | -- | The real utility: target zip path, charset (literal symbol
    -- string, duplicates removed by the caller), min length, max length.
    Crack FilePath String Int Int
  deriving (Eq, Show)

parseCommand :: [String] -> Either String Command
parseCommand ["validate"]          = Right Validate
parseCommand ["analyze"]           = Right Analyze
parseCommand ["plan"]              = Right Plan
parseCommand ["run", "hash"]       = Right RunHash
parseCommand ["run", "file", path] = Right (RunFile path)
parseCommand ["crack", path, charset, minStr, maxStr] =
  case (readMaybe minStr, readMaybe maxStr) of
    (Just mn, Just mx) -> Right (Crack path charset mn mx)
    _ ->
      Left
        ( "crack: min-length and max-length must be integers, got: "
            <> minStr
            <> " "
            <> maxStr
        )
parseCommand args =
  Left
    ( "usage: akshara (validate|analyze|plan|run hash|run file PATH|"
        <> "crack ZIPFILE CHARSET MIN MAX), got: "
        <> show args
    )
