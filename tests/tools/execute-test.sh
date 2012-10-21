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

e=0

if test -t 1 && test "z$CHECK_VERBOSE" != z; then
  "$@" || e=$?
else
  "$@" > capture-$$.log 2>&1 || e=$?
fi

# if exit code is 0, check for skipped tests
if test z$e = z0; then
  if test -f capture-$$.log; then
    grep -i skipped capture-$$.log || true
  fi
  rm -f capture-$$.log
# exit code is not 0, so output log and exit
else
  cat capture-$$.log
  exit $e
fi
