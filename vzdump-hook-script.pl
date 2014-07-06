#!/usr/bin/perl -w

# example hook script for vzdump (--script option)

use strict;

print "HOOK: " . join (' ', @ARGV) . "\n";

my $phase = shift;

if ($phase eq 'job-start' || 
    $phase eq 'job-end'  || 
    $phase eq 'job-abort') { 

    my $dumpdir = $ENV{DUMPDIR};

    my $storeid = $ENV{STOREID};

    print "HOOK-ENV: dumpdir=$dumpdir;storeid=$storeid\n";

    # do what you want 

} elsif ($phase eq 'backup-start' || 
	 $phase eq 'backup-end' ||
	 $phase eq 'backup-abort' || 
	 $phase eq 'log-end' || 
	 $phase eq 'pre-stop' ||
	 $phase eq 'pre-restart') {

    my $mode = shift; # stop/suspend/snapshot

    my $vmid = shift;

    my $vmtype = $ENV{VMTYPE}; # openvz/qemu

    my $dumpdir = $ENV{DUMPDIR};

    my $storeid = $ENV{STOREID};

    my $hostname = $ENV{HOSTNAME};

    # tarfile is only available in phase 'backup-end'
    my $tarfile = $ENV{TARFILE};

    # logfile is only available in phase 'log-end'
    my $logfile = $ENV{LOGFILE}; 

    print "HOOK-ENV: vmtype=$vmtype;dumpdir=$dumpdir;storeid=$storeid;hostname=$hostname;tarfile=$tarfile;logfile=$logfile\n";

    # Backup result postprocessing

    if ($phase eq 'backup-end') {
    
	print "Postprocessing Job 1: Copy resulted tarball to removable storage\n";
   	system ("

		if [ -f /mnt/pve/pveremovebackup/.pveremovebackup ]; then
			rm -Rf /mnt/pve/pveremovebackup/dump/vzdump-*-$vmid-*.vma.* && cp $tarfile /mnt/pve/pveremovebackup/dump/
		fi

		") == 0 || 
		die "Copy tar file to removable storage failed. Please make sure .pveremovebackup label file is present.";

	print "Postprocessing Job 2: doing differential backup.\n";
	
	# Default archive type.
	my $extension = 'tar';

    	# 0 and 7 = Sunday; 1 = Monday etc.
    	my $full_backup_day = 1;

        # Maximum number of groups (weeks) to keep
        my $max = 7;

 	if ($vmtype eq 'qemu') { $extension = 'vma'; }
	system ("

          if [ `date +%u` -eq $full_backup_day ]; then
          
	    touch $dumpdir/0-$vmtype-$vmid-dummy.group && rename 's/group(\\d+)/sprintf \"group%d\", \$1+1/e' $dumpdir/*-$vmtype-$vmid-*.group* && mv $tarfile $dumpdir/`basename $tarfile | sed \"s/$extension/group0.full.$extension/\"` && find $dumpdir -name '*-$vmtype-$vmid-*.group$max.*' -delete;
	
  	  else
	    
            if ls $dumpdir/*-$vmtype-$vmid-*.group0.full.*; then 
		
              xdelta3 -e -s `ls -1t $dumpdir/*-$vmtype-$vmid-*.group0.full.* | head -1` $tarfile $dumpdir/`basename $tarfile | cut -d'.' -f1`.group0.xdelta.$extension.gz; 

	    else 

              mv $tarfile $dumpdir/`basename $tarfile | sed \"s/$extension/group0.full.$extension/\"`; 

            fi;
              
          fi

		") == 0 || 
		die "Differential backup failed. You can try to run bash script manually";


    }

    if ($phase eq 'log-end') {

	print "Postprocessing Job 3: Copy resulted logs to removable storage\n";
    	system ("

		if [ -f /mnt/pve/pveremovebackup/.pveremovebackup ]; then 
			rm -Rf /mnt/pve/pveremovebackup/dump/vzdump-*-$vmid-*.log && cp $logfile /mnt/pve/pveremovebackup/dump
		fi

		") == 0 ||
    	    die "Copy log file to removable storage failed. Please make sure .pveremovebackup label file is present on destination.";
    }
    
} else {

    die "got unknown phase '$phase'";

}

exit (0);

