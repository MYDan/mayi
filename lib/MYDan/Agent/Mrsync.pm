package MYDan::Agent::Mrsync;

=head1 NAME

MYDan::Util::Mrsync - Replicate data via phased rsync

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

#        my $ssh = 'ssh -x -c blowfish -o StrictHostKeyChecking=no';
#        my @cmd = ( $ssh, $dst );
#
#        push @cmd, "nice -n $param{nice}" if $param{nice};
#        push @cmd, << "RSYNC";
#'rsync -e "$ssh" $param{opt} $src:$sp $dp'
#RSYNC
#        my $rsync = join ' ', @cmd; chop $rsync;

        use MYDan::Agent::Query;
        use Time::HiRes qw(time);
        use AnyEvent;
        use AnyEvent::Impl::Perl;
        use AnyEvent::Socket;
        use AnyEvent::Handle;

        eval{

            my $load = MYDan::Agent::Query->dump(+{ code => 'load', argv => [ $sp ] });
            my $query = MYDan::Agent::Query->dump(+{ code => 'download', 
                argv => [ +{ load => $load, src => $src, port => 65111, sp => $sp, dp => $dp } ]
             });
            my ( $cv, %keepalive ) = ( AE::cv, cont => '', skip => 0 );
            tcp_connect $dst, "65111", sub {
               my ( $fh ) = @_  or die "tcp_connect: $!";
               my $hdl; $hdl = new AnyEvent::Handle(
                       fh => $fh,
                       on_read => sub {
                           my $self = shift;
                           $self->unshift_read (
                               chunk => length $self->{rbuf},
                               sub {
                                   $keepalive{cont} .= $_[1];
                                   unless( $keepalive{skip} )
                                   {
                                       $keepalive{cont} =~ s/^\*+//g;
                                       if( $keepalive{cont} =~ s/^#\*keepalive\*#// )
                                       {
                                           $keepalive{skip} = 1;
                                       }
                                   }
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
            die "$keepalive{cont}" unless $keepalive{cont} =~ /--- 0\n$/;
        };

        return $@ ? die "ERR: rsync $@" : 'OK';
#        return system( $rsync ) ? die "ERR: $rsync" : 'OK';
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
