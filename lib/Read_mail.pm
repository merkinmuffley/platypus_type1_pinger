#
use strict;
use warnings;
package Read_mail;

sub new
{
my $class=shift;

my $self={
    fileno => 1,
    time_received => $^T,
};
bless $self,$class;
$self->{filename}=sprintf("in-%08d",$self->{fileno});

$self->{dir}=File::Temp::tempdir("/tmp/platypus_incoming_XXXXXXXXXXXXXXXXX", CLEANUP => 1);
die("tempdir $!") if (!defined($self->{dir}));
chdir($self->{dir}) or die("chdir tempdir $!");

open(my $f, '>', $self->{filename}) or die("open $!");
{
local $/;
undef $/;
my $text=<STDIN>;
printf($f "%s", $text);
}
close($f) or die("close $!");

return $self;
}

sub gpg_from_body
{
my $self=shift;

open(my $f, '<', $self->{filename}) or die("open $!");
$self->{fileno}++;
$self->{filename}=sprintf("in-%08d",$self->{fileno});
open(my $g, '>', $self->{filename}) or die("open $!");
my $show=0;
my $fin=0;
while (defined(my $line=<$f>)) {
     chomp($line);
     if ($line eq '-----BEGIN PGP MESSAGE-----') {
         $show=1;
     }
     printf($g "%s\n", $line) if ($show);
     if ($line eq '-----END PGP MESSAGE-----' && $show) {
         $fin=1;
         last;
     }
}
close($f);
close($g);
die('no pgp message found') if (!$fin);
}


sub gpg_d
{
my $self=shift;

my $tmpfile=$self->{filename} .'.txt';
my $pid=fork();
die("fork $!") if (!defined($pid));
if (!$pid) {
    open(STDIN, '<', '/home/platypus/secret/gpg_passphrase') or die("open stdout $!");
    open(STDOUT, '>', $tmpfile) or die("open stdout $!");
    exec ('gpg','-d', '--batch','-u','platypus','--passphrase-fd','0', $self->{filename});
    exit(1);
}
waitpid($pid,0);
$tmpfile=$self->{filename}=$tmpfile;
}

sub ping_compare
{
my $self=shift;

open(my $f, '<', $self->{filename}) or die("open $!");
my $line=<$f>;
chomp($line);
close($f);
if ($line =~ /^ping data (\d+)$/) {
    my $num=$1;
    chdir( ((getpwuid($<)))[7] ) or die("chdir $!");
    chdir('pings') or die("chdir $!");
    opendir(my $pd, '.') or die("opendir $!");
    my @fnames=readdir($pd);
    closedir($pd);
    foreach my $fn (@fnames) {
        next if ($fn eq '.');
        next if ($fn eq '..');
        open(my $fp, '<', $fn) or next;
        while (<$fp>) {
            chomp();
            if ($_ eq $num) {
                rename ($fn, '../success/'.$fn);
                printf("Recognised ping result\n");
                exit(0);
            }
        }
        close($fp);
    }
}
exit(0);
}

1;
