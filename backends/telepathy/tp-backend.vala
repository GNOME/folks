/*
 * Copyright (C) 2010 Collabora Ltd.
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
 */

using GLib;
using Gee;
using TelepathyGLib;
using Folks;
using Folks.Backends.Tp;

extern const string BACKEND_NAME;

/**
 * A backend which connects to the Telepathy accounts service and creates a
 * {@link PersonaStore} for each valid account known to Telepathy.
 */
public class Folks.Backends.Tp.Backend : Folks.Backend
{
  private AccountManager _account_manager;
  private bool _is_prepared = false;
  private bool _is_quiescent = false;
  private HashMap<string, PersonaStore> _persona_stores;
  private Map<string, PersonaStore> _persona_stores_ro;

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
   * @since 0.3.0
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
          if (!this._is_prepared)
            {
              this._account_manager = AccountManager.dup ();
              yield this._account_manager.prepare_async (null);
              this._account_manager.account_enabled.connect (
                  this._account_enabled_cb);
              this._account_manager.account_validity_changed.connect (
                  this._account_validity_changed_cb);

              GLib.List<unowned Account> accounts =
                  this._account_manager.get_valid_accounts ();
              foreach (Account account in accounts)
                {
                  this._account_enabled_cb (account);
                }

              this._is_prepared = true;
              this.notify_property ("is-prepared");

              this._is_quiescent = true;
              this.notify_property ("is-quiescent");
            }
        }
    }

  /**
   * {@inheritDoc}
   */
  public override async void unprepare () throws GLib.Error
    {
      if (!this._is_prepared)
        return;

      this._account_manager.account_enabled.disconnect (
          this._account_enabled_cb);
      this._account_manager.account_validity_changed.disconnect (
          this._account_validity_changed_cb);
      this._account_manager = null;

      foreach (var persona_store in this._persona_stores.values)
        {
          this.persona_store_removed (persona_store);
        }

      this._persona_stores.clear ();
      this.notify_property ("persona-stores");

      this._is_quiescent = false;
      this.notify_property ("is-quiescent");

      this._is_prepared = false;
      this.notify_property ("is-prepared");
    }

  private void _account_validity_changed_cb (Account account, bool valid)
    {
      if (valid)
        this._account_enabled_cb (account);
    }

  private void _account_enabled_cb (Account account)
    {
      var store = this._persona_stores.get (account.get_object_path ());

      if (store != null)
        return;

      store = new Tpf.PersonaStore (account);

      this._persona_stores.set (store.id, store);
      store.removed.connect (this._store_removed_cb);
      this.notify_property ("persona-stores");

      this.persona_store_added (store);
    }

  private void _store_removed_cb (PersonaStore store)
    {
      store.removed.disconnect (this._store_removed_cb);
      this.persona_store_removed (store);
      this._persona_stores.unset (store.id);
      this.notify_property ("persona-stores");
    }
}
