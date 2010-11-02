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
using TelepathyGLib;
using Folks;
using Folks.Backends.Tp;

/**
 * A backend which connects to the Telepathy accounts service and creates a
 * {@link PersonaStore} for each valid account known to Telepathy.
 */
public class Folks.Backends.Tp.Backend : Folks.Backend
{
  private AccountManager account_manager;
  private bool _is_prepared = false;

  /**
   * {@inheritDoc}
   */
  public override string name { get; private set; }

  /**
   * {@inheritDoc}
   */
  public override HashTable<string, PersonaStore> persona_stores
    {
      get; private set;
    }

  /**
   * {@inheritDoc}
   */
  public Backend ()
    {
      Object (name: "telepathy");
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
   * {@inheritDoc}
   */
  public override async void prepare () throws GLib.Error
    {
      lock (this._is_prepared)
        {
          if (!this._is_prepared)
            {
              this.account_manager = AccountManager.dup ();
              yield this.account_manager.prepare_async (null);
              this.account_manager.account_enabled.connect (
                  this.account_enabled_cb);
              this.account_manager.account_validity_changed.connect (
                  (a, valid) =>
                    {
                      if (valid)
                        this.account_enabled_cb (a);
                    });

              GLib.List<unowned Account> accounts =
                  this.account_manager.get_valid_accounts ();
              foreach (Account account in accounts)
                {
                  this.account_enabled_cb (account);
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
      this.account_manager.account_enabled.disconnect (this.account_enabled_cb);
      this.account_manager.account_validity_changed.disconnect (
          this.account_validity_changed_cb);
      this.account_manager = null;

      this.persona_stores.foreach ((k, v) =>
        {
          this.persona_store_removed ((PersonaStore) v);
        });

      this.persona_stores.remove_all ();

      this._is_prepared = false;
      this.notify_property ("is-prepared");
    }

  private void account_validity_changed_cb (Account account, bool valid)
    {
      if (valid)
        this.account_enabled_cb (account);
    }

  private void account_enabled_cb (Account account)
    {
      PersonaStore store = this.persona_stores.lookup (
          account.get_object_path ());

      if (store != null)
        return;

      store = new Tpf.PersonaStore (account);

      this.persona_stores.insert (store.id, store);
      store.removed.connect (this.store_removed_cb);

      this.persona_store_added (store);
    }

  private void store_removed_cb (PersonaStore store)
    {
      this.persona_store_removed (store);
      this.persona_stores.remove (store.id);
    }
}
