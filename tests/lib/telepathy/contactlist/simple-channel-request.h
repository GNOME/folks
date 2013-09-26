/*
 * simple-channel-request.h - header for a simple channel request service.
 *
 * Copyright © 2010 Collabora Ltd.
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_SIMPLE_CHANNEL_REQUEST_H__
#define __TP_TESTS_SIMPLE_CHANNEL_REQUEST_H__

#include <glib-object.h>

#include <telepathy-glib/telepathy-glib.h>

#include "simple-conn.h"

G_BEGIN_DECLS

typedef struct _TpTestsSimpleChannelRequest TpTestsSimpleChannelRequest;
typedef struct _TpTestsSimpleChannelRequestClass TpTestsSimpleChannelRequestClass;
typedef struct _TpTestsSimpleChannelRequestPrivate TpTestsSimpleChannelRequestPrivate;

struct _TpTestsSimpleChannelRequestClass {
    GObjectClass parent_class;
    TpDBusPropertiesMixinClass dbus_props_class;
};

struct _TpTestsSimpleChannelRequest {
    GObject parent;

    TpTestsSimpleChannelRequestPrivate *priv;
};

GType tp_tests_simple_channel_request_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_SIMPLE_CHANNEL_REQUEST \
  (tp_tests_simple_channel_request_get_type ())
#define SIMPLE_CHANNEL_REQUEST(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_REQUEST, \
                              TpTestsSimpleChannelRequest))
#define SIMPLE_CHANNEL_REQUEST_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_SIMPLE_CHANNEL_REQUEST, \
                           TpTestsSimpleChannelRequestClass))
#define SIMPLE_IS_CHANNEL_REQUEST(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_REQUEST))
#define SIMPLE_IS_CHANNEL_REQUEST_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_SIMPLE_CHANNEL_REQUEST))
#define SIMPLE_CHANNEL_REQUEST_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_REQUEST, \
                              TpTestsSimpleChannelRequestClass))

TpTestsSimpleChannelRequest *
tp_tests_simple_channel_request_new (const gchar *path,
    TpTestsSimpleConnection *conn,
    const gchar *account_path,
    gint64 user_action_time,
    const gchar *preferred_handler,
    GPtrArray *requests,
    GHashTable *hints);

GHashTable * tp_tests_simple_channel_request_dup_immutable_props (
    TpTestsSimpleChannelRequest *self);

G_END_DECLS

#endif /* #ifndef __TP_TESTS_SIMPLE_CHANNEL_REQUEST_H__ */
