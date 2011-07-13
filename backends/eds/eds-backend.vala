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
 *       Travis Reitter <travis.reitter@collabora.co.uk>
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 */

using E;
using Gee;
using GLib;
using Folks;
using Folks.Backends.Eds;

extern const string BACKEND_NAME;

/**
 * A backend which connects to EDS and creates a {@link PersonaStore}
 * for each service.
 */
public class Folks.Backends.Eds.Backend : Folks.Backend
{
  private static const string _use_address_books =
      "FOLKS_BACKEND_EDS_USE_ADDRESS_BOOKS";
  private bool _is_prepared = false;
  private HashMap<string, PersonaStore> _persona_stores;
  private Map<string, PersonaStore> _persona_stores_ro;
  private E.SourceList _ab_sources;

  /**
   * {@inheritDoc}
   */
  public override string name { get { return BACKEND_NAME; } }

  /**
   * {@inheritDoc}
   */
  public override Map<string, PersonaStore> persona_stores
    {
      get { return this._persona_stores_ro; }
    }

  /**
   * {@inheritDoc}
   */
  public Backend ()
    {
      this._persona_stores = new HashMap<string, PersonaStore> ();
      this._persona_stores_ro = this._persona_stores.read_only_view;
    }

  /**
   * Whether this Backend has been prepared.
   *
   * See {@link Folks.Backend.is_prepared}.
   *
   * @since 0.5.UNRELEASED
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              this._create_avatars_cache_dir ();

              E.BookClient.get_sources (out this._ab_sources);
              this._ab_sources.changed.connect (
                  this._ab_source_list_changed_cb);
              this._ab_source_list_changed_cb (this._ab_sources);

              this._is_prepared = true;
              this.notify_property ("is-prepared");
            }
        }
    }

  /**
   * {@inheritDoc}
   */
  public override async void unprepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (this._is_prepared)
            {
              foreach (var persona_store in this._persona_stores.values)
                {
                  this._remove_address_book (persona_store);
                }

              this._ab_sources.changed.disconnect (this._ab_source_list_changed_cb);
              this._ab_sources = null;

              this._is_prepared = false;
              this.notify_property ("is-prepared");
            }
        }
    }

  private void _create_avatars_cache_dir ()
    {
      string avatars_dir = GLib.Path.build_filename
          (GLib.Environment.get_user_cache_dir (), "folks", "avatars");
      DirUtils.create_with_parents (avatars_dir, 0700);
    }

  /* Called every time the list of E.Sources changes. Note that there may be
   * cases where it's called but we don't have to do anything. For example, if
   * an address book is renamed, we don't have to add or remove any persona
   * stores since we don't use the address book names. */
  private void _ab_source_list_changed_cb (E.SourceList list)
    {
      string[] use_addressbooks = this._get_addressbooks_from_env ();
      unowned GLib.SList<weak E.SourceGroup> groups =
          this._ab_sources.peek_groups ();

      debug ("Address book source list changed.");

      /* Collapse the updated list of groups down into a set of current address
       * books we're interested in, excluding the ones currently in the
       * backend. */
      var new_sources = new HashMap<string, E.Source> ();

      foreach (var g in groups)
        {
          foreach (E.Source s in g.peek_sources ())
            {
              /* If we've been told to use just a specific set of address
               * books, we must ignore all others. */
              if (use_addressbooks.length > 0 &&
                  !(s.peek_name () in use_addressbooks))
                {
                  continue;
                }

              new_sources.set (s.peek_relative_uri (), s);
            }
        }

      /* Remove address books which no longer exist from the backend. */
      var removed_sources = new LinkedList<string> ();

      foreach (var source_uri in this._persona_stores.keys)
        {
          if (!new_sources.has_key (source_uri))
            {
              removed_sources.add (source_uri);
            }
        }

      /* Add address books which didn't previously exist in the backend. */
      var added_sources = new LinkedList<string> ();

      foreach (var source_uri in new_sources.keys)
        {
          if (!this._persona_stores.has_key (source_uri))
            {
              added_sources.add (source_uri);
            }
        }

      /* Actually apply the changes to our state. We can't do this any earlier
       * or we'll mess up the calculation of what's been added and removed. */
      foreach (var source_uri in removed_sources)
        {
          this._remove_address_book (this._persona_stores.get (source_uri));
        }

      foreach (var source_uri in added_sources)
        {
          this._add_address_book (new_sources.get (source_uri));
        }
    }

  /**
   * Add a new addressbook connected to a Persona Store.
   */
  private void _add_address_book (E.Source s)
    {
      string relative_uri = s.peek_relative_uri ();

      if (this._persona_stores.has_key (relative_uri))
        return;

      debug ("Adding address book '%s'.", relative_uri);

      var store = new Edsf.PersonaStore (s);

      store.removed.connect (this._store_removed_cb);

      this._persona_stores.set (store.id, store);
      this.notify_property ("persona-stores");

      this.persona_store_added (store);
    }

  private void _remove_address_book (Folks.PersonaStore store)
    {
      debug ("Removing address book '%s'.", store.id);

      this.persona_store_removed (store);

      this.persona_stores.unset (store.id);
      this.notify_property ("persona-stores");

      store.removed.disconnect (this._store_removed_cb);
    }

  private void _store_removed_cb (Folks.PersonaStore store)
    {
      this._remove_address_book (store);
    }

  private string[] _get_addressbooks_from_env ()
    {
      string[] addressbooks = {};
      string ab_list = Environment.get_variable (this._use_address_books);

      if (ab_list != null && ab_list != "")
        {
          addressbooks = ab_list.split (":");
        }

      return addressbooks;
    }
}
