#
use strict;
use warnings;
package T1ping;

sub new
{
my $class=shift;

my $self={
    fileno => 1,
    dice => int rand(1000_000_000),
    keylist => [],
    time_sent => undef,
};
bless $self,$class;
$self->{filename}=sprintf("thing-%08d",$self->{fileno});

$self->{dir}=File::Temp::tempdir("/tmp/platypus_pinger_XXXXXXXXXXXXXXXXX", CLEANUP => 1);
die("tempdir $!") if (!defined($self->{dir}));
chdir($self->{dir}) or die("chdir tempdir $!");

open(my $f, '>', $self->{filename}) or die("open $!");
printf($f "ping data %d\n", $self->{dice});
close($f) or die("close $!");

return $self;
}

sub wrap
{
my ($self,$newkey,$addr)=@_;

$self->{fileno} = $self->{fileno} +1;
my $tmpfile=$self->{filename} . '.asc';
my $pid=fork();
die("fork $!") if (!defined($pid));
if (!$pid) {
    open(STDIN, '<',  $self->{filename}) or die("open stdin $!");
    open(STDOUT, '>', $tmpfile) or die("open stdout $!");
    exec ('gpg','--encrypt','--armor',  '--trust-model','always',  '--recipient',$newkey);
    exit(1);
}
waitpid($pid,0);

$self->{filename}=sprintf("thing-%08d",$self->{fileno});
open(my $f, '>', $self->{filename}) or die();
open(my $g, '<', $tmpfile) or die("open to read: $!");
{
local $/;
undef $/;
my $text=<$g>;
printf($f "::\nAnon-To: %s\n\n", $addr);
printf($f "::\nEncrypted: PGP\n\n%s", $text);
}
close($g);
close($f);

push (@{$self->{keylist}}, $newkey);
$self->{addr}=$addr;
}

sub send
{
my ($self,$pubring)=@_;
$self->{time_sent} =time();

open(my $mail, '|-', '/usr/sbin/sendmail','-oi','-t') or die("sendmail $!");
printf($mail "From: <platypus\@notatla.org.uk>\n");
printf($mail "To: <%s>\n",$self->{addr});
printf($mail "Subject: %04d\n\n", int rand(9999));
open(my $g, '<', $self->{filename}) or die("open to read: $!");
{
my $text=<$g>;
$text=<$g>;
$text=<$g>;
local $/;
undef $/;
$text=<$g>;
printf($mail "%s", $text);
}
close($g);
close($mail);

if (defined($pubring)) {
    chdir( ((getpwuid($<)))[7] ) or die("chdir $!");
    chdir('pings') or die("chdir $!");
    open(my $record, '>', $^T .'_'.$$.'_'.$self) or die();
    printf($record "ping pending (standard)\n%s\n%s\n%d\n",
                 $self->{dice},
                 join(',', map {$pubring->get_addr($_) .'='. $_} @{$self->{keylist}}),
                 $self->{time_sent});
    close($record) or die(0);
}
}

1;
