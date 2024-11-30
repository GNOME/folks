Folks development policies
==========================

Code merging
------------
This is the work flow for modifying the folks repository:

1. File a bug for the given flaw or feature (if it does not already exist) at
   https://gitlab.gnome.org/GNOME/folks/issues.

2. Create a fork of the main repository on gitlab.gnome.org (if you haven't
   already) and commit your work there.

3. If this is a non-trivial flaw or feature, write test cases. We won't accept
   significant changes without adequate test coverage.

4. Write code to fix the flaw or add the feature. In the case that tests are
   necessary, the new tests must pass consistently.

5. All code must follow the project coding style (see below).

6. Make a Merge Request from your fork to the main folks repository.

7. The project must remain buildable with all meson options and pass all
   tests on all platforms. It should also pass the CI.

8. Rework your code based on suggestions in the review and submit new patches.
   Return to the review step as necessary.

9. Finally, if everything is reviewed and approved, a maintainer will merge it
   for you. Thanks!

Clean commits
-------------
Commits/patches should be as fine-grained as possible (and no finer). Every
distinct change should be in its own commit and every commit should be a
meaningful change on its own.

As much as possible, the full tree should be buildable and pass all tests at
every commit. There are exceptions, but they're rare. And, of course, it's more
critical that the master branch be buildable (and all tests pass) after every
merge.

Coding style
------------
In general, Folks follows the Telepathy-GLib coding style described in
http://telepathy.freedesktop.org/wiki/Style.

Additional general rules
------------------------
1. All public symbols which support a Valadoc comment block must have one. This
   comment block must also be sufficient for gobject-introspection to adequately
   introspect the symbol for use in other programming languages.

2. Include a @since statement in the comment block for new symbols.

Vala-specific rules
-------------------
1. Any functions which could block must be async.

2. Use the language-native Errors for error reporting, not return values.

3. Take advantage of properties and their automatic `notify` signals as much as
   possible (this eliminates the need for most special accessors, mutators, and
   custom signals and is more conventional).

4. Class function blocks should be indented like GNU/Telepathy-GLib if/while
   blocks. It's arguable that these should be aligned in column 0, as in regular
   C functions, but it's too late to change this (as it would make `git blame`
   useless).

5. Private and internal class data members should begin with a `_` (public data
   members and local variables should not begin with a `_`). This is to make
   non-public data members instantly recognizable as such (which helps
   readability).

6. Private and internal class functions should begin with a `_` (public
   functions should not begin with a `_`). This is to make non-public functions
   instantly recognizable as such (which helps readability).

7. Maximize use of the `var` variable type. This shortens the declarations where
   it's valid, reducing noise.

   Rarely, the use of `var` can obscure the effective type of the variable. In
   this case, it's acceptable to provide an explicit type.

8. Use the `unowned` modifier when it would prevent a non-trivial amount of
   memory allocation. This is most commonly true for strings, arrays, and
   non-reference-counted variables.

   Do not use `unowned` for reference-counted variables (like objects) since it
   reduces readability without benefit. And, as of this writing, bgo#638199
   forces unowned variables to have an explicit type (preventing the use of
   `var`).

9. As in most languages, avoid casting. Casting is usually a sign of an error
   which should be fixed and reduces readability.

10. Refer to non-local variables and methods with their qualified name. Within a
    class function, refer to private data members like `this._foo` and foreign
    package symbols like `package_name.symbol`.

    This makes scope immediately clear, helping readability.

