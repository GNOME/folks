#pragma once

#include <glib-object.h>
#include <libtracker-sparql/tracker-sparql.h>

G_BEGIN_DECLS

#define FOLKSD_TYPE_BLUEZ_MINER (folksd_bluez_miner_get_type())

G_DECLARE_FINAL_TYPE (FolksdBluezMiner, folksd_bluez_miner, FOLKSD, BLUEZ_MINER, GObject)

FolksdBluezMiner *folksd_bluez_miner_new (TrackerEndpointDBus *endpoint);

G_END_DECLS
