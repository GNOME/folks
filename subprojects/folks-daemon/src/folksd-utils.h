/*
 * Copyright 2022 Corentin Noël <corentin.noel@collabora.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include <glib.h>
#include <gio/gio.h>
#include <libtracker-sparql/tracker-sparql.h>

#define TRACKER_IPC_BUS           tracker_ipc_bus()

static inline GBusType
tracker_ipc_bus (void)
{
  const char *bus = g_getenv ("TRACKER_BUS_TYPE");

  if (G_UNLIKELY (bus != NULL &&
                  g_ascii_strcasecmp (bus, "system") == 0)) {
    return G_BUS_TYPE_SYSTEM;
  }

  return G_BUS_TYPE_SESSION;
}

TrackerResource *
folksd_utils_create_addressbook (const char *uid,
                                 const char *display_name);
