#!/bin/sh
# Copyright (c) 2023-2024 Wolfram Schneider <wosch@FreeBSD.org>
#
# This script checks if man(1) works as designed on FreeBSD.
# It may run on Linux and MacOS as well.
#
# for developing, try:
#
#   env man_command="sh /usr/src/usr.bin/man/man.sh" ./man.sh 
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
: ${bug_spaces=true}
: ${bug_spaces_new=true}
: ${bug_meta_characters=true}
: ${bug_quotes=true}
: ${bug_corrupt_gzip=true}
: ${bug_huge_manpage=true}
: ${bug_ulimit_cpu=true}
: ${bug_so=true}

# optional package groff
: ${groff_installed=true}

# man command to test
: ${man_command="/usr/bin/man"}

# OS specific tests for FreeBSD/Linux/MacOS
uname=$(uname)

# simple error/exit handler for everything
trap 'exit_handler' 0

if [ $debug -ge 1 ]; then
  cat <<EOF
PATH=$PATH
MANPATH=$MANPATH
groff_installed=$groff_installed
man_command=$man_command

EOF

  set | grep '^bug_'
  echo ""
fi

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
    decho ">>> All man(1) tests are successfull done <<<"
  else
    echo ""
    echo "A test failed, status=$ret"
    if [ $debug -le 0 ]; then
      echo "Please run again: env debug=1 $0 $@"
    fi
  fi

  rm -rf $tmpdir
}

decho "basic test"
if ! $man_command cat > /dev/null 2>&1; then
  printf ">>> Something is really wrong. Please check the script\n$man_command cat\n\n" >&2
  exit 2
fi

decho "find path of a manual page"
$man_command -w cat > /dev/null

decho "debug flag"
$man_command -d cat > /dev/null 2>&1
$man_command -d -w  cat > /dev/null 2>&1

decho "once"
test $($man_command -w cat | wc -l) = 1

decho "bug_spaces_new=$bug_spaces_new" 2
if $bug_spaces_new; then
  decho "twice"
  test $($man_command -w cat man | wc -l) = 2
fi

decho "cat(1) is larger than NN bytes"
test $($man_command cat | wc -l) -gt 60

decho "cat(1) is in section 1"
$man_command -S1 cat >/dev/null
test $($man_command -S1 cat | wc -l) -gt 60

decho "cat(1) is not in section 3"
if $man_command -S4 cat >/dev/null 2>&1; then
  false
else
  true
fi

decho "no MANPATH variable set"
( unset MANPATH; $man_command -w cat > /dev/null )

decho "searching for more than one manual page"
if $bug_spaces_new; then
  $man_command -P cat cat >/dev/null
  $man_command 1 cat >/dev/null
  $man_command -M /usr/share/man:/usr/share/man -a 1 cat man >/dev/null
  $man_command -M /usr/share/man:/usr/share/man -a -P cat 1 man man man >/dev/null

  size=$(expr $($man_command -M /usr/share/man cat | wc -l) '*' 3)
  decho "cat(1) manual page is 200 bytes long"
  test $($man_command -M /usr/share/man:/usr/share/man -a -P cat cat cat cat 2>/dev/null | wc -l) -ge $size
fi

# temporary manpath
tmpdir=$(mktemp -d)
man_dir="$tmpdir/man"
mkdir -p $man_dir/man1

cp $($man_command -w cat) $man_dir/man1

decho "basic cat"
$man_command -M $man_dir -w cat >/dev/null
test $($man_command -M $man_dir -w cat | wc -l) = 1

decho "bug_spaces=$bug_spaces" 2
if $bug_spaces; then
  # create manual pages with spaces in filenames
  cp $($man_command -w cat) $man_dir/man1/"c a t.1"
  cp $($man_command -w man) $man_dir/man1/"m a n.1"

  decho "run man(1) on path with spaces"
  $man_command $man_dir/man1/"c a t.1" >/dev/null

  test $($man_command -M $man_dir -w "c a t" | wc -l) = 1
  test $($man_command -M $man_dir -w "m a n" | wc -l) = 1
  test $($man_command -M $man_dir -w "c a t" "m a n" | wc -l) = 2

  decho "multiple copies of a manual pages (gzip'd or not), with spaces"
  $man_command cp > $man_dir/man1/"c p.1"
  $man_command cp | gzip > $man_dir/man1/"c p.1.gz"
  test $($man_command -M $man_dir -w "c a t" | wc -l) = 1

  test $($man_command -M $man_dir -w "c a t" "m a n" "c p" | wc -l) = 3

  decho "same manpath several times"
  case $uname in FreeBSD ) count=6;; *) count=3;; esac
  test $($man_command -a -M $man_dir:$man_dir -w "c a t" "m a n" "c p" | wc -l) = $count
fi


decho "multiple copies of a manual pages (gzip'd or not)"
$man_command cp >  $man_dir/man1/cp.1
$man_command cp | gzip >  $man_dir/man1/cp.1.gz
test $($man_command -M $man_dir -w cp | wc -l) = 1

decho "bug_meta_characters=$bug_meta_characters" 2
if $bug_meta_characters; then
  decho "meta shell characters"

  for i in ';' "'" '(' ')' '[' ']' '&' '>' '<' '#' '|' '*' '_' '-' '?' ' ' '	' '+' '~' '^' '!' '%' ':' '@'
  do
    cp $($man_command -w cal) "$man_dir/man1/d${i}${i}e.1.gz"
    $man_command "$man_dir/man1/d${i}${i}e.1.gz" >/dev/null
    $man_command -M $man_dir -- "d${i}${i}e" >/dev/null
  done
