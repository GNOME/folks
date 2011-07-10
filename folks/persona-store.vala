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
using Gee;

/**
 * Trust level for a {@link PersonaStore}'s {@link Persona}s for linking
 * purposes.
 *
 * @since 0.1.13
 */
public enum Folks.PersonaStoreTrust
{
  /**
   * The {@link Persona}s aren't trusted at all, and cannot be linked.
   *
   * This should be used for {@link PersonaStore}s where even the
   * {@link Persona} UID could be maliciously edited to corrupt {@link Persona}
   * links, or where the UID changes regularly.
   *
   * @since 0.1.13
   */
  NONE,

  /**
   * Only the {@link Persona.uid} property is trusted for linking.
   *
   * In practice, this means that {@link Persona}s from this
   * {@link PersonaStore} will not contribute towards the linking process, but
   * can be linked together by their UIDs using data from {@link Persona}s from
   * a fully-trusted {@link PersonaStore}.
   *
   * @since 0.1.13
   */
  PARTIAL,

  /**
   * Every property in {@link Persona.linkable_properties} is trusted.
   *
   * This should only be used for user-controlled {@link PersonaStore}s, as if a
   * remote store is compromised, malicious changes could be made to its data
   * which corrupt the user's {@link Persona} links.
   *
   * @since 0.1.13
   */
  FULL
}
/**
 * Errors from {@link PersonaStore}s.
 */
public errordomain Folks.PersonaStoreError
{
  /**
   * An argument to the method was invalid.
   */
  INVALID_ARGUMENT,

  /**
   * Creation of a {@link Persona} failed.
   */
  CREATE_FAILED,

  /**
   * Such an operation may not be performed on a {@link Persona} with
   * {@link Persona.is_user} set to `true`.
   *
   * @since 0.3.0
   */
  UNSUPPORTED_ON_USER,

  /**
   * The {@link PersonaStore} was offline (ie, this is a temporary failure).
   *
   * @since 0.3.0
   */
  STORE_OFFLINE,

  /**
   * The {@link PersonaStore} doesn't support write operations.
   *
   * @since 0.3.4
   */
  READ_ONLY,

  /**
   * The operation was denied due to not having sufficient permissions.
   *
   * @since UNRELEASED
   */
  PERMISSION_DENIED,

  /**
   * Removal of a {@link Persona} failed. This is a generic error which is used
   * if no other error code (such as, e.g.,
   * {@link PersonaStoreError.PERMISSION_DENIED}) is applicable.
   *
   * @since UNRELEASED
   */
  REMOVE_FAILED,
}

/**
 * Definition of the available fields to be looked up with
 * {@link PersonaStore.detail_key}.
 *
 * @since 0.5.0
 */
/* NOTE: Must be kept in sync with
 * {@link Folks.PersonaStore._PERSONA_DETAIL}. */
public enum Folks.PersonaDetail
{
  ALIAS,
  AVATAR,
  BIRTHDAY,
  EMAIL_ADDRESSES,
  FULL_NAME,
  GENDER,
  IM_ADDRESSES,
  IS_FAVOURITE,
  LOCAL_IDS,
  NICKNAME,
  NOTES,
  PHONE_NUMBERS,
  POSTAL_ADDRESSES,
  ROLES,
  STRUCTURED_NAME,
  URLS,
  WEB_SERVICE_ADDRESSES
}

/**
 * A store for {@link Persona}s.
 *
 * After creating a PersonaStore instance, you must connect to the
 * {@link PersonaStore.personas_changed} signal, //then// call
 * {@link PersonaStore.prepare}, otherwise a race condition may occur between
 * emission of {@link PersonaStore.personas_changed} and your code connecting to
 * it.
 */
public abstract class Folks.PersonaStore : Object
{
  /**
   * The following list of properties are the basic keys
   * that each PersonaStore with write capabilities should
   * support for {@link Persona.add_persona_from_details}.
   *
   * Note that these aren't the only valid keys; backends are
   * allowed to support keys beyond the ones defined here
   * which might be specific to the backend in question.
   *
   * NOTE: MUST be kept in sync with {@link Folks.PersonaDetail}.
   *
   * @since 0.5.0
   */
  private static const string _PERSONA_DETAIL[] = {
    "alias",
    "avatar",
    "birthday",
    "email-addresses",
    "full-name",
    "gender",
    "im-addresses",
    "is-favourite",
    "local-ids",
    "nickname",
    "notes",
    "phone-numbers",
    "postal-addresses",
    "roles",
    "structured-name",
    "urls",
    "web-service-addresses"
  };

