package MYDan::Agent::Client;

=head1 NAME

MYDan::Agent::Client

=head1 SYNOPSIS

 use MYDan::Agent::Client;
 my $client = MYDan::Agent::Client->new( [ 'node1:13148', 'node2:13148' ] );
 my %result = $client->run( timeout => 300, input => '' ); 

=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Spec;
use File::Basename;
use FindBin qw( $RealBin );
use YAML::XS;

use MYDan::MIO::TCP;
use MYDan::Agent::Query;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Time::HiRes qw(time);

use MYDan::API::Agent;

our %RUN = ( user => 'root', max => 128, timeout => 300 );

sub new
{
    my $class = shift;
    bless +{ node => \@_ }, ref $class || $class;
}


sub run
{
    my ( $this, %run, %result ) = ( shift, %RUN, @_ );

    return unless my @node = @{$this->{node}};

    my $isc = $run{role} && $run{role} eq 'client' ? 1 : 0;
    $run{query}{node} = \@node if $isc;

    my $query = MYDan::Agent::Query->dump($run{query});

    eval{ $query = MYDan::API::Agent->new()->encryption( $query ) if $isc };
    if( $@ )
    {
        warn "ERROR:$@\n";
        return map{ $_ => "norun --- 1\n" }@node;
    }
 

    my $cv = AE::cv;

    my $work;$work = sub{
        return unless my $node = shift @node;
        $result{$node} = '';
        
        $cv->begin;
        tcp_connect $node, $run{port}, sub {
             my ( $fh ) = @_;
             unless( $fh ){
                 $cv->end;
                 $result{$node} = "tcp_connect: $!";
                 $work->();
                 return;
             }
             my $hdl; $hdl = new AnyEvent::Handle(
                 fh => $fh,
                 on_read => sub {
                     my $self = shift;
                     $self->unshift_read (
                         chunk => length $self->{rbuf},
                         sub { $result{$node} .= $_[1];}
                     );
                  },
                  on_eof => sub{
                      undef $hdl;
                      $cv->end;
                      $work->();
                  }
             );
             $hdl->push_write($query);
             $hdl->push_shutdown;
          };
    };

    my $max = scalar @node > $run{max} ? $run{max} : scalar @node;
    $work->() for 1 .. $max ;

    $cv->recv;
    map{ $_ =~ s/^\**#\*keepalive\*#//;}values %result;
    return %result;
}

1;
