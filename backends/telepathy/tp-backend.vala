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

      this.persona_stores = new HashTable<string, PersonaStore> (str_hash,
          str_equal);
    }

  public override async void prepare () throws GLib.Error
    {
      this.account_manager = AccountManager.dup ();
      yield this.account_manager.prepare_async (null);
      this.account_manager.account_enabled.connect (this.account_enabled_cb);
      this.account_manager.account_validity_changed.connect ((a, valid) =>
        {
          if (valid)
            this.account_enabled_cb (a);
        });

      GLib.List<unowned Account> accounts = this.account_manager.get_valid_accounts ();
      foreach (Account account in accounts)
        {
          this.account_enabled_cb (account);
        }
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
