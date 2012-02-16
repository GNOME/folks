/*
 * conn.c - an tp_test connection
 *
 * Copyright © 2007-2011 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright © 2007-2010 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */


#include "config.h"

#include "conn.h"

#include <string.h>

#include <dbus/dbus-glib.h>

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/handle-repo-dynamic.h>
#include <telepathy-glib/handle-repo-static.h>

#include "contact-list-manager.h"

static void init_aliasing (gpointer, gpointer);
static void init_contact_info (gpointer, gpointer);

G_DEFINE_TYPE_WITH_CODE (TpTestContactListConnection,
    tp_test_contact_list_connection,
    TP_TYPE_BASE_CONNECTION,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_ALIASING,
      init_aliasing);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_CONTACTS,
      tp_contacts_mixin_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_PRESENCE,
      tp_presence_mixin_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_SIMPLE_PRESENCE,
      tp_presence_mixin_simple_presence_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_CONTACT_INFO,
      init_contact_info))

enum
{
  PROP_ACCOUNT = 1,
  PROP_SIMULATION_DELAY,
  PROP_MANAGER,
  PROP_PUBLISH_FLAGS,
  PROP_SUBSCRIBE_FLAGS,
  N_PROPS
};

struct _TpTestContactListConnectionPrivate
{
  gchar *account;
  guint simulation_delay;
  TpTestContactListManager *list_manager;
  gboolean away;
  TpChannelGroupFlags publish_flags;
  TpChannelGroupFlags subscribe_flags;
};

static TpChannelGroupFlags default_group_flags =
    TP_CHANNEL_GROUP_FLAG_CAN_ADD |
    TP_CHANNEL_GROUP_FLAG_CAN_REMOVE |
    TP_CHANNEL_GROUP_FLAG_MEMBERS_CHANGED_DETAILED;

static void
tp_test_contact_list_connection_init (TpTestContactListConnection *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self,
      TP_TEST_TYPE_CONTACT_LIST_CONNECTION,
      TpTestContactListConnectionPrivate);
}

static void
get_property (GObject *object,
              guint property_id,
              GValue *value,
              GParamSpec *spec)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (object);

  switch (property_id)
    {
    case PROP_ACCOUNT:
      g_value_set_string (value, self->priv->account);
      break;

    case PROP_MANAGER:
      g_value_set_object (value, self->priv->list_manager);
      break;

    case PROP_PUBLISH_FLAGS:
      g_value_set_uint (value, self->priv->publish_flags);
      break;

    case PROP_SUBSCRIBE_FLAGS:
      g_value_set_uint (value, self->priv->subscribe_flags);
      break;

    case PROP_SIMULATION_DELAY:
      g_value_set_uint (value, self->priv->simulation_delay);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
    }
}

static void
set_property (GObject *object,
              guint property_id,
              const GValue *value,
              GParamSpec *spec)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (object);

  switch (property_id)
    {
    case PROP_ACCOUNT:
      g_free (self->priv->account);
      self->priv->account = g_value_dup_string (value);
      break;

    case PROP_PUBLISH_FLAGS:
      self->priv->publish_flags = g_value_get_uint (value);
      break;

    case PROP_SUBSCRIBE_FLAGS:
      self->priv->subscribe_flags = g_value_get_uint (value);
      break;

    case PROP_SIMULATION_DELAY:
      self->priv->simulation_delay = g_value_get_uint (value);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
    }
}

static void
finalize (GObject *object)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (object);

  tp_contacts_mixin_finalize (object);
  g_free (self->priv->account);

  G_OBJECT_CLASS (tp_test_contact_list_connection_parent_class)->finalize (
      object);
}

/**
 * tp_test_contact_list_connection_get_manager:
 * @self: the connection
 *
 * Returns: (transfer none): the contact list manager or %NULL.
 */
TpTestContactListManager *
tp_test_contact_list_connection_get_manager (TpTestContactListConnection *self)
{
  g_return_val_if_fail (TP_TEST_IS_CONTACT_LIST_CONNECTION (self), NULL);

  return self->priv->list_manager;
}

static gchar *
get_unique_connection_name (TpBaseConnection *conn)
{
  TpTestContactListConnection *self = TP_TEST_CONTACT_LIST_CONNECTION (conn);

  return g_strdup_printf ("%s@%p", self->priv->account, self);
}

