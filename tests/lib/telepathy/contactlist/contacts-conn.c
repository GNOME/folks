/*
 * contacts-conn.c - connection with contact info
 *
 * Copyright (C) 2007-2008 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007-2008 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "contacts-conn.h"

#include <dbus/dbus-glib.h>

#include <telepathy-glib/interfaces.h>
#include <telepathy-glib/dbus.h>
#include <telepathy-glib/errors.h>
#include <telepathy-glib/gtypes.h>
#include <telepathy-glib/handle-repo-dynamic.h>
#include <telepathy-glib/util.h>

#include "debug.h"

static void init_aliasing (gpointer, gpointer);
static void init_avatars (gpointer, gpointer);
static void init_location (gpointer, gpointer);
static void init_contact_caps (gpointer, gpointer);
static void init_contact_info (gpointer, gpointer);
static void conn_avatars_properties_getter (GObject *object, GQuark interface,
    GQuark name, GValue *value, gpointer getter_data);

G_DEFINE_TYPE_WITH_CODE (TpTestsContactsConnection,
    tp_tests_contacts_connection,
    TP_TESTS_TYPE_SIMPLE_CONNECTION,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_ALIASING,
      init_aliasing);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_AVATARS,
      init_avatars);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_PRESENCE,
      tp_presence_mixin_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_SIMPLE_PRESENCE,
      tp_presence_mixin_simple_presence_iface_init)
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_LOCATION,
      init_location)
    G_IMPLEMENT_INTERFACE (
      TP_TYPE_SVC_CONNECTION_INTERFACE_CONTACT_CAPABILITIES,
      init_contact_caps)
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_CONTACT_INFO,
      init_contact_info)
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_CONTACTS,
      tp_contacts_mixin_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_CONTACT_LIST,
      tp_base_contact_list_mixin_list_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_CONTACT_GROUPS,
      tp_base_contact_list_mixin_groups_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_CLIENT_TYPES,
      NULL);
    );

/* type definition stuff */

static const char *mime_types[] = { "image/png", NULL };
static TpDBusPropertiesMixinPropImpl conn_avatars_properties[] = {
      { "MinimumAvatarWidth", GUINT_TO_POINTER (1), NULL },
      { "MinimumAvatarHeight", GUINT_TO_POINTER (2), NULL },
      { "RecommendedAvatarWidth", GUINT_TO_POINTER (3), NULL },
      { "RecommendedAvatarHeight", GUINT_TO_POINTER (4), NULL },
      { "MaximumAvatarWidth", GUINT_TO_POINTER (5), NULL },
      { "MaximumAvatarHeight", GUINT_TO_POINTER (6), NULL },
      { "MaximumAvatarBytes", GUINT_TO_POINTER (7), NULL },
      /* special-cased - it's the only one with a non-guint value */
      { "SupportedAvatarMIMETypes", NULL, NULL },
      { NULL }
};

enum
{
  N_SIGNALS
};

struct _TpTestsContactsConnectionPrivate
{
  /* TpHandle => gchar * */
  GHashTable *aliases;
  /* TpHandle => AvatarData */
  GHashTable *avatars;
  /* TpHandle => ContactsConnectionPresenceStatusIndex */
  GHashTable *presence_statuses;
  /* TpHandle => gchar * */
  GHashTable *presence_messages;
  /* TpHandle => GHashTable * */
  GHashTable *locations;
  /* TpHandle => GPtrArray * */
  GHashTable *capabilities;
  /* TpHandle => GPtrArray * */
  GHashTable *contact_info;
  GPtrArray *default_contact_info;

  TpTestsContactListManager *list_manager;
};

typedef struct
{
  GArray *data;
  gchar *mime_type;
  gchar *token;
} AvatarData;

static AvatarData *
avatar_data_new (GArray *data,
    const gchar *mime_type,
    const gchar *token)
{
  AvatarData *a;

  a = g_slice_new (AvatarData);
  a->data = data ? g_array_ref (data) : NULL;
  a->mime_type = g_strdup (mime_type);
  a->token = g_strdup (token);

  return a;
}

static void
avatar_data_free (gpointer data)
{
  AvatarData *a = data;

  if (a != NULL)
    {
      if (a->data != NULL)
        g_array_unref (a->data);
      g_free (a->mime_type);
      g_free (a->token);
      g_slice_free (AvatarData, a);
    }
}

static void
free_rcc_list (GPtrArray *rccs)
{
  g_boxed_free (TP_ARRAY_TYPE_REQUESTABLE_CHANNEL_CLASS_LIST, rccs);
}

static void
tp_tests_contacts_connection_init (TpTestsContactsConnection *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self, TP_TESTS_TYPE_CONTACTS_CONNECTION,
      TpTestsContactsConnectionPrivate);
  self->priv->aliases = g_hash_table_new_full (g_direct_hash, g_direct_equal,
      NULL, g_free);
  self->priv->avatars = g_hash_table_new_full (g_direct_hash,
      g_direct_equal, NULL, avatar_data_free);
  self->priv->presence_statuses = g_hash_table_new_full (g_direct_hash,
      g_direct_equal, NULL, NULL);
  self->priv->presence_messages = g_hash_table_new_full (g_direct_hash,
      g_direct_equal, NULL, g_free);
  self->priv->locations = g_hash_table_new_full (g_direct_hash, g_direct_equal,
      NULL, (GDestroyNotify) g_hash_table_unref);
  self->priv->capabilities = g_hash_table_new_full (g_direct_hash,
      g_direct_equal, NULL, (GDestroyNotify) free_rcc_list);
  self->priv->contact_info = g_hash_table_new_full (g_direct_hash,
      g_direct_equal, NULL, (GDestroyNotify) g_ptr_array_unref);
}

