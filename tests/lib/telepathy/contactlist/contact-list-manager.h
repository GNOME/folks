/*
 * Example channel manager for contact lists
 *
 * Copyright © 2007-2009 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright © 2007-2009 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TEST_CONTACT_LIST_MANAGER_H__
#define __TP_TEST_CONTACT_LIST_MANAGER_H__

#include <glib-object.h>

#include <telepathy-glib/channel-manager.h>
#include <telepathy-glib/handle.h>
#include <telepathy-glib/presence-mixin.h>

G_BEGIN_DECLS

typedef struct _TpTestContactListManager TpTestContactListManager;
typedef struct _TpTestContactListManagerClass TpTestContactListManagerClass;
typedef struct _TpTestContactListManagerPrivate TpTestContactListManagerPrivate;

struct _TpTestContactListManagerClass {
    GObjectClass parent_class;
};

struct _TpTestContactListManager {
    GObject parent;

    TpTestContactListManagerPrivate *priv;
};

GType tp_test_contact_list_manager_get_type (void);

#define TP_TEST_TYPE_CONTACT_LIST_MANAGER \
  (tp_test_contact_list_manager_get_type ())
#define TP_TEST_CONTACT_LIST_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TEST_TYPE_CONTACT_LIST_MANAGER, \
                              TpTestContactListManager))
#define TP_TEST_CONTACT_LIST_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TEST_TYPE_CONTACT_LIST_MANAGER, \
                           TpTestContactListManagerClass))
#define TP_TEST_IS_CONTACT_LIST_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TEST_TYPE_CONTACT_LIST_MANAGER))
#define TP_TEST_IS_CONTACT_LIST_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TEST_TYPE_CONTACT_LIST_MANAGER))
#define TP_TEST_CONTACT_LIST_MANAGER_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TEST_TYPE_CONTACT_LIST_MANAGER, \
                              TpTestContactListManagerClass))

gboolean tp_test_contact_list_manager_add_to_group (
    TpTestContactListManager *self, GObject *channel,
    TpHandle group, TpHandle member, const gchar *message, GError **error);

gboolean tp_test_contact_list_manager_remove_from_group (
    TpTestContactListManager *self, GObject *channel,
    TpHandle group, TpHandle member, const gchar *message, GError **error);

/* elements 1, 2... of this enum must be kept in sync with elements 0, 1...
 * of the array _contact_lists in contact-list-manager.h */
typedef enum {
    INVALID_TP_TEST_CONTACT_LIST,
    TP_TEST_CONTACT_LIST_SUBSCRIBE = 1,
    TP_TEST_CONTACT_LIST_PUBLISH,
    TP_TEST_CONTACT_LIST_STORED
} TpTestContactListHandle;

#define NUM_TP_TEST_CONTACT_LISTS TP_TEST_CONTACT_LIST_STORED + 1

/* this enum must be kept in sync with the array _statuses in
 * contact-list-manager.c */
typedef enum {
    TP_TEST_CONTACT_LIST_PRESENCE_OFFLINE = 0,
    TP_TEST_CONTACT_LIST_PRESENCE_UNKNOWN,
    TP_TEST_CONTACT_LIST_PRESENCE_ERROR,
    TP_TEST_CONTACT_LIST_PRESENCE_AWAY,
    TP_TEST_CONTACT_LIST_PRESENCE_AVAILABLE
} TpTestContactListPresence;

const TpPresenceStatusSpec *tp_test_contact_list_presence_statuses (
    void);

gboolean tp_test_contact_list_manager_add_to_list (
    TpTestContactListManager *self, GObject *channel,
    TpTestContactListHandle list, TpHandle member, const gchar *message,
    GError **error);

gboolean tp_test_contact_list_manager_remove_from_list (
    TpTestContactListManager *self, GObject *channel,
    TpTestContactListHandle list, TpHandle member, const gchar *message,
    GError **error);

const gchar **tp_test_contact_lists (void);

TpTestContactListPresence tp_test_contact_list_manager_get_presence (
    TpTestContactListManager *self, TpHandle contact);
const gchar *tp_test_contact_list_manager_get_alias (
    TpTestContactListManager *self, TpHandle contact);
void tp_test_contact_list_manager_set_alias (
    TpTestContactListManager *self, TpHandle contact, const gchar *alias);

G_END_DECLS

#endif
