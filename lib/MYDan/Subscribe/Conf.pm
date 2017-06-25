package MYDan::Subscribe::Conf;
use strict;
use warnings;
use Carp;
use YAML::XS;

use Data::Dumper;
use POSIX;

use MYDan::Util::OptConf;
use File::Basename;
use MYDan::Subscribe::DBI::DB;
use MYDan::Notify;

sub new
{
    my ( $class, %this ) = @_;

    die "path undef" unless $this{path};
    $this{db} =  MYDan::Subscribe::DBI::DB->new(
        $this{path},
        $MYDan::Subscribe::DBI::DB::TABLE
    );

    bless \%this, ref $class || $class;
}

sub insert
{
    my ( $this, %param ) = @_;
    $this->{db}->insert( @param{qw( user attr user level)} );
}

sub select
{
    my ( $this, %param, %query ) = @_;

    map{ $query{$_} = [ 1, $param{$_} ] if $param{$_} }qw( user attr user level);
    $this->{db}->select( '*', %query );
}

sub delete
{
    my ( $this, %param, %query ) = @_;

    map{ $query{$_} = [ 1, $param{$_} ] if $param{$_} }qw( user attr user level);
    $this->{db}->delete( %query );
}


1;
