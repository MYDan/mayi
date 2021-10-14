package MYDan::MonitorV3::NodeExporter::Collector;

use warnings;
use strict;
use Carp;
use IPC::Open3;
use Symbol 'gensym';
use AnyEvent;

use MYDan::MonitorV3::Prometheus::Tiny;

my %declare = (
    node_collector_error => 'Number of errors encountered during node exporter collection',
);

my %proc;
our $prom;

sub new
{
    my ( $class, %this ) = @_;
    $prom = $this{prom} = MYDan::MonitorV3::Prometheus::Tiny->new;
    my @task = qw( DiskBlocks DiskInodes Uptime Dmesg Coredump PortTcp PortUdp Process Http Sar );

    my $i = 0;
    for my $type ( @task )
    {
        $i ++;
        eval "use MYDan::MonitorV3::NodeExporter::Collector::${type};";
        warn "err: $@" if $@;
        eval "%declare = ( %declare, %MYDan::MonitorV3::NodeExporter::Collector::${type}::declare );";
        warn "err: $@" if $@;
        my $cmd;
        eval "\$cmd = \$MYDan::MonitorV3::NodeExporter::Collector::${type}::cmd;";
        warn "load cmd fail: $@" if $@;
        if( $cmd )
        {

            $this{timer}{$type} = AnyEvent->timer(
                after => $i, 
                interval => 15,
                cb => sub {
                    return if $proc{$type}{pid};
                    my ( $err, $wtr, $rdr ) = gensym;
                    my $pid = IPC::Open3::open3( undef, $rdr, undef, $cmd );
                    $proc{$type}{pid} = $pid;
                    $proc{$type}{child} = AnyEvent->child(
                        pid => $pid, cb => sub{
                            delete $proc{$type}{pid};
                            my $input;my $n = sysread $rdr, $input, 102400;
                            return unless $n;

                            my @data = eval "MYDan::MonitorV3::NodeExporter::Collector::${type}::co( \$input )";
                            warn "ERR: $@" if $@;
                            map{ $this{prom}->set($_->{name}, $_->{value}, $_->{lable}) if $declare{$_->{name}}; }@data;
                        }
                    );
                }
            ); 

        }
        else
        {
            $this{timer}{$type} = AnyEvent->timer(
                after => $i, 
                interval => 15,
                cb => sub {
                    my @data = eval "MYDan::MonitorV3::NodeExporter::Collector::${type}::co()";
                    warn "ERR: $@" if $@;
                    map{ $this{prom}->set($_->{name}, $_->{value}, $_->{lable}) if $declare{$_->{name}}; }@data;
                }
            ); 
        }
    }

    map{ $this{prom}->declare( $_, help => $declare{$_}, type => 'gauge' ); }keys %declare;

    bless \%this, ref $class || $class;
}

sub run
{
    my $this = shift;
    $this->refresh();
}

sub refresh
{
    my $this = shift;
    $this->{prom}->set('node_system_time', time);
    return $this;
}

sub format
{
    my $this = shift;
    return $this->{prom}->format;
}

1;
