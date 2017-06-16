package MYDan::Subscribe::Input;
use strict;
use warnings;
use Carp;
use YAML::XS;

use Data::Dumper;

sub new
{
    my ( $class, %this ) = @_;
    bless \%this, ref $class || $class;
}

sub push
{
    my ( $this, @in ) = @_;

    print Dumper \@in;
}

1;