fi

decho "bug_quotes=$bug_quotes" 2
if $bug_quotes; then
  decho "meta shell characters, second round"
  for i in '`' '$' '$$' '$1' '$2' '$@' '$*'
  do
    cp $($man_command -w cal) "$man_dir/man1/d${i}${i}e.1.gz"
    $man_command "$man_dir/man1/d${i}${i}e.1.gz" >/dev/null
    $man_command -M $man_dir -- "d${i}${i}e" >/dev/null
  done

  decho "double quotes"
  cp $($man_command -w cal) "$man_dir/man1/d\"\"e.1.gz"
  cp $($man_command -w cal) "$man_dir/man1/d\"e.1.gz"
  $man_command "$man_dir/man1/d\"\"e.1.gz" >/dev/null
  $man_command "$man_dir/man1/d\"e.1.gz" >/dev/null
  $man_command -M $man_dir "d\"\"e" >/dev/null
  $man_command -M $man_dir "d\"e" >/dev/null
fi

decho "no arguments"
if $man_command >/dev/null 2>&1; then
  echo "calling man(1) without arguments should be a failure"
  exit 1
fi

# lesskey requires groff(1) commandn installed
if test $uname = "FreeBSD" && $groff_installed; then
  decho "lesskey requires groff(1) commandn installed"
  if ! env PATH=/bin:/usr/bin:/usr/local/bin which groff >/dev/null; then
    echo "Please install groff(1): pkg install groff"
    echo "or run with: env groff_installed=false $0 $@"
    echo ""
    exit 1
  fi

  if env PATH=/bin:/usr/bin $man_command lesskey >/dev/null 2>&1; then
    echo "Did you fixed the lesskey(1) manual page?"
    exit 1
  fi

  env PATH=/bin:/usr/bin:/usr/local/bin $man_command -M $man_dir cp >/dev/null

  if $bug_quotes; then
  cp $($man_command -w lesskey) "$man_dir/man1/less\"key.1.gz"
  env PATH=/bin:/usr/bin:/usr/local/bin $man_command -M $man_dir "less\"key" >/dev/null 2>&1
  fi
fi

decho "bug_huge_manpage=$bug_huge_manpage" 2
if $bug_huge_manpage; then
  # may reproce warnings due SIGPIPE
  decho "man(1) should work with huge manual pages"

  # test with tcsh or bash page if available
  if $man_command -w tcsh >/dev/null 2>&1; then
    $man_command tcsh >/dev/null
  fi
  if $man_command -w bash >/dev/null 2>&1; then
    $man_command bash >/dev/null
  fi
fi

decho "bug_ulimit_cpu=$bug_ulimit_cpu" 2
if $bug_ulimit_cpu; then
  decho "if man(1) gets killed by a CPU limit, it need to stop with a non-zero exit status"
  # this test will runs for at least a CPU second

  zcat /usr/share/man/man1/*.gz | gzip > $man_dir/man1/huge.1.gz
  if ( ulimit -t 1; $man_command $man_dir/man1/huge.1.gz >/dev/null 2>&1 ); then
    echo "man got killed, but exit status is zero"
    exit 1
  fi
fi

decho "bug_corrupt_gzip=$bug_corrupt_gzip" 2
if $bug_corrupt_gzip; then
  decho "a corrupt compressed file should report an error"

  $man_command sh > $man_dir/man1/sh.1
  gzip < $man_dir/man1/sh.1 2>/dev/null | head -n1 > $man_dir/man1/sh.1.gz
  rm -f $man_dir/man1/sh.1

  if gzip -t $man_dir/man1/sh.1.gz >/dev/null 2>&1; then
    echo "Oops, please rewrite the test"
    exit 1
  fi

  if $man_command $man_dir/man1/sh.1.gz >/dev/null 2>&1; then
    echo "calling man(1) on a broken gzip'd file should report an error"
    exit 1
  fi
  if $man_command -M $man_dir sh >/dev/null 2>&1; then
    echo "calling man(1) -M on a broken gzip'd file should report an error"
    exit 1
  fi

  touch $man_dir/man1/foobar.1.gz
  if $man_command $man_dir/man1/foobar.1.gz >/dev/null 2>&1; then
    echo "calling man(1) on a empty gzip'd file should report an error"
    exit 1
  fi
  if $man_command -M $man_dir foobar >/dev/null 2>&1; then
    echo "calling man(1) -M on a empty gzip'd file should report an error"
    exit 1
  fi
fi

decho "bug_so=$bug_so" 2
if $bug_so; then
  decho ".so man1/bla.1 filename space bug"
  # filename space bug / exists() function with empty arguments

  (
  cd "$man_dir"
  cp $($man_command -w cat) "$man_dir/man1/dog.1.gz"
  echo ".so man1/dog.1" > $man_dir/man1/kitty.1
  if ! $man_command -M $man_dir -w kitty | grep '^/.*/dog.1.gz$' >/dev/null; then
    echo "cound not find .so file" >&2
    exit 1
  fi

  gzip -f $man_dir/man1/kitty.1
  if ! $man_command -M $man_dir -w kitty | grep '^/.*/dog.1.gz$' >/dev/null; then
    echo "cound not find .so file / gzip" >&2
    exit 1
  fi

  if ! $man_command -w $man_dir/man1/kitty.1.gz | grep '^/.*/dog.1.gz$' >/dev/null; then
    echo "man -w: cound not find .so file" >&2
    exit 1
  fi

  if ! $man_command $man_dir/man1/kitty.1.gz >/dev/null; then
    echo "man: cound not find .so file" >&2
    exit 1
  fi
  )
fi

#EOF