static void
finalize (GObject *object)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (object);

  tp_contacts_mixin_finalize (object);
  g_hash_table_unref (self->priv->aliases);
  g_hash_table_unref (self->priv->avatars);
  g_hash_table_unref (self->priv->presence_statuses);
  g_hash_table_unref (self->priv->presence_messages);
  g_hash_table_unref (self->priv->locations);
  g_hash_table_unref (self->priv->capabilities);
  g_hash_table_unref (self->priv->contact_info);

  if (self->priv->default_contact_info != NULL)
    g_ptr_array_unref (self->priv->default_contact_info);

  G_OBJECT_CLASS (tp_tests_contacts_connection_parent_class)->finalize (object);
}

static void
aliasing_fill_contact_attributes (GObject *object,
                                  const GArray *contacts,
                                  GHashTable *attributes)
{
  guint i;
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (object);
  TpBaseConnection *base = TP_BASE_CONNECTION (object);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, guint, i);
      const gchar *alias = g_hash_table_lookup (self->priv->aliases,
          GUINT_TO_POINTER (handle));

      if (alias == NULL)
        {
          alias = tp_handle_inspect (contact_repo, handle);
        }

      tp_contacts_mixin_set_contact_attribute (attributes, handle,
          TP_IFACE_CONNECTION_INTERFACE_ALIASING "/alias",
          tp_g_value_slice_new_string (alias));
    }
}

static void
avatars_fill_contact_attributes (GObject *object,
                                 const GArray *contacts,
                                 GHashTable *attributes)
{
  guint i;
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (object);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, guint, i);
      AvatarData *a = g_hash_table_lookup (self->priv->avatars,
          GUINT_TO_POINTER (handle));

      if (a != NULL && a->token != NULL)
        {
          tp_contacts_mixin_set_contact_attribute (attributes, handle,
              TP_IFACE_CONNECTION_INTERFACE_AVATARS "/token",
              tp_g_value_slice_new_string (a->token));
        }
    }
}

static void
location_fill_contact_attributes (GObject *object,
    const GArray *contacts,
    GHashTable *attributes)
{
  guint i;
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (object);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, guint, i);
      GHashTable *location = g_hash_table_lookup (self->priv->locations,
          GUINT_TO_POINTER (handle));

      if (location != NULL)
        {
          tp_contacts_mixin_set_contact_attribute (attributes, handle,
              TP_IFACE_CONNECTION_INTERFACE_LOCATION "/location",
              tp_g_value_slice_new_boxed (TP_HASH_TYPE_LOCATION, location));
        }
    }
}

static void
contact_caps_fill_contact_attributes (GObject *object,
    const GArray *contacts,
    GHashTable *attributes)
{
  guint i;
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (object);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, guint, i);
      GPtrArray *caps = g_hash_table_lookup (self->priv->capabilities,
          GUINT_TO_POINTER (handle));

      if (caps != NULL)
        {
          tp_contacts_mixin_set_contact_attribute (attributes, handle,
              TP_IFACE_CONNECTION_INTERFACE_CONTACT_CAPABILITIES "/capabilities",
              tp_g_value_slice_new_boxed (
                TP_ARRAY_TYPE_REQUESTABLE_CHANNEL_CLASS_LIST, caps));
        }
    }
}

