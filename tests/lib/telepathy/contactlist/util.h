/* Simple utility code used by the regression tests.
 *
 * Copyright © 2008-2010 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright © 2008 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_LIB_UTIL_H__
#define __TP_TESTS_LIB_UTIL_H__

#include <telepathy-glib/telepathy-glib.h>

TpDBusDaemon *tp_tests_dbus_daemon_dup_or_die (void);

void tp_tests_proxy_run_until_dbus_queue_processed (gpointer proxy);

void tp_tests_proxy_run_until_prepared (gpointer proxy,
    const GQuark *features);
gboolean tp_tests_proxy_run_until_prepared_or_failed (gpointer proxy,
    const GQuark *features,
    GError **error);

#define test_assert_empty_strv(strv) \
  _test_assert_empty_strv (__FILE__, __LINE__, strv)
void _test_assert_empty_strv (const char *file, int line, gconstpointer strv);

#define tp_tests_assert_strv_equals(actual, expected) \
  _tp_tests_assert_strv_equals (__FILE__, __LINE__, \
      #actual, actual, \
      #expected, expected)
void _tp_tests_assert_strv_equals (const char *file, int line,
  const char *actual_desc, gconstpointer actual_strv,
  const char *expected_desc, gconstpointer expected_strv);

#define tp_tests_assert_bytes_equals(actual, expected, expected_length) \
  _tp_tests_assert_bytes_equal (__FILE__, __LINE__, \
      actual, expected, expected_length)
void _tp_tests_assert_bytes_equal (const gchar *file, int line,
  GBytes *actual, gconstpointer expected_data, gsize expected_length);

void tp_tests_create_conn (GType conn_type,
    const gchar *account,
    gboolean connect,
    TpBaseConnection **service_conn,
    TpConnection **client_conn);

void tp_tests_create_and_connect_conn (GType conn_type,
    const gchar *account,
    TpBaseConnection **service_conn,
    TpConnection **client_conn);

gpointer tp_tests_object_new_static_class (GType type,
    ...) G_GNUC_NULL_TERMINATED;

void tp_tests_run_until_result (GAsyncResult **result);
void tp_tests_result_ready_cb (GObject *object,
    GAsyncResult *res, gpointer user_data);

void tp_tests_abort_after (guint sec);

void tp_tests_init (int *argc,
    char ***argv);

GValue *_tp_create_local_socket (TpSocketAddressType address_type,
    TpSocketAccessControl access_control,
    GSocketService **service,
    gchar **unix_address,
    gchar **unix_tmpdir,
    GError **error);

void _tp_destroy_socket_control_list (gpointer data);

void tp_tests_connection_assert_disconnect_succeeds (TpConnection *connection);

TpContact *tp_tests_connection_run_until_contact_by_id (
    TpConnection *connection,
    const gchar *id,
    const GQuark *features);

void tp_tests_channel_assert_expect_members (TpChannel *channel,
    TpIntset *expected_members);

TpConnection *tp_tests_connection_new (TpDBusDaemon *dbus,
    const gchar *bus_name,
    const gchar *object_path,
    GError **error);

TpAccount *tp_tests_account_new (TpDBusDaemon *dbus,
    const gchar *object_path,
    GError **error);

TpChannel *tp_tests_channel_new (TpConnection *conn,
    const gchar *object_path,
    const gchar *optional_channel_type,
    TpHandleType optional_handle_type,
    TpHandle optional_handle,
    GError **error);

TpChannel *tp_tests_channel_new_from_properties (TpConnection *conn,
    const gchar *object_path,
    const GHashTable *immutable_properties,
    GError **error);

void tp_tests_add_channel_to_ptr_array (GPtrArray *arr,
    TpChannel *channel);

#endif /* #ifndef __TP_TESTS_LIB_UTIL_H__ */
