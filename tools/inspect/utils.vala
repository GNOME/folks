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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Folks;
using Gee;
using GLib;

private class Folks.Inspect.Utils
{
  /* The current indentation level, in spaces */
  private static uint indentation = 0;
  private static string indentation_string = "";

  public static void init ()
    {
      Utils.indentation_string = "";

      /* Register some general transformation functions */
      Value.register_transform_func (typeof (Object), typeof (string),
          Utils.transform_object_to_string);
      Value.register_transform_func (typeof (Folks.PersonaStore),
          typeof (string), Utils.transform_persona_store_to_string);
      Value.register_transform_func (typeof (string[]), typeof (string),
          Utils.transform_string_array_to_string);
    }

  private static void transform_object_to_string (Value src,
      out Value dest)
    {
      /* FIXME: works around bgo#638363 */
      Value dest_tmp = Value (typeof (string));
      dest_tmp.take_string ("%p".printf (src.get_object ()));
      dest = dest_tmp;
    }

  private static void transform_persona_store_to_string (Value src,
      out Value dest)
    {
      /* FIXME: works around bgo#638363 */
      Value dest_tmp = Value (typeof (string));
      Folks.PersonaStore store = (Folks.PersonaStore) src.get_object ();
      dest_tmp.take_string ("%p: %s, %s (%s)".printf (store, store.type_id,
          store.id, store.display_name));
      dest = dest_tmp;
    }

  private static void transform_string_array_to_string (Value src,
      out Value dest)
    {
      /* FIXME: works around bgo#638363 */
      Value dest_tmp = Value (typeof (string));
      unowned string[] array = (string[]) src.get_boxed ();
      string output = "{ ";
      bool first = true;
      foreach (string element in array)
        {
          if (first == false)
            output += ", ";
          output += "'%s'".printf (element);
          first = false;
        }
      output += " }";
      dest_tmp.take_string (output);
      dest = dest_tmp;
    }

  public static void indent ()
    {
      /* We indent in increments of two spaces */
      Utils.indentation += 2;
      Utils.indentation_string = string.nfill (Utils.indentation, ' ');
    }

  public static void unindent ()
    {
      Utils.indentation -= 2;
      Utils.indentation_string = string.nfill (Utils.indentation, ' ');
    }

  [PrintfFormat ()]
  public static void print_line (string format, ...)
    {
      /* FIXME: store the va_list temporarily to work around bgo#638308 */
      var valist = va_list ();
      string output = format.vprintf (valist);
      stdout.printf ("%s%s\n", Utils.indentation_string, output);
    }

  public static void print_individual (Individual individual,
      bool show_personas)
    {
      Utils.print_line ("Individual '%s' with %u personas:",
          individual.id, individual.personas.length ());

      /* List the Individual's properties */
      unowned ParamSpec[] properties =
          individual.get_class ().list_properties ();

      Utils.indent ();
      foreach (unowned ParamSpec pspec in properties)
        {
          Value prop_value;
          string output_string;

          /* Ignore the personas property if we're printing the personas out */
          if (show_personas == true && pspec.get_name () == "personas")
            continue;

          prop_value = Value (pspec.value_type);
          individual.get_property (pspec.get_name (), ref prop_value);

          output_string = Utils.property_to_string (individual.get_type (),
              pspec.get_name (), prop_value);

          Utils.print_line ("%-20s  %s", pspec.get_nick (), output_string);
        }

      if (show_personas == true)
        {
          Utils.print_line ("");
          Utils.print_line ("Personas:");

          Utils.indent ();
          foreach (Persona persona in individual.personas)
            Utils.print_persona (persona);
          Utils.unindent ();
        }
      Utils.unindent ();
    }

  public static void print_persona (Persona persona)
    {
      Utils.print_line ("Persona '%s':", persona.uid);

      /* List the Persona's properties */
      unowned ParamSpec[] properties =
          persona.get_class ().list_properties ();

      Utils.indent ();
      foreach (unowned ParamSpec pspec in properties)
        {
          Value prop_value;
          string output_string;

          prop_value = Value (pspec.value_type);
          persona.get_property (pspec.get_name (), ref prop_value);

          output_string = Utils.property_to_string (persona.get_type (),
              pspec.get_name (), prop_value);

          Utils.print_line ("%-20s  %s", pspec.get_nick (), output_string);
        }
      Utils.unindent ();
    }

  public static void print_persona_store (PersonaStore store,
      bool show_personas)
    {
      Utils.print_line ("Persona store '%s' with %u personas:",
          store.id, store.personas.size ());

      /* List the store's properties */
      unowned ParamSpec[] properties =
          store.get_class ().list_properties ();

      Utils.indent ();
      foreach (unowned ParamSpec pspec in properties)
        {
          Value prop_value;
          string output_string;

          /* Ignore the personas property if we're printing the personas out */
          if (show_personas == true && pspec.get_name () == "personas")
            continue;

          prop_value = Value (pspec.value_type);
          store.get_property (pspec.get_name (), ref prop_value);

          output_string = Utils.property_to_string (store.get_type (),
              pspec.get_name (), prop_value);

          Utils.print_line ("%-20s  %s", pspec.get_nick (), output_string);
        }

      if (show_personas == true)
        {
          Utils.print_line ("");
          Utils.print_line ("Personas:");

          Utils.indent ();
          store.personas.foreach ((k, v) =>
            {
              Utils.print_persona ((Persona) v);
            });
          Utils.unindent ();
        }
      Utils.unindent ();
    }