static void
contact_info_fill_contact_attributes (GObject *object,
    const GArray *contacts,
    GHashTable *attributes)
{
  guint i;
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (object);

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, guint, i);
      GPtrArray *info = g_hash_table_lookup (self->priv->contact_info,
          GUINT_TO_POINTER (handle));

      if (info != NULL)
        {
          tp_contacts_mixin_set_contact_attribute (attributes, handle,
              TP_IFACE_CONNECTION_INTERFACE_CONTACT_INFO "/info",
              tp_g_value_slice_new_boxed (TP_ARRAY_TYPE_CONTACT_INFO_FIELD_LIST,
                  info));
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
client_types_fill_contact_attributes (
    GObject *object,
    const GArray *contacts,
    GHashTable *attributes)
{
  TpTestsContactsConnectionClass *klass =
      TP_TESTS_CONTACTS_CONNECTION_GET_CLASS (object);

  if (klass->fill_client_types != NULL)
    klass->fill_client_types (object, contacts, attributes);
  /* …else do nothing: a no-op implementation is valid, relatively speaking.
   * The spec sez the /client-types attribute should be “omitted from the
   * result if the contact's client types are not known.”
   */
}

static void
constructed (GObject *object)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (object);
  TpBaseConnection *base = TP_BASE_CONNECTION (object);
  void (*parent_impl) (GObject *) =
    G_OBJECT_CLASS (tp_tests_contacts_connection_parent_class)->constructed;

  if (parent_impl != NULL)
    parent_impl (object);

  tp_contacts_mixin_init (object,
      G_STRUCT_OFFSET (TpTestsContactsConnection, contacts_mixin));
  tp_base_connection_register_with_contacts_mixin (base);
  if (self->priv->list_manager)
    tp_base_contact_list_mixin_register_with_contacts_mixin (base);
  tp_contacts_mixin_add_contact_attributes_iface (object,
      TP_IFACE_CONNECTION_INTERFACE_ALIASING,
      aliasing_fill_contact_attributes);
  tp_contacts_mixin_add_contact_attributes_iface (object,
      TP_IFACE_CONNECTION_INTERFACE_AVATARS,
      avatars_fill_contact_attributes);
  tp_contacts_mixin_add_contact_attributes_iface (object,
      TP_IFACE_CONNECTION_INTERFACE_LOCATION,
      location_fill_contact_attributes);
  tp_contacts_mixin_add_contact_attributes_iface (object,
      TP_IFACE_CONNECTION_INTERFACE_CONTACT_CAPABILITIES,
      contact_caps_fill_contact_attributes);
  tp_contacts_mixin_add_contact_attributes_iface (object,
      TP_IFACE_CONNECTION_INTERFACE_CONTACT_INFO,
      contact_info_fill_contact_attributes);
  tp_contacts_mixin_add_contact_attributes_iface (object,
      TP_IFACE_CONNECTION_INTERFACE_CLIENT_TYPES,
      client_types_fill_contact_attributes);

  tp_presence_mixin_init (object,
      G_STRUCT_OFFSET (TpTestsContactsConnection, presence_mixin));
  tp_presence_mixin_simple_presence_register_with_contacts_mixin (object);
}

static const TpPresenceStatusOptionalArgumentSpec can_have_message[] = {
      { "message", "s", NULL, NULL },
      { NULL }
};

/* Must match TpTestsContactsConnectionPresenceStatusIndex in the .h */
static const TpPresenceStatusSpec my_statuses[] = {
      { "available", TP_CONNECTION_PRESENCE_TYPE_AVAILABLE, TRUE,
        can_have_message },
      { "busy", TP_CONNECTION_PRESENCE_TYPE_BUSY, TRUE, can_have_message },
      { "away", TP_CONNECTION_PRESENCE_TYPE_AWAY, TRUE, can_have_message },
      { "offline", TP_CONNECTION_PRESENCE_TYPE_OFFLINE, FALSE, NULL },
      { "unknown", TP_CONNECTION_PRESENCE_TYPE_UNKNOWN, FALSE, NULL },
      { "error", TP_CONNECTION_PRESENCE_TYPE_ERROR, FALSE, NULL },
      { NULL }
};

static gboolean
my_status_available (GObject *object,
                     guint index)
{
  TpBaseConnection *base = TP_BASE_CONNECTION (object);

  return tp_base_connection_check_connected (base, NULL);
}

static GHashTable *
my_get_contact_statuses (GObject *object,
                         const GArray *contacts,
                         GError **error)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (object);
  GHashTable *result = g_hash_table_new_full (g_direct_hash, g_direct_equal,
      NULL, (GDestroyNotify) tp_presence_status_free);
  guint i;

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, TpHandle, i);
      gpointer key = GUINT_TO_POINTER (handle);
      TpTestsContactsConnectionPresenceStatusIndex index;
      const gchar *presence_message;
      GHashTable *parameters;

      index = GPOINTER_TO_UINT (g_hash_table_lookup (
            self->priv->presence_statuses, key));
      presence_message = g_hash_table_lookup (
          self->priv->presence_messages, key);

      parameters = g_hash_table_new_full (g_str_hash,
          g_str_equal, NULL, (GDestroyNotify) tp_g_value_slice_free);

      if (presence_message != NULL)
        g_hash_table_insert (parameters, (gpointer) "message",
            tp_g_value_slice_new_string (presence_message));

      g_hash_table_insert (result, key,
          tp_presence_status_new (index, parameters));
      g_hash_table_unref (parameters);
    }

  return result;
}

static gboolean
my_set_own_status (GObject *object,
                   const TpPresenceStatus *status,
                   GError **error)
{
  TpBaseConnection *base_conn = TP_BASE_CONNECTION (object);
  TpTestsContactsConnectionPresenceStatusIndex index = status->index;
  const gchar *message = "";
  TpHandle self_handle;

  if (status->optional_arguments != NULL)
    {
      message = g_hash_table_lookup (status->optional_arguments, "message");

      if (message == NULL)
        message = "";
    }

  self_handle = tp_base_connection_get_self_handle (base_conn);
  tp_tests_contacts_connection_change_presences (TP_TESTS_CONTACTS_CONNECTION (object),
      1, &self_handle, &index, &message);

  return TRUE;
}

static guint
my_get_maximum_status_message_length_cb (GObject *obj)
{
  return 512;
}

static GPtrArray *
create_channel_managers (TpBaseConnection *conn)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (conn);
  GPtrArray *ret = g_ptr_array_sized_new (1);

  self->priv->list_manager = g_object_new (TP_TESTS_TYPE_CONTACT_LIST_MANAGER,
      "connection", conn, NULL);

  g_ptr_array_add (ret, self->priv->list_manager);

  return ret;
}

