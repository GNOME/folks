#
# Helper functions to start your own Tracker instance. This depends
# on you having your own D-Bus session bus started (first).
#
#
# Copyright (C) 2011 Collabora Ltd. <http://www.collabora.co.uk/>
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.

tracker_tmpdir=$(mktemp -d)

tracker_init_settings () {
    export XDG_DATA_HOME=$tracker_tmpdir/.local
    export XDG_CACHE_HOME=$tracker_tmpdir/.cache
    export XDG_CONFIG_HOME=$tracker_tmpdir/.config
}

# This should be called on INT TERM and EXIT
tracker_cleanup () {
    rm -rf $tracker_tmpdir
    rm -rf $tracker_tmpdir
}

tracker_start () {
    tracker-control -r > /dev/null 2>&1
}

tracker_stop () {
    tracker_cleanup
    tracker-control -r > /dev/null 2>&1
}

