package Test::Chimps::Smoker::Source;

use strict;
use warnings;
use base qw/Class::Accessor/;
use Scalar::Util qw(weaken);

__PACKAGE__->mk_ro_accessors(qw/config smoker/);
__PACKAGE__->mk_accessors(qw/directory cloned/);

sub new {
    my $proto = shift;
    my %args = @_;
    my $type = delete $args{'type'} or die "No type of a source repository";

    my $class = ref($proto) || $proto;
    $class =~ s/[^:]*$/$type/;

    eval "require $class; 1" or die "Couldn't load $class: $@";

    my $obj = bless { %args }, $class;
    weaken $obj->{'smoker'};
    return $obj->_init;
}

sub _init { return $_[0] }

sub clone { return 1 }
sub checkout { return 1 }
sub clean { return 1 }

sub next { return () }

1;
