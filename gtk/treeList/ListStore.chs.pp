-- -*-haskell-*-
--  GIMP Toolkit (GTK) ListStore TreeModel
--
--  Author : Axel Simon
--          
--  Created: 9 May 2001
--
--  Version $Revision: 1.1 $ from $Date: 2004/11/21 15:06:16 $
--
--  Copyright (c) 2001 Axel Simon
--
--  This file is free software; you can redistribute it and/or modify
--  it under the terms of the GNU General Public License as published by
--  the Free Software Foundation; either version 2 of the License, or
--  (at your option) any later version.
--
--  This file is distributed in the hope that it will be useful,
--  but WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
--  GNU General Public License for more details.
--
-- |
--
-- The database for simple (non-hierarchical) tables.
--
module ListStore(
  ListStore,
  TMType(..),
  GenericValue(..),
  listStoreNew,
  listStoreSetValue,
  listStoreRemove,
  listStoreInsert,
  listStoreInsertBefore,
  listStoreInsertAfter,
  listStorePrepend,
  listStoreAppend,
  listStoreClear
#if GTK_CHECK_VERSION(2,2,0)
 ,listStoreReorder,
  listStoreSwap,
  listStoreMoveBefore,
  listStoreMoveAfter
#endif
  ) where

import Monad	(liftM, when)
import Maybe	(fromMaybe)
import FFI

