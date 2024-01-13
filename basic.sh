#!/bin/sh
#
# env man_command="sh $HOME/projects/src/usr.bin/man/man.sh" ./basic.sh 
#
# in case of an error run this script with /bin/sh -x

set -e

# man command to test
: ${man_command="/usr/bin/man"}

: ${bug_page_spaces=false}
: ${bug_page_spaces_new=false}

MANPATH="/usr/share/man"; export MANPATH

# simple error/exit handler for everything
trap 'exit_handler' 0

exit_handler ()
{
  local ret=$?
  if [ $ret = 0 ]; then
    echo "all tests are successfull done"
  else
    echo "A test failed, status=$ret"
    echo "Please run again: sh -x $0 $@"
  fi

  rm -rf $tmpdir
}

# find path of a manual page
$man_command -w cat > /dev/null

# once
test $($man_command -w cat | wc -l) = 1

# twice
if $bug_page_spaces_new; then
test $($man_command -w cat man | wc -l) = 2
fi

# cat(1) is larger than NN bytes
test $($man_command cat | wc -l) -gt 60

# cat(1) is in section 1
$man_command -S1 cat >/dev/null
test $($man_command -S1 cat | wc -l) -gt 60

# cat(1) is not in section 3
if $man_command -S3 cat >/dev/null 2>&1; then
  false
else
  true
fi

# no MANPATH variable set
( unset MANPATH; $man_command -w cat > /dev/null )

# apropos
$man_command -k socket >/dev/null
test $($man_command -k socket 2>/dev/null | wc -l) -gt 40

# expect a non zero exit if nothing was found
if $man_command -k socket12345 >/dev/null 2>&1; then
  false
else
  true
fi

if $bug_page_spaces_new; then

$man_command -P cat cat >/dev/null
$man_command 1 cat >/dev/null
$man_command -M /usr/share/man:/usr/share/man -a 1 cat man >/dev/null

$man_command -M /usr/share/man:/usr/share/man -a -P cat 1 man man man >/dev/null

# cat(1) manual page is 200 bytes long
test $($man_command -M /usr/share/man:/usr/share/man -a -P cat cat cat cat 2>/dev/null | wc -l) -ge 600
fi

# temporary manpath
tmpdir=$(mktemp -d)
man_dir="$tmpdir/man"
mkdir -p $man_dir/man1

cp $($man_command -w cat) $man_dir/man1

$man_command -M $man_dir -w cat >/dev/null
test $($man_command -M $man_dir -w cat | wc -l) = 1

# create manual pages with spaces in filenames
cp $($man_command -w cat) $man_dir/man1/"c a t.1"
cp $($man_command -w man) $man_dir/man1/"m a n.1"

# run man(1) on path with spaces
$man_command $man_dir/man1/"c a t.1" >/dev/null

# run man(1) on page with spaces
if $bug_page_spaces; then
test $($man_command -M $man_dir -w "c a t" | wc -l) = 1
test $($man_command -M $man_dir -w "m a n" | wc -l) = 1
test $($man_command -M $man_dir -w "c a t" "m a n" | wc -l) = 2

# multiple copies of a manual pages (gzip'd or not), with spaces
cp $($man_command -w cp) $man_dir/man1/"c p.1.gz"
gunzip $man_dir/man1/"c p.1.gz"
cp $($man_command -w cp) $man_dir/man1/"c p.1.gz"
test $($man_command -M $man_dir -w "c a t" | wc -l) = 1

test $($man_command -M $man_dir -w "c a t" "m a n" "c p" | wc -l) = 3
test $($man_command -a -M $man_dir:$man_dir -w "c a t" "m a n" "c p" | wc -l) = 6
fi

# multiple copies of a manual pages (gzip'd or not)
cp $($man_command -w cp) $man_dir/man1/cp.1.gz
gunzip $man_dir/man1/cp.1.gz
cp $($man_command -w cp) $man_dir/man1/cp.1.gz
test $($man_command -M $man_dir -w cp | wc -l) = 1


#EOF
