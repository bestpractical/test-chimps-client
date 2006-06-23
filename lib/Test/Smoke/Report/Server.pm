package Test::Smoke::Report::Server;

use warnings;
use strict;

use Test::Smoke::Report;

use Algorithm::TokenBucket;
use CGI::Carp   qw<fatalsToBrowser>;
use CGI;
use Digest::MD5 qw<md5_hex>;
use File::Basename;
use File::Spec;
use Fcntl       qw<:DEFAULT :flock>;
use HTML::Mason;
use Params::Validate qw<:all>;
use Storable    qw<store_fd fd_retrieve freeze>;
use YAML::Syck;

use constant PROTO_VERSION => 0.1;

=head1 NAME

Test::Smoke::Report::Server - Accept smoke report uploads and display smoke reports

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

This module simplifies the process of running a smoke server.  It
is meant to be used with Test::Smoke::Report::Client.

    use Test::Smoke::Report::Server;

    my $server = Test::Smoke::Report::Server->new(base_dir => '/var/www/smokes');

    $server->handle_request;

=head1 METHODS

=head2 new ARGS

Creates a new Server object.  ARGS is a hash whose valid keys are:

=over 4

=item * base_dir

Mandatory.  Base directory where report data will be stored.

=item * bucket_file

Name of bucket database file (see L<Algorithm::Bucket>).  Defaults
to 'bucket.dat'.

=item * burst_rate

Burst upload rate allowed (see L<Algorithm::Bucket>).  Defaults to
5.

=item * extra_validation_spec

A hash reference of the form accepted by Params::Validate.  If
supplied, this will be used to validate the extra data submitted to
the server.

=item * list_template

Template filename under base_dir/template_dir to use for listing
smoke reports.  Defaults to 'list.tmpl'.

=item * max_rate

Maximum upload rate allowed (see L<Algorithm::Bucket>).  Defaults
to 1/30.

=item * max_size

Maximum size of HTTP POST that will be accepted.  Defaults to 3
MiB.

=item * max_smokes_per_subcategory

Maximum number of smokes allowed per category.  Defaults to 5.

=item * report_dir

Directory under base_dir where smoke reports will be stored.
Defaults to 'reports'.

=item * template_dir

Directory under base_dir where html templates will be stored.
Defaults to 'templates'.

=back

=cut

{
  no strict 'refs';
  our @fields = qw/base_dir bucket_file max_rate max_size
                   max_smokes_per_subcategory report_dir
                   template_dir list_template extra_validation_spec/;

  foreach my $field (@fields) {
    *{$field} =
      sub {
        my $self = shift;
        return $self->{$field};
      };
  }
} 

sub new {
  my $class = shift;
  my $obj = bless {}, $class;
  $obj->_init(@_);
  return $obj;
}

sub _init {
  my $self = shift;
  my %args = validate_with
    (params => \@_,
     called => 'The Test::Smoke::Report::Server constructor',
     spec => 
     { base_dir =>
       { type => SCALAR,
         optional => 0 },
       bucket_file =>
       { type => SCALAR,
         default => 'bucket.dat',
         optional => 1 },
       burst_rate =>
       { type => SCALAR,
         optional => 1,
         default => 5,
         callbacks =>
         { "greater than or equal to 0" =>
           sub { $_[0] >= 0 }} },
       extra_validation_spec =>
       { type => HASHREF,
         optional => 1 },
       list_template =>
       { type => SCALAR,
         optional => 1,
         default => 'list.tmpl' },
       max_rate =>
       { type => SCALAR,
         default => (1 / 30),
         optional => 1,
         callbacks =>
         {"greater than or equal to 0" =>
          sub { $_[0] >= 0 }} },
       max_size =>
       { type => SCALAR,
         default => 2**20 * 3.0,
         optional => 1,
         callbacks =>
         { "greater than or equal to 0" =>
           sub { $_[0] >= 0 }} },
       max_smokes_per_subcategory =>
       { type => SCALAR,
         default => 5,
         optional => 1,
         callbacks =>
         { "greater than or equal to 0" =>
           sub { $_[0] >= 0 }} },
       pre_add_hook =>
       { type => CODEREF,
         optional => 1 },
       report_dir =>
       { type => SCALAR,
         default => 'reports',
         optional => 1 },
       template_dir =>
       { type => SCALAR,
         default => 'templates',
         optional => 1 }
     });
  
  foreach my $key (%args) {
    $self->{$key} = $args{$key};
  }
}

=head2 handle_request

Handles a single request.  This function will either accept a
series of reports for upload or display report summaries.

=cut

sub handle_request {
  my $self = shift;

  my $cgi = CGI->new;
  if ($cgi->param("upload")) {
    $self->_process_upload($cgi);
  } elsif ($cgi->param("id")) {
    $self->_process_detail($cgi);
  } else {
    $self->_process_listing($cgi);
  }
}

