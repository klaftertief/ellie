module Ellie.Adapters.DatabaseRepo where

import Prelude

import Control.Monad.Eff.Exception (Error)
import Control.Monad.Error.Class (class MonadThrow, try)
import Control.Monad.IO.Class (class MonadIO)
import Control.Monad.IO.Class (liftIO) as IO
import Control.Monad.Maybe.Trans (MaybeT(..), runMaybeT)
import Data.Either as Either
import Data.Entity (Entity)
import Data.Entity as Entity
import Data.Maybe (Maybe)
import Data.String.Class (toString) as String
import Data.Uuid as Uuid
import Ellie.Types.Revision (Revision)
import Ellie.Types.Revision as Revision
import Ellie.Types.User (User)
import Ellie.Types.User as User
import System.Jwt (Jwt, Secret)
import System.Jwt as Jwt
import System.Postgres as Postgres


type Env r =
  { jwtSecret ∷ Secret
  , postgresClient ∷ Postgres.Client
  | r
  }


getRevision ∷ ∀ m r. MonadIO m ⇒ MonadThrow Error m ⇒ Revision.Id → Env r → m (Maybe (Entity Revision.Id Revision))
getRevision revisionId env =
  IO.liftIO
    $ Postgres.exec env.postgresClient
    $ Postgres.invoke "ellie.retrieve_revision"
    $ revisionId


revisionExists ∷ ∀ m r. MonadIO m ⇒ Revision.Id → Env r → m Boolean
revisionExists revisionId env =
  IO.liftIO
    $ Postgres.exec env.postgresClient
    $ Postgres.invoke "ellie.revision_exists"
    $ revisionId


saveRevision ∷ ∀ m r. MonadIO m ⇒ Revision.Id → Revision → Env r → m Unit
saveRevision revisionId revision env =
  IO.liftIO
    $ Postgres.exec env.postgresClient
    $ Postgres.invoke "ellie.save_revision"
    $ Entity.entity revisionId revision


-- USERS


getUser ∷ ∀ m r. MonadIO m ⇒ MonadThrow Error m ⇒ User.Id → Env r → m (Maybe (Entity User.Id User))
getUser userId env = do
  IO.liftIO
    $ Postgres.exec env.postgresClient
    $ Postgres.invoke "ellie.retrieve_user"
    $ userId


createUser ∷ ∀ m r. MonadIO m ⇒ Env r → m (Entity User.Id User)
createUser env =
  IO.liftIO
    $ Postgres.exec env.postgresClient
    $ Postgres.invoke "ellie.create_user"
    $ Postgres.arguments []


saveUser ∷ ∀ m r. MonadIO m ⇒ User.Id → User → Env r → m Unit
saveUser userId user env =
  IO.liftIO
    $ Postgres.exec env.postgresClient
    $ Postgres.invoke "ellie.update_user"
    $ Entity.entity userId user


verifyUser ∷ ∀ m r. MonadIO m ⇒ Jwt → Env r → m (Maybe User.Id)
verifyUser token env =
  IO.liftIO $ runMaybeT do
    string ← MaybeT $ map Either.hush $ try $ Jwt.decode env.jwtSecret token
    MaybeT $ pure $ map User.Id $ Uuid.fromString string


signUser ∷ ∀ m r. MonadIO m ⇒ User.Id → Env r → m Jwt
signUser (User.Id uuid) env =
  IO.liftIO $ Jwt.encode env.jwtSecret (String.toString uuid)