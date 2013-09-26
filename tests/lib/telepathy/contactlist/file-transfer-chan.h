/*
 * stream-tube-chan.h - Simple stream tube channel
 *
 * Copyright (C) 2010-2011 Morten Mjelva <morten.mjelva@gmail.com>
 * Copyright (C) 2010-2011 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_FILE_TRANSFER_CHAN_H__
#define __TP_FILE_TRANSFER_CHAN_H__

#include <glib-object.h>
#include <telepathy-glib/telepathy-glib.h>

G_BEGIN_DECLS

typedef struct _TpTestsFileTransferChannel TpTestsFileTransferChannel;
typedef struct _TpTestsFileTransferChannelClass TpTestsFileTransferChannelClass;
typedef struct _TpTestsFileTransferChannelPrivate TpTestsFileTransferChannelPrivate;

GType tp_tests_file_transfer_channel_get_type (void);

#define TP_TESTS_TYPE_FILE_TRANSFER_CHANNEL \
    (tp_tests_file_transfer_channel_get_type ())
#define TP_TESTS_FILE_TRANSFER_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TESTS_TYPE_FILE_TRANSFER_CHANNEL, \
                               TpTestsFileTransferChannel))
#define TP_TESTS_FILE_TRANSFER_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TESTS_TYPE_FILE_TRANSFER_CHANNEL, \
                            TpTestsFileTransferChannelClass))
#define TP_TESTS_IS_FILE_TRANSFER_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TESTS_TYPE_FILE_TRANSFER_CHANNEL))
#define TP_TESTS_IS_FILE_TRANSFER_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TESTS_TYPE_FILE_TRANSFER_CHANNEL))
#define TP_TESTS_FILE_TRANSFER_CHANNEL_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_FILE_TRANSFER_CHANNEL, \
                              TpTestsFileTransferChannelClass))

struct _TpTestsFileTransferChannelClass {
    TpBaseChannelClass parent_class;
    TpDBusPropertiesMixinClass dbus_properties_class;
};

struct _TpTestsFileTransferChannel {
    TpBaseChannel parent;

    TpTestsFileTransferChannelPrivate *priv;
};

void tp_tests_file_transfer_channel_close (TpTestsFileTransferChannel *self);

GHashTable * tp_tests_file_transfer_channel_get_props (
        TpTestsFileTransferChannel *self);

GSocketAddress * tp_tests_file_transfer_channel_get_server_address (
        TpTestsFileTransferChannel *self);

G_END_DECLS

#endif
