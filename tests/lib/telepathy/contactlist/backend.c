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
  TpTestAccountManager *account_manager;
  GList *accounts;
};

typedef struct
{
  TpTestAccount *account;
  TpBaseConnection *conn;
  gchar *bus_name;
  gchar *object_path;
} AccountData;

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
  TpTestBackendPrivate *priv = TP_TEST_BACKEND (object)->priv;
  GList *l;

  for (l = priv->accounts; l != NULL; l = l->next)
    {
      tp_test_backend_remove_account (TP_TEST_BACKEND (object), l->data);
    }

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
      g_value_set_object (value, tp_test_backend_get_connection (self));
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
_log_should_suppress (const char *domain,
   GLogLevelFlags flags,
   const char *message)
{
  /* Ignore the error caused by not running the logger */
  return g_str_has_suffix (message,
      "The name org.freedesktop.Telepathy.Logger was not provided by any "
      ".service files");
}

static void
_log_default_handler (const char *domain,
   GLogLevelFlags flags,
   const char *message,
   gpointer user_data)
{
  if (!_log_should_suppress (domain, flags, message))
    g_log_default_handler (domain, flags, message, user_data);
}

static gboolean
_log_fatal_handler (const char *domain,
   GLogLevelFlags flags,
   const char *message,
   gpointer user_data)
{
  gboolean suppress = _log_should_suppress (domain, flags, message);

  if (!suppress)
    g_on_error_stack_trace ("libtool --mode=exec gdb");

  return !suppress;
}

void
tp_test_backend_set_up (TpTestBackend *self)
{
  TpTestBackendPrivate *priv = self->priv;
  GError *error = NULL;

  /* Override the handler set in the general Folks.TestCase class */
  g_log_set_default_handler (_log_default_handler, NULL);
  g_test_log_set_fatal_handler (_log_fatal_handler, NULL);

  priv->daemon = tp_dbus_daemon_dup (&error);
  if (error != NULL)
    g_error ("Couldn't get D-Bus daemon: %s", error->message);

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

/**
 * tp_test_backend_add_account:
 * @self:
 * @protocol_name:
 * @user_id:
 * @connection_manager_name:
 * @account_name:
 *
 * Return value: (transfer none):
 */
gpointer
tp_test_backend_add_account (TpTestBackend *self,
    const gchar *protocol_name,
    const gchar *user_id,
    const gchar *connection_manager_name,
    const gchar *account_name)
{
  TpTestBackendPrivate *priv = self->priv;
  TpHandleRepoIface *handle_repo;
  TpHandle self_handle;
  gchar *object_path;
  AccountData *data;
  GError *error = NULL;

  data = g_slice_new (AccountData);

  /* Set up a contact list connection */
  data->conn =
      TP_BASE_CONNECTION (tp_test_contact_list_connection_new (user_id,
          protocol_name, 0, 0));

  tp_base_connection_register (data->conn, connection_manager_name,
      &data->bus_name, &data->object_path, &error);
  if (error != NULL)
    {
      g_error ("Failed to register connection %p: %s", data->conn,
          error->message);
    }

  handle_repo = tp_base_connection_get_handles (data->conn,
      TP_HANDLE_TYPE_CONTACT);
  self_handle = tp_handle_ensure (handle_repo, user_id, NULL, &error);
  if (error != NULL)
    {
      g_error ("Couldn't ensure self handle '%s': %s", user_id, error->message);
    }

  tp_base_connection_set_self_handle (data->conn, self_handle);
  tp_base_connection_change_status (data->conn,
      TP_CONNECTION_STATUS_CONNECTED, TP_CONNECTION_STATUS_REASON_REQUESTED);

  /* Create an account */
  data->account = tp_test_account_new (data->object_path);
  object_path =
      g_strdup_printf ("%s%s/%s/%s", TP_ACCOUNT_OBJECT_PATH_BASE,
          connection_manager_name, protocol_name, account_name);
  tp_dbus_daemon_register_object (priv->daemon, object_path, data->account);

  /* Add the account to the account manager */
  tp_test_account_manager_add_account (priv->account_manager, object_path);

  g_free (object_path);

  /* Add the account to the list of accounts and return a handle to it */
  priv->accounts = g_list_prepend (priv->accounts, data);

  return data;
}

void
tp_test_backend_remove_account (TpTestBackend *self,
    gpointer handle)
{
  TpTestBackendPrivate *priv = self->priv;
  AccountData *data;

  if (g_list_find (priv->accounts, handle) == NULL)
    {
      return;
    }

  /* Remove the account from the list of accounts */
  priv->accounts = g_list_remove (priv->accounts, handle);
  data = (AccountData *) handle;

  /* Remove the account from the account manager */
  tp_test_account_manager_remove_account (priv->account_manager,
      data->object_path);

  /* Disconnect it */
  tp_base_connection_change_status (data->conn,
      TP_CONNECTION_STATUS_DISCONNECTED, TP_CONNECTION_STATUS_REASON_REQUESTED);

  tp_dbus_daemon_unregister_object (priv->daemon, data->account);
  tp_clear_object (&data->account);

  tp_clear_object (&data->conn);

  g_free (data->bus_name);
  g_free (data->object_path);
}

void
tp_test_backend_tear_down (TpTestBackend *self)
{
  TpTestBackendPrivate *priv = self->priv;
  GError *error = NULL;

  tp_dbus_daemon_unregister_object (priv->daemon, priv->account_manager);
  tp_clear_object (&priv->account_manager);

  tp_dbus_daemon_release_name (priv->daemon, TP_ACCOUNT_MANAGER_BUS_NAME,
      &error);
  if (error != NULL)
    {
      g_error ("Couldn't release account manager bus name '%s': %s",
          TP_ACCOUNT_MANAGER_BUS_NAME, error->message);
    }

  tp_clear_object (&priv->daemon);
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
  AccountData *data;

  g_return_val_if_fail (TP_TEST_IS_BACKEND (self), NULL);

  if (self->priv->accounts == NULL)
    {
      return NULL;
    }

  data = (AccountData *) self->priv->accounts->data;
  return TP_TEST_CONTACT_LIST_CONNECTION (data->conn);
}
