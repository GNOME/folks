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

#ifndef __FOLKS_MANAGER_H__
#define __FOLKS_MANAGER_H__

#include <glib-object.h>
#include <gio/gio.h>

G_BEGIN_DECLS

#define FOLKS_TYPE_MANAGER (folks_manager_get_type())

G_DECLARE_FINAL_TYPE (FolksManager, folks_manager, FOLKS, MANAGER, GObject)

FolksManager *folks_manager_new_sync (GCancellable  *cancellable,
                                      GError       **error);
void          folks_manager_new (int                  io_priority,
                                 GCancellable        *cancellable,
                                 GAsyncReadyCallback  callback,
                                 gpointer             user_data);
FolksManager *folks_manager_new_finish (GAsyncResult  *res,
                                        GError       **error);

G_END_DECLS

#endif /* __FOLKS_MANAGER_H__ */
