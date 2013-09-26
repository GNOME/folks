/*
 * my-conn-proxy.h - header for a simple subclass of TpConnection
 *
 * Copyright (C) 2010 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_MY_CONN_PROXY_H__
#define __TP_TESTS_MY_CONN_PROXY_H__

#include <glib-object.h>
#include <telepathy-glib/telepathy-glib.h>


G_BEGIN_DECLS

typedef struct _TpTestsMyConnProxy TpTestsMyConnProxy;
typedef struct _TpTestsMyConnProxyClass TpTestsMyConnProxyClass;
typedef struct _TpTestsMyConnProxyPrivate TpTestsMyConnProxyPrivate;

struct _TpTestsMyConnProxyClass {
    TpConnectionClass parent_class;
};

typedef enum
{
  BEFORE_CONNECTED_STATE_UNPREPARED = 0,
  BEFORE_CONNECTED_STATE_NOT_CONNECTED,
  BEFORE_CONNECTED_STATE_CONNECTED,
} TpTestsMyConnProxyBeforeConnectedState;


struct _TpTestsMyConnProxy {
    TpConnection parent;

    gboolean retry_feature_success;
    TpTestsMyConnProxyBeforeConnectedState before_connected_state;
};

GType tp_tests_my_conn_proxy_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_MY_CONN_PROXY \
  (tp_tests_my_conn_proxy_get_type ())
#define TP_TESTS_MY_CONN_PROXY(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_MY_CONN_PROXY, \
                              TpTestsMyConnProxy))
#define TP_TESTS_MY_CONN_PROXY_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_MY_CONN_PROXY, \
                           TpTestsMyConnProxyClass))
#define TP_TESTS_SIMPLE_IS_MY_CONN_PROXY(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_MY_CONN_PROXY))
#define TP_TESTS_SIMPLE_IS_MY_CONN_PROXY_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_MY_CONN_PROXY))
#define TP_TESTS_MY_CONN_PROXY_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_MY_CONN_PROXY, \
                              TpTestsMyConnProxyClass))

/* Core feature */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_CORE \
  (tp_tests_my_conn_proxy_get_feature_quark_core ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_core (void) G_GNUC_CONST;

/* No depends */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_A \
  (tp_tests_my_conn_proxy_get_feature_quark_a ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_a (void) G_GNUC_CONST;

/* Depends on A */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_B \
  (tp_tests_my_conn_proxy_get_feature_quark_b ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_b (void) G_GNUC_CONST;

/* Depends on an unimplemented iface */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_WRONG_IFACE \
  (tp_tests_my_conn_proxy_get_feature_quark_wrong_iface ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_wrong_iface (void) G_GNUC_CONST;

/* Depends on WRONG_IFACE */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_BAD_DEP \
  (tp_tests_my_conn_proxy_get_feature_quark_bad_dep ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_bad_dep (void) G_GNUC_CONST;

/* Fail during preparation */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_FAIL \
  (tp_tests_my_conn_proxy_get_feature_quark_fail ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_fail (void) G_GNUC_CONST;

/* Depends on FAIL */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_FAIL_DEP \
  (tp_tests_my_conn_proxy_get_feature_quark_fail_dep ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_fail_dep (void) G_GNUC_CONST;

/* Fail at first attempt but succeed after */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_RETRY \
  (tp_tests_my_conn_proxy_get_feature_quark_retry ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_retry (void) G_GNUC_CONST;

/* Depends on FEATURE_RETRY */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_RETRY_DEP \
  (tp_tests_my_conn_proxy_get_feature_quark_retry_dep ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_retry_dep (void) G_GNUC_CONST;

/* Can be prepared before the connection is connected and block announcing the
 * connected state */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_BEFORE_CONNECTED \
  (tp_tests_my_conn_proxy_get_feature_quark_before_connected ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_before_connected (void) G_GNUC_CONST;

#define TP_TESTS_MY_CONN_PROXY_IFACE_LATER "org.freedesktop.Telepathy.Conncetion.Interface.Test.Later"

/* Need the interface TP_TESTS_MY_CONN_PROXY_IFACE_LATER to be prepared but
 * this interface is not in the initial set of interfaces of the connection.
 * It is added when the connection is connected. */
#define TP_TESTS_MY_CONN_PROXY_FEATURE_INTERFACE_LATER \
  (tp_tests_my_conn_proxy_get_feature_quark_interface_later ())
GQuark tp_tests_my_conn_proxy_get_feature_quark_interface_later (void) G_GNUC_CONST;

G_END_DECLS

#endif /* #ifndef __TP_TESTS_MY_CONN_PROXY_H__ */
