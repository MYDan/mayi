package MYDan::Agent::Mrsync;

=head1 NAME

MYDan::Util::Mrsync - Replicate data via phased agent

=head1 SYNOPSIS

 use MYDan::Util::Mrsync;

 my $mrsync = MYDan::Util::Mrsync->new
 ( 
     src => \@src_hosts,
     dst => \@dst_hosts,
     sp => $src_path,
     dp => $dst_path, ## defaults to sp
 );

 $mrsync->run
 (
     timeout => 300, ## default 0, no timeout
     retry => 2,     ## default 0, no retry
     log => $log_handle,    ## default \*STDERR
     max => $max_in_flight, ## default 2
     opt => $rsync_options, ## default -aqz
 );

=cut
use strict;
use warnings;

use Carp;
use File::Basename;

use base qw( MYDan::Util::Phasic );

our %RUN = ( retry => 2, opt => '-aq' );

use MYDan::Agent::Query;
use Time::HiRes qw(time);
use AnyEvent;
use AnyEvent::Impl::Perl;
use AnyEvent::Socket;
use AnyEvent::Handle;
use MYDan::Util::OptConf;
use MYDan::API::Agent;
use MYDan::Agent::Client;

our %agent; 
BEGIN{ %agent = MYDan::Util::OptConf->load()->dump( 'agent' ); };

sub new
{
    my ( $class, %param ) = splice @_;
    my ( $sp, $dp ) = delete @param{ qw( sp dp ) };
    my %src = map { $_ => 1 } @{ $param{src} };

    $sp = $dp unless $sp;
    $dp = $sp unless $dp;

    croak "path not defined" unless $sp;

    $param{dst} = [ grep { ! $src{$_} } @{ $param{dst} } ] if $sp eq $dp;

    if ( $sp =~ /\/$/ ) { $dp .= '/' if $dp !~ /\/$/ }
    elsif ( $dp =~ /\/$/ ) { $dp .= File::Basename::basename( $sp ) }

    my $w8 = sub 
    {
        my @addr = gethostbyname shift;
        return @addr ? unpack N => $addr[-1] : 0;
    };

    my $rsync = sub
    {
        my ( $src, $dst, %param ) = splice @_;
        my $sp = $src{$src} ? $sp : $dp;


        eval{


            my $isc = $agent{role} && $agent{role} eq 'client' ? 1 : 0;

            my %load = ( 
                argv => [ $sp ],
                code => 'load', map{ $_ => $param{$_} }qw( user sudo )
            );
            $load{node} = [ $src ] if $isc;

            my $load = MYDan::Agent::Query->dump(\%load);
            eval{ $load = MYDan::API::Agent->new()->encryption( $load ) if $isc };
            die "encryption fail:$@" if $@;


            my %query = ( 
                argv => +{ load => $load, src => $src, port => $agent{port}, sp => $sp, dp => $dp, map{ $_ => $param{$_} }qw( chown chmod cc ) },
		code => 'download', map{ $_ => $param{$_} }qw( user sudo )
            );


	    my %result = MYDan::Agent::Client->new(
		    $dst
		)->run( %agent, query => \%query );

            my $result = $result{$dst}||'';
	    die $result unless $result =~ /--- 0\n$/;
        };

        return $@ ? die "ERR: rsync $@" : 'OK';

    };

    bless $class->SUPER::new( %param, weight => $w8, code => $rsync ),
        ref $class || $class;
}

sub run
{
    my ( $self, %run ) = splice @_;
    $MYDan::Util::Phasic::MAX = delete $run{max} if $run{max};
    $self->SUPER::run( %RUN, %run );
    return $self;
}

1;
