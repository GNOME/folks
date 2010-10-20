using DBus;
using TelepathyGLib;
using TpTest;
using Tpf;
using Folks;
using Gee;

public class IndividualPropertiesTests : Folks.TestCase
{
  private TpTest.Backend tp_backend;
  private string individual_id_prefix = "telepathy:protocol:";

  public IndividualPropertiesTests ()
    {
      base ("IndividualProperties");

      this.tp_backend = new TpTest.Backend ();

      this.add_test ("individual properties",
          this.test_individual_properties);
      this.add_test ("individual properties:change alias through tp backend",
          this.test_individual_properties_change_alias_through_tp_backend);
      this.add_test ("individual properties:change alias through test cm",
          this.test_individual_properties_change_alias_through_test_cm);
    }

  public override void set_up ()
    {
      this.tp_backend.set_up ();
    }

  public override void tear_down ()
    {
      this.tp_backend.tear_down ();
    }

  public void test_individual_properties ()
    {
      var main_loop = new GLib.MainLoop (null, false);

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("The name org.freedesktop.Telepathy.Logger " +
              "was not provided by any .service files");
        });

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          foreach (Individual i in added)
            {
              /* We only check one */
              if (i.id != (this.individual_id_prefix + "olivier@example.com"))
                {
                  continue;
                }

              /* Check properties */
              assert (i.alias == "Olivier");
              assert (i.presence_message == "");
              assert (i.presence_type == PresenceType.AWAY);
              assert (i.is_online () == true);

              /* Check groups */
              assert (i.groups.size () == 2);
              assert (i.groups.lookup ("Montreal") == true);
              assert (i.groups.lookup ("Francophones") == true);
            }

          assert (removed == null);
        });
      aggregator.prepare ();

      /* Kill the main loop after a few seconds. If there are still individuals
       * in the set of expected individuals, the aggregator has either failed
       * or been too slow (which we can consider to be failure). */
      Timeout.add_seconds (3, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_individual_properties_change_alias_through_tp_backend ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var alias_notified = false;

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("The name org.freedesktop.Telepathy.Logger " +
              "was not provided by any .service files");
        });

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          var new_alias = "New Alias";

          foreach (Individual i in added)
            {
              /* We only check one */
              if (i.id != (this.individual_id_prefix + "olivier@example.com"))
                {
                  continue;
                }

              /* Check properties */
              assert (i.alias != new_alias);

              i.notify["alias"].connect ((s, p) =>
                  {
                    /* we can't re-use i here due to Vala's implementation */
                    var ind = (Individual) s;

                    if (ind.alias == new_alias)
                      alias_notified = true;
                  });

              /* the contact list this aggregator is based upon has exactly 1
               * Tpf.Persona per Individual */
              var persona = i.personas.data;
              assert (persona is Tpf.Persona);

              /* set the alias through Telepathy and wait for it to hit our
               * alias notification callback above */

              ((Tpf.Persona) persona).alias = new_alias;
            }

          assert (removed == null);
        });
      aggregator.prepare ();

      /* Kill the main loop after a few seconds. If the alias hasn't been
       * notified, something along the way failed or been too slow (which we can
       * consider to be failure). */
      Timeout.add_seconds (3, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      assert (alias_notified);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }

  public void test_individual_properties_change_alias_through_test_cm ()
    {
      var main_loop = new GLib.MainLoop (null, false);
      var alias_notified = false;

      /* Ignore the error caused by not running the logger */
      Test.log_set_fatal_handler ((d, l, m) =>
        {
          return !m.has_suffix ("The name org.freedesktop.Telepathy.Logger " +
              "was not provided by any .service files");
        });

      /* Set up the aggregator */
      var aggregator = new IndividualAggregator ();
      aggregator.individuals_changed.connect ((added, removed, m, a, r) =>
        {
          var new_alias = "New Alias";

          foreach (Individual i in added)
            {
              /* We only check one */
              if (i.id != (this.individual_id_prefix + "olivier@example.com"))
                {
                  continue;
                }

              /* Check properties */
              assert (i.alias != new_alias);

              i.notify["alias"].connect ((s, p) =>
                  {
                    /* we can't re-use i here due to Vala's implementation */
                    var ind = (Individual) s;

                    if (ind.alias == new_alias)
                      alias_notified = true;
                  });

              /* the contact list this aggregator is based upon has exactly 1
               * Tpf.Persona per Individual */
              var persona = i.personas.data;
              assert (persona is Tpf.Persona);

              /* set the alias through Telepathy and wait for it to hit our
               * alias notification callback above */

              var handle = (Handle) ((Tpf.Persona) persona).contact.handle;
              this.tp_backend.connection.manager.set_alias (handle, new_alias);
            }

          assert (removed == null);
        });
      aggregator.prepare ();

      /* Kill the main loop after a few seconds. If the alias hasn't been
       * notified, something along the way failed or been too slow (which we can
       * consider to be failure). */
      Timeout.add_seconds (3, () =>
        {
          main_loop.quit ();
          return false;
        });

      main_loop.run ();

      assert (alias_notified);

      /* necessary to reset the aggregator for the next test */
      aggregator = null;
    }
}

public int main (string[] args)
{
  Test.init (ref args);

  TestSuite root = TestSuite.get_root ();
  root.add_suite (new IndividualPropertiesTests ().get_suite ());

  Test.run ();

  return 0;
}
