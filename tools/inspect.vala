/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Copyright 2023 Collabora, Ltd.
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
 */

public class FolksInspect.Application : GLib.Application {
  private Application () {
    Object (application_id: "org.gnome.Folks.Inspect", flags: ApplicationFlags.NON_UNIQUE);
  }

  public override void activate () {
    try {
      var manager = new Folks.Manager.sync ();
      print ("Found %u addressbooks:\n", manager.get_n_items ());
      for (uint i = 0; i < manager.get_n_items (); i++) {
        var store = (Folks.PersonaStore) manager.get_object (i);
        hold ();
        store.load.begin (null, (obj, res) => {
          try {
            store.load.end (res);
          } catch (Error e) {
            critical (e.message);
          }

          for (uint j = 0; j < store.get_n_items (); j++) {
            var persona = (Folks.Persona) store.get_object (j);
            print ("  - %s\n", persona.fullname);
          }

          release ();
        });
        print (" - %s\n", store.title);
      }
    } catch (Error e) {
      error ("Unable to connect to Folks service: %s", e.message);
    }
  }

  public static int main (string[] args) {
    Application app = new Application ();
    return app.run (args);
  }
}
