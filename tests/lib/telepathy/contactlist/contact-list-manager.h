/*
 * Example channel manager for contact lists
 *
 * Copyright © 2007-2010 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright © 2007-2010 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_CONTACT_LIST_MANAGER_H__
#define __TP_TESTS_CONTACT_LIST_MANAGER_H__

#include <telepathy-glib/base-contact-list.h>

G_BEGIN_DECLS

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

typedef struct _TpTestsContactListManager TpTestsContactListManager;
typedef struct _TpTestsContactListManagerClass TpTestsContactListManagerClass;
typedef struct _TpTestsContactListManagerPrivate TpTestsContactListManagerPrivate;

struct _TpTestsContactListManagerClass {
    TpBaseContactListClass parent_class;
};

struct _TpTestsContactListManager {
    TpBaseContactList parent;

    TpTestsContactListManagerPrivate *priv;
};

GType tp_tests_contact_list_manager_get_type (void);

void tp_tests_contact_list_manager_add_to_group (TpTestsContactListManager *self,
    const gchar *group_name, TpHandle member);
void tp_tests_contact_list_manager_remove_from_group (TpTestsContactListManager *self,
    const gchar *group_name, TpHandle member);

void tp_tests_contact_list_manager_request_subscription (TpTestsContactListManager *self,
    guint n_members, TpHandle *members,  const gchar *message);
void tp_tests_contact_list_manager_unsubscribe (TpTestsContactListManager *self,
    guint n_members, TpHandle *members);
void tp_tests_contact_list_manager_authorize_publication (TpTestsContactListManager *self,
    guint n_members, TpHandle *members);
void tp_tests_contact_list_manager_unpublish (TpTestsContactListManager *self,
    guint n_members, TpHandle *members);
void tp_tests_contact_list_manager_remove (TpTestsContactListManager *self,
    guint n_members, TpHandle *members);
void tp_tests_contact_list_manager_add_initial_contacts (TpTestsContactListManager *self,
    guint n_members, TpHandle *members);

G_END_DECLS

#endif
