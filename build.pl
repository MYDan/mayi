#!/usr/bin/env perl
my $perl = $ENV{PERL_PATH} || $^X;
my $mydan = $perl;$mydan =~ s/\/perl\/bin\/perl$//;

my $cpan = $perl;$cpan =~ s/perl$/cpan/;
system( "$cpan install YAML::XS" ) if ( system "$perl -e \"use YAML::XS\"" );

exec "$perl Makefile.PL && make && make install mydan=$mydan && make clean";
