/*
 * conn.h - header for an example connection
 *
 * Copyright (C) 2007 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_ECHO_CONN_H__
#define __TP_TESTS_ECHO_CONN_H__

#include <glib-object.h>

#include "contacts-conn.h"

G_BEGIN_DECLS

typedef struct _TpTestsEchoConnection TpTestsEchoConnection;
typedef struct _TpTestsEchoConnectionClass TpTestsEchoConnectionClass;
typedef struct _TpTestsEchoConnectionPrivate TpTestsEchoConnectionPrivate;

struct _TpTestsEchoConnectionClass {
    TpTestsContactsConnectionClass parent_class;
};

struct _TpTestsEchoConnection {
    TpTestsContactsConnection parent;

    TpTestsEchoConnectionPrivate *priv;
};

GType tp_tests_echo_connection_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_ECHO_CONNECTION \
  (tp_tests_echo_connection_get_type ())
#define TP_TESTS_ECHO_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_ECHO_CONNECTION, \
                              TpTestsEchoConnection))
#define TP_TESTS_ECHO_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_ECHO_CONNECTION, \
                           TpTestsEchoConnectionClass))
#define TP_TESTS_IS_ECHO_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_ECHO_CONNECTION))
#define TP_TESTS_IS_ECHO_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_ECHO_CONNECTION))
#define TP_TESTS_ECHO_CONNECTION_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_ECHO_CONNECTION, \
                              TpTestsEchoConnectionClass))

G_END_DECLS

#endif