gchar *
tp_test_contact_list_normalize_contact (TpHandleRepoIface *repo,
                                        const gchar *id,
                                        gpointer context,
                                        GError **error)
{
  if (id == NULL || id[0] == '\0')
    {
      g_set_error (error, TP_ERRORS, TP_ERROR_INVALID_HANDLE,
          "Contact ID must not be empty");
      return NULL;
    }

  return g_utf8_normalize (id, -1, G_NORMALIZE_ALL_COMPOSE);
}

static gchar *
tp_test_contact_list_normalize_group (TpHandleRepoIface *repo,
                                      const gchar *id,
                                      gpointer context,
                                      GError **error)
{
  if (id == NULL || id[0] == '\0')
    {
      g_set_error (error, TP_ERRORS, TP_ERROR_INVALID_HANDLE,
          "Contact group name cannot be empty");
      return NULL;
    }

  return g_utf8_normalize (id, -1, G_NORMALIZE_ALL_COMPOSE);
}

static void
create_handle_repos (TpBaseConnection *conn,
                     TpHandleRepoIface *repos[NUM_TP_HANDLE_TYPES])
{
  repos[TP_HANDLE_TYPE_CONTACT] = tp_dynamic_handle_repo_new
      (TP_HANDLE_TYPE_CONTACT, tp_test_contact_list_normalize_contact, NULL);

  repos[TP_HANDLE_TYPE_LIST] = tp_static_handle_repo_new
      (TP_HANDLE_TYPE_LIST, tp_test_contact_lists ());

  repos[TP_HANDLE_TYPE_GROUP] = tp_dynamic_handle_repo_new
      (TP_HANDLE_TYPE_GROUP, tp_test_contact_list_normalize_group, NULL);
}

static void
alias_updated_cb (TpTestContactListManager *manager,
                  TpHandle contact,
                  TpTestContactListConnection *self)
{
  GPtrArray *aliases;
  GValueArray *pair;

  pair = g_value_array_new (2);
  g_value_array_append (pair, NULL);
  g_value_array_append (pair, NULL);
  g_value_init (pair->values + 0, G_TYPE_UINT);
  g_value_init (pair->values + 1, G_TYPE_STRING);
  g_value_set_uint (pair->values + 0, contact);
  g_value_set_string (pair->values + 1,
      tp_test_contact_list_manager_get_alias (manager, contact));

  aliases = g_ptr_array_sized_new (1);
  g_ptr_array_add (aliases, pair);

  tp_svc_connection_interface_aliasing_emit_aliases_changed (self, aliases);

  g_ptr_array_free (aliases, TRUE);
  g_value_array_free (pair);
}

static void
contact_info_updated_cb (TpTestContactListManager *manager,
                         TpHandle contact,
                         TpTestContactListConnection *self)
{
  GPtrArray *contact_info = tp_test_contact_list_manager_get_contact_info (
      self->priv->list_manager, contact);

  if (contact_info != NULL)
    {
      tp_svc_connection_interface_contact_info_emit_contact_info_changed (self,
          contact, contact_info);
    }
}

static void
presence_updated_cb (TpTestContactListManager *manager,
                     TpHandle contact,
                     TpTestContactListConnection *self)
{
  TpBaseConnection *base = (TpBaseConnection *) self;
  TpPresenceStatus *status;

  /* we ignore the presence indicated by the contact list for our own handle */
  if (contact == base->self_handle)
    return;

  status = tp_presence_status_new (
      tp_test_contact_list_manager_get_presence (manager, contact),
      NULL);
  tp_presence_mixin_emit_one_presence_update ((GObject *) self,
      contact, status);
  tp_presence_status_free (status);
}

static GPtrArray *
create_channel_managers (TpBaseConnection *conn)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (conn);
  GPtrArray *ret = g_ptr_array_sized_new (1);

  self->priv->list_manager =
    TP_TEST_CONTACT_LIST_MANAGER (g_object_new (
          TP_TEST_TYPE_CONTACT_LIST_MANAGER,
          "connection", conn,
          "simulation-delay", self->priv->simulation_delay,
          NULL));

  g_signal_connect (self->priv->list_manager, "alias-updated",
      G_CALLBACK (alias_updated_cb), self);
  g_signal_connect (self->priv->list_manager, "contact-info-updated",
      G_CALLBACK (contact_info_updated_cb), self);
  g_signal_connect (self->priv->list_manager, "presence-updated",
      G_CALLBACK (presence_updated_cb), self);

  g_ptr_array_add (ret, self->priv->list_manager);

  return ret;
}

