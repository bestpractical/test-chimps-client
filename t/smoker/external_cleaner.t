use strict;
use warnings;
use lib 't/lib/';

use Test::More tests => 2;

use YAML::Syck;

use Test::Chimps::Smoker;
use Test::Chimps::TestServer;
use Test::Chimps::TestSVN;

use Cwd qw(abs_path);

my $repo = new Test::Chimps::TestSVN; 
ok $repo, "created a svn repository";

$repo->create;

{
    my $test_file = new File::Temp;
    my $clean_cmd_text = <<END;
use strict;
use warnings;

open my \$fh, '>>', '$test_file'
    or die "Couldn't open file $test_file: \$!";

my \@args = splice \@ARGV;

if ( grep \$_ eq '--clean', \@args ) {
    my \@input = <>;
    print \$fh join "\n", \@args;
    print \$fh "\n";
    print \$fh join "", \@input;
} else {
    print \$fh join "\n", \@args;
    print \$fh "\n";
    print "woot\n";
    print \$fh "---\n";
}
END

    my $clean_cmd = new File::Temp;
    print $clean_cmd $clean_cmd_text;
    $clean_cmd->flush;

    my $config = {
        'test-project' => {
            configure_cmd => 'perl Makefile.PL --defaultdeps && make',
            clean_cmd  => 'perl '. $clean_cmd,
            repository => {
                type => 'SVN',
                uri  => $repo->uri,
            },
            revision => 0,
        }
    };

    my $config_file = new File::Temp;
    DumpFile("$config_file", $config);
    my $smoker = Test::Chimps::Smoker->new(
        config_file => "$config_file",
    );
    $smoker->smoke(iterations => 1);

    $test_file->seek(0, 0);
    my $got = do { local $/; <$test_file> };
    my $abs_config_file = abs_path($config_file);
    is $got, <<END, "got correct data in cleaner command";
--project
test-project
--config
$abs_config_file
---
--project
test-project
--config
$abs_config_file
--clean
woot
END

}
