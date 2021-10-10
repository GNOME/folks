/* GIO testing utilities
 *
 * Copyright (C) 2008-2010 Red Hat, Inc.
 * Copyright (C) 2012 Collabora Ltd. <http://www.collabora.co.uk/>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General
 * Public License along with this library; if not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: David Zeuthen <davidz@redhat.com>
 *          Xavier Claessens <xavier.claessens@collabora.co.uk>
 */

#include "config.h"

#include <stdlib.h>
#include <stdio.h>
#include <glib/gstdio.h>
#ifdef G_OS_UNIX
#include <unistd.h>
#endif
#ifdef G_OS_WIN32
#include <io.h>
#endif

#include <glib.h>
#include <gio/gio.h>

#include "gtestdbus.h"

#ifdef G_OS_WIN32
#include <windows.h>
#endif

GType
folks_test_dbus_flags_get_type (void)
{
  static gsize g_define_type_id__volatile = 0;

  if (g_once_init_enter (&g_define_type_id__volatile))
    {
      static const GFlagsValue values[] = {
        { FOLKS_TEST_DBUS_NONE, "FOLKS_TEST_DBUS_NONE", "none" },
        { FOLKS_TEST_DBUS_SESSION_BUS, "FOLKS_TEST_DBUS_SESSION_BUS", "session-bus" },
        { FOLKS_TEST_DBUS_SYSTEM_BUS, "FOLKS_TEST_DBUS_SYSTEM_BUS", "system-bus" },
        { 0, NULL, NULL }
      };
      GType g_define_type_id =
        g_flags_register_static (g_intern_static_string ("FolksTestDBusFlags"), values);
      g_once_init_leave (&g_define_type_id__volatile, g_define_type_id);
    }

  return g_define_type_id__volatile;
}

/* -------------------------------------------------------------------------- */
/* Utility: Wait until object has a single ref  */

typedef struct
{
  GMainLoop *loop;
  gboolean   timed_out;
} WeakNotifyData;

static gboolean
on_weak_notify_timeout (gpointer user_data)
{
  WeakNotifyData *data = user_data;
  data->timed_out = TRUE;
  g_main_loop_quit (data->loop);
  return FALSE;
}

static gboolean
dispose_on_idle (gpointer object)
{
  g_object_run_dispose (object);
  g_object_unref (object);
  return FALSE;
}

static gboolean
_g_object_dispose_and_wait_weak_notify (gpointer object)
{
  WeakNotifyData data;
  guint timeout_id;

  data.loop = g_main_loop_new (NULL, FALSE);
  data.timed_out = FALSE;

  g_object_weak_ref (object, (GWeakNotify) g_main_loop_quit, data.loop);

  /* Drop the ref in an idle callback, this is to make sure the mainloop
   * is already running when weak notify happens */
  g_idle_add (dispose_on_idle, object);

  /* Make sure we don't block forever */
  timeout_id = g_timeout_add (30 * 1000, on_weak_notify_timeout, &data);

  g_main_loop_run (data.loop);

  if (data.timed_out)
    {
      g_warning ("Weak notify timeout, object ref_count=%d\n",
          G_OBJECT (object)->ref_count);
    }
  else
    {
      g_source_remove (timeout_id);
    }

  g_main_loop_unref (data.loop);
  return data.timed_out;
}

/* -------------------------------------------------------------------------- */
/* Utilities to cleanup the mess in the case unit test process crash */

#ifdef G_OS_WIN32

/* This could be interesting to expose in public API */
static void
_folks_test_watcher_add_pid (GPid pid)
{
  static gsize started = 0;
  HANDLE job;

  if (g_once_init_enter (&started))
    {
      JOBOBJECT_EXTENDED_LIMIT_INFORMATION info;

      job = CreateJobObjectW (NULL, NULL);
      memset (&info, 0, sizeof (info));
      info.BasicLimitInformation.LimitFlags = 0x2000 /* JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE */;

      if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, &info, sizeof (info)))
        g_warning ("Can't enable JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE: %s", g_win32_error_message (GetLastError()));

      g_once_init_leave (&started,(gsize)job);
    }

  job = (HANDLE)started;

  if (!AssignProcessToJobObject(job, pid))
    g_warning ("Can't assign process to job: %s", g_win32_error_message (GetLastError()));
}

