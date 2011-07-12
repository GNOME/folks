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
  public static const string use_addressbooks =
      "FOLKS_BACKEND_EDS_USE_ADDRESSBOOKS";
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
              string[] use_addressbooks = this._get_addressbooks_from_env ();
              this._create_avatars_cache_dir ();

              E.BookClient.get_sources (out this._ab_sources);
              unowned GLib.SList<weak E.SourceGroup> groups =
                  this._ab_sources.peek_groups ();

              foreach (var g in groups)
                {
                  foreach (E.Source s in g.peek_sources ())
                    {
                      if (use_addressbooks.length > 0)
                        {
                          if (s.peek_name () in use_addressbooks)
                            {
                              this._add_addressbook (s);
                            }
                        }
                      else
                        {
                          this._add_addressbook (s);
                        }
                    }
                }

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
      foreach (var persona_store in this._persona_stores.values)
        {
          this.persona_store_removed (persona_store);
        }

      this._persona_stores.clear ();
      this.notify_property ("persona-stores");

      this._is_prepared = false;
      this.notify_property ("is-prepared");
    }

  private void _create_avatars_cache_dir ()
    {
      string avatars_dir = GLib.Path.build_filename
          (GLib.Environment.get_user_cache_dir (), "folks", "avatars");
      DirUtils.create_with_parents (avatars_dir, 0700);
    }

  /**
   * Add a new addressbook connected to a Persona Store.
   */
  private void _add_addressbook (E.Source s)
    {
      string relative_uri = s.peek_relative_uri ();

      if (this._persona_stores.has_key (relative_uri))
        return;

      var store = new Edsf.PersonaStore (s);
      this._persona_stores.set (store.id, store);
      store.removed.connect (this._store_removed_cb);
      this.notify_property ("persona-stores");
      this.persona_store_added (store);
    }

  private void _store_removed_cb (Folks.PersonaStore store)
    {
      store.removed.disconnect (this._store_removed_cb);
      this.persona_store_removed (store);
      this.persona_stores.unset (store.id);
    }

  private string[] _get_addressbooks_from_env ()
    {
      string[] addressbooks = {};
      string ab_list = Environment.get_variable (this.use_addressbooks);

      if (ab_list != null && ab_list != "")
        {
          addressbooks = ab_list.split (":");
        }

      return addressbooks;
    }
}