static void
tp_tests_contacts_connection_class_init (TpTestsContactsConnectionClass *klass)
{
  TpBaseConnectionClass *base_class =
      (TpBaseConnectionClass *) klass;
  GObjectClass *object_class = (GObjectClass *) klass;
  TpPresenceMixinClass *mixin_class;
  static const gchar *interfaces_always_present[] = {
      TP_IFACE_CONNECTION_INTERFACE_ALIASING,
      TP_IFACE_CONNECTION_INTERFACE_AVATARS,
      TP_IFACE_CONNECTION_INTERFACE_CONTACTS,
      TP_IFACE_CONNECTION_INTERFACE_CONTACT_LIST,
      TP_IFACE_CONNECTION_INTERFACE_CONTACT_GROUPS,
      TP_IFACE_CONNECTION_INTERFACE_PRESENCE,
      TP_IFACE_CONNECTION_INTERFACE_SIMPLE_PRESENCE,
      TP_IFACE_CONNECTION_INTERFACE_LOCATION,
      TP_IFACE_CONNECTION_INTERFACE_CLIENT_TYPES,
      TP_IFACE_CONNECTION_INTERFACE_CONTACT_CAPABILITIES,
      TP_IFACE_CONNECTION_INTERFACE_CONTACT_INFO,
      TP_IFACE_CONNECTION_INTERFACE_REQUESTS,
      NULL };
  static TpDBusPropertiesMixinIfaceImpl prop_interfaces[] = {
        { TP_IFACE_CONNECTION_INTERFACE_AVATARS,
          conn_avatars_properties_getter,
          NULL,
          conn_avatars_properties,
        },
        { TP_IFACE_CONNECTION_INTERFACE_CONTACT_INFO,
          conn_contact_info_properties_getter,
          NULL,
          conn_contact_info_properties,
        },
        { NULL }
  };

  object_class->constructed = constructed;
  object_class->finalize = finalize;
  g_type_class_add_private (klass, sizeof (TpTestsContactsConnectionPrivate));

  base_class->interfaces_always_present = interfaces_always_present;
  base_class->create_channel_managers = create_channel_managers;

  tp_contacts_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestsContactsConnectionClass, contacts_mixin));

  tp_presence_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestsContactsConnectionClass, presence_mixin),
      my_status_available, my_get_contact_statuses,
      my_set_own_status, my_statuses);
  mixin_class = TP_PRESENCE_MIXIN_CLASS(klass);
  mixin_class->get_maximum_status_message_length =
      my_get_maximum_status_message_length_cb;

  tp_presence_mixin_simple_presence_init_dbus_properties (object_class);

  klass->properties_class.interfaces = prop_interfaces;
  tp_dbus_properties_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestsContactsConnectionClass, properties_class));

  tp_base_contact_list_mixin_class_init (base_class);
}

TpTestsContactListManager *
tp_tests_contacts_connection_get_contact_list_manager (
    TpTestsContactsConnection *self)
{
  return self->priv->list_manager;
}

/**
 * tp_tests_contacts_connection_change_aliases:
 * @self: a #TpTestsContactsConnection
 * @n: the number of handles
 * @handles: (array length=n): the handles
 * @aliases: (array length=n): aliases
 *
 */
void
tp_tests_contacts_connection_change_aliases (TpTestsContactsConnection *self,
                                    guint n,
                                    const TpHandle *handles,
                                    const gchar * const *aliases)
{
  GPtrArray *structs = g_ptr_array_sized_new (n);
  guint i;

  for (i = 0; i < n; i++)
    {
      GValueArray *pair = g_value_array_new (2);

      DEBUG ("contact#%u -> %s", handles[i], aliases[i]);

      g_hash_table_insert (self->priv->aliases,
          GUINT_TO_POINTER (handles[i]), g_strdup (aliases[i]));

      g_value_array_append (pair, NULL);
      g_value_init (pair->values + 0, G_TYPE_UINT);
      g_value_set_uint (pair->values + 0, handles[i]);

      g_value_array_append (pair, NULL);
      g_value_init (pair->values + 1, G_TYPE_STRING);
      g_value_set_string (pair->values + 1, aliases[i]);

      g_ptr_array_add (structs, pair);
    }

  tp_svc_connection_interface_aliasing_emit_aliases_changed (self,
      structs);

  g_ptr_array_foreach (structs, (GFunc) g_value_array_free, NULL);
  g_ptr_array_unref (structs);
}

