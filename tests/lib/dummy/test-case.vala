/* test-case.vala
 *
 * Copyright © 2013 Collabora Ltd.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.

 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
 *
 * Author:
 *      Renato Araujo Oliveira Filho <renato@canonical.com>
 *      Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Folks;
using Gee;

/**
 * A test case for the dummy backend, which is configured as the
 * primary store and as the only backend allowed.
 *
 * @since 0.9.7
 */
public class DummyTest.TestCase : Folks.TestCase
{
  private BackendStore _backend_store;

  /**
   * The dummy test backend.
   *
   * @since 0.9.7
   */
  public FolksDummy.Backend dummy_backend;

  /**
   * The default dummy persona store.
   *
   * @since 0.9.7
   */
  public FolksDummy.PersonaStore dummy_persona_store;

  /**
   * Create a new dummy test case.
   *
   * @param name test case name
   *
   * @since 0.9.7
   */
  public TestCase (string name)
    {
      base (name);

      Environment.set_variable ("FOLKS_BACKENDS_ALLOWED", "dummy", true);
      Environment.set_variable ("FOLKS_PRIMARY_STORE", "dummy", true);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.7
   */
  public override void set_up ()
    {
      base.set_up ();

      var main_loop = new GLib.MainLoop (null, false);

      this._backend_store = BackendStore.dup ();
      this._backend_store.load_backends.begin ((obj, res) =>
        {
            try
              {
                this._backend_store.load_backends.end (res);
                main_loop.quit ();
              }
            catch (GLib.Error e1)
              {
                error ("Failed to initialise backend store: %s", e1.message);
              }
        });

      TestUtils.loop_run_with_timeout (main_loop);

      /* Grab the dummy backend. */
      this.dummy_backend =
          (FolksDummy.Backend)
              this._backend_store.dup_backend_by_name ("dummy");
      assert (this.dummy_backend != null);

      this.configure_primary_store ();
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.7
   */
  public virtual void configure_primary_store ()
    {
      string[] writable_properties =
        {
          Folks.PersonaStore.detail_key (PersonaDetail.BIRTHDAY),
          Folks.PersonaStore.detail_key (PersonaDetail.EMAIL_ADDRESSES),
          Folks.PersonaStore.detail_key (PersonaDetail.PHONE_NUMBERS),
          null
        };

      /* Create a new persona store. */
      this.dummy_persona_store =
          new FolksDummy.PersonaStore ("dummy-store", "Dummy personas",
              writable_properties);
      this.dummy_persona_store.persona_type = typeof (FolksDummy.FullPersona);

      /* Register it with the backend. */
      var persona_stores = new HashSet<FolksDummy.PersonaStore> ();
      persona_stores.add (this.dummy_persona_store);
      this.dummy_backend.register_persona_stores (persona_stores);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.9.7
   */
  public override void tear_down ()
    {
      var persona_stores = new HashSet<FolksDummy.PersonaStore> ();
      persona_stores.add (this.dummy_persona_store);
      this.dummy_backend.unregister_persona_stores (persona_stores);

      this.dummy_persona_store = null;
      this.dummy_backend = null;
      this._backend_store = null;

      /* Ensure that all pending operations are complete.
       *
       * FIXME: This should be eliminated and unprepare() should guarantee there
       * are no more pending Backend/PersonaStore events.
       *
       * https://bugzilla.gnome.org/show_bug.cgi?id=727700 */
      var context = MainContext.default ();
      while (context.iteration (false));

      base.tear_down ();
    }
}
