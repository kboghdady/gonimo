{-- Freer extensible effects for database access, based on persistent types.
--}
module Gonimo.Database.Effects where

import Control.Exception.Base (SomeException)
import Control.Monad.Freer (send, Member, Eff)
import Control.Monad.Freer.Exception (throwError, Exc(..))


import Database.Persist (PersistEntity(..), Entity)
import GHC.Generics


-- Tidy up the following Database definition
type EDatabase backend a =  Database backend (Either DbException a)


data Database backend v where
  Insert  :: (backend ~ PersistEntityBackend a, PersistEntity a) => a -> EDatabase backend (Key a)
  Insert_ :: (backend ~ PersistEntityBackend a, PersistEntity a) => a -> EDatabase backend ()
  Replace :: (backend ~ PersistEntityBackend a, PersistEntity a) => Key a -> a -> EDatabase backend ()
  Delete  :: (backend ~ PersistEntityBackend a, PersistEntity a) => Key a -> EDatabase backend ()
  Get     :: (backend ~ PersistEntityBackend a, PersistEntity a) => Key a -> EDatabase backend a
  GetBy   :: (backend ~ PersistEntityBackend a, PersistEntity a) => Unique a -> EDatabase backend (Entity a)

data DbException =
  NotFound
  | SystemException SomeException deriving (Show, Generic)

insert :: DbConstraint backend a r => a -> Eff r (Key a)
insert = sendDb . Insert

insert_ :: DbConstraint backend a r => a -> Eff r ()
insert_ = sendDb . Insert_

replace :: DbConstraint backend a r => Key a -> a -> Eff r ()
replace k v = sendDb $ Replace k v

get :: DbConstraint backend a r => Key a -> Eff r a
get = sendDb . Get

delete :: DbConstraint backend a r => Key a -> Eff r ()
delete = sendDb . Delete

getBy :: DbConstraint backend a r => Unique a -> Eff r (Entity a)
getBy = sendDb . GetBy

-- Type synonym for constraints on Database API functions, requires ConstraintKinds language extension:
type DbConstraint backend a r = (Member (Database backend) r
                                , Member (Exc DbException) r
                                , PersistEntity a, backend ~ PersistEntityBackend a)


-- Send a server operation, that is an operation that might fail:
sendDb :: (Member (Database backend) r, Member (Exc DbException) r) => EDatabase backend a -> Eff r a
sendDb op = do
  r <- send op
  case r of
    Left e -> throwError e
    Right v -> return v
