package MYDan::Subscribe::Input::Mesg;

=head1 NAME

=head1 SYNOPSIS

 use MYDan::Subscribe::Input::DB;

 my $db = MYDan::Subscribe::Input::DB->new( '/database/file' );

 $db->select( 'node', name => [ 1, 'foo' ] );

=cut
use strict;
use warnings;

=head1 METHODS

See MYDan::Util::SQLiteDB.

=cut
use base qw( MYDan::Util::SQLiteDB );

=head1 DATABASE

A SQLITE db has a I<node> table of I<four> columns:

 name : cluster name
 attr : table name
 node : node name

=cut
our $TABLE  = 'mesg';

sub define
{
    id => 'integer PRIMARY KEY autoincrement',
    name => 'TEXT NOT NULL',
    attr => 'TEXT NOT NULL',
    mesg => 'TEXT NOT NULL',
};


=head3 insert( @record ) 

Insert @record into $table.

=cut
sub insert
{
    my $self = shift;
    $self->SUPER::insert( $TABLE, @_ );
}

=head3 select( $column, %query ) 

Select $column from $table.

=cut
sub select
{
    my $self = shift;
    $self->SUPER::select( $TABLE, @_ );
}

=head3 delete( %query ) 

Delete records from $table.

=cut
sub delete
{
    my $self = shift;
    $self->SUPER::delete( $TABLE, @_ );
}

1;
