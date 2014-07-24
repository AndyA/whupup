#!/bin/bash

cd "$( dirname "$0" )"

DB_NAME='[% wp.DB_NAME %]'
DB_USER='[% wp.DB_USER %]'
DB_PASSWORD='[% wp.DB_PASSWORD %]'
DB_HOST='[% wp.DB_HOST %]'

OUT="sql"

MYSQL=$( which mysql )
MYSQLDUMP=$( which mysqldump )

DBOPT="-u $DB_USER"
[ "$DB_PASSWORD" ] && DBOPT="$DBOPT -p$DB_PASSWORD"
DBOPT="$DBOPT $DB_NAME"

mkdir -p "$OUT"
echo 'SHOW TABLES' | $MYSQL $DBOPT | tail -n +2 | \
  while read tbl; do 
    echo "Dumping $tbl to $OUT/$tbl.sql"
    $MYSQLDUMP --skip-extended-insert --skip-dump-date $DBOPT "$tbl" > "$OUT/$tbl.sql"; 
  done

# vim:ts=2:sw=2:sts=2:et:ft=sh

