/*
 * chan.h - header for an example channel
 *
 * Copyright (C) 2007 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_TESTS_CHAN_H__
#define __TP_TESTS_CHAN_H__

#include <glib-object.h>
#include <telepathy-glib/telepathy-glib.h>

G_BEGIN_DECLS

typedef struct _TpTestsEchoChannel TpTestsEchoChannel;
typedef struct _TpTestsEchoChannelClass TpTestsEchoChannelClass;
typedef struct _TpTestsEchoChannelPrivate TpTestsEchoChannelPrivate;

GType tp_tests_echo_channel_get_type (void);

#define TP_TESTS_TYPE_ECHO_CHANNEL \
  (tp_tests_echo_channel_get_type ())
#define TP_TESTS_ECHO_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TESTS_TYPE_ECHO_CHANNEL, \
                               TpTestsEchoChannel))
#define TP_TESTS_ECHO_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TESTS_TYPE_ECHO_CHANNEL, \
                            TpTestsEchoChannelClass))
#define TP_TESTS_IS_ECHO_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TESTS_TYPE_ECHO_CHANNEL))
#define TP_TESTS_IS_ECHO_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TESTS_TYPE_ECHO_CHANNEL))
#define TP_TESTS_ECHO_CHANNEL_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_ECHO_CHANNEL, \
                              TpTestsEchoChannelClass))

struct _TpTestsEchoChannelClass {
    TpBaseChannelClass parent_class;
    TpDBusPropertiesMixinClass dbus_properties_class;
};

struct _TpTestsEchoChannel {
    TpBaseChannel parent;
    TpMessageMixin message;

    TpTestsEchoChannelPrivate *priv;
};

G_END_DECLS

#endif /* #ifndef __TP_TESTS_CHAN_H__ */
