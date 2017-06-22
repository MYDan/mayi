package MYDan::Subscribe::Input;
use strict;
use warnings;
use Carp;
use YAML::XS;

use Data::Dumper;
use POSIX;

use MYDan::Util::OptConf;
my %o; BEGIN{ %o = MYDan::Util::OptConf->load()->dump('subscribe');};
use MYDan::Subscribe::DBI::Mesg;
use File::Basename;
use MIME::Base64;

sub new
{
    my ( $class, %this ) = @_;
    bless \%this, ref $class || $class;
}

sub push
{
    my ( $this, $mesg, $name, $attr ) = @_;

    $name = 'unkown' unless $name && $name =~ /^[a-zA-Z0-9_\-]+$/;
    $attr = 'unkown' unless $attr && $attr =~ /^[a-zA-Z0-9_\-]+$/;

    
    my $db = MYDan::Subscribe::DBI::Mesg->new( 
        sprintf( "$o{input}/%s",  POSIX::strftime( "%Y-%m-%d_%H", localtime ) ),
        $MYDan::Subscribe::DBI::Mesg::TABLE
    );
    $db->insert( $name, $attr, encode_base64( $mesg ), POSIX::strftime( "%Y-%m-%d_%H:%M:%S", localtime ) );
}

sub list
{
    map{ basename $_ } glob "$o{input}/*";
}


sub dump
{
    my ( $this, $time ) = @_;
    my $db = MYDan::Subscribe::DBI::Mesg->new( "$o{input}/$time", $MYDan::Subscribe::DBI::Mesg::TABLE  );
    map{ [ $_->[4], @$_[0..2], decode_base64($_->[3])] } $db->dump( $MYDan::Subscribe::DBI::Mesg::TABLE );
}

1;
