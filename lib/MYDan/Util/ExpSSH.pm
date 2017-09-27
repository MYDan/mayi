package MYDan::Util::ExpSSH;

use strict;
use warnings;

use Expect;
use MYDan::Node;
use MYDan::Util::OptConf;
use MYDan::Util::Pass;
use MYDan::Util::Hosts;
use MYDan::Util::Alias;

our $TIMEOUT = 20;
our $SSH;
BEGIN{
    my $x = MYDan::Util::Alias->new()->alias( 'ssh' ) || 'ssh';
    $SSH = $x . ' -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -t';
};

=head1 SYNOPSIS

 use MYDan::Util::ExpSSH;

 my $ssh = MYDan::Util::ExpSSH->new( );

 $ssh->conn( host => 'foo', user => 'joe', 
             pass => '/conf/file', 
             sudo => 'user1',
             rsync => '-aP /tmp/foo user@host:/tmp/bar', #if rsync
           );

=cut

sub new
{
    my $class = shift;
    bless +{}, ref $class || $class;
}

sub conn
{
    my ( $self, %conn ) = splice @_;
    my $i = 0;

    my $hosts = MYDan::Util::Hosts->new();
    return unless my @host = $self->host( $hosts, $conn{host} );


    if ( @host > 1 )
    {
        my @host = map { sprintf "[ %d ] %s", $_ + 1, $host[$_] } 0 .. $#host; 
        print STDERR join "\n", @host, "please select: [ 1 ] ";
        $i = $1 - 1 if <STDIN> =~ /(\d+)/ && $1 && $1 <= @host;
    }

    my ( undef, $pass ) = MYDan::Util::Pass->new( conf => $conn{pass} )
        ->pass( [ $host[$i] ] => $conn{user} );

    if( $pass && ref $pass )
    {
        my $default = delete $pass->{default};
        my ( $j, @user ) = ( 0, keys %$pass );

        if( @user == 1 )
        {
            $conn{user} = $user[0];$pass = $pass->{$user[0]};
        }
        elsif ( @user  > 1 )
        {
            my @u = map { sprintf "[ %d ] %s", $_ + 1, $user[$_] } 0 .. $#user;
            print STDERR join "\n", @u, "please select: [ 1 ] ";
            $j = $1 - 1 if <STDIN> =~ /(\d+)/ && $1 && $1 <= @user;
            $conn{user} = $user[$j];
            $pass = $pass->{$user[$j]};
        }elsif( $pass = $default )
        {
            $conn{user} = `logname`;chop $conn{user};
        }
    }

    $pass .= "\n" if defined $pass;

    my $ssh;
    if ( defined $conn{rsync} )
    {
        $ssh = sprintf "rsync -e '$SSH %s ' $conn{rsync}",
            $conn{user} ? "-l $conn{user}" : '';
        print $ssh, "\n";
    }
    else
    {
        my $node = $host[$i];
        my %node = $hosts->match( $node );
        $ssh = sprintf "$SSH %s $node{$node}", $conn{user} ? "-l $conn{user}" : '';
    }

    my $prompt = '::sudo::';
    if ( my $sudo = $conn{sudo} ) { $ssh .= " sudo -p '$prompt' su - $sudo" }

    exec $ssh unless $pass;

    my $exp = Expect->new();

    $SIG{WINCH} = sub
    {
        $exp->slave->clone_winsize_from( \*STDIN );
        kill WINCH => $exp->pid if $exp->pid;
        local $SIG{WINCH} = $SIG{WINCH};
    };

    $exp->slave->clone_winsize_from( \*STDIN );
    $exp->spawn( $ssh );
    $exp->expect
    ( 
        $TIMEOUT, 
        [ qr/[Pp]assword: *$/ => sub { $exp->send( $pass ); exp_continue; } ],
        [ qr/[#\$%] $/ => sub { $exp->interact; } ],
        [ qr/$prompt$/ => sub { $exp->send( $pass ); $exp->interact; } ],
    );
}

sub host
{
    my ( $self, $hosts, $host ) = splice @_;

    return $host if $host =~ /^\d+\.\d+\.\d+\.\d+$/ || `host $host` =~ /\b\d+\.\d+\.\d+\.\d+\b/;

    my $range = MYDan::Node->new( MYDan::Util::OptConf->load()->dump( 'range') );
    my $db = $range->db;

    my %node = map{ $_ => 1 }grep{ /$host/ && /^[\w.-]+$/ }
                   map{ @$_ }$db->select( 'node' );

    map{ $node{$_} = 1 }grep{ /$host/ && /^[\w.-]+$/ }$hosts->hosts();
    return %node ? sort keys %node : $host;
}

1;
