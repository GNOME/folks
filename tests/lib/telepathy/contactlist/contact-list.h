/*
 * TpTest ContactList channels with handle type LIST or GROUP
 *
 * Copyright © 2009 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright © 2009 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef TP_TESTS_CONTACT_LIST_H
#define TP_TESTS_CONTACT_LIST_H

#include <glib-object.h>

#include <telepathy-glib/base-connection.h>
#include <telepathy-glib/group-mixin.h>

G_BEGIN_DECLS

typedef struct _TpTestsContactListBase TpTestsContactListBase;
typedef struct _TpTestsContactListBaseClass TpTestsContactListBaseClass;
typedef struct _TpTestsContactListBasePrivate TpTestsContactListBasePrivate;

typedef struct _TpTestsContactList TpTestsContactList;
typedef struct _TpTestsContactListClass TpTestsContactListClass;
typedef struct _TpTestsContactListPrivate TpTestsContactListPrivate;

typedef struct _TpTestsContactGroup TpTestsContactGroup;
typedef struct _TpTestsContactGroupClass TpTestsContactGroupClass;
typedef struct _TpTestsContactGroupPrivate TpTestsContactGroupPrivate;

GType tp_tests_contact_list_base_get_type (void);
GType tp_tests_contact_list_get_type (void);
GType tp_tests_contact_group_get_type (void);

#define TP_TESTS_TYPE_CONTACT_LIST_BASE \
  (tp_tests_contact_list_base_get_type ())
#define TP_TESTS_CONTACT_LIST_BASE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TESTS_TYPE_CONTACT_LIST_BASE, \
                               TpTestsContactListBase))
#define TP_TESTS_CONTACT_LIST_BASE_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TESTS_TYPE_CONTACT_LIST_BASE, \
                            TpTestsContactListBaseClass))
#define TP_TESTS_IS_CONTACT_LIST_BASE(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TESTS_TYPE_CONTACT_LIST_BASE))
#define TP_TESTS_IS_CONTACT_LIST_BASE_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TESTS_TYPE_CONTACT_LIST_BASE))
#define TP_TESTS_CONTACT_LIST_BASE_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_CONTACT_LIST_BASE, \
                              TpTestsContactListBaseClass))

#define TP_TESTS_TYPE_CONTACT_LIST \
  (tp_tests_contact_list_get_type ())
#define TP_TESTS_CONTACT_LIST(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TESTS_TYPE_CONTACT_LIST, \
                               TpTestsContactList))
#define TP_TESTS_CONTACT_LIST_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TESTS_TYPE_CONTACT_LIST, \
                            TpTestsContactListClass))
#define TP_TESTS_IS_CONTACT_LIST(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TESTS_TYPE_CONTACT_LIST))
#define TP_TESTS_IS_CONTACT_LIST_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TESTS_TYPE_CONTACT_LIST))
#define TP_TESTS_CONTACT_LIST_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_CONTACT_LIST, \
                              TpTestsContactListClass))

#define TP_TESTS_TYPE_CONTACT_GROUP \
  (tp_tests_contact_group_get_type ())
#define TP_TESTS_CONTACT_GROUP(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TESTS_TYPE_CONTACT_GROUP, \
                               TpTestsContactGroup))
#define TP_TESTS_CONTACT_GROUP_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TESTS_TYPE_CONTACT_GROUP, \
                            TpTestsContactGroupClass))
#define TP_TESTS_IS_CONTACT_GROUP(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TESTS_TYPE_CONTACT_GROUP))
#define TP_TESTS_IS_CONTACT_GROUP_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TESTS_TYPE_CONTACT_GROUP))
#define TP_TESTS_CONTACT_GROUP_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_CONTACT_GROUP, \
                              TpTestsContactGroupClass))

struct _TpTestsContactListBaseClass {
    GObjectClass parent_class;
    TpGroupMixinClass group_class;
    TpDBusPropertiesMixinClass dbus_properties_class;
};

struct _TpTestsContactListClass {
    TpTestsContactListBaseClass parent_class;
};

struct _TpTestsContactGroupClass {
    TpTestsContactListBaseClass parent_class;
};

struct _TpTestsContactListBase {
    GObject parent;
    TpGroupMixin group;
    TpTestsContactListBasePrivate *priv;
};

struct _TpTestsContactList {
    TpTestsContactListBase parent;
    TpTestsContactListPrivate *priv;
};

struct _TpTestsContactGroup {
    TpTestsContactListBase parent;
    TpTestsContactGroupPrivate *priv;
};

G_END_DECLS

#endif
