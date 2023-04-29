#pragma once

#include <glib-object.h>
#include <libtracker-sparql/tracker-sparql.h>

G_BEGIN_DECLS

#define FOLKSD_TYPE_EDS_MINER (folksd_eds_miner_get_type())

G_DECLARE_FINAL_TYPE (FolksdEdsMiner, folksd_eds_miner, FOLKSD, EDS_MINER, GObject)

FolksdEdsMiner *folksd_eds_miner_new (TrackerEndpointDBus *endpoint);

G_END_DECLS
