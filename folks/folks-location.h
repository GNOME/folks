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

#ifndef __FOLKS_LOCATION_H__
#define __FOLKS_LOCATION_H__

#include <glib-object.h>

G_BEGIN_DECLS

#define FOLKS_TYPE_LOCATION (folks_location_get_type())

G_DECLARE_FINAL_TYPE (FolksLocation, folks_location, FOLKS, LOCATION, GObject)

FolksLocation *folks_location_new (void);

G_END_DECLS

#endif /* __FOLKS_LOCATION_H__ */
