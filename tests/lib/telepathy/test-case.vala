/* test-case.vala
 *
 * Copyright © 2011 Collabora Ltd.
 * Copyright © 2013 Intel Corporation
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
 * Authors:
 *      Travis Reitter <travis.reitter@collabora.co.uk>
 *      Simon McVittie <simon.mcvittie@collabora.co.uk>
 */

/**
 * A test case with a Telepathy backend (used to test the Telepathy
 * backend specifically), and optionally also a keyfile backend
 * (used to test Folks in general - see //MixedTestCase//).
 *
 * Folks is configured to use the Telepathy backend, with no primary store,
 * unless //use_keyfile_too// is set.
 */
public class TpfTest.TestCase : Folks.TestCase
{
  /**
   * The key-file backend, or null if a test case has overridden
   * create_kf_backend() to avoid creating it, or has left
   * //use_keyfile_too// set to false.
   *
   * For the moment this is created in the constructor and freed
   * in the destructor; ideally those would move into set_up() and
   * tear_down() at some point.
   *
   * If this is non-null, the subclass is expected to have called
   * its set_up() method at some point before tear_down() is reached.
   */
  public KfTest.Backend? kf_backend = null;

  /**
   * The Telepathy backend, or null if a test case has overridden
   * create_tp_backend() to avoid creating it.
   *
   * If this is non-null, the subclass is expected to have called
   * its set_up() method at some point before tear_down() is reached.
   */
  public TpTests.Backend? tp_backend = null;

  /**
   * An account used by the //tp_backend//, or null if a test case
   * has overridden set_up_tp() to avoid creating it.
   *
   * If non-null when tear_down() is reached, this account will be
   * removed automatically.
   */
  public void *account_handle = null;

  /**
   * If true, Folks will be configured to use a key-file as its primary
   * store, and allow both Telepathy and the key-file to be loaded.
   * This is used to test Folks in general (e.g. the IndividualAggregator).
   *
   * If false, Folks will be configured to use Telepathy only, with no
   * primary store. This is used to test the Telepathy backend.
   */
  public virtual bool use_keyfile_too
    {
      get
        {
          return false;
        }
    }

  /**
   * Set ``FOLKS_BACKENDS_ALLOWED`` and ``FOLKS_PRIMARY_STORE``,
   * and create the backends if appropriate (although the latter should
   * ideally move into set_up()).
   */
  public TestCase (string name)
    {

      base (name);

      if (use_keyfile_too)
        {
          Environment.set_variable ("FOLKS_BACKENDS_ALLOWED",
              "telepathy,key-file", true);
          Environment.set_variable ("FOLKS_PRIMARY_STORE", "key-file", true);
        }
      else
        {
          Environment.set_variable ("FOLKS_BACKENDS_ALLOWED",
              "telepathy", true);
          Environment.set_variable ("FOLKS_PRIMARY_STORE", "", true);
        }

      this.create_kf_backend ();
      this.create_tp_backend ();
    }

  /**
   * Virtual method to create the keyfile backend. Currently called by
   * the constructor (once per process), but might move into set_up() later.
   *
   * The default implementation respects //use_keyfile_too//. Subclasses
   * can override this to never, or always, create this backend.
   *
   * Subclasses may chain up, but are not required to so.
   */
  public virtual void create_kf_backend ()
    {
      /* Default key-file backend file to load. */
      Environment.set_variable ("FOLKS_BACKEND_KEY_FILE_PATH",
          Folks.TestUtils.get_source_test_data ("telepathy/relationships-empty.ini"),
          true);

      if (use_keyfile_too)
        this.kf_backend = new KfTest.Backend ();
    }

  /**
   * Virtual method to create the Telepathy backend. Currently called by
   * the constructor (once per process), but might move into set_up() later.
   *
   * Subclasses may chain up, but are not required to so.
   */
  public virtual void create_tp_backend ()
    {
      this.tp_backend = new TpTests.Backend ();
    }

  public override void set_up ()
    {
      base.set_up ();
      this.set_up_tp ();
      this.set_up_kf ();
    }

  /**
   * Virtual method to set up the Telepathy backend, called from
   * set_up(). The default implementation sets it up and adds one account,
   * storing its handle in //account_handle//.
   *
   * Subclasses may override this to avoid setting up any accounts, to
   * set up more than one account, or to avoid setup at this stage
   * (deferring it until the test itself). However, if tp_backend
   * is not null at tear_down(), the subclass is expected to have called
   * set_up() on it at some point.
   *
   * Subclasses may chain up, but are not required to so.
   */
  public virtual void set_up_tp ()
    {
      if (this.tp_backend != null)
        {
          var tp_backend = (!) this.tp_backend;

          tp_backend.set_up ();
          this.account_handle = tp_backend.add_account ("protocol",
              "me@example.com", "cm", "account");
        }
    }

  /**
   * Virtual method to set up the key-file backend, called from
   * set_up(). The default implementation sets it up using an empty
   * key-file, unless it has not been created. Subclasses may override
   * this to set it up with different contents, or to avoid setup
   * altogether (deferring it until the test itself). However, if kf_backend
   * is not null at tear_down(), the subclass is expected to have called
   * set_up() on it at some point.
   *
   * Subclasses may chain up, but are not required to so.
   */
  public virtual void set_up_kf ()
    {
      if (this.kf_backend != null)
        ((!) this.kf_backend).set_up ("");
    }

  public override void tear_down ()
    {
      if (this.tp_backend != null)
        {
          var tp_backend = (!) this.tp_backend;

          if (this.account_handle != null)
            {
              tp_backend.remove_account (account_handle);
              this.account_handle = null;
            }

          tp_backend.tear_down ();
        }

      if (this.kf_backend != null)
        {
          ((!) this.kf_backend).tear_down ();
        }

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

  internal extern static void _dbus_1_set_no_exit_on_disconnect ();

  public override void final_tear_down ()
    {
      TestCase._dbus_1_set_no_exit_on_disconnect ();

      base.final_tear_down ();
    }
}

/**
 * A test-case for the combination of Telepathy and a key-file,
 * used to test things like the IndividualAggregator. This is just
 * TestCase with //use_keyfile_too// overridden to true.
 *
 * Folks is configured to use the Telepathy and key-file backends,
 * with the latter as its primary store.
 */
public class TpfTest.MixedTestCase : TpfTest.TestCase
{
  public override bool use_keyfile_too
    {
      get
        {
          return true;
        }
    }

  public MixedTestCase (string name)
    {
      base (name);
    }
}
