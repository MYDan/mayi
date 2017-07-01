package MYDan::VSSH::Execute;

use strict;
use warnings;

use MYDan::Agent::Client;
use MYDan::Util::OptConf;

use MYDan::Node;
use YAML::XS;
use MYDan::Util::MIO::SSH;

our $dan = 1;
our $pass;

$|++;

our %o; BEGIN{ %o = MYDan::Util::OptConf->load()->dump('agent'); };
sub new
{
    my ( $class, %self ) =  @_;
    bless \%self, ref $class || $class;
}

sub run
{
    my ( $this, %param ) = @_;
 
    if( $dan )
    {
        my %query = ( code => 'exec', argv => [ $param{cmd} ], map{ $_ => $param{$_} }qw( logname user ) );

        my $client = MYDan::Agent::Client->new( @{$this->{node}} );
        return $client->run( %o, query => \%query );
    }
    else
    {

        unless( defined $pass )
        {

            my $option = MYDan::Util::OptConf->load();

            my $range = MYDan::Node->new( $option->dump( 'range' ) );

            my $conf = eval{ YAML::XS::LoadFile sprintf "%s/pass", $option->dump( 'util' )->{conf} };
            die "load pass fail:$@" if $@;
            my %pass;
            while ( my ( $node, $pass ) = each %$conf )
            {
                map{ $pass{$_} = $pass }$range->load( $node )->list();
            }
            $pass = \%pass;

        }

        tie my @input, 'Tie::File', my $input = "/tmp/mssh.".time.".$$";
        @input = ( $param{cmd} );

        my %result = MYDan::Util::MIO::SSH->new( map{ $_ => [] }@{$this->{node}} )->run( user => $param{user}, pass => $pass, input => $input );
        my %re;
        while( my ( $type, $result ) = each %result )
        {
            map{ my $t = $_; map{ $re{$_} .= $t } @{$result->{$t}};}keys %$result;
        }
        return %re;
    }
}

1;
