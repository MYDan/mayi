#!/usr/bin/env perl
use strict;
use warnings;

use FindBin qw( $RealBin );
use Tie::File;

my $mydan = $RealBin;
chdir $mydan;

die "no find mydan path" unless $mydan =~ s/mydan\/mayi$/mydan/;

die "rsync box to tmp fail.\n" if system "rsync -a box/ 'box.i/'";

die "rsync dan/node to tmp fail.\n" if system "rsync -a dan/node/ 'box.i/node/'";

map{
    die "rsync dan/tools/$_ to tmp fail.\n"
        if system "rsync -a dan/tools/$_ 'box.i/tools/$_'";
}qw( range mcmd mssh expect vssh );

map{
    die "rsync dan/util/conf/$_ to tmp fail.\n"
        if system "rsync -a dan/util/conf/$_ 'box.i/util/conf/$_'";
}qw( pass expect );

my $perl = $ENV{PERL_PATH} || $^X;
for my $file ( `find box.i -type f` )
{
    chomp $file;
    tie my ( @file ), 'Tie::File', $file;

    next unless @file && $file[0] =~ /#![^#]*perl(.*$)/o;
    $file[0] = "#!$perl$1 -I $mydan/mayi/lib/";
    warn "$file\n";
    untie @file;
}

die "sed fail" if system "sed -i 's/MYDan::VSSH::Execute::dan=1/MYDan::VSSH::Execute::dan=0/' box.i/tools/vssh";

die "rsync dan to '$mydan/dan/' fail.\n" if system "rsync -a box.i/ '$mydan/box/'";

my $cpan = $perl;$cpan =~ s/perl$/cpan/;

for(0..2)
{
    warn "check PREREQ_PM\n";
    my $do;
    map{
        if( system "$perl -e \"use $_\"" )
        {
            system( "$cpan install $_" );
            $do = 1;
        }
    }qw(
        YAML::XS
    );
    last unless $do;
};

system "rm -rf box.i";
exit 0;