static void
_folks_test_watcher_remove_pid (GPid pid)
{
  /* No need to unassign the process from the job object as the process
     will be killed anyway */
}

#else

#define ADD_PID_FORMAT "add pid %d\n"
#define REMOVE_PID_FORMAT "remove pid %d\n"

static void
watch_parent (gint fd)
{
  GIOChannel *channel;
  GPollFD fds[1];
  GArray *pids_to_kill;

  channel = g_io_channel_unix_new (fd);

  fds[0].fd = fd;
  fds[0].events = G_IO_HUP | G_IO_IN;
  fds[0].revents = 0;

  pids_to_kill = g_array_new (FALSE, FALSE, sizeof (guint));

  do
    {
      gint num_events;
      gchar *command = NULL;
      guint pid;
      guint n;
      GError *error = NULL;

      num_events = g_poll (fds, 1, -1);
      if (num_events == 0)
        continue;

      if (fds[0].revents == G_IO_HUP)
        {
          /* Parent quit, cleanup the mess and exit */
          for (n = 0; n < pids_to_kill->len; n++)
            {
              pid = g_array_index (pids_to_kill, guint, n);
              g_print ("cleaning up pid %d\n", pid);
              kill (pid, SIGTERM);
            }

          g_array_unref (pids_to_kill);
          g_io_channel_shutdown (channel, FALSE, &error);
          g_assert_no_error (error);
          g_io_channel_unref (channel);

          exit (0);
        }

      /* Read the command from the input */
      g_io_channel_read_line (channel, &command, NULL, NULL, &error);
      g_assert_no_error (error);

      /* Check for known commands */
      if (sscanf (command, ADD_PID_FORMAT, &pid) == 1)
        {
          g_array_append_val (pids_to_kill, pid);
        }
      else if (sscanf (command, REMOVE_PID_FORMAT, &pid) == 1)
        {
          for (n = 0; n < pids_to_kill->len; n++)
            {
              if (g_array_index (pids_to_kill, guint, n) == pid)
                {
                  g_array_remove_index (pids_to_kill, n);
                  pid = 0;
                  break;
                }
            }
          if (pid != 0)
            {
              g_warning ("unknown pid %d to remove", pid);
            }
        }
      else
        {
          g_warning ("unknown command from parent '%s'", command);
        }

      g_free (command);
    }
  while (TRUE);
}

static GIOChannel *
watcher_init (void)
{
  static gsize started = 0;
  static GIOChannel *channel = NULL;

  if (g_once_init_enter (&started))
    {
      gint pipe_fds[2];

      /* fork a child to clean up when we are killed */
      if (pipe (pipe_fds) != 0)
        {
          g_warning ("pipe() failed: %m");
          g_assert_not_reached ();
        }

      switch (fork ())
        {
        case -1:
          g_warning ("fork() failed: %m");
          g_assert_not_reached ();
          break;

        case 0:
          /* child */
          close (pipe_fds[1]);
          watch_parent (pipe_fds[0]);
          break;

        default:
          /* parent */
          close (pipe_fds[0]);
          channel = g_io_channel_unix_new (pipe_fds[1]);
        }

      g_once_init_leave (&started, 1);
    }

  return channel;
}

static void
watcher_send_command (const gchar *command)
{
  GIOChannel *channel;
  GError *error = NULL;

  channel = watcher_init ();

  g_io_channel_write_chars (channel, command, -1, NULL, &error);
  g_assert_no_error (error);

  g_io_channel_flush (channel, &error);
  g_assert_no_error (error);
}

/* This could be interesting to expose in public API */
static void
_folks_test_watcher_add_pid (GPid pid)
{
  gchar *command;

  command = g_strdup_printf (ADD_PID_FORMAT, (guint) pid);
  watcher_send_command (command);
  g_free (command);
}

static void
_folks_test_watcher_remove_pid (GPid pid)
{
  gchar *command;

  command = g_strdup_printf (REMOVE_PID_FORMAT, (guint) pid);
  watcher_send_command (command);
  g_free (command);
}

#endif

/* -------------------------------------------------------------------------- */
/* FolksTestDBus object implementation */

