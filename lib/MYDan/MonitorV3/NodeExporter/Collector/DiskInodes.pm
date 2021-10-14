package MYDan::MonitorV3::NodeExporter::Collector::DiskInodes;

use strict;
use warnings;
use Carp;
use POSIX;

our %declare = (
    node_disk_inodes_use_percent => 'Inode usage percentage',
    node_disk_inodes_total => 'Total inode size',
    node_disk_inodes_free => 'Free size of inode',
);

our $cmd = 'LANG=en df -i -T';

#Filesystem              Type      Inodes  IUsed   IFree IUse% Mounted on
#/dev/mapper/centos-root xfs      2423440 346659 2076781   15% /
#devtmpfs                devtmpfs  998126    390  997736    1% /dev
sub co
{
    my @df = split /\n/, shift;
    my ( $error, @stat ) = ( 0 );
    eval{
        my $title = shift @df;
        die "df -i format unkown" unless $title =~ /^Filesystem\s+Type\s+Inodes\s+IUsed\s+IFree\s+IUse%\s+Mounted on$/;
        for ( @df )
        {
            my ( $filesystem, $type, $total, $use, $free, $use_percent, $mountpoint ) = split /\s+/, $_, 7;
            next if $mountpoint =~ m#^/var/lib/docker/#;
            $use_percent =~ s/%//;
            my $lable = +{ mountpoint => $mountpoint, fstype => $type, filesystem => $filesystem };

            push @stat, +{
                name => 'node_disk_inodes_use_percent',
                value => $use_percent,
                lable => $lable,
            };
            push @stat, +{
                name => 'node_disk_inodes_total',
                value => $total,
                lable => $lable,
            };
            push @stat, +{
                name => 'node_disk_inodes_free',
                value => $free,
                lable => $lable,
            };
        }
    };
    if( $@ )
    {
        warn "collector node_disk_inodes_* err:$@";
        $error ++;
    }

    push @stat, +{ name => 'node_collector_error', value => $error, lable => +{ collector => 'node_disk_inodes' } };
    return @stat;
}

1;
