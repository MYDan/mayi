package NS::Util::MCMD;

=head1 NAME

NS::Util::MCMD

=head1 SYNOPSIS

 use NS::Util::MCMD;

 my %proxy_config = ( );
 my $client = NS::Util::MCMD->new( [ 'node1', 'node2' ] )
                  ->proxy( 'proxy/config/path' );

 my %result = $client->run( timeout => 300, cmd => \@cmd ); 

=cut

use strict;
use warnings;

use Carp;
use YAML::XS;

use NS::MIO::TCP;
use NS::MIO::CMD;
use NS::Poros::Query;

our %RUN = ( max => 128, timeout => 300, 'proxy-timeout' => 86400, 'proxy-max' => 32 );

sub new
{
    my $class = shift;
    bless +{ node => \@_ }, ref $class || $class;
}

sub proxy
{
    my ( $this, $conf ) = @_;

    return $this unless $conf && $this->{node} && ref $this->{node} eq 'ARRAY';

    $conf = eval{ YAML::XS::LoadFile $conf };
    confess "load proxy file fail: $@\n" if $@;

    my %conf = map{ $_->[0] => $_->[1] }@$conf;

    my %proxy;
    for my $node ( @{$this->{node} } )
    {
        map{
            if( $node =~ /$_->[0]/ ) 
            {
                push( @{$proxy{$_->[0]}}, $node );
                next;
            }
        }@$conf;
    }

    my %node;
    while( my ( $k, $n ) = each %proxy )
    {
        for( my $i = 0; @$n; $i++ )
        {
            $i = 0 if $i >= @{$conf{$k}};
            push @{$node{$conf{$k}->[$i]}}, shift @$n;
        }
    }

    $this->{node} = \%node;
    return $this;
}

sub run
{
    my ( $this, %run, %result ) = ( shift, %RUN, @_ );

    return unless my $node = $this->{node};

    my %mcmd_run = map{ $_ => $run{$_} }qw( timeout max noop );

    if( ref $node eq 'ARRAY' || $run{noop} )
    {
        $node = [ map{ @$_ }values %$node ] if ref $node ne 'ARRAY';

        %result = NS::MIO::CMD->new( map { $_ => $run{cmd} } @$node )
            ->run( %mcmd_run );

        return %result;

    }

    my ( %input, %check );
    while( my ( $proxy, $n ) = each %$node )
    {
        
        $input{$proxy} = NS::Poros::Query->dump( 
            +{
               proxy => { node => $n, exe => { %mcmd_run, cmd => $run{cmd} } }, 
               code => 'proxy',
             } 
        );
        map{ $check{$_} = 1 }@$n;
    }

    my %r = NS::MIO::TCP->new( keys %$node )
        ->run( input => \%input, map{ $_ => $run{"proxy-$_"} }qw( timeout max ) );

    my ( $error, $mesg ) = @r{qw( error mesg )};

    if( $error )
    {
        while( my ( $m, $n ) = each %$error )
        {
            my @node = map{@$_}@$node{@$n};
            push @{$result{stderr}{"[ns proxy error]: $m\n"}}, @node;
            map{ delete $check{$_} } @node;
        }
    }

    if( $mesg )
    {
         while( my ( $m, $n ) = each %$mesg )
        {
            my @node = map{@$_}@$node{@$n};
            map{ delete $check{$_} } @node;

            my $stat = $1 if $m =~ s/--- (\d+)$//;

            my ( $error, $mc ) = ( ! defined $stat ) 
                ? "[ns proxy no return]"
                : $stat ? "[ns proxy exit: $stat]" : undef;

            unless ( $error )
            {
                $mc = eval{ YAML::XS::Load ( $m ) };
                $error = "[ns proxy mesg no hash]: $@" if $@;
            }

            if( $error )
            {
                push @{$result{error}{"$error\n"}}, @node;
                next;
            }

            while( my ( $t, $v ) = each %$mc )
            {
                while( my ( $msg, $no ) = each %$v )
                {
                    push @{$result{$t}{$msg}}, @$no;
                }
            }
        }
    }   

    push @{$result{stderr}{"[ns proxy error]: no run\n"}}, keys %check if %check;

    return %result;
}

1;
