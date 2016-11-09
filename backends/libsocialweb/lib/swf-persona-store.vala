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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 *       Marco Barisione <marco.barisione@collabora.co.uk>
 */

using GLib;
using Gee;
using Folks;
using SocialWebClient;

extern const string BACKEND_NAME;

/**
 * A persona store which is associated with a single libsocialweb service.
 *
 * It will create {@link Persona}s for each of the contacts known to that
 * service.
 */
public class Swf.PersonaStore : Folks.PersonaStore
{
  private HashMap<string, Persona> _personas;
  private Map<string, Persona> _personas_ro;
  private bool _is_prepared = false;
  private bool _prepare_pending = false;
  private bool _is_quiescent = false;
  private ClientContactView _contact_view;

  /* No writeable properties
   *
   * FIXME: we can't mark this as const because Vala gets confused
   *        and generates the wrong C output (char *arr[0] = {}
   *        instead of char **arr = NULL)
   */
  private static string[] _always_writeable_properties = {};

  /**
   * The type of persona store this is.
   *
   * See {@link Folks.PersonaStore.type_id}.
   */
  public override string type_id { get { return BACKEND_NAME; } }

  /**
   * Whether this PersonaStore can add {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_add_personas}.
   *
   * @since 0.5.0
   */
  public override MaybeBool can_add_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can set the alias of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_alias_personas}.
   *
   * @since 0.5.0
   */
  public override MaybeBool can_alias_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can set the groups of {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_group_personas}.
   *
   * @since 0.5.0
   */
  public override MaybeBool can_group_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore can remove {@link Folks.Persona}s.
   *
   * See {@link Folks.PersonaStore.can_remove_personas}.
   *
   * @since 0.5.0
   */
  public override MaybeBool can_remove_personas
    {
      get { return MaybeBool.FALSE; }
    }

  /**
   * Whether this PersonaStore has been prepared.
   *
   * See {@link Folks.PersonaStore.is_prepared}.
   *
   * @since 0.5.0
   */
  public override bool is_prepared
    {
      get { return this._is_prepared; }
    }

  /**
   * {@inheritDoc}
   *
   * @since 0.6.2
   */
  public override string[] always_writeable_properties
    {
      get { return Swf.PersonaStore._always_writeable_properties; }
    }

  /*
   * Whether this PersonaStore has reached a quiescent state.
   *
   * See {@link Folks.PersonaStore.is_quiescent}.
   *
   * @since 0.6.2
   */
  public override bool is_quiescent
    {
      get { return this._is_quiescent; }
    }

  /**
   * The {@link Persona}s exposed by this PersonaStore.
   *
   * See {@link Folks.PersonaStore.personas}.
   */
  public override Map<string, Folks.Persona> personas
    {
      get { return this._personas_ro; }
    }

  /**
   * The libsocialweb {@link SocialWebClient.ClientService} associated with the
   * persona store.
   *
   * @since 0.6.6
   */
  public ClientService service { get; construct; }

  /**
   * Create a new PersonaStore.
   *
   * Create a new persona store to store the {@link Persona}s for the contacts
   * provided by the ``service``.
   *
   * @param service the libsocialweb service being represented by the new
   * persona store
   */
  public PersonaStore (ClientService service)
    {
      Object (display_name: service.get_display_name (),
              id: service.get_name (),
              service: service);
    }

  construct
    {
      this.trust_level = PersonaStoreTrust.PARTIAL;
      this._personas = new HashMap<string, Persona> ();
      this._personas_ro = this._personas.read_only_view;
    }

  ~PersonaStore ()
    {
      if (this._contact_view != null)
        {
          this._contact_view.contacts_added.disconnect (this.contacts_added_cb);
          this._contact_view.contacts_changed.disconnect (
              this.contacts_changed_cb);
          this._contact_view.contacts_removed.disconnect (
              this.contacts_removed_cb);
        }
    }

  /**
   * Add a new {@link Persona} to the PersonaStore.
   *
   * See {@link Folks.PersonaStore.add_persona_from_details}.
   *
   * @throws Folks.PersonaStoreError.READ_ONLY every time — libsocialweb is
   * read-only
   */
  public override async Folks.Persona? add_persona_from_details (
      HashTable<string, Value?> details) throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be added to this store.");
    }

  /**
   * Remove a {@link Persona} from the PersonaStore.
   *
   * See {@link Folks.PersonaStore.remove_persona}.
   *
   * @throws Folks.PersonaStoreError.READ_ONLY every time — libsocialweb is
   * read-only
   */
  public override async void remove_persona (Folks.Persona persona)
      throws Folks.PersonaStoreError
    {
      throw new PersonaStoreError.READ_ONLY (
          "Personas cannot be removed from this store.");
    }

  /* This is safe to call multiple times concurrently (assuming libsocialweb
   * itself is safe). */
  private async string[]? _get_static_capabilities () throws GLib.Error
    {
      /* Take a reference to the PersonaStore while waiting for the async call
       * to return. See: bgo#665039. */
      this.ref ();

      var received_callback = false;
      var has_yielded = false;

      string[]? caps = null;
      Error? error = null;

      this.service.get_static_capabilities ((service, _caps, _error) =>
        {
          received_callback = true;

          caps = _caps;
          error = _error;

          if (has_yielded == true)
            {
              this._get_static_capabilities.callback ();
            }
        });

      /* Yield for the get_static_capabilities() callback to be invoked, if it
       * hasn't already been invoked (which could happen if
       * get_static_capabilities() called it immediately). */
      if (received_callback == false)
        {
          has_yielded = true;
          yield;
        }

      this.unref ();

      /* Handle the error, if it was set. */
      if (error != null)
        {
          throw error;
        }

      return caps;
    }

  /* This is safe to call multiple times concurrently (assuming libsocialweb
   * itself is safe). */
  private async ClientContactView? _contacts_query_open_view (string query,
      HashTable<weak string, weak string> parameters)
    {
      /* Take a reference to the PersonaStore while waiting for the async call
       * to return. See: bgo#665039. */
      this.ref ();

      var received_callback = false;
      var has_yielded = false;

      ClientContactView? contact_view = null;

      this.service.contacts_query_open_view (query, parameters,
          (service, _contact_view) =>
        {
          received_callback = true;

          contact_view = _contact_view;

          if (has_yielded == true)
            {
              this._contacts_query_open_view.callback ();
            }
        });

      /* Yield for the contacts_query_open_view() callback to be invoked, if it
       * hasn't already been invoked (which could happen if
       * contacts_query_open_view() called it immediately). */
      if (received_callback == false)
        {
          has_yielded = true;
          yield;
        }

      this.unref ();

      return contact_view;
    }

  /**
   * Prepare the PersonaStore for use.
   *
   * See {@link Folks.PersonaStore.prepare}.
   *
   * @throws Folks.PersonaStoreError.INVALID_ARGUMENT if the libsocialweb
   * service capabilities couldn’t be retrieved, or if the ‘contacts’ capability
   * wasn’t found, or if a view couldn’t be opened
   */
  public override async void prepare () throws GLib.Error
    {
      Internal.profiling_start ("preparing Swf.PersonaStore (ID: %s)", this.id);

      if (this._is_prepared || this._prepare_pending)
        {
          return;
        }
      
      try
        {
          this._prepare_pending = true;
          
          /* Get the service's capabilities. */
          string[]? caps = null;
          
          try
            {
              caps = yield this._get_static_capabilities ();

              Internal.profiling_point ("got capabilities in " +
                  "Swf.PersonaStore (ID: %s)", this.id);

              if (caps == null)
                {
                  throw new PersonaStoreError.INVALID_ARGUMENT (
                      /* Translators: the parameter is an error message. */
                      _("Couldn’t prepare libsocialweb service: %s"),
                      _("No capabilities were found."));
                }
            }
          catch (GLib.Error e1)
            {
              /* Remove the persona store on error */
              this.removed ();

              throw e1;
            }

          /* Check for the contacts query interface. */
          bool has_contacts = ClientService.has_cap (caps,
              "has-contacts-query-iface");
          if (!has_contacts)
            {
              /* Remove the persona store on error */
              this.removed ();

              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the parameter is an error message. */
                  _("Couldn’t prepare libsocialweb service: %s"),
                  _("No contacts capability was found."));
            }

          /* Open a contacts query view. */
          var contact_view = yield this._contacts_query_open_view ("people",
              new HashTable<weak string, weak string> (str_hash,
                  str_equal));

          Internal.profiling_point ("opened view in Swf.PersonaStore " +
              "(ID: %s)", this.id);

          /* Propagate errors from the contacts_query_open_view()
           * callback. */
          if (contact_view == null)
            {
              /* Remove the persona store on error */
              this.removed ();

              throw new PersonaStoreError.INVALID_ARGUMENT (
                  /* Translators: the parameter is an error message. */
                  _("Couldn’t prepare libsocialweb service: %s"),
                  _("Error opening contacts view."));
            }

          contact_view.contacts_added.connect (this.contacts_added_cb);
          contact_view.contacts_changed.connect (this.contacts_changed_cb);
          contact_view.contacts_removed.connect (this.contacts_removed_cb);

          this._contact_view = contact_view;
          this._is_prepared = true;
          this.notify_property ("is-prepared");

          /* FIXME: for lsw Stores with 0 contacts or badly configured (or
           * not authenticated, etc) we are condemned to never reach
           * quiescence if we wait for contacts to be added. A possible way
           * around this would be, if libsocialweb provided such properties,
           * to query the social client to see if it's available
           * (authenticated and ready) and the number of contacts that we
           * would (eventually) get. That is the only way we could ever
           * reach quiescence without waiting for eternity.
           *
           * See: https://bugzilla.gnome.org/show_bug.cgi?id=658445
           */
          this._is_quiescent = true;
          this.notify_property ("is-quiescent");

          this._contact_view.start ();
        }
      finally
        {
          this._prepare_pending = false;
        }

      Internal.profiling_end ("preparing Swf.PersonaStore (ID: %s)", this.id);
    }

  private void contacts_added_cb (GLib.List<unowned Contact> contacts)
    {
      var added_personas = new HashSet<Persona> ();
      foreach (var contact in contacts)
        {
          var persona = new Persona(this, contact);
          _personas.set (persona.iid, persona);
          added_personas.add (persona);
        }

      if (added_personas.size > 0)
        {
          this._emit_personas_changed (added_personas, null);
        }

      /* If this is the first contacts-added notification, assume we've reached
       * a quiescent state. We can't do any better, since libsocialweb doesn't
       * expose an is-quiescent property (or similar). */
      if (this._is_quiescent == false)
        {
          this._is_quiescent = true;
          this.notify_property ("is-quiescent");
        }
    }

  private void contacts_changed_cb (GLib.List<unowned Contact> contacts)
    {
      foreach (var contact in contacts)
        {
          if (this.service.get_name () != contact.service)
            {
              continue;
            }
          var iid = Swf.Persona._build_iid(contact.service, Persona.get_contact_id (contact));
          var persona = _personas.get (iid);
          if (persona != null)
            persona.update (contact);
        }
    }

  private void contacts_removed_cb (GLib.List<unowned Contact> contacts)
    {
      var removed_personas = new HashSet<Persona> ();
      foreach (var contact in contacts)
        {
          if (this.service.get_name () != contact.service)
            {
              continue;
            }
          var iid = Swf.Persona._build_iid(contact.service, Persona.get_contact_id (contact));
          var persona = _personas.get (iid);
          if (persona != null)
            {
              removed_personas.add (persona);
              _personas.unset (persona.iid);
            }
        }

      if (removed_personas.size > 0)
        {
          this._emit_personas_changed (null, removed_personas);
        }
    }
}
