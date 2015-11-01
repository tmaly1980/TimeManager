package MalyLicense;

use Storable ();
use Data::Dumper;


sub encode
{
  my ($struct) = @_;
  return undef unless ref $struct;
  my $serialized = Storable::freeze($struct);
  my $encoded = unpack("h*", $serialized);
  return $encoded;
}

sub decode
{
  my ($encoded) = @_;
  my $decoded = pack("h*", $encoded);
  return undef unless $decoded;
  my $struct = Storable::thaw($decoded);
  return $struct;
}

1;
