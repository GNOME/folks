
#ifndef __TP_TESTS_ROOM_LIST_CHAN_H__
#define __TP_TESTS_ROOM_LIST_CHAN_H__

#include <glib-object.h>
#include <telepathy-glib/base-channel.h>

G_BEGIN_DECLS

typedef struct _TpTestsRoomListChan TpTestsRoomListChan;
typedef struct _TpTestsRoomListChanClass TpTestsRoomListChanClass;
typedef struct _TpTestsRoomListChanPriv TpTestsRoomListChanPriv;

struct _TpTestsRoomListChanClass {
    TpBaseChannelClass parent_class;
    TpDBusPropertiesMixinClass dbus_properties_class;
};

struct _TpTestsRoomListChan {
    TpBaseChannel parent;
    TpTestsRoomListChanPriv *priv;
};

GType tp_tests_room_list_chan_get_type (void);

/* TYPE MACROS */
#define TP_TESTS_TYPE_ROOM_LIST_CHAN \
  (tp_tests_room_list_chan_get_type ())
#define TP_TESTS_ROOM_LIST_CHAN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), \
    TP_TESTS_TYPE_ROOM_LIST_CHAN, \
    TpTestsRoomListChan))
#define TP_TESTS_ROOM_LIST_CHAN_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST((klass), \
    TP_TESTS_TYPE_ROOM_LIST_CHAN, \
    TpTestsRoomListChanClass))
#define TP_TESTS_IS_ROOM_LIST_CHAN(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE((obj), \
    TP_TESTS_TYPE_ROOM_LIST_CHAN))
#define TP_TESTS_IS_ROOM_LIST_CHAN_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE((klass), \
    TP_TESTS_TYPE_ROOM_LIST_CHAN))
#define TP_TESTS_ROOM_LIST_CHAN_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), \
    TP_TESTS_TYPE_ROOM_LIST_CHAN, \
    TpTestsRoomListChanClass))

G_END_DECLS

#endif /* #ifndef __TP_TESTS_ROOM_LIST_CHAN_H__*/
