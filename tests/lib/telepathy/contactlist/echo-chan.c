/*
 * chan.c - an example text channel talking to a particular
 * contact. Similar code is used for 1-1 IM channels in many protocols
 * (IRC private messages ("/query"), XMPP IM etc.)
 *
 * Copyright (C) 2007 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2007 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "echo-chan.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>

static void destroyable_iface_init (gpointer iface, gpointer data);

G_DEFINE_TYPE_WITH_CODE (TpTestsEchoChannel,
    tp_tests_echo_channel,
    TP_TYPE_BASE_CHANNEL,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_TYPE_TEXT,
      tp_message_mixin_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_INTERFACE_DESTROYABLE1,
      destroyable_iface_init);
    )

/* type definition stuff */

static GPtrArray *
tp_tests_echo_channel_get_interfaces (TpBaseChannel *self)
{
  GPtrArray *interfaces;

  interfaces = TP_BASE_CHANNEL_CLASS (tp_tests_echo_channel_parent_class)->
    get_interfaces (self);

  g_ptr_array_add (interfaces, TP_IFACE_CHANNEL_INTERFACE_DESTROYABLE1);
  return interfaces;
};

static void
tp_tests_echo_channel_init (TpTestsEchoChannel *self)
{
}

static void text_send (GObject *object, TpMessage *message,
    TpMessageSendingFlags flags);

static void
constructed (GObject *object)
{
  TpTestsEchoChannel *self = TP_TESTS_ECHO_CHANNEL (object);
  TpBaseConnection *conn = tp_base_channel_get_connection (TP_BASE_CHANNEL (self));
  const TpChannelTextMessageType types[] = {
      TP_CHANNEL_TEXT_MESSAGE_TYPE_NORMAL,
      TP_CHANNEL_TEXT_MESSAGE_TYPE_ACTION,
      TP_CHANNEL_TEXT_MESSAGE_TYPE_NOTICE,
  };
  const gchar * supported_content_types[] = {
      "text/plain",
      NULL
  };
  g_assert (conn != NULL);

  G_OBJECT_CLASS (tp_tests_echo_channel_parent_class)->constructed (object);

  tp_base_channel_register (TP_BASE_CHANNEL (self));

  tp_message_mixin_init (object,
      G_STRUCT_OFFSET (TpTestsEchoChannel, message),
      conn);
  tp_message_mixin_implement_sending (object,
      text_send, G_N_ELEMENTS (types), types, 0, 0,
      supported_content_types);
}

static void
finalize (GObject *object)
{
  tp_message_mixin_finalize (object);

  ((GObjectClass *) tp_tests_echo_channel_parent_class)->finalize (object);
}

static void
tp_tests_echo_channel_close (TpTestsEchoChannel *self)
{
  GObject *object = (GObject *) self;
  gboolean closed = tp_base_channel_is_destroyed (TP_BASE_CHANNEL (self));

  if (!closed)
    {
      TpHandle first_sender;

      /* The manager wants to be able to respawn the channel if it has pending
       * messages. When respawned, the channel must have the initiator set
       * to the contact who sent us those messages (if it isn't already),
       * and the messages must be marked as having been rescued so they
       * don't get logged twice. */
      if (tp_message_mixin_has_pending_messages (object, &first_sender))
        {
          tp_base_channel_reopened (TP_BASE_CHANNEL (self), first_sender);
          tp_message_mixin_set_rescued (object);
        }
      else
        {
          tp_base_channel_destroyed (TP_BASE_CHANNEL (self));
        }
    }
}

static void
channel_close (TpBaseChannel *channel)
{
  TpTestsEchoChannel *self = TP_TESTS_ECHO_CHANNEL (channel);

  tp_tests_echo_channel_close (self);
}

static void
tp_tests_echo_channel_class_init (TpTestsEchoChannelClass *klass)
{
  GObjectClass *object_class = (GObjectClass *) klass;
  TpBaseChannelClass *base_class = TP_BASE_CHANNEL_CLASS (klass);

  object_class->constructed = constructed;
  object_class->finalize = finalize;

  base_class->channel_type = TP_IFACE_CHANNEL_TYPE_TEXT;
  base_class->target_handle_type = TP_HANDLE_TYPE_CONTACT;
  base_class->get_interfaces = tp_tests_echo_channel_get_interfaces;
  base_class->close = channel_close;

  tp_message_mixin_init_dbus_properties (object_class);
}


static void
text_send (GObject *object,
    TpMessage *message,
    TpMessageSendingFlags flags)
{
  TpTestsEchoChannel *self = TP_TESTS_ECHO_CHANNEL (object);
  TpChannelTextMessageType type = tp_message_get_message_type (message);
  TpChannelTextMessageType echo_type = type;
  TpHandle target = tp_base_channel_get_target_handle (TP_BASE_CHANNEL (self));
  gchar *echo;
  gint64 now = time (NULL);
  const GHashTable *part;
  const gchar *text;
  TpMessage *msg;

  /* Pretend that the remote contact has replied. Normally, you'd
   * call tp_text_mixin_receive or tp_text_mixin_receive_with_flags
   * in response to network events */

  part = tp_message_peek (message, 1);
  text = tp_asv_get_string (part, "content");

  switch (type)
    {
    case TP_CHANNEL_TEXT_MESSAGE_TYPE_NORMAL:
      echo = g_strdup_printf ("You said: %s", text);
      break;
    case TP_CHANNEL_TEXT_MESSAGE_TYPE_ACTION:
      echo = g_strdup_printf ("notices that the user %s", text);
      break;
    case TP_CHANNEL_TEXT_MESSAGE_TYPE_NOTICE:
      echo = g_strdup_printf ("You sent a notice: %s", text);
      break;
    default:
      echo = g_strdup_printf ("You sent some weird message type, %u: \"%s\"",
          type, text);
      echo_type = TP_CHANNEL_TEXT_MESSAGE_TYPE_NORMAL;
    }

  tp_message_mixin_sent (object, message, 0, "", NULL);

  msg = tp_cm_message_new (
      tp_base_channel_get_connection (TP_BASE_CHANNEL (self)),
      2);

  tp_cm_message_set_sender (msg, target);
  tp_message_set_uint32 (msg, 0, "message-type", echo_type);
  tp_message_set_int64 (msg, 0, "message-sent", now);
  tp_message_set_int64 (msg, 0, "message-received", now);

  tp_message_set_string (msg, 1, "content-type", "text/plain");
  tp_message_set_string (msg, 1, "content", echo);

  tp_message_mixin_take_received (object, msg);

  g_free (echo);
}

static void
destroyable_destroy (TpSvcChannelInterfaceDestroyable1 *iface,
                     DBusGMethodInvocation *context)
{
  TpTestsEchoChannel *self = TP_TESTS_ECHO_CHANNEL (iface);

  tp_message_mixin_clear ((GObject *) self);
  tp_base_channel_destroyed (TP_BASE_CHANNEL (self));

  tp_svc_channel_interface_destroyable1_return_from_destroy (context);
}

static void
destroyable_iface_init (gpointer iface,
                        gpointer data)
{
  TpSvcChannelInterfaceDestroyable1Class *klass = iface;

#define IMPLEMENT(x) \
  tp_svc_channel_interface_destroyable1_implement_##x (klass, destroyable_##x)
  IMPLEMENT (destroy);
#undef IMPLEMENT
}
