package MYDan::API::AntDen;
use strict;
use warnings;

use base qw( MYDan::API );
our $URI = "";

sub submitjob
{
    my ( $self, %data ) = @_;
    return $self->post( "$URI/scheduler/submitJob", %data );
}

sub listjob
{
    my ( $self, $owner ) = @_;
    return $self->get( "$URI/scheduler/listJob?owner=$owner" );
}

sub info
{
    my ( $self, $jobid ) = @_;
    return $self->get( "$URI/scheduler/jobinfo/$jobid" );
}

sub stop
{
    my ( $self, $jobid ) = @_;
    return $self->get( "$URI/scheduler/jobstop/$jobid" );
}

sub taskinfo
{
    my ( $self, $taskid ) = @_;
    return $self->get( "$URI/scheduler/taskinfo/$taskid" );
}

sub resources
{
    return shift->get( "$URI/scheduler/resources" );
}

1;
