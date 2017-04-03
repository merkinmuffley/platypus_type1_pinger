#!/usr/bin/perl

use strict;
use warnings;

use File::Temp;
use FindBin;
use lib "$FindBin::Bin/../lib";
use gpg_keyring;
use T1ping;

my $pubring=gpg_keyring->new();
$pubring->read_keyring();
my @remailers=$pubring->show_keyring();
my @garbage;


  my $msg=T1ping->new();
  push(@garbage,$msg);
  $msg->wrap('platypus','platypus@notatla.org.uk');
  $msg->wrap('B052DF06','mixmaster@remailer.privacy.at');
  $msg->wrap('1698D34C','remailer@dizum.com');
  $msg->send();
