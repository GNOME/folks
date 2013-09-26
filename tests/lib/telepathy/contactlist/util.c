/* Simple utility code used by the regression tests.
 *
 * Copyright © 2008-2010 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright © 2008 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "util.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>

#include <glib/gstdio.h>
#include <string.h>

#ifdef G_OS_UNIX
# include <unistd.h> /* for alarm() */
#endif

#ifdef HAVE_GIO_UNIX
#include <gio/gunixsocketaddress.h>
#include <gio/gunixconnection.h>
#endif

void
tp_tests_proxy_run_until_prepared (gpointer proxy,
    const GQuark *features)
{
  GError *error = NULL;

  tp_tests_proxy_run_until_prepared_or_failed (proxy, features, &error);
  g_assert_no_error (error);
}

/* A GAsyncReadyCallback whose user_data is a GAsyncResult **. It writes a
 * reference to the result into that pointer. */
void
tp_tests_result_ready_cb (GObject *object,
    GAsyncResult *res,
    gpointer user_data)
{
  GAsyncResult **result = user_data;

  *result = g_object_ref (res);
}

/* Run until *result contains a result. Intended to be used with a pending
 * async call that uses tp_tests_result_ready_cb. */
void
tp_tests_run_until_result (GAsyncResult **result)
{
  /* not synchronous */
  g_assert (*result == NULL);

  while (*result == NULL)
    g_main_context_iteration (NULL, TRUE);
}

gboolean
tp_tests_proxy_run_until_prepared_or_failed (gpointer proxy,
    const GQuark *features,
    GError **error)
{
  GAsyncResult *result = NULL;
  gboolean r;

  tp_proxy_prepare_async (proxy, features, tp_tests_result_ready_cb, &result);

  tp_tests_run_until_result (&result);

  r =  tp_proxy_prepare_finish (proxy, result, error);
  g_object_unref (result);
  return r;
}

TpDBusDaemon *
tp_tests_dbus_daemon_dup_or_die (void)
{
  TpDBusDaemon *d = tp_dbus_daemon_dup (NULL);

  /* In a shared library, this would be very bad (see fd.o #18832), but in a
   * regression test that's going to be run under a temporary session bus,
   * it's just what we want. */
  if (d == NULL)
    {
      g_error ("Unable to connect to session bus");
    }

  return d;
}

static void
introspect_cb (TpProxy *proxy G_GNUC_UNUSED,
    const gchar *xml G_GNUC_UNUSED,
    const GError *error G_GNUC_UNUSED,
    gpointer user_data,
    GObject *weak_object G_GNUC_UNUSED)
{
  g_main_loop_quit (user_data);
}

void
tp_tests_proxy_run_until_dbus_queue_processed (gpointer proxy)
{
  GMainLoop *loop = g_main_loop_new (NULL, FALSE);

  tp_cli_dbus_introspectable_call_introspect (proxy, -1, introspect_cb,
      loop, NULL, NULL);
  g_main_loop_run (loop);
  g_main_loop_unref (loop);
}

void
_test_assert_empty_strv (const char *file,
    int line,
    gconstpointer strv)
{
  const gchar * const *strings = strv;

  if (strv != NULL && strings[0] != NULL)
    {
      guint i;

      g_message ("%s:%d: expected empty strv, but got:", file, line);

      for (i = 0; strings[i] != NULL; i++)
        {
          g_message ("* \"%s\"", strings[i]);
        }

      g_error ("%s:%d: strv wasn't empty (see above for contents",
          file, line);
    }
}

void
_tp_tests_assert_strv_equals (const char *file,
    int line,
    const char *expected_desc,
    gconstpointer expected_strv,
    const char *actual_desc,
    gconstpointer actual_strv)
{
  const gchar * const *expected = expected_strv;
  const gchar * const *actual = actual_strv;
  guint i;

  g_assert (expected != NULL);
  g_assert (actual != NULL);

  for (i = 0; expected[i] != NULL || actual[i] != NULL; i++)
    {
      if (expected[i] == NULL)
        {
          g_error ("%s:%d: assertion failed: (%s)[%u] == (%s)[%u]: "
              "NULL == %s", file, line, expected_desc, i,
              actual_desc, i, actual[i]);
        }
      else if (actual[i] == NULL)
        {
          g_error ("%s:%d: assertion failed: (%s)[%u] == (%s)[%u]: "
              "%s == NULL", file, line, expected_desc, i,
              actual_desc, i, expected[i]);
        }
      else if (tp_strdiff (expected[i], actual[i]))
        {
          g_error ("%s:%d: assertion failed: (%s)[%u] == (%s)[%u]: "
              "%s == %s", file, line, expected_desc, i,
              actual_desc, i, expected[i], actual[i]);
        }
    }
}

