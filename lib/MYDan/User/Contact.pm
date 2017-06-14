package MYDan::User::Contact;
use strict;
use warnings;
use Carp;
use YAML::XS;

=head1 SYNOPSIS

 use MYDan::User::Contact;
 my $contact = MYDan::User::Contact->new();
 my $email = $contact->contact( 'user1' => 'email' );

=cut

use MYDan::Util::OptConf;

our %o; BEGIN{ %o = MYDan::Util::OptConf->load()->dump( 'user' ) };

sub new
{
    my ( $class, %this ) = @_;

    $this{config} = eval{ YAML::XS::LoadFile $this{file} || "$o{conf}/contact" };
    die "load config error:$@" if $@;

    bless \%this, ref $class || $class;
}

sub contact
{
    my ( $this, $user, $type ) = @_;
    return $this->{$user}{$type};
}

1;
