package MYDan::Util::Percent;
use strict;
use warnings;

$|++;

sub new
{
    my $class = shift;
    bless +{ size => shift, len => 0 }, ref $class || $class;
}

sub renew
{
    my $this = shift;
    $this->{size} = shift;
    return $this;
}

sub add
{
    my $this = shift;
    $this->{len} = $this->{len}  + shift;
    return $this;
}

sub print
{
    my ( $this, $prompt ) = @_;
    my ( $size, $len ) = @$this{qw( size len )};
    $prompt ||='';
    my $p = $size ? sprintf( "%d", $len*100/$size ) : 0;
    $p = 100 if $p >100;
    print "\r$prompt $p%";
    print "\n" if $p==100;
    return $this;
}

1;
__END__
