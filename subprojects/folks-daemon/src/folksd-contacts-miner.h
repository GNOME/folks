/*
 * Copyright 2022 Corentin Noël <corentin.noel@collabora.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#pragma once

#include <glib-object.h>

G_BEGIN_DECLS

#define EDM_TYPE_CONTACTS_MINER (edm_contacts_miner_get_type())

G_DECLARE_FINAL_TYPE (EdmContactsMiner, edm_contacts_miner, EDM, CONTACTS_MINER, GObject)

EdmContactsMiner *edm_contacts_miner_new (void);

G_END_DECLS
