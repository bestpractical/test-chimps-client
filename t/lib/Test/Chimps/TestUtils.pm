package Test::Chimps::TestUtils;

use strict;
use warnings;
use base qw(Exporter);
our @EXPORT_OK = qw(write_file run_cmd);

use File::Path qw(make_path);

sub write_file {
    my ($dir, $name, $content) = @_;

    make_path($dir);

    my $fn = File::Spec->catfile( $dir, $name );
    open my $fh, '>', $fn
        or die "Couldn't open $fn: $!";
    print $fh $content;
    close $fh;
}

sub run_cmd {
    my @args = @_;
    system(@args) == 0
        or die "Couldn't run `". join(' ', @args ) ."`: $!";
    return 1;
}

1;
