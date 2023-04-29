#pragma once

#include <glib-object.h>
#include <gio/gio.h>

#include "folksd-bluez-device.h"
#include "folksd-bluez-obex-client.h"

G_BEGIN_DECLS

#define FOLKSD_TYPE_BLUEZ_DEVICE_HANDLER (folksd_bluez_device_handler_get_type())

G_DECLARE_FINAL_TYPE (FolksdBluezDeviceHandler, folksd_bluez_device_handler, FOLKSD, BLUEZ_DEVICE_HANDLER, GObject)

FolksdBluezDeviceHandler *folksd_bluez_device_handler_new (FolksdBluezDevice1 *dev,
                                                           FolksdBluezObexClient1 *obex_client);

GCancellable *folksd_bluez_device_handler_get_cancellable (FolksdBluezDeviceHandler *self);

FolksdBluezDevice1 *folksd_bluez_device_handler_get_device (FolksdBluezDeviceHandler *self);

void folksd_bluez_device_handler_update_contacts_async (FolksdBluezDeviceHandler *self,
                                                        GCancellable *cancellable,
                                                        GAsyncReadyCallback callback,
                                                        gpointer user_data);

GFile *folksd_bluez_device_handler_update_contacts_finish (FolksdBluezDeviceHandler *self,
                                                           GAsyncResult *result,
                                                           GError **error);

G_END_DECLS
