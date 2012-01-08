/*
 * Copyright (C) 2010 Collabora Ltd.
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
 *
 * Authors:
 *       Philip Withnall <philip.withnall@collabora.co.uk>
 */

using Folks.Inspect.Commands;
using Folks;
using Readline;
using Gee;
using GLib;

/* We have to have a static global instance so that the readline callbacks can
 * access its data, since they don't pass closures around. */
static Inspect.Client main_client = null;

public class Folks.Inspect.Client : Object
{
  public HashMap<string, Command> commands;
  private MainLoop main_loop;
  private unowned Thread folks_thread;
  public IndividualAggregator aggregator { get; private set; }
  public BackendStore backend_store { get; private set; }
  public SignalManager signal_manager { get; private set; }

  public static int main (string[] args)
    {
      Intl.bindtextdomain (BuildConf.GETTEXT_PACKAGE, BuildConf.LOCALE_DIR);
      Intl.textdomain (BuildConf.GETTEXT_PACKAGE);

      /* Parse command line options. */
      OptionContext context = new OptionContext ("[COMMAND]");
      context.set_summary ("Inspect meta-contact information in libfolks.");

      try
        {
          context.parse (ref args);
        }
      catch (OptionError e1)
        {
          stderr.printf ("Couldn’t parse command line options: %s\n",
              e1.message);
          return 1;
        }

      /* Create the client and run the command. */
      main_client = new Client ();

      if (args.length == 1)
        {
          main_client.run_interactive ();
        }
      else
        {
          assert (args.length > 1);

          /* Drop the first argument and parse the rest as a command line. If
           * the first argument is ‘--’ then the command was passed after some
           * flags. */
          string command_line;
          if (args[1] == "--")
            {
              command_line = string.joinv (" ", args[2:0]);
            }
          else
            {
              command_line = string.joinv (" ", args[1:0]);
            }

          main_client.run_non_interactive (command_line);
        }

      return 0;
    }

  public Client ()
    {
      Utils.init ();

      this.commands = new HashMap<string, Command> (str_hash, str_equal);

      /* Register the commands we support */
      /* FIXME: This should be automatic */
      this.commands.set ("quit", new Commands.Quit (this));
      this.commands.set ("help", new Commands.Help (this));
      this.commands.set ("individuals", new Commands.Individuals (this));
      this.commands.set ("linking", new Commands.Linking (this));
      this.commands.set ("personas", new Commands.Personas (this));
      this.commands.set ("backends", new Commands.Backends (this));
      this.commands.set ("persona-stores", new Commands.PersonaStores (this));
      this.commands.set ("signals", new Commands.Signals (this));
      this.commands.set ("debug", new Commands.Debug (this));

      /* Create various bits of folks machinery. */
      this.main_loop = new MainLoop ();
      this.signal_manager = new SignalManager ();
      this.backend_store = BackendStore.dup ();
      this.aggregator = new IndividualAggregator ();
    }

  private async void _wait_for_quiescence () throws GLib.Error
    {
      var has_yielded = false;
      var signal_id = this.aggregator.notify["is-quiescent"].connect (
          (obj, pspec) =>
        {
          if (has_yielded == true)
            {
              this._wait_for_quiescence.callback ();
            }
        });

      try
        {
          yield this.aggregator.prepare ();

          if (this.aggregator.is_quiescent == false)
            {
              has_yielded = true;
              yield;
            }
        }
      finally
        {
          this.aggregator.disconnect (signal_id);
          assert (this.aggregator.is_quiescent == true);
        }
    }

  public void run_non_interactive (string command_line)
    {
      /* Non-interactive mode: run a single command and output the results.
       * We do this all from the main thread, in a main loop, waiting for
       * quiescence before running the command. */

      /* Check we can parse the command first. */
      string subcommand;
      string command_name;
      var command = this.parse_command_line (command_line, out command_name,
          out subcommand);

      if (command == null)
        {
          stdout.printf ("Unrecognised command ‘%s’.\n", command_name);
          return;
        }

      /* Wait until we reach quiescence, or the results will probably be
       * useless. */
      this._wait_for_quiescence.begin ((obj, res) =>
        {
          try
            {
              this._wait_for_quiescence.end (res);
            }
          catch (GLib.Error e1)
            {
              stderr.printf ("Error preparing aggregator: %s\n", e1.message);
              Process.exit (1);
            }

          /* Run the command */
          command.run (subcommand);

          this.main_loop.quit ();
        });

      this.main_loop.run ();
    }

  private void *folks_thread_main ()
    {
      this.aggregator.prepare ();
      this.main_loop.run ();

      return null;
    }

  public void run_interactive ()
    {
      /* Interactive mode: have a little shell which allows the data from
       * libfolks to be browsed and edited in real time. We do this by spawning
       * a second thread which takes care of the main loop and aggregator. The
       * main thread then sits in a readline loop. */

      /* Spawn the folks worker thread. */
      try
        {
          this.folks_thread = Thread<void*>.create<void*> (
              this.folks_thread_main, true);
        }
      catch (ThreadError e)
        {
          stdout.printf ("Couldn't create aggregator thread: %s", e.message);
          Process.exit (1);
        }

      /* Allow things to be set for folks-inspect in ~/.inputrc, and install our
       * own completion function. */
      Readline.readline_name = "folks-inspect";
      Readline.attempted_completion_function = Client.completion_cb;

      /* Main prompt loop */
      while (true)
        {
          string command_line = Readline.readline ("> ");

          if (command_line == null)
            continue;

          command_line = command_line.strip ();
          if (command_line == "")
            continue;

          string subcommand;
          string command_name;
          Command command = this.parse_command_line (command_line,
              out command_name, out subcommand);

          /* Run the command */
          if (command != null)
            command.run (subcommand);
          else
            stdout.printf ("Unrecognised command '%s'.\n", command_name);

          /* Store the command in the history, even if it failed */
          Readline.History.add (command_line);
        }
    }

  private static Command? parse_command_line (string command_line,
      out string command_name,
      out string? subcommand)
    {
      /* Default output */
      command_name = "";
      subcommand = null;

      string[] parts = command_line.split (" ", 2);

      if (parts.length < 1)
        return null;

      command_name = parts[0];
      if (parts.length == 2 && parts[1] != "")
        subcommand = parts[1];
      else
        subcommand = null;

      /* Extract the first part of the command and see if it matches anything in
       * this.commands */
      return main_client.commands.get (parts[0]);
    }

  [CCode (array_length = false, array_null_terminated = true)]
  private static string[]? completion_cb (string word,
      int start,
      int end)
    {
      /* word is the word to complete, and start and end are its bounds inside
       * Readline.line_buffer, which contains the entire current line. */

      /* Command name completion */
      if (start == 0)
        {
          return Readline.completion_matches (word,
              Utils.command_name_completion_cb);
        }

      /* Command parameter completion is passed off to the Command objects */
      string command_name;
      string subcommand;
      Command command = Client.parse_command_line (Readline.line_buffer,
          out command_name,
          out subcommand);

      if (command != null)
        {
          if (subcommand == null)
            subcommand = "";
          return command.complete_subcommand (subcommand);
        }

      return null;
    }
}

private abstract class Folks.Inspect.Command
{
  protected Client client;

  public Command (Client client)
    {
      this.client = client;
    }

  public abstract string name { get; }
  public abstract string description { get; }
  public abstract string help { get; }

  public abstract void run (string? command_string);

  public virtual string[]? complete_subcommand (string subcommand)
    {
      /* Default implementation */
      return null;
    }
}
