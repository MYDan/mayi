package MYDan::Agent::Porxy;

=head1 NAME

MYDan::Agent::Porxy

=head1 SYNOPSIS

 use MYDan::Agent::Porxy;

 my $porxy = MYDan::Agent::Porxy->new( '/conf/file' );

 my %r = $porxy->search( 'node1', 'node2', '10.10.0.1', '10.10.0.2' );
 
 %r = (
      node1 => undef, node2 => undef,
      '10.10.0.1' => 'porxyip',
      '10.10.0.2' => 'porxyip',
  );

=cut
use strict;
use warnings;

use Carp;
use Tie::File;

sub new
{
    my ( $class, $conf ) = @_;
    confess "no conf" unless $conf && -e $conf;

    die "tie fail: $!" unless tie my @conf, 'Tie::File', $conf;
    
    my @c;
    for my $c ( @conf )
    {
        next unless $c =~ /^\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\/(\d{1,2})\s*:\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s*$/;
        push @c, +{ ip => $1, mask=> $2, porxy => $3, net => substr(unpack("B32",pack("C4", (split/\./,$1))),0,$2) };
    }

    untie @conf;

    bless [ sort{ $a->{mask} <=> $b->{mask} }@c ], ref $class || $class;
}

sub search
{
    my ( $this, @node, %result ) = @_;

    my @conf = @$this;

    for my $node ( @node )
    {
        $result{$node} = undef;
        next unless $node =~ /^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/;

        for my $conf ( @conf )
        {
             next unless substr(unpack("B32",pack("C4", (split/\./,$node))),0,$conf->{mask})  == $conf->{net};
             $result{$node} = $conf->{porxy};
             last;
        }
    }

    return %result;
}

1;
