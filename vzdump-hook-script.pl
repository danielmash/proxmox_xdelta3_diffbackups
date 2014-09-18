#!/usr/bin/perl -w

# hook script for vzdump (--script option)

use strict;
use Time::Period;

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

        print "Postprocessing Job 1: doing differential backup in background. Use jobs and ps to monitor.\n";

        # Default archive type.
        my $extension = 'tar';

        # Perform full backup in period of time between Thusday night and Friday morning until next backup cycle (required perl module)
        my $full_backup = inPeriod( time(), "wd{Thu} hr {6pm-0}, wd{Fri} hr {0-6pm}");

        # Maximum number of groups (weeks) to keep
        my $max = 5;

        if ($vmtype eq 'qemu') { $extension = 'vma'; }
        system ("

          if [ $full_backup -ne 0 ]; then

            touch $dumpdir/0-$vmtype-$vmid-dummy.group && rename 's/group(\\d+)/sprintf \"group%d\", \$1+1/e' $dumpdir/*-$vmtype-$vmid-*.group* && mv $tarfile $dumpdir/`basename $tarfile | sed \"s/$extension/group0.full.$extension/\"` && find $dumpdir -name '*-$vmtype-$vmid-*.group$max.*' -delete;

          else

            if ls $dumpdir/*-$vmtype-$vmid-*.group0.full.$extension.*; then {

                screen -X -S `screen -ls | grep $vmid.Xdelta3 | cut -d. -f1 | awk '{print \$1}'` quit && echo WARNING for $vmid - previous process has not finished, xdelta might be inconsistant;
                screen -S $vmid.Xdelta3 -d -m xdelta3 -q -e -s `ls -1t $dumpdir/*-$vmtype-$vmid-*.group0.full.$extension.gz | head -1` $tarfile $dumpdir/`basename $tarfile | cut -d'.' -f1`.group0.xdelta.$extension.gz
                }
            else

              mv $tarfile $dumpdir/`basename $tarfile | sed \"s/$extension/group0.full.$extension/\"`;

            fi;

          fi

                ") == 0 ||
                die "Differential backup failed. You can try to run bash script manually";

    }
    if ($phase eq 'log-end') {


        print "Postprocessing Job 2: Rename resulted logs to match differential backups.\n";
        system ("

              cp $logfile $dumpdir/`basename $logfile | sed \"s/log/group0.full.log/\"`;

                ") == 0 ||
                die "Copy log file is unsuccessful";

    }

} else {

    die "got unknown phase '$phase'";

}

exit (0);
