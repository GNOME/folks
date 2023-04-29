/*
 * Copyright 2022 Corentin Noël <corentin.noel@collabora.com>
 * SPDX-License-Identifier: GPL-2.0-or-later
 */

#include "folksd-config.h"

#include <glib.h>
#include <locale.h>
#include <stdlib.h>

#include "folksd-contacts-miner.h"

gint
main (gint   argc,
      gchar *argv[])
{
  g_autoptr(GOptionContext) context = NULL;
  g_autoptr(GError) error = NULL;
  g_autoptr(EdmContactsMiner) contacts_miner = NULL;
  gboolean version = FALSE;
  GOptionEntry main_entries[] = {
    { "version", 0, 0, G_OPTION_ARG_NONE, &version, "Show program version", NULL },
    G_OPTION_ENTRY_NULL
  };

  setlocale (LC_ALL, "");

  context = g_option_context_new ("- my command line tool");
  g_option_context_add_main_entries (context, main_entries, NULL);

  if (!g_option_context_parse (context, &argc, &argv, &error))
    {
      g_printerr ("%s\n", error->message);
      return EXIT_FAILURE;
    }

  if (version)
    {
      g_printerr ("%s\n", PACKAGE_VERSION);
      return EXIT_SUCCESS;
    }

  g_autoptr(GMainLoop) main_loop = g_main_loop_new (NULL, TRUE);
  contacts_miner = edm_contacts_miner_new ();
  g_main_loop_run (main_loop);
  return EXIT_SUCCESS;
}
