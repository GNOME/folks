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

/* Linked list implementation of the {@link Gee.Set} interface.
 * This implementation provides an ordered set with predictable iteration.
 *
 * @since 0.3.UNRELEASED
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
   */
  public LinkedHashSet (HashFunc? hash_func = null,
      EqualFunc? equal_func = null)
  {
    this._hash_set = new HashSet<G> (hash_func, equal_func);
    this._linked_list = new LinkedList<G> (equal_func);
  }

  /**
   * {@inheritDoc}
   */
  public override int size
  {
    get { return this._linked_list.size; }
  }

  /**
   * {@inheritDoc}
   */
  public override bool contains (G item)
  {
    return this._hash_set.contains (item);
  }

  /**
   * {@inheritDoc}
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
   * {@inheritDoc}
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
   * {@inheritDoc}
   */
  public override void clear ()
  {
    this._hash_set.clear ();
    this._linked_list.clear ();
  }

  /**
   * {@inheritDoc}
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
   * {@inheritDoc}
   */
  public override int index_of (G item)
  {
    if (!this._hash_set.contains (item))
      return -1;
    return this._linked_list.index_of (item);
  }

  /**
   * {@inheritDoc}
   */
  public override G remove_at (int index)
  {
    G item = this._linked_list.remove_at (index);
    if (item != null)
      this._hash_set.remove (item);
    return item;
  }

  /**
   * {@inheritDoc}
   */
  public override Gee.List<G>? slice (int start, int stop)
  {
    return this._linked_list.slice (start, stop);
  }

  /**
   * {@inheritDoc}
   */
  public override G first ()
  {
    return this._linked_list.first ();
  }

  /**
   * {@inheritDoc}
   */
  public override G last ()
  {
    return this._linked_list.last ();
  }

  /**
   * {@inheritDoc}
   */
  public override bool add_all (Collection<G> collection)
  {
    bool modified = false;

    foreach (G item in collection)
      modified |= add(item);

    return modified;
  }


  /**
   * {@inheritDoc}
   */
  public override Gee.Iterator<G> iterator ()
  {
    return this._linked_list.iterator ();
  }

  /**
   * {@inheritDoc}
   */
  public override ListIterator<G> list_iterator ()
  {
    return this._linked_list.list_iterator ();
  }
}