import GObject	  (makeNewGObject)
{#import Hierarchy#}
{#import Signal#}
{#import TreeModel#}
import Structs	  (treeIterSize)
import StoreValue (TMType(..), GenericValue(..))
{#import GValue#} (GValue, valueUnset)
import GType	  (GType)

{# context lib="gtk" prefix="gtk" #}

-- methods

-- | Generate a new entity to store tree information.
--
listStoreNew :: [TMType] -> IO ListStore
listStoreNew cols = makeNewGObject mkListStore $ 
  withArray0 ((fromIntegral.fromEnum) TMinvalid) 
  (map (fromIntegral.fromEnum) cols) $
  {#call unsafe list_store_newv#} ((fromIntegral.length) cols)

-- | Set the data of a specific node.
--
-- * The supplied value must match the type that was set for the column.
--
listStoreSetValue :: (ListStoreClass ts) => ts -> TreeIter -> Int ->
                     GenericValue -> IO ()
listStoreSetValue ts ti col val = with val $ \vPtr -> do
  {#call unsafe list_store_set_value#} (toListStore ts) ti 
    (fromIntegral col) vPtr
  valueUnset vPtr

#if GTK_CHECK_VERSION(2,2,0)
-- | Remove a specific node.
--
-- * The 'TreeIter' will point to the entry following the one which
--   was just removed. The function returns @False@ if the
--   @ti@TreeIter does not point to a valid element (i.e. the
--   function just removed the bottom entry from the list).
--
-- * This function returned @()@ in Gtk version 2.0.X
--
listStoreRemove :: (ListStoreClass ts) => ts -> TreeIter -> IO Bool
listStoreRemove ts ti = liftM toBool $ 
  {#call list_store_remove#} (toListStore ts) ti

#else
-- | Remove a specific node.
--
-- * The 'TreeIter' will point to the entry following the one which
--   was just removed.
--
-- * This function returns @Bool@ in Gtk version 2.2.0 and later
--
listStoreRemove :: (ListStoreClass ts) => ts -> TreeIter -> IO ()
listStoreRemove ts ti = {#call list_store_remove#} (toListStore ts) ti
#endif

-- | Insert a new row into the list.
--
-- * The @pos@ parameter
-- determines the row number where the row should be inserted. Set this to
-- @-1@ to insert at the end of the list.
--
listStoreInsert :: (ListStoreClass ts) => ts -> Int -> IO TreeIter
listStoreInsert ts pos = do
  iterPtr <- mallocBytes treeIterSize
  iter <- liftM TreeIter $ newForeignPtr iterPtr (foreignFree iterPtr)
  {#call list_store_insert#} (toListStore ts) iter (fromIntegral pos)
  return iter


-- | Insert a row in front of the
-- @sibling@ node.
--
listStoreInsertBefore :: (ListStoreClass ts) => ts -> TreeIter -> IO TreeIter
listStoreInsertBefore ts sibling = do
  iterPtr <- mallocBytes treeIterSize
  iter <- liftM TreeIter $ newForeignPtr iterPtr (foreignFree iterPtr)
  {#call list_store_insert_before#} (toListStore ts) iter sibling
  return iter

-- | Insert a row behind the @sibling@
-- row.
--
listStoreInsertAfter :: (ListStoreClass ts) => ts -> TreeIter -> IO TreeIter
listStoreInsertAfter ts sibling = do
  iterPtr <- mallocBytes treeIterSize
  iter <- liftM TreeIter $ newForeignPtr iterPtr (foreignFree iterPtr)
  {#call list_store_insert_after#} (toListStore ts) iter sibling
  return iter

-- | Insert a row in front of every other row.
--
-- * This is equivalent to 'listStoreInsert' @0@.
--
listStorePrepend :: (ListStoreClass ts) => ts -> IO TreeIter
listStorePrepend ts = do
  iterPtr <- mallocBytes treeIterSize
  iter <- liftM TreeIter $ newForeignPtr iterPtr (foreignFree iterPtr)
  {#call list_store_prepend#} (toListStore ts) iter 
  return iter

-- | Insert a row at the end of the table .
--
-- * This is equivalent to 'listStoreInsert' (-1).
--
listStoreAppend :: (ListStoreClass ts) => ts -> IO TreeIter
listStoreAppend ts = do
  iterPtr <- mallocBytes treeIterSize
  iter <- liftM TreeIter $ newForeignPtr iterPtr (foreignFree iterPtr)
  {#call list_store_append#} (toListStore ts) iter 
  return iter

-- | Clear all rows in this table.
--
listStoreClear :: (ListStoreClass ts) => ts -> IO ()
listStoreClear = {#call list_store_clear#}.toListStore

#if GTK_CHECK_VERSION(2,2,0)
-- | Reorders store to follow the order indicated by the mapping. The list
-- argument should be a mapping from the /new/ positions to the /old/
-- positions. That is @newOrder !! newPos = oldPos@
--
-- * Note that this function only works with unsorted stores.
--
-- * You must make sure the mapping is the right size for the store, use
-- @'treeModelIterNChildren' store Nothing@ to check.
--
listStoreReorder :: (ListStoreClass ts) => ts -> [Int] -> IO ()
listStoreReorder ts newOrder = do
  --check newOrder is the right length or it'll overrun
  storeLength <- treeModelIterNChildren ts Nothing
  when (storeLength /= length newOrder)
       (fail "ListStore.listStoreReorder: mapping wrong length for store")
  withArray (map fromIntegral newOrder) $ \newOrderArrPtr ->
    {#call list_store_reorder#} (toListStore ts) newOrderArrPtr

-- | Swaps the two items in the store.
--
-- * Note that this function only works with unsorted stores.
--
listStoreSwap :: (ListStoreClass ts) => ts -> TreeIter -> TreeIter -> IO ()
listStoreSwap ts a b =
  {#call list_store_swap#} (toListStore ts) a b

-- | Moves the item in the store to before the given position. If the position
-- is @Nothing@ the item will be moved to then end of the list.
--
-- * Note that this function only works with unsorted stores.
--
listStoreMoveBefore :: (ListStoreClass ts) => ts
                    -> TreeIter       -- ^ Iter for the item to be moved
		    -> Maybe TreeIter -- ^ Iter for the position or @Nothing@.
		    -> IO ()
listStoreMoveBefore ts iter maybePosition =
   {#call list_store_move_before#} (toListStore ts) iter
     (fromMaybe (TreeIter nullForeignPtr) maybePosition)

-- | Moves the item in the store to after the given position. If the position
-- is @Nothing@ the item will be moved to then start of the list.
--
-- * Note that this function only works with unsorted stores.
--
listStoreMoveAfter :: (ListStoreClass ts) => ts
                   -> TreeIter       -- ^ Iter for the item to be moved
		   -> Maybe TreeIter -- ^ Iter for the position or @Nothing@.
		   -> IO ()
listStoreMoveAfter ts iter maybePosition =
  {#call list_store_move_after#} (toListStore ts) iter
    (fromMaybe (TreeIter nullForeignPtr) maybePosition)
#endif