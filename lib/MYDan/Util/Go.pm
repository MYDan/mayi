package MYDan::Util::Go;
use strict;
use warnings;

use Expect;
use YAML::XS;
use Authen::OATH;
use Convert::Base32 qw( decode_base32 );

our $TIMEOUT = 20;

=head1 SYNOPSIS

 use MYDan::Util::Go;
 MYDan::Util::Go->new( '/path/go')->go();

=cut

sub new
{
    my ( $class, $path ) = @_;

    my $conf = $path && -e $path ? eval{ YAML::XS::LoadFile $path } : +{};
    die "load $path fail:$@" if $@;

    bless $conf, ref $class || $class;
}

sub go
{
    my $this = shift;

    return unless my @host = sort keys %$this;

    my $i = 0;
    if( @host > 1 )
    {
        my @host = map { sprintf "[ %d ] %s", $_ + 1, $host[$_] } 0 .. $#host; 
        print STDERR join "\n", @host, "please select: [ 1 ] ";
        $i = $1 - 1 if <STDIN> =~ /(\d+)/ && $1 && $1 <= @host;
    }

    my $conf = $this->{$host[$i]};

    my $exp = Expect->new();
    $SIG{WINCH} = sub
    {
        $exp->slave->clone_winsize_from( \*STDIN );
        kill WINCH => $exp->pid if $exp->pid;
        local $SIG{WINCH} = $SIG{WINCH};
    };

    $conf->{expect} = +{} unless $conf->{expect} && ref $conf->{expect} eq 'HASH';

    for ( keys  %{$conf->{expect}} )
    {
        next unless $conf->{expect}{$_} =~ /googlecode\s*:\s*(\w+)/;
	$conf->{expect}{$_} = Authen::OATH->new->totp(  decode_base32( $1 ));
    }

    $exp->slave->clone_winsize_from( \*STDIN );
    $exp->spawn( $conf->{go} );
    $exp->expect
    ( 
        $TIMEOUT, 
        [ qr/[#\$%] $/ => sub { $exp->interact; } ],
	map{ my $v = $conf->{expect}{$_};[ qr/$_/ => sub { $exp->send( "$v\n" ); exp_continue; } ] }keys %{ $conf->{expect} }
    );
}

1;
