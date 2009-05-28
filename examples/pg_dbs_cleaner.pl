#!/usr/bin/env perl

use warnings;
use strict;
use DBI;

# --config <path to the file>, --project <project name>, [--clean]
my @args = splice @ARGV;

local $ENV{DBI_USER} = "postgres";

unless ( grep $_ eq '--clean', @args ) {
    # can collect state before smoking and print it to stdout
    print join "\n", list_dbs(), '';
} else {
    # read collected info from stdin
    my %skip = map { chomp; $_ => 1 } <>;

    my @dbs = grep !$skip{ $_ }, list_dbs();
    return unless @dbs;

    my $dbh = DBI->connect("dbi:Pg:dbname=template1","postgres","",{RaiseError => 1});
    $dbh->do("DROP DATABASE $_") for @dbs;
}

sub list_dbs {
    local $@;
    return map {s/.*dbname=(.*)/$1/ ? $_ : () } grep defined,
        eval { DBI->data_sources("Pg") };
}

