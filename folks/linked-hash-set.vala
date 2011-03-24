/*
 * Copyright (C) 2011 Collabora Ltd.
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors:
 *       Eitan Isaacson <eitan.isaacson@collabora.co.uk>
 */

using Gee;

/**
 * Linked list implementation of the {@link Gee.Set} interface.
 * This implementation provides an ordered set with predictable iteration.
 *
 * @since 0.3.4
 */
public class Folks.LinkedHashSet<G> : AbstractList<G>,
    Set<G>
{
  /* A hash set that maintains a unique set. */
  private HashSet<G> _hash_set;
  /* A linked list that maintains the order of the items. */
  private LinkedList<G> _linked_list;

  /**
   * Constructs a new empty set.
   *
   * If no function parameters are provided, the default functions for the
   * set's item type are used.
   *
   * @param hash_func an optional hash function
   * @param equal_func an optional equality testing function
   *
   * @since 0.3.4
   */
  public LinkedHashSet (HashFunc? hash_func = null,
      EqualFunc? equal_func = null)
  {
    this._hash_set = new HashSet<G> (hash_func, equal_func);
    this._linked_list = new LinkedList<G> (equal_func);
  }

  /**
   * The number of items in this collection.
   *
   * @see Gee.AbstractCollection.size
   *
   * @since 0.3.4
   */
  public override int size
  {
    get { return this._linked_list.size; }
  }

  /**
   * Returns whether this structure contains the given item.
   *
   * @param item the element to find
   *
   * @return `true` if this collection contains the specified item.
   * @see Gee.AbstractCollection.contains
   *
   * @since 0.3.4
   */
  public override bool contains (G item)
  {
    return this._hash_set.contains (item);
  }

  /**
   * Add the given element.
   *
   * @param item element to add
   *
   * @return `true` if the element was added.
   * @see Gee.AbstractCollection.add
   *
   * @since 0.3.4
   */
  public override bool add (G item)
  {
    if (this._hash_set.add (item))
      {
        this._linked_list.add (item);
        return true;
      }

    return false;
  }

  /**
   * Remove the instance of the given element.
   *
   * @param item element to remove
   *
   * @return `true` if the element was removed.
   * @see Gee.AbstractCollection.remove
   *
   * @since 0.3.4
   */
  public override bool remove (G item)
  {
    if (this._hash_set.remove (item))
      {
        this._linked_list.remove (item);
        return true;
      }

    return false;
  }

  /**
   * Removes all items from this collection. Must not be called on read-only
   * collections.
   *
   * @see Gee.AbstractCollection.clear
   *
   * @since 0.3.4
   */
  public override void clear ()
  {
    this._hash_set.clear ();
    this._linked_list.clear ();
  }

  /**
   * Returns the item at the given position.
   *
   * @param index the position of an element to retrieve.
   *
   * @return the item at the specified index in this list.
   * @see Gee.AbstractList.get
   *
   * @since 0.3.4
   */
  public override G get (int index)
  {
    return this._linked_list.get (index);
  }

  /**
   * Unimplemented method (incompatable with ordered set).
   */
  public override void set (int index, G item)
  {
    assert_not_reached ();
  }

  /**
   * Unimplemented method (incompatable with ordered set).
   */
  public override void insert (int index, G item)
  {
    assert_not_reached ();
  }

  /**
   * Returns the position of the given item.
   *
   * @param item an element to find within this structure.
   *
   * @return the index of the occurence of the specified item in this list.
   * @see Gee.AbstractList.index_of
   *
   * @since 0.3.4
   */
  public override int index_of (G item)
  {
    if (!this._hash_set.contains (item))
      return -1;
    return this._linked_list.index_of (item);
  }

  /**
   * Remove the element at the given index.
   *
   * @param index position of the element to remove.
   *
   * @return the removed element.
   * @see Gee.AbstractList.remove_at
   *
   * @since 0.3.4
   */
  public override G remove_at (int index)
  {
    G item = this._linked_list.remove_at (index);
    if (item != null)
      this._hash_set.remove (item);
    return item;
  }

  /**
   * Returns a new sub-list of this structure. Caller does not own the new
   * list's elements.
   *
   * @param start position of first element in sub-list
   * @param stop position of last element in sub-list
   *
   * @return the sub-list specified by start and stop.
   * @see Gee.AbstractList.slice
   *
   * @since 0.3.4
   */
  public override Gee.List<G>? slice (int start, int stop)
  {
    return this._linked_list.slice (start, stop);
  }

  /**
   * Returns the first element in this structure.
   *
   * @return the first element in the structure. Fails if the structure is
   * empty.
   * @see Gee.AbstractList.first
   *
   * @since 0.3.4
   */
  public override G first ()
  {
    return this._linked_list.first ();
  }

  /**
   * Returns the first element in this structure.
   *
   * @return the last element in the structure. Fails if the structure is empty.
   * @see Gee.AbstractList.last
   *
   * @since 0.3.4
   */
  public override G last ()
  {
    return this._linked_list.last ();
  }

  /**
   * Adds all the elements of the given collection to this one (as necessary).
   *
   * @param collection a {@link Gee.Collection} of elements to add.
   *
   * @return `true` if new elements were added to the collection.
   * @see Gee.AbstractCollection.add_all
   *
   * @since 0.3.4
   */
  public override bool add_all (Collection<G> collection)
  {
    bool modified = false;

    foreach (G item in collection)
      modified |= add(item);

    return modified;
  }


  /**
   * Returns the Iterator for this structure.
   *
   * @return a {@link Gee.Iterator} that can be used for iteration over this
   * structure.
   * @see Gee.Iterator
   *
   * @since 0.3.4
   */
  public override Gee.Iterator<G> iterator ()
  {
    return this._linked_list.iterator ();
  }

  /**
   * Unimplemented method (incompatible with ordered set).
   *
   * @return nothing
   * @see Gee.ListIterator
   *
   * @since 0.3.4
   */
  public override ListIterator<G> list_iterator ()
  {
    assert_not_reached ();
  }
}
