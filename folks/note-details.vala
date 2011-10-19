/*
 * Copyright (C) 2011 Collabora Ltd.
 * Copyright (C) 2011 Philip Withnall
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
 *       Raul Gutierrez Segales <raul.gutierrez.segales@collabora.co.uk>
 *       Philip Withnall <philip@tecnocode.co.uk>
 */

using Gee;
using GLib;

/**
 * Object representing a note that can have some parameters associated with it.
 *
 * See {@link Folks.AbstractFieldDetails} for details on common parameter names
 * and values.
 *
 * @since 0.6.0
 */
public class Folks.NoteFieldDetails : AbstractFieldDetails<string>
{
  /**
   * The UID of the note (if any).
   */
  public string uid { get; set; }

  /**
   * Create a new NoteFieldDetails.
   *
   * @param value the value of the field
   * @param parameters initial parameters. See
   * {@link AbstractFieldDetails.parameters}. A `null` value is equivalent to a
   * empty map of parameters.
   *
   * @return a new NoteFieldDetails
   *
   * @since 0.6.0
   */
  public NoteFieldDetails (string value,
      MultiMap<string, string>? parameters = null,
      string? uid = null)
    {
      this.value = value;
      if (parameters != null)
        this.parameters = parameters;
      this.uid = uid;
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override bool equal (AbstractFieldDetails<string> that)
    {
      if (!base.equal<string> (that))
        return false;

      var that_nfd = that as NoteFieldDetails;
      if (that_nfd == null)
        return false;

      return (this.uid == that_nfd.uid && this.value == that_nfd.value);
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.0
   */
  public override uint hash ()
    {
      uint retval = 0;

      if (this.value != null)
        retval += this.value.hash ();

      if (this.uid != null)
        retval += this.uid.hash ();

      return retval;
    }
}

/**
 * This interface represents the list of notes associated
 * to a {@link Persona} and {@link Individual}.
 *
 * @since 0.4.0
 */
public interface Folks.NoteDetails : Object
{
  /**
   * The notes about the contact.
   *
   * @since 0.5.1
   */
  public abstract Set<NoteFieldDetails> notes { get; set; }

  /**
   * Change the contact's notes.
   *
   * It's preferred to call this rather than setting {@link NoteDetails.notes}
   * directly, as this method gives error notification and will only return once
   * the notes have been written to the relevant backing store (or the
   * operation's failed).
   *
   * @param notes the set of notes
   * @throws PropertyError if setting the notes failed
   * @since 0.6.2
   */
  public virtual async void change_notes (Set<NoteFieldDetails> notes)
      throws PropertyError
    {
      /* Default implementation. */
      throw new PropertyError.NOT_WRITEABLE (
          _("Notes are not writeable on this contact."));
    }
}
