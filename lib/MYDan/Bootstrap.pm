package MYDan::Bootstrap;
use strict;
use warnings;
use Carp;
use YAML::XS;

use File::Basename;
use MYDan::Util::ProcLock;
use POSIX qw( :sys_wait_h );
use AnyEvent::Loop;
use AnyEvent;

use IPC::Open3;
use Symbol 'gensym';
use Time::TAI64 qw/unixtai64n/;
use Data::Dumper;

my %RUN =( size => 10000000, keep => 5 );
our %time;

our %proc;
sub new
{
    my ( $class, %this ) = @_;
    map{ 
        confess "$_ undef" unless $this{$_};
        system "mkdir -p '$this{$_}'" unless -d $this{$_};
    }qw( logs exec lock );
    bless \%this, ref $class || $class;
}

sub run
{
    my ( $this, %run ) = @_;

    our ( $logs, $exec, $lock ) = @$this{qw( logs exec lock )};
    my $proclock = MYDan::Util::ProcLock->new( "$lock/lock" );
   
    if ( my $pid = $proclock->check() )
    {
        print "master locked by $pid.\n" if $ENV{MYDan_DEBUG};
        exit;
    }
   
    $proclock->lock();
    $0 = 'mydan.bootstrap.master';

    
    my ( $i, $cv ) = ( 0, AnyEvent->condvar );

    our ( $logf, $logH ) = ( "$logs/current" );
    
    print "log $logs/current\n";
    confess "open log: $!" unless open $logH, ">>$logf"; 
    $logH->autoflush;



    my $t = AnyEvent->timer(
        after => 2,
        interval => 3,
        cb => sub {
            print "check\n";
            my @name = map{ basename $_ }glob "$exec/*";
            print Dumper \@name,\%proc;
            for my $name ( @name )
            {
                next if $proc{$name};
                my ( $err, $wtr, $rdr ) = gensym;
                my $pid = IPC::Open3::open3( undef, $rdr, $err, "$exec/$name" );
           
		$proc{$name}{pid} = $pid;
                $proc{$name}{rdr} = AnyEvent->io (
                    fh => $rdr, poll => "r",
                    cb => sub {
                        my $input = <$rdr>; 
                        delete $proc{$name}{rdr} and return unless $input;
                        chomp $input;
                        print $logH unixtai64n(time), " [$name] [STDOUT] $input\n";
                    }
                );
                $proc{$name}{err} = AnyEvent->io (
                    fh => $err, poll => "r", 
                    cb => sub {
                        my $input = <$err>;
                        delete $proc{$name}{err} and return unless $input;

                        chomp $input;
                        print $logH unixtai64n(time), " [$name] [STDERR] $input\n"; 
                    }
                );
            }
        }
    );
    my $tt = AnyEvent->timer(
        after => 30,
        interval => 60,
        cb => sub {
            print "cut log\n";
            my $size= ( stat "$logs/current" )[7];
            return unless $size > $RUN{size};
            my $num = $this->_num();
            system "mv '$logs/current' '$logs/log.$num'";
            
	    confess "open log: $!" unless open $logH, ">>$logf"; 
	    $logH->autoflush;
             
        }
    );

    $cv->recv;
    return $this;
}

sub _num
{
    my ( $logs, %time ) = shift->{logs};
    for my $num ( 1 .. $RUN{keep} )
    {
       return $num unless $time{$num} = ( stat "$logs/log.$num" )[10];
    }
    return ( sort{ $time{$a} <=> $time{$b} } keys %time )[0];
}

1;
