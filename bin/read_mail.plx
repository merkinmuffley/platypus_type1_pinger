#!/usr/bin/perl

use strict;
use warnings;

use File::Temp;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Read_mail;

my $mail=Read_mail->new();
$mail->gpg_from_body();
$mail->gpg_d();
$mail->ping_compare();
