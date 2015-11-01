#!/usr/bin/perl

my $cgi = ProductCGI->new(PATH_INFO_KEYS=>["target", "mode"], DBO=>1);

package ProductCGI;
use lib "../lib";
use base "TMCGI";
use MalyTemplate;
use Data::Dumper;
use User;
use UserManagers;
use Group;
use TaskCategoriesRemoved;
use Calendar;
use Task;
use GroupMembership;
use TaskCategories;
use Product;
use FeatureRequest;
use Competitor;
use Components;
use Goals;
use ComponentFeatures;
use ComponentFeatureItems;
use ProductAudience;
use ProductSysReqLink;
use ProductSysReqModules;
use DBOFactory;

sub process
{
  my ($self, $action) = @_;
  my ($target, $mode) = $self->get_path_info("target", "mode");

  my $session_uid = $self->session_get("UID");
  my $siteadmin = $self->session_get("SITEADMIN");

  my $product = Product->new();
  my $version = ProductVersion->new();
  my $prod_id = $self->get("PROD_ID");
  my %form = $self->get_hash;
  my %smart_hash = $self->get_smart_hash;
  if ($prod_id ne '')
  {
    $product->search(PROD_ID=>$prod_id);
  }
  ($form{PROD_ID}, $form{VER_ID}) = split(":", $form{PROD_VER_ID}) if $form{PROD_VER_ID} ne '';

  if (not $target)
  {
    $self->template_display("Products/product_list", PRODUCTS=>Product->search());
  }
  elsif ($target eq 'product')
  {

    if ($mode eq 'Add' or $mode eq 'Edit')
    {
  
      if ($action eq 'Update' or $action eq 'Add')
      {
        $product->commit(%form);
        $prod_id = $product->get("PROD_ID");
  
        my $versions = $product->get("VERSIONS");
  
        my @versions = $self->get("VERSIONS");
        my @ver_id = ();
        my @ver_name = ();
        my @ver_alias = ();
        foreach my $version (@versions)
        {
          my ($ver_id, $ver_name, $ver_alias) = split(":", $version);
  	push @ver_id, $ver_id;
  	push @ver_name, $ver_name;
  	push @ver_alias, $ver_alias;
        }
  
        $versions->commit_list([PROD_ID=>$prod_id], undef, undef, VER_ID=>\@ver_id, VER_NAME=>\@ver_name, VER_ALIAS=>\@ver_alias);
  
      }
      $self->template_display("Products/edit", PRODUCT=>$product);
    } elsif ($mode eq 'View') {
      $self->template_display("Products/view", PRODUCT=>$product);
    }
  } elsif ($target eq 'version') {
    # If no ver_id, prolly adding.
    my $version = ProductVersion->new();
    my $ver_id = $self->get("VER_ID");

    if ($mode eq 'Add' or $mode eq 'Edit')
    {
      if ($ver_id ne '')
      {
        $version->search(VER_ID=>$ver_id);
	$prod_id = $version->get("PROD_ID");
	$product->search(PROD_ID=>$prod_id);
      }

      if ($action eq 'Update')
      {
        $version->commit(%form);
	$ver_id = $version->get("VER_ID");

	$version->get("GOALS")->multi_commit_sorted_list("GOAL_NUM", %smart_hash);
	$version->get("PRODUCT_APPLICATIONS")->multi_commit_sorted_list("APP_NUM", %smart_hash);
	$version->get("COMPONENTS")->multi_commit_sorted_list("COMPONENT_NUM", %smart_hash);

	my @audience = $self->get("AUDIENCE");
	if (@audience)
	{
	  my @audience_id = ();
	  my @description = ();
	  my @order_id = ();

	  for (my $i = 0; $i < @audience; $i++)
	  {
	    ($audience_id[$i], $description[$i]) = split(":", $audience[$i]);
	    $order_id[$i] = $i;
	  }

	  my $audience = $version->get("AUDIENCE") || ProductAudience->new();
	  $audience->commit_list([PROD_ID=>$prod_id, VER_ID=>$ver_id], undef, undef, 
	    AUDIENCE_ID=>\@audience_id, ORDER_ID=>\@order_id,
	    DESCRIPTION=>\@description);
	  $version->set("AUDIENCE", $audience);
	} else {
	  ProductAudience->search(VER_ID=>$ver_id)->delete_all;
	}


	# 

	my @sysreq = $self->get("SYSREQ");
	if (@sysreq)
	{
	  my @sysreq_id = ();
	  my @sysreq_link_id = ();
	  my @order_id = ();
	  for (my $i = 0; $i < @sysreq; $i++)
	  {
	    my $sysreq = $sysreq[$i];
	    my ($sysreq_idn, $sysreq_link_id) = split(":", $sysreq);
	    push @sysreq_id, $sysreq_idn;
	    push @sysreq_link_id, $sysreq_link_id;
	    push @order_id, $i;
	  }
	  my $sysreq_id = $version->get("SYSREQ_ID") || ProductSysReqLink->new();
	  $sysreq_id->commit_list([PROD_ID=>$prod_id, VER_ID=>$ver_id], undef, undef,
	    SYSREQ_ID=>\@sysreq_id, SYSREQ_LINK_ID=>\@sysreq_link_id, ORDER_ID=>\@order_id);
	  $version->set("SYSREQ_ID", $sysreq_id);
	} else {
	  ProductSysReqLink->search(VER_ID=>$ver_id)->delete_all;
	}

	my @modules = $self->get("SYSREQ_MODULES");
	if (@modules)
	{
	  my @module_id = ();
	  my @description = ();

	  foreach my $module (@modules)
	  {
	    my ($id, $desc) = split(":", $module);
	    push @module_id, $id;
	    push @description, $desc;
	  }

	  my $mdbo = $version->get("SYSREQ_MODULES") || ProductSysReqModules->new();
	  $mdbo->commit_list([PROD_ID=>$prod_id, VER_ID=>$ver_id], undef, undef,
	    MODULE_ID=>\@module_id, DESCRIPTION=>\@description);


	  $version->set("SYSREQ_MODULES", $mdbo);
	} else {
	  ProductSysReqModules->search(VER_ID=>$ver_id)->delete_all;
	}

	$self->redirect("cgi-bin/Products.pl/version/Edit?ver_id=$ver_id") if $version->is_new;
      }

      $self->template_display("Products/version", VERSION=>$version, PRODUCT=>$product, ALL_SYSREQ=>
        ProductSysReq->search);
    }

  } elsif ($target eq 'frequest') {
    if ($mode eq 'Add' or $mode eq 'Edit')
    {
      my $freq = FeatureRequest->new();
      my $req_id = $self->get("REQ_ID");

      $freq->search(REQ_ID=>$req_id) if $req_id ne '';

      if ($action eq 'Update')
      {

        $freq->commit(%form);
	$req_id = $freq->get("REQ_ID");

	if ($freq->is_new)
	{
	  $self->redirect("cgi-bin/Products.pl/frequest/Edit?req_id=$req_id");
	}
      }

      $self->template_display("Products/feature_request", FREQ=>$freq, 
        PRODUCTS=>Product->search()
	
	);
    }

  } elsif ($target eq 'competitor') {

    if ($mode eq 'Edit' or $mode eq 'Add')
    {
      my $comp_id = $self->get("COMP_ID");
      my $competitor = Competitor->new();
      $competitor->search(COMP_ID=>$comp_id) if $comp_id ne '';
      if ($action eq 'Update')
      {
        # Calculate score!
	$form{SCORE} = 0;
	map { $form{SCORE} += ($form{$_}||0) } qw(
          LOOKNFEEL USABILITY INTEGRATION DOCUMENTATION 
	  CUSTOMERSERVICE COMPATIBILITY ROADMAP FEATURES 
	  ARCHITECTURE TARGETMARKET PRICING
          );

        # EVENTUALLY, FOR SCORE, TAKE INTO ACCOUNT FEATURES THEY HAVE, AS TO HOW ADVANCED THEY EACH ARE...
	# XXX TODO

	#
	$competitor->commit(%form);
	$comp_id = $competitor->get("COMP_ID");

	if ($competitor->is_new)
	{
	  $self->redirect("cgi-bin/Products.pl/competitor/Edit?comp_id=$comp_id");
	}
      }

      $self->template_display("Products/competitor", COMP=>$competitor, PRODUCTS=>Product->search);
    }

  } elsif ($target eq 'component') {
    # May want separate page for re-ordering, placed here somewhere...

    if ($mode eq 'Edit' or $mode eq 'Add')
    {
      my $component_id = $self->get("COMPONENT_ID");
      my $component = Components->new();
      my $ver_id = undef;
      my $prod_id = undef;
      if ($component_id ne '')
      {
        $component->search(COMPONENT_ID=>$component_id);
	$ver_id = $component->get("VER_ID");
	$prod_id = $component->get("PROD_ID");
      }

      if ($mode eq 'Add')
      {
        ($prod_id, $ver_id) = split(":", $form{PROD_VER_ID});
      }

      $version->search(VER_ID=>$ver_id) if $ver_id ne '';
      $product->search(PROD_ID=>$prod_id) if $prod_id ne '';

      if ($action eq 'Update')
      {
        $component->commit(%form);
	$component_id = $component->get("COMPONENT_ID");

	# Save feature ordering.
	my $features = $component->get("FEATURES");
	$features->multi_commit_sorted_list("FEATURE_NUM", %smart_hash);

	# Now save overview_images
	my @overview_images = $self->get("OVERVIEW_IMAGES");
	if (@overview_images)
	{
	  my $images = $component->get("OVERVIEW_IMAGES") ||
	    DBOFactory->new("OVERVIEW_IMAGES");

	  my @image_id = ();
	  my @src = ();
	  my @order_id = ();

	  for (my $i = 0; $i < @overview_images; $i++)
	  {
	    my ($image_id, $src) = split(":", $overview_images[$i]);
	    push @order_id, $i;
	    push @src, $src;
	    push @image_id, $image_id;
	  }

	  $images->commit_list([OVERVIEW_COMPONENT_ID=>$component_id], undef, undef,
	    SRC=>\@src, IMAGE_ID=>\@image_id, ORDER_ID=>\@order_id);

	  $component->set("OVERVIEW_IMAGES", $images);
	} else {
	  DBOFactory->new("REFERENCE_IMAGES")->search(["OVERVIEW_COMPONENT_ID IS NOT NULL"])->delete_all;
	}

	# Now save access_images
	my @access_images = $self->get("ACCESS_IMAGES");
	if (@access_images)
	{
	  my $images = $component->get("ACCESS_IMAGES") ||
	    DBOFactory->new("ACCESS_IMAGES");

	  my @image_id = ();
	  my @src = ();
	  my @order_id = ();

	  for (my $i = 0; $i < @access_images; $i++)
	  {
	    my ($image_id, $src) = split(":", $access_images[$i]);
	    push @order_id, $i;
	    push @src, $src;
	    push @image_id, $image_id;
	  }


	  $images->commit_list([ACCESS_COMPONENT_ID=>$component_id], undef, undef,
	    SRC=>\@src, IMAGE_ID=>\@image_id, ORDER_ID=>\@order_id);

	  $component->set("ACCESS_IMAGES", $images);
	} else {
	  DBOFactory->new("REFERENCE_IMAGES")->search(["ACCESS_COMPONENT_ID IS NOT NULL"])->delete_all;
	}

	if ($component->is_new)
	{
	  $self->redirect("cgi-bin/Products.pl/component/Edit?component_id=$component_id");
	}
      }
      $self->template_display("Products/component", COMPONENT=>$component, PRODUCTS=>Product->search, PRODUCT=>$product, VERSION=>$version);
    } elsif ($mode eq 'List') {
      my $ver_id = $self->get("VER_ID");
      $self->user_error("Must enter in version ID.") unless $ver_id ne '';
      my $components = Components->search(VER_ID=>$ver_id);

      if ($action eq 'Update')
      {
        $components->multi_commit_sorted_list("COMPONENT_NUM", %smart_hash);
      }

      $self->template_display("Products/component_list", COMPONENTS=>$components);
    }

  } elsif ($target eq 'goal') {
    # May want separate page for re-ordering, placed here somewhere...

    if ($mode eq 'Edit' or $mode eq 'Add')
    {
      my $goal_id = $self->get("GOAL_ID");
      my $goal = Goals->new();

      my $version = ProductVersion->new();

      if ($goal_id ne '')
      {
        $goal->search(GOAL_ID=>$goal_id);
	my $ver_id = $goal->get("VER_ID");
	$version->search(VER_ID=>$ver_id) if $ver_id ne '';
      } else {
        $version->search(VER_ID=>$form{VER_ID}) if $form{VER_ID} ne '';
      }

      if ($action eq 'Update')
      {
	#$form{COMPONENT_ID} = undef if $form{COMPONENT_ID} eq '';
        $goal->commit(%form, MARKETING=>$form{MARKETING});
	# Need to explicitly set MARKETING, as checkbox being unchecked doesn't show up in form.
	$goal_id = $goal->get("GOAL_ID");

	if ($goal->is_new)
	{
	  $self->redirect("cgi-bin/Products.pl/goal/Edit?goal_id=$goal_id");
	}
      } elsif ($action eq 'Delete') {
	$goal->delete();
	$self->msg_page("The record has been removed.", "Javascript:window.close()");
      }

      $self->template_display("Products/goal", GOAL=>$goal, VERSION=>$version);
    } elsif ($mode eq 'Order') {
      my $ver_id = $self->get("VER_ID");
      $self->user_error("Must enter in version ID.") unless $ver_id ne '';
      my $goals = Goals->search(VER_ID=>$ver_id);

      if ($action eq 'Update')
      {

      }

      $self->template_display("Products/goal_list", GOALS=>$goals);
    }

  } elsif ($target eq 'component_feature') {
    if ($mode eq 'Edit' or $mode eq 'Add')
    {
      my $cfeature_id = $self->get("CFEATURE_ID");

      my $cfeature = ComponentFeatures->new();
      $cfeature->search(CFEATURE_ID=>$cfeature_id) if $cfeature_id ne '';

      if ($action eq 'Update')
      {
        $cfeature->commit(%form);
	$cfeature_id = $cfeature->get("CFEATURE_ID");

	$cfeature->get("ITEMS")->multi_commit_sorted_list("ITEM_NUM", %smart_hash);
	$cfeature->get("HOWTO")->multi_commit_sorted_list("HOWTO_NUM", %smart_hash);

	$self->redirect("cgi-bin/Products.pl/component_feature/Edit?cfeature_id=$cfeature_id")
	  if $cfeature->is_new;
      }

      $self->template_display("Products/component_feature", CFEATURE=>$cfeature);
    }
  } elsif ($target eq 'feature_item') {
    if ($mode eq 'Edit' or $mode eq 'Add')
    {
      my $fitem_id = $self->get("FITEM_ID");

      my $fitem = ComponentFeatureItems->new();
      $fitem->search(FITEM_ID=>$fitem_id) if $fitem_id ne '';

      if ($action eq 'Update')
      {
        $fitem->commit(%form);
	$fitem_id = $fitem->get("FITEM_ID");

	$self->redirect("cgi-bin/Products.pl/feature_item/Edit?fitem_id=$fitem_id")
	  if $fitem->is_new;
      }

      $self->template_display("Products/feature_item", FITEM=>$fitem);
    }
  } elsif ($target eq 'documentation') {
    my $ver_id = $self->get("VER_ID");
    my $version = ProductVersion->search(VER_ID=>$ver_id);
    my $product = Product->search(PROD_ID=>$version->get("PROD_ID"));

    if ($action eq 'Update')
    {

    }

    $self->template_display("Products/documentation", VERSION=>$version,
      PRODUCT=>$product);
  } elsif ($target eq 'product_architecture_OLD') {
    my $ver_id = $self->get("VER_ID");
    my $version = ProductVersion->search(VER_ID=>$ver_id);
    my $product = Product->search(PROD_ID=>$version->get("PROD_ID"));


    # !!! SOMEDAY GENERALIZE THIS TO, WHERE WE GOT AN ENTIRE DBO LIST
    # TO EDIT, YET USE POSTFIXES TO SPECIFY KEY, AS INCLUDES MULTILISTS!!!

    if ($mode eq 'Sort')
    {
      my $pa = DBOFactory->new($target);
      $pa->search(VER_ID=>$ver_id) if $ver_id ne '';

      if ($action eq 'Update')
      {
        # Handle changes to image lists!!!!

      }

      $self->template_display("Products/product_architecture_sort",
        VERSION=>$version,
	PRODUCT=>$product,
	PRODUCT_ARCHITECTURE=>$pa,
      );

    }

  } else { # default.

    # Perhaps it would make sense to separate cgi code based upon the type of work it does.
    # I.e., this below would be considered a DBOCGIFactory
    # And if there is any special stuff, we can have hooks below, and override stuff.
    # 
    #

    # It is possible that there could be multiple kinds of CGI Factories.

    my %form = $self->get_hash;
    my $table = $target;
    my $dbo = DBOFactory->new($table);
    my $dbokey = $dbo->key_name;
    my $dboorderkey = $dbo->{TABLE_META}->{SORTBY};
    my %table_columns = map { ($_, 1) } $dbo->table_columns;
    my $dboname = $dbo->{TABLE_META}->{NAME} || $table;
    my @managed_subrecs = ref $dbo->{TABLE_META}->{MANAGED_SUBRECS} ?
      @{ $dbo->{TABLE_META}->{MANAGED_SUBRECS} } : ();
    my $keyvalue = $self->get($dbokey);
    my $retpage = $self->get("_RETPAGE");

    # MAKE SURE TO TAKE CARE OF THIS APPROPRIATELY PER CGI, WHEN THIS DBOCGIFACTORY IS MOVED...
    if ($form{VER_ID} ne '')
    {
     my $version = ProductVersion->search(VER_ID=>$form{VER_ID});
     $form{PROD_ID} = $version->get("PROD_ID");
    } elsif ($form{PROD_VER_ID} ne '') {
      ($form{PROD_ID}, $form{VER_ID}) = split(":", $form{PROD_VER_ID});
    }
    # I.e., we ALWAYS get both from the same form field.

    my $realmode = $mode;
    $realmode = 'Edit' if $realmode eq 'Add';
    $realmode = 'Search' if $realmode eq 'Browse';


    my $parent_table = $dbo->{TABLE_META}->{PARENT};
    my $parent = undef;
    my $parentkey = $DBOFactory::CONF->{$parent_table}->{KEY};
    # REALLY SHOULD BE MODIFIED TO NOT ACCESS VIA DBOF!
    my $parentkeyvalue = undef;

    if ($parentkey)
    {
      $parentkeyvalue = $self->get($parentkey);
      $parent = DBOFactory->new($parent_table);
      $parent->search($parentkey=>$parentkeyvalue) if $parentkeyvalue ne '';
    }

    my $version = ProductVersion->new();

    my %vars = (
      DBOMETA=>$dbo->{TABLE_META},
      $dboname=>$dbo,
      $parent_table=>$parent,
      VERSION=>$version,
      # We should ALSO be able to figure out that we want stuff relating to global lists.
      # THUS, in db.conf, we should be able to say, for a table, what the master list is
      # (i.e., for dual lists, checkboxes, etc...)


    );

    my @parentparams = $parentkey ? ($parentkey=>$parentkeyvalue) : ();

    my $template = "Products/" . lc($table . "_" . $realmode); 

    # FIX ISSUE WITH HAVING EDIT W/O KEY VALUE!!!!!!!!!!!! TODO XXX

    # IF ADDING (BEFORE SUBMIT), REQUIRE PARENT KEY, IF SHOULD!!!!!!

    if ($mode eq 'Add' or $mode eq 'Edit')
    {
      if ($mode eq 'Add' and $parentkey and $parentkeyvalue eq '')
      {
        $self->user_error("No parent reference key provided", "Javascript:window.close()");
      } elsif ($mode eq 'Edit') {
        $self->user_error("No reference key provided", "Javascript:window.close()") if ($keyvalue eq '');
	#$dbo->{DEBUG} =1;
        $dbo->search($dbokey=>$keyvalue);
	$self->user_error("No such entry", "Javascript:window.close()")
	  unless $dbo->count;
      }

      print STDERR "ITER=$dbo->{ITER}, REC=".Dumper($dbo->{RECORDS})."\n";

      if ($action eq 'Update')
      {
        $dbo->recursive_commit(undef, %smart_hash);
	$dbokeyvalue = $dbo->get($dbokey);
        $self->redirect("cgi-bin/Products.pl/$table/Edit?$dbokey=$dbokeyvalue") if $mode eq 'Add';
	#$dbo->is_new;
      } 
      elsif ($action eq 'Delete' and $mode eq 'Edit')
      {
        # Need to MAYBE autoremove subrecords eventually -- but may not want to! but may!

	$dbo->delete();
	$self->msg_page("The record has been removed.", "Javascript:window.close()");
      }
      my $ver_id = $dbo->get("VER_ID") || $form{VER_ID};
      $version->search(VER_ID=>$ver_id) if $ver_id ne '';


      $self->template_display($template, %vars);
    } elsif ($mode eq 'Multiedit') {

      if ($parentkey and $parentkeyvalue eq '')
      {
        $self->user_error("No parent reference key provided", "Javascript:window.close()");
      }

      my @searchparams = $parentkey ? ($parentkey=>$parentkeyvalue) : ();

      $dbo->search(@searchparams);

      if ($action eq 'Update')
      {
        $dbo->recursive_commit_all(%smart_hash);
      }
      my $ver_id = $dbo->get("VER_ID") || $form{VER_ID};
      $version->search(VER_ID=>$ver_id) if $ver_id ne '';

      $self->template_display($template, %vars);
    } elsif ($mode eq 'List') { # JUST SHOW! NO FORM ACTIONS!
      if ($parentkey and $parentkeyvalue eq '')
      {
        $self->user_error("No parent reference key provided", "Javascript:window.close()");
      }
      my @searchparams = $parentkey ? ($parentkey=>$parentkeyvalue) : ();

      $dbo->search(@searchparams);

      my $sortby = $dbo->{TABLE_META}->{SORTBY};
      my $prikey = $dbo->key_name;

      print STDERR "SORTBY=$sortby\n";

      if ($action eq 'Update' and $sortby) # There was a change to list ordering.
      {
        # To avoid removing entries, we really need to just do a sort.
	# The hash NEEDS to be converted!!!
	#
	#
	my $base_struct = {};
	MalyVar->struct_update($base_struct, undef, %smart_hash);
	my $struct = MalyVar->var_evaluate($base_struct, $dbo->{TABLE_NAME});
	my @struct = ref $struct eq 'ARRAY' ? @$struct : ($struct);

	my @sortvals = map { $_->{$sortby} } @struct;
	my @privals = map { $_->{$prikey} } @struct;

	print STDERR "PRIVALS=".Dumper(\@privals)."\n";

	$dbo->multi_commit_sorted_list($sortby, $sortby=>\@sortvals, $prikey=>\@privals);

        #$dbo->recursive_commit_all(%smart_hash);
	# List should do NO modifications other than REORDERING!!!!! NO REMOVALS!
      }

      my $ver_id = $dbo->get("VER_ID") || $form{VER_ID};
      $version->search(VER_ID=>$ver_id) if $ver_id ne '';

      $self->template_display($template, %vars);

    } else {
      $self->user_error("Mode not implemented.");
    }
  }
}

1;
