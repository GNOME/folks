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

/**
 * Represents a "shard" of a person from a single source (a single
 * {@link Backend}), such as an XMPP contact from Telepathy or a vCard contact
 * from evolution-data-server.
 *
 * All the personas belonging to one physical person are aggregated to form a
 * single {@link Individual} representing that person.
 */
public abstract class Folks.Persona : Object
{
  /**
   * The internal ID used to represent the Persona for linking.
   *
   * This is opaque, and shouldn't be parsed or considered meaningful by
   * clients.
   *
   * The internal ID should be unique within a backend, but may not be unique
   * across backends, so that links can be made between Personas with similar
   * internal IDs.
   */
  /* For example: jabber:foo@xmpp.example.org or joe@example.org */
  public string iid { get; construct; }

  /**
   * The universal ID used to represent the Persona outside its {@link Backend}.
   *
   * This is opaque, and should only be parsed by clients using
   * {@link Persona.split_uid}.
   *
   * This is the canonical way to refer to any Persona. It is guaranteed to be
   * unique within the Persona's {@link PersonaStore}.
   *
   * @see Persona.build_uid
   * @see Persona.split_uid
   */
  /* For example: telepathy:jabber:foo@xmpp.example.org or
   * key-file:relationships.ini:joe@example.org
   *
   * It comprises three components, separated by colons:
   * # {@link Backend.name}
   * # {@link PersonaStore.id}
   * # Persona identifier
   * Each component is escaped by replacing all colons with double underscores
   * before building the UID.*/
  public string uid { get; construct; }

  /**
   * The human-readable, service-specific universal ID used to represent the
   * Persona.
   *
   * For example: `foo@@xmpp.example.org`.
   *
   * This should be used whenever the user needs to be presented with a
   * familiar, service-specific ID. For instance, in a prompt for the user to
   * select a specific IM contact within an {@link Individual} to begin a chat
   * with.
   *
   * This is not guaranteed to be unique outside of the Persona's
   * {@link PersonaStore}.
   *
   * @since 0.1.13
   */
  public string display_id { get; construct; }

  /**
   * Whether the Persona is the user.
   *
   * Iff the Persona represents the user – the person who owns the account in
   * the respective backend – this is `true`.
   *
   * @since 0.3.0
   */
  public bool is_user { get; construct; }

  /**
   * The {@link PersonaStore} which contains this Persona.
   */
  public weak PersonaStore store { get; construct; }

  /**
   * The names of the properties of this Persona which are linkable.
   *
   * If a property name is in this list, and the Persona is from a
   * {@link PersonaStore} whose trust level is {@link PersonaStoreTrust.FULL},
   * the {@link IndividualAggregator} should be able to reliably use the value
   * of the property from a given Persona instance to link the Persona with
   * other Personas and form {@link Individual}s.
   *
   * Note that {@link Persona.uid} is always implicitly a member of this list,
   * and doesn't need to be added explicitly.
   *
   * This list will have no effect if the Persona's {@link PersonaStore} trust
   * level is not {@link PersonaStoreTrust.FULL}.
   *
   * @since 0.1.13
   */
  public string[] linkable_properties { get; protected set; }

  /**
   * Callback into the aggregator to manipulate a link mapping.
   *
   * This is a callback provided by the {@link IndividualAggregator} whenever
   * a {@link Persona.linkable_property_to_links} method is called, which should
   * be called by the `linkable_property_to_links` implementation for each
   * linkable-property-to-individual mapping it wants to add or remove in the
   * aggregator.
   *
   * @param link the mapping string to be added to the
   * {@link IndividualAggregator}
   * @since 0.1.13
   */
  public delegate void LinkablePropertyCallback (string link);

  /* FIXME: This code should move to the IMable interface as a concrete
   * method of the interface. However, that depends on bgo#624842 */
  /**
   * Produce one or more mapping strings for the given property's value.
   *
   * This is a virtual method, to be overridden by subclasses of {@link Persona}
   * who have linkable properties. Each of their linkable properties should be
   * handled by their implementation of this function, examining the current
   * value of the property and calling `callback` with one or more mapping
   * strings for the property's value. Each of these mapping strings will be
   * added to the {@link IndividualAggregator}'s link map, related to the
   * {@link Individual} instance which contains this {@link Persona}.
   *
   * @param prop_name the name of the linkable property to use, which must be
   * listed in {@link Persona.linkable_properties}
   * @param callback a callback to execute for each of the mapping strings
   * generated by this property
   * @see Persona.linkable_properties
   * @since 0.1.13
   */
  public virtual void linkable_property_to_links (string prop_name,
      LinkablePropertyCallback callback)
    {
      /* Backend-specific Persona subclasses should override this if they have
       * any linkable properties */
      assert_not_reached ();
    }

  private static string escape_uid_component (string component)
    {
      /* Escape colons with backslashes */
      string escaped = component.replace ("\\", "\\\\");
      return escaped.replace (":", "\\:");
    }

  private static string unescape_uid_component (string component)
    {
      /* Unescape colons and backslashes */
      string unescaped = component.replace ("\\:", ":");
      return unescaped.replace ("\\", "\\\\");
    }

  /**
   * Build a UID from the given components.
   *
   * Each component is escaped before the UID is built.
   *
   * @param backend_name the {@link Backend.name}
   * @param persona_store_id the {@link PersonaStore.id}
   * @param persona_id the Persona identifier (backend-specific)
   * @return a valid UID
   * @see Persona.split_uid
   * @since 0.1.13
   */
  public static string build_uid (string backend_name,
      string persona_store_id, string persona_id)
    {
      return "%s:%s:%s".printf (Persona.escape_uid_component (backend_name),
                                Persona.escape_uid_component (persona_store_id),
                                Persona.escape_uid_component (persona_id));
    }

  /**
   * Split a UID into its component parts.
   *
   * Each component is unescaped before being returned. The UID //must// be
   * correctly formed.
   *
   * @param uid a valid UID
   * @param backend_name the {@link Backend.name}
   * @param persona_store_id the {@link PersonaStore.id}
   * @param persona_id the Persona identifier (backend-specific)
   * @see Persona.build_uid
   * @since 0.1.13
   */
  public static void split_uid (string uid, out string backend_name,
      out string persona_store_id, out string persona_id)
    {
      assert (uid.validate ());

      size_t backend_name_length = 0, persona_store_id_length = 0;
      bool escaped = false;
      for (unowned string i = uid; i.get_char () != '\0'; i = i.next_char ())
        {
          if (i.get_char () == '\\')
            escaped = !escaped;
          else if (escaped == false && i.get_char () == ':')
            {
              if (backend_name_length == 0)
                backend_name_length = ((char*) i) - ((char*) uid);
              else
                persona_store_id_length =
                  (((char*) i) - ((char*) uid)) - backend_name_length - 1;
            }
        }

      assert (backend_name_length != 0 && persona_store_id_length != 0);

      backend_name = Persona.unescape_uid_component (
          uid.ndup (backend_name_length));
      persona_store_id = Persona.unescape_uid_component (
          ((string) ((char*) uid + backend_name_length + 1)).ndup (
              persona_store_id_length));
      persona_id = Persona.unescape_uid_component (
          ((string) ((char*) uid + backend_name_length +
              persona_store_id_length + 2)));
    }
}