  /**
   * Returns the key corresponding to @detail, for use in
   * the details param of {@link Persona.add_persona_from_details}.
   *
   * @param detail the {@link PersonaDetail} to lookup
   *
   * @since 0.5.0
   */
  public static unowned string detail_key (Folks.PersonaDetail detail)
    {
      return PersonaStore._PERSONA_DETAIL[detail];
    }

 /**
   * Emitted when one or more {@link Persona}s are added to or removed from
   * the store.
   *
   * This will not be emitted until after {@link PersonaStore.prepare} has been
   * called.
   *
   * @param added a set of {@link Persona}s which have been removed
   * @param removed a set of {@link Persona}s which have been removed
   * @param message a string message from the backend, if any
   * @param actor the {@link Persona} who made the change, if known
   * @param reason the reason for the change
   *
   * @since 0.5.1
   */
  public signal void personas_changed (Set<Persona> added,
      Set<Persona> removed,
      string? message,
      Persona? actor,
      GroupDetails.ChangeReason reason);

  /* Emit the personas-changed signal, turning null parameters into empty sets
   * and only passing a read-only view to the signal handlers. */
  protected void _emit_personas_changed (Set<Persona>? added,
      Set<Persona>? removed,
      string? message = null,
      Persona? actor = null,
      GroupDetails.ChangeReason reason = GroupDetails.ChangeReason.NONE)
    {
      var _added = added;
      var _removed = removed;

      if ((added == null || added.size == 0) &&
          (removed == null || removed.size == 0))
        {
          /* Don't bother signalling if nothing's changed */
          return;
        }
      else if (added == null)
        {
          _added = new HashSet<Persona> ();
        }
      else if (removed == null)
        {
          _removed = new HashSet<Persona> ();
        }

      this.personas_changed (_added.read_only_view, _removed.read_only_view,
          message, actor, reason);
    }

  /**
   * Emitted when the backing store for this PersonaStore has been removed.
   *
   * At this point, the PersonaStore and all its {@link Persona}s are invalid,
   * so any client referencing it should unreference it.
   *
   * This will not be emitted until after {@link PersonaStore.prepare} has been
   * called.
   */
  public abstract signal void removed ();

  /**
   * The type of PersonaStore this is.
   *
   * This is the same for all PersonaStores provided by a given {@link Backend}.
   *
   * This is guaranteed to always be available; even before
   * {@link PersonaStore.prepare} is called.
   */
  public abstract string type_id { get; }

  /**
   * The human-readable, service-specific name used to represent the
   * PersonaStore to the user.
   *
   * For example: `foo@@xmpp.example.org`.
   *
   * This should be used whenever the user needs to be presented with a
   * familiar, service-specific name. For instance, in a prompt for the user to
   * select a specific IM account from which to initiate a chat.
   *
   * This is not guaranteed to be unique even within this PersonaStore's
   * {@link Backend}.
   *
   * @since 0.1.13
   */
  public string display_name { get; construct; }

  /**
   * The instance identifier for this PersonaStore.
   *
   * Since each {@link Backend} can provide multiple different PersonaStores
   * for different accounts or servers (for example), they each need an ID
   * which is unique within the backend.
   */
  public string id { get; construct; }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * @since 0.5.1
   */
  public abstract Map<string, Persona> personas { get; }

  /**
   * Whether this {@link PersonaStore} can add {@link Persona}s.
   *
   * @since 0.3.1
   */
  public abstract MaybeBool can_add_personas { get; default = MaybeBool.UNSET; }

  /**
   * Whether this {@link PersonaStore} can set the alias of {@link Persona}s.
   *
   * @since 0.3.1
   */
  public abstract MaybeBool can_alias_personas
    {
      get;
      default = MaybeBool.UNSET;
    }