void
tp_tests_contacts_connection_change_presences (
    TpTestsContactsConnection *self,
    guint n,
    const TpHandle *handles,
    const TpTestsContactsConnectionPresenceStatusIndex *indexes,
    const gchar * const *messages)
{
  GHashTable *presences = g_hash_table_new_full (g_direct_hash, g_direct_equal,
      NULL, (GDestroyNotify) tp_presence_status_free);
  guint i;

  for (i = 0; i < n; i++)
    {
      GHashTable *parameters;
      gpointer key = GUINT_TO_POINTER (handles[i]);

      DEBUG ("contact#%u -> %s \"%s\"", handles[i],
          my_statuses[indexes[i]].name, messages[i]);

      g_hash_table_insert (self->priv->presence_statuses, key,
          GUINT_TO_POINTER (indexes[i]));
      g_hash_table_insert (self->priv->presence_messages, key,
          g_strdup (messages[i]));

      parameters = g_hash_table_new_full (g_str_hash,
          g_str_equal, NULL, (GDestroyNotify) tp_g_value_slice_free);

      if (messages[i] != NULL && messages[i][0] != '\0')
        g_hash_table_insert (parameters, (gpointer) "message",
            tp_g_value_slice_new_string (messages[i]));

      g_hash_table_insert (presences, key, tp_presence_status_new (indexes[i],
            parameters));
      g_hash_table_unref (parameters);
    }

  tp_presence_mixin_emit_presence_update ((GObject *) self,
      presences);
  g_hash_table_unref (presences);
}

void
tp_tests_contacts_connection_change_avatar_tokens (TpTestsContactsConnection *self,
                                          guint n,
                                          const TpHandle *handles,
                                          const gchar * const *tokens)
{
  guint i;

  for (i = 0; i < n; i++)
    {
      DEBUG ("contact#%u -> %s", handles[i], tokens[i]);
      g_hash_table_insert (self->priv->avatars,
          GUINT_TO_POINTER (handles[i]), avatar_data_new (NULL, NULL, tokens[i]));
      tp_svc_connection_interface_avatars_emit_avatar_updated (self,
          handles[i], tokens[i]);
    }
}

void
tp_tests_contacts_connection_change_avatar_data (
    TpTestsContactsConnection *self,
    TpHandle handle,
    GArray *data,
    const gchar *mime_type,
    const gchar *token)
{
  g_hash_table_insert (self->priv->avatars,
      GUINT_TO_POINTER (handle), avatar_data_new (data, mime_type, token));

  tp_svc_connection_interface_avatars_emit_avatar_updated (self,
      handle, token);
}

void
tp_tests_contacts_connection_change_locations (TpTestsContactsConnection *self,
    guint n,
    const TpHandle *handles,
    GHashTable **locations)
{
  guint i;

  for (i = 0; i < n; i++)
    {
      DEBUG ("contact#%u ->", handles[i]);
      tp_asv_dump (locations[i]);
      g_hash_table_insert (self->priv->locations,
          GUINT_TO_POINTER (handles[i]), g_hash_table_ref (locations[i]));

      tp_svc_connection_interface_location_emit_location_updated (self,
          handles[i], locations[i]);
    }
}

void
tp_tests_contacts_connection_change_capabilities (
    TpTestsContactsConnection *self,
    GHashTable *capabilities)
{
  GHashTableIter iter;
  gpointer handle, caps;

  g_hash_table_iter_init (&iter, capabilities);
  while (g_hash_table_iter_next (&iter, &handle, &caps))
    {
      g_hash_table_insert (self->priv->capabilities,
          handle,
          g_boxed_copy (TP_ARRAY_TYPE_REQUESTABLE_CHANNEL_CLASS_LIST,
            caps));
    }

  tp_svc_connection_interface_contact_capabilities_emit_contact_capabilities_changed (
      self, capabilities);
}

void
tp_tests_contacts_connection_change_contact_info (
    TpTestsContactsConnection *self,
    TpHandle handle,
    GPtrArray *info)
{
  g_hash_table_insert (self->priv->contact_info, GUINT_TO_POINTER (handle),
      g_ptr_array_ref (info));

  tp_svc_connection_interface_contact_info_emit_contact_info_changed (self,
      handle, info);
}

void
tp_tests_contacts_connection_set_default_contact_info (
    TpTestsContactsConnection *self,
    GPtrArray *info)
{
  if (self->priv->default_contact_info != NULL)
    g_ptr_array_unref (self->priv->default_contact_info);
  self->priv->default_contact_info = g_ptr_array_ref (info);
}

static void
my_get_alias_flags (TpSvcConnectionInterfaceAliasing *aliasing,
                    DBusGMethodInvocation *context)
{
  TpBaseConnection *base = TP_BASE_CONNECTION (aliasing);

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);
  tp_svc_connection_interface_aliasing_return_from_get_alias_flags (context,
      TP_CONNECTION_ALIAS_FLAG_USER_SET);
}

static void
my_get_aliases (TpSvcConnectionInterfaceAliasing *aliasing,
                const GArray *contacts,
                DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (aliasing);
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
      TpHandle handle = g_array_index (contacts, TpHandle, i);
      const gchar *alias = g_hash_table_lookup (self->priv->aliases,
          GUINT_TO_POINTER (handle));

      if (alias == NULL)
        g_hash_table_insert (result, GUINT_TO_POINTER (handle),
            (gchar *) tp_handle_inspect (contact_repo, handle));
      else
        g_hash_table_insert (result, GUINT_TO_POINTER (handle),
            (gchar *) alias);
    }

  tp_svc_connection_interface_aliasing_return_from_get_aliases (context,
      result);
  g_hash_table_unref (result);
}

