package Test::Chimps::ReportCollection;

use warnings;
use strict;

use base qw/Jifty::DBI::Collection/;

sub record_class {
  return 'Test::Chimps::Report';
}

1;