static gboolean
start_connecting (TpBaseConnection *conn,
                  GError **error)
{
  TpTestContactListConnection *self = TP_TEST_CONTACT_LIST_CONNECTION (conn);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (conn,
      TP_HANDLE_TYPE_CONTACT);

  /* In a real connection manager we'd ask the underlying implementation to
   * start connecting, then go to state CONNECTED when finished, but here
   * we can do it immediately. */

  conn->self_handle = tp_handle_ensure (contact_repo, self->priv->account,
      NULL, error);

  if (conn->self_handle == 0)
    return FALSE;

  tp_base_connection_change_status (conn, TP_CONNECTION_STATUS_CONNECTED,
      TP_CONNECTION_STATUS_REASON_REQUESTED);

  return TRUE;
}

static void
shut_down (TpBaseConnection *conn)
{
  /* In a real connection manager we'd ask the underlying implementation to
   * start shutting down, then call this function when finished, but here
   * we can do it immediately. */
  tp_base_connection_finish_shutdown (conn);
}

static void
aliasing_fill_contact_attributes (GObject *object,
                                  const GArray *contacts,
                                  GHashTable *attributes)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (object);
  guint i;

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle contact = g_array_index (contacts, guint, i);

      tp_contacts_mixin_set_contact_attribute (attributes, contact,
          TP_TOKEN_CONNECTION_INTERFACE_ALIASING_ALIAS,
          tp_g_value_slice_new_string (
            tp_test_contact_list_manager_get_alias (self->priv->list_manager,
              contact)));
    }
}

static void
contact_info_fill_contact_attributes (GObject *object,
                                      const GArray *contacts,
                                      GHashTable *attributes_hash)
{
  TpTestContactListConnection *self = TP_TEST_CONTACT_LIST_CONNECTION (object);
  guint i;

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle contact = g_array_index (contacts, TpHandle, i);
      GPtrArray *contact_info = tp_test_contact_list_manager_get_contact_info (
          self->priv->list_manager, contact);
      if (contact_info != NULL)
        {
          GValue *val =  tp_g_value_slice_new_boxed (
                  TP_ARRAY_TYPE_CONTACT_INFO_FIELD_LIST, contact_info);

          tp_contacts_mixin_set_contact_attribute (attributes_hash,
                  contact,
                  TP_IFACE_CONNECTION_INTERFACE_CONTACT_INFO "/info", val);
        }
    }
}

static TpDBusPropertiesMixinPropImpl conn_contact_info_properties[] = {
      { "ContactInfoFlags", GUINT_TO_POINTER (TP_CONTACT_INFO_FLAG_PUSH |
          TP_CONTACT_INFO_FLAG_CAN_SET), NULL },
      { "SupportedFields", NULL, NULL },
      { NULL }
};

static void
conn_contact_info_properties_getter (GObject *object,
                                     GQuark interface,
                                     GQuark name,
                                     GValue *value,
                                     gpointer getter_data)
{
  GQuark q_supported_fields = g_quark_from_static_string ("SupportedFields");
  static GPtrArray *supported_fields = NULL;

  if (name == q_supported_fields)
    {
      if (supported_fields == NULL)
        {
          supported_fields = g_ptr_array_new ();

          g_ptr_array_add (supported_fields, tp_value_array_build (4,
              G_TYPE_STRING, "bday",
              G_TYPE_STRV, NULL,
              G_TYPE_UINT, 0,
              G_TYPE_UINT, 1,
              G_TYPE_INVALID));

          g_ptr_array_add (supported_fields, tp_value_array_build (4,
              G_TYPE_STRING, "email",
              G_TYPE_STRV, NULL,
              G_TYPE_UINT, 0,
              G_TYPE_UINT, G_MAXUINT32,
              G_TYPE_INVALID));

          g_ptr_array_add (supported_fields, tp_value_array_build (4,
              G_TYPE_STRING, "fn",
              G_TYPE_STRV, NULL,
              G_TYPE_UINT, 0,
              G_TYPE_UINT, 1,
              G_TYPE_INVALID));

          g_ptr_array_add (supported_fields, tp_value_array_build (4,
              G_TYPE_STRING, "tel",
              G_TYPE_STRV, NULL,
              G_TYPE_UINT, 0,
              G_TYPE_UINT, G_MAXUINT32,
              G_TYPE_INVALID));

          g_ptr_array_add (supported_fields, tp_value_array_build (4,
              G_TYPE_STRING, "url",
              G_TYPE_STRV, NULL,
              G_TYPE_UINT, 0,
              G_TYPE_UINT, G_MAXUINT32,
              G_TYPE_INVALID));
        }
      g_value_set_boxed (value, supported_fields);
    }
  else
    {
      g_value_set_uint (value, GPOINTER_TO_UINT (getter_data));
    }
}

