/*
 * dbus-tube-chan.h - Simple dbus tube channel
 *
 * Copyright (C) 2010 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#ifndef __TP_DBUS_TUBE_CHAN_H__
#define __TP_DBUS_TUBE_CHAN_H__

#include <glib-object.h>
#include <telepathy-glib/telepathy-glib.h>

G_BEGIN_DECLS

/* Base Class */
typedef struct _TpTestsDBusTubeChannel TpTestsDBusTubeChannel;
typedef struct _TpTestsDBusTubeChannelClass TpTestsDBusTubeChannelClass;
typedef struct _TpTestsDBusTubeChannelPrivate TpTestsDBusTubeChannelPrivate;

GType tp_tests_dbus_tube_channel_get_type (void);

#define TP_TESTS_TYPE_DBUS_TUBE_CHANNEL \
  (tp_tests_dbus_tube_channel_get_type ())
#define TP_TESTS_DBUS_TUBE_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TESTS_TYPE_DBUS_TUBE_CHANNEL, \
                               TpTestsDBusTubeChannel))
#define TP_TESTS_DBUS_TUBE_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TESTS_TYPE_DBUS_TUBE_CHANNEL, \
                            TpTestsDBusTubeChannelClass))
#define TP_TESTS_IS_DBUS_TUBE_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TESTS_TYPE_DBUS_TUBE_CHANNEL))
#define TP_TESTS_IS_DBUS_TUBE_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TESTS_TYPE_DBUS_TUBE_CHANNEL))
#define TP_TESTS_DBUS_TUBE_CHANNEL_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_DBUS_TUBE_CHANNEL, \
                              TpTestsDBusTubeChannelClass))

struct _TpTestsDBusTubeChannelClass {
    TpBaseChannelClass parent_class;
    TpDBusPropertiesMixinClass dbus_properties_class;
};

struct _TpTestsDBusTubeChannel {
    TpBaseChannel parent;

    TpTestsDBusTubeChannelPrivate *priv;
};

typedef enum {
    TP_TESTS_DBUS_TUBE_CHANNEL_OPEN_FIRST,
    TP_TESTS_DBUS_TUBE_CHANNEL_OPEN_SECOND,
    TP_TESTS_DBUS_TUBE_CHANNEL_NEVER_OPEN
} TpTestsDBusTubeChannelOpenMode;

void tp_tests_dbus_tube_channel_set_open_mode (
    TpTestsDBusTubeChannel *self,
    TpTestsDBusTubeChannelOpenMode open_mode);

/* Contact DBus Tube */

typedef struct _TpTestsContactDBusTubeChannel TpTestsContactDBusTubeChannel;
typedef struct _TpTestsContactDBusTubeChannelClass TpTestsContactDBusTubeChannelClass;

GType tp_tests_contact_dbus_tube_channel_get_type (void);

#define TP_TESTS_TYPE_CONTACT_DBUS_TUBE_CHANNEL \
  (tp_tests_contact_dbus_tube_channel_get_type ())
#define TP_TESTS_CONTACT_DBUS_TUBE_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TESTS_TYPE_CONTACT_DBUS_TUBE_CHANNEL, \
                               TpTestsContactDBusTubeChannel))
#define TP_TESTS_CONTACT_DBUS_TUBE_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TESTS_TYPE_CONTACT_DBUS_TUBE_CHANNEL, \
                            TpTestsContactDBusTubeChannelClass))
#define TP_TESTS_IS_CONTACT_DBUS_TUBE_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TESTS_TYPE_CONTACT_DBUS_TUBE_CHANNEL))
#define TP_TESTS_IS_CONTACT_DBUS_TUBE_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TESTS_TYPE_CONTACT_DBUS_TUBE_CHANNEL))
#define TP_TESTS_CONTACT_DBUS_TUBE_CHANNEL_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_CONTACT_DBUS_TUBE_CHANNEL, \
                              TpTestsContactDBusTubeChannelClass))

struct _TpTestsContactDBusTubeChannelClass {
    TpTestsDBusTubeChannelClass parent_class;
};

struct _TpTestsContactDBusTubeChannel {
    TpTestsDBusTubeChannel parent;
};

/* Room DBus Tube */

typedef struct _TpTestsRoomDBusTubeChannel TpTestsRoomDBusTubeChannel;
typedef struct _TpTestsRoomDBusTubeChannelClass TpTestsRoomDBusTubeChannelClass;

GType tp_tests_room_dbus_tube_channel_get_type (void);

#define TP_TESTS_TYPE_ROOM_DBUS_TUBE_CHANNEL \
  (tp_tests_room_dbus_tube_channel_get_type ())
#define TP_TESTS_ROOM_DBUS_TUBE_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), TP_TESTS_TYPE_ROOM_DBUS_TUBE_CHANNEL, \
                               TpTestsRoomDBusTubeChannel))
#define TP_TESTS_ROOM_DBUS_TUBE_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), TP_TESTS_TYPE_ROOM_DBUS_TUBE_CHANNEL, \
                            TpTestsRoomDBusTubeChannelClass))
#define TP_TESTS_IS_ROOM_DBUS_TUBE_CHANNEL(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TP_TESTS_TYPE_ROOM_DBUS_TUBE_CHANNEL))
#define TP_TESTS_IS_ROOM_DBUS_TUBE_CHANNEL_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), TP_TESTS_TYPE_ROOM_DBUS_TUBE_CHANNEL))
#define TP_TESTS_ROOM_DBUS_TUBE_CHANNEL_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), TP_TESTS_TYPE_ROOM_DBUS_TUBE_CHANNEL, \
                              TpTestsRoomDBusTubeChannelClass))

struct _TpTestsRoomDBusTubeChannelClass {
    TpTestsDBusTubeChannelClass parent_class;
};

struct _TpTestsRoomDBusTubeChannel {
    TpTestsDBusTubeChannel parent;
};

G_END_DECLS

#endif /* #ifndef __TP_DBUS_TUBE_CHAN_H__ */
