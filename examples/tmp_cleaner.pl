#!/usr/bin/env perl

use warnings;
use strict;
use File::Find;
use constant TMPDIR => "/tmp";

my @args = splice @ARGV;
unless ( grep $_ eq '--clean', @args ) {
    print "$_\n" for file_list();
} else {
    my %skip;
    $skip{$_}++ for split /\n/, do {local $/; scalar <>};
    my @destroy = grep {!$skip{$_} and not m{^/tmp/chimps-}} file_list();
    for (@destroy) {
        if (-d $_) {
            rmdir($_) or die "Can't rmdir $_: $!";
        } else {
            unlink($_) or die "Can't unlink $_: $!";
        }
    }
}

sub file_list {
    my %open;
    # Find all the open files under /tmp
    $open{$_}++ for map {s/^n//;$_} grep {/^n(.*)/}
        split /\n/, `lsof +D @{[TMPDIR]} -F 'n'`;

    for my $file (keys %open) {
        # Add the parent dirs, as well
        $open{$file}++ while $file ne "/" and $file =~ s{/[^/]+$}{};
    }

    my @found;
    finddepth(
        {
            preprocess => sub {
                # Skip directories which had open files in them
                return grep {not $open{$File::Find::dir."/".$_}} @_;
            },
            wanted => sub {
                # Everything else gets listed
                push @found, $File::Find::name;
            }
        },
        TMPDIR
    );
    return @found;
}
