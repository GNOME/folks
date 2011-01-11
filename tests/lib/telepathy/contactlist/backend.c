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
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

#include <config.h>
#include <glib.h>
#include <telepathy-glib/base-connection.h>
#include <telepathy-glib/dbus.h>

#include "account.h"
#include "account-manager.h"
#include "conn.h"
#include "contact-list.h"

#include "backend.h"

struct _TpTestBackendPrivate
{
  TpDBusDaemon *daemon;
  TpTestAccount *account;
  TpTestAccountManager *account_manager;
  TpBaseConnection *conn;
  gchar *bus_name;
  gchar *object_path;
};

G_DEFINE_TYPE (TpTestBackend, tp_test_backend, G_TYPE_OBJECT)

enum
{
  PROP_CONNECTION = 1,
  N_PROPS
};

static void
tp_test_backend_init (TpTestBackend *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self, TP_TEST_TYPE_BACKEND,
      TpTestBackendPrivate);
}

static void
tp_test_backend_finalize (GObject *object)
{
  tp_test_backend_tear_down (TP_TEST_BACKEND (object));
  G_OBJECT_CLASS (tp_test_backend_parent_class)->finalize (object);
}

static void
tp_test_backend_get_property (GObject *object,
    guint property_id,
    GValue *value,
    GParamSpec *spec)
{
  TpTestBackend *self = TP_TEST_BACKEND (object);

  switch (property_id)
    {
    case PROP_CONNECTION:
      g_value_set_object (value, self->priv->conn);
      break;

    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
    }
}

static void
tp_test_backend_set_property (GObject *object,
    guint property_id,
    const GValue *value,
    GParamSpec *spec)
{
  switch (property_id)
    {
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, spec);
    }
}

static void
tp_test_backend_class_init (TpTestBackendClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  GParamSpec *param_spec;

  g_type_class_add_private (klass, sizeof (TpTestBackendPrivate));
  object_class->finalize = tp_test_backend_finalize;
  object_class->get_property = tp_test_backend_get_property;
  object_class->set_property = tp_test_backend_set_property;

  param_spec = g_param_spec_object ("connection", "Connection",
      "The base ContactListConnection",
      TP_TEST_TYPE_CONTACT_LIST_CONNECTION,
      G_PARAM_READABLE | G_PARAM_STATIC_STRINGS);
  g_object_class_install_property (object_class, PROP_CONNECTION, param_spec);
}

TpTestBackend *
tp_test_backend_new (void)
{
  return g_object_new (TP_TEST_TYPE_BACKEND, NULL);
}

static gboolean
_log_fatal_handler (const char *domain,
   GLogLevelFlags flags,
   const char *message,
   gpointer user_data)
{
  gboolean fatal;

  /* Ignore the error caused by not running the logger */
  fatal = !g_str_has_suffix (message,
      "The name org.freedesktop.Telepathy.Logger was not provided by any "
      ".service files");

  if (fatal)
    g_on_error_stack_trace ("libtool --mode=exec gdb");

  return fatal;
}

void
tp_test_backend_set_up (TpTestBackend *self)
{
  TpTestBackendPrivate *priv = self->priv;
  TpHandleRepoIface *handle_repo;
  TpHandle self_handle;
  gchar *object_path;
  GError *error = NULL;

  /* Override the handler set in the general Folks.TestCase class */
  g_log_set_default_handler (g_log_default_handler, NULL);
  g_test_log_set_fatal_handler (_log_fatal_handler, NULL);

  priv->daemon = tp_dbus_daemon_dup (&error);
  if (error != NULL)
    g_error ("Couldn't get D-Bus daemon: %s", error->message);

  /* Set up a contact list connection */
  priv->conn =
      TP_BASE_CONNECTION (tp_test_contact_list_connection_new ("me@example.com",
          "protocol", 0, 0));

  tp_base_connection_register (priv->conn, "cm", &priv->bus_name,
      &priv->object_path, &error);
  if (error != NULL)
    {
      g_error ("Failed to register connection %p: %s", priv->conn,
          error->message);
    }

  handle_repo = tp_base_connection_get_handles (priv->conn,
      TP_HANDLE_TYPE_CONTACT);
  self_handle = tp_handle_ensure (handle_repo, "me@example.com", NULL, &error);
  if (error != NULL)
    {
      g_error ("Couldn't ensure self handle '%s': %s", "me@example.com",
              error->message);
    }

  tp_base_connection_set_self_handle (priv->conn, self_handle);
  tp_base_connection_change_status (priv->conn,
      TP_CONNECTION_STATUS_CONNECTED, TP_CONNECTION_STATUS_REASON_REQUESTED);

  /* Create an account */
  priv->account = tp_test_account_new (priv->object_path);
  object_path =
      g_strdup_printf ("%scm/protocol/account", TP_ACCOUNT_OBJECT_PATH_BASE);
  tp_dbus_daemon_register_object (priv->daemon, object_path, priv->account);
  g_free (object_path);

  /* Create an account manager */
  tp_dbus_daemon_request_name (priv->daemon, TP_ACCOUNT_MANAGER_BUS_NAME, FALSE,
      &error);
  if (error != NULL)
    {
      g_error ("Couldn't request account manager bus name '%s': %s",
          TP_ACCOUNT_MANAGER_BUS_NAME, error->message);
    }

  priv->account_manager = tp_test_account_manager_new ();
  tp_dbus_daemon_register_object (priv->daemon, TP_ACCOUNT_MANAGER_OBJECT_PATH,
      priv->account_manager);
}

void
tp_test_backend_tear_down (TpTestBackend *self)
{
  TpTestBackendPrivate *priv = self->priv;
  GError *error = NULL;

  tp_base_connection_change_status (priv->conn,
      TP_CONNECTION_STATUS_DISCONNECTED, TP_CONNECTION_STATUS_REASON_REQUESTED);

  tp_dbus_daemon_unregister_object (priv->daemon, priv->account_manager);
  tp_clear_object (&priv->account_manager);

  tp_dbus_daemon_release_name (priv->daemon, TP_ACCOUNT_MANAGER_BUS_NAME,
      &error);
  if (error != NULL)
    {
      g_error ("Couldn't release account manager bus name '%s': %s",
          TP_ACCOUNT_MANAGER_BUS_NAME, error->message);
    }

  tp_dbus_daemon_unregister_object (priv->daemon, priv->account);
  tp_clear_object (&priv->account);

  tp_clear_object (&priv->conn);
  tp_clear_object (&priv->daemon);
  g_free (priv->bus_name);
  priv->bus_name = NULL;
  g_free (priv->object_path);
  priv->object_path = NULL;
}

/**
 * tp_test_backend_get_connection:
 * @self: the backend
 *
 * Returns: (transfer none): the contact list connection or %NULL.
 */
TpTestContactListConnection *
tp_test_backend_get_connection (TpTestBackend *self)
{
  g_return_val_if_fail (TP_TEST_IS_BACKEND (self), NULL);

  return TP_TEST_CONTACT_LIST_CONNECTION (self->priv->conn);
}
