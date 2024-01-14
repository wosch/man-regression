#!/bin/sh
# Copyright (c) 2023-2024 Wolfram Schneider <wosch@FreeBSD.org>
#
# env man_command="sh /usr/src/usr.bin/man/man.sh" ./basic.sh 
#
# in case of an error run this script with /bin/sh -x

set -e
PATH="/bin:/usr/bin:/usr/local/bin"; export PATH
MANPATH="/usr/share/man"; export MANPATH

# man command to test
: ${man_command="/usr/bin/man"}

# known bugs in older FreeBSD releases
: ${bug_page_spaces=true}
: ${bug_page_spaces_new=true}
: ${bug_page_quotes=false}

MANPATH="/usr/share/man"; export MANPATH

uname=$(uname)

# simple error/exit handler for everything
trap 'exit_handler' 0

exit_handler ()
{
  local ret=$?
  if [ $ret = 0 ]; then
    echo "All man(1) tests are successfull done."
  else
    echo "A test failed, status=$ret"
    echo "Please run again: sh -x $0 $@"
  fi

  rm -rf $tmpdir
}

if ! $man_command cat > /dev/null 2>&1; then
  printf ">>> Something is really wrong. Please check the script\n$man_command cat\n\n" >&2
  exit 2
fi

# find path of a manual page
$man_command -w cat > /dev/null

# debug flag
$man_command -d cat 2> /dev/null
$man_command -d -w cat > /dev/null 2>&1

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
if $man_command -S4 cat >/dev/null 2>&1; then
  false
else
  true
fi

# no MANPATH variable set
( unset MANPATH; $man_command -w cat > /dev/null )

# apropos
$man_command -k socket >/dev/null
test $($man_command -k socket 2>/dev/null | wc -l) -ge 7

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

size=$(expr $($man_command -M /usr/share/man cat | wc -l) '*' 3)
# cat(1) manual page is 200 bytes long
test $($man_command -M /usr/share/man:/usr/share/man -a -P cat cat cat cat 2>/dev/null | wc -l) -ge $size
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
$man_command cp > $man_dir/man1/"c p.1"
$man_command cp | gzip > $man_dir/man1/"c p.1.gz"
test $($man_command -M $man_dir -w "c a t" | wc -l) = 1

test $($man_command -M $man_dir -w "c a t" "m a n" "c p" | wc -l) = 3

# same manpath several times
case $uname in FreeBSD ) count=6;; *) count=3;; esac
test $($man_command -a -M $man_dir:$man_dir -w "c a t" "m a n" "c p" | wc -l) = $count
fi


# multiple copies of a manual pages (gzip'd or not)
$man_command cp >  $man_dir/man1/cp.1
$man_command cp | gzip >  $man_dir/man1/cp.1.gz
test $($man_command -M $man_dir -w cp | wc -l) = 1

# meta shell characters
for i in ';' "'" '(' ')' '[' ']' '&' '>' '<' '#' '|' '*' '_' '-' '?' ' ' '	' '+' '~' '^' '!' '%' ':'
do
  cp $($man_command -w date) "$man_dir/man1/d${i}${i}e.1.gz"
  $man_command "$man_dir/man1/d${i}${i}e.1.gz" >/dev/null
  $man_command -M $man_dir -- "d${i}${i}e" >/dev/null
done


# meta shell characters
if $bug_page_quotes; then
for i in '`' '$' #'$$' '$1' '$2' '$@'
do
  cp $($man_command -w date) "$man_dir/man1/d${i}${i}e.1.gz"
  $man_command "$man_dir/man1/d${i}${i}e.1.gz" >/dev/null
  $man_command -M $man_dir -- "d${i}${i}e" >/dev/null
done
fi

# double quotes
if $bug_page_quotes; then
cp $($man_command -w date) "$man_dir/man1/d\"\"e.1.gz"
cp $($man_command -w date) "$man_dir/man1/d\"e.1.gz"
$man_command "$man_dir/man1/d\"\"e.1.gz" >/dev/null
$man_command "$man_dir/man1/d\"e.1.gz" >/dev/null
$man_command -M $man_dir "d\"\"e" >/dev/null
$man_command -M $man_dir "d\"e" >/dev/null
fi

# lesskey requires groff(1) commandn installed
if [ $uname = "FreeBSD" ]; then
  if PATH=/bin:/usr/bin $man_command lesskey >/dev/null 2>&1; then
    echo "Did you fixed the lesskey(1) manual page?"
    exit 1
  fi

  PATH=/bin:/usr/bin:/usr/local/bin $man_command -M $man_dir cp >/dev/null

  cp $($man_command -w lesskey) "$man_dir/man1/less\"key.1.gz"
  PATH=/bin:/usr/bin:/usr/local/bin $man_command -M $man_dir "less\"key" >/dev/null 2>&1
fi

#EOF
