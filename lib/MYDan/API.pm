package MYDan::API;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;
use MYDan::Util::OptConf;
use URI::Escape;
use Sys::Hostname;
use HTTP::Cookies;
use MYDan::Node;
use Net::Ping;
use YAML::XS;

my $o; BEGIN{ $o = MYDan::Util::OptConf->load()->dump( 'api' ); }; 

sub new 
{
    my ( $class, %self ) = splice @_;

    $self{addr} ||=  $o->{addr};
    confess "api addr undef" unless $self{addr};

    $self{ua} = my $ua = LWP::UserAgent->new();
    $ua->agent('Mozilla/9 [en] (Centos; Linux)');

    $ua->timeout( 10 );

    bless \%self, ref $class || $class;
}

sub _get
{
    my ( $self, $uri ) = @_;

#    $uri = URI::Escape::uri_escape( $uri );
    $uri =~ s/ /%20/g;

    my $url = "$self->{addr}$uri";
    return +{ stat => JSON::true, data => $url } if $self->{urlonly};

    my $res = $self->{ua}->get( $url );
    system "touch '$self->{mark}'" if $res->code() == 500 && $self->{mark} && ! $ENV{MYDan_OpenAPI_Retry};
    print "get $url\n" if $ENV{MYDan_DEBUG};
    my $cont = $res->content;
    return +{ stat => JSON::false, info => $res->content } unless $res->is_success;

    my $data = eval{JSON::from_json $cont};
    return $@ ? +{ stat => JSON::false, info => $@ } : $data;
}

sub get
{
    my $self = shift;

    my ( $uri ) = @_;
    if( $ENV{MYDan_OpenAPI_Retry} )
    {
        while( 1 )
        {
            my $res = $self->_get( @_ );
            return $res->{data} if $res->{stat};
            warn "[WARN] openapi fail: $uri\n";
            sleep 3;
        }
    }
    else
    {
        my $res = $self->_get( @_ );
        $res->{stat} ? $res->{data} : die "[ERROR] openapi fail: $uri\n";
    }
}

sub _post
{
    my ( $self, $uri, %form ) = @_;

#    $uri = URI::Escape::uri_escape( $uri );
    $uri =~ s/ /%20/g;

    my $url = "$self->{addr}$uri";
    return +{ stat => JSON::true, data => $url } if $self->{urlonly};

    print "post $url\n" if $ENV{MYDan_DEBUG};
    my $res = $self->{ua}->post( "$url", 
          Content => JSON::to_json(\%form), 'Content-Type' => 'application/json' );
    system "touch '$self->{mark}'" if $res->code() == 500 && $self->{mark} && ! $ENV{MYDan_OpenAPI_Retry};
    my $cont = $res->content;
    return +{ stat => JSON::false, info => $res->content } unless $res->is_success;

    my $data = eval{JSON::from_json $cont};
    return $@ ? +{ stat => JSON::false, info => $@ } : $data;

}

sub post
{
    my $self = shift;

    my ( $uri ) = @_;
    if( $ENV{MYDan_OpenAPI_Retry} )
    {
        while( 1 )
        {
            my $res = $self->_post( @_ );
            return $res->{data} if $res->{stat};
            warn "[WARN] openapi fail: $uri\n";
            sleep 3;
        }
    }
    else
    {
        my $res = $self->_post( @_ );
        $res->{stat} ? $res->{data} : die "[ERROR] openapi fail: $uri\n";
    }

}

1;
