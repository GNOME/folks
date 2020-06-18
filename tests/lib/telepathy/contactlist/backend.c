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
#include <telepathy-glib/svc-account.h>

#include "simple-account.h"
#include "simple-account-manager.h"
#include "util.h"
#include "contacts-conn.h"

#include "backend.h"

struct _TpTestsBackend
{
  GObject parent;

  TpDBusDaemon *daemon;
  TpTestsSimpleAccountManager *account_manager;
  TpAccountManager *client_am;
  GList *accounts;
};

typedef struct
{
  TpTestsSimpleAccount *account;
  TpBaseConnection *base_connection;
  TpConnection *client_conn;
  gchar *object_path;
} AccountData;

G_DEFINE_TYPE (TpTestsBackend, tp_tests_backend, G_TYPE_OBJECT)

static void
tp_tests_backend_init (TpTestsBackend *self)
{
}

static void
tp_tests_backend_finalize (GObject *object)
{
  TpTestsBackend *self = TP_TESTS_BACKEND (object);
  GList *l;

  for (l = self->accounts; l != NULL; l = l->next)
    {
      tp_tests_backend_remove_account (TP_TESTS_BACKEND (object), l->data);
    }

  tp_tests_backend_tear_down (TP_TESTS_BACKEND (object));
  G_OBJECT_CLASS (tp_tests_backend_parent_class)->finalize (object);
}

static void
tp_tests_backend_class_init (TpTestsBackendClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->finalize = tp_tests_backend_finalize;
}

TpTestsBackend *
tp_tests_backend_new (void)
{
  return g_object_new (TP_TESTS_TYPE_BACKEND, NULL);
}

static gboolean
_log_should_suppress (const char *domain,
   GLogLevelFlags flags,
   const char *message)
{
  gboolean suppress = FALSE;

  /* Ignore the error caused by not running the logger through dbus-glib */
  suppress |= g_str_has_suffix (message,
      "The name org.freedesktop.Telepathy.Logger was not provided by any "
      ".service files");

  /* And again for GDBus */
  suppress |= g_str_has_suffix (message,
      "Lost connection to the telepathy-logger service.");

  return suppress;
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
  return !_log_should_suppress (domain, flags, message);
}

void
tp_tests_backend_set_up (TpTestsBackend *self)
{
  TpSimpleClientFactory *factory;
  GError *error = NULL;

  /* Override the handler set in the general Folks.TestCase class */
  g_log_set_default_handler (_log_default_handler, NULL);
  g_test_log_set_fatal_handler (_log_fatal_handler, NULL);

  self->daemon = tp_dbus_daemon_dup (&error);
  if (error != NULL)
    g_error ("Couldn't get D-Bus daemon: %s", error->message);

  /* Create an account manager */
  tp_dbus_daemon_request_name (self->daemon, TP_ACCOUNT_MANAGER_BUS_NAME, FALSE,
      &error);
  if (error != NULL)
    {
      g_error ("Couldn't request account manager bus name '%s': %s",
          TP_ACCOUNT_MANAGER_BUS_NAME, error->message);
    }

  self->account_manager = tp_tests_object_new_static_class (
      TP_TESTS_TYPE_SIMPLE_ACCOUNT_MANAGER, NULL);
  tp_dbus_daemon_register_object (self->daemon, TP_ACCOUNT_MANAGER_OBJECT_PATH,
      self->account_manager);

  self->client_am = tp_account_manager_dup ();
  factory = tp_proxy_get_factory (self->client_am);
  tp_simple_client_factory_add_contact_features_varargs (factory,
      TP_CONTACT_FEATURE_ALIAS,
      TP_CONTACT_FEATURE_AVATAR_DATA,
      TP_CONTACT_FEATURE_AVATAR_TOKEN,
      TP_CONTACT_FEATURE_CAPABILITIES,
      TP_CONTACT_FEATURE_CLIENT_TYPES,
      TP_CONTACT_FEATURE_PRESENCE,
      TP_CONTACT_FEATURE_CONTACT_INFO,
      TP_CONTACT_FEATURE_CONTACT_GROUPS,
      TP_CONTACT_FEATURE_INVALID);
}