sub _process_upload {
  my $self = shift;
  my $cgi = shift;

  print $cgi->header("text/plain");
  $self->_limit_rate($cgi);
  $self->_validate_params($cgi);  
  $self->_validate_extra($cgi);
  $self->_add_report($cgi);
  $self->_clean_old_reports($cgi);

  print "ok";
}

sub _limit_rate {
  my $self = shift;
  my $cgi = shift;

  my $bucket_file = File::Spec->catfile($self->{base_dir},
                                        $self->{bucket_file});
  
  # Open the DB and lock it exclusively. See perldoc -q lock.
  sysopen my $fh, $bucket_file, O_RDWR|O_CREAT
    or die "Couldn't open \"$bucket_file\": $!\n";
  flock $fh, LOCK_EX
    or die "Couldn't flock \"$bucket_file\": $!\n";

  my $data   = eval { fd_retrieve $fh };
  $data    ||= [$self->{max_rate}, $self->{burst_rate}];
  my $bucket = Algorithm::TokenBucket->new(@$data);

  my $exit;
  unless($bucket->conform(1)) {
    print "Rate limiting -- please wait a bit and try again, thanks.";
    $exit++;
  }
  $bucket->count(1);

  seek     $fh, 0, 0  or die "Couldn't rewind \"$bucket_file\": $!\n";
  truncate $fh, 0     or die "Couldn't truncate \"$bucket_file\": $!\n";

  store_fd [$bucket->state] => $fh or
    croak "Couldn't serialize bucket to \"$bucket_file\": $!\n";

  exit if $exit;
}

sub _validate_params {
  my $self = shift;
  my $cgi = shift;
  
  if(! $cgi->param("version") ||
     $cgi->param("version") != PROTO_VERSION) {
    print "Protocol versions do not match!";
    exit;
  }

  if(! $cgi->param("reports")) {
    print "No reports given!";
    exit;
  }

#  uncompress_smoke();
}

sub _validate_extra {
  my $self = shift;
  my $cgi = shift;
  
  my @reports = map { Load($_) } $cgi->param("reports");
  
  if (defined $self->{validate_extra}) {
    foreach my $report (@reports) {
      eval {
        validate(@{$report->{extra_data}}, $self->{validate_extra});
      };
      if ($@) {
        # XXX: doesn't dump subroutines because we're using YAML::Syck
        print "This server accepts extra parameters.  It's validation ",
          "string looks like this:\n", Dump($self->{validate_extra});
        exit;
      }

    }
  }
}

sub _add_report {
  my $self = shift;
  my $cgi = shift;

  my @reports = $cgi->param("reports");

  foreach my $report (@reports) {
    my $id = md5_hex $report;

    my $report_file = File::Spec->catfile($self->{base_dir},
                                          $self->{report_dir},
                                          $id . ".yml");
    if (-e $report_file) {
      print  "One of the submitted reports was already submitted!";
      exit;
    }

    open my $fh, ">", $report_file or
      croak "Couldn't open \"$report_file\" for writing: $!\n";
    print $fh $report or
      croak "Couldn't write to \"$report_file\": $!\n";
    close $fh or
      croak "Couldn't close \"$report_file\": $!\n";
  }
}

sub _clean_old_reports {
  # XXX: stub
}

sub _process_detail {
  my $self = shift;
  my $cgi = shift;

  print $cgi->header;
  
  my $id = $cgi->param("id");

  unless ($id =~ m/^[a-f0-9]+$/i) {
    print "Invalid id: $id";
    exit;
  }

  my $report = LoadFile(File::Spec->catfile($self->{base_dir},
                                          $self->{report_dir},
                                          $id . ".yml"));

  print $report->report_text;
}

sub _process_listing {
  my $self = shift;
  my $cgi = shift;

  print $cgi->header();

  my @files = glob File::Spec->catfile($self->{base_dir},
                                       $self->{report_dir},
                                       "*.yml");

  my @reports = map { bless LoadFile($_), 'Test::Smoke::Report' }
    @files;

  for (my $i = 0; $i < scalar @reports ; $i++) {
    my ($filename, $directories, $suffix) = fileparse($files[$i], '.yml');
    $reports[$i]->{url} = $cgi->url . "?id=$filename";
    $reports[$i]->{id} = $filename;
  }
  
  my $interp = HTML::Mason::Interp->new(comp_root =>
                                        File::Spec->catfile($self->{base_dir},
                                                            $self->{template_dir}));
  $interp->exec(File::Spec->catfile(File::Spec->rootdir,
                                    $self->{list_template}),
                report_dir => $self->{http_report_dir},
                reports => \@reports);
  
}

=head1 AUTHOR

Zev Benjamin, C<< <zev at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-smoke-report at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Smoke-Report>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::Smoke::Report

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-Smoke-Report>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-Smoke-Report>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-Smoke-Report>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-Smoke-Report>

=back

=head1 ACKNOWLEDGEMENTS

The code in this distribution is based on smokeserv-client.pl and
smokeserv-server.pl from the PUGS distribution.

=head1 COPYRIGHT & LICENSE

Copyright 2006 Zev Benjamin, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
  
1;
