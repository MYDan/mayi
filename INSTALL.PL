#use strict;
#use warnings;
use FindBin qw( $Bin );
use Tie::File;

exit 0 unless my $mydan = $ENV{mydan};
die "no such path: $mydan\n" unless -d $mydan;
die "rsync dan to tmp fail.\n" if system "rsync -a dan/ 'dan.i/'";


my $perl = $ENV{PERL_PATH} || $^X;
for my $file ( `find dan.i -type f` )
{
    chomp $file;
    tie my ( @file ), 'Tie::File', $file;

    next unless @file && $file[0] =~ /#![^#]*perl(.*$)/o;
    $file[0] = "#!$perl$1";
    warn "$file\n";
    untie @file;
}

if( my $conf = $ENV{conf} )
{
    die "conf $conf undef.\n" unless -d "conf/$conf";
    die "rsync conf $conf fail.\n" if system "rsync -a 'conf/$conf/' 'dan.i/'";
}

die "rsync dan to '$mydan/dan/' fail.\n" if system "rsync -a dan.i/ '$mydan/dan/'";

my ( $cpan, $do )= $perl;$cpan =~ s/perl$/cpan/;
for(0..2)
{
    warn "check PREREQ_PM\n";
    if( system "$perl -e \"use YAML::XS\"" )
    {
         system( "$cpan install YAML::XS" );
         $do = 1;
    }
    use YAML::XS;
    #require YAML::XS;
    my $x = eval{ YAML::XS::LoadFile 'MYMETA.yml' };
    map{
        if( system "$perl -e \"use $_\"" )
        {
            system( "$cpan install $_" );
            $do = 1;
        }
    }keys %{$x->{requires}};
    last unless $do;
};

exit 0;
