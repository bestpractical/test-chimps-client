use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Test::Smoke::Report',
    AUTHOR              => 'Zev Benjamin <zev@cpan.org>',
    VERSION_FROM        => 'lib/Test/Smoke/Report.pm',
    ABSTRACT_FROM       => 'lib/Test/Smoke/Report.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Test-Smoke-Report-*' },
);
