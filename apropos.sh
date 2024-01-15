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
release=$(uname -r)

if $DEBUG; then
  cat <<EOF
PATH=$PATH
MANPATH=$MANPATH
bug_page_spaces=$bug_page_spaces
bug_page_spaces_new=$bug_page_spaces_new
bug_page_quotes=$bug_page_quotes
groff_installed=$groff_installed
man_command=$man_command
apropos_command=$apropos_command

EOF
fi

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

$man_command -k socket >/dev/null
test $($man_command -k socket 2>/dev/null | wc -l) -ge 7

# expect a non zero exit if nothing was found
if $man_command -k socket12345 >/dev/null 2>&1; then
  false
else
  true
fi

test $($apropos_command '^cat' | wc -l) -ge 5

# make -K was added in FreeBSD-14.*
if [ $uname = "FreeBSD" ]; then
  case $release in 1[0123].* ) bug_page_fulltext=false;; esac
fi

if $bug_page_fulltext; then
  $man_command -S6 -K 'games'                  > /dev/null 2>&1 || $bug_page_fulltext_exit
  $man_command -S6 -K 'introduction to games'  > /dev/null 2>&1 || $bug_page_fulltext_exit
  $man_command -S6 -K ' introduction to games' > /dev/null 2>&1 || $bug_page_fulltext_exit
  $man_command -S6 -K 'INTRODUCTION TO GAMES'  > /dev/null 2>&1 || $bug_page_fulltext_exit
  $man_command -S6 -K 'INTRODUCTION\s+\S+\s+GAMES'  > /dev/null 2>&1 || $bug_page_fulltext_exit

  if test $uname = "FreeBSD"; then
    test $($man_command -S6 -K 'morse' 2>/dev/null | wc -l) -ge 5
  fi
fi

# no MANPATH variable set
(
unset MANPATH
$man_command -k cat > /dev/null 2>&1
test $($apropos_command '^cat' | wc -l) -ge 5
)

# test -s flag
test $($apropos_command 'socket' | wc -l) -ge 30
counter=$($apropos_command 'socket' | wc -l)
case $uname in FreeBSD ) section=2;; Linux) section=2:3;; *) section=3;; esac
test $($apropos_command -s${section} 'socket' | wc -l) -le $counter

# test -M flag / -k
counter=$($man_command -M /usr/share/man -S6 -k 'intro' | wc -l) 
counter2=$($man_command -M /usr/share/man:/usr/share/man -S6 -k 'intro' | wc -l)
test $counter = $counter2

# test -M flag / -K (fulltext)
if $bug_page_fulltext; then
  case $uname in FreeBSD ) double_m=2;; *) double_m=1;; esac
  counter=$($man_command -M /usr/share/man -S6 -K 'intro' | wc -l) 
  counter2=$($man_command -M /usr/share/man:/usr/share/man -S6 -K 'intro' | wc -l)
  test $(expr $double_m \* $counter) = $counter2
fi

#EOF
