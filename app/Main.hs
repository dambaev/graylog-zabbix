{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
module Main where

import Network.Wai
import Network.Wai.Handler.Warp
import Servant
import Data.Text as T
import qualified Data.Text.IO as T
import Control.Concurrent (forkIO)
import Control.Monad.IO.Class (liftIO)
import Data.Aeson
import GHC.Generics
import qualified Control.Concurrent.STM as STM
import qualified Control.Concurrent.STM.TBMQueue as STM
import           Control.Monad.Trans.Reader  (ReaderT, ask, runReaderT)
import System.Environment as E


type UsersAPI = ReqBody '[JSON] InternalEvent :> PostNoContent

data Event = Event
  { event_title :: Text
  , event_timestamp :: Text
  , event_message :: Text
  }
  deriving
    ( Generic
    , Show
    )

data InternalEvent = InternalEvent
  { internal_event_definition_title :: Text
  , internal_event_event :: InternalInternalEvent
  }
data InternalInternalEvent = InternalInternalEvent
  { ineternal_internal_event_fields :: InternalInternalFields
  , internal_event_timestamp :: Text
  }
newtype InternalInternalFields = InternalInternalFields
  { internal_internal_fields_message :: Text
  }

instance FromJSON InternalEvent where
  parseJSON (Object v) = InternalEvent
    <$> v .: "event_definition_title"
    <*> v .: "event"

instance FromJSON InternalInternalEvent where
  parseJSON (Object v) = InternalInternalEvent
    <$> v .: "fields"
    <*> v .: "timestamp"

instance FromJSON InternalInternalFields where
  parseJSON (Object v) = InternalInternalFields
    <$> v .: "message"

usersAPI :: Proxy UsersAPI
usersAPI = Proxy

data State = State
  { log_queue :: STM.TBMQueue Event
  }

type AppM = ReaderT State Handler

usersServer :: InternalEvent-> AppM NoContent
usersServer internalEvent = do
  liftIO $ putStrLn $ show event
  State queue <- ask
  liftIO $ STM.atomically $ STM.writeTBMQueue queue event
  return NoContent
    where
    InternalEvent event_definition (InternalInternalEvent (InternalInternalFields message) timestamp) = internalEvent
    event = Event event_definition timestamp message

app :: State -> Application
app s = serve usersAPI $ hoistServer usersAPI (nt s) usersServer

nt :: State -> AppM a -> Handler a
nt s x = runReaderT x s

serveQueue :: Text-> STM.TBMQueue Event-> IO ()
serveQueue logDir queue = do
  mline <- STM.atomically $ STM.readTBMQueue queue
  case mline of
    Nothing-> return ()
    Just (Event title timestamp message) -> do
      T.appendFile (T.unpack (logDir `T.append` "/" `T.append` title `T.append` ".log")) (timestamp `T.append` ": " `T.append` message `T.append` "\n")
      serveQueue logDir queue

main :: IO ()
main = do
  mlogDir <- E.lookupEnv "GRAYLOG_ZABBIX_LOG_DIR"
  let logDir = case mlogDir of
        Nothing-> "/var/log/graylog-zabbix/"
        Just v-> T.pack v
  queue <- STM.newTBMQueueIO 100
  forkIO (serveQueue logDir queue)
  run 3000 (app (State queue))