  private static string property_to_string (Type object_type,
      string prop_name,
      Value prop_value)
    {
      string output_string;

      /* Overrides for various known properties */
      if (object_type.is_a (typeof (Individual)) && prop_name == "personas")
        {
          unowned GLib.List<Persona> personas =
              (GLib.List<Persona>) prop_value.get_pointer ();
          return "List of %u personas".printf (personas.length ());
        }
      else if (object_type.is_a (typeof (PersonaStore)) &&
          prop_name == "personas")
        {
          unowned HashTable<string, Persona> personas =
              (HashTable<string, Persona>) prop_value.get_boxed ();
          return "Set of %u personas".printf (personas.size ());
        }
      else if (prop_name == "groups")
        {
          HashTable<string, bool> groups =
              (HashTable<string, bool>) prop_value.get_boxed ();
          output_string = "{ ";
          bool first = true;

          /* FIXME: This is rather inefficient */
          groups.foreach ((k, v) =>
            {
              if ((bool) v == true)
                {
                  if (first == false)
                    output_string += ", ";
                  output_string += "'%s'".printf ((string) k);
                  first = false;
                }
            });

          output_string += " }";
          return output_string;
        }
      else if (prop_name == "avatar")
        {
          string ret = null;
          File avatar = (File) prop_value.get_object ();
          if (avatar != null)
            ret = avatar.get_uri ();
          return ret;
        }
      else if (prop_name == "im-addresses")
        {
          MultiMap<string, string> im_addresses =
              (MultiMap<string, string>) prop_value.get_object ();
          output_string = "{ ";
          bool first = true;

          foreach (var protocol in im_addresses.get_keys ())
            {
              if (first == false)
                output_string += ", ";
              output_string += "'%s' : { ".printf (protocol);
              first = false;

              var addresses = im_addresses.get (protocol);
              bool _first = true;
              foreach (var a in addresses)
                {
                  if (_first == false)
                    output_string += ", ";
                  output_string += "'%s'".printf ((string) a);
                  _first = false;
                }

              output_string += " }";
            }

          output_string += " }";
          return output_string;
        }
      else if (prop_name == Folks.PersonaStore.detail_key
          (PersonaDetail.WEB_SERVICE_ADDRESSES))
        {
          MultiMap<string, string> web_service_addresses =
              (MultiMap<string, string>) prop_value.get_object ();
          output_string = "{ ";
          bool first = true;

          foreach (var web_service in web_service_addresses.get_keys ())
            {
              if (first == false)
                output_string += ", ";
              output_string += "'%s' : { ".printf (web_service);
              first = false;

              var addresses = web_service_addresses.get (web_service);
              bool _first = true;
              foreach (var a in addresses)
                {
                  if (_first == false)
                    output_string += ", ";
                  output_string += "'%s'".printf ((string) a);
                  _first = false;
                }

              output_string += " }";
            }

          output_string += " }";
          return output_string;
        }
      else if (prop_name == "email-addresses" ||
               prop_name == "urls" ||
               prop_name == "phone-numbers")
        {
          output_string = "{ ";
          bool first = true;
          unowned GLib.List<FieldDetails> prop_list =
              (GLib.List<FieldDetails>) prop_value.get_pointer ();

          foreach (var p in prop_list)
            {
              if (!first)
                {
                  output_string += ", ";
                }
              output_string +=  p.value;
              first = false;
            }
            output_string += " }";

            return output_string;
        }
      else if (prop_name == "birthday")
        {
          unowned DateTime dobj = (DateTime) prop_value.get_boxed ();
          if (dobj != null)
            return dobj.to_string ();
          else
            return "";
        }
      else if (prop_name == "postal-addresses")
        {
          output_string = "{ ";
          bool first = true;
          unowned GLib.List<PostalAddress> prop_list =
              (GLib.List<PostalAddress>) prop_value.get_pointer ();

          foreach (var p in prop_list)
            {
              if (!first)
                {
                  output_string += ". ";
                }
              output_string +=  p.to_string ();
              first = false;
            }
            output_string += " }";

            return output_string;
        }
      else if (prop_name == "structured-name")
        {
          unowned StructuredName sn = (StructuredName) prop_value.get_object ();
          string ret = null;
          if (sn != null)
            ret = sn.to_string ();
          return ret;
        }

      return Utils.transform_value_to_string (prop_value);
    }

