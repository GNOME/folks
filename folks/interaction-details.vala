/*
 * Copyright (C) 2012 Collabora Ltd.
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
 *       Seif Lotfy <seif.lotfy@collabora.co.uk>
 */

using GLib;

/**
 * Object representing interaction details for an Individual or Persona.
 * Interaction details are the number of call or IM interactions with the a
 * a {@link Persona} or an {@link Individual} as well as the the datetime of
 * the last call and im interaction.
 *
 * @since UNRELEASED
 */
public interface Folks.InteractionDetails : Object
{
  /**
   * The IM interaction associated with a Persona
   *
   * @since UNRELEASED
   */
  public abstract uint im_interaction_count
    {
      get;
    }

  /**
   * The latest IM interaction timestamp associated with a Persona
   *
   * @since UNRELEASED
   */
  public abstract DateTime? last_im_interaction_datetime
    {
      get;
    }

  /**
   * The call interaction associated with a Persona
   *
   * @since UNRELEASED
   */
  public abstract uint call_interaction_count
    {
      get;
    }

  /**
   * The latest call interaction timestamp associated with a Persona
   *
   * @since UNRELEASED
   */
  public abstract DateTime? last_call_interaction_datetime
    {
      get;
    }
}
