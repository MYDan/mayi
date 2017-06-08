package MYDan::API::Agent;
use strict;
use warnings;
use Carp;

use JSON;
use LWP::UserAgent;

use base qw( MYDan::API );

our $URI = "/api/agent";

sub list
{
    my ( $self, $query ) = @_;
    $self->get( sprintf "$URI/list%s", $user ? "?user=$user" : '' );
}

sub create
{
    my ( $self, $name ) = @_;
    $self->get( sprintf "$URI/create?name=%s", $name || $self->{name} );
}

sub myid
{
    my ( $self, $myid ) = splice @_, 0, 2;
    $self->_api( "myid/$myid", @_ );
}

sub _api
{
    my ( $self, $type, $data ) = @_;
    $self->post( sprintf( "$URI/%s/$type", $self->{name}), $data ? ( data => $data ) :() );
}

1;