11. Use nullable types correctly. This helps readability (and makes the
    programmer's intentions clearer about whether a variable may be `null`). The
    ultimate goal is for folks to compile correctly with Vala’s strict-non-null
    mode enabled
    (https://docs.vala.dev/tutorials/programming-language/main/05-00-experimental-features/05-03-strict-non-null-mode.html).

12. Place the (private) member variable declaration for a variable which backs a
    property next to the (public) property declaration, rather than at the top
    of the file. This keeps as much of the code pertaining to a property as
    possible in one location.

13. Initialise member variables when declaring them, if possible, rather than in
    a constructor or `construct {}` block. If it’s not possible to initialise a
    member variable at declaration time (e.g. because its value depends on
    another variable), perform the initialisation in a `construct{}` block
    rather than a specific constructor. This means that the initialisation
    doesn’t have to be copied between multiple alternate constructors.

14. When iterating over a `Gee.MultiMap`, try to use the `map_iterator()`.
    This is more efficient than iterating over the result of `get_keys()`,
    then calling `get()` separately for each key.

Build health
------------
1.  Before pushing commits to the mainline branch, the final commit in the
    series must successfully build and pass `meson test` consistently.

2.  After commits have been pushed to mainline, all buildbots must successfully
    build and pass `meson test` on their next build of Folks. It's up to the
    committer to ensure this requirement is met and make necessary changes.

Debugging tests
---------------
To run a single test:

```
meson test -C builddir $test_name
```

If a test ever crashes, you'll probably want to run it through gdb or valgrind.
Meson provides a convenience options for these, and documents these at
http://mesonbuild.com/Unit-tests.html. Some examples:

```
meson test -C $builddir --repeat=100 $test_name
meson test -C $builddir --gdb $test_name
meson test -C $builddir --wrap=valgrind $test_name
```

Thanks to meson's test harness, the output from all tests is logged
automatically to `$builddir/meson-logs/testlog.txt` and in JSON format to
`$builddir/meson-logs/testlog.json`, so no additional options need to be
provided to force verbose output.

Profiling folks
---------------
Folks has various profiling points throughout its startup code, in order to be
able to profile the startup process. In order to use this:
 1. Compile folks with --enable-profiling.
 2. strace -ttt -f -o /tmp/logfile folks-inspect # or some other folks program
 3. python plot-timeline.py -o output.png /tmp/logfile
 4. Examine output.png for obvious problems

This is based on Federico Mena Quintero’s plot-timeline.py, described on:
http://people.gnome.org/~federico/news-2006-03.html#timeline-tools. The Python
script itself can be downloaded from
http://gitorious.org/projects/performance-scripts.

Running folks from JHBuild master
---------------------------------
When running folks from JHBuild master, problems may be caused by running it on
an inappropriate D-Bus session bus, typically resulting in the following error:

> folks-WARNING **: Failed to find primary PersonaStore with type ID 'eds' and
> ID 'system-address-book'.

This is caused by compiling folks against git master of evolution-data-server,
but then running it against an older version with a different API. EDS exposes
its API version in its D-Bus interface, so if the wrong version of EDS is
running, folks can’t find it on the bus, which cripples folks’ EDS backend.
The same principle applies to other D-Bus services which folks relies on, such
as Telepathy.

There are two ways to fix this:
 • If you wish to use your desktop’s session bus, re-compile folks against the
   system versions of EDS and other dependencies, rather than the JHBuild
   versions.
 • If you wish to use the latest version of EDS, run folks in a custom session
   bus, and ensure that the D-Bus configuration for that bus can see the
   .service file for the latest version of EDS. This is discussed here:
   http://www.murrayc.com/permalink/2008/07/16/d-bus-in-jhbuild-confusion-and-hacks/

Environment variables
---------------------
`FOLKS_BACKEND_STORE_KEY_FILE_PATH` sets the keyfile used to control the set
of enabled backends. The default is `g_get_user_data_dir()/folks/backends.ini`,
and if it is empty, all backends are enabled.

If `FOLKS_BACKENDS_ALLOWED` is set, it's a space-, comma- or
colon-separated list of backends to allow, or "all". If unset, the
default is equivalent to "all". Backends not in the list are disallowed,
even if enabled in the keyfile or with enable_backend().

If `FOLKS_BACKENDS_DISABLED` is set, it's a space-, comma- or
colon-separated list of backends to disallow, or "all". If unset, the
default is equivalent to "all". Backends in the list are disallowed,
even if enabled in the keyfile or with enable_backend().
