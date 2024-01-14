#!/bin/sh
# Copyright (c) 2023-2024 Wolfram Schneider <wosch@FreeBSD.org>
#
# This script checks if apropos(1) works as designed on FreeBSD.
# It may run on Linux and MacOS as well.
#
# for developing, try:
#
#   env man_command="sh /usr/src/usr.bin/man/man.sh" ./basic.sh 
#
# in case of an error run this script with: env DEBUG=true
#

set -e

# run in debug mode
: ${DEBUG=false}
if $DEBUG; then
  set -x
fi

# set default values for path
PATH="/bin:/usr/bin:/usr/local/bin"; export PATH
MANPATH="/usr/share/man"; export MANPATH

# known bugs in older FreeBSD releases (< 15.0-CURRENT)
: ${bug_page_fulltext=true}
: ${bug_page_fulltext_exit=true}

# man command to test
: ${man_command="/usr/bin/man"}
: ${apropos_command="/usr/bin/apropos"}

# OS specific tests for FreeBSD/Linux/MacOS
uname=$(uname)

# simple error/exit handler for everything
trap 'exit_handler' 0

exit_handler ()
{
  local ret=$?
  if [ $ret = 0 ]; then
    echo "All apropos(1) tests are successfull done."
  else
    echo "A test failed, status=$ret"
    echo "Please run again: env DEBUG=true $0 $@"
  fi

  rm -rf $tmpdir
}

if ! $man_command -k cat > /dev/null 2>&1; then
  printf ">>> Something is really wrong. Please check the script\n$man_command -k cat\n\n" >&2
  exit 2
fi

# find path of a manual page
$man_command -k '^cat' > /dev/null
$apropos_command '^cat' > /dev/null

test $($apropos_command '^cat' | wc -l) -ge 5

if $bug_page_fulltext; then
$man_command -S6 -K 'games'                  > /dev/null 2>&1 || $bug_page_fulltext_exit
$man_command -S6 -K 'introduction to games'  > /dev/null 2>&1 || $bug_page_fulltext_exit
$man_command -S6 -K ' introduction to games' > /dev/null 2>&1 || $bug_page_fulltext_exit
$man_command -S6 -K 'INTRODUCTION TO GAMES'  > /dev/null 2>&1 || $bug_page_fulltext_exit

if test $uname = "FreeBSD"; then
test $($man_command -S6 -K 'morse' 2>/dev/null | wc -l) -ge 5
fi

fi

# no MANPATH variable set
(
unset MANPATH
$man_command -k cat > /dev/null 
test $($apropos_command '^cat' | wc -l) -ge 5
)

#EOF
