#!/usr/bin/perl

# Tool to manipulate widgets!
#

use File::Basename;
use Data::Dumper;
my $basedir = dirname(dirname(__FILE__));
my $libdir = "/home/tomas/projects/TimeManager/lib";

push @INC, $libdir, $basedir, "$basedir/MalyCGI";

require MalyTemplate;
our $DBOCONF = require "$basedir/etc/db.conf";

my $globals = 
{

};

local $/;
my $content = <>;

my $render = MalyTemplate->new($globals);

my %vars = 
(
  DBOCONF=>$DBOCONF,

);

# Create callbacks

$render->set_callback("widget-.*", \&widget);


# Parse!
my $output = $render->parse_template($content, \%vars);

print $output;

sub widget
{
  my ($self, $tag, $attrs, $children, $vars) = @_;
  # Get defaults, also from conf file! XXX TODO

  my $file = $tag;
  $file =~ s/^widget-//g;

  my %vars = ref $vars eq 'HASH' ? %$vars : ();
  my @children = ref $children eq 'ARRAY' ? @$children : ();

  my %attrs = $self->evaluate_attrs($attrs, $vars);
  %attrs = map { (uc($_), $attrs{$_}) } keys %attrs;

  my @hash_names = ();

  #print STDERR "TAG=$tag, ATTRS=".Dumper(\%attrs)."\n";

  # Get attrs to convert to array of hashes.
  my @value_keys = grep { /^hash_.+_values$/i } keys %attrs;
  foreach my $value_key (@value_keys)
  {
    my ($name) = $value_key =~ /^hash_(.+)_values$/i;
    my $values = $attrs{"HASH_${name}_VALUES"};
    my $keys = $attrs{"HASH_${name}_KEYS"};

    my @keys = split(",", $keys);
    my @values = split(",", $values);
    my @array = ();
    for (my $i = 0; $i < @values; $i++)
    {
      my @parts = split(";", $values[$i]);
      my %hash = map { ($keys[$_], $parts[$_]) } (0..$#parts);
      push @array, \%hash;
    }
    $attrs{$name} = \@array;
    push @hash_names, $name;
  }

  #print STDERR "VARS=".Dumper(\%vars)."\n";

  if ($attrs{"TABLE"})
  {
    $vars{TABLE_META} = $DBOCONF->{uc $attrs{"TABLE"}};
    if ($vars{TABLE_META}->{PARENT})
    {
      $vars{PARENT_META} = $DBOCONF->{uc $vars{TABLE_META}->{PARENT} };
    }
  }

  #
  
  my $subengine = MalyTemplate->new($globals);
  $subengine->set_callback("widget-.*", \&widget);
  my @templates = ("$basedir/lib/widget/$file.html", "$basedir/MalyCGI/widget/$file.html");
  # WANT TWO DIRS!
  my $new_content = $subengine->render(\@templates, %vars, %attrs, _KEEPIGNORE=>1);

  map { delete $attrs{$_} } @hash_names;
  my $start_tag = $self->get_start_tag($tag, \%attrs, {_KEEPIGNORE=>1});
  my $end_tag = $self->get_end_tag($tag, \%attrs, {_KEEPIGNORE=>1});
  my $old_content = join("", map { $self->evaluate_node($_, $vars) } @children);

  # Now, print self, as well as new content, and old content, IF
  # we got the keepold attr

  return join("",
    (
      $start_tag, "\n",
        $new_content, "\n",
	($attrs{KEEPOLD} ? 
	  ("\n<!-- OLD WIDGET INSTANCE -->\n", $old_content, "\n<!-- END OLD WIDGET INSTANCE -->\n")
	  : ()
	),
      $end_tag
    )
  );
}

__END__

This displays an entire web page (i.e., for an edit popup)

<widget-edit [page="popup_main"] [w_name="Product Application"] w_table="PRODUCT_APPLICATIONS" cols="description=textarea,name=text,col1=type,col2=mutliList,..." />

to create just the list table (i.e. for browse in the parent page), including the add link!:

<widget-list table="PRODUCT_APPLICATIONS" [name="Product Applications"] [link="colX,colN"] cols="col1,col2,colN" />


to create just a single row for form input into a specific column:
<widget-inputrow name=colN type=TYPE [colspan=1] ... />

to create just a single form field for a specific column, call the above code, with a tag name of widget-input instead of widget-inputrow:

---------------------------------------------------------
it WOULD make sense to create sensible defaults, i.e., storable within a .conf file. THUS, we prolly should run the widget creator FROM the MalyCGI/ within the project , i.e., so it can read ../etc/widget.conf
