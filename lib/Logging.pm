####################
package Logging;
# Logs changes to items.

use lib "../../MalyCGI";
use Notes;
use Data::Dumper;

our $CONF = do "../etc/TMCGI.conf";
our $GLOBAL = {};

sub init
{
  my ($global) = @_;
  $GLOBAL = $global;
}

sub log_changes
{
  my ($self) = @_;
  my $class = ref $self;
  my %changes = $self->hash;
  my $keyname = $self->key_name;
  my $keyvalue = $self->get($keyname);

  my $fields = $CONF->{LOG_FIELDS}->{$class};
  return undef unless ref $fields eq 'HASH' and %{$fields};
  my %fields = %$fields;

  print STDERR "FIELDS=".Dumper(\%fields)."\n";

  my @notes = ();

  foreach my $field (keys %fields)
  {
    my @field_info = ref $fields{$field} eq 'ARRAY' ? @{ $fields{$field} } : ();
    next unless @field_info;
    my ($key, $valuekey) = @field_info;
    $valuekey ||= $key;
    next unless $self->has_changed($key);
    my $value = $self->get($valuekey) || "Unknown";
    push @notes, "$field set to $value";
  }
  add_note($keyname, $keyvalue, @notes);
}


sub add_note
{
  my ($key, $value, @notes) = @_;
  return unless @notes;
  my $concat_notes = join("\n", @notes);
  if ($concat_notes ne '')
  {
    my $note = Notes->new();
    my $uid = $GLOBAL ? $GLOBAL->{SESSION}->get("UID") : undef;
    my ($sec,$min,$hour,$day,$mon,$year) = localtime();
    my $timestamp = sprintf "%04u-%02u-%02u %02u:%02u:%02u", 
	$year+1900, $mon+1, $day, $hour, $min, $sec;
    $note->commit($key=>$value,UID=>$uid,TEXT=>$concat_notes,TIMESTAMP=>$timestamp);
  }
}

1;

