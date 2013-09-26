/*
 * simple-channel-dispatcher.h - header for a simple channel dispatcher service.
 *
 * Copyright © 2010 Collabora Ltd.
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_SIMPLE_CHANNEL_DISPATCHER_H__
#define __TP_TESTS_SIMPLE_CHANNEL_DISPATCHER_H__

#include <glib-object.h>
#include <telepathy-glib/telepathy-glib.h>


G_BEGIN_DECLS

typedef struct _TpTestsSimpleChannelDispatcher TpTestsSimpleChannelDispatcher;
typedef struct _TpTestsSimpleChannelDispatcherClass TpTestsSimpleChannelDispatcherClass;
typedef struct _TpTestsSimpleChannelDispatcherPrivate TpTestsSimpleChannelDispatcherPrivate;

struct _TpTestsSimpleChannelDispatcherClass {
    GObjectClass parent_class;
    TpDBusPropertiesMixinClass dbus_props_class;
};

struct _TpTestsSimpleChannelDispatcher {
    GObject parent;

    /* so regression tests can verify what was asked for */
    GHashTable *last_request;
    gchar *last_account;
    gint64 last_user_action_time;
    gchar *last_preferred_handler;
    GHashTable *last_hints;

    TpTestsSimpleChannelDispatcherPrivate *priv;

    gboolean refuse_delegate;
};

GType tp_tests_simple_channel_dispatcher_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_SIMPLE_CHANNEL_DISPATCHER \
  (tp_tests_simple_channel_dispatcher_get_type ())
#define SIMPLE_CHANNEL_DISPATCHER(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_DISPATCHER, \
                              TpTestsSimpleChannelDispatcher))
#define SIMPLE_CHANNEL_DISPATCHER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), TP_TESTS_TYPE_SIMPLE_CHANNEL_DISPATCHER, \
                           TpTestsSimpleChannelDispatcherClass))
#define SIMPLE_IS_CHANNEL_DISPATCHER(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_DISPATCHER))
#define SIMPLE_IS_CHANNEL_DISPATCHER_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), TP_TESTS_TYPE_SIMPLE_CHANNEL_DISPATCHER))
#define SIMPLE_CHANNEL_DISPATCHER_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_SIMPLE_CHANNEL_DISPATCHER, \
                              TpTestsSimpleChannelDispatcherClass))


G_END_DECLS

#endif /* #ifndef __TP_TESTS_SIMPLE_CHANNEL_DISPATCHER_H__ */
