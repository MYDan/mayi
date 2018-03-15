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
use Socket;

sub new
{
    my ( $class, $conf, %self ) = splice @_, 0, 2;


    if( my $addr =  $ENV{MYDan_Agent_Proxy_Addr} )
    {
        $self{addr} = $addr;
    }
    else
    {
        confess "no conf" unless $conf;
        my %conf;
        for my $c ( $conf, $ENV{MYDan_Agent_Proxy_Config} )
        {
            next unless $c;
            confess "no conf: $c" unless  -e $c;
            my $y = eval{ YAML::XS::LoadFile( $c ) };
            confess "error: $@" if $@;
            $y = +{} unless defined $y;
            confess "error: not HASH" if ref $y ne 'HASH';
            %conf = ( %conf, %$y );
       }

        $self{conf} = \%conf;
    }

    bless \%self, ref $class || $class;
}

sub search
{
    my ( $this, @node, %innet ) = @_;

    return map{ $_ => $this->{addr} eq '0.0.0.0' ? undef : $this->{addr} }@node if $this->{addr};

    my $conf = $this->{conf};

    for ( keys %$conf )
    {
        next unless $_ =~ /^\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})\s*$/;
        $innet{$_} = $conf->{$_} if is_ipv4( $1 ) && $2 >=0 && $2 <= 32;
    }

    return map{ $_ => undef }@node unless %innet;

    my $regexp = create_iprange_regexp_depthfirst( \%innet );

    my %hosts = MYDan::Util::Hosts->new()->match( @node );
    map{
        $hosts{$_} = inet_ntoa( gethostbyname $_ ) 
	    unless is_ipv4( $hosts{$_} )
    }keys %hosts;

    return map{ $_ => match_ip( $hosts{$_}, $regexp )}@node;
}

1;
