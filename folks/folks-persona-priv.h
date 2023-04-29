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

#ifndef __FOLKS_PERSONA_PRIV_H__
#define __FOLKS_PERSONA_PRIV_H__

#include <libtracker-sparql/tracker-sparql.h>

#include "folks/folks-persona.h"

FolksPersona *folks_persona_new (TrackerSparqlCursor *cursor);

const char *folks_persona_get_urn (FolksPersona *self);

#endif /* __FOLKS_PERSONA_PRIV_H__ */