static void
constructed (GObject *object)
{
  TpBaseConnection *base = TP_BASE_CONNECTION (object);
  void (*chain_up) (GObject *) =
    G_OBJECT_CLASS (tp_test_contact_list_connection_parent_class)->constructed;

  if (chain_up != NULL)
    chain_up (object);

  tp_contacts_mixin_init (object,
      G_STRUCT_OFFSET (TpTestContactListConnection, contacts_mixin));
  tp_base_connection_register_with_contacts_mixin (base);
  tp_contacts_mixin_add_contact_attributes_iface (object,
      TP_IFACE_CONNECTION_INTERFACE_ALIASING,
      aliasing_fill_contact_attributes);
  tp_contacts_mixin_add_contact_attributes_iface (object,
      TP_IFACE_CONNECTION_INTERFACE_CONTACT_INFO,
      contact_info_fill_contact_attributes);

  tp_presence_mixin_init (object,
      G_STRUCT_OFFSET (TpTestContactListConnection, presence_mixin));
  tp_presence_mixin_simple_presence_register_with_contacts_mixin (object);
}

static gboolean
status_available (GObject *object,
                  guint index_)
{
  TpBaseConnection *base = TP_BASE_CONNECTION (object);

  if (base->status != TP_CONNECTION_STATUS_CONNECTED)
    return FALSE;

  return TRUE;
}

static GHashTable *
get_contact_statuses (GObject *object,
                      const GArray *contacts,
                      GError **error)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (object);
  TpBaseConnection *base = TP_BASE_CONNECTION (object);
  guint i;
  GHashTable *result = g_hash_table_new_full (g_direct_hash, g_direct_equal,
      NULL, (GDestroyNotify) tp_presence_status_free);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle contact = g_array_index (contacts, guint, i);
      TpTestContactListPresence presence;
      GHashTable *parameters;

      /* we get our own status from the connection, and everyone else's status
       * from the contact lists */
      if (contact == base->self_handle)
        {
          presence = (self->priv->away ? TP_TEST_CONTACT_LIST_PRESENCE_AWAY
              : TP_TEST_CONTACT_LIST_PRESENCE_AVAILABLE);
        }
      else
        {
          presence = tp_test_contact_list_manager_get_presence (
              self->priv->list_manager, contact);
        }

      parameters = g_hash_table_new_full (g_str_hash,
          g_str_equal, NULL, (GDestroyNotify) tp_g_value_slice_free);
      g_hash_table_insert (result, GUINT_TO_POINTER (contact),
          tp_presence_status_new (presence, parameters));
      g_hash_table_destroy (parameters);
    }

  return result;
}

static gboolean
set_own_status (GObject *object,
                const TpPresenceStatus *status,
                GError **error)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (object);
  TpBaseConnection *base = TP_BASE_CONNECTION (object);
  GHashTable *presences;

  if (status->index == TP_TEST_CONTACT_LIST_PRESENCE_AWAY)
    {
      if (self->priv->away)
        return TRUE;

      self->priv->away = TRUE;
    }
  else
    {
      if (!self->priv->away)
        return TRUE;

      self->priv->away = FALSE;
    }

  presences = g_hash_table_new_full (g_direct_hash, g_direct_equal,
      NULL, NULL);
  g_hash_table_insert (presences, GUINT_TO_POINTER (base->self_handle),
      (gpointer) status);
  tp_presence_mixin_emit_presence_update (object, presences);
  g_hash_table_destroy (presences);
  return TRUE;
}

