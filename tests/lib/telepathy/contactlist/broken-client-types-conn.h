/*
 * broken-client-types-conn.h - header for a connection with a broken client
 *   types implementation which inexplicably returns presence information!
 *
 * Copyright © 2011 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef TP_TESTS_BROKEN_CLIENT_TYPES_CONN_H
#define TP_TESTS_BROKEN_CLIENT_TYPES_CONN_H

#include "contacts-conn.h"

typedef struct _TpTestsBrokenClientTypesConnection TpTestsBrokenClientTypesConnection;
typedef struct _TpTestsBrokenClientTypesConnectionClass TpTestsBrokenClientTypesConnectionClass;
typedef struct _TpTestsBrokenClientTypesConnectionPrivate TpTestsBrokenClientTypesConnectionPrivate;

struct _TpTestsBrokenClientTypesConnectionClass {
    TpTestsContactsConnectionClass parent_class;
};

struct _TpTestsBrokenClientTypesConnection {
    TpTestsContactsConnection parent;

    TpTestsBrokenClientTypesConnectionPrivate *priv;
};

GType tp_tests_broken_client_types_connection_get_type (void);

/* HI MUM */
#define TP_TESTS_TYPE_BROKEN_CLIENT_TYPES_CONNECTION \
  (tp_tests_broken_client_types_connection_get_type ())
#define TP_TESTS_BROKEN_CLIENT_TYPES_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_BROKEN_CLIENT_TYPES_CONNECTION, \
                              TpTestsBrokenClientTypesConnection))
#define TP_TESTS_BROKEN_CLIENT_TYPES_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_BROKEN_CLIENT_TYPES_CONNECTION, \
                           TpTestsBrokenClientTypesConnectionClass))
#define TP_TESTS_IS_BROKEN_CLIENT_TYPES_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_BROKEN_CLIENT_TYPES_CONNECTION))
#define TP_TESTS_IS_BROKEN_CLIENT_TYPES_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_BROKEN_CLIENT_TYPES_CONNECTION))
#define TP_TESTS_BROKEN_CLIENT_TYPES_CONNECTION_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_BROKEN_CLIENT_TYPES_CONNECTION, \
                              TpTestsBrokenClientTypesConnectionClass))

#endif // TP_TESTS_BROKEN_CLIENT_TYPES_CONN_H
