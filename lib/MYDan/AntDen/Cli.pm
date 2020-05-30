package MYDan::AntDen::Cli;
use strict;
use warnings;

use Carp;
use MYDan;
use MYDan::Util::OptConf;
use MYDan::Agent::Client;

sub new
{
    my ( $class, %self ) = splice @_;
    bless +{ %self, mt => "$MYDan::PATH/dan/tools" }, ref $class || $class;
}

sub _api
{
    my $this = shift @_;

    my %api = MYDan::Util::OptConf->load()->set()->get()->dump( 'api' );
    die "api.addr undef" unless my $api = $api{addr};
    $api =~ s/^http[s]*:\/\///;
    $api =~ s/:.*$//;
    $api =~ s/\/.*$//;
    die "api.addr error" unless $api && $api =~ /^[a-zA-Z0-9\.]+$/;

    return $api;
}

sub _rcall
{
    my ( $this, %argv ) = splice @_;

    my $option = MYDan::Util::OptConf->load();
    my %o = $option->set( timeout => 60 )->get()->dump( 'agent' );

    $o{user} = `id -un` and chop $o{user} unless $o{user};
    $o{sudo} = 'root';

    my $api = $this->_api();
    my %query = ( code => 'antdencli', argv => \%argv, map{ $_ => $o{$_} }qw( user sudo ) );

    my %result = MYDan::Agent::Client->new( 
	$api
    )->run( %o, query => \%query ); 

    my $res = $result{$api} || '';
    die "call fail: $res" unless $res =~ s/--- 0$//;
    return $res;
}

sub run
{
    my ( $this, %run ) = splice @_;

    map{ die "$_ undef" unless defined $run{$_} }qw( nice group count resources );
    my $api = $this->_api();

    my $uuid = time . '.'. sprintf "%012d", int rand 1000000000000;

    my $user = $ENV{MYDan_username};
    $user = `id -un` and chop $user unless $user;

    my ( $temp, $repofile, $runpath ) = ( "/tmp/antden.pkg.$uuid.tar.gz", "/data/AntDen_repo/$user.$uuid.tar.gz", "/tmp/AntDen.run.$uuid" );

    print "[INFO]Compress local path...\n";
    die "tar fail: $!" if system "tar -zcvf $temp `ls -a|grep -v '^\\.\$'|grep -v '^\\.\\.\$'`";
    print "[INFO]Upload data...\n";
    die "dump fail: $!" if system "$this->{mt}/rcall -r $api dump $temp --path '$repofile' --sudo root >/dev/null";
    die "remove temp file $temp fail:$!" if system "rm -f $temp";

    print "[INFO]Submit job...\n";

    my @resources;
    map{
        push( @resources, [ $1, '.', $2 ]) if $_ =~ /^([A-Z]+):(\d+)$/;
    } split /,/, $run{resources};

    die "resources err" unless @resources;

    my %argv = (
        ctrl => 'submitjob',
        conf => +{
            nice => $run{nice},
            group => $run{group},
            config => [+{
                executer => +{
                    name => 'exec',
                    param => +{
                        exec => "MYDan_Agent_Load_Code=free.load_antden $this->{mt}/load --host $api  --sp '$repofile' --dp $runpath.tar.gz && mkdir -p $runpath && tar -zxvf $runpath.tar.gz -C '$runpath' &&cd '$runpath' && $run{run}"
                    }
                },
                scheduler => +{
                    envhard => 'arch=x86_64,os=Linux',
                    envsoft => 'app1=1.0',
                    count => $run{count},
                    resources => \@resources
                }
            }]
        }
    );

    my $res = $this->_rcall( %argv );
    my $jobid = eval{ YAML::XS::Load $res };
    die "call fail: $res $@" if $@;
    die "call fail: $res\n" unless $jobid =~ /^J\.\d{8}\.\d{6}.\d{6}\.\d{3}$/;
    return $jobid;
}

sub list
{
    my ( $this, %run ) = splice @_;
    my $res = $this->_rcall( ctrl => 'listjob' );
    my $job = eval{ YAML::XS::Load $res };
    die "call fail: $res $@" if $@;
    return $job;
}

sub info
{
    my ( $this, %run ) = splice @_;

    die "jobid undef" unless $run{jobid};

    my $res = $this->_rcall(
        ctrl => 'info',
        conf => +{
            jobid => $run{jobid}
        }
    );
    my $job = eval{ YAML::XS::Load $res };
    die "call fail: $res $@" if $@;
    return $job;
}

sub stop
{
    my ( $this, %run ) = splice @_;
    die "jobid undef" unless $run{jobid};

    my $res = $this->_rcall(
        ctrl => 'stop',
        conf => +{
            jobid => $run{jobid}
        }
    );

    my $job = eval{ YAML::XS::Load $res };
    die "call fail: $res $@" if $@;
    return $job;
}

sub tail
{
    my ( $this, %run ) = splice @_;
    $this->_taskcall( %run, name => 'tail' );
}

sub top
{
    my ( $this, %run ) = splice @_;
    $this->_taskcall( %run, name => 'top' );
}

sub shell
{
    my ( $this, %run ) = splice @_;
    $this->_taskcall( %run, name => 'shell' );
}

sub _taskcall
{
    my ( $this, %run ) = splice @_;

    die "jobid undef" unless my $taskid = $run{jobid};
    $taskid .= '.001' if $taskid =~ s/^J/T/;
        
    my $res = $this->_rcall(
        ctrl => 'taskinfo',
        conf => +{
            taskid => $taskid
        }
    );

    my $task = eval{ YAML::XS::Load $res };
    die "call fail: $res $@" if $@;
    die "task no Hash" unless $task && ref $task eq 'HASH';
    my $host = $task->{hostip};
    die "get task hostip fail: $res" unless $host && $host =~ /^\d+\.\d+\.\d+\.\d+$/;

    if ( $run{name} eq 'tail' )
    {
        exec "$this->{mt}/shellv2 -h '$host' --sudo root --cmd 'tail -F /opt/AntDen/logs/task/$taskid.log'";
    }
    elsif ( $run{name} eq 'top' )
    {
        exec "$this->{mt}/shellv2 -h '$host' --sudo root --cmd top";
    }
    else
    {
        exec "$this->{mt}/shellv2 -h '$host' --sudo root";
    }
}

1;
