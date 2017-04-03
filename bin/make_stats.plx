#!/usr/bin/perl

use strict;
use warnings;
use File::Temp;
use FindBin;
use lib "$FindBin::Bin/../lib";
use T1ping;

#####################
sub get_counts
{
my ($below_homedir,$maxage,$minage)=@_;
chdir($below_homedir) or die();
opendir(my $dh,'.') or die();
my @fnames=readdir($dh);
closedir($dh);

my %got;
foreach my $f (@fnames) {
    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
    $atime,$mtime,$ctime,$blksize,$blocks)=();
       ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
    $atime,$mtime,$ctime,$blksize,$blocks)=lstat($f);
    next if (!defined($mode));
    next if (($mode&0170000) != 0100000);
    my $fileage=$^T-$mtime;
    next if ($fileage > $maxage);
    next if ($fileage < $minage);
    open(my $pf, '<', $f) or die();
    READFILE: while (<$pf>) {
        chomp();
        if (/^[a-z=]*platypus,(\S+)$/) {
            my $route=$1;
            if (defined($got{$route})) {
                $got{$route} ++;
            } else {
                $got{$route} =1;
            }
            next READFILE;
        }
    }
    close($pf);
}

return \%got;
}
#####################


my ($maxage,$minage)=(604800, 18000);
my $homedir=((getpwuid($<)))[7];
my $success=get_counts($homedir.'/success',$maxage,$minage);
my $pings=get_counts($homedir.'/pings',$maxage,$minage);

foreach my $thing ($success,$pings) {
    foreach my $sk (sort keys %{$thing}) {
        if ($sk !~ /,/) {
            delete($thing->{$sk});
            next;
        }
    }
}


my %ratio;
    # 100% success
    foreach my $sk (sort keys %{$success}) {
        next if (defined($pings->{$sk}));
        $ratio{$sk}=[$success->{$sk},$success->{$sk}];
        delete($success->{$sk});
    }
    # 100% failure
    foreach my $sk (sort keys %{$pings}) {
        next if (defined($success->{$sk}));
        $ratio{$sk}=[0,$pings->{$sk}];
        delete($pings->{$sk});
    }
    foreach my $sk (sort keys %{$pings}) {
      # my $r = $success->{$sk} / ($success->{$sk} + $pings->{$sk}) ;
        $ratio{$sk}=[$success->{$sk},($success->{$sk} + $pings->{$sk})];
        delete($pings->{$sk});
    }

my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=();
($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=localtime(time);
my $today=sprintf("%04d-%02d-%02d", 1900+$year, 1+$mon, $mday);
my %r;
my $spooldir=File::Temp::tempdir("$homedir/tmp/platypus_spool_XXXXXXXXXXXXXXXXX", CLEANUP => 1);
chdir($spooldir) or die();
open(my $cs,'>','chain_stats');
printf($cs "::\nAnon-To: mail2news\@dizum.com\n\n##\nSubject: type1 chain pings %s\nNewsgroups: alt.privacy.anon-server.stats\n\n", $today);
foreach my $sk (sort keys %ratio) {
  $r{$sk}=$ratio{$sk}->[0]/$ratio{$sk}->[1];
}
my @order=sort {$r{$b} <=> $r{$a}} keys %r;
foreach my $sk (@order) {
    printf($cs "%s %d/%d\n", $sk, @{$ratio{$sk}} );
}
close($cs);

my $msg=T1ping->new();
chdir($spooldir) or die();
$msg->{filename}='chain_stats';
$msg->wrap('dizum','remailer@dizum.com');
$msg->send();

rename('chain_stats', $homedir.'/stats/'.$^T) or die("rename failed $!");
