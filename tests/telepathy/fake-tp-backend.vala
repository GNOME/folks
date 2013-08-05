/*
 * Copyright (C) 2012 Philip Withnall
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
 * Authors: Philip Withnall <philip@tecnocode.co.uk>
 */

using TpTests;
using Folks;

/* A simple test program to expose the test Telepathy account used by folks’
 * Telepathy tests on the current D-Bus bus. This is intended to be used for
 * manual testing using the test Telepathy account. */

public int main (string[] args)
{
  var tp_backend = new TpTests.Backend ();

  tp_backend.set_up ();
  void *account_handle = tp_backend.add_account ("protocol", "me@example.com",
      "cm", "account");

  var main_loop = new GLib.MainLoop (null, false);

  /* Set up the aggregator */
  var aggregator = IndividualAggregator.dup ();

  Idle.add (() =>
    {
      aggregator.prepare.begin ((s,r) =>
        {
          try
            {
              aggregator.prepare.end (r);
            }
          catch (GLib.Error e1)
            {
              GLib.critical ("Failed to prepare aggregator: %s", e1.message);
              assert_not_reached ();
            }
        });

      return false;
    });

  /* Run until we're killed. */
  main_loop.run ();

  /* Tear down .*/
  aggregator = null;

  tp_backend.remove_account (account_handle);
  tp_backend.tear_down ();

  return 0;
}
