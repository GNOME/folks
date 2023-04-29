/*
 * Copyright 2022 Corentin Noël <corentin.noel@collabora.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */
#include "folksd-utils.h"

/**
 * folksd_utils_create_addressbook:
 * @uid: Unique ID
 * @display_name: (nullable): Display name of the Addressbook
 *
 * Creates a new addressbook with the given @uid and @display_name.
 *
 * Returns: (transfer full): a #TrackerResource
 */
TrackerResource *
folksd_utils_create_addressbook (const char *uid,
                                 const char *display_name)
{
  g_autofree char *uri = NULL;
  TrackerResource *resource;

  g_return_val_if_fail (uid != NULL, NULL);

  uri = tracker_sparql_escape_uri_printf ("urn:addressbook:%s", uid);
  resource = tracker_resource_new (uri);
  tracker_resource_set_uri (resource, "rdf:type", "nco:ContactList");
  if (display_name)
    tracker_resource_set_string (resource, "nie:title", display_name);

  return resource;
}
