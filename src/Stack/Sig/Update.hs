{-# LANGUAGE CPP #-}

{-|
Module      : Stack.Sig.Update
Description : Update Mappings & Signatures
Copyright   : (c) FPComplete.com, 2015
License     : BSD3
Maintainer  : Tim Dysinger <tim@fpcomplete.com>
Stability   : experimental
Portability : POSIX
-}

module Stack.Sig.Update where

import           Control.Exception (catch, throwIO, SomeException)
import           Control.Monad (when, unless)
import qualified Data.Conduit as C (($$+-))
import           Data.Conduit.Binary (sinkFile)
import           Data.Monoid ((<>))
import           Data.Time (formatTime, getCurrentTime)
import           Network.HTTP.Conduit (Response(responseBody),
                                       withManager, http, parseUrl)
import           Stack.Sig.Defaults (configDir, archiveDir)
import           Stack.Sig.Types
import           System.Directory (renameDirectory,
                                   getTemporaryDirectory,
                                   getHomeDirectory,
                                   doesDirectoryExist)
import           System.Exit (ExitCode(..))
import           System.FilePath ((</>))
import           System.Process (readProcessWithExitCode)

#if MIN_VERSION_time(1,5,0)
import           Data.Time (defaultTimeLocale)
#else
import           System.Locale (defaultTimeLocale)
#endif

update :: String -> IO ()
update url = do
    home <- getHomeDirectory
    temp <- getTemporaryDirectory
    let tempFile = temp </> "sig-archive.tar.gz"
        configPath = home </> configDir
        archivePath = configPath </> archiveDir
    request <-
        parseUrl (url <> "/download/archive")
    catch
        (withManager
             (\mgr ->
                   do res <- http request mgr
                      (responseBody res) C.$$+-
                          sinkFile tempFile))
        (\e ->
              throwIO
                  (SigServiceException
                       (show (e :: SomeException))))
    oldExists <- doesDirectoryExist archivePath
    when
        oldExists
        (do time <- getCurrentTime
            renameDirectory
                archivePath
                (formatTime
                     defaultTimeLocale
                     (archivePath <> "-%s")
                     time))
    (code,_out,err) <-
        readProcessWithExitCode
            "tar"
            ["xf", tempFile, "-C", configPath]
            []
    unless
        (code == ExitSuccess)
        (throwIO (ArchiveUpdateException err))