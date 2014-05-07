/*
 * my-conn-proxy.c - a simple subclass of TpConnection
 *
 * Copyright (C) 2010-2011 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "my-conn-proxy.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>

G_DEFINE_TYPE  (TpTestsMyConnProxy, tp_tests_my_conn_proxy,
    TP_TYPE_CONNECTION)

static void
tp_tests_my_conn_proxy_init (TpTestsMyConnProxy *self)
{
}

enum {
    FEAT_CORE,
    FEAT_A,
    FEAT_B,
    FEAT_WRONG_IFACE,
    FEAT_BAD_DEP,
    FEAT_FAIL,
    FEAT_FAIL_DEP,
    FEAT_RETRY,
    FEAT_RETRY_DEP,
    FEAT_BEFORE_CONNECTED,
    FEAT_INTERFACE_LATER,
    N_FEAT
};

static void
prepare_core_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  /* superclass core features are prepared first */
  g_assert (tp_proxy_is_prepared (proxy, TP_CONNECTION_FEATURE_CORE));

  result = g_simple_async_result_new ((GObject *) proxy, callback, user_data,
      prepare_core_async);

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static void
prepare_a_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  g_assert (tp_proxy_is_prepared (proxy, TP_TESTS_MY_CONN_PROXY_FEATURE_CORE));

  result = g_simple_async_result_new ((GObject *) proxy, callback, user_data,
      prepare_a_async);

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static void
prepare_b_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  g_assert (tp_proxy_is_prepared (proxy, TP_TESTS_MY_CONN_PROXY_FEATURE_CORE));
  g_assert (tp_proxy_is_prepared (proxy, TP_TESTS_MY_CONN_PROXY_FEATURE_A));

  result = g_simple_async_result_new ((GObject *) proxy, callback, user_data,
      prepare_b_async);

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static void
cannot_be_prepared_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  g_assert_not_reached ();
}

static void
prepare_fail_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  g_assert (tp_proxy_is_prepared (proxy, TP_TESTS_MY_CONN_PROXY_FEATURE_CORE));

  result = g_simple_async_result_new_error ((GObject *) proxy, callback,
      user_data, TP_ERROR, TP_ERROR_NOT_AVAILABLE,
      "No feature for you!");

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static void
prepare_retry_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  TpTestsMyConnProxy *self = (TpTestsMyConnProxy *) proxy;
  GSimpleAsyncResult *result;

  result = g_simple_async_result_new ((GObject *) proxy, callback, user_data,
      prepare_retry_async);

  if (!self->retry_feature_success)
    {
      /* Fail the first time we try to prepare the feature */
      g_simple_async_result_set_error (result, TP_ERROR,
          TP_ERROR_NOT_YET, "Nah");
    }

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static void
prepare_retry_dep_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  g_assert (tp_proxy_is_prepared (proxy, TP_TESTS_MY_CONN_PROXY_FEATURE_CORE));

  result = g_simple_async_result_new ((GObject *) proxy, callback, user_data,
      prepare_retry_dep_async);

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static void
prepare_before_connected_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  TpTestsMyConnProxy *self = (TpTestsMyConnProxy *) proxy;
  GSimpleAsyncResult *result;

  g_assert (tp_proxy_is_prepared (proxy, TP_TESTS_MY_CONN_PROXY_FEATURE_CORE));

  result = g_simple_async_result_new ((GObject *) proxy, callback, user_data,
      prepare_before_connected_async);

  if (tp_connection_get_status (TP_CONNECTION (self), NULL) ==
        TP_CONNECTION_STATUS_CONNECTED)
    self->before_connected_state = BEFORE_CONNECTED_STATE_CONNECTED;
  else
    self->before_connected_state = BEFORE_CONNECTED_STATE_NOT_CONNECTED;

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static void
prepare_before_connected_before_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  TpTestsMyConnProxy *self = (TpTestsMyConnProxy *) proxy;
  GSimpleAsyncResult *result;

  g_assert (tp_proxy_is_prepared (proxy, TP_TESTS_MY_CONN_PROXY_FEATURE_CORE));

  g_assert_cmpuint (tp_connection_get_status (TP_CONNECTION (proxy), NULL), ==,
      TP_CONNECTION_STATUS_CONNECTING);

  result = g_simple_async_result_new ((GObject *) proxy, callback, user_data,
      prepare_before_connected_before_async);

  self->before_connected_state = BEFORE_CONNECTED_STATE_CONNECTED;

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static void
prepare_interface_later_async (TpProxy *proxy,
    const TpProxyFeature *feature,
    GAsyncReadyCallback callback,
    gpointer user_data)
{
  GSimpleAsyncResult *result;

  result = g_simple_async_result_new ((GObject *) proxy, callback, user_data,
      prepare_interface_later_async);

  g_simple_async_result_complete_in_idle (result);
  g_object_unref (result);
}

