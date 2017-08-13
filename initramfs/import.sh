# Print available commands
help()
{
	echo "\
available commands:
	mount_tmp
	umount_tmp
	mount_root
	
	tcsd_init
	tcsd_exit
	encrypt <input> <outut>
	decrpyt <input> <output>
	shred <file>
        encrypted_mount <key_file> <mount_point> <luks_name>

	openrc
	systemd
	
	rescue_shell
	test_shell
	
for busybox commands \"busybox\"."
}

# Simple logger function that logs into kmsg (dmesg)
print()
{
	echo "$@"
        echo "initramfs: $@" >> dev/kmsg
}

# Propper shell on tty (ctrl+C, background tasks, ...)
test_shell()
{
	setsid /bin/busybox sh -c '/bin/busybox sh </dev/tty1 >/dev/tty1 2>&1'
}

# Drop down to rescue shell
rescue_shell()
{
        print "Something went wrong. Dropping to a shell - (\'exit\' to continue), \'. import.sh\' to load helper functions."
	sh
}

# Mount basic kernel filesystems (required to mount root filesystem)
mount_tmp()
{
        print "Mounting temporary filesystems"
        mount -o hidepid=1 -t proc none /proc || rescue_shell
        mount -t sysfs none /sys || rescue_shell
        mount -t devtmpfs none /dev || rescue_shell
	
	# Technically not required but nice to have (populate /dev by scaning /sys)
	mdev -s || rescue_shell
}

# Unmount basic kernel filesystems
umount_tmp()
{
        print "Unmounting temporary filesystems"
        umount /proc
        umount /sys
        umount /dev
}

# Mount root filesystem (edit according to your setup)
mount_root()
{
        print "Mounting root filesystem"
        mount -o rw /dev/sda3 /mnt/root || rescue_shell
        mount -o rw /dev/sda1 /mnt/root/boot || rescue_shell
}

# Starts tscd daemon in the background (required for TPM)
tcsd_init()
{
	print "Initializing TSCD"
	#tscd requires bunch of folders to be setup with right user/group ownership
	chown -R tss:tss 	\
		/etc/tcsd.conf	\
		/var/lib/tpm	\
		/var/run/nscd

	# tscd uses TCP sockets on localhost hence we need to bring loopback up
	ifconfig lo up || rescue_shell
	
	#execute tscd (daemon mode)
	tcsd || rescue_shell
}

# Stops tscd and cleans up (TPM)
tcsd_exit()
{
	print "Exiting TSCD"
	killall tcsd
	ifconfig lo down || rescue_shell
}

# Encrypt file $1, output in $2
encrypt()
{
        print "encrypting file $1 -> $2"
	/bin/tpm_sealdata --infile $1 --outfile $2 || rescue_shell 
}

# Decrypt file $1, output in $2
decrypt()
{
        print "decrypting file $1 -> $2"
	/bin/tpm_unsealdata --infile $1 --outfile $2 || rescue_shell
}

# Shred file 
# note: tmpfs writes in place hence we can overwrite memory simply by writing into file
shred()
{
	if [ -f $1 ]; then
		SIZE=$(ls -l $1 | awk '{print $5}')
		dd if=/dev/urandom of=$1 bs=1 count=$SIZE
		sync
		rm $1
	else
		print "failure shredding $1"
                rescue_shell
	fi
}

# Mount encrypted volume via luks
# $1 - keyfile
# $2 - mountpoint
# $3 - luks name
encrypted_mount()
{
    if [ "$#" -eq 3 ]; then
        if [ ! -f $1 ]; then
            print "encrypted mount: missing key file"
            rescue_shell
        fi
        
        # cryptsetup luksOpen --key-file key /dev/sdb1 external
        cryptsetup luksOpen --key-file $1 $2 $3
        # mount /dev/mapper/external /mnt/root/mnt/media
        mount /dev/mapper/$3 $2
    else
        print "encrypted mount: wrong number of parameters"
        rescue_shell
    fi
}

# Debug symbols
enable_debug()
{
	export LD_DEBUG=all
}

disable_debug()
{
	unset LD_DEBUG
	unset LD_DEBUG_FILE
}

# Execute OpenRC init (gentoo)
openrc()
{
        if [ ! -f /mnt/root/sbin/init ]; then
            print "OpenRC init not found, perhaps rootfs isn't mounted?"
            rescue_shell
        else
            print "Executing OpenRC init"
            exec switch_root /mnt/root /sbin/init
        fi
}

# Execute systemd init (gentoo path: /usr/lib/systemd/systemd)
systemd()
{
        if [ ! -f /mnt/root/usr/lib/systemd/systemd ]; then
            print "systemd init not found, perhaps rootfs isn't mounted?"
            rescue_shell
        else
            print "Executing systemd init"
            exec switch_root /mnt/root /usr/lib/systemd/systemd
        fi
}

