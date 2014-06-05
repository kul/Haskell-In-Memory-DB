{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE ExistentialQuantification #-} 
{-# LANGUAGE RankNTypes #-}

{- Exporting all types, constructors, and accessors -}
module DBTypes (Tablename(..), ErrString(..), Database(..), Fieldname(..), Table(..), Column(..), Element(..), TransactionID(..), RowHash(..), LogOperation(..), Row(..), Log(..), ActiveTransactions(..)) where

import Data.Typeable 
import Control.Concurrent.STM
import Data.Map.Lazy
import Control.Concurrent.Chan
 
newtype Tablename = Tablename String deriving(Ord, Eq, Show, Read)
newtype ErrString = ErrString String deriving(Show)

data Database = Database { database :: Map Tablename (TVar Table) }
data Fieldname = Fieldname String deriving(Ord, Eq, Show, Read)

data Table = Table { rowCounter :: Int 
                   , primaryKey :: Maybe Fieldname 
                   , table :: Map Fieldname Column}

data Column = Column { default_val :: Maybe Element
                     , col_type :: TypeRep
                     , column :: TVar(Map RowHash (TVar Element))
                     } -- first element is default value

data Element = forall a. (Show a, Ord a, Eq a, Read a, Typeable a) => Element (Maybe a) -- Nothing here means that it's null

instance Show Element where
  show (Element x) = show x

instance Read Element where
  readsPrec _ str = [(fst (head (readsPrec 0 str)),"")]

{-How do this correctly?-}
instance Eq Element where
  '==' (Element x) (Element y) | Just x_val <- x, Just y_val <- y = x == y
                               | Nothing <- x, Nothing <- y       = True
                               | otherwise                        = False

{-  (Element x)==(Element y)= case x of 
                              Just a -> case y of 
                                          Just b -> if typeOf a == typeOf b
                                                      then (a == b)
                                                      else False
                                          Nothing -> False
                              Nothing -> case y of 
                                           Just _ -> False
                                           Nothing -> True
                    

instance Ord Element where 
 -}

data TransactionID = TransactionID { clientName :: String 
                                   , transactionNum :: Int 
                                   } deriving(Eq, Show, Read)-- clientname, transaction number
 
data Row = Row {getField :: Fieldname -> STM(Maybe Element)}

construct_row :: [(Fieldname, Element)] -> Row
construct_row content = return . (flip lookup content)

verify_row :: [(Fieldname, Element->Bool)] -> Row -> STM Bool
verify_row content row = foldR (liftM2 (&&)) (return True) $ zipWith liftM (map (evaluate . snd) content) $ map (getField row) (map fst content) 
    where evaluate f Nothing = False
          evaluate f Just x  = f x

newtype RowHash = RowHash Int deriving(Show, Read, Eq, Ord) 
data LogOperation = Start TransactionID
                  | Insert TransactionID (Tablename, RowHash) [(Fieldname, Element)]
                  | Delete TransactionID (Tablename, RowHash) [(Fieldname, Element)]
                  | Update TransactionID (Tablename, RowHash) [(Fieldname, Element, Element)] -- last two are old val, new val
                  | Commit TransactionID  
                  | StartCheckpoint [TransactionID]   
                  | EndCheckpoint
                  | DropTable TransactionID Tablename 
                  | CreateTable TransactionID Tablename
                  | AddField TransactionID Tablename Fieldname
                  | DropField TransactionID Tablename Fieldname
                  | SetPrimaryKey TransactionID (Maybe Fieldname) (Maybe Fieldname) Tablename -- old field, new field
                  deriving (Show, Read) 

type Log = Chan LogOperation
type ActiveTransactions = Set TransactionID
