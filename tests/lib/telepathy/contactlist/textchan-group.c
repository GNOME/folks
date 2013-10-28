/*
 * a stub anonymous MUC
 *
 * Copyright (C) 2008 Collabora Ltd. <http://www.collabora.co.uk/>
 * Copyright (C) 2008 Nokia Corporation
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "textchan-group.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>

static void password_iface_init (gpointer iface, gpointer data);

G_DEFINE_TYPE_WITH_CODE (TpTestsTextChannelGroup,
    tp_tests_text_channel_group, TP_TYPE_BASE_CHANNEL,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_TYPE_TEXT,
        tp_message_mixin_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_INTERFACE_GROUP1,
      tp_group_mixin_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CHANNEL_INTERFACE_PASSWORD1,
      password_iface_init);
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_DBUS_PROPERTIES,
      tp_dbus_properties_mixin_iface_init))

static GPtrArray *
text_channel_group_get_interfaces (TpBaseChannel *self)
{
  GPtrArray *interfaces;

  interfaces = TP_BASE_CHANNEL_CLASS (
      tp_tests_text_channel_group_parent_class)->get_interfaces (self);

  g_ptr_array_add (interfaces, TP_IFACE_CHANNEL_INTERFACE_GROUP1);
  g_ptr_array_add (interfaces, TP_IFACE_CHANNEL_INTERFACE_PASSWORD1);
  return interfaces;
};

/* type definition stuff */

struct _TpTestsTextChannelGroupPrivate
{
  gboolean closed;
  gboolean disposed;

  gchar *password;
};


static gboolean
add_member (GObject *obj,
            TpHandle handle,
            const gchar *message,
            GError **error)
{
  TpTestsTextChannelGroup *self = TP_TESTS_TEXT_CHANNEL_GROUP (obj);
  TpIntset *add = tp_intset_new ();
  GHashTable *details = tp_asv_new (
      "actor", G_TYPE_UINT, tp_base_connection_get_self_handle (self->conn),
      "change-reason", G_TYPE_UINT, TP_CHANNEL_GROUP_CHANGE_REASON_NONE,
      "message", G_TYPE_STRING, message,
      NULL);

  tp_intset_add (add, handle);
  tp_group_mixin_change_members (obj, add, NULL, NULL, NULL, details);
  tp_intset_destroy (add);

  g_hash_table_unref (details);

  return TRUE;
}

static gboolean
remove_with_reason (GObject *obj,
    TpHandle handle,
    const gchar *message,
    guint reason,
    GError **error)
{
  TpTestsTextChannelGroup *self = TP_TESTS_TEXT_CHANNEL_GROUP (obj);
  TpGroupMixin *group = TP_GROUP_MIXIN (self);

  tp_clear_pointer (&self->removed_message, g_free);

  self->removed_handle = handle;
  self->removed_message = g_strdup (message);
  self->removed_reason = reason;

  if (handle == group->self_handle)
    {
      /* User wants to leave */
      if (!self->priv->closed)
        {
          self->priv->closed = TRUE;
          tp_svc_channel_emit_closed (self);
        }

      return TRUE;
    }

  return TRUE;
}

static void
tp_tests_text_channel_group_init (TpTestsTextChannelGroup *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self,
      TP_TESTS_TYPE_TEXT_CHANNEL_GROUP, TpTestsTextChannelGroupPrivate);
}

static void
text_send (GObject *object,
           TpMessage *message,
           TpMessageSendingFlags flags)
{
  /* silently swallow the message */
  tp_message_mixin_sent (object, message, 0, "", NULL);
}

static void
constructed (GObject *object)
{
  TpTestsTextChannelGroup *self = TP_TESTS_TEXT_CHANNEL_GROUP (object);
  TpHandleRepoIface *contact_repo;
  TpChannelGroupFlags flags = 0;
  TpBaseChannel *base = TP_BASE_CHANNEL (self);
  const TpChannelTextMessageType types[] = {
      TP_CHANNEL_TEXT_MESSAGE_TYPE_NORMAL,
      TP_CHANNEL_TEXT_MESSAGE_TYPE_ACTION,
      TP_CHANNEL_TEXT_MESSAGE_TYPE_NOTICE,
  };
  const gchar * supported_content_types[] = {
      "text/plain",
      NULL
  };

  G_OBJECT_CLASS (tp_tests_text_channel_group_parent_class)->constructed (
      object);

  self->conn = tp_base_channel_get_connection (base);

  contact_repo = tp_base_connection_get_handles (self->conn,
      TP_HANDLE_TYPE_CONTACT);

  tp_base_channel_register (base);

  tp_message_mixin_init (object,
      G_STRUCT_OFFSET (TpTestsTextChannelGroup, message),
      self->conn);

  tp_message_mixin_implement_sending (object,
      text_send, G_N_ELEMENTS (types), types, 0, 0,
      supported_content_types);

  flags |= TP_CHANNEL_GROUP_FLAG_CAN_ADD;

  tp_group_mixin_init (object, G_STRUCT_OFFSET (TpTestsTextChannelGroup, group),
      contact_repo,
      tp_base_connection_get_self_handle (self->conn));

  tp_group_mixin_change_flags (object, flags, 0);
}

