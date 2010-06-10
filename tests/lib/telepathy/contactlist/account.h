/*
 * account.h - header for a simple account service.
 *
 * Copyright (C) 2010 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 *
 * Copied from telepathy-glib/tests/lib/simple-account.h.
 */

#ifndef __TP_TEST_ACCOUNT_H__
#define __TP_TEST_ACCOUNT_H__

#include <glib-object.h>
#include <telepathy-glib/dbus-properties-mixin.h>


G_BEGIN_DECLS

typedef struct _TpTestAccount TpTestAccount;
typedef struct _TpTestAccountClass TpTestAccountClass;
typedef struct _TpTestAccountPrivate TpTestAccountPrivate;

struct _TpTestAccountClass {
    GObjectClass parent_class;
    TpDBusPropertiesMixinClass dbus_props_class;
};

struct _TpTestAccount {
    GObject parent;

    TpTestAccountPrivate *priv;
};

GType tp_test_account_get_type (void);

/* TYPE MACROS */
#define TP_TEST_TYPE_ACCOUNT \
  (tp_test_account_get_type ())
#define TP_TEST_ACCOUNT(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TEST_TYPE_ACCOUNT, \
                              TpTestAccount))
#define TP_TEST_ACCOUNT_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TEST_TYPE_ACCOUNT, \
                           TpTestAccountClass))
#define TP_TEST_IS_ACCOUNT(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TEST_TYPE_ACCOUNT))
#define TP_TEST_IS_ACCOUNT_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TEST_TYPE_ACCOUNT))
#define TP_TEST_ACCOUNT_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TEST_TYPE_ACCOUNT, \
                              TpTestAccountClass))

TpTestAccount *tp_test_account_new (const gchar *connection_path);

G_END_DECLS

#endif /* #ifndef __TP_TEST_ACCOUNT_H__ */
