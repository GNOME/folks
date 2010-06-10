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

#ifndef TP_TEST_CONTACT_LIST_H
#define TP_TEST_CONTACT_LIST_H

#include <glib-object.h>

#include <telepathy-glib/base-connection.h>
#include <telepathy-glib/group-mixin.h>

G_BEGIN_DECLS

typedef struct _TpTestContactListBase TpTestContactListBase;
typedef struct _TpTestContactListBaseClass TpTestContactListBaseClass;
typedef struct _TpTestContactListBasePrivate TpTestContactListBasePrivate;

typedef struct _TpTestContactList TpTestContactList;
typedef struct _TpTestContactListClass TpTestContactListClass;
typedef struct _TpTestContactListPrivate TpTestContactListPrivate;

typedef struct _TpTestContactGroup TpTestContactGroup;
typedef struct _TpTestContactGroupClass TpTestContactGroupClass;
typedef struct _TpTestContactGroupPrivate TpTestContactGroupPrivate;

GType tp_test_contact_list_base_get_type (void);
GType tp_test_contact_list_get_type (void);
GType tp_test_contact_group_get_type (void);

#define TP_TEST_TYPE_CONTACT_LIST_BASE \
  (tp_test_contact_list_base_get_type ())
#define TP_TEST_CONTACT_LIST_BASE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TEST_TYPE_CONTACT_LIST_BASE, \
                               TpTestContactListBase))
#define TP_TEST_CONTACT_LIST_BASE_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TEST_TYPE_CONTACT_LIST_BASE, \
                            TpTestContactListBaseClass))
#define TP_TEST_IS_CONTACT_LIST_BASE(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TEST_TYPE_CONTACT_LIST_BASE))
#define TP_TEST_IS_CONTACT_LIST_BASE_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TEST_TYPE_CONTACT_LIST_BASE))
#define TP_TEST_CONTACT_LIST_BASE_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TEST_TYPE_CONTACT_LIST_BASE, \
                              TpTestContactListBaseClass))

#define TP_TEST_TYPE_CONTACT_LIST \
  (tp_test_contact_list_get_type ())
#define TP_TEST_CONTACT_LIST(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TEST_TYPE_CONTACT_LIST, \
                               TpTestContactList))
#define TP_TEST_CONTACT_LIST_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TEST_TYPE_CONTACT_LIST, \
                            TpTestContactListClass))
#define TP_TEST_IS_CONTACT_LIST(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TEST_TYPE_CONTACT_LIST))
#define TP_TEST_IS_CONTACT_LIST_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TEST_TYPE_CONTACT_LIST))
#define TP_TEST_CONTACT_LIST_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TEST_TYPE_CONTACT_LIST, \
                              TpTestContactListClass))

#define TP_TEST_TYPE_CONTACT_GROUP \
  (tp_test_contact_group_get_type ())
#define TP_TEST_CONTACT_GROUP(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TEST_TYPE_CONTACT_GROUP, \
                               TpTestContactGroup))
#define TP_TEST_CONTACT_GROUP_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TEST_TYPE_CONTACT_GROUP, \
                            TpTestContactGroupClass))
#define TP_TEST_IS_CONTACT_GROUP(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TEST_TYPE_CONTACT_GROUP))
#define TP_TEST_IS_CONTACT_GROUP_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TEST_TYPE_CONTACT_GROUP))
#define TP_TEST_CONTACT_GROUP_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TEST_TYPE_CONTACT_GROUP, \
                              TpTestContactGroupClass))

struct _TpTestContactListBaseClass {
    GObjectClass parent_class;
    TpGroupMixinClass group_class;
    TpDBusPropertiesMixinClass dbus_properties_class;
};

struct _TpTestContactListClass {
    TpTestContactListBaseClass parent_class;
};

struct _TpTestContactGroupClass {
    TpTestContactListBaseClass parent_class;
};

struct _TpTestContactListBase {
    GObject parent;
    TpGroupMixin group;
    TpTestContactListBasePrivate *priv;
};

struct _TpTestContactList {
    TpTestContactListBase parent;
    TpTestContactListPrivate *priv;
};

struct _TpTestContactGroup {
    TpTestContactListBase parent;
    TpTestContactGroupPrivate *priv;
};

G_END_DECLS

#endif
