{-# LANGUAGE ExtendedDefaultRules #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}

{-|
Module      : Stack.Sig.Doc
Description : Pretty Printing Functions
Copyright   : (c) FPComplete.com, 2015
License     : BSD3
Maintainer  : Tim Dysinger <tim@fpcomplete.com>
Stability   : experimental
Portability : POSIX
-}

module Stack.Sig.Doc (ToDoc(..), putToDoc, putHeader, putPkgOK)
       where

import           Control.Monad.Catch ()
import           Control.Monad.IO.Class (MonadIO, liftIO)
import           Control.Monad.Trans.Control ()
import qualified Data.ByteString.Char8 as C (unpack)
import           Data.List (intercalate)
import           Data.Map (Map)
import qualified Data.Map.Strict as M
import           Data.Set (Set)
import qualified Data.Set as S
import           Data.Text (Text)
import qualified Data.Text as T
import           Data.Version (Version(..))
import           Distribution.Package (PackageName, PackageIdentifier(..))
import           Distribution.Text (display)
import           Stack.Sig.Types
import           Text.Email.Validate (EmailAddress, toByteString)
import           Text.PrettyPrint.ANSI.Leijen
       (Doc, vsep, text, putDoc, linebreak, indent, hang, fill, empty,
        (<>), (<+>), (<$>))

default (Text)

-- | Neatly print to a color ANSI console
class ToDoc a  where
    toDoc :: a -> Doc

instance ToDoc Text where
    toDoc = text . T.unpack

instance ToDoc Config where
    toDoc Config{..} = text "Trusted Signers:" <$>
        hang 2 (indent 2 (vsep (map toDoc configTrustedMappingSigners))) <>
        linebreak

instance ToDoc Archive where
    toDoc Archive{..} = text "Mappings:" <$>
        hang 2 (indent 2 (toDoc archiveMappings)) <>
        text "Signatures:" <$>
        hang 2 (indent 2 (toDoc archiveSignatures))

instance ToDoc (Map Text Mapping) where
    toDoc x = vsep
            (map
                 (\(a,b) ->
                       toDoc a <$>
                       hang 2 (indent 2 (toDoc b)))
                 (M.toList x)) <>
        linebreak

instance ToDoc (Map PackageIdentifier (Set Signature)) where
    toDoc x = vsep
            (map
                 (\(a,b) ->
                       toDoc a <$>
                       hang 2 (indent 2 (vsep (map toDoc (S.toList b)))))
                 (M.toList x)) <>
        linebreak

instance ToDoc Mapping where
    toDoc Mapping{..} = vsep
            (map
                 (\(a,b) ->
                       toDoc a <$>
                       hang 2 (indent 2 (vsep (map toDoc (S.toList b)))))
                 (M.toList mappingSigners))

instance ToDoc Signer where
    toDoc Signer{..} = toDoc signerFingerprint <+> toDoc signerEmail

instance ToDoc Signature where
    toDoc = text . show

instance ToDoc EmailAddress where
    toDoc = text . C.unpack . toByteString

instance ToDoc FingerprintSample where
    toDoc (FingerprintSample x) = toDoc x

instance ToDoc PackageIdentifier where
    toDoc x = toDoc (pkgName x) <>
        text "-" <>
        text
            (intercalate
                 "."
                 (map show (versionBranch $ pkgVersion x))) <>
        case versionTags
                 (pkgVersion x) of
            [] -> empty
            xs -> text "-" <>
                text (intercalate "-" xs)

instance ToDoc PackageName where
    toDoc = text . display

putToDoc :: forall a (m :: * -> *).
            (ToDoc a, MonadIO m)
         => a -> m ()
putToDoc = liftIO . putDoc . toDoc

putHeader :: forall (m :: * -> *).
             MonadIO m
          => String -> m ()
putHeader a = liftIO (putDoc (text a <> linebreak))

putPkgOK :: forall (m :: * -> *).
            MonadIO m
         => PackageIdentifier -> m ()
putPkgOK pkg = liftIO
        (putDoc
             (text "  " <>
              fill 74 (toDoc pkg) <>
              "OK" <>
              linebreak))