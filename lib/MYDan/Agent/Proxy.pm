package MYDan::Agent::Proxy;

=head1 NAME

MYDan::Agent::Proxy

=head1 SYNOPSIS

 use MYDan::Agent::Proxy;

 my $proxy = MYDan::Agent::Proxy->new( '/conf/file' );

 my %r = $proxy->search( 'node1', 'node2', '10.10.0.1', '10.10.0.2' );
 
 %r = (
      node1 => undef, node2 => undef,
      '10.10.0.1' => 'proxyip',
      '10.10.0.2' => 'proxyip',
  );

=cut

use strict;
use warnings;

use Carp;
use YAML::XS;
use Net::IP::Match::Regexp qw( match_ip create_iprange_regexp_depthfirst );
use Data::Validate::IP qw( is_ipv4 );
use MYDan::Util::OptConf;
use MYDan::Node;
use Socket;

sub new
{
    my ( $class, $conf ) = @_;
    confess "no conf" unless $conf && -e $conf;

    eval { $conf = YAML::XS::LoadFile( $conf ) };

    confess "error: $@" if $@;
    confess "error: not HASH" if ref $conf ne 'HASH';

    bless $conf, ref $class || $class;
}

sub search
{
    my ( $this, @node, %result ) = @_;

    my %conf = %$this;

    my ( %ip_innet, $ip_regexp );

    for my $conf ( keys %conf )
    {
        my ( $addr, $netmask );
        if ( $conf
            =~ /^\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})\s*/ )
        {
            ( $addr, $netmask ) = split /\//, $conf;
        }
        if ( is_ipv4( $addr ) && $netmask >= 0 && $netmask <= 32 )
        {
            $ip_innet{ $conf } = delete $conf{ $conf };
        }
    }

    $ip_regexp = create_iprange_regexp_depthfirst( \%ip_innet ) if %ip_innet;

    for my $node ( @node )
    {
        $result{ $node } = undef;
        if ( !is_ipv4( $node ) )
        {
            for my $conf ( keys %conf )
            {
                if ( $conf =~ m{\(\?\^u:}xms )
                {
                    $result{ $node } = $conf{ $conf } if $node =~ $conf;
                    last;
                }

                if (grep { $node eq $_ } MYDan::Node->new(
                        MYDan::Util::OptConf->load()->dump( 'range' )
                    )->load( $conf )->list()
                    )
                {
                    $result{ $node } = $conf{ $conf };
                    last;
                }
            }
        }

        if ( !is_ipv4( $node ) && !defined $result{ $node } )
        {
            my $node_ip = inet_ntoa( my $packed_ip = gethostbyname $node )
                if gethostbyname $node;
            $result{ $node } = match_ip( $node_ip, $ip_regexp );
        }

        if ( is_ipv4( $node ) )
        {
            $result{ $node } = match_ip( $node, $ip_regexp );
        }
    }

    return %result;
}

1;
