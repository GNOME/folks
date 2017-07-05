/*
 * Copyright (C) 2012 Collabora
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
 * Authors: Seif Lotfy <seif.lotfy@collabora.co.uk>
 */

using TpTests;
using Folks;

/* A simple test program to expose the test Telepathy account used by folks’
 * Telepathy tests on the current D-Bus bus. This is intended to be used for
 * manual testing using the test Telepathy account. */

private void print_individual (Individual i)
{
  uint new_count = i.im_interaction_count;
  uint new_call_count = i.call_interaction_count;
  DateTime new_call_datetime = i.last_call_interaction_datetime;
  DateTime new_chat_datetime = i.last_im_interaction_datetime;
  if (new_count > 0)
    {
      int64 timestamp = 0;
      if (new_chat_datetime != null)
        timestamp = new_chat_datetime.to_unix();
      stdout.printf("\n %s\n   chat interaction count: %u\n   chat interaction timestamp: %" + int64.FORMAT + "\n", i.alias, new_count, timestamp);
      timestamp = 0;
      if (new_call_datetime != null)
        timestamp = new_call_datetime.to_unix();
      stdout.printf("   call interaction count: %u\n   call interaction timestamp: %" + int64.FORMAT + "\n", new_call_count, timestamp);
    }
}

public int main (string[] args)
{
  var main_loop = new GLib.MainLoop (null, false);
  /* Set up the aggregator */
  var aggregator = IndividualAggregator.dup ();

  aggregator.notify["is-quiescent"].connect (() =>
    {
      foreach (Individual i in aggregator.individuals.values)
        {
          uint count = i.im_interaction_count;
          uint call_count = i.call_interaction_count;
          DateTime chat_datetime = i.last_im_interaction_datetime;
          DateTime call_datetime = i.last_call_interaction_datetime;
          if (count > 0)
            {
              int64 timestamp = 0;
              if (chat_datetime != null)
                timestamp = chat_datetime.to_unix();
              stdout.printf("\n %s\n   chat interaction count: %u\n   chat interaction timestamp: %" + int64.FORMAT + "\n", i.alias, count, timestamp);
              timestamp = 0;
              if (call_datetime != null)
                timestamp = call_datetime.to_unix();
              stdout.printf("   call interaction count: %u\n   call interaction timestamp: %" + int64.FORMAT + "\n", call_count, timestamp);
            }
          i.notify["im-interaction-count"].connect(() => {print_individual (i);});
          i.notify["call-interaction-count"].connect(() => {print_individual (i);});
        }
    });

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

  return 0;
}
