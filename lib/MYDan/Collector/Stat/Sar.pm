package MYDan::Collector::Stat::Sar;
use strict;
use warnings;
use Carp;
use POSIX;

my %alias = ( 
    CPU => +{ '%usr' => '%user', '%sys' => '%system' },
    IFACE => +{ 'rxkB/s' => 'rxbyt/s', 'txkB/s' => 'txbyt/s' }
);

sub co
{
    local $/ = "\n";

    my ( $interval, $flip, $flop, @data, @stat, $cmd ) = -t STDIN ? 1 : 6;

    eval{
        confess "open: $!" unless open $cmd, "LANG=en sar -A $interval 1 |";
    };

    return () if $@;
    

    while ( my $line = <$cmd> )
    {
        $flop = $flip if $flip = $line =~ s/^Average:\s+//;
        next unless $flop;

        if ( length $line > 1 ) { push @data, [ split /\s+/, $line ] }
        else { $flop = $flip; push @stat, [ splice @data ] }
    }

    push @stat, [ splice @data ] if @data;

    for my $stat ( @stat )
    {
        my $title = $stat->[0];
        next unless $alias{$title->[0]};

        if( 'IFACE' eq $title->[0] )
        {
            my @all = ( 'ALL' );
            for my $index ( 1 .. @$title -1 )
            {
                map{ $all[$index] += $stat->[$_][$index] }1 .. @$stat -1;
            }
            push @$stat, \@all;
            for my $index ( 1 .. @$title -1 )
            {
                next unless $title->[$index] eq 'rxkB/s' || $title->[$index] eq 'txkB/s';
                map { $stat->[$_][$index] *= 1024; }1 .. @$stat -1;
            }
        }

        map{
            my $t = $alias{$title->[0]}{$title->[$_]};
            $title->[$_] = $t if defined $t;
        } 0 .. @$title -1;
    }

    return @stat;
}

1;
