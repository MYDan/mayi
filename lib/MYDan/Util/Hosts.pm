package MYDan::Util::Hosts;

use strict;
use warnings;
use Carp;

use Tie::File;
use Fcntl 'O_RDONLY';

use MYDan;

sub new
{
    my ( $class, $path, %host ) = splice @_, 0, 2;

    die "tie fail: $!" unless tie my @host, 'Tie::File', $path || "$MYDan::PATH/etc/hosts", mode => O_RDONLY;

    for my $host ( @host )
    {
        next unless $host =~ /^\s*(\d+\.\d+\.\d+\.\d)\s+([a-zA-Z][\w\s\.\-]+)/;
        map{$host{$_} = $1 }split /\s+/, $2;
    }
    
    bless \%host, ref $class || $class;
}

sub match
{
    my $this = shift;
    map{ $_ => $this->{$_} || $_ }@_;
}

1;
__END__
