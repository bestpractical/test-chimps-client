package Test::Chimps::Smoker::Source;

use strict;
use warnings;
use base qw/Class::Accessor/;

__PACKAGE__->mk_ro_accessors(qw/config/);

sub new {
    my $proto = shift;
    my %args = @_;
    my $type = delete $args{'type'} or die "No type of a source repository";

    my $class = ref($proto) || $proto;
    $class =~ s/[^:]*$/$type/;

    eval "require $class; 1" or die "Couldn't load $class: $@";

    my $obj = bless { %args }, $class;
    return $obj->_init;
}

sub _init { return $_[0] }

1;
