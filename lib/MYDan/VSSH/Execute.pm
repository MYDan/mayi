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
 
    my %query = ( code => 'exec', argv => [ $param{cmd} ] );

    my $client = MYDan::Agent::Client->new( map { join ':', $_, $o{port} } @{$this->{node}});
    my %result = $client->run( query => \%query );
    map{ my $k = $_;$k =~ s/:$o{port}$//; $k => $result{$_} }keys %result;
}

1;
