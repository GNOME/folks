/*
 * conn.c - an example connection
 *
 * Copyright (C) 2007 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "echo-conn.h"

#include <dbus/dbus-glib.h>

#include <telepathy-glib/telepathy-glib.h>

#include "echo-im-manager.h"
#include "simple-channel-manager.h"

G_DEFINE_TYPE (TpTestsEchoConnection,
    tp_tests_echo_connection,
    TP_TESTS_TYPE_CONTACTS_CONNECTION)

/* type definition stuff */

enum
{
  PROP_CHANNEL_MANAGER = 1,
  N_PROPS
};

struct _TpTestsEchoConnectionPrivate
{
  TpTestsSimpleChannelManager *channel_manager;
};


static void
tp_tests_echo_connection_init (TpTestsEchoConnection *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self, TP_TESTS_TYPE_ECHO_CONNECTION,
      TpTestsEchoConnectionPrivate);
}

/* Returns the same id given in but in lowercase. If '#' is present,
 * the normalized contact will be the lhs of it. For example:
 *
 * LOL -> lol
 * Lol#foo -> lol
 */
static gchar *
tp_tests_echo_normalize_contact (TpHandleRepoIface *repo,
                           const gchar *id,
                           gpointer context,
                           GError **error)
{
  gchar *hash;

  if (id[0] == '\0')
    {
      g_set_error (error, TP_ERROR, TP_ERROR_INVALID_HANDLE,
          "ID must not be empty");
      return NULL;
    }

  hash = g_utf8_strchr (id, -1, '#');

  return g_utf8_strdown (id, hash != NULL ? (hash - id) : -1);
}

static void
create_handle_repos (TpBaseConnection *conn,
                     TpHandleRepoIface *repos[TP_NUM_HANDLE_TYPES])
{
  ((TpBaseConnectionClass *)
      tp_tests_echo_connection_parent_class)->create_handle_repos (conn, repos);

  /* Replace the contacts handle repo with our own, for special normalization */
  g_assert (repos[TP_HANDLE_TYPE_CONTACT] != NULL);
  g_object_unref (repos[TP_HANDLE_TYPE_CONTACT]);
  repos[TP_HANDLE_TYPE_CONTACT] = tp_dynamic_handle_repo_new
      (TP_HANDLE_TYPE_CONTACT, tp_tests_echo_normalize_contact, NULL);
}

static GPtrArray *
create_channel_managers (TpBaseConnection *conn)
{
  TpTestsEchoConnection *self = TP_TESTS_ECHO_CONNECTION (conn);
  GPtrArray *ret;

  ret = ((TpBaseConnectionClass *)
      tp_tests_echo_connection_parent_class)->create_channel_managers (conn);

  if (self->priv->channel_manager == NULL)
    {
      self->priv->channel_manager = g_object_new (TP_TESTS_TYPE_ECHO_IM_MANAGER,
          "connection", conn,
          NULL);
    }

  /* tp-glib will free this for us so we don't need to worry about
     doing it ourselves. */
  g_ptr_array_add (ret, self->priv->channel_manager);

  return ret;
}

static void
get_property (GObject *object,
    guint property_id,
    GValue *value,
    GParamSpec *spec)
{
  TpTestsEchoConnection *self = TP_TESTS_ECHO_CONNECTION (object);

  switch (property_id) {
    case PROP_CHANNEL_MANAGER:
      g_assert (self->priv->channel_manager == NULL); /* construct-only */
      g_value_set_object (value, self->priv->channel_manager);
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
  TpTestsEchoConnection *self = TP_TESTS_ECHO_CONNECTION (object);

  switch (property_id) {
    case PROP_CHANNEL_MANAGER:
      self->priv->channel_manager = g_value_dup_object (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
  }
}

static void
tp_tests_echo_connection_class_init (TpTestsEchoConnectionClass *klass)
{
  TpBaseConnectionClass *base_class =
      (TpBaseConnectionClass *) klass;
  GObjectClass *object_class = (GObjectClass *) klass;
  GParamSpec *param_spec;

  object_class->get_property = get_property;
  object_class->set_property = set_property;
  g_type_class_add_private (klass, sizeof (TpTestsEchoConnectionPrivate));

  base_class->create_handle_repos = create_handle_repos;
  base_class->create_channel_managers = create_channel_managers;

  param_spec = g_param_spec_object ("channel-manager", "Channel manager",
      "The channel manager", TP_TESTS_TYPE_SIMPLE_CHANNEL_MANAGER,
      G_PARAM_CONSTRUCT_ONLY | G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_CHANNEL_MANAGER, param_spec);
}