static void
fill_default_roster (AccountData *data)
{
  TpTestsContactsConnection *conn = (TpTestsContactsConnection *) data->base_connection;
  TpTestsContactListManager *manager;
  TpHandleRepoIface *repo;
  TpHandle handle;
  const gchar *str;
  TpTestsContactsConnectionPresenceStatusIndex presence;
  GPtrArray *info;
  const gchar *single_value[] = { NULL, NULL };
  GQuark conn_features[] = { TP_CONNECTION_FEATURE_CONNECTED, 0 };

  repo = tp_base_connection_get_handles (data->base_connection,
      TP_HANDLE_TYPE_CONTACT);
  manager = tp_tests_contacts_connection_get_contact_list_manager (conn);

  /* Create some contacts and fill some info */
  handle = tp_handle_ensure (repo, "guillaume@example.com", NULL, NULL);
  tp_tests_contact_list_manager_request_subscription (manager, 1, &handle, "");

  handle = tp_handle_ensure (repo, "sjoerd@example.com", NULL, NULL);
  tp_tests_contact_list_manager_request_subscription (manager, 1, &handle, "");

  handle = tp_handle_ensure (repo, "travis@example.com", NULL, NULL);
  tp_tests_contact_list_manager_request_subscription (manager, 1, &handle, "");

  handle = tp_handle_ensure (repo, "olivier@example.com", NULL, NULL);
  tp_tests_contact_list_manager_request_subscription (manager, 1, &handle, "");
  str = "Olivier";
  tp_tests_contacts_connection_change_aliases (conn, 1, &handle, &str);
  presence = TP_TESTS_CONTACTS_CONNECTION_STATUS_AWAY;
  str = "";
  tp_tests_contacts_connection_change_presences (conn, 1, &handle, &presence, &str);
  tp_tests_contact_list_manager_add_to_group (manager, "Montreal", handle);
  tp_tests_contact_list_manager_add_to_group (manager, "Francophones", handle);
  info = g_ptr_array_new_with_free_func ((GDestroyNotify) g_value_array_free);
  single_value[0] = "+15142345678";
  g_ptr_array_add (info, tp_value_array_build (3,
      G_TYPE_STRING, "tel",
      G_TYPE_STRV, NULL,
      G_TYPE_STRV, single_value,
      G_TYPE_INVALID));
  single_value[0] = "Olivier Crete";
  g_ptr_array_add (info, tp_value_array_build (3,
      G_TYPE_STRING, "fn",
      G_TYPE_STRV, NULL,
      G_TYPE_STRV, single_value,
      G_TYPE_INVALID));
  single_value[0] = "olivier@example.com";
  g_ptr_array_add (info, tp_value_array_build (3,
      G_TYPE_STRING, "email",
      G_TYPE_STRV, NULL,
      G_TYPE_STRV, single_value,
      G_TYPE_INVALID));
  single_value[0] = "ocrete.example.com";
  g_ptr_array_add (info, tp_value_array_build (3,
      G_TYPE_STRING, "url",
      G_TYPE_STRV, NULL,
      G_TYPE_STRV, single_value,
      G_TYPE_INVALID));
  tp_tests_contacts_connection_change_contact_info (conn, handle, info);
  g_ptr_array_unref (info);

  handle = tp_handle_ensure (repo, "christian@example.com", NULL, NULL);
  tp_tests_contact_list_manager_request_subscription (manager, 1, &handle, "");

  handle = tp_handle_ensure (repo, "geraldine@example.com", NULL, NULL);
  tp_tests_contact_list_manager_request_subscription (manager, 1, &handle, "");

  handle = tp_handle_ensure (repo, "helen@example.com", NULL, NULL);
  tp_tests_contact_list_manager_request_subscription (manager, 1, &handle, "");

  handle = tp_handle_ensure (repo, "wim@example.com", NULL, NULL);
  tp_tests_contact_list_manager_request_subscription (manager, 1, &handle, "");

  /* Run until connected */
  tp_cli_connection_call_connect (data->client_conn, -1, NULL, NULL, NULL, NULL);
  tp_tests_proxy_run_until_prepared (data->client_conn, conn_features);
}

/**
 * tp_tests_backend_add_account:
 * @self:
 * @user_id:
 *
 * Return value: (transfer none):
 */
