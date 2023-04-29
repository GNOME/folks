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

#ifndef __FOLKS_PERSONA_H__
#define __FOLKS_PERSONA_H__

#include <glib-object.h>
#include <gio/gio.h>

#include "folks/folks-structured-name.h"
#include "folks/folks-location.h"

G_BEGIN_DECLS

#define FOLKS_TYPE_PERSONA (folks_persona_get_type())

G_DECLARE_FINAL_TYPE (FolksPersona, folks_persona, FOLKS, PERSONA, GObject)

char *folks_persona_get_alias (FolksPersona *self);
char *folks_persona_get_fullname (FolksPersona *self);
char *folks_persona_get_nickname (FolksPersona *self);
FolksStructuredName *folks_persona_get_structured_name (FolksPersona *self);
gboolean folks_persona_set_alias (FolksPersona  *self,
                                  const char    *alias,
                                  GCancellable  *cancellable,
                                  GError       **error);
GIcon *folks_persona_get_avatar (FolksPersona *self);
GDateTime *folks_persona_get_birthday (FolksPersona *self);
GListModel *folks_persona_get_emails (FolksPersona *self);
GListModel *folks_persona_get_extended_fields (FolksPersona *self);
gboolean folks_persona_get_is_favourite (FolksPersona *self);
char *folks_persona_get_gender (FolksPersona *self);
GListModel *folks_persona_get_groups (FolksPersona *self);
GListModel *folks_persona_get_im_addresses (FolksPersona *self);
FolksLocation *folks_persona_get_location (FolksPersona *self);
GListModel *folks_persona_get_notes (FolksPersona *self);
GListModel *folks_persona_get_phone_numbers (FolksPersona *self);
GListModel *folks_persona_get_postal_addresses (FolksPersona *self);
GListModel *folks_persona_get_roles (FolksPersona *self);
GListModel *folks_persona_get_urls (FolksPersona *self);

G_END_DECLS

#endif /* __FOLKS_PERSONA_H__ */