void
_tp_tests_assert_bytes_equal (const gchar *file, int line,
  GBytes *actual, gconstpointer expected_data,
  gsize expected_length)
{
  if (expected_length != g_bytes_get_size (actual))
    {
      g_error ("%s:%d: assertion failed: expected %"G_GSIZE_FORMAT
         " bytes, got %"G_GSIZE_FORMAT,
        file, line, expected_length, g_bytes_get_size (actual));
    }
  else if (memcmp (g_bytes_get_data (actual, NULL),
      expected_data, expected_length) != 0)
    {
      g_error (
        "%s:%d: assertion failed: expected data didn't match the actual data",
        file, line);
    }
}

void
tp_tests_create_conn (GType conn_type,
    const gchar *account,
    gboolean connect,
    TpBaseConnection **service_conn,
    TpConnection **client_conn)
{
  TpDBusDaemon *dbus;
  gchar *name;
  gchar *conn_path;
  GError *error = NULL;

  g_assert (service_conn != NULL);
  g_assert (client_conn != NULL);

  dbus = tp_tests_dbus_daemon_dup_or_die ();

  *service_conn = tp_tests_object_new_static_class (
        conn_type,
        "account", account,
        "protocol", "simple",
        NULL);
  g_assert (*service_conn != NULL);

  g_assert (tp_base_connection_register (*service_conn, "simple",
        &name, &conn_path, &error));
  g_assert_no_error (error);

  *client_conn = tp_tests_connection_new (dbus, NULL, conn_path, &error);
  g_assert (*client_conn != NULL);
  g_assert_no_error (error);

  if (connect)
    {
      GQuark conn_features[] = { TP_CONNECTION_FEATURE_CONNECTED, 0 };

      tp_cli_connection_call_connect (*client_conn, -1, NULL, NULL, NULL, NULL);
      tp_tests_proxy_run_until_prepared (*client_conn, conn_features);
    }

  g_free (name);
  g_free (conn_path);

  g_object_unref (dbus);
}

void
tp_tests_create_and_connect_conn (GType conn_type,
    const gchar *account,
    TpBaseConnection **service_conn,
    TpConnection **client_conn)
{
  tp_tests_create_conn (conn_type, account, TRUE, service_conn, client_conn);
}

/* This object exists solely so that tests/tests.supp can ignore "leaked"
 * classes. */
gpointer
tp_tests_object_new_static_class (GType type,
    ...)
{
  va_list ap;
  GObject *object;
  const gchar *first_property;

  va_start (ap, type);
  first_property = va_arg (ap, const gchar *);
  object = g_object_new_valist (type, first_property, ap);
  va_end (ap);
  return object;
}

static gboolean
time_out (gpointer nil G_GNUC_UNUSED)
{
  g_error ("Timed out");
  g_assert_not_reached ();
  return FALSE;
}

void
tp_tests_abort_after (guint sec)
{
  gboolean debugger = FALSE;
  gchar *contents;

  if (g_file_get_contents ("/proc/self/status", &contents, NULL, NULL))
    {
/* http://www.youtube.com/watch?v=SXmv8quf_xM */
#define TRACER_T "\nTracerPid:\t"
      gchar *line = strstr (contents, TRACER_T);

      if (line != NULL)
        {
          gchar *value = line + strlen (TRACER_T);

          if (value[0] != '0' || value[1] != '\n')
            debugger = TRUE;
        }

      g_free (contents);
    }

  if (g_getenv ("TP_TESTS_NO_TIMEOUT") != NULL || debugger)
    return;

  g_timeout_add_seconds (sec, time_out, NULL);

#ifdef G_OS_UNIX
  /* On Unix, we can kill the process more reliably; this is a safety-catch
   * in case it deadlocks or something, in which case the main loop won't be
   * processed. The default handler for SIGALRM is process termination. */
  alarm (sec + 2);
#endif
}

void
tp_tests_init (int *argc,
    char ***argv)
{
  g_type_init ();
  tp_tests_abort_after (10);
  tp_debug_set_flags ("all");

  g_test_init (argc, argv, NULL);
}

void
_tp_destroy_socket_control_list (gpointer data)
{
  GArray *tab = data;
  g_array_unref (tab);
}

