#!/usr/bin/perl

my $cgi = CalendarCGI->new(PATH_INFO_KEYS=>[qw/scope date/], NO_SESSION=>1);

package CalendarCGI;
use lib "../lib";
use base "TMCGI";
use Data::Dumper;
use Calendar;

sub process
{
  my ($self, $action) = @_;
  my $cal = Calendar->new($self->{VARS});

  # Way to do things:
  #

  my $scope = $self->get_path_info('scope'); # 
  my $date = $self->get_path_info('date'); # YYYY-MM-DD format

  my @meta = $cal->template_meta($scope, $date);
  $self->internal_error("Invalid URL", "Javascript:window.close()") unless scalar @meta;
  $self->template_display(@meta);
}

1;