  public static string transform_value_to_string (Value prop_value)
    {
      if (Value.type_transformable (prop_value.type (), typeof (string)))
        {
          /* Convert to a string value */
          Value string_value = Value (typeof (string));
          prop_value.transform (ref string_value);
          return string_value.get_string ();
        }
      else
        {
          /* Can't convert the property value to a string */
          return "Can't convert from type '%s' to '%s'".printf (
              prop_value.type ().name (), typeof (string).name ());
        }
    }

  /* FIXME: This can't be in the command_completion_cb() function because Vala
   * doesn't allow static local variables. Erk. */
  private static MapIterator<string, Command>? command_name_iter = null;

  /* Complete a command name, starting with @word. */
  public static string? command_name_completion_cb (string word,
      int state)
    {
      /* Initialise state. Whoever wrote the readline API should be shot. */
      if (state == 0)
        Utils.command_name_iter = main_client.commands.map_iterator ();

      while (Utils.command_name_iter.next () == true)
        {
          string command_name = Utils.command_name_iter.get_key ();
          if (command_name.has_prefix (word))
            return command_name;
        }

      /* Clean up */
      Utils.command_name_iter = null;
      return null;
    }

  /* FIXME: This can't be in the individual_id_completion_cb() function because
   * Vala doesn't allow static local variables. Erk. */
  private static HashTableIter<string, Individual>? individual_id_iter = null;

  /* Complete an individual's ID, starting with @word. */
  public static string? individual_id_completion_cb (string word,
      int state)
    {
      /* Initialise state. Whoever wrote the readline API should be shot. */
      if (state == 0)
        {
          Utils.individual_id_iter = HashTableIter<string, Individual> (
              main_client.aggregator.individuals);
        }

      string id;
      Individual individual;
      while (Utils.individual_id_iter.next (out id, out individual) == true)
        {
          if (id.has_prefix (word))
            return id;
        }

      /* Clean up */
      Utils.individual_id_iter = null;
      return null;
    }

  /* FIXME: This can't be in the individual_id_completion_cb() function because
   * Vala doesn't allow static local variables. Erk. */
  private static unowned GLib.List<Persona>? persona_uid_iter = null;

  /* Complete an individual's ID, starting with @word. */
  public static string? persona_uid_completion_cb (string word,
      int state)
    {
      /* Initialise state. Whoever wrote the readline API should be shot. */
      if (state == 0)
        {
          Utils.individual_id_iter = HashTableIter<string, Individual> (
              main_client.aggregator.individuals);
          Utils.persona_uid_iter = null;
        }

      Individual individual = null;
      while (Utils.persona_uid_iter != null ||
          Utils.individual_id_iter.next (null, out individual) == true)
        {
          if (Utils.persona_uid_iter == null)
            {
              assert (individual != null);
              Utils.persona_uid_iter = individual.personas;
            }

          while (Utils.persona_uid_iter != null)
            {
              unowned Persona persona = (Persona) Utils.persona_uid_iter.data;
              Utils.persona_uid_iter = Utils.persona_uid_iter.next;
              if (persona.uid.has_prefix (word))
                return persona.uid;
            }
        }

      /* Clean up */
      Utils.individual_id_iter = null;
      return null;
    }

  /* FIXME: This can't be in the backend_name_completion_cb() function because
   * Vala doesn't allow static local variables. Erk. */
  private static Iterator<Backend>? backend_name_iter = null;

  /* Complete an individual's ID, starting with @word. */
  public static string? backend_name_completion_cb (string word,
      int state)
    {
      /* Initialise state. Whoever wrote the readline API should be shot. */
      if (state == 0)
        {
          Utils.backend_name_iter =
              main_client.backend_store.list_backends ().iterator ();
        }

      while (Utils.backend_name_iter.next () == true)
        {
          Backend backend = Utils.backend_name_iter.get ();
          if (backend.name.has_prefix (word))
            return backend.name;
        }

      /* Clean up */
      Utils.backend_name_iter = null;
      return null;
    }

  /* FIXME: This can't be in the persona_store_id_completion_cb() function
   * because Vala doesn't allow static local variables. Erk. */
  private static HashTableIter<string, PersonaStore>? persona_store_id_iter =
      null;

  /* Complete a persona store's ID, starting with @word. */
  public static string? persona_store_id_completion_cb (string word,
      int state)
    {
      /* Initialise state. Whoever wrote the readline API should be shot. */
      if (state == 0)
        {
          Utils.backend_name_iter =
              main_client.backend_store.list_backends ().iterator ();
          Utils.persona_store_id_iter = null;
        }

      while (Utils.persona_store_id_iter != null ||
          Utils.backend_name_iter.next () == true)
        {
          if (Utils.persona_store_id_iter == null)
            {
              Backend backend = Utils.backend_name_iter.get ();
              Utils.persona_store_id_iter =
                  HashTableIter<string, PersonaStore> (backend.persona_stores);
            }

          string id;
          PersonaStore store;
          while (Utils.persona_store_id_iter.next (out id, out store) == true)
            {
              if (id.has_prefix (word))
                return id;
            }

          /* Clean up */
          Utils.persona_store_id_iter = null;
        }

      /* Clean up */
      Utils.backend_name_iter = null;
      return null;
    }
}
