proxmox_xdelta3_diffbackups
===========================

Differential backups for ProxMox via vzdump-hook-script

Differential backups implemented as make normal full vm backup, then calculate "delta". Every certain day of the week it keeps "full" backup image for each week cycle to be able to restore from deltas. Previous week rotating by incrementing "group0" extension in the filename. Full image for each day of the week migh be restored by applying "delta" to "full" of the same "group".  

~# apt-get install xdelta3  ## install software to enable binary patching

Enable vzdump hook script for custom postprocessing.

(https://pve.proxmox.com/wiki/Vzdump_manual)

~# cp /usr/share/doc/pve-manager/examples/vzdump-hook-script.pl /root/bin/ && chmod +x /root/bin/vzdump-hook-script.pl
~# echo "script: /root/bin/vzdump-hook-script.pl" >> /etc/vzdump.conf

New version of the script saves disk space by just renaming backup files where extensions are:

groupN -- group of full and diffs. [0 -this cycle 1,2,3.... previous cycles]
full --indicates base file for restore.
xdelta -- difference. binary patch file.

Proxmox will not recognise odd file extensions and thus ignore these files when rotating old backups.
Please copy and paste the following after "if ($phase eq 'backup-end') {"

Change $max of you want to keep more or less weeks of incrementals. Please note the whole group (week) will be removed if reached $max.


Manual differential backup and restore.

Make differential:

~$ xdelta3 -e -s    groupN.full    new_vzdump_image    groupN.xdelta

Restore full:

~$ xdelta3 -d -s    groupN.full   groupN.xdelta     decoded_full_vzdump_image


Restore example from differential backup.

First we need restore from differential to full. Please login to console and run xdelta3 -d -s source.vma.gz delta.vma.gz destination.vma.gz to build full image.

Example:

~# cd /mnt/exportpvebackup/dump/
~# xdelta3 -d -s vzdump-qemu-100-2014_07_06-10_25_30.group0.full.vma.gz vzdump-qemu-100-2014_07_06-10_38_39.group0.xdelta.vma.gz vzdump-qemu-100-2014_07_06-10_38_39.group0.restored_from_incremental_`date +%d_%m_%Y-%H_%M_%S`.vma.gz

Then go back to Proxmox WebUI and restore whatever-file-123-restored_from_incremental_06_07_2014-15_15_10.vma.gz