static void
tp_test_contact_list_connection_class_init (
    TpTestContactListConnectionClass *klass)
{
  static const gchar *interfaces_always_present[] = {
      TP_IFACE_CONNECTION_INTERFACE_ALIASING,
      TP_IFACE_CONNECTION_INTERFACE_CONTACT_INFO,
      TP_IFACE_CONNECTION_INTERFACE_CONTACTS,
      TP_IFACE_CONNECTION_INTERFACE_PRESENCE,
      TP_IFACE_CONNECTION_INTERFACE_REQUESTS,
      TP_IFACE_CONNECTION_INTERFACE_SIMPLE_PRESENCE,
      NULL };
  static TpDBusPropertiesMixinIfaceImpl prop_interfaces[] = {
        { TP_IFACE_CONNECTION_INTERFACE_CONTACT_INFO,
          conn_contact_info_properties_getter,
          NULL,
          conn_contact_info_properties,
        },
        { NULL }
  };

  TpBaseConnectionClass *base_class = (TpBaseConnectionClass *) klass;
  GObjectClass *object_class = (GObjectClass *) klass;
  GParamSpec *param_spec;

  object_class->get_property = get_property;
  object_class->set_property = set_property;
  object_class->constructed = constructed;
  object_class->finalize = finalize;
  g_type_class_add_private (klass,
      sizeof (TpTestContactListConnectionPrivate));

  base_class->create_handle_repos = create_handle_repos;
  base_class->get_unique_connection_name = get_unique_connection_name;
  base_class->create_channel_managers = create_channel_managers;
  base_class->start_connecting = start_connecting;
  base_class->shut_down = shut_down;
  base_class->interfaces_always_present = interfaces_always_present;

  param_spec = g_param_spec_string ("account", "Account name",
      "The username of this user", NULL,
      G_PARAM_CONSTRUCT_ONLY | G_PARAM_READWRITE |
      G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB);
  g_object_class_install_property (object_class, PROP_ACCOUNT, param_spec);

  param_spec = g_param_spec_object ("manager", "TpTestContactListManager",
      "TpTestContactListManager object that owns this channel",
      TP_TEST_TYPE_CONTACT_LIST_MANAGER,
      G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_MANAGER, param_spec);

  param_spec = g_param_spec_uint ("publish-flags", "publish channel flags",
      "'publish' channel group capabilities flags",
      0, ~0, default_group_flags,
      G_PARAM_CONSTRUCT_ONLY | G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_PUBLISH_FLAGS,
      param_spec);

  param_spec = g_param_spec_uint ("subscribe-flags", "subscribe channel flags",
      "'subscribe' channel group capabilities flags",
      0, ~0, default_group_flags,
      G_PARAM_CONSTRUCT_ONLY | G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_SUBSCRIBE_FLAGS,
      param_spec);

  param_spec = g_param_spec_uint ("simulation-delay", "Simulation delay",
      "Delay between simulated network events",
      0, G_MAXUINT32, 1000,
      G_PARAM_CONSTRUCT_ONLY | G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_SIMULATION_DELAY,
      param_spec);

  tp_contacts_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestContactListConnectionClass, contacts_mixin));
  tp_presence_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestContactListConnectionClass, presence_mixin),
      status_available, get_contact_statuses, set_own_status,
      tp_test_contact_list_presence_statuses ());
  tp_presence_mixin_simple_presence_init_dbus_properties (object_class);

  klass->properties_class.interfaces = prop_interfaces;
  tp_dbus_properties_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestContactListConnectionClass, properties_class));
}

static void
get_alias_flags (TpSvcConnectionInterfaceAliasing *aliasing,
                 DBusGMethodInvocation *context)
{
  TpBaseConnection *base = TP_BASE_CONNECTION (aliasing);

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);
  tp_svc_connection_interface_aliasing_return_from_get_alias_flags (context,
      TP_CONNECTION_ALIAS_FLAG_USER_SET);
}

