package MYDan::Agent::Auth;

=head1 NAME

MYDan::Agent::Auth

=head1 SYNOPSIS

 use MYDan::Agent::Auth;

 my $sig = MYDan::Agent::Auth->new( key => /foo/ca/ )->sign( $mesg );

 MYDan::Agent::Auth->new( pub => /foo/ca/ )->verify( $sig, $mesg ); 


=cut
use strict;
use warnings;

use Carp;
use YAML::XS;
use File::Basename;
use Crypt::PK::RSA;
use FindBin qw( $RealBin );

sub new
{
    my ( $class, $type, $auth, %self ) = splice @_, 0, 3;
    confess "invalid auth dir" unless $auth && -d $auth;

    for my $file ( glob "$auth/*" )
    {
        $self{ basename $file} = "$file.$type" if $file =~ s/\.$type$//;;
    }

    bless \%self, ref $class || $class;
}

sub sign
{
    my ( $this, $mesg, %sig ) = splice @_, 0, 2;
    confess "no mesg"  unless $mesg;

    map 
    { 
        $sig{$_} = Crypt::PK::RSA->new( $this->{$_} )->sign_message( $mesg );
    }keys %{$this};
    return wantarray ? %sig : \%sig;
}

sub verify
{
    my ( $this, $sig, $mesg ) = @_;
    map
    { 
        next unless $sig->{$_};
        return 1 if Crypt::PK::RSA->new( $this->{$_} )->verify_message( $sig->{$_}, $mesg );
    }keys %$this;
    return 0;
}

1;
