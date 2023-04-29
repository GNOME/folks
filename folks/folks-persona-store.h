/*
 * SPDX-License-Identifier: LGPL-2.1-or-later
 *
 * Copyright 2023 Collabora, Ltd.
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2.1 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef __FOLKS_PERSONA_STORE_H__
#define __FOLKS_PERSONA_STORE_H__

#include <glib-object.h>
#include <gio/gio.h>

G_BEGIN_DECLS

#define FOLKS_TYPE_PERSONA_STORE (folks_persona_store_get_type())

G_DECLARE_FINAL_TYPE (FolksPersonaStore, folks_persona_store, FOLKS, PERSONA_STORE, GObject)

typedef enum _FolksPersonaStorePreloadFlags {
    FOLKS_PERSONA_STORE_PRELOAD_NICKNAME = 1ull << 0,
    FOLKS_PERSONA_STORE_PRELOAD_ALIAS = 1ull << 1,
    FOLKS_PERSONA_STORE_PRELOAD_FULLNAME = 1ull << 2,
    FOLKS_PERSONA_STORE_PRELOAD_STRUCTURED_NAME = 1ull << 3,
    FOLKS_PERSONA_STORE_PRELOAD_AVATAR = 1ull << 4,
    FOLKS_PERSONA_STORE_PRELOAD_BIRTHDAY = 1ull << 5,
    FOLKS_PERSONA_STORE_PRELOAD_EMAILS = 1ull << 6,
    FOLKS_PERSONA_STORE_PRELOAD_EXTENDED_FIELDS = 1ull << 7,
    FOLKS_PERSONA_STORE_PRELOAD_IS_FAVOURITE = 1ull << 8,
    FOLKS_PERSONA_STORE_PRELOAD_GENDER = 1ull << 9,
    FOLKS_PERSONA_STORE_PRELOAD_GROUPS = 1ull << 10,
    FOLKS_PERSONA_STORE_PRELOAD_IM_ADDRESSES = 1ull << 11,
    FOLKS_PERSONA_STORE_PRELOAD_LOCATION = 1ull << 12,
    FOLKS_PERSONA_STORE_PRELOAD_NOTES = 1ull << 13,
    FOLKS_PERSONA_STORE_PRELOAD_PHONE_NUMBERS = 1ull << 14,
    FOLKS_PERSONA_STORE_PRELOAD_POSTAL_ADDRESSES = 1ull << 15,
    FOLKS_PERSONA_STORE_PRELOAD_ROLES = 1ull << 16,
    FOLKS_PERSONA_STORE_PRELOAD_URLS = 1ull << 17,
} FolksPersonaStorePreloadFlags;

void folks_persona_store_load (FolksPersonaStore   *self,
                               GCancellable        *cancellable,
                               GAsyncReadyCallback  callback,
                               gpointer             user_data);

gboolean folks_persona_store_load_finish (FolksPersonaStore  *self,
                                          GAsyncResult       *result,
                                          GError            **error);

void folks_persona_store_set_preload_flags (FolksPersonaStore             *self,
                                            FolksPersonaStorePreloadFlags  preload_flags);

FolksPersonaStorePreloadFlags folks_persona_store_get_preload_flags (FolksPersonaStore *self);

G_END_DECLS

#endif /* __FOLKS_PERSONA_STORE_H__ */
