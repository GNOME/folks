#include "folksd-bluez-device-handler.h"

#include <gio/gio.h>

#include "folksd-bluez-obex-transfer.h"
#include "folksd-bluez-obex-phonebook-access.h"

struct _FolksdBluezDeviceHandler
{
  GObject parent_instance;

  FolksdBluezDevice1 *device;
  FolksdBluezObexClient1 *obex_client;
  GCancellable *cancellable;
};

G_DEFINE_FINAL_TYPE (FolksdBluezDeviceHandler, folksd_bluez_device_handler, G_TYPE_OBJECT)

enum {
  PROP_DEVICE = 1,
  PROP_OBEX_CLIENT,
  N_PROPS
};

static GParamSpec *properties [N_PROPS];

FolksdBluezDeviceHandler *
folksd_bluez_device_handler_new (FolksdBluezDevice1 *dev,
                                 FolksdBluezObexClient1 *obex_client)
{
  return g_object_new (FOLKSD_TYPE_BLUEZ_DEVICE_HANDLER,
                       "device", dev,
                       "obex-client", obex_client,
                       NULL);
}

static void
folksd_bluez_device_handler_dispose (GObject *object)
{
  FolksdBluezDeviceHandler *self = (FolksdBluezDeviceHandler *)object;

  if (self->cancellable)
    g_cancellable_cancel (self->cancellable);

  g_clear_object (&self->cancellable);

  G_OBJECT_CLASS (folksd_bluez_device_handler_parent_class)->dispose (object);
}

