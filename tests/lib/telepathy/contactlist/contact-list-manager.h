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

#ifndef __TP_TESTS_CONTACT_LIST_MANAGER_H__
#define __TP_TESTS_CONTACT_LIST_MANAGER_H__

#include <glib-object.h>

#include <telepathy-glib/channel-manager.h>
#include <telepathy-glib/handle.h>
#include <telepathy-glib/presence-mixin.h>

G_BEGIN_DECLS

typedef struct _TpTestsContactListManager TpTestsContactListManager;
typedef struct _TpTestsContactListManagerClass TpTestsContactListManagerClass;
typedef struct _TpTestsContactListManagerPrivate TpTestsContactListManagerPrivate;

struct _TpTestsContactListManagerClass {
    GObjectClass parent_class;
};

struct _TpTestsContactListManager {
    GObject parent;

    TpTestsContactListManagerPrivate *priv;
};

GType tp_tests_contact_list_manager_get_type (void);

#define TP_TESTS_TYPE_CONTACT_LIST_MANAGER \
  (tp_tests_contact_list_manager_get_type ())
#define TP_TESTS_CONTACT_LIST_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_CONTACT_LIST_MANAGER, \
                              TpTestsContactListManager))
#define TP_TESTS_CONTACT_LIST_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_CONTACT_LIST_MANAGER, \
                           TpTestsContactListManagerClass))
#define TP_TESTS_IS_CONTACT_LIST_MANAGER(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_CONTACT_LIST_MANAGER))
#define TP_TESTS_IS_CONTACT_LIST_MANAGER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_CONTACT_LIST_MANAGER))
#define TP_TESTS_CONTACT_LIST_MANAGER_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_CONTACT_LIST_MANAGER, \
                              TpTestsContactListManagerClass))

gboolean tp_tests_contact_list_manager_add_to_group (
    TpTestsContactListManager *self, GObject *channel,
    TpHandle group, TpHandle member, const gchar *message, GError **error);

gboolean tp_tests_contact_list_manager_remove_from_group (
    TpTestsContactListManager *self, GObject *channel,
    TpHandle group, TpHandle member, const gchar *message, GError **error);

/* elements 1, 2... of this enum must be kept in sync with elements 0, 1...
 * of the array _contact_lists in contact-list-manager.h */
typedef enum {
    INVALID_TP_TESTS_CONTACT_LIST,
    TP_TESTS_CONTACT_LIST_SUBSCRIBE = 1,
    TP_TESTS_CONTACT_LIST_PUBLISH,
    TP_TESTS_CONTACT_LIST_STORED
} TpTestsContactListHandle;

#define NUM_TP_TESTS_CONTACT_LISTS TP_TESTS_CONTACT_LIST_STORED + 1

/* this enum must be kept in sync with the array _statuses in
 * contact-list-manager.c */
typedef enum {
    TP_TESTS_CONTACT_LIST_PRESENCE_OFFLINE = 0,
    TP_TESTS_CONTACT_LIST_PRESENCE_UNKNOWN,
    TP_TESTS_CONTACT_LIST_PRESENCE_ERROR,
    TP_TESTS_CONTACT_LIST_PRESENCE_AWAY,
    TP_TESTS_CONTACT_LIST_PRESENCE_AVAILABLE
} TpTestsContactListPresence;

const TpPresenceStatusSpec *tp_tests_contact_list_presence_statuses (
    void);

gboolean tp_tests_contact_list_manager_add_to_list (
    TpTestsContactListManager *self, GObject *channel,
    TpTestsContactListHandle list, TpHandle member, const gchar *message,
    GError **error);

gboolean tp_tests_contact_list_manager_remove_from_list (
    TpTestsContactListManager *self, GObject *channel,
    TpTestsContactListHandle list, TpHandle member, const gchar *message,
    GError **error);

const gchar **tp_tests_contact_lists (void);

TpTestsContactListPresence tp_tests_contact_list_manager_get_presence (
    TpTestsContactListManager *self, TpHandle contact);
const gchar *tp_tests_contact_list_manager_get_alias (
    TpTestsContactListManager *self, TpHandle contact);
void tp_tests_contact_list_manager_set_alias (
    TpTestsContactListManager *self, TpHandle contact, const gchar *alias);
GPtrArray * tp_tests_contact_list_manager_get_contact_info (
    TpTestsContactListManager *self, TpHandle contact);
void tp_tests_contact_list_manager_set_contact_info (
    TpTestsContactListManager *self, const GPtrArray *contact_info);

G_END_DECLS

#endif