GValue *
_tp_create_local_socket (TpSocketAddressType address_type,
    TpSocketAccessControl access_control,
    GSocketService **service,
    gchar **unix_address,
    gchar **unix_tmpdir,
    GError **error)
{
  gboolean success;
  GSocketAddress *address, *effective_address;
  GValue *address_gvalue;

  g_assert (service != NULL);
  g_assert (unix_address != NULL);

  switch (access_control)
    {
      case TP_SOCKET_ACCESS_CONTROL_LOCALHOST:
      case TP_SOCKET_ACCESS_CONTROL_CREDENTIALS:
      case TP_SOCKET_ACCESS_CONTROL_PORT:
        break;

      default:
        g_assert_not_reached ();
    }

  switch (address_type)
    {
#ifdef HAVE_GIO_UNIX
      case TP_SOCKET_ADDRESS_TYPE_UNIX:
        {
          GError *e = NULL;
          gchar *dir = g_dir_make_tmp ("tp-glib-tests.XXXXXX", &e);
          gchar *name;

          g_assert_no_error (e);

          name = g_build_filename (dir, "s", NULL);
          address = g_unix_socket_address_new (name);
          g_free (name);

          if (unix_tmpdir != NULL)
            *unix_tmpdir = dir;
          else
            g_free (dir);
          break;
        }
#endif

      case TP_SOCKET_ADDRESS_TYPE_IPV4:
      case TP_SOCKET_ADDRESS_TYPE_IPV6:
        {
          GInetAddress *localhost;

          localhost = g_inet_address_new_loopback (
              address_type == TP_SOCKET_ADDRESS_TYPE_IPV4 ?
              G_SOCKET_FAMILY_IPV4 : G_SOCKET_FAMILY_IPV6);
          address = g_inet_socket_address_new (localhost, 0);

          g_object_unref (localhost);
          break;
        }

      default:
        g_assert_not_reached ();
    }

  *service = g_socket_service_new ();

  success = g_socket_listener_add_address (
      G_SOCKET_LISTENER (*service),
      address, G_SOCKET_TYPE_STREAM,
      G_SOCKET_PROTOCOL_DEFAULT,
      NULL, &effective_address, NULL);
  g_assert (success);

  switch (address_type)
    {
#ifdef HAVE_GIO_UNIX
      case TP_SOCKET_ADDRESS_TYPE_UNIX:
        *unix_address = g_strdup (g_unix_socket_address_get_path (
              G_UNIX_SOCKET_ADDRESS (effective_address)));
        address_gvalue =  tp_g_value_slice_new_bytes (
            g_unix_socket_address_get_path_len (
              G_UNIX_SOCKET_ADDRESS (effective_address)),
            g_unix_socket_address_get_path (
              G_UNIX_SOCKET_ADDRESS (effective_address)));
        break;
#endif

      case TP_SOCKET_ADDRESS_TYPE_IPV4:
      case TP_SOCKET_ADDRESS_TYPE_IPV6:
        *unix_address = NULL;

        address_gvalue = tp_g_value_slice_new_take_boxed (
            TP_STRUCT_TYPE_SOCKET_ADDRESS_IPV4,
            dbus_g_type_specialized_construct (
              TP_STRUCT_TYPE_SOCKET_ADDRESS_IPV4));

        dbus_g_type_struct_set (address_gvalue,
            0, address_type == TP_SOCKET_ADDRESS_TYPE_IPV4 ?
              "127.0.0.1" : "::1",
            1, g_inet_socket_address_get_port (
              G_INET_SOCKET_ADDRESS (effective_address)),
            G_MAXUINT);
        break;

      default:
        g_assert_not_reached ();
    }

  g_object_unref (address);
  g_object_unref (effective_address);
  return address_gvalue;
}

void
tp_tests_connection_assert_disconnect_succeeds (TpConnection *connection)
{
  GAsyncResult *result = NULL;
  GError *error = NULL;
  gboolean ok;

  tp_connection_disconnect_async (connection, tp_tests_result_ready_cb,
      &result);
  tp_tests_run_until_result (&result);
  ok = tp_connection_disconnect_finish (connection, result, &error);
  g_assert_no_error (error);
  g_assert (ok);
  g_object_unref (result);
}

static void
one_contact_cb (GObject *object,
    GAsyncResult *result,
    gpointer user_data)
{
  TpConnection *connection = (TpConnection *) object;
  TpContact **contact_loc = user_data;
  GError *error = NULL;

  *contact_loc = tp_connection_dup_contact_by_id_finish (connection, result,
      &error);

  g_assert_no_error (error);
  g_assert (TP_IS_CONTACT (*contact_loc));
}

TpContact *
tp_tests_connection_run_until_contact_by_id (TpConnection *connection,
    const gchar *id,
    const GQuark *features)
{
  TpContact *contact = NULL;

  tp_connection_dup_contact_by_id_async (connection, id, features,
      one_contact_cb, &contact);

  while (contact == NULL)
    g_main_context_iteration (NULL, TRUE);

  return contact;
}

