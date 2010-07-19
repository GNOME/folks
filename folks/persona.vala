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
using Folks;

/**
 * Represents a "shard" of a person from a single source (a single
 * {@link Backend}), such as an XMPP contact from Telepathy or a vCard contact
 * from evolution-data-server. All the personas belonging to one physical person
 * are aggregated to form a single {@link Individual} representing that person.
 */
public abstract class Folks.Persona : Object
{
  /**
   * The internal ID used to represent the Persona within its {@link Backend}.
   *
   * This should not be used by client code.
   */
  public string iid { get; construct; }

  /**
   * The universal ID used to represent the Persona outside its {@link Backend}.
   *
   * For example: `foo@@xmpp.example.org`.
   *
   * This is the canonical way to refer to any Persona. It is guaranteed to be
   * unique within the Persona's {@link PersonaStore}.
   */
  public string uid { get; construct; }

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
   * @see Persona.linkable_properties
   */
  public virtual void linkable_property_to_links (string prop_name,
      LinkablePropertyCallback callback)
    {
      /* Backend-specific Persona subclasses should override this if they have
       * any linkable properties */
      assert_not_reached ();
    }
}
