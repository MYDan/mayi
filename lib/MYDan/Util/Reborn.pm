package MYDan::Util::Reborn;
use strict;
use warnings;

our $VERSION = 1;

=head1 SYNOPSIS

 use MYDan::Util::Reborn;
 MYDan::Util::Reborn->new( url => '' )->do();

=cut

sub new
{
    my ( $class, %self ) = @_;
    map{die "$_ undef" unless $self{$_} }qw( url mac ipaddr netmask gateway hostname dns );
    bless \%self, ref $class || $class;
}

sub do
{
    my $this = shift;

    my ( $ksurl, $kscont ) = $this->{ks} ? ( $this->{ks} , $this->uaget( $this->{ks} ) )  : $this->ksget();

    $this->checkversion( $kscont );
    $this->call( $kscont );

    my $hostinfo = join ':',  map{ $this->{$_} }qw( hostname ipaddr netmask gateway dns );
    my $cmd = "ks=$ksurl nofb text  ksdevice=link BOOTIF=01-$this->{mac} osdrive=sda ip=dhcp net.ifnames=0 biosdevname=0 HOSTINFO=$hostinfo";

    if( -f '/boot/grub2/grub.cfg' || -f '/boot/grub/grub.cfg' )
    {
        $this->grub2( $cmd );
    }
    elsif( -f '/boot/grub/grub.conf' )
    {
        $this->grub( $cmd );
    }
    else
    {
        die "nofind grub or grub2.\n";
    }
}

sub grub2
{
    my ( $this, $cmd ) = @_;

    my ( $v, $conf ) = -f '/boot/grub2/grub.cfg' ? ( '2', '/boot/grub2/grub.cfg' ) : ( '', '/boot/grub/grub.cfg' );
    my $temp = '/tmp/05_custom.' . time;

    die "cp 40_custom fail: $!" if system "cp /etc/grub.d/40_custom $temp";
    open my $H, ">>", $temp or die "open $temp fail: $!";
    my $cont = `cat $conf`;
    die "nofind set root=" unless $cont =~ /set root='([a-zA-Z0-9,]+)'/;
    print $H <<EOF;
menuentry "install" {
        set root='$1'
        linux /install/vmlinuz $cmd
        initrd /install/initrd.img
}
EOF
    close($H);
    die "reborn fail:$!" if system "cp $temp /etc/grub.d/05_custom && grub$v-mkconfig -o $conf && grub$v-set-default 0";
}

sub grub
{
    my ( $this, $cmd ) = @_;

    my $conf = '/boot/grub/grub.conf';
    my $temp = '/tmp/grub.conf.' . time;

    die "cp $conf-0 fail:$!" if system "cp -a $conf $conf-0";
    open my $H, ">", $temp or die "open $temp fail: $!";
    print $H <<EOF;
default=0
timeout=10
#hiddenmenu
    title install
    root (hd0,0)
    kernel /install/vmlinuz $cmd
    initrd /install/initrd.img
EOF
    close($H);
    die "reborn fail:$!" if system "cat $conf-0 | grep -v default | grep -v timeout | grep -v hiddenmenu | grep -v splashimage >> $temp && cp $temp $conf" ;
}

sub call
{
    for( split /\n/, $_[1] )
    {
        next unless $_ =~ /^#MYDan::CALL=(.+)$/;
        print "call: $1\n";
        die "call $1 fail: $!" if system $1;
    }
}

sub checkversion
{
    my ( $this, $cont ) = @_;
    my $v = $cont =~ /VERSION=(\d+)/ ? $1 : return;
    die "VERSION:$VERSION ks.VERSION=$v notmatch.\n" unless $v == $VERSION;
}

sub ksget
{
    my $this = shift;

    die "notty.\n" unless -t STDIN;

    die "get kslist fail.\n" unless my $list = $this->uaget( $this->{url} );
    die "kslist null.\n" unless my @list = split /\n/, $list;;

    my %list; map{ $list{$_} = $this->uaget( $_ ) }@list; 
    die "kslist null.\n" unless @list = grep{ $list{$_} }@list;

    my $x;
    while(1)
    {
        map { printf "[ %d ] %s\n", $_ + 1, $list[$_] } 0 .. $#list;
        print "please select:";

        $x = <STDIN>;
        chomp $x;
        last if $x =~ /^\d+$/ && $x <= @list;
    }
    return ( $list[$x-1], $list{$list[$x-1]} );
}

sub uaget
{
    my ( $this, $url ) = @_;
    my $r = `curl -k --connect-timeout 3 '$url' 2>/dev/null`;
    warn "get $url: null\n" if $this->{verbose} && ! $r;
    return $r;
}

1;