static void
dispose (GObject *object)
{
  TpTestsTextChannelGroup *self = TP_TESTS_TEXT_CHANNEL_GROUP (object);

  if (self->priv->disposed)
    return;

  self->priv->disposed = TRUE;

  if (!self->priv->closed)
    {
      tp_svc_channel_emit_closed (self);
    }

  ((GObjectClass *) tp_tests_text_channel_group_parent_class)->dispose (object);
}

static void
finalize (GObject *object)
{
  TpTestsTextChannelGroup *self = TP_TESTS_TEXT_CHANNEL_GROUP (object);

  tp_message_mixin_finalize (object);
  tp_group_mixin_finalize (object);

  tp_clear_pointer (&self->priv->password, g_free);

  ((GObjectClass *) tp_tests_text_channel_group_parent_class)->finalize (object);
}

static void
channel_close (TpBaseChannel *base)
{
  TpTestsTextChannelGroup *self = TP_TESTS_TEXT_CHANNEL_GROUP (base);

  if (!self->priv->closed)
    {
      self->priv->closed = TRUE;
      tp_svc_channel_emit_closed (self);
    }
}

static void
tp_tests_text_channel_group_class_init (TpTestsTextChannelGroupClass *klass)
{
  GObjectClass *object_class = (GObjectClass *) klass;
  TpBaseChannelClass *base_class = (TpBaseChannelClass *) klass;

  g_type_class_add_private (klass, sizeof (TpTestsTextChannelGroupPrivate));

  object_class->constructed = constructed;
  object_class->dispose = dispose;
  object_class->finalize = finalize;

  base_class->channel_type = TP_IFACE_CHANNEL_TYPE_TEXT;
  base_class->target_handle_type = TP_HANDLE_TYPE_NONE;
  base_class->get_interfaces = text_channel_group_get_interfaces;
  base_class->close = channel_close;

  tp_group_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestsTextChannelGroupClass, group_class), add_member,
      NULL);

  tp_group_mixin_class_set_remove_with_reason_func (object_class,
      remove_with_reason);

  tp_group_mixin_class_allow_self_removal (object_class);

  tp_dbus_properties_mixin_class_init (object_class,
      G_STRUCT_OFFSET (TpTestsTextChannelGroupClass, dbus_properties_class));

  tp_group_mixin_init_dbus_properties (object_class);

  tp_message_mixin_init_dbus_properties (object_class);
}

void
tp_tests_text_channel_group_join (TpTestsTextChannelGroup *self)
{
  TpIntset *add, *empty;
  GHashTable *details = tp_asv_new (
      "actor", G_TYPE_UINT, 0,
      "change-reason", G_TYPE_UINT, 0,
      "message", G_TYPE_STRING, "",
      NULL);

 /* Add ourself as a member */
  add = tp_intset_new_containing (
      tp_base_connection_get_self_handle (self->conn));
  empty = tp_intset_new ();

  tp_group_mixin_change_members ((GObject *) self, add, empty,
      empty, empty, details);

  tp_intset_destroy (add);
  tp_intset_destroy (empty);
  g_hash_table_unref (details);
}

void
tp_tests_text_channel_set_password (TpTestsTextChannelGroup *self,
    const gchar *password)
{
  gboolean pass_was_needed, pass_needed;

  pass_was_needed = (self->priv->password != NULL);

  tp_clear_pointer (&self->priv->password, g_free);

  self->priv->password = g_strdup (password);

  pass_needed = (self->priv->password != NULL);

  if (pass_needed == pass_was_needed)
    return;

  if (pass_needed)
    tp_svc_channel_interface_password1_emit_password_flags_changed (self,
        TP_CHANNEL_PASSWORD_FLAG_PROVIDE, 0);
  else
    tp_svc_channel_interface_password1_emit_password_flags_changed (self,
        0, TP_CHANNEL_PASSWORD_FLAG_PROVIDE);
}

static void
password_get_password_flags (TpSvcChannelInterfacePassword1 *chan,
    DBusGMethodInvocation *context)
{
  TpTestsTextChannelGroup *self = (TpTestsTextChannelGroup *) chan;
  TpChannelPasswordFlags flags = 0;

  if (self->priv->password != NULL)
    flags |= TP_CHANNEL_PASSWORD_FLAG_PROVIDE;

  tp_svc_channel_interface_password1_return_from_get_password_flags (context,
      flags);
}

static void
password_provide_password (TpSvcChannelInterfacePassword1 *chan,
    const gchar *password,
    DBusGMethodInvocation *context)
{
  TpTestsTextChannelGroup *self = (TpTestsTextChannelGroup *) chan;

  tp_svc_channel_interface_password1_return_from_provide_password (context,
      !tp_strdiff (password, self->priv->password));
}

static void
password_iface_init (gpointer iface, gpointer data)
{
  TpSvcChannelInterfacePassword1Class *klass = iface;

#define IMPLEMENT(x) tp_svc_channel_interface_password1_implement_##x (klass, password_##x)
  IMPLEMENT (get_password_flags);
  IMPLEMENT (provide_password);
#undef IMPLEMENT
}
