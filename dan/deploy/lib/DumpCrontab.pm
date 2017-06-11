package DumpCrontab;
use strict;
use warnings;

use YAML::XS;
use Digest::MD5;
use MYDan::Util::DBConn;
use MYDan::Node::DBI::Root;

use Tie::File;
use MYDan::Util::OptConf;
use File::Basename;
use Data::Dumper;
use MIME::Base64;

our %deploy;
BEGIN{ 
   %deploy = MYDan::Util::OptConf->load()->get()->dump('deploy'); 
   map{ die "$_ undef on deploy" unless $deploy{$_}  }qw( conf bin );
};

sub new
{
    my ( $class, %self ) = @_;

    map{ die "$_ undef" unless $self{$_} }qw( conn cron name );

    bless \%self, ref $class || $class;
}

sub run
{
    my $this = shift;

    my ( $conn, $cron, $name ) = @$this{ qw( conn cron name ) };
    
    my $crontab = MYDan::Util::DBConn->new( $conn )
        ->exe( 'select ID,PROJECTID,NAME,USER,BATCH,TIMEOUT,CMD,
                   Timer,NODE,`DESC` from crontab where stat="enabled"' );
    my $node = MYDan::Util::DBConn->new( $conn )
        ->exe( 'select ID,Node from project where node is not null' );

    my %cron = map{ $_->[0] => $_->[7] }@$crontab;   
    my %node = map{ $_->[0] => $_->[1] }@$node;

    print Dumper \%cron;

    die "tie cron.mould fail: $!" unless tie my @mould, 'Tie::File', "$deploy{conf}/$name";
    for my $data ( @$crontab )
    {
        die "tie cron.mould fail: $!" unless 
            tie my @conf, 'Tie::File', "$deploy{conf}/.cron.id_$data->[0].handle";

        my %node;
        for( split ';', $data->[8] )
        {
            next unless $_ =~ /^([@\w_]+):{([\d,~*]+)}$/;
            $node{"{==\$DB==$1??=={$2}}"}  = 1;
        }
    
        my $range = join ',', keys %node;
        my $node = $node{$data->[1]}|| 'node_undef';
        $range =~ s/\$DB/$node/g;

        my $exec = decode_base64( $data->[6] ) if $data->[6];

        @conf = @mould;
        map{
            $_ =~ s/\$env{test}/0/;
            $_ =~ s/\$env{batch}/$data->[4]/ if $data->[4];
            $_ =~ s/\$env{timeout}/$data->[5]/ if $data->[5];
            $_ =~ s/\$env{user}/$data->[3]/ if $data->[3];
            $_ =~ s/\$env{exec}/$exec/ if $exec;
            $_ =~ s/\$env{host}/$range/ if $range;
        }@conf;
        rename  "$deploy{conf}/.cron.id_$data->[0].handle",  "$deploy{conf}/cron.id_$data->[0]";
        print "make deploy conf: $data->[0]\n";
    }

    unlink glob "$deploy{conf}/.dan.deploy.cron.id_*.job.handle";

    for( keys %cron )
    {
        die "tie fail: $!" unless tie my @conf, 'Tie::File', "$cron/dan.deploy.cron.id_$_.job";
        @conf = ( "$cron{$_} root $deploy{bin}/deploy cron.id_$_" );
        print "make crontab conf: $_\n";
    }

    for ( glob "$cron/*" )
    {
        my $name = basename $_;
        next unless $name =~ /^dan\.deploy\.cron\.id_(\d+).job$/;
        next if $cron{$1};
        print "unlink: $name\n";
        unlink "$cron/dan.deploy.cron.id_$1.job";
    }
    return $this;
}

1;
