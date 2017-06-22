package MYDan::Subscribe::Input;
use strict;
use warnings;
use Carp;
use YAML::XS;

use Data::Dumper;
use POSIX;

use MYDan::Util::OptConf;
my %o; BEGIN{ %o = MYDan::Util::OptConf->load()->dump('subscribe');};
use MYDan::Subscribe::Input::Mesg;

sub new
{
    my ( $class, %this ) = @_;
    bless \%this, ref $class || $class;
}

sub push
{
    my ( $this, $mesg, $name, $attr ) = @_;

    $name = 'unkown' if $name && $name =~ /^[a-zA-Z0-9_\-]+$/;
    $attr = 'unkown' if $attr && $attr =~ /^[a-zA-Z0-9_\-]+$/;

    
    my $db = MYDan::Subscribe::Input::Mesg->new( 
        sprintf( "$o{input}/%s",  POSIX::strftime( "%Y-%m-%d_%H", localtime ) ),
        $MYDan::Subscribe::Input::Mesg::TABLE
    );
    $db->insert( $name, $attr, $mesg );
}

1;