static void
my_request_aliases (TpSvcConnectionInterfaceAliasing *aliasing,
                    const GArray *contacts,
                    DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (aliasing);
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
      TpHandle handle = g_array_index (contacts, TpHandle, i);
      const gchar *alias = g_hash_table_lookup (self->priv->aliases,
          GUINT_TO_POINTER (handle));

      if (alias == NULL)
        g_ptr_array_add (result,
            (gchar *) tp_handle_inspect (contact_repo, handle));
      else
        g_ptr_array_add (result, (gchar *) alias);
    }

  g_ptr_array_add (result, NULL);
  strings = (gchar **) g_ptr_array_free (result, FALSE);
  tp_svc_connection_interface_aliasing_return_from_request_aliases (context,
      (const gchar **) strings);
  g_free (strings);
}

static void
my_set_aliases (TpSvcConnectionInterfaceAliasing *aliasing,
    GHashTable *table,
    DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (aliasing);
  TpBaseConnection *base = TP_BASE_CONNECTION (aliasing);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  guint n;
  GArray *handles;
  GPtrArray *aliases;
  GHashTableIter iter;
  gpointer key, value;
  GError *error = NULL;

  /* Convert the hash table to arrays of handles and aliases */
  n = g_hash_table_size (table);
  handles = g_array_sized_new (FALSE, FALSE, sizeof (TpHandle), n);
  aliases = g_ptr_array_sized_new (n);
  g_hash_table_iter_init (&iter, table);
  while (g_hash_table_iter_next (&iter, &key, &value))
    {
      TpHandle handle = GPOINTER_TO_UINT (key);

      g_array_append_val (handles, handle);
      g_ptr_array_add (aliases, value);
    }
  g_assert_cmpuint (handles->len, ==, n);
  g_assert_cmpuint (aliases->len, ==, n);

  /* Verify all handles are valid */
  if (!tp_handles_are_valid (contact_repo, handles, FALSE, &error))
    {
      dbus_g_method_return_error (context, error);
      g_clear_error (&error);
      goto out;
    }

  /* Change aliases */
  tp_tests_contacts_connection_change_aliases (self, n,
      (const TpHandle *) handles->data,
      (const gchar * const *) aliases->pdata);

  tp_svc_connection_interface_aliasing_return_from_set_aliases (context);

out:
  g_array_unref (handles);
  g_ptr_array_unref (aliases);
}

static void
init_aliasing (gpointer g_iface,
               gpointer iface_data)
{
  TpSvcConnectionInterfaceAliasingClass *klass = g_iface;

#define IMPLEMENT(x) tp_svc_connection_interface_aliasing_implement_##x (\
    klass, my_##x)
  IMPLEMENT(get_alias_flags);
  IMPLEMENT(request_aliases);
  IMPLEMENT(get_aliases);
  IMPLEMENT(set_aliases);
#undef IMPLEMENT
}

static void
my_get_avatar_tokens (TpSvcConnectionInterfaceAvatars *avatars,
                      const GArray *contacts,
                      DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (avatars);
  TpBaseConnection *base = TP_BASE_CONNECTION (avatars);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *error = NULL;
  GHashTable *result;
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
      TpHandle handle = g_array_index (contacts, TpHandle, i);
      AvatarData *a = g_hash_table_lookup (self->priv->avatars,
          GUINT_TO_POINTER (handle));

      if (a == NULL || a->token == NULL)
        {
          /* we're expected to do a round-trip to the server to find out
           * their token, so we have to give some sort of result. Assume
           * no avatar, here */
          a = avatar_data_new (NULL, NULL, "");
          g_hash_table_insert (self->priv->avatars,
              GUINT_TO_POINTER (handle), a);
          tp_svc_connection_interface_avatars_emit_avatar_updated (self,
              handle, a->token);
        }

      g_hash_table_insert (result, GUINT_TO_POINTER (handle),
          a->token);
    }

  tp_svc_connection_interface_avatars_return_from_get_known_avatar_tokens (
      context, result);
  g_hash_table_unref (result);
}

static void
my_get_known_avatar_tokens (TpSvcConnectionInterfaceAvatars *avatars,
                            const GArray *contacts,
                            DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (avatars);
  TpBaseConnection *base = TP_BASE_CONNECTION (avatars);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *error = NULL;
  GHashTable *result;
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
      TpHandle handle = g_array_index (contacts, TpHandle, i);
      AvatarData *a = g_hash_table_lookup (self->priv->avatars,
          GUINT_TO_POINTER (handle));
      const gchar *token = a ? a->token : NULL;

      g_hash_table_insert (result, GUINT_TO_POINTER (handle),
          (gchar *) (token != NULL ? token : ""));
    }

  tp_svc_connection_interface_avatars_return_from_get_known_avatar_tokens (
      context, result);
  g_hash_table_unref (result);
}

static void
my_request_avatars (TpSvcConnectionInterfaceAvatars *avatars,
    const GArray *contacts,
    DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (avatars);
  TpBaseConnection *base = TP_BASE_CONNECTION (avatars);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *error = NULL;
  guint i;

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);

  if (!tp_handles_are_valid (contact_repo, contacts, FALSE, &error))
    {
      dbus_g_method_return_error (context, error);
      g_error_free (error);
      return;
    }

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, TpHandle, i);
      AvatarData *a = g_hash_table_lookup (self->priv->avatars,
          GUINT_TO_POINTER (handle));

      if (a != NULL)
        tp_svc_connection_interface_avatars_emit_avatar_retrieved (self, handle,
            a->token, a->data, a->mime_type);
    }

  tp_svc_connection_interface_avatars_return_from_request_avatars (context);
}

