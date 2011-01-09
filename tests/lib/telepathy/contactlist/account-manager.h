/*
 * account-manager.h - header for a simple account manager service.
 *
 * Copyright (C) 2007-2009 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007-2008 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 *
 * Copied from telepathy-glib/tests/lib/simple-account-manager.h.
 */

#ifndef __TP_TEST_ACCOUNT_MANAGER_H__
#define __TP_TEST_ACCOUNT_MANAGER_H__

#include <glib-object.h>
#include <telepathy-glib/dbus-properties-mixin.h>


G_BEGIN_DECLS

typedef struct _TpTestAccountManager TpTestAccountManager;
typedef struct _TpTestAccountManagerClass TpTestAccountManagerClass;
typedef struct _TpTestAccountManagerPrivate TpTestAccountManagerPrivate;

struct _TpTestAccountManagerClass {
    GObjectClass parent_class;
    TpDBusPropertiesMixinClass dbus_props_class;
};

struct _TpTestAccountManager {
    GObject parent;

    TpTestAccountManagerPrivate *priv;
};

GType tp_test_account_manager_get_type (void);

/* TYPE MACROS */
#define TP_TEST_TYPE_ACCOUNT_MANAGER \
  (tp_test_account_manager_get_type ())
#define TP_TEST_ACCOUNT_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TEST_TYPE_ACCOUNT_MANAGER, \
                              TpTestAccountManager))
#define TP_TEST_ACCOUNT_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TEST_TYPE_ACCOUNT_MANAGER, \
                           TpTestAccountManagerClass))
#define IS_TP_TEST_ACCOUNT_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TEST_TYPE_ACCOUNT_MANAGER))
#define TP_TEST_IS_ACCOUNT_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TEST_TYPE_ACCOUNT_MANAGER))
#define TP_TEST_ACCOUNT_MANAGER_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TEST_TYPE_ACCOUNT_MANAGER, \
                              TpTestAccountManagerClass))

TpTestAccountManager *tp_test_account_manager_new (void);

void tp_test_account_manager_add_account (TpTestAccountManager *self,
    const gchar *account_path);
void tp_test_account_manager_remove_account (TpTestAccountManager *self,
    const gchar *account_path);

G_END_DECLS

#endif /* #ifndef __TP_TEST_ACCOUNT_MANAGER_H__ */
