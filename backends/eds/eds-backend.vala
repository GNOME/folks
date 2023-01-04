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

/* The following function is needed in order to use the async SourceRegistry
 * constructor. FIXME: https://bugzilla.gnome.org/show_bug.cgi?id=659886 */
[CCode (cname = "e_source_registry_new", cheader_filename = "libedataserver/libedataserver.h", finish_name = "e_source_registry_new_finish")]
internal extern static async E.SourceRegistry create_source_registry (GLib.Cancellable? cancellable = null) throws GLib.Error;

/**
 * A backend which connects to EDS and creates a {@link PersonaStore}
 * for each service.
 */
public class Folks.Backends.Eds.Backend : Folks.Backend
{
  private const string _use_address_books =
      "FOLKS_BACKEND_EDS_USE_ADDRESS_BOOKS";
  private bool _is_prepared = false;
  private bool _prepare_pending = false; /* used for unprepare() too */
  private bool _is_quiescent = false;
  private HashMap<string, PersonaStore> _persona_stores;
  private Map<string, PersonaStore> _persona_stores_ro;
  private E.SourceRegistry _ab_sources;
  private Set<string>? _storeids;

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
  public override void disable_persona_store (PersonaStore store)
    {
      if (this._persona_stores.has_key (store.id))
        {
          this._remove_address_book (store);
        }
    }

  /**
   * {@inheritDoc}
   */
  public override void enable_persona_store (PersonaStore store)
    {
      if (this._persona_stores.has_key (store.id) == false)
        {
          this._add_persona_store (store);
        }
    }

  private void _add_persona_store (PersonaStore store, bool notify = true)
    {
      store.removed.connect (this._store_removed_cb);

      this._persona_stores.set (store.id, store);

      this.persona_store_added (store);
      if (notify)
        {
          this.notify_property ("persona-stores");
        }
    }

  /**
   * {@inheritDoc}
   */
  public override void set_persona_stores (Set<string>? storeids)
    {
      this._storeids = storeids;

      /* If the set is empty, load all unloaded stores then return. */
      if (storeids == null)
        {
          this._ab_source_list_changed_cb ();
          return;
        }

      bool stores_changed = false;
      /* First handle adding any missing persona stores. */
      foreach (string id in storeids)
        {
          if (this._persona_stores.has_key (id) == false)
            {
              E.Source? s = this._ab_sources.ref_source (id);

              if (s == null)
                {
                  warning ("Unable to reference EDS source with ID %s", id);
                  continue;
                }

              var store =
                new Edsf.PersonaStore.with_source_registry (this._ab_sources, s);
              this._add_persona_store (store, false);

              stores_changed = true;
            }
        }

      var iter = this._persona_stores.map_iterator ();

      while (iter.next ())
        {
          var store = iter.get_value ();

          if (!storeids.contains (store.id))
            {
              this._remove_address_book (store, false, iter);
              stores_changed = true;
            }
        }

      if (stores_changed)
        {
          this.notify_property ("persona-stores");
        }
    }

  /**
   * {@inheritDoc}
   */
  public Backend ()
    {
      Object ();
    }

  construct
    {
      this._persona_stores = new HashMap<string, PersonaStore> ();
      this._persona_stores_ro = this._persona_stores.read_only_view;
      this._storeids = null;
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
      var profiling = Internal.profiling_start ("preparing Eds.Backend");

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;
          this.freeze_notify ();

          this._create_avatars_cache_dir ();

          this._ab_sources = yield create_source_registry ();
          /* Our callback only looks for added sources, so we only
           need to connect to source-added and source-enabled signals */
          this._ab_sources.source_added.connect (
              this._ab_source_list_changed_cb);
          this._ab_sources.source_enabled.connect (
              this._ab_source_list_changed_cb);
          this._ab_source_list_changed_cb ();

          this._is_prepared = true;
          this.notify_property ("is-prepared");

          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
      finally
        {
          this.thaw_notify ();
          this._prepare_pending = false;
        }

      Internal.profiling_end ((owned) profiling);
    }

  /**
   * {@inheritDoc}
   */
  public override async void unprepare () throws GLib.Error
    {
      if (!this._is_prepared || this._prepare_pending)
        {
          return;
        }

      try
        {
          this._prepare_pending = true;
          this.freeze_notify ();

          var iter = this._persona_stores.map_iterator ();

          while (iter.next ())
            this._remove_address_book (iter.get_value (), true, iter);

          this._ab_sources.source_added.disconnect (this._ab_source_list_changed_cb);
          this._ab_sources.source_enabled.disconnect (this._ab_source_list_changed_cb);
          this._ab_sources = null;

          this._is_quiescent = false;
          this.notify_property ("is-quiescent");

          this._is_prepared = false;
          this.notify_property ("is-prepared");
        }
      finally
        {
          this.thaw_notify ();
          this._prepare_pending = false;
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
  private void _ab_source_list_changed_cb ()
    {
      string[] use_addressbooks = this._get_addressbooks_from_env ();
      GLib.List<E.Source> books =
          this._ab_sources.list_enabled (SOURCE_EXTENSION_ADDRESS_BOOK);

      debug ("Address book source list changed.");

      /* Add address books which didn't previously exist in the backend.
       * We don't deal with removals here: see _source_list_changed_cb() in
       * Edsf.PersonaStore for that. */
      var added_sources = new LinkedList<E.Source> ();

      foreach (E.Source s in books)
        {
          /* If we've been told to use just a specific set of address
           * books, we must ignore all others. */
          var uid = s.get_uid ();
          if (use_addressbooks.length > 0 &&
              !(uid in use_addressbooks))
            {
              continue;
            }

          if (this._storeids != null &&
              !(uid in this._storeids))
            {
              continue;
            }

          if (!this._persona_stores.has_key (uid))
            {
              added_sources.add (s);
            }
        }

      /* Actually apply the changes to our state. We can't do this any earlier
       * or we'll mess up the calculation of what's been added. */
      foreach (var s in added_sources)
        {
          this._add_address_book (s);
        }
    }

  /**
   * Add a new addressbook connected to a Persona Store.
   */
  private void _add_address_book (E.Source s)
    {
      string uid = s.get_uid ();
      if (this._persona_stores.has_key (uid))
        return;

      debug ("Adding address book '%s'.", uid);

      var store =
          new Edsf.PersonaStore.with_source_registry (this._ab_sources, s);

      this.enable_persona_store (store);
    }

  private void _remove_address_book (Folks.PersonaStore store,
      bool notify = true,
      MapIterator<string, Folks.PersonaStore>? iter = null)
    {
      debug ("Removing address book '%s'.", store.id);

      if (iter != null)
        {
          assert (store == iter.get_value ());
          iter.unset ();
        }
      else
        {
          this._persona_stores.unset (store.id);
        }

      this.persona_store_removed (store);

      if (notify)
        {
          this.notify_property ("persona-stores");
        }

      store.removed.disconnect (this._store_removed_cb);
    }

  private void _store_removed_cb (Folks.PersonaStore store)
    {
      this._remove_address_book (store);
    }

  private string[] _get_addressbooks_from_env ()
    {
      string[] addressbooks = {};
      string ab_list = Environment.get_variable (Backend._use_address_books);

      if (ab_list != null && ab_list != "")
        {
          addressbooks = ab_list.split (":");
        }

      return addressbooks;
    }
}