static void
conn_avatars_properties_getter (GObject *object,
                                GQuark interface,
                                GQuark name,
                                GValue *value,
                                gpointer getter_data)
{
  GQuark q_mime_types = g_quark_from_static_string (
      "SupportedAvatarMIMETypes");

  if (name == q_mime_types)
    {
      g_value_set_static_boxed (value, mime_types);
    }
  else
    {
      g_value_set_uint (value, GPOINTER_TO_UINT (getter_data));
    }
}

static void
init_avatars (gpointer g_iface,
              gpointer iface_data)
{
  TpSvcConnectionInterfaceAvatarsClass *klass = g_iface;

#define IMPLEMENT(x) tp_svc_connection_interface_avatars_implement_##x (\
    klass, my_##x)
  /* IMPLEMENT(get_avatar_requirements); */
  IMPLEMENT(get_avatar_tokens);
  IMPLEMENT(get_known_avatar_tokens);
  /* IMPLEMENT(request_avatar); */
  IMPLEMENT(request_avatars);
  /* IMPLEMENT(set_avatar); */
  /* IMPLEMENT(clear_avatar); */
#undef IMPLEMENT
}

static void
my_get_locations (TpSvcConnectionInterfaceLocation *avatars,
    const GArray *contacts,
    DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (avatars);
  TpBaseConnection *base = TP_BASE_CONNECTION (avatars);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *error = NULL;
  GHashTable *result;
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
      TpHandle handle = g_array_index (contacts, TpHandle, i);
      GHashTable *location = g_hash_table_lookup (self->priv->locations,
          GUINT_TO_POINTER (handle));

      if (location != NULL)
        {
          g_hash_table_insert (result, GUINT_TO_POINTER (handle), location);
        }
    }

  tp_svc_connection_interface_location_return_from_get_locations (
      context, result);
  g_hash_table_unref (result);
}

static void
init_location (gpointer g_iface,
    gpointer iface_data)
{
  TpSvcConnectionInterfaceLocationClass *klass = g_iface;

#define IMPLEMENT(x) tp_svc_connection_interface_location_implement_##x (\
    klass, my_##x)
  IMPLEMENT(get_locations);
#undef IMPLEMENT
}

static void
my_get_contact_capabilities (TpSvcConnectionInterfaceContactCapabilities *obj,
    const GArray *contacts,
    DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (obj);
  TpBaseConnection *base = TP_BASE_CONNECTION (obj);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *error = NULL;
  GHashTable *result;
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
      TpHandle handle = g_array_index (contacts, TpHandle, i);
      GPtrArray *arr = g_hash_table_lookup (self->priv->capabilities,
          GUINT_TO_POINTER (handle));

      if (arr != NULL)
        {
          g_hash_table_insert (result, GUINT_TO_POINTER (handle), arr);
        }
    }

  tp_svc_connection_interface_contact_capabilities_return_from_get_contact_capabilities (
      context, result);

  g_hash_table_unref (result);
}

static void
init_contact_caps (gpointer g_iface,
    gpointer iface_data)
{
  TpSvcConnectionInterfaceContactCapabilitiesClass *klass = g_iface;

#define IMPLEMENT(x) tp_svc_connection_interface_contact_capabilities_implement_##x (\
    klass, my_##x)
  IMPLEMENT(get_contact_capabilities);
#undef IMPLEMENT
}

static GPtrArray *
lookup_contact_info (TpTestsContactsConnection *self,
    TpHandle handle)
{
  GPtrArray *ret = g_hash_table_lookup (self->priv->contact_info,
      GUINT_TO_POINTER (handle));

  if (ret == NULL && self->priv->default_contact_info != NULL)
    {
      ret = self->priv->default_contact_info;
      g_hash_table_insert (self->priv->contact_info, GUINT_TO_POINTER (handle),
          g_ptr_array_ref (ret));
    }

  if (ret == NULL)
    return g_ptr_array_new ();

  return g_ptr_array_ref (ret);
}

static void
my_refresh_contact_info (TpSvcConnectionInterfaceContactInfo *obj,
    const GArray *contacts,
    DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (obj);
  TpBaseConnection *base = TP_BASE_CONNECTION (obj);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *error = NULL;
  guint i;

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);

  if (!tp_handles_are_valid (contact_repo, contacts, FALSE, &error))
    {
      dbus_g_method_return_error (context, error);
      g_error_free (error);
      return;
    }

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, guint, i);
      GPtrArray *arr = lookup_contact_info (self, handle);

      tp_svc_connection_interface_contact_info_emit_contact_info_changed (self,
          handle, arr);
      g_ptr_array_unref (arr);
    }

  tp_svc_connection_interface_contact_info_return_from_refresh_contact_info (
      context);
}

