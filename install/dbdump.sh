#!/bin/bash

cd "$( dirname "$0" )"

DB_NAME='[% wp.DB_NAME %]'
DB_USER='[% wp.DB_USER %]'
DB_PASSWORD='[% wp.DB_PASSWORD %]'
DB_HOST='[% wp.DB_HOST %]'
CALLBACK='[% whupup.callback %]'
POLLFILE='[% whupup.pollfile %]'

OUT="sql"

MYSQL=$( which mysql )
MYSQLDUMP=$( which mysqldump )
WGET=$( which wget )
CURL=$( which curl )
LYNX=$( which lynx )

function die {
  echo "$*" 2>&1
  exit 1
}

function hit {
  local url="$1"
  if [ "$WGET" -a -x "$WGET" ]; then
    $WGET -q -O /dev/null "$url"
  elif [ "$CURL" -a -x "$CURL" ]; then
    $CURL -s "$url" > /dev/null
  elif [ "$LYNX" -a -x "$LYNX" ]; then
    $LYNX --source "$url" > /dev/null
  fi
}

DBOPT="-u $DB_USER"
[ "$DB_PASSWORD" ] && DBOPT="$DBOPT -p$DB_PASSWORD"
DBOPT="$DBOPT $DB_NAME"

mkdir -p "$OUT"
echo 'SHOW TABLES' | $MYSQL $DBOPT | tail -n +2 | \
  while read tbl; do 
    echo "Dumping $tbl to $OUT/$tbl.sql"
    $MYSQLDUMP \
      --skip-extended-insert \
      --skip-dump-date \
      $DBOPT "$tbl" > "$OUT/$tbl.sql" || die "mysqldump failed: $?"
  done

touch "$POLLFILE"

# vim:ts=2:sw=2:sts=2:et:ft=sh

