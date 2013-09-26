/*
 * broken-client-types-conn.c - a connection with a broken client
 *   types implementation which inexplicably returns presence information!
 *
 * Copyright © 2011 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * Copying and distribution of this file, with or without modification,
 * are permitted in any medium without royalty provided the copyright
 * notice and this notice are preserved.
 */

#include "config.h"

#include "broken-client-types-conn.h"

#include <telepathy-glib/telepathy-glib.h>
#include <telepathy-glib/telepathy-glib-dbus.h>

G_DEFINE_TYPE_WITH_CODE (TpTestsBrokenClientTypesConnection,
    tp_tests_broken_client_types_connection,
    TP_TESTS_TYPE_CONTACTS_CONNECTION,
    G_IMPLEMENT_INTERFACE (TP_TYPE_SVC_CONNECTION_INTERFACE_CLIENT_TYPES,
        NULL);
    );

static void
tp_tests_broken_client_types_connection_init (
    TpTestsBrokenClientTypesConnection *self)
{
}

static void
broken_fill_client_types (
    GObject *object,
    const GArray *contacts,
    GHashTable *attributes)
{
  guint i;

  for (i = 0; i < contacts->len; i++)
    {
      TpHandle handle = g_array_index (contacts, guint, i);
      /* Muahaha. Actually we add Presence information. */
      GValueArray *presence = tp_value_array_build (3,
          G_TYPE_UINT, TP_CONNECTION_PRESENCE_TYPE_AVAILABLE,
          G_TYPE_STRING, "available",
          G_TYPE_STRING, "hi mum!",
          G_TYPE_INVALID);

      tp_contacts_mixin_set_contact_attribute (attributes,
          handle,
          TP_TOKEN_CONNECTION_INTERFACE_PRESENCE_PRESENCE,
          tp_g_value_slice_new_take_boxed (G_TYPE_VALUE_ARRAY, presence));
    }
}

static void
tp_tests_broken_client_types_connection_class_init (
    TpTestsBrokenClientTypesConnectionClass *klass)
{
  TpTestsContactsConnectionClass *cc_class =
      TP_TESTS_CONTACTS_CONNECTION_CLASS (klass);

  cc_class->fill_client_types = broken_fill_client_types;
}
