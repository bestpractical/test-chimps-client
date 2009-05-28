use strict;
use warnings;
use lib 't/lib/';

use Test::More tests => 14;

use Test::Chimps::Smoker;
use Test::Chimps::TestServer;
use Test::Chimps::TestSVN;

use File::Temp qw(tempdir);
use YAML::Syck;

my $server = new Test::Chimps::TestServer;
my $url = $server->started_ok("start up my web server");

my $repo = new Test::Chimps::TestSVN; 
ok $repo, "created a svn repository";

$repo->create;
$repo->update( 't', 'basic.t', <<END
use Test::More tests => 2;
ok 1, "basic test";
ok 1, "another test";
END
);

{
    $server->flush_reports;
    my $config = {
        'test-project' => {
            configure_cmd => 'perl Makefile.PL --defaultdeps && make',
            repository => {
                type => 'SVN',
                uri  => $repo->uri,
            },
            revision => 0,
            root_dir => '.',
        }
    };

    my $config_file = new File::Temp;
    DumpFile("$config_file", $config);
    my $smoker = Test::Chimps::Smoker->new(
        server      => $url,
        config_file => $config_file,
        sleep       => 0,
    );
    $smoker->smoke(iterations => 1);

    my @reports = $server->reports;
    is scalar @reports, 1, "only iteration";
    is $reports[0]{'meta'}{'extra_properties'}{'revision'}, 1, "smoked first revision";
    ok $reports[0]{'meta'}{'extra_properties'}{'committer'}, "has some committer";
    is $reports[0]{'TAP'}, "1..1\nok 1 - basic test\n", "correct tap";
}

{
    $server->flush_reports;
    my $config = {
        'test-project' => {
            configure_cmd => 'perl Makefile.PL --defaultdeps && make',
            repository => {
                type => 'SVN',
                uri  => $repo->uri,
            },
            revision => 0,
            root_dir => '.',
        }
    };

    my $config_file = new File::Temp;
    DumpFile("$config_file", $config);
    my $smoker = Test::Chimps::Smoker->new(
        server      => $url,
        config_file => $config_file,
        sleep       => 0,
    );
    $smoker->smoke(iterations => 2);

    my @reports = $server->reports;
    is scalar @reports, 2, "two iterations";
    is $reports[0]{'meta'}{'extra_properties'}{'revision'}, 1, "smoked first revision";
    ok $reports[0]{'meta'}{'extra_properties'}{'committer'}, "has some committer";
    is $reports[0]{'TAP'}, "1..1\nok 1 - basic test\n", "correct tap";

    is $reports[1]{'meta'}{'extra_properties'}{'revision'}, 2, "smoked second revision";
    ok $reports[1]{'meta'}{'extra_properties'}{'committer'}, "has some committer";
    is $reports[1]{'TAP'}, "1..2\nok 1 - basic test\nok 2 - another test\n", "correct tap";
}