/**
 * SECTION:folkstestdbus
 * @short_description: D-Bus testing helper
 * @include: gio/gio.h
 *
 * A helper class for testing code which uses D-Bus without touching the user's
 * system or session bus.
 *
 * Note that #FolksTestDBus modifies the user’s environment, calling setenv().
 * This is not thread-safe, so all #FolksTestDBus calls should be completed before
 * threads are spawned, or should have appropriate locking to ensure no access
 * conflicts to environment variables shared between #FolksTestDBus and other
 * threads.
 *
 * ## Creating unit tests using FolksTestDBus
 *
 * Testing of D-Bus services can be tricky because normally we only ever run
 * D-Bus services over an existing instance of the D-Bus daemon thus we
 * usually don't activate D-Bus services that are not yet installed into the
 * target system. The #FolksTestDBus object makes this easier for us by taking care
 * of the lower level tasks such as running a private D-Bus daemon and looking
 * up uninstalled services in customizable locations, typically in your source
 * code tree.
 *
 * The first thing you will need is a separate service description file for the
 * D-Bus daemon. Typically a `services` subdirectory of your `tests` directory
 * is a good place to put this file.
 *
 * The service file should list your service along with an absolute path to the
 * uninstalled service executable in your source tree. Using autotools we would
 * achieve this by adding a file such as `my-server.service.in` in the services
 * directory and have it processed by configure.
 * |[
 *     [D-BUS Service]
 *     Name=org.gtk.GDBus.Examples.ObjectManager
 *     Exec=@abs_top_builddir@/gio/tests/gdbus-example-objectmanager-server
 * ]|
 * You will also need to indicate this service directory in your test
 * fixtures, so you will need to pass the path while compiling your
 * test cases. Typically this is done with autotools with an added
 * preprocessor flag specified to compile your tests such as:
 * |[
 *     -DTEST_SERVICES=\""$(abs_top_builddir)/tests/services"\"
 * ]|
 *     Once you have a service definition file which is local to your source tree,
 * you can proceed to set up a GTest fixture using the #FolksTestDBus scaffolding.
 *
 * An example of a test fixture for D-Bus services can be found
 * here:
 * [gdbus-test-fixture.c](https://git.gnome.org/browse/glib/tree/gio/tests/gdbus-test-fixture.c)
 *
 * The default behaviour is to create a session bus. The
 * %FOLKS_TEST_DBUS_SESSION_BUS flag may be specified to clarify this, but it
 * isn’t required.
 *
 * If your service needs to run on the system bus, rather than the session
 * bus, pass the %FOLKS_TEST_DBUS_SYSTEM_BUS flag to folks_test_dbus_new(). This
 * will create an isolated system bus. Using two #GTestDBus instances, one
 * with this flag set and one without, a unit test can use isolated services
 * on both the system and session buses.
 *
 * Note that these examples only deal with isolating the D-Bus aspect of your
 * service. To successfully run isolated unit tests on your service you may need
 * some additional modifications to your test case fixture. For example; if your
 * service uses GSettings and installs a schema then it is important that your test service
 * not load the schema in the ordinary installed location (chances are that your service
 * and schema files are not yet installed, or worse; there is an older version of the
 * schema file sitting in the install location).
 *
 * Most of the time we can work around these obstacles using the
 * environment. Since the environment is inherited by the D-Bus daemon
 * created by #FolksTestDBus and then in turn inherited by any services the
 * D-Bus daemon activates, using the setup routine for your fixture is
 * a practical place to help sandbox your runtime environment. For the
 * rather typical GSettings case we can work around this by setting
 * `GSETTINGS_SCHEMA_DIR` to the in tree directory holding your schemas
 * in the above fixture_setup() routine.
 *
 * The GSettings schemas need to be locally pre-compiled for this to work. This can be achieved
 * by compiling the schemas locally as a step before running test cases, an autotools setup might
 * do the following in the directory holding schemas:
 * |[
 *     all-am:
 *             $(GLIB_COMPILE_SCHEMAS) .
 *
 *     CLEANFILES += gschemas.compiled
 * ]|
 */

typedef struct _FolksTestDBusClass   FolksTestDBusClass;
typedef struct _FolksTestDBusPrivate FolksTestDBusPrivate;

/**
 * FolksTestDBus:
 *
 * The #FolksTestDBus structure contains only private data and
 * should only be accessed using the provided API.
 *
 * Since: 2.34
 */
