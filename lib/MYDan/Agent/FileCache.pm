package MYDan::Agent::FileCache;

=head1 NAME

MYDan::Agent::FileCache

=head1 SYNOPSIS

 use MYDan::Agent::FileCache;

 my $fc = MYDan::Agent::FileCache->new();
 
 $fc->save( '/my/file' );
 $fc->save( '/my/file' => md5 );

 $fc->check( md5 );

 $fc->get( '/my/file' => md5 );

 $fc->clean();

=cut
use strict;
use warnings;

use MYDan;
use Digest::MD5;

sub new
{
    my ( $class, %self ) = @_;
    $self{path} ||= "$MYDan::PATH/var/run/filecache";
    bless \%self, ref $class || $class;
}

sub save
{
    my ( $this, $file, $md5, $mv ) = @_;

    my $path = $this->{path};
    return 0 unless -e $path && defined $file &&  -f $file && ! -l $file;

    unless( $md5 && $md5 =~ /^[a-zA-Z0-9]+$/ )
    {
        open my $fh, "<$file" or die "open fail: $!";
        $md5 = Digest::MD5->new()->addfile( $fh )->hexdigest();
        close $fh;
    }

    return 1 if -e "$path/$md5";

    if( $mv )
    {
        die "save fail: $!" if system "mv '$file' '$path/$md5'";
    }
    else
    {
        my $id = time.$$;
        die "save fail: $!" if system "cp '$file' '$path/$md5.$id' && mv '$path/$md5.$id' '$path/$md5'";
    }
    
    return 1;
}

sub check
{
    my ( $this, $md5 ) = @_;

    my $path = $this->{path};
    return 0 unless -e $path && defined $md5;

    return  -e "$path/$md5" ? 1 : 0;
}

sub get
{
    my ( $this, $file, $md5 ) = @_;

    my $path = $this->{path};
    return 0 unless -e $path && defined $file && defined $md5 &&  -e "$path/$md5";

    die "get fail: $!" if system "cp '$path/$md5' '$file'";
    return 1;
}

sub clean
{
    my ( $this, $md5 ) = @_;

    my $path = $this->{path};
    return 0 unless -e $path && defined $md5;

    my $c = 0;
    for my $f ( grep{ -f } glob "$path*" )
    {
        if( $f =~ m/\/[a-zA-Z0-9]{32}\.\d+$/ )
        {
            my $t = ( stat $f )[9];
            unlink $f if $t && $t < time - 3600;
            $c ++;
        }
        elsif( $f =~ m/\/[a-zA-Z0-9]{32}$/ )
        {
            my $t = ( stat $f )[9];
            unlink $f if $t && $t < time - 604800;
            $c ++;
        }
    }

    return $c;
}

1;
