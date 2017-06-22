package MYDan::VSSH;

use strict;
use warnings;
use MYDan::VSSH::Execute;
use MYDan::VSSH::Comp;
use MYDan::VSSH::History;
use MYDan::VSSH::Print;

$|++;

sub new
{
    my ( $class, %self ) =  @_;

    $self{config} = +{ };

    bless \%self, ref $class || $class;
}

sub run
{
    my ( $this, %busy ) = shift;
 
    my $history = MYDan::VSSH::History->new();
    my $execute = MYDan::VSSH::Execute->new( node => $this->{node} );
    my $print = MYDan::VSSH::Print->new();
    $print->welcome();

    while ( 1 )
    {
	next unless my $cmd = $this->_comp();
        exit if $cmd eq 'exit' || $cmd eq 'quit' ||  $cmd eq 'logout';
   
        my %result = $execute->run( cmd => $cmd, map{ $_ => $this->{$_}}qw( logname user ) );
        $print->result( %result );

        $history->push( $cmd );
    }
}

sub _comp
{
    my $self = shift;
    my $tc = MYDan::VSSH::Comp->new(
        'clear'  => qr/\cl/,
        'reverse'  => qr/\cr/,
        'wipe'  => qr/\cw/,
         prompt => "mydan sh#",
         choices => [ ],
         up       => qr/\x1b\[[A]/,
         down     => qr/\x1b\[[B]/,
         left     => qr/\x1b\[[D]/,
         right    => qr/\x1b\[[C]/,
         quit     => qr/[\cc]/,
    );
    my ( $cmd, $danger ) = $tc->complete();
    return $cmd unless $danger;
    while( 1 )
    {
        print "$cmd [y/n]:";
        my $in = <STDIN>;
        next unless $in;
        return $cmd if $in eq "y\n";
        return undef if $in eq "n\n";
    }
}

1;