gpointer
tp_tests_backend_add_account (TpTestsBackend *self,
    const gchar *protocol,
    const gchar *user_id,
    const gchar *cm_name,
    const gchar *account)
{
  TpSimpleClientFactory *factory;
  AccountData *data;
  gchar *conn_path;
  GError *error = NULL;

  data = g_slice_new (AccountData);

  /* Set up a contact list connection */
  data->base_connection = tp_tests_object_new_static_class (
        TP_TESTS_TYPE_CONTACTS_CONNECTION,
        "account", user_id,
        "protocol", protocol,
        NULL);
  tp_base_connection_register (data->base_connection, cm_name,
        NULL, &conn_path, &error);
  g_assert_no_error (error);

  factory = tp_proxy_get_factory (self->client_am);
  data->client_conn = tp_simple_client_factory_ensure_connection (factory,
      conn_path, NULL, &error);
  g_assert_no_error (error);

  /* Create an account */
  data->account = tp_tests_object_new_static_class (
      TP_TESTS_TYPE_SIMPLE_ACCOUNT, NULL);
  data->object_path = g_strdup_printf ("%s%s/%s/%s", TP_ACCOUNT_OBJECT_PATH_BASE,
      cm_name, protocol, account);
  tp_dbus_daemon_register_object (self->daemon, data->object_path,
      data->account);

  /* Set the connection on the account */
  tp_tests_simple_account_set_connection (data->account, conn_path);

  /* Add the account to the account manager */
  tp_tests_simple_account_manager_add_account (self->account_manager,
      data->object_path, TRUE);

  /* Add the account to the list of accounts and return a handle to it */
  self->accounts = g_list_prepend (self->accounts, data);

  fill_default_roster (data);

  g_free (conn_path);

  return data;
}

void
tp_tests_backend_remove_account (TpTestsBackend *self,
    gpointer handle)
{
  AccountData *data;

  if (g_list_find (self->accounts, handle) == NULL)
    {
      return;
    }

  /* Remove the account from the list of accounts */
  self->accounts = g_list_remove (self->accounts, handle);
  data = (AccountData *) handle;

  /* Make sure all D-Bus traffic with account's connection is done */
  tp_tests_proxy_run_until_dbus_queue_processed (data->client_conn);

  /* Remove the account from the account manager */
  tp_tests_simple_account_manager_remove_account (self->account_manager,
      data->object_path);
  tp_tests_simple_account_removed (data->account);

  /* Disconnect it */
  tp_base_connection_change_status (data->base_connection,
      TP_CONNECTION_STATUS_DISCONNECTED, TP_CONNECTION_STATUS_REASON_REQUESTED);

  tp_dbus_daemon_unregister_object (self->daemon, data->account);

  tp_clear_object (&data->account);
  tp_clear_object (&data->base_connection);
  tp_clear_object (&data->client_conn);
  g_free (data->object_path);
}

void
tp_tests_backend_tear_down (TpTestsBackend *self)
{
  GError *error = NULL;

  if (self->daemon == NULL)
    {
      /* already torn down */
      return;
    }

  /* Make sure all D-Bus traffic with AM is done */
  tp_tests_proxy_run_until_dbus_queue_processed (self->client_am);
  g_clear_object (&self->client_am);

  tp_dbus_daemon_unregister_object (self->daemon, self->account_manager);
  tp_clear_object (&self->account_manager);

  tp_dbus_daemon_release_name (self->daemon, TP_ACCOUNT_MANAGER_BUS_NAME,
      &error);
  if (error != NULL)
    {
      g_error ("Couldn't release account manager bus name '%s': %s",
          TP_ACCOUNT_MANAGER_BUS_NAME, error->message);
    }

  tp_clear_object (&self->daemon);
}

/**
 * tp_tests_backend_get_connection_for_handle:
 * @self: the backend
 *
 * Returns: (transfer none): the contact list connection or %NULL.
 */
TpTestsContactsConnection *
tp_tests_backend_get_connection_for_handle (TpTestsBackend *self,
    gpointer handle)
{
  AccountData *data;

  g_return_val_if_fail (TP_TESTS_IS_BACKEND (self), NULL);

  if (g_list_find (self->accounts, handle) == NULL)
    {
      return NULL;
    }

  data = (AccountData *) handle;
  return TP_TESTS_CONTACTS_CONNECTION (data->base_connection);
}
