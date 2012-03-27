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

#ifndef __TP_TESTS_ACCOUNT_MANAGER_H__
#define __TP_TESTS_ACCOUNT_MANAGER_H__

#include <glib-object.h>
#include <telepathy-glib/dbus-properties-mixin.h>


G_BEGIN_DECLS

typedef struct _TpTestsAccountManager TpTestsAccountManager;
typedef struct _TpTestsAccountManagerClass TpTestsAccountManagerClass;
typedef struct _TpTestsAccountManagerPrivate TpTestsAccountManagerPrivate;

struct _TpTestsAccountManagerClass {
    GObjectClass parent_class;
    TpDBusPropertiesMixinClass dbus_props_class;
};

struct _TpTestsAccountManager {
    GObject parent;

    TpTestsAccountManagerPrivate *priv;
};

GType tp_tests_account_manager_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_ACCOUNT_MANAGER \
  (tp_tests_account_manager_get_type ())
#define TP_TESTS_ACCOUNT_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_ACCOUNT_MANAGER, \
                              TpTestsAccountManager))
#define TP_TESTS_ACCOUNT_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_ACCOUNT_MANAGER, \
                           TpTestsAccountManagerClass))
#define IS_TP_TESTS_ACCOUNT_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_ACCOUNT_MANAGER))
#define TP_TESTS_IS_ACCOUNT_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_ACCOUNT_MANAGER))
#define TP_TESTS_ACCOUNT_MANAGER_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_ACCOUNT_MANAGER, \
                              TpTestsAccountManagerClass))

TpTestsAccountManager *tp_tests_account_manager_new (void);

void tp_tests_account_manager_add_account (TpTestsAccountManager *self,
    const gchar *account_path);
void tp_tests_account_manager_remove_account (TpTestsAccountManager *self,
    const gchar *account_path);

G_END_DECLS

#endif /* #ifndef __TP_TESTS_ACCOUNT_MANAGER_H__ */
