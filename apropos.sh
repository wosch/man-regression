#!/bin/sh
# Copyright (c) 2023-2024 Wolfram Schneider <wosch@FreeBSD.org>
#
# This script checks if apropos(1) works as designed on FreeBSD.
# It may run on Linux and MacOS as well.
#
# for developing, try:
#
#   env man_command="sh /usr/src/usr.bin/man/man.sh" ./apropos.sh 
#
# in case of an error run this script with: env DEBUG=true
#

set -e

# run in debug mode
: ${debug=1}

# set default values for path
PATH="/bin:/usr/bin:/usr/local/bin"; export PATH
MANPATH="/usr/share/man"; export MANPATH

# known bugs in older FreeBSD releases (< 15.0-CURRENT)
: ${bug_fulltext=true}
: ${bug_fulltext_exit=true}

# man command to test
: ${man_command="/usr/bin/man"}
: ${apropos_command="/usr/bin/apropos"}

# OS specific tests for FreeBSD/Linux/MacOS
uname=$(uname)
release=$(uname -r)

if [ $debug -ge 1 ]; then
  cat <<EOF
PATH=$PATH
MANPATH=$MANPATH
groff_installed=$groff_installed
man_command=$man_command
apropos_command=$apropos_command

EOF

  set | grep '^bug_'
  echo ""
fi

# simple error/exit handler for everything
trap 'exit_handler' 0

# Usage: decho "string" [debuglevel]
# Echoes to stderr string prefaced with -- if high enough debuglevel.
decho() {
  if [ $debug -ge ${2:-1} ]; then
    echo "-- $1" >&2
  fi
}

exit_handler ()
{
  local ret=$?
  if [ $ret = 0 ]; then
    decho ">>> All apropos(1) tests are successfull done <<<"
  else
    echo ""
    echo "A test failed, status=$ret"
    echo "Please run again: env DEBUG=true $0 $@"
  fi

  rm -rf $tmpdir
}

if ! $man_command -k cat > /dev/null 2>&1; then
  printf ">>> Something is really wrong. Please check the script\n$man_command -k cat\n\n" >&2
  exit 2
fi

decho "find path of a manual page: man -k"
$man_command -k '^cat' > /dev/null
decho "find path of a manual page: apropos"
$apropos_command '^cat' > /dev/null

$man_command -k socket >/dev/null
test $($man_command -k socket 2>/dev/null | wc -l) -ge 7

decho "expect a non zero exit if nothing was found"
if $man_command -k socket12345 >/dev/null 2>&1; then
  false
else
  true
fi

test $($apropos_command '^cat' | wc -l) -ge 5

# make -K was added in FreeBSD-14.*
if [ $uname = "FreeBSD" ]; then
  case $release in 1[0123].* ) bug_fulltext=false;; esac
fi

decho "bug_fulltext=$bug_fulltext bug_fulltext_exit=$bug_fulltext_exit" 2
if $bug_fulltext; then
  $man_command -S6 -K 'games'                  > /dev/null 2>&1 || $bug_fulltext_exit
  $man_command -S6 -K 'introduction to games'  > /dev/null 2>&1 || $bug_fulltext_exit
  $man_command -S6 -K ' introduction to games' > /dev/null 2>&1 || $bug_fulltext_exit
  $man_command -S6 -K 'INTRODUCTION TO GAMES'  > /dev/null 2>&1 || $bug_fulltext_exit
  $man_command -S6 -K 'INTRODUCTION\s+\S+\s+GAMES'  > /dev/null 2>&1 || $bug_fulltext_exit

  if test $uname = "FreeBSD"; then
    test $($man_command -S6 -K 'morse' 2>/dev/null | wc -l) -ge 5
  fi
fi

decho "no MANPATH variable set"
(
unset MANPATH
$man_command -k cat > /dev/null 2>&1
test $($apropos_command '^cat' | wc -l) -ge 5
)

decho "test -s flag"
test $($apropos_command 'socket' | wc -l) -ge 30
counter=$($apropos_command 'socket' | wc -l)
case $uname in FreeBSD ) section=2;; Linux) section=2:3;; *) section=3;; esac
test $($apropos_command -s${section} 'socket' | wc -l) -le $counter

decho "test -M flag / -k"
counter=$($man_command -M /usr/share/man -S6 -k 'intro' | wc -l) 
counter2=$($man_command -M /usr/share/man:/usr/share/man -S6 -k 'intro' | wc -l)
test $counter = $counter2

decho "bug_fulltext=$bug_fulltext" 2
if $bug_fulltext; then
  decho "test -M flag / -K (fulltext)"

  case $uname in FreeBSD ) double_m=2;; *) double_m=1;; esac
  counter=$($man_command -M /usr/share/man -S6 -K 'intro' | wc -l) 
  counter2=$($man_command -M /usr/share/man:/usr/share/man -S6 -K 'intro' | wc -l)
  test $(expr $double_m \* $counter) = $counter2
fi

#EOF