  /**
   * Whether this {@link PersonaStore} can set the groups of {@link Persona}s.
   *
   * @since 0.3.1
   */
  public abstract MaybeBool can_group_personas
    {
      get;
      default = MaybeBool.UNSET;
    }

  /**
   * Whether this {@link PersonaStore} can remove {@link Persona}s.
   *
   * @since 0.3.1
   */
  public abstract MaybeBool can_remove_personas
    {
      get;
      default = MaybeBool.UNSET;
    }

  /**
   * Whether {@link PersonaStore.prepare} has successfully completed for this
   * store.
   *
   * @since 0.3.0
   */
  public abstract bool is_prepared { get; default = false; }

   /**
   * Whether the PersonaStore is writeable.
   *
   * Only if a PersonaStore is writeable will changes to its {@link Persona}s'
   * properties be written out to the relevant backing store.
   *
   * PersonaStores must not set this property themselves; it will be set as
   * appropriate by the {@link IndividualAggregator}.
   *
   * @since 0.1.13
   */
  public bool is_writeable { get; set; default = false; }

  /**
   * The trust level of the PersonaStore for linking.
   *
   * Each {@link PersonaStore} is assigned a trust level by the
   * IndividualAggregator, designating whether to trust the properties of its
   * {@link Persona}s for linking to produce {@link Individual}s.
   *
   * @see PersonaStoreTrust
   * @since 0.1.13
   */
  public PersonaStoreTrust trust_level
    {
      get; set; default = PersonaStoreTrust.NONE;
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * This connects the PersonaStore to whichever backend-specific services it
   * requires to be able to provide {@link Persona}s. This should be called
   * //after// connecting to the {@link PersonaStore.personas_changed} signal,
   * or a race condition could occur, with the signal being emitted before your
   * code has connected to it, and {@link Persona}s getting "lost" as a result.
   *
   * This is normally handled transparently by the {@link IndividualAggregator}.
   *
   * If this function throws an error, the PersonaStore will not be functional.
   *
   * This function is guaranteed to be idempotent (since version 0.3.0).
   *
   * @since 0.1.11
   */
  public abstract async void prepare () throws GLib.Error;

  /**
   * Flush any pending changes to the PersonaStore's backing store.
   *
   * PersonaStores may (transparently) implement caching or I/O queueing which
   * means that changes to their {@link Persona}s may not be immediately written
   * to the PersonaStore's backing store. Calling this function will force all
   * pending changes to be flushed to the backing store.
   *
   * This must not be called before {@link PersonaStore.prepare}.
   *
   * @since 0.1.17
   */
  public virtual async void flush ()
    {
      /* Default implementation doesn't have to do anything */
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * The {@link Persona} will be created by the PersonaStore backend from the
   * key-value pairs given in `details`.
   *
   * All additions through this function will later be emitted through the
   * personas-changed signal to be notified of the new {@link Persona}. The
   * return value is purely for convenience, since it can be complicated to
   * correlate the provided details with the final Persona.
   *
   * If the store is offline, this function will throw
   * {@link PersonaStoreError.STORE_OFFLINE}. It's the responsibility of the
   * caller to cache details and re-try this function if it wishes to make
   * offline adds work.
   *
   * If the details are not recognised or are invalid,
   * {@link PersonaStoreError.INVALID_ARGUMENT} will be thrown. A default set
   * of possible details are defined by {@link Folks.PersonaDetail} but backends
   * can either support a subset or superset of the suggested defaults.
   *
   * If a {@link Persona} with the given details already exists in the store, no
   * error will be thrown and this function will return `null`.
   *
   * @param details a key-value map of details to use in creating the new
   * {@link Persona}
   *
   * @return the new {@link Persona} or `null` if the corresponding Persona
   * already existed. If non-`null`, the new {@link Persona} will also be
   * amongst the {@link Persona}(s) in a future emission of
   * {@link PersonaStore.personas_changed}.
   */
  public abstract async Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError;

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * It isn't guaranteed that the Persona will actually be removed by the time
   * this asynchronous function finishes. The successful removal of the Persona
   * will be signalled through emission of
   * {@link PersonaStore.personas_changed}.
   *
   * @param persona the {@link Persona} to remove
   * @since 0.1.11
   */
  public abstract async void remove_persona (Persona persona)
      throws Folks.PersonaStoreError;
}
