/*
 * bug-19101-conn.h - header for a broken connection to reproduce bug #19101
 *
 * Copyright (C) 2007-2008 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007-2008 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_BUG19101_CONN_H__
#define __TP_TESTS_BUG19101_CONN_H__

#include "contacts-conn.h"

G_BEGIN_DECLS

typedef struct _TpTestsBug19101Connection TpTestsBug19101Connection;
typedef struct _TpTestsBug19101ConnectionClass TpTestsBug19101ConnectionClass;

struct _TpTestsBug19101ConnectionClass {
    TpTestsContactsConnectionClass parent_class;
};

struct _TpTestsBug19101Connection {
    TpTestsContactsConnection parent;
};

GType tp_tests_bug19101_connection_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_BUG19101_CONNECTION \
  (tp_tests_bug19101_connection_get_type ())
#define BUG_19101_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_BUG19101_CONNECTION, \
                              TpTestsBug19101Connection))
#define BUG_19101_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_BUG19101_CONNECTION, \
                           TpTestsBug19101ConnectionClass))
#define BUG_19101_IS_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_BUG19101_CONNECTION))
#define BUG_19101_IS_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_BUG19101_CONNECTION))
#define BUG_19101_CONNECTION_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_BUG19101_CONNECTION, \
                              TpTestsBug19101ConnectionClass))

G_END_DECLS

#endif /* #ifndef __TP_TESTS_BUG19101_CONN_H__ */
