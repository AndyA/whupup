#!/usr/bin/env perl

use v5.10;

use autodie;
use strict;
use warnings;

use File::Find;
use File::chdir;
use FindBin;
use Getopt::Long;
use JSON;
use Net::FTP;
use POSIX qw( strftime );
use Path::Class;
use Template;

use constant INST_PROTO => dir $FindBin::Bin, '..', 'install';
use constant PROBE      => dir $FindBin::Bin, 'probe.php';
use constant INST_DIR   => 'whupup';

my %O = ( install => 0 );

GetOptions( 'install' => \$O{install} ) or die syntax();

for my $spec (@ARGV) {
  my $info = JSON->new->decode( scalar file($spec)->slurp );
  my $gl = $info->{global} || {};
  for my $site ( @{ $info->{sites} } ) {
    whupup( $gl, $site );
  }
  tmp_file( $gl, 'probe' )->parent->rmtree;
}

sub site_dir {
  my $gl   = shift;
  my $site = shift;
  return dir $gl->{base}, $site->{name}, @_;
}

sub whupup {
  my ( $gl, $site ) = @_;
  my $dir = site_dir( $gl, $site, 'backup' );
  $dir->mkpath;
  if ( $O{install} ) {
    install( $gl, $site );
  }
  else {
    mirror( $gl, $site, $dir );
    snapshot( $gl, $site, $dir );
  }
}

sub install {
  my ( $gl, $site ) = @_;
  my $ftp    = ftp_connect( $gl, $site );
  my $root   = $ftp->pwd;
  my $whupup = join '/', $root, INST_DIR;
  my $info   = {
    root   => $root,
    whupup => {
      dir      => $whupup,
      callback => 'http://jaded.uk/ping',
    },
    wp     => get_wp_config( $gl, $site, $ftp ),
    site   => $site,
    global => $gl,
  };

  my $dir = build_inject( $gl, $site, $info );
  $ftp->mkdir( $whupup, 1 ) || die "Can't make $whupup: $@";
  rmirror( $gl, $site, $dir, $whupup );
}

sub mk_passwd {
  my ( $dir, $user, $pass ) = @_;
  my $passwd = file $dir, 'passwd';
  my @cmd = ( htpasswd => -cb => $passwd, $user, $pass );
  system @cmd;
  die "htpasswd failed: $?" if $?;
}

sub site_password {
  my $site = shift;
  return $site->{password};
}

sub build_inject {
  my ( $gl, $site, $info ) = @_;
  my $dir = site_dir( $gl, $site, INST_DIR );
  find {
    wanted => sub {
      return unless -f;
      my $src  = file $_;
      my $leaf = $src->basename;
      return if $leaf =~ /^\./;
      $leaf =~ s/^dot\././;
      my $dst = dir $dir, file($src)->relative(INST_PROTO)->parent, $leaf;
      print "$src -> $dst\n";
      $dst->parent->mkpath;
      my $tt = Template->new( { ABSOLUTE => 1 } );
      $tt->process( "$src", $info, "$dst" ) || die $tt->error;
      my $mode = ( stat $src )[2];
      chmod $mode, $dst if defined $mode;
    },
    no_chdir => 1
   },
   INST_PROTO;
  return $dir;
}

sub get_wp_config {
  my ( $gl, $site, $ftp ) = @_;
  my $local = tmp_file( $gl, 'wp-config.php' );
  $ftp->get( $site->{config} // 'wp-config.php', "$local" );
  my $config = parse_using_php($local);
  return $config;
}

sub parse_using_php {
  my $file = shift;
  open my $fh, '-|', 'php', PROBE, $file;
  my $config = JSON->new->decode(
    do { local $/; <$fh> }
  );
  close $fh;
  return $config;
}

sub tmp_file {
  my ( $gl, $leaf ) = @_;
  state $next = 0;
  $leaf //= sprintf ' tmp . %08d', $next++;
  my $tmp = file $gl->{tmp} // '/tmp', "whupup.$$", $leaf;
  $tmp->parent->mkpath;
  return $tmp;
}

sub ftp_connect {
  my ( $gl, $site ) = @_;
  my $ftp = Net::FTP->new( $site->{host} );
  $ftp->login( $site->{user}, $site->{password} );
  $ftp->binary;
  $ftp->cwd( $site->{path} );
  return $ftp;
}

sub rmirror {
  my ( $gl, $site, $dir, $rem ) = @_;

  my $opt = $site->{options}{mirror} // '';
  my @cmd = (
    lftp => -u => join( ',', $site->{user}, $site->{password} ),
    $site->{host},
    -e => "mirror -R $dir $rem && exit"
  );
  system @cmd;
}

sub mirror {
  my ( $gl, $site, $dir ) = @_;

  my $opt = $site->{options}{mirror} // '';
  my @cmd = (
    lftp => -u => join( ',', $site->{user}, $site->{password} ),
    $site->{host},
    -e => 'set ftp:list-options -a',
    -e =>
     "mirror -vvv --exclude .git $opt --delete $site->{path} $dir && exit"
  );
  system @cmd;
}

sub ts {
  my $tm = shift // time;
  strftime '%Y-%m-%d %H:%M:%S', localtime $tm;
}

sub snapshot {
  my ( $gl, $site, $dir ) = @_;
  local $CWD = $dir;
  system 'git init .' unless -d '.git';
  system 'git add .';
  system 'git add -u .';
  system 'git', 'commit', -m => 'Backup at ' . ts();
}

sub syntax {
  return <<EOT
Syntax: whupup.pl [--install] sites.json ...
EOT
}

# vim:ts=2:sw=2:sts=2:et:ft=perl
