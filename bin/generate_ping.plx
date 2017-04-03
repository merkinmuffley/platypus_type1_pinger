#!/usr/bin/perl

use strict;
use warnings;

use File::Temp;
use FindBin;
use lib "$FindBin::Bin/../lib";
use gpg_keyring qw(get_addr);
use T1ping;

my $pubring=gpg_keyring->new();
$pubring->read_keyring();
my @remailers=$pubring->show_keyring();
my @garbage;

# single pings
foreach my $r (@remailers) {
  my $msg=T1ping->new();
  push(@garbage,$msg);
  $msg->wrap('platypus','platypus@notatla.org.uk');
  $msg->wrap($r, $pubring->get_addr($r));
  $msg->send($pubring);
}

# chains of two
foreach my $r1 (@remailers) {
   next if ('platypus@notatla.org.uk' eq $pubring->get_addr($r1));
   foreach my $r2 (@remailers) {
      next if ('platypus@notatla.org.uk' eq $pubring->get_addr($r2));
      my $msg=T1ping->new();
      push(@garbage,$msg);
      $msg->wrap('platypus','platypus@notatla.org.uk');
      $msg->wrap($r1, $pubring->get_addr($r1));
      $msg->wrap($r2, $pubring->get_addr($r2));
      $msg->send($pubring);
   }
}
