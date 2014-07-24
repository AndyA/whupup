#!/bin/bash

cd "$( dirname "$0" )"

PERL='/home/andy/perl5/perlbrew/perls/perl-5.16.0/bin/perl'
$PERL tools/whupup.pl sites.json

# vim:ts=2:sw=2:sts=2:et:ft=sh

