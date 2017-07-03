package MYDan::VSSH::Execute;

use strict;
use warnings;

use MYDan::Agent::Client;
use MYDan::Util::OptConf;

use MYDan::Node;
use YAML::XS;
use MYDan::Util::MIO::SSH;
use MYDan::Util::Pass;

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

        $param{user} = `logname` and chop $param{user} unless $param{user};

        $pass = +{ MYDan::Util::Pass->new()->pass( $this->{node} => $param{user} )}unless defined $pass;
        tie my @input, 'Tie::File', my $input = "/tmp/mssh.".time.".$$";
        @input = ( $param{cmd} );

        my ( %result, %re )= MYDan::Util::MIO::SSH->new( map{ $_ => [] }@{$this->{node}} )
            ->run( user => $param{user}, pass => $pass, input => $input );

        while( my ( $type, $result ) = each %result )
        {
            map{ my $t = $_; map{ $re{$_} .= $t } @{$result->{$t}};}keys %$result;
        }
        return %re;
    }
}

1;