struct _FolksTestDBus {
  GObject parent;

  FolksTestDBusPrivate *priv;
};

struct _FolksTestDBusClass {
  GObjectClass parent_class;
};

struct _FolksTestDBusPrivate
{
  FolksTestDBusFlags flags;
  GPtrArray *service_dirs;
  GPid bus_pid;
  gint bus_stdout_fd;
  gchar *bus_address;
  gboolean up;
};

enum
{
  PROP_0,
  PROP_FLAGS,
};

G_DEFINE_TYPE_WITH_PRIVATE (FolksTestDBus, folks_test_dbus, G_TYPE_OBJECT)

static void
folks_test_dbus_init (FolksTestDBus *self)
{
  self->priv = folks_test_dbus_get_instance_private (self);
  self->priv->service_dirs = g_ptr_array_new_with_free_func (g_free);
}

static void
folks_test_dbus_dispose (GObject *object)
{
  FolksTestDBus *self = (FolksTestDBus *) object;

  if (self->priv->up)
    folks_test_dbus_down (self);

  G_OBJECT_CLASS (folks_test_dbus_parent_class)->dispose (object);
}

static void
folks_test_dbus_finalize (GObject *object)
{
  FolksTestDBus *self = (FolksTestDBus *) object;

  g_ptr_array_unref (self->priv->service_dirs);
  g_free (self->priv->bus_address);

  G_OBJECT_CLASS (folks_test_dbus_parent_class)->finalize (object);
}