static void
get_aliases (TpSvcConnectionInterfaceAliasing *aliasing,
             const GArray *contacts,
             DBusGMethodInvocation *context)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (aliasing);
  TpBaseConnection *base = TP_BASE_CONNECTION (aliasing);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GHashTable *result;
  GError *error = NULL;
  guint i;

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);

  if (!tp_handles_are_valid (contact_repo, contacts, FALSE, &error))
    {
      dbus_g_method_return_error (context, error);
      g_error_free (error);
      return;
    }

  result = g_hash_table_new_full (g_direct_hash, g_direct_equal, NULL, NULL);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle contact = g_array_index (contacts, TpHandle, i);
      const gchar *alias = tp_test_contact_list_manager_get_alias (
          self->priv->list_manager, contact);

      g_hash_table_insert (result, GUINT_TO_POINTER (contact),
          (gchar *) alias);
    }

  tp_svc_connection_interface_aliasing_return_from_get_aliases (context,
      result);
  g_hash_table_destroy (result);
}

static void
request_aliases (TpSvcConnectionInterfaceAliasing *aliasing,
                 const GArray *contacts,
                 DBusGMethodInvocation *context)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (aliasing);
  TpBaseConnection *base = TP_BASE_CONNECTION (aliasing);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GPtrArray *result;
  gchar **strings;
  GError *error = NULL;
  guint i;

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);

  if (!tp_handles_are_valid (contact_repo, contacts, FALSE, &error))
    {
      dbus_g_method_return_error (context, error);
      g_error_free (error);
      return;
    }

  result = g_ptr_array_sized_new (contacts->len + 1);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle contact = g_array_index (contacts, TpHandle, i);
      const gchar *alias = tp_test_contact_list_manager_get_alias (
          self->priv->list_manager, contact);

      g_ptr_array_add (result, (gchar *) alias);
    }

  g_ptr_array_add (result, NULL);
  strings = (gchar **) g_ptr_array_free (result, FALSE);
  tp_svc_connection_interface_aliasing_return_from_request_aliases (context,
      (const gchar **) strings);
  g_free (strings);
}

static void
set_aliases (TpSvcConnectionInterfaceAliasing *aliasing,
             GHashTable *aliases,
             DBusGMethodInvocation *context)
{
  TpTestContactListConnection *self =
    TP_TEST_CONTACT_LIST_CONNECTION (aliasing);
  TpBaseConnection *base = TP_BASE_CONNECTION (aliasing);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GHashTableIter iter;
  gpointer key, value;

  g_hash_table_iter_init (&iter, aliases);

  while (g_hash_table_iter_next (&iter, &key, &value))
    {
      GError *error = NULL;

      if (!tp_handle_is_valid (contact_repo, GPOINTER_TO_UINT (key),
            &error))
        {
          dbus_g_method_return_error (context, error);
          g_error_free (error);
          return;
        }
    }

  g_hash_table_iter_init (&iter, aliases);

  while (g_hash_table_iter_next (&iter, &key, &value))
    {
      tp_test_contact_list_manager_set_alias (self->priv->list_manager,
          GPOINTER_TO_UINT (key), value);
    }

  tp_svc_connection_interface_aliasing_return_from_set_aliases (context);
}

static void
init_aliasing (gpointer iface,
               gpointer iface_data G_GNUC_UNUSED)
{
  TpSvcConnectionInterfaceAliasingClass *klass = iface;

#define IMPLEMENT(x) tp_svc_connection_interface_aliasing_implement_##x (\
    klass, x)
  IMPLEMENT(get_alias_flags);
  IMPLEMENT(request_aliases);
  IMPLEMENT(get_aliases);
  IMPLEMENT(set_aliases);
#undef IMPLEMENT
}

static void
get_contact_info (
    TpSvcConnectionInterfaceContactInfo *iface,
    const GArray *contacts,
    DBusGMethodInvocation *context)
{
  TpTestContactListConnection *self = TP_TEST_CONTACT_LIST_CONNECTION (iface);
  TpBaseConnection *base = (TpBaseConnection *) self;
  TpHandleRepoIface *contact_handles = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *error = NULL;
  guint i;
  GHashTable *ret;

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (TP_BASE_CONNECTION (iface),
      context);

  if (!tp_handles_are_valid (contact_handles, contacts, FALSE, &error))
    {
      dbus_g_method_return_error (context, error);
      g_error_free (error);
      return;
    }

  ret = dbus_g_type_specialized_construct (TP_HASH_TYPE_CONTACT_INFO_MAP);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle contact = g_array_index (contacts, TpHandle, i);
      GPtrArray *contact_info = tp_test_contact_list_manager_get_contact_info (
          self->priv->list_manager, contact);
      if (contact_info != NULL)
        {
          g_hash_table_insert (ret, GUINT_TO_POINTER (contact),
              g_boxed_copy (TP_ARRAY_TYPE_CONTACT_INFO_FIELD_LIST,
                contact_info));
        }
    }

  tp_svc_connection_interface_contact_info_return_from_get_contact_info (
      context, ret);

  g_boxed_free (TP_HASH_TYPE_CONTACT_INFO_MAP, ret);
}