static const TpProxyFeature *
list_features (TpProxyClass *cls G_GNUC_UNUSED)
{
  static TpProxyFeature features[N_FEAT + 1] = { { 0 } };
  static GQuark need_a[2] = {0, 0};
  static GQuark need_channel_core[2] = {0, 0};
  static GQuark need_wrong_iface[2] = {0, 0};
  static GQuark need_fail[2] = {0, 0};
  static GQuark need_retry[2] = {0, 0};
  static GQuark need_iface_later[2] = {0, 0};

  if (G_LIKELY (features[0].name != 0))
    return features;

  features[FEAT_CORE].name = TP_TESTS_MY_CONN_PROXY_FEATURE_CORE;
  features[FEAT_CORE].core = TRUE;
  features[FEAT_CORE].prepare_async = prepare_core_async;

  features[FEAT_A].name = TP_TESTS_MY_CONN_PROXY_FEATURE_A;
  features[FEAT_A].prepare_async = prepare_a_async;

  features[FEAT_B].name = TP_TESTS_MY_CONN_PROXY_FEATURE_B;
  features[FEAT_B].prepare_async = prepare_b_async;
  need_a[0] = TP_TESTS_MY_CONN_PROXY_FEATURE_A;
  features[FEAT_B].depends_on = need_a;

  features[FEAT_WRONG_IFACE].name = TP_TESTS_MY_CONN_PROXY_FEATURE_WRONG_IFACE;
  features[FEAT_WRONG_IFACE].prepare_async = cannot_be_prepared_async;
  need_channel_core[0] = TP_CHANNEL_FEATURE_CORE;
  features[FEAT_WRONG_IFACE].interfaces_needed = need_channel_core;

  features[FEAT_BAD_DEP].name = TP_TESTS_MY_CONN_PROXY_FEATURE_BAD_DEP;
  features[FEAT_BAD_DEP].prepare_async = cannot_be_prepared_async;
  need_wrong_iface[0] = TP_TESTS_MY_CONN_PROXY_FEATURE_WRONG_IFACE;
  features[FEAT_BAD_DEP].depends_on = need_wrong_iface;

  features[FEAT_FAIL].name = TP_TESTS_MY_CONN_PROXY_FEATURE_FAIL;
  features[FEAT_FAIL].prepare_async = prepare_fail_async;

  features[FEAT_FAIL_DEP].name = TP_TESTS_MY_CONN_PROXY_FEATURE_FAIL_DEP;
  features[FEAT_FAIL_DEP].prepare_async = cannot_be_prepared_async;
  need_fail[0] = TP_TESTS_MY_CONN_PROXY_FEATURE_FAIL;
  features[FEAT_FAIL_DEP].depends_on = need_fail;

  features[FEAT_RETRY].name = TP_TESTS_MY_CONN_PROXY_FEATURE_RETRY;
  features[FEAT_RETRY].prepare_async = prepare_retry_async;
  features[FEAT_RETRY].can_retry = TRUE;

  features[FEAT_RETRY_DEP].name = TP_TESTS_MY_CONN_PROXY_FEATURE_RETRY_DEP;
  need_retry[0] = TP_TESTS_MY_CONN_PROXY_FEATURE_RETRY;
  features[FEAT_RETRY_DEP].prepare_async = prepare_retry_dep_async;
  features[FEAT_RETRY_DEP].depends_on = need_retry;

  features[FEAT_BEFORE_CONNECTED].name =
    TP_TESTS_MY_CONN_PROXY_FEATURE_BEFORE_CONNECTED;
  features[FEAT_BEFORE_CONNECTED].prepare_async =
    prepare_before_connected_async;
  features[FEAT_BEFORE_CONNECTED].prepare_before_signalling_connected_async =
    prepare_before_connected_before_async;

  features[FEAT_INTERFACE_LATER].name =
    TP_TESTS_MY_CONN_PROXY_FEATURE_INTERFACE_LATER;
  features[FEAT_INTERFACE_LATER].prepare_async = prepare_interface_later_async;
  need_iface_later[0] = g_quark_from_static_string (
      TP_TESTS_MY_CONN_PROXY_IFACE_LATER);
  features[FEAT_INTERFACE_LATER].interfaces_needed = need_iface_later;

  return features;
}

static void
tp_tests_my_conn_proxy_class_init (TpTestsMyConnProxyClass *klass)
{
  TpProxyClass *proxy_class = (TpProxyClass *) klass;

  proxy_class->list_features = list_features;
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_core (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-core");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_a (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-a");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_b (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-b");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_wrong_iface (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-wrong_iface");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_bad_dep (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-bad-dep");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_fail (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-fail");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_fail_dep (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-fail-dep");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_retry (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-retry");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_retry_dep (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-retry-dep");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_before_connected (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-before-connected");
}

GQuark
tp_tests_my_conn_proxy_get_feature_quark_interface_later (void)
{
  return g_quark_from_static_string ("tp-my-conn-proxy-feature-interface-later");
}
