package MYDan::Agent::Load;

=head1 NAME

MYDan::Agent::Load

   load data by agent

=head1 SYNOPSIS

 use MYDan::Agent::Load; my $load = MYDan::Agent::Load->new( 
   node => 'host1', sp=> 'srcpath', dp => 'dstpath'
 );

 my %result = $client->load( 
   timeout => 300,
   user => '',
   sudo => '',
   verbose => 1, 
   port => '',
   continue => 0,
 ); 

=cut
use strict;
use warnings;

use Carp;
use Time::HiRes qw(time);
use AnyEvent;
use AnyEvent::Impl::Perl;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Digest::MD5;
use MYDan::Agent::Query;
use Fcntl qw(:flock SEEK_END);

sub new
{
    my ( $class, %self ) = @_;
    map{ confess "$_ undef" unless $self{$_} }qw( node sp );

    $self{dp} ||= $self{sp};

    bless \%self, ref $class || $class;
}


sub run
{
    my ( $this, %run ) = @_;

    my ( $node, $sp, $dp, $query ) = @$this{qw( node sp dp )};

    my $temp = sprintf "$dp.%stmp", $run{continue} ? '' : time.'.'.$$.'.';

    my $position = -f $temp ? ( stat $temp )[7] : 0;

    open my $TEMP, '+>', $temp or die "Can't open '$temp': $!";

    unless( $query = $run{query} )
    {
        my %query = ( code => 'load', user => $run{user}, sudo=> $run{sudo}, argv => [ $sp, $position ] );

        my $isc = $run{role} && $run{role} eq 'client' ? 1 : 0;

        $query{node} = [ $node ] if $isc;

        my $query = MYDan::Agent::Query->dump(\%query);
        eval{ $query = MYDan::API::Agent->new()->encryption( $query ) if $isc };

        die "encryption fail:$@" if $@;

    }

    my ( $cv, $len, %keepalive )
        = ( AE::cv, $position,  cont => '', skip => 0, first => 1 );
    
    printf "position: %d\n", $position if $run{verbose};

    tcp_connect $node, $run{port}, sub {
        my ( $fh ) = @_  or die "tcp_connect: $!";
        my $hdl; $hdl = new AnyEvent::Handle(
           fh => $fh,
           on_read => sub {
               my $self = shift;
               $self->unshift_read (
                   chunk => length $self->{rbuf},
                   sub {
		       ( $keepalive{first}, $keepalive{skip} ) = ( 0, 1 )
                           if $keepalive{first} && $_[1] !~ /^\*/;

                       if( $keepalive{skip} )
                       {
                           $len += length $_[1];
                           print $TEMP $_[1];
                       }
                       else
                       {
                           $keepalive{cont} .= $_[1];
                           $keepalive{cont} =~ s/^\*+//g;
                           if( $keepalive{cont} =~ s/^#\*keepalive\*#// )
                           {
                               $keepalive{skip} = 1;
                               $len += length $keepalive{cont};
                               print $TEMP delete $keepalive{cont};
                           }
                       }

		       printf "len : %d\n", $len if $run{verbose};
                   }
               );
            },
            on_eof => sub{
                undef $hdl;
                 $cv->send;
             }
        );
        $hdl->push_write($query);
        $hdl->push_shutdown;
    };

    $cv->recv;

    seek $TEMP, -38, SEEK_END;
    sysread $TEMP, my $end, 38;

    my ( $filemd5 ) = $end =~ /^([0-9a-z]{32})--- 0\n$/;
    unless( $filemd5 )
    {
        unlink $temp;
        die "end nomatch $end\n";
    }
    truncate $TEMP, $len - 38;
    seek $TEMP, 0, 0;

    unless( $filemd5 eq Digest::MD5->new()->addfile( $TEMP )->hexdigest() )
    {
        unlink $temp;
        die "md5 nomatch\n";
    }
    rename $temp, $dp;
}

1;