static void
refresh_contact_info (TpSvcConnectionInterfaceContactInfo *iface,
                      const GArray *contacts,
                      DBusGMethodInvocation *context)
{
  TpTestContactListConnection *self = TP_TEST_CONTACT_LIST_CONNECTION (iface);
  guint i;

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle contact = g_array_index (contacts, TpHandle, i);
      GPtrArray *contact_info;

      contact_info = tp_test_contact_list_manager_get_contact_info (
          self->priv->list_manager, contact);

      if (contact_info != NULL)
        {
          tp_svc_connection_interface_contact_info_emit_contact_info_changed (
              iface, contact, contact_info);
        }
    }
}

static void
_return_from_request_contact_info (TpTestContactListConnection *self,
                                   guint contact,
                                   DBusGMethodInvocation *context)
{
  GError *error = NULL;
  GPtrArray *contact_info;

  contact_info = tp_test_contact_list_manager_get_contact_info (
      self->priv->list_manager, contact);

  if (contact_info == NULL)
    {
      dbus_g_method_return_error (context, error);
      g_error_free (error);
      return;
    }

  tp_svc_connection_interface_contact_info_return_from_request_contact_info (
      context, contact_info);
}

static void
request_contact_info (TpSvcConnectionInterfaceContactInfo *iface,
                      guint contact,
                      DBusGMethodInvocation *context)
{
  TpTestContactListConnection *self = TP_TEST_CONTACT_LIST_CONNECTION (iface);
  TpBaseConnection *base = (TpBaseConnection *) self;
  TpHandleRepoIface *contact_handles = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *err = NULL;

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);

  if (!tp_handle_is_valid (contact_handles, contact, &err))
    {
      dbus_g_method_return_error (context, err);
      g_error_free (err);
      return;
    }

  _return_from_request_contact_info (self, contact, context);
}

static void
set_contact_info (TpSvcConnectionInterfaceContactInfo *iface,
                  const GPtrArray *contact_info,
                  DBusGMethodInvocation *context)
{
  TpTestContactListConnection *self = TP_TEST_CONTACT_LIST_CONNECTION (iface);
  GError *error = NULL;

  if (contact_info == NULL)
    {
      dbus_g_method_return_error (context, error);
      g_error_free (error);
      return;
    }

  tp_test_contact_list_manager_set_contact_info (self->priv->list_manager,
      contact_info);

  tp_svc_connection_interface_contact_info_return_from_set_contact_info (
      context);
}

static void
init_contact_info (gpointer iface,
                   gpointer iface_data G_GNUC_UNUSED)
{
  TpSvcConnectionInterfaceContactInfoClass *klass = iface;

#define IMPLEMENT(x) tp_svc_connection_interface_contact_info_implement_##x (\
    klass, x)
  IMPLEMENT(get_contact_info);
  IMPLEMENT(refresh_contact_info);
  IMPLEMENT(request_contact_info);
  IMPLEMENT(set_contact_info);
#undef IMPLEMENT
}

TpTestContactListConnection *
tp_test_contact_list_connection_new (const gchar *account,
    const gchar *protocol,
    TpChannelGroupFlags publish_flags,
    TpChannelGroupFlags subscribe_flags)
{
  if (publish_flags == 0)
    publish_flags = default_group_flags;

  if (subscribe_flags == 0)
    subscribe_flags = default_group_flags;

  return g_object_new (TP_TEST_TYPE_CONTACT_LIST_CONNECTION,
      "account", account,
      "protocol", protocol,
      "publish-flags", publish_flags,
      "subscribe-flags", subscribe_flags,
      NULL);
}
