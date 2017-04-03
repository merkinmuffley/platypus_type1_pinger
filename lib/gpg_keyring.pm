#
use strict;
use warnings;
package gpg_keyring;

sub new
{
my $class=shift;

my $self={
    pub_key_hash => {},
};
bless $self,$class;
return $self;
}

sub insert
{
my ($self,$pubid,$addr)=@_;
$self->{pub_key_hash}->{$pubid}=$addr;
}

sub read_keyring
{
my $self=shift;

pipe(RH,WH) or die("pipe $!");
my $pid=fork();
die("fork $!") if (!defined($pid));
if (!$pid) {
    close(RH);
    open(STDIN, '<', '/dev/null');
    open(STDOUT, ">&WH") or die("open stdout $!");
    open(STDERR, ">&WH") or die("open stderr $!");
    exec ('gpg','-kvv');
    exit(1);
}
close(WH);
my ($pub,$addr)=();
while (<RH>) {
    chomp();
    if (/^pub\s+\w+\/(\w+)\s/) {
        $pub=$1;
        next;
    }
    if (/^uid\s+.*\s<(\w[\w.+-]+@[\w.+-]+)>$/) {
        $addr=$1;
        next if ($addr =~ /\bexample\.com$/);
        next if ($addr =~ /\bexample\.org$/);
        next if ($addr =~ /\bexample\.net$/);
        next if ($addr =~ /\bwhitehouse\.gov$/);
        next if ($addr =~ /\bhomeip\.net$/);
        $self->insert($pub,$addr);
        next;
    }
    if (/^$/) {
        ($pub,$addr)=();
    }
}
waitpid($pid,0);

}

sub get_addr
{
my ($self,$pub_id)=@_;
return 'pinger' if ('platypus' eq $pub_id);
my %h=%{$self->{pub_key_hash}};
return $h{$pub_id};
}

sub show_keyring
{
my $self=shift;
my %h=%{$self->{pub_key_hash}};
my @r=sort keys %h;
return @r;
}

1;
