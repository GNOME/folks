Folks
=====

libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

## Building
You can build and install libfolks using [Meson]:

```sh
meson build
ninja -C build
ninja -C build install
```

Various backends can be enabled or disabled at compile-time. A comprehensive
list of compile-time options can be found at `meson_options.txt`

## Contributing
You can browse the code, issues and more at libfolks' [GitLab repository].

If you find a bug in libfolks, please file an issue on the [issue tracker].
Please try to add reproducible steps and the relevant version of libfolks.

If you want to contribute functionality or bug fixes, please open a Merge
Request (MR). For more info on how to do this, see GitLab's [help pages on
MR's]. Please also follow our coding conventions, as described in
CONTRIBUTING.md

If libfolks is not translated in your language or you believe that the current
translation has errors, you can join one of the various translation teams in
GNOME. Translators do not commit directly to Git, but are advised to use our
separate translation infrastructure instead. More info can be found at the
[translation project wiki page].

## More information
libfolks has its own web page on https://wiki.gnome.org/Projects/Folks.

The latest version of the documentation is also published online by our CI to
the GitLab Pages of our repository. You can find the documentation for both the
[Vala API] as well as the [C API].

To discuss issues with developers and other users, you can post to the [GNOME
discourse] instance or join [#contacts] on irc.gnome.org.

## License
libfolks is released under the LGPL, version 2.1. See `COPYING` for more info.

[GNOME]: https://www.gnome.org
[Meson]: http://mesonbuild.com
[GitLab repository]: https://gitlab.gnome.org/GNOME/folks
[help pages on MR's]: https://docs.gitlab.com/ee/gitlab-basics/add-merge-request.html
[issue tracker]: https://gitlab.gnome.org/GNOME/folks/issues
[translation project wiki page]: https://wiki.gnome.org/TranslationProject/
[GNOME Discourse]: https://discourse.gnome.org
[Vala API]: https://gnome.pages.gitlab.gnome.org/folks/devhelp/folks/index.htm
[C API]: https://gnome.pages.gitlab.gnome.org/folks/gtkdoc/folks/
[#contacts]: irc://irc.gnome.org/contacts
