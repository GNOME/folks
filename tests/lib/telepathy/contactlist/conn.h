/*
 * conn.h - header for an example connection
 *
 * Copyright © 2007-2009 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright © 2007-2009 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TEST_CONTACT_LIST_CONN_H__
#define __TP_TEST_CONTACT_LIST_CONN_H__

#include <glib-object.h>
#include <telepathy-glib/base-connection.h>
#include <telepathy-glib/contacts-mixin.h>
#include <telepathy-glib/presence-mixin.h>

G_BEGIN_DECLS

typedef struct _TpTestContactListConnection TpTestContactListConnection;
typedef struct _TpTestContactListConnectionClass
    TpTestContactListConnectionClass;
typedef struct _TpTestContactListConnectionPrivate
    TpTestContactListConnectionPrivate;

struct _TpTestContactListConnectionClass {
    TpBaseConnectionClass parent_class;
    TpPresenceMixinClass presence_mixin;
    TpContactsMixinClass contacts_mixin;
};

struct _TpTestContactListConnection {
    TpBaseConnection parent;
    TpPresenceMixin presence_mixin;
    TpContactsMixin contacts_mixin;

    TpTestContactListConnectionPrivate *priv;
};

GType tp_test_contact_list_connection_get_type (void);

#define TP_TEST_TYPE_CONTACT_LIST_CONNECTION \
  (tp_test_contact_list_connection_get_type ())
#define TP_TEST_CONTACT_LIST_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TEST_TYPE_CONTACT_LIST_CONNECTION, \
                              TpTestContactListConnection))
#define TP_TEST_CONTACT_LIST_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TEST_TYPE_CONTACT_LIST_CONNECTION, \
                           TpTestContactListConnectionClass))
#define TP_TEST_IS_CONTACT_LIST_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TEST_TYPE_CONTACT_LIST_CONNECTION))
#define TP_TEST_IS_CONTACT_LIST_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TEST_TYPE_CONTACT_LIST_CONNECTION))
#define TP_TEST_CONTACT_LIST_CONNECTION_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TEST_TYPE_CONTACT_LIST_CONNECTION, \
                              TpTestContactListConnectionClass))

gchar *tp_test_contact_list_normalize_contact (TpHandleRepoIface *repo,
    const gchar *id, gpointer context, GError **error);

TpTestContactListConnection *tp_test_contact_list_connection_new (
    const gchar *account, const gchar *protocol);

G_END_DECLS

#endif