void
tp_tests_channel_assert_expect_members (TpChannel *channel,
    TpIntset *expected_members)
{
  GPtrArray *contacts;
  TpIntset *members;
  guint i;

  members = tp_intset_new ();
  contacts = tp_channel_group_dup_members (channel);
  if (contacts != NULL)
    {
      for (i = 0; i < contacts->len; i++)
        {
          TpContact *contact = g_ptr_array_index (contacts, i);
          tp_intset_add (members, tp_contact_get_handle (contact));
        }
    }

  g_assert (tp_intset_is_equal (members, expected_members));

  g_ptr_array_unref (contacts);
  tp_intset_destroy (members);
}

TpConnection *
tp_tests_connection_new (TpDBusDaemon *dbus,
    const gchar *bus_name,
    const gchar *object_path,
    GError **error)
{
  TpClientFactory *factory;
  gchar *dup_path = NULL;
  TpConnection *ret = NULL;

  g_return_val_if_fail (TP_IS_DBUS_DAEMON (dbus), NULL);
  g_return_val_if_fail (object_path != NULL ||
                        (bus_name != NULL && bus_name[0] != ':'), NULL);

  if (object_path == NULL)
    {
      dup_path = g_strdelimit (g_strdup_printf ("/%s", bus_name), ".", '/');
      object_path = dup_path;
    }

  if (!tp_dbus_check_valid_object_path (object_path, error))
    goto finally;

  factory = tp_automatic_client_factory_new (dbus);
  ret = tp_client_factory_ensure_connection (factory,
      object_path, NULL, error);
  g_object_unref (factory);

finally:
  g_free (dup_path);

  return ret;
}

TpAccount *
tp_tests_account_new (TpDBusDaemon *dbus,
    const gchar *object_path,
    GError **error)
{
  TpClientFactory *factory;
  TpAccount *ret;

  if (!tp_dbus_check_valid_object_path (object_path, error))
    return NULL;

  factory = tp_automatic_client_factory_new (dbus);
  ret = tp_client_factory_ensure_account (factory,
      object_path, NULL, error);
  g_object_unref (factory);

  return ret;
}

TpChannel *
tp_tests_channel_new (TpConnection *conn,
    const gchar *object_path,
    const gchar *optional_channel_type,
    TpHandleType optional_handle_type,
    TpHandle optional_handle,
    GError **error)
{
  TpChannel *ret;
  GHashTable *asv;

  asv = tp_asv_new (NULL, NULL);

  if (optional_channel_type != NULL)
    {
      tp_asv_set_string (asv,
          TP_PROP_CHANNEL_CHANNEL_TYPE, optional_channel_type);
    }
  if (optional_handle_type != TP_HANDLE_TYPE_NONE)
    {
      tp_asv_set_uint32 (asv,
          TP_PROP_CHANNEL_TARGET_HANDLE_TYPE, optional_handle_type);
    }
  if (optional_handle != 0)
    {
      tp_asv_set_uint32 (asv,
          TP_PROP_CHANNEL_TARGET_HANDLE, optional_handle);
    }

  ret = tp_tests_channel_new_from_properties (conn, object_path, asv, error);

  g_hash_table_unref (asv);

  return ret;
}

TpChannel *
tp_tests_channel_new_from_properties (TpConnection *conn,
    const gchar *object_path,
    const GHashTable *immutable_properties,
    GError **error)
{
  TpClientFactory *factory;

  if (!tp_dbus_check_valid_object_path (object_path, error))
    return NULL;

  factory = tp_proxy_get_factory (conn);
  return tp_client_factory_ensure_channel (factory, conn,
      object_path, immutable_properties, error);
}

void
tp_tests_add_channel_to_ptr_array (GPtrArray *arr,
    TpChannel *channel)
{
  GValueArray *tmp;
  GVariant *variant;
  GValue v = G_VALUE_INIT;
  GHashTable *asv;

  g_assert (arr != NULL);
  g_assert (channel != NULL);

  variant = tp_channel_dup_immutable_properties (channel);
  dbus_g_value_parse_g_variant (variant, &v);
  asv = g_value_get_boxed (&v);

  tmp = tp_value_array_build (2,
      DBUS_TYPE_G_OBJECT_PATH, tp_proxy_get_object_path (channel),
      TP_HASH_TYPE_STRING_VARIANT_MAP, asv,
      G_TYPE_INVALID);

  g_ptr_array_add (arr, tmp);
  g_variant_unref (variant);
  g_value_unset (&v);
}