static void
my_request_contact_info (TpSvcConnectionInterfaceContactInfo *obj,
    guint handle,
    DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (obj);
  TpBaseConnection *base = TP_BASE_CONNECTION (obj);
  TpHandleRepoIface *contact_repo = tp_base_connection_get_handles (base,
      TP_HANDLE_TYPE_CONTACT);
  GError *error = NULL;
  GPtrArray *ret;

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);

  if (!tp_handle_is_valid (contact_repo, handle, &error))
    {
      dbus_g_method_return_error (context, error);
      g_error_free (error);
      return;
    }

  ret = lookup_contact_info (self, handle);

  tp_svc_connection_interface_contact_info_return_from_request_contact_info (
      context, ret);

  g_ptr_array_unref (ret);
}

static void
my_set_contact_info (TpSvcConnectionInterfaceContactInfo *obj,
    const GPtrArray *info,
    DBusGMethodInvocation *context)
{
  TpTestsContactsConnection *self = TP_TESTS_CONTACTS_CONNECTION (obj);
  TpBaseConnection *base = TP_BASE_CONNECTION (obj);
  GPtrArray *copy;
  guint i;
  TpHandle self_handle;

  TP_BASE_CONNECTION_ERROR_IF_NOT_CONNECTED (base, context);

  /* Deep copy info */
  copy = g_ptr_array_new_with_free_func ((GDestroyNotify) g_value_array_free);
  for (i = 0; i < info->len; i++)
    g_ptr_array_add (copy, g_value_array_copy (g_ptr_array_index (info, i)));

  self_handle = tp_base_connection_get_self_handle (base);
  tp_tests_contacts_connection_change_contact_info (self, self_handle, copy);
  g_ptr_array_unref (copy);

  tp_svc_connection_interface_contact_info_return_from_set_contact_info (
      context);
}

static void
init_contact_info (gpointer g_iface,
    gpointer iface_data)
{
  TpSvcConnectionInterfaceContactInfoClass *klass = g_iface;

#define IMPLEMENT(x) tp_svc_connection_interface_contact_info_implement_##x (\
    klass, my_##x)
  IMPLEMENT (refresh_contact_info);
  IMPLEMENT (request_contact_info);
  IMPLEMENT (set_contact_info);
#undef IMPLEMENT
}

/* =============== Legacy version (no Contacts interface) ================= */

G_DEFINE_TYPE (TpTestsLegacyContactsConnection,
    tp_tests_legacy_contacts_connection, TP_TESTS_TYPE_CONTACTS_CONNECTION);

enum
{
    LEGACY_PROP_HAS_IMMORTAL_HANDLES = 1
};

static void
legacy_contacts_connection_get_property (GObject *object,
    guint property_id,
    GValue *value,
    GParamSpec *pspec)
{
  switch (property_id)
    {
    case LEGACY_PROP_HAS_IMMORTAL_HANDLES:
      /* Pretend we don't. */
      g_value_set_boolean (value, FALSE);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
      break;
    }
}

static void
tp_tests_legacy_contacts_connection_init (TpTestsLegacyContactsConnection *self)
{
}

static void
tp_tests_legacy_contacts_connection_class_init (
    TpTestsLegacyContactsConnectionClass *klass)
{
  /* Leave Contacts out of the interfaces we say are present, so clients
   * won't use it */
  static const gchar *interfaces_always_present[] = {
      TP_IFACE_CONNECTION_INTERFACE_ALIASING,
      TP_IFACE_CONNECTION_INTERFACE_AVATARS,
      TP_IFACE_CONNECTION_INTERFACE_PRESENCE,
      TP_IFACE_CONNECTION_INTERFACE_SIMPLE_PRESENCE,
      TP_IFACE_CONNECTION_INTERFACE_LOCATION,
      TP_IFACE_CONNECTION_INTERFACE_REQUESTS,
      NULL };
  TpBaseConnectionClass *base_class =
      (TpBaseConnectionClass *) klass;
  GObjectClass *object_class = (GObjectClass *) klass;

  object_class->get_property = legacy_contacts_connection_get_property;

  base_class->interfaces_always_present = interfaces_always_present;

  g_object_class_override_property (object_class,
      LEGACY_PROP_HAS_IMMORTAL_HANDLES, "has-immortal-handles");
}

/* =============== No Requests and no ContactCapabilities ================= */

G_DEFINE_TYPE (TpTestsNoRequestsConnection, tp_tests_no_requests_connection,
    TP_TESTS_TYPE_CONTACTS_CONNECTION);

static void
tp_tests_no_requests_connection_init (TpTestsNoRequestsConnection *self)
{
}

static void
tp_tests_no_requests_connection_class_init (
    TpTestsNoRequestsConnectionClass *klass)
{
  static const gchar *interfaces_always_present[] = {
      TP_IFACE_CONNECTION_INTERFACE_ALIASING,
      TP_IFACE_CONNECTION_INTERFACE_AVATARS,
      TP_IFACE_CONNECTION_INTERFACE_CONTACTS,
      TP_IFACE_CONNECTION_INTERFACE_PRESENCE,
      TP_IFACE_CONNECTION_INTERFACE_SIMPLE_PRESENCE,
      TP_IFACE_CONNECTION_INTERFACE_LOCATION,
      NULL };
  TpBaseConnectionClass *base_class =
      (TpBaseConnectionClass *) klass;

  base_class->interfaces_always_present = interfaces_always_present;
  base_class->create_channel_managers = NULL;
}
