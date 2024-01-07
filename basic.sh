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

  rm -rf $tmpdir
}

$man -w cat > /dev/null

test $($man -w cat | wc -l) = 1
#test $($man -w cat man | wc -l) = 2

test $($man cat | wc -l) -gt 70
test $($man -S1 cat | wc -l) -gt 70

if $man -S3 cat >/dev/null 2>&1; then
  false
else
  true
fi


$man -k socket >/dev/null

if $man -k socket12345 >/dev/null 2>&1; then
  false
else
  true
fi

tmpdir=$(mktemp -d)
man_dir="$tmpdir/man"
mkdir -p $man_dir/man1

cp $($man -w cat) $man_dir/man1

$man -M $man_dir -w cat >/dev/null
test $($man -M $man_dir -w cat | wc -l) = 1

cp $($man -w cat) $man_dir/man1/"c a t.1"
$man $man_dir/man1/"c a t.1" >/dev/null

#test $($man -M $man_dir -w "c a t" | wc -l) = 1

#EOF
