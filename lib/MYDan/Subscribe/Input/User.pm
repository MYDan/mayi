package MYDan::Subscribe::Input::User;

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

 name : user name
 mark : id

=cut
our $TABLE  = 'user';

sub define
{
    name => 'TEXT NOT NULL UNIQUE',
    mark => 'TEXT NOT NULL',
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
