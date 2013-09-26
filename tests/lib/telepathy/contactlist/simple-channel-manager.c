/*
 * simple-channel-manager.c
 *
 * Copyright (C) 2010 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>

#include "simple-channel-manager.h"
#include "util.h"
#include "echo-chan.h"

static void channel_manager_iface_init (gpointer, gpointer);

G_DEFINE_TYPE_WITH_CODE (TpTestsSimpleChannelManager,
    tp_tests_simple_channel_manager, G_TYPE_OBJECT,
    G_IMPLEMENT_INTERFACE (TP_TYPE_CHANNEL_MANAGER, channel_manager_iface_init);
    )

/* signals */
enum {
  REQUEST,
  LAST_SIGNAL
};

static guint signals[LAST_SIGNAL];

static void
tp_tests_simple_channel_manager_class_init (TpTestsSimpleChannelManagerClass *klass)
{
  signals[REQUEST] = g_signal_new ("request",
      G_TYPE_FROM_CLASS (klass),
      G_SIGNAL_RUN_LAST,
      0, NULL, NULL, NULL,
      G_TYPE_NONE, 1, G_TYPE_HASH_TABLE);
}

static void
tp_tests_simple_channel_manager_init (TpTestsSimpleChannelManager *self)
{
}

static gboolean
tp_tests_simple_channel_manager_request (TpChannelManager *manager,
    gpointer request_token,
    GHashTable *request_properties)
{
  TpTestsSimpleChannelManager *self =
    TP_TESTS_SIMPLE_CHANNEL_MANAGER (manager);
  GSList *tokens;
  TpExportableChannel *channel;
  TpHandle handle = tp_asv_get_uint32 (request_properties,
      TP_PROP_CHANNEL_TARGET_HANDLE, NULL);
  gchar *path;

  g_signal_emit (manager, signals[REQUEST], 0, request_properties);

  tokens = g_slist_append (NULL, request_token);

  path = g_strdup_printf ("%s/Channel",
      tp_base_connection_get_object_path (self->conn));

  channel = tp_tests_object_new_static_class (
      TP_TESTS_TYPE_ECHO_CHANNEL,
      "connection", self->conn,
      "object-path", path,
      "handle", handle,
      NULL);

  tp_channel_manager_emit_new_channel (manager, channel, tokens);

  g_free (path);
  g_slist_free (tokens);
  g_object_unref (channel);

  return TRUE;
}

static void
channel_manager_iface_init (gpointer g_iface,
    gpointer giface_data G_GNUC_UNUSED)
{
  TpChannelManagerIface *iface = g_iface;

  iface->create_channel = tp_tests_simple_channel_manager_request;
  iface->ensure_channel = tp_tests_simple_channel_manager_request;
  iface->request_channel = tp_tests_simple_channel_manager_request;
}
