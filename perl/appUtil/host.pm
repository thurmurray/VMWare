sub get_hosts {
   my ($entity, $datacenter, $folder, %filter_hash) = @_;
   my $begin;
   my $entityViews;
   my %filter = %filter_hash;

   if (defined $datacenter) {
      $begin =
         Vim::find_entity_views (view_type => 'Datacenter',
                                filter => {name => $datacenter});
                                
      unless (@$begin) {
         Util::trace(0, "Datacenter $datacenter not found.\n");
         return;
      }

	   if ($#{$begin} != 0) {
         Util::trace(0, "Datacenter <$datacenter> not unique.\n");
         return;
      }

   }
   else {
      @$begin = Vim::get_service_content()->rootFolder;
   }
   if (defined $folder) {
      my $vms = Vim::find_entity_views (view_type => 'Folder',
                                        begin_entity => @$begin,
                                        filter => {name => $folder});
      unless (@$vms) {
         Util::trace(0, "Folder <$folder> not found.\n");
         return;
      }
      if ($#{$vms} != 0) {
         Util::trace(0, "Folder <$folder> not unique.\n");
         return;
      }
      @$begin = shift (@$vms);
   }
      $entityViews = Vim::find_entity_views (view_type => $entity,
                                             begin_entity => @$begin,
                                             filter => \%filter);
      unless (@$entityViews) {
          Util::trace(0, "No host found.\n");
          return;
       }

    if ($entityViews) {return \@$entityViews;}
   else {return 0;}
}
sub get_datastore {
   my %args = @_;
   my $host_view = $args{host_view};
   my $config_datastore = $args{datastore};
   my $disksize = $args{disksize};
   my $name = undef;
   my $mor = undef;

   my $ds_mor_array = $host_view->datastore;
   my $datastores = Vim::get_views(mo_ref_array => $ds_mor_array);
   my $found_datastore = 0;

   if($config_datastore) {
      foreach (@$datastores) {
         $name = $_->summary->name;
         if($name eq $config_datastore) {
             my $ds_disksize = ($_->summary->freeSpace)/1024;
             
             if($ds_disksize < $disksize && $_->summary->accessible) {
                return (mor => 0, name => 'disksize_error');
             }
            $found_datastore = 1;
            $mor = $_->{mo_ref};
            last;
         }
      }
   }
   else {
      foreach (@$datastores) {
         my $ds_disksize = ($_->summary->freeSpace)/1024;
         if($ds_disksize > $disksize && $_->summary->accessible) {
            $found_datastore = 1;
            $name = $_->summary->name;
            $mor = $_->{mo_ref};
         } else {
            return (mor => 0, name => 'disksize_error');
         }
      }
   }
   
   if (!$found_datastore) {
      my $host_name = $host_view->name;
      my $ds_name;
      if ($args{datastore}) {
         $ds_name = $args{datastore};
      }
      return (mor => 0, name => 'datastore_error');
   }
   return (name => $name, mor => $mor);
}
sub check_pool {
   my %args = @_;
   my $pool_name = $args{poolname};
   my $targethost = $args{targethost};

   my $mor;
   my $found_host = 0;
   my $target_pool = Vim::find_entity_views(view_type => 'ResourcePool',
                                            filter => {name => $pool_name});

   my $pool_owner;
   unless (@$target_pool) {
      Util::trace(0, "Resource pool <$pool_name> not found.\n");
      return (foundhost => $found_host, mor => $mor);
   }
   if ($#{$target_pool} != 0) {
      Util::trace(0, "Resource pool <$pool_name> not unique.\n");
      return (foundhost => $found_host, mor => $mor);
   }

   foreach (@$target_pool) {
       $pool_owner = $_->owner;
       $mor = $_;
   }
   $pool_owner = Vim::get_view(mo_ref => $pool_owner);
   if(defined $pool_owner->host) {
      my $host_mor_array = $pool_owner->host;
      my $host_array = Vim::get_views(mo_ref_array => $host_mor_array);

      foreach (@$host_array) {
         if ($_->name eq $targethost) {
            $found_host = 1;
         }
      }
   }
   if($found_host == 0) {
      Util::trace(0, "Specified Resource pool not belongs to Target Host");
   }
   return (foundhost => $found_host, mor => $mor);
}

sub get_migrate_option {
   my %args = @_;
   my $datastore_name = $args{datastore_name};
   my $found = 0;

   my $target_host_view = $args{target_host_view};
   if(defined $target_host_view->datastore) {
      my $target_datastore_mor = $target_host_view->datastore;
      my $target_datastores = Vim::get_views(mo_ref_array => $target_datastore_mor);


      foreach (@$target_datastores) {
         my $name = $_->summary->name;
         if($name eq $datastore_name) {
            $found = 1;
         }
      }
   }

   if($found == 1) {
      $found = 0;
      my $source_host_view = $args{source_host_view};
      if(defined $source_host_view->datastore) {
         my $source_datastore_mor = $source_host_view->datastore;
         my $source_datastores = Vim::get_views(mo_ref_array => $source_datastore_mor);
         foreach (@$source_datastores) {
            my $name = $_->summary->name;
            if($name eq $datastore_name) {
               $found = 1;
            }
         }
         if($found == 1) {
            return "migrate";
         }
         else {
            return "relocate";
         }
      }
      else {
         return "relocate";
      }
   }
   else {
      return "notfound";
   }
}

1;
