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

#ifndef __TP_TESTS_CONTACT_LIST_CONN_H__
#define __TP_TESTS_CONTACT_LIST_CONN_H__

#include <glib-object.h>
#include <telepathy-glib/base-connection.h>
#include <telepathy-glib/contacts-mixin.h>
#include <telepathy-glib/presence-mixin.h>

#include "contact-list-manager.h"

G_BEGIN_DECLS

typedef struct _TpTestsContactListConnection TpTestsContactListConnection;
typedef struct _TpTestsContactListConnectionClass
    TpTestsContactListConnectionClass;
typedef struct _TpTestsContactListConnectionPrivate
    TpTestsContactListConnectionPrivate;

struct _TpTestsContactListConnectionClass {
    TpBaseConnectionClass parent_class;
    TpDBusPropertiesMixinClass properties_class;
    TpPresenceMixinClass presence_mixin;
    TpContactsMixinClass contacts_mixin;
};

struct _TpTestsContactListConnection {
    TpBaseConnection parent;
    TpPresenceMixin presence_mixin;
    TpContactsMixin contacts_mixin;

    TpTestsContactListConnectionPrivate *priv;
};

GType tp_tests_contact_list_connection_get_type (void);

#define TP_TESTS_TYPE_CONTACT_LIST_CONNECTION \
  (tp_tests_contact_list_connection_get_type ())
#define TP_TESTS_CONTACT_LIST_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_CONTACT_LIST_CONNECTION, \
                              TpTestsContactListConnection))
#define TP_TESTS_CONTACT_LIST_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_CONTACT_LIST_CONNECTION, \
                           TpTestsContactListConnectionClass))
#define TP_TESTS_IS_CONTACT_LIST_CONNECTION(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_CONTACT_LIST_CONNECTION))
#define TP_TESTS_IS_CONTACT_LIST_CONNECTION_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_CONTACT_LIST_CONNECTION))
#define TP_TESTS_CONTACT_LIST_CONNECTION_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_CONTACT_LIST_CONNECTION, \
                              TpTestsContactListConnectionClass))

TpTestsContactListManager *tp_tests_contact_list_connection_get_manager (
    TpTestsContactListConnection *self);

gchar *tp_tests_contact_list_normalize_contact (TpHandleRepoIface *repo,
    const gchar *id, gpointer context, GError **error);

TpTestsContactListConnection *tp_tests_contact_list_connection_new (
    const gchar *account, const gchar *protocol,
    TpChannelGroupFlags publish_flags, TpChannelGroupFlags subscribe_flags);

G_END_DECLS

#endif
