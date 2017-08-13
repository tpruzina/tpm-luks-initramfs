# Print available commands
help()
{
	echo "\
available commands:
	mount_tmp
	umount_tmp
	mount_root
	insmod_nvidia
	
	tcsd_init
	tcsd_exit
	encrypt <input> <outut>
	decrpyt <input> <output>
	shred <file>
	
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
	setsid /bin/busybox sh -c 'exec /bin/busybox sh </dev/tty1 >/dev/tty1 2>&1'
}

# Drop down to rescue shell
rescue_shell()
{
        print "Something went wrong. Dropping to a shell."
	sh
}

# Mount basic kernel filesystems (required to mount root filesystem)
mount_tmp()
{
        print "Mounting temporary filesystems"
        mount -o hidepid=1 -t proc none /proc
        mount -t sysfs none /sys
        mount -t devtmpfs none /dev
	
	# Technically not required but nice to have (populate /dev by scaning /sys)
	mdev -s
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

# Insert Nvidia kernel modules (you probably don't need this)
insmod_nvidia()
{
        print "Inserting Nvidia kernel modules"
        insmod /nvidia.ko || rescue_shell
        insmod /nvidia-modeset.ko || rescue_shell
        insmod /nvidia-drm.ko modeset=1 || rescue_shell
        insmod /nvidia-uvm.ko || rescue_shell
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
	ifconfig lo up
	
	#execute tscd (daemon mode)
	tcsd
}

# Stops tscd and cleans up (TPM)
tcsd_exit()
{
	print "Exiting TSCD"
	killall tcsd
	ifconfig lo down
}

# Encrypt file $1, output in $2
encrypt()
{
        print "encrypting file $1 -> $2"
	/bin/tpm_sealdata --infile $1 --outfile $2
}

# Decrypt file $1, output in $2
decrypt()
{
        print "decrypting file $1 -> $2"
	/bin/tpm_unsealdata --infile $1 --outfile $2
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
        print "Executing OpenRC init"
        exec switch_root /mnt/root /sbin/init
}

# Execute systemd init (gentoo path: /usr/lib/systemd/systemd)
systemd()
{
        print "Executing systemd init"
        exec switch_root /mnt/root /usr/lib/systemd/systemd
}
