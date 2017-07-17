package MYDan::Agent::Client;

=head1 NAME

MYDan::Agent::Client

=head1 SYNOPSIS

 use MYDan::Agent::Client;
 my $client = MYDan::Agent::Client->new( [ 'node1', 'node2' ] );
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

use MYDan::Agent::Query;
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use Time::HiRes qw(time);

use MYDan::API::Agent;
use MYDan::Util::Percent;

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
    my ( @work, $stop );

    $SIG{TERM} = $SIG{INT} = my $tocb = sub
    {
        $stop = 1;
        for my $w ( @work )
        {
            next unless $$w && $$w->fh;
            $$w->destroy;
            $cv->end;
        }

        map{ $cv->end; } 1 .. $cv->{_ae_counter}||0;
    };

    my $percent =  MYDan::Util::Percent->new( scalar @node, 'run ..' );
    my $work;$work = sub{
        return unless my $node = shift @node;
        $result{$node} = '';
        
        $cv->begin;
        tcp_connect $node, $run{port}, sub {
             my ( $fh ) = @_;
             unless( $fh ){
                 $cv->end;
		 $percent->add()->print();
                 $result{$node} = "tcp_connect: $!";
                 $work->();
                 return;
             }
             if( $stop )
             {
                 close $fh;
                 return;
             }

             my $hdl;
             push @work, \$hdl;
             $hdl = new AnyEvent::Handle(
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
		      $percent->add()->print();
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


    my $w = AnyEvent->timer ( after => $run{timeout},  cb => $tocb );
    $cv->recv;
    undef $w;

    map{ $_ =~ s/^\**#\*keepalive\*#//;}values %result;
    return %result;
}

1;
