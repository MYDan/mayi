package MYDan::AntDen::Cli;
use strict;
use warnings;

use Cwd;
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
    die "tar fail: $!" if system "tar -zcf $temp `ls -a|grep -v '^\\.\$'|grep -v '^\\.\\.\$'`";
    print "[INFO]Upload data...\n";
    die "dump fail: $!" if system "$this->{mt}/rcall -r $api dump $temp --path '$repofile' --sudo root >/dev/null";
    die "remove temp file $temp fail:$!" if system "rm -f $temp";

    print "[INFO]Submit job...\n";

    my @resources;
    map{
        if( my @x = $_ =~ /^([A-Z]+):(\d+)$/ )
        {
            if( $x[0] eq 'GPU' )
            {
                map{ push( @resources, [ $x[0], '.', 1 ] ) } 1 .. $x[1];
            }
            else { push( @resources, [ $x[0], '.', $x[1] ] ) }
        }
    } split /,/, $run{resources};

    die "resources err" unless @resources;

    my @datasets; @datasets = map{ "/mnt/$_:/mnt/$_" }split /,/, $run{datasets} if $run{datasets};
    my @volume; @volume = split /,/, $run{volume} if $run{volume};

    my $executer;
    if( $run{image} )
    {
        my $pwd = getcwd;
        $executer = +{
            name => 'docker',
            param => +{
                cmd => "$run{run}",
                image => $run{image},
                volumes => [ "/data/AntDen_repo/$user.$uuid:$pwd", @datasets, @volume ],
                antden_repo => [ $api, "/data/AntDen_repo/$user.$uuid" ],
                workdir => $run{run} =~ /\.\// ? $pwd : undef,
            }
        },
    }
    else
    {
        $executer = +{
            name => 'exec',
            param => +{
                exec => "MYDan_Agent_Load_Code=free.load_antden $this->{mt}/load --host $api  --sp '$repofile' --dp $runpath.tar.gz && mkdir -p $runpath && tar -zxvf $runpath.tar.gz -C '$runpath' &&cd '$runpath' && $run{run}"
            }
        },
    }

    my %argv = (
        ctrl => 'submitjob',
        conf => +{
            config => [+{
                executer => $executer,
                scheduler => +{
                    ip => $run{hostip},
                    envhard => 'arch=x86_64,os=Linux',
                    envsoft => 'app1=1.0',
                    count => $run{count},
                    resources => \@resources
                }
            }],
            map{ $_ => $run{$_} }qw( nice name group )
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

sub resources
{
    my ( $this, %run ) = splice @_;
    my $res = $this->_rcall( ctrl => 'resources' );
    my $r = eval{ YAML::XS::Load $res };
    die "call fail: $res $@" if $@;
    return $r;
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

sub nvidiasmi
{
    my ( $this, %run ) = splice @_;
    $this->_taskcall( %run, name => 'nvidia-smi' );
}

sub listoutput
{
    my ( $this, %run ) = splice @_;
    $this->_taskcall( %run, name => 'listoutput' );
}

sub download
{
    my ( $this, %run ) = splice @_;
    $this->_taskcall( %run, name => 'download' );
}

sub _gethost
{
    my ( $this, $taskid, $type ) = @_;
    my $res = $this->_rcall(
        ctrl => 'taskinfo',
        conf => +{
            taskid => $taskid
        }
    );

    my $task = eval{ YAML::XS::Load $res };
    die "call fail: $res $@" if $@;
    die "task no Hash" unless $task && ref $task eq 'HASH';
    return ( $task, 'scheduling' ) unless my $host = $task->{hostip};
    return ( $task, 'nofind ip' ) unless $host =~ /^\d+\.\d+\.\d+\.\d+$/;
    return ( $task, 'nofind status' ) unless $task->{status};
    my $x = "task status $task->{status}";
    if( grep{ $type eq $_ }qw( tail listoutput download ) )
    {
        return ( grep{ $task->{status} eq $_ } qw( running stoped ) ) ? ( $task, $x, $host ) : ( $task, $x );
    }
    die "task stoped.\n" if $task->{status} eq 'stoped';
    return ( $task->{status} eq 'running' ) ? ( $task, $x, $host ) : ( $task, $x );
}

sub _taskcall
{
    my ( $this, %run, $task, $mesg, $host ) = splice @_;

    die "jobid undef" unless my $taskid = $run{jobid};
    $taskid .= '.001' if $taskid =~ s/^J/T/;
        
    for( 1 .. 60 )
    {
        ( $task, $mesg, $host ) = $this->_gethost( $taskid, $run{name} );
        last if $host;
        print "[INFO]Pending... $_ [$mesg]\n";
        sleep 1;
    }

    die "[INFO] Please try again later\n" unless $host;
    print "[INFO] Go ...\n";

    if ( $run{name} eq 'tail' )
    {
        exec $task->{executer} eq 'docker'
            ? "$this->{mt}/shellv2 -h '$host' --sudo root --cmd 'docker logs -f $taskid'"
            : "$this->{mt}/shellv2 -h '$host' --sudo root --cmd 'tail -F /opt/AntDen/logs/task/$taskid.log'";
    }
    elsif ( $run{name} eq 'top' )
    {
        exec $task->{executer} eq 'docker'
            ? "$this->{mt}/shellv2 -h '$host' --sudo root --cmd 'docker exec -it $taskid top'"
            : "$this->{mt}/shellv2 -h '$host' --sudo root --cmd top";
    }
    elsif ( $run{name} eq 'nvidia-smi' )
    {
        exec $task->{executer} eq 'docker'
            ? "$this->{mt}/shellv2 -h '$host' --sudo root --cmd 'docker exec -it $taskid bash -c \"watch nvidia-smi\"'"
            : "$this->{mt}/shellv2 -h '$host' --sudo root --cmd 'watch nvidia-smi'";
    }
    elsif ( $run{name} eq 'listoutput' )
    {
        exec "$this->{mt}/rcall -r '$host' --sudo root exec 'cd /data/AntDen_output && ls -l $taskid/$run{listoutput}'";
    }
    elsif ( $run{name} eq 'download' )
    {
        exec "$this->{mt}/load -h '$host' --sudo root  --sp '/data/AntDen_output/$taskid/$run{download}' --dp '$run{to}'";
    }
    else
    {
        exec $task->{executer} eq 'docker'
            ? "$this->{mt}/shellv2 -h '$host' --sudo root --cmd 'docker exec -it $taskid bash' --ictrl 0"
            : "$this->{mt}/shellv2 -h '$host' --sudo root";
    }
}

1;
