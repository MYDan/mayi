package MYDan::MonitorV3::NodeQuery;

use warnings;
use strict;
use Carp;

use YAML::XS;
use AnyEvent;
use AnyEvent::Socket;
use AnyEvent::Handle;
use AnyEvent::HTTP;
use MIME::Base64;

my ( %proxy, %carry );

sub new
{
    my ( $class, %this ) = @_;
    die "port undef" unless $this{port};

    bless \%this, ref $class || $class;
}

sub getResponseProxy
{
    my ( $this, $content ) = @_;
    $content = "#HELP DEBUG By Proxy\n". $content;
    my $length = length $content;
    my @h = (
        "HTTP/1.0 200 OK",
        "Content-Length: $length",
        "Content-Type: text/plain",
    );

    return join "\n",@h, "", $content;
}

sub getResponseRoot
{
    my $this = shift;
    my $content = 
'
<html>
    <head><title>MYDan Node Query</title></head>
    <body>
        <h1>MYDan Node Query</h1>
    </body>
</html>
';
    my $length = length $content;
    my @h = (
        "HTTP/1.0 200 OK",
        "Content-Length: $length",
        "Content-Type: text/html",
    );

    return join "\n",@h, "", $content;
}

sub run
{
    my $this = shift;

    my $cv = AnyEvent->condvar;
    tcp_server undef, $this->{port}, sub {
       my ( $fh ) = @_ or die "tcp_server: $!";

       my $handle; $handle = new AnyEvent::Handle( 
           fh => $fh,
           keepalive => 1,
           rbuf_max => 1024000,
           wbuf_max => 1024000,
           autocork => 1,
           on_read => sub {
               my $self = shift;
               my $len = length $self->{rbuf};
               $self->push_read (
                   chunk => $len,
                   sub { 
                       my $data = $_[1];
                       if( $data =~ m#/query_([\d+\.\d+\.\d+\.\d+]+)_query# )
                       {
                           my $ip = $1;

                           if( $carry{$ip} && ref $carry{$ip} )
                           {
                               $carry{$ip} = encode_base64( YAML::XS::Dump $carry{$ip} );
                               $carry{$ip} =~ s/\n//g;
                           }
                           my $carry = $carry{$ip} ? "/carry_$carry{$ip}_carry" : "";

                           if( $proxy{$ip} )
                           {
                               http_get "http://$proxy{$ip}:65110/proxy_${ip}_proxy$carry", sub { 
                                   my $c = $_[0] || $_[1]->{URL}. " -> ".$_[1]->{Reason};
                                   $handle->push_write($this->getResponseProxy($c)) if $c;
                                   $handle->push_shutdown();
                                   $handle->destroy();
                               };
                           }
                           else
                           {
                               http_get "http://$ip:65110/metrics$carry", sub { 
                                   my $c = $_[0] || $_[1]->{URL}. " -> ".$_[1]->{Reason};
                                   $handle->push_write($this->getResponseProxy($c)) if $c;
                                   $handle->push_shutdown();
                                   $handle->destroy();
                               };
                           }
                       }
                       else
                       {
                           $handle->push_write($this->getResponseRoot());
                           $handle->push_shutdown();
                           $handle->destroy();
                       }
                    }
               );
           },
        );
    };

    my $proxyUpdate = AnyEvent->timer(
        after => 3, 
        interval => 6,
        cb => sub { 
            my $proxy = eval{ YAML::XS::LoadFile $this->{proxy} };
            if ( $@ )
            {
                warn "load proxy file fail: $@";
                return;
            }

            unless( $proxy && ref $proxy eq 'HASH' )
            {
                warn "load proxy file no HASH\n";
                return;
            }
            %proxy = %$proxy;
        }
    ) if $this->{proxy}; 

    my $carryUpdate = AnyEvent->timer(
        after => 6, 
        interval => 6,
        cb => sub { 
            my $carry = eval{ YAML::XS::LoadFile $this->{carry} };
            if ( $@ )
            {
                warn "load carry file fail: $@";
                return;
            }

            unless( $carry && ref $carry eq 'HASH' )
            {
                warn "load carry file no HASH\n";
                return;
            }
            %carry = %$carry;
        }
    ) if $this->{carry}; 

    $cv->recv;
}

1;
