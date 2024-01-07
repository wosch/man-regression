#!/bin/sh
#

set -e

# man command to test
: ${man_command="/usr/bin/man"}

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

$man_command -w cat > /dev/null

test $($man_command -w cat | wc -l) = 1
test $($man_command -w cat man | wc -l) = 2

test $($man_command cat | wc -l) -gt 70
test $($man_command -S1 cat | wc -l) -gt 70

if $man_command -S3 cat >/dev/null 2>&1; then
  false
else
  true
fi


$man_command -k socket >/dev/null

if $man_command -k socket12345 >/dev/null 2>&1; then
  false
else
  true
fi

tmpdir=$(mktemp -d)
man_dir="$tmpdir/man"
mkdir -p $man_dir/man1

cp $($man_command -w cat) $man_dir/man1

$man_command -M $man_dir -w cat >/dev/null
test $($man_command -M $man_dir -w cat | wc -l) = 1

cp $($man_command -w cat) $man_dir/man1/"c a t.1"
cp $($man_command -w man) $man_dir/man1/"m a n.1"
$man_command $man_dir/man1/"c a t.1" >/dev/null

test $($man_command -M $man_dir -w "c a t" | wc -l) = 1
test $($man_command -M $man_dir -w "m a n" | wc -l) = 1
test $($man_command -M $man_dir -w "c a t" "m a n" | wc -l) = 2

#EOF
