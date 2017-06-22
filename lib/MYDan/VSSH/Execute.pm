package MYDan::VSSH::Execute;

use strict;
use warnings;

use MYDan::Agent::Client;
use MYDan::Util::OptConf;

$|++;

our %o; BEGIN{ %o = MYDan::Util::OptConf->load()->dump('agent');};
sub new
{
    my ( $class, %self ) =  @_;
    bless \%self, ref $class || $class;
}

sub run
{
    my ( $this, %param ) = @_;
 
    my %query = ( code => 'exec', argv => [ $param{cmd} ], map{ $_ => $param{$_} }qw( logname user ) );

    my $client = MYDan::Agent::Client->new( @{$this->{node}} );
    return $client->run( %o, query => \%query );
}

1;
