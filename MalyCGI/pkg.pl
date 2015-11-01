#!/usr/bin/perl

my @projects = 
qw(
pkgs
MalyCGI
TimeManager
DirectoryManager
small/help
malysoft.com
);

my ($s, $m, $h, $d, $mon, $y) = localtime();

my $filename = sprintf "p-%04u_%02u_%02u-%02u_%02u_%02u.bz2", $y+1900, $mon+1, $d, $h, $m, $s;

my $dest = $ARGV[0];

my $tar = "tar jcvf $filename @projects";
print STDERR "$tar\n";
system($tar);

if ($dest)
{
  my $cp = "cp $filename $dest";
  print STDERR "$cp\n";
  system($cp);
}
