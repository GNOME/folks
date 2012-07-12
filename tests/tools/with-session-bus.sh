#!/bin/sh
# with-session-bus.sh - run a program with a temporary D-Bus session daemon
#
# interesting bits have been move into dbus to permit reusability
#
# Copyright (C) 2007-2008 Collabora Ltd. <http://www.collabora.co.uk/>
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.


cur_dir=`dirname $0`

. $cur_dir"/dbus-session.sh"

dbus_parse_args $@
while test "z$1" != "z--"; do
    shift
done
shift
if test "z$1" = "z"; then dbus_usage; fi

cleanup ()
{
    dbus_stop
}

trap cleanup INT HUP TERM

dbus_init 0
dbus_start

e=0

if test -t 1 && test "z$CHECK_VERBOSE" != z; then
  "$@" || e=$?
else
  "$@" > capture-$$.log 2>&1 || e=$?
fi

trap - INT HUP TERM
cleanup

# if exit code is 0, check for skipped tests
if test z$e = z0; then
  grep -i skipped capture-$$.log || true
  rm -f capture-$$.log
# exit code is not 0, so output log and exit
else
  cat capture-$$.log
  exit $e
fi
