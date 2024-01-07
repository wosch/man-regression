#!/bin/sh
#

set -e

# man command to test
: ${man="/usr/bin/man"}

MANPATH="/usr/share/man"; export MANPATH

trap 'exit_handler' 0

exit_handler ()
{
  if [ $? = 0 ]; then
    echo "all tests are successfull done"
  else
    echo "A test failed: $?"
  fi
}

$man -w cat > /dev/null

test $($man -w cat | wc -l) = 1
#test $($man -w cat man | wc -l) = 2

test $($man cat | wc -l) -gt 70
test $($man -S1 cat | wc -l) -gt 70

if $man -S3 cat >/dev/null; then
  false
else
  true
fi


$man -k socket >/dev/null

if $man -k socket12345 >/dev/null; then
  false
else
  true
fi

#EOF
