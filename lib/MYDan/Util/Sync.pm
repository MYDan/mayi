package MYDan::Util::Sync;
use strict;
use warnings;
use Carp;
use MYDan;

sub new
{
    my ( $class, $conf ) = @_;
    die "conf undef" unless $conf;
    bless $conf, ref $class || $class;
}

sub sync
{
    my $this = shift;

    die "addr nofind" unless my $addr = $this->{api}{addr};

    my ( $hosts, $hostt ) = ( "$MYDan::PATH/etc/hosts", "$MYDan::PATH/etc/hosts.tmp" );
    unlink $hostt if -e $hostt;
    die "sync hosts fail.\n" if system "wget -O '$hostt' $addr/download/sync/hosts";
    die "rename hosts fail.\n" if system "mv '$hostt' '$hosts'";


    die "range.cache nofeind" unless my $cache = $this->{range}{cache};

    my $cachet = "$cache.tmp";

    unlink $cachet if -e $cachet;

    die "sync range.cache fail.\n" if system "wget -O '$cachet' $addr/download/sync/node.cache";
    die "rename range.cache fail.\n" if system "mv '$cachet' '$cache'";
}

1;
__END__
