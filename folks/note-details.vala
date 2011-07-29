/*
 * Copyright (C) 2011 Collabora Ltd.
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
 */

using Gee;
using GLib;

/**
 * Representation of a Note that might be attached to a {@link Persona}.
 *
 * @since 0.4.0
 */
public class Folks.Note : Object
{
  /**
   * The note's content.
   */
  public string content { get; set; }

  /**
   * The UID of the note (if any).
   */
  public string uid { get; set; }

  /**
   * Default constructor.
   *
   * @param content the note's content
   * @param uid the note's UID (may be null)
   * @return a new Note
   *
   * @since 0.4.0
   */
  public Note (string content, string? uid = null)
    {
      if (uid == null)
        {
          uid = "";
        }

      Object (uid:                  uid,
              content:              content);
    }

  /**
   * Compare if 2 notes are equal. This compares both their {@link Note.content}
   * and {@link Note.uid} (if set).
   *
   * @param a a note to compare
   * @param b another note to compare
   * @return `true` if the roles are equal, `false` otherwise
   */
  public static bool equal (Note a, Note b)
    {
      return (a.uid == b.uid && a.content == b.content);
    }

  /**
   * Hash function for the class. Suitable for use as a hash table key.
   *
   * @param r a note to hash
   * @return hash value for the note instance
   */
  public static uint hash (Note r)
    {
      return r.uid.hash () + r.content.hash ();
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
  public abstract Set<Note> notes { get; set; }
}
