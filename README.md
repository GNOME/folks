Folks
=====

libfolks is a library that aggregates people from multiple sources (eg,
Telepathy connection managers) to create metacontacts.

## Building
You can build, test and install libfolks using [Meson]:

```sh
meson setup build
meson compile -C build
meson test -C build
meson install -C build
```

Various backends can be enabled or disabled at compile-time. A comprehensive
list of compile-time options can be found at `meson_options.txt`

## Contributing and more information
You can browse the code, issues and more at libfolks' [GitLab repository].

If you want to help out and contribute, you can find more information at our
[wiki page].

To discuss issues with developers and other users, you can post to the [GNOME
discourse] instance or join the [#contacts:gnome.org] Matrix channel.

## License
libfolks is released under the LGPL, version 2.1. See `COPYING` for more info.

[GNOME]: https://www.gnome.org
[Meson]: http://mesonbuild.com
[wiki page]: https://gitlab.gnome.org/GNOME/folks/-/wikis/Home
[GitLab repository]: https://gitlab.gnome.org/GNOME/folks
[GNOME Discourse]: https://discourse.gnome.org
[#contacts:gnome.org]: https://matrix.to/#/#contacts:gnome.org
