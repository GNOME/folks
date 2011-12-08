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
  private bool _prepare_pending = false; /* used for unprepare() too */
  private bool _is_quiescent = false;
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
   * @since 0.6.0
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * Whether this Backend has reached a quiescent state.
   *
   * See {@link Folks.Backend.is_quiescent}.
   *
   * @since 0.6.2
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * {@inheritDoc}
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (this._is_prepared || this._prepare_pending)
            {
              return;
            }

          try
            {
              this._prepare_pending = true;

              this._create_avatars_cache_dir ();

              E.BookClient.get_sources (out this._ab_sources);
              this._ab_sources.changed.connect (
                  this._ab_source_list_changed_cb);
              this._ab_source_list_changed_cb (this._ab_sources);

              this._is_prepared = true;
              this.notify_property ("is-prepared");

              this._is_quiescent = true;
              this.notify_property ("is-quiescent");
            }
          finally
            {
              this._prepare_pending = false;
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
          if (!this._is_prepared || this._prepare_pending)
            {
              return;
            }

          try
            {
              this._prepare_pending = true;

              foreach (var persona_store in this._persona_stores.values)
                {
                  this._remove_address_book (persona_store);
                }

              this._ab_sources.changed.disconnect (this._ab_source_list_changed_cb);
              this._ab_sources = null;

              this._is_quiescent = false;
              this.notify_property ("is-quiescent");

              this._is_prepared = false;
              this.notify_property ("is-prepared");
            }
          finally
            {
              this._prepare_pending = false;
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

      /* Add address books which didn't previously exist in the backend.
       * We don't deal with removals here: see _source_list_changed_cb() in
       * Edsf.PersonaStore for that. */
      var added_sources = new LinkedList<E.Source> ();

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

              var uid = s.peek_uid ();
              if (!this._persona_stores.has_key (uid))
                {
                  added_sources.add (s);
                }
            }
        }

      /* Actually apply the changes to our state. We can't do this any earlier
       * or we'll mess up the calculation of what's been added. */
      foreach (var source in added_sources)
        {
          this._add_address_book (source);
        }
    }

  /**
   * Add a new addressbook connected to a Persona Store.
   */
  private void _add_address_book (E.Source s)
    {
      string uid = s.peek_uid ();
      if (this._persona_stores.has_key (uid))
        return;

      debug ("Adding address book '%s'.", uid);

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

      this._persona_stores.unset (store.id);
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