static void
folks_test_dbus_get_property (GObject *object,
    guint property_id,
    GValue *value,
    GParamSpec *pspec)
{
  FolksTestDBus *self = (FolksTestDBus *) object;

  switch (property_id)
    {
      case PROP_FLAGS:
        g_value_set_flags (value, folks_test_dbus_get_flags (self));
        break;
      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
folks_test_dbus_set_property (GObject *object,
    guint property_id,
    const GValue *value,
    GParamSpec *pspec)
{
  FolksTestDBus *self = (FolksTestDBus *) object;

  switch (property_id)
    {
      case PROP_FLAGS:
        self->priv->flags = g_value_get_flags (value);
        break;
      default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
folks_test_dbus_class_init (FolksTestDBusClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);

  object_class->dispose = folks_test_dbus_dispose;
  object_class->finalize = folks_test_dbus_finalize;
  object_class->get_property = folks_test_dbus_get_property;
  object_class->set_property = folks_test_dbus_set_property;

  /**
   * FolksTestDBus:flags:
   *
   * #FolksTestDBusFlags specifying the behaviour of the D-Bus session.
   *
   * Since: 2.34
   */
  g_object_class_install_property (object_class, PROP_FLAGS,
    g_param_spec_flags ("flags",
                        "D-Bus session flags",
                        "Flags specifying the behaviour of the D-Bus session",
                        FOLKS_TYPE_TEST_DBUS_FLAGS, FOLKS_TEST_DBUS_NONE,
                        G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY |
                        G_PARAM_STATIC_STRINGS));

}

static gchar *
write_config_file (FolksTestDBus *self)
{
  GString *contents;
  gint fd;
  guint i;
  GError *error = NULL;
  gchar *path = NULL;

  fd = g_file_open_tmp ("g-test-dbus-XXXXXX", &path, &error);
  g_assert_no_error (error);

  contents = g_string_new (NULL);
  g_string_append (contents,
      "<busconfig>\n"
#ifdef G_OS_WIN32
      "  <listen>nonce-tcp:</listen>\n"
#else
      "  <listen>unix:tmpdir=/tmp</listen>\n"
#endif
  );

  if (self->priv->flags & FOLKS_TEST_DBUS_SYSTEM_BUS)
    {
      g_string_append (contents,
          "  <type>system</type>\n");
    }
  else
    {
      g_string_append (contents,
          "  <type>session</type>\n");
    }

  for (i = 0; i < self->priv->service_dirs->len; i++)
    {
      const gchar *dir_path = g_ptr_array_index (self->priv->service_dirs, i);

      g_string_append_printf (contents,
          "  <servicedir>%s</servicedir>\n", dir_path);
    }

  g_string_append (contents,
      "  <policy context=\"default\">\n"
      "    <!-- Allow everything to be sent -->\n"
      "    <allow send_destination=\"*\" eavesdrop=\"true\"/>\n"
      "    <!-- Allow everything to be received -->\n"
      "    <allow eavesdrop=\"true\"/>\n"
      "    <!-- Allow anyone to own anything -->\n"
      "    <allow own=\"*\"/>\n"
      "  </policy>\n"
      "</busconfig>\n");

  g_file_set_contents (path, contents->str, contents->len, &error);
  g_assert_no_error (error);

  g_string_free (contents, TRUE);

  close (fd);

  return path;
}

static void
start_daemon (FolksTestDBus *self)
{
  const gchar *argv[] = {"dbus-daemon", "--print-address", "--config-file=foo", NULL};
  gchar *config_path;
  gchar *config_arg;
  GIOChannel *channel;
  gsize termpos;
  GError *error = NULL;

  if (g_getenv ("G_TEST_DBUS_DAEMON") != NULL)
    argv[0] = (gchar *)g_getenv ("G_TEST_DBUS_DAEMON");

  /* Write config file and set its path in argv */
  config_path = write_config_file (self);
  config_arg = g_strdup_printf ("--config-file=%s", config_path);
  argv[2] = config_arg;

  /* Spawn dbus-daemon */
  g_spawn_async_with_pipes (NULL,
                            (gchar **) argv,
                            NULL,
#ifdef G_OS_WIN32
                            /* We Need this to get the pid returned on win32 */
                            G_SPAWN_DO_NOT_REAP_CHILD |
#endif
                            G_SPAWN_SEARCH_PATH,
                            NULL,
                            NULL,
                            &self->priv->bus_pid,
                            NULL,
                            &self->priv->bus_stdout_fd,
                            NULL,
                            &error);
  g_assert_no_error (error);

  _folks_test_watcher_add_pid (self->priv->bus_pid);

  /* Read bus address from daemon' stdout. We have to be careful to avoid
   * closing the FD, as it is passed to any D-Bus service activated processes,
   * and if we close it, they will get a SIGPIPE and die when they try to write
   * to their stdout. */
  channel = g_io_channel_unix_new (dup (self->priv->bus_stdout_fd));
  g_io_channel_read_line (channel, &self->priv->bus_address, NULL,
      &termpos, &error);
  g_assert_no_error (error);
  self->priv->bus_address[termpos] = '\0';

  /* start dbus-monitor */
  if (g_getenv ("G_DBUS_MONITOR") != NULL)
    {
      gchar *command;

      command = g_strdup_printf ("dbus-monitor --address %s",
          self->priv->bus_address);
      g_spawn_command_line_async (command, NULL);
      g_free (command);

      g_usleep (500 * 1000);
    }

  /* Cleanup */
  g_io_channel_shutdown (channel, FALSE, &error);
  g_assert_no_error (error);
  g_io_channel_unref (channel);

  /* Don't use g_file_delete since it calls into gvfs */
  if (g_unlink (config_path) != 0)
    g_assert_not_reached ();

  g_free (config_path);
  g_free (config_arg);
}

static void
stop_daemon (FolksTestDBus *self)
{
#ifdef G_OS_WIN32
  if (!TerminateProcess (self->priv->bus_pid, 0))
    g_warning ("Can't terminate process: %s", g_win32_error_message (GetLastError()));
#else
  kill (self->priv->bus_pid, SIGTERM);
#endif
  _folks_test_watcher_remove_pid (self->priv->bus_pid);
  g_spawn_close_pid (self->priv->bus_pid);
  self->priv->bus_pid = 0;
  close (self->priv->bus_stdout_fd);
  self->priv->bus_stdout_fd = -1;

  g_free (self->priv->bus_address);
  self->priv->bus_address = NULL;
}

static void
common_envar_unset (void)
{
  /* Always want to unset the starter address since we don't support simulating
   * auto-launched buses */
  g_unsetenv ("DISPLAY");
  g_unsetenv ("DBUS_SESSION_BUS_PID");
  g_unsetenv ("DBUS_SESSION_BUS_WINDOWID");
  g_unsetenv ("DBUS_STARTER_ADDRESS");
  g_unsetenv ("DBUS_STARTER_BUS_TYPE");
}

static void
partial_envar_unset (GBusType bus_type)
{
  common_envar_unset ();

  switch (bus_type)
    {
      case G_BUS_TYPE_SESSION:
        g_unsetenv ("DBUS_SESSION_BUS_ADDRESS");
        break;
      case G_BUS_TYPE_SYSTEM:
        g_unsetenv ("DBUS_SYSTEM_BUS_ADDRESS");
        break;
      case G_BUS_TYPE_STARTER:
      case G_BUS_TYPE_NONE:
      default:
        break;
    }
}

/**
 * folks_test_dbus_new:
 * @flags: a #FolksTestDBusFlags
 *
 * Create a new #FolksTestDBus object.
 *
 * Returns: (transfer full): a new #FolksTestDBus.
 */
FolksTestDBus *
folks_test_dbus_new (FolksTestDBusFlags flags)
{
  return g_object_new (FOLKS_TYPE_TEST_DBUS,
      "flags", flags,
      NULL);
}

/**
 * folks_test_dbus_get_flags:
 * @self: a #FolksTestDBus
 *
 * Get the flags of the #FolksTestDBus object.
 *
 * Returns: the value of #FolksTestDBus:flags property
 */
FolksTestDBusFlags
folks_test_dbus_get_flags (FolksTestDBus *self)
{
  g_return_val_if_fail (FOLKS_IS_TEST_DBUS (self), FOLKS_TEST_DBUS_NONE);

  return self->priv->flags;
}

/**
 * folks_test_dbus_get_bus_address:
 * @self: a #FolksTestDBus
 *
 * Get the address on which dbus-daemon is running. If folks_test_dbus_up() has not
 * been called yet, %NULL is returned. This can be used with
 * g_dbus_connection_new_for_address().
 *
 * Returns: (allow-none): the address of the bus, or %NULL.
 */
const gchar *
folks_test_dbus_get_bus_address (FolksTestDBus *self)
{
  g_return_val_if_fail (FOLKS_IS_TEST_DBUS (self), NULL);

  return self->priv->bus_address;
}

/**
 * folks_test_dbus_add_service_dir:
 * @self: a #FolksTestDBus
 * @path: path to a directory containing .service files
 *
 * Add a path where dbus-daemon will look up .service files. This can't be
 * called after folks_test_dbus_up().
 */
void
folks_test_dbus_add_service_dir (FolksTestDBus *self,
    const gchar *path)
{
  g_return_if_fail (FOLKS_IS_TEST_DBUS (self));
  g_return_if_fail (self->priv->bus_address == NULL);

  g_ptr_array_add (self->priv->service_dirs, g_strdup (path));
}

/**
 * folks_test_dbus_up:
 * @self: a #FolksTestDBus
 *
 * Start a dbus-daemon instance and set <envar>DBUS_SESSION_BUS_ADDRESS</envar>
 * or <envar>DBUS_SYSTEM_BUS_ADDRESS</envar> (if the %FOLKS_TEST_DBUS_SYSTEM_BUS
 * flag was passed to folks_test_dbus_new()). After this call, it is safe for
 * unit tests to start sending messages on the session (or system) bus.
 *
 * If this function is called from the setup callback of g_test_add(),
 * folks_test_dbus_down() must be called in its teardown callback.
 *
 * If this function is called from unit test's main(), then folks_test_dbus_down()
 * must be called after g_test_run().
 *
 * As a side-effect, this function unsets the <envar>DISPLAY</envar>,
 * <envar>DBUS_STARTER_BUS_ADDRESS</envar> and
 * <envar>DBUS_STARTER_BUS_TYPE</envar> environment variables. It does not unset
 * <envar>DBUS_SESSION_BUS_ADDRESS</envar> if a system bus is being spawned,
 * and similarly for <envar>BUS_SYSTEM_BUS_ADDRESS</envar> with a session bus.
 */
void
folks_test_dbus_up (FolksTestDBus *self)
{
  const gchar *envar;
  GBusType bus_type;

  g_return_if_fail (FOLKS_IS_TEST_DBUS (self));
  g_return_if_fail (self->priv->bus_address == NULL);
  g_return_if_fail (!self->priv->up);

  start_daemon (self);

  bus_type = (self->priv->flags & FOLKS_TEST_DBUS_SYSTEM_BUS) ?
      G_BUS_TYPE_SYSTEM :
      G_BUS_TYPE_SESSION;
  partial_envar_unset (bus_type);

  envar = (self->priv->flags & FOLKS_TEST_DBUS_SYSTEM_BUS) ?
      "DBUS_SYSTEM_BUS_ADDRESS" :
      "DBUS_SESSION_BUS_ADDRESS";
  g_setenv (envar, self->priv->bus_address, TRUE);

  self->priv->up = TRUE;
}


/**
 * folks_test_dbus_stop:
 * @self: a #FolksTestDBus
 *
 * Stop the session (or system) bus started by folks_test_dbus_up().
 *
 * Unlike folks_test_dbus_down(), this won't verify the #GDBusConnection
 * singleton returned by g_bus_get() or g_bus_get_sync() is destroyed. Unit
 * tests wanting to verify behaviour after the bus has been stopped
 * can use this function but should still call folks_test_dbus_down() when done.
 */
void
folks_test_dbus_stop (FolksTestDBus *self)
{
  g_return_if_fail (FOLKS_IS_TEST_DBUS (self));
  g_return_if_fail (self->priv->bus_address != NULL);

  stop_daemon (self);
}

/**
 * folks_test_dbus_down:
 * @self: a #FolksTestDBus
 *
 * Stop the session (or system) bus started by folks_test_dbus_up().
 *
 * This will wait for the singleton returned by g_bus_get() or g_bus_get_sync()
 * is destroyed. This is done to ensure that the next unit test won't get a
 * leaked singleton from this test.
 *
 * As a side-effect, this function unsets the <envar>DISPLAY</envar>,
 * <envar>DBUS_STARTER_BUS_ADDRESS</envar> and
 * <envar>DBUS_STARTER_BUS_TYPE</envar> environment variables. It does not unset
 * <envar>DBUS_SESSION_BUS_ADDRESS</envar> if a system bus is being shut down,
 * and similarly for <envar>BUS_SYSTEM_BUS_ADDRESS</envar> with a session bus.
 */
void
folks_test_dbus_down (FolksTestDBus *self)
{
  GBusType bus_type;
  GDBusConnection *connection;

  g_return_if_fail (FOLKS_IS_TEST_DBUS (self));
  g_return_if_fail (self->priv->up);

  bus_type = (self->priv->flags & FOLKS_TEST_DBUS_SYSTEM_BUS) ?
      G_BUS_TYPE_SYSTEM :
      G_BUS_TYPE_SESSION;

  connection = g_bus_get_sync (bus_type, NULL, NULL);
  if (connection != NULL)
    {
      g_dbus_connection_set_exit_on_close (connection, FALSE);
      g_dbus_connection_flush_sync (connection, NULL, NULL);
      g_dbus_connection_close_sync (connection, NULL, NULL);
    }

  if (self->priv->bus_address != NULL)
    stop_daemon (self);

  if (connection != NULL)
    _g_object_dispose_and_wait_weak_notify (connection);

  partial_envar_unset (bus_type);
  self->priv->up = FALSE;
}

/**
 * folks_test_dbus_unset:
 *
 * Unset various D-Bus environment variables to ensure the test won't use the
 * user's session (or system) bus:
 * <itemizedlist>
 * <listitem><para>DISPLAY</para></listitem>
 * <listitem><para>DBUS_SESSION_BUS_ADDRESS</para></listitem>
 * <listitem><para>DBUS_SESSION_BUS_PID</para></listitem>
 * <listitem><para>DBUS_SESSION_BUS_WINDOWID</para></listitem>
 * <listitem><para>DBUS_SYSTEM_BUS_ADDRESS</para></listitem>
 * <listitem><para>DBUS_STARTER_ADDRESS</para></listitem>
 * <listitem><para>DBUS_STARTER_BUS_TYPE</para></listitem>
 * </itemizedlist>
 *
 * This is useful for unit tests that want to verify behaviour when no session
 * (or system) bus is running. It is not necessary to call this if the unit test
 * already calls folks_test_dbus_up() before acquiring the bus.
 */
void
folks_test_dbus_unset (void)
{
  /* See also: partial_envar_unset(). */
  common_envar_unset ();

  g_unsetenv ("DBUS_SESSION_BUS_ADDRESS");
  g_unsetenv ("DBUS_SYSTEM_BUS_ADDRESS");
}