static void
folksd_bluez_device_handler_get_property (GObject    *object,
                                          guint       prop_id,
                                          GValue     *value,
                                          GParamSpec *pspec)
{
  FolksdBluezDeviceHandler *self = FOLKSD_BLUEZ_DEVICE_HANDLER (object);

  switch (prop_id)
    {
    case PROP_DEVICE:
      g_value_set_object (value, self->device);
      break;
    case PROP_OBEX_CLIENT:
      g_value_set_object (value, self->obex_client);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folksd_bluez_device_handler_set_property (GObject      *object,
                                          guint         prop_id,
                                          const GValue *value,
                                          GParamSpec   *pspec)
{
  FolksdBluezDeviceHandler *self = FOLKSD_BLUEZ_DEVICE_HANDLER (object);

  switch (prop_id)
    {
    case PROP_DEVICE:
      g_assert (!self->device);
      self->device = g_value_dup_object (value);
      break;
    case PROP_OBEX_CLIENT:
      g_assert (!self->obex_client);
      self->obex_client = g_value_dup_object (value);
      break;
    default:
      G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
    }
}

static void
folksd_bluez_device_handler_class_init (FolksdBluezDeviceHandlerClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->dispose = folksd_bluez_device_handler_dispose;
  object_class->get_property = folksd_bluez_device_handler_get_property;
  object_class->set_property = folksd_bluez_device_handler_set_property;

  properties[PROP_DEVICE] =
    g_param_spec_object ("device",
                         "Device",
                         "Bluez Device",
                         FOLKSD_BLUEZ_TYPE_DEVICE1,
                         G_PARAM_CONSTRUCT_ONLY | G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

  properties[PROP_OBEX_CLIENT] =
    g_param_spec_object ("obex-client",
                         "Obex Client",
                         "Bluez Obex Client",
                         FOLKSD_BLUEZ_OBEX_TYPE_CLIENT1,
                         G_PARAM_CONSTRUCT_ONLY | G_PARAM_READWRITE | G_PARAM_STATIC_STRINGS);

  g_object_class_install_properties (object_class,
                                     N_PROPS,
                                     properties);
}

static void
folksd_bluez_device_handler_init (G_GNUC_UNUSED FolksdBluezDeviceHandler *self)
{

}

void
on_transfer_properties_changed (GDBusProxy *proxy,
                                G_GNUC_UNUSED GVariant   *changed_properties,
                                G_GNUC_UNUSED GStrv       invalidated_properties,
                                gpointer    user_data)
{
  GTask *task = user_data;
  FolksdBluezDeviceHandler *self = g_task_get_source_object (task);
  FolksdBluezObexTransfer1 *obex_transfer = FOLKSD_BLUEZ_OBEX_TRANSFER1 (proxy);
  const char *status;

  status = folksd_bluez_obex_transfer1_get_status (obex_transfer);
  g_critical ("CHANGED: %s", folksd_bluez_obex_transfer1_get_status (obex_transfer));
  if (g_task_return_error_if_cancelled (task)) {
    g_signal_handlers_disconnect_by_func (obex_transfer, G_CALLBACK (on_transfer_properties_changed), user_data);
    g_task_set_task_data (task, NULL, NULL);
  }

  if (!g_strcmp0 (status, "error")) {

    g_signal_handlers_disconnect_by_func (obex_transfer, G_CALLBACK (on_transfer_properties_changed), user_data);
    g_task_return_new_error (task,
                             G_IO_ERROR,
                             G_IO_ERROR_FAILED,
                             "Error during transfer of the address book ‘%s’ from Bluetooth device ‘%s’.",
                             folksd_bluez_obex_transfer1_get_name (obex_transfer),
                             folksd_bluez_device1_get_alias (self->device));
    g_task_set_task_data (task, NULL, NULL);
  } else if (!g_strcmp0 (status, "complete")) {
    const char *filename;

    g_signal_handlers_disconnect_by_func (obex_transfer, G_CALLBACK (on_transfer_properties_changed), user_data);

    filename = folksd_bluez_obex_transfer1_get_filename (obex_transfer);
    if (!filename) {
      g_task_return_new_error (task,
                               G_IO_ERROR,
                               G_IO_ERROR_FAILED,
                               "Error during transfer of the address book ‘%s’ from Bluetooth device ‘%s’.",
                               folksd_bluez_obex_transfer1_get_name (obex_transfer),
                               folksd_bluez_device1_get_alias (self->device));
    } else {
      g_task_return_pointer (task, g_file_new_for_path (filename), g_object_unref);
    }

    g_task_set_task_data (task, NULL, NULL);
  }
}

static void
update_contacts_thread (GTask         *task,
                        gpointer       source_object,
                        G_GNUC_UNUSED gpointer       task_data,
                        GCancellable  *cancellable)
{
  FolksdBluezDeviceHandler *self = source_object;
  GVariantDict args;
  g_autofree char *session_path = NULL;
  g_autoptr(GError) error = NULL;
  g_autoptr(FolksdBluezObexPhonebookAccess1) obex_pbap = NULL;
  g_autofree char *transfer_path = NULL;
  g_autoptr(GVariant) properties = NULL;
  g_autoptr(FolksdBluezObexTransfer1) obex_transfer = NULL;
  g_autoptr(GMainLoop) main_loop = NULL;

  g_assert (FOLKSD_IS_BLUEZ_DEVICE_HANDLER (self));

  g_debug ("Creating a new OBEX session.");

  g_variant_dict_init (&args, NULL);
  g_variant_dict_insert (&args, "Target", "s", "PBAP");

  if (!folksd_bluez_obex_client1_call_create_session_sync (self->obex_client,
                                                           folksd_bluez_device1_get_address (self->device),
                                                           g_variant_dict_end (&args),
                                                           &session_path,
                                                           cancellable,
                                                           &error)) {
    g_prefix_error (&error, "Failed to create session: ");
    g_task_return_error (task, g_steal_pointer (&error));
    return;
  }

  g_debug ("    Got OBEX session path: %s", session_path);
  obex_pbap = folksd_bluez_obex_phonebook_access1_proxy_new_for_bus_sync (G_BUS_TYPE_SESSION,
                                                                          G_DBUS_PROXY_FLAGS_NONE,
                                                                          "org.bluez.obex",
                                                                          session_path,
                                                                          cancellable,
                                                                          &error);
  if (!obex_pbap) {
    g_prefix_error (&error, "Failed to get OBEX PBAB: ");
    g_task_return_error (task, g_steal_pointer (&error));
    return;
  }

  g_debug ("    Got OBEX PBAP proxy");
  /* Select the phonebook object we want to download ie:
   * PB: phonebook for the saved contacts */
  if (!folksd_bluez_obex_phonebook_access1_call_select_sync (obex_pbap, "int", "PB", cancellable, &error)){
    g_prefix_error (&error, "Failed to call select: ");
    g_task_return_error (task, g_steal_pointer (&error));
    return;
  }

  /* Initiate a phone book transfer from the PSE server using a
   * plain string vCard format, transferring to a temporary file. */
  g_variant_dict_init (&args, NULL);
  g_variant_dict_insert (&args, "Format", "s", "Vcard30");
  const char *fields[] = { "UID", "N", "FN", "NICKNAME", "TEL", "URL", "EMAIL", "PHOTO", NULL };
  g_variant_dict_insert (&args, "Fields", "^as", fields);
  if (!folksd_bluez_obex_phonebook_access1_call_pull_all_sync (obex_pbap, "",
                                                               g_variant_dict_end (&args),
                                                               &transfer_path,
                                                               &properties,
                                                               cancellable,
                                                               &error)) {
    g_prefix_error (&error, "Failed to call pull all: ");
    g_task_return_error (task, g_steal_pointer (&error));
    return;
  }

  obex_transfer = folksd_bluez_obex_transfer1_proxy_new_for_bus_sync (G_BUS_TYPE_SESSION,
                                                                      G_DBUS_PROXY_FLAGS_GET_INVALIDATED_PROPERTIES,
                                                                      "org.bluez.obex",
                                                                      transfer_path,
                                                                      cancellable,
                                                                      &error);
  if (!obex_transfer) {
    g_prefix_error (&error, "Failed to get OBEX Transfer: ");
    g_task_return_error (task, g_steal_pointer (&error));
    return;
  }

  main_loop = g_main_loop_new (NULL, TRUE);
  g_signal_connect (obex_transfer, "g-properties-changed", G_CALLBACK (on_transfer_properties_changed), task);
  g_task_set_task_data (task, main_loop, (GDestroyNotify) g_main_loop_quit);
  g_main_loop_run (main_loop);
}

void
folksd_bluez_device_handler_update_contacts_async (FolksdBluezDeviceHandler *self,
                                                   GCancellable *cancellable,
                                                   GAsyncReadyCallback callback,
                                                   gpointer user_data)
{
  g_autoptr(GTask) task = NULL;

  g_return_if_fail (FOLKSD_IS_BLUEZ_DEVICE_HANDLER (self));
  g_return_if_fail (!cancellable || G_IS_CANCELLABLE (cancellable));

  task = g_task_new (self, cancellable, callback, user_data);
  g_task_set_source_tag (task, folksd_bluez_device_handler_update_contacts_async);
  g_task_run_in_thread (task, update_contacts_thread);
}

GFile *
folksd_bluez_device_handler_update_contacts_finish (FolksdBluezDeviceHandler *self,
                                                    GAsyncResult *result,
                                                    GError **error)
{
  g_return_val_if_fail (FOLKSD_IS_BLUEZ_DEVICE_HANDLER (self), FALSE);
  g_return_val_if_fail (g_task_is_valid (result, self), FALSE);

  return g_task_propagate_pointer (G_TASK (result), error);
}

GCancellable *
folksd_bluez_device_handler_get_cancellable (FolksdBluezDeviceHandler *self)
{
  g_return_val_if_fail (FOLKSD_IS_BLUEZ_DEVICE_HANDLER (self), NULL);

  return self->cancellable;
}

FolksdBluezDevice1 *
folksd_bluez_device_handler_get_device (FolksdBluezDeviceHandler *self)
{
  g_return_val_if_fail (FOLKSD_IS_BLUEZ_DEVICE_HANDLER (self), NULL);

  return self->device;
}
