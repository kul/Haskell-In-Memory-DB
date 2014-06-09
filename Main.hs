module Main where

import qualified Operation as O
import qualified DBTypes as D 
import qualified DBUtils as DU
import Data.Maybe
import Control.Concurrent.STM
import qualified Data.Map.Lazy as L 
import Data.Typeable
import Control.Exception
import System.Exit

create_empty_db :: STM(TVar D.Database)
create_empty_db = newTVar $ D.Database L.empty

main :: IO ()
main = do output <- sequence $ [test_create_table
                                ,test_drop_table
                                ,test_alter_add
                                ]
          mapM putStrLn output
          return ()


test_create_table :: IO String
test_create_table = atomically $ do let tablename  = D.Tablename "sample_table"
                                    let field_and_default =  [(D.Fieldname "field1", 1), (D.Fieldname "field2", 2)]
                                    db <- create_empty_db
                                    res <- O.create_table db (D.TransactionID "blah" 0) tablename (fmap (\(f, d)-> (f, Just(D.Element(Just d)), typeOf(d::Int))) field_and_default) Nothing
                                    case res of 
                                      Left (D.ErrString errstr) -> return errstr
                                      Right _ -> O.show_table_contents db tablename

test_drop_table :: IO String
test_drop_table = atomically $ do let tablename1  = D.Tablename "sample_table1"
                                  let tablename2 = D.Tablename "sample_table2"
                                  let field_and_default1 =  [(D.Fieldname "field1", 1), (D.Fieldname "field2", 2)]
                                  let field_and_default2 = [(D.Fieldname "field1", 1)]
                                  db <- create_empty_db
                                  _ <- O.create_table db (D.TransactionID "blah" 0) tablename1 (fmap (\(f, d)-> (f, Just(D.Element(Just d)), typeOf(d::Int))) field_and_default1) Nothing
                                  _ <- O.create_table db (D.TransactionID "blah" 0) tablename2 (fmap (\(f, d)-> (f, Just(D.Element(Just d)), typeOf(d::Int))) field_and_default2) Nothing
                                  res1 <- O.show_tables db
                                  _ <- O.drop_table db (D.TransactionID "blah" 0) tablename1
                                  res2 <- O.show_tables db
                                  return $ unlines ["Create 2 tables: ", res1, "Drop first table: ", res2] 

test_alter_add :: IO String
test_alter_add = atomically $ do let tablename  = D.Tablename "sample_table"
                                 let field_and_default =  [(D.Fieldname "field1", 1), (D.Fieldname "field2", 2)]
                                 db <- create_empty_db
                                 _ <- O.create_table db (D.TransactionID "blah" 0) tablename (fmap (\(f, d)-> (f, Just(D.Element(Just d)), typeOf(d::Int))) field_and_default) Nothing
                                 _ <- O.alter_table_add db (D.TransactionID "blah" 0) tablename (D.Fieldname "field3") (typeOf(undefined::String)) Nothing True
                                 O.show_table_contents db tablename

