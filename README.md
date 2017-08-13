== TMP/LUKS enabled linux initramfs ==

This repository contains my personal initramfs that loads encrypted filesystem (poormans bitlocker for linux) with TPM/LUKS.
It's meant to be used with gentoo (systemd+openrc) on x86\_64, anything else will require modification of init and import.sh scripts as well as recompilation of provided binaries.
Building static trousers and tpm-tools is pain hence lddtree utility was used to extract shared libraries (glibc-1.26, openssl).
You are strongly encouraged to replace all binaries provided with your own, firstly my binaries might not work on your system, secondly you shouldn't trust me :-)

NOTE: this README doesn't teach you how to use tpm-tools, cryptsetup nor kernel and initramfs. I suggest these articles for details:

https://pagefault.blog/2016/12/23/guide-encryption-with-tpm/
https://wiki.gentoo.org/wiki/Custom\_Initramfs

== Warning, Danger Will Robinson ==
This is more or less a guide how to setup this, not a copy&paste tutorial. You are expected to use google-fu.
Please create issue on bug tracker here if you find things unclear/flatout broken, much appreciated.
If anybody managed to build tpm-tools statically I would very much want to hear about it so I can get rid of this dynamic libraries.

== INSTALL ==
While this initramfs is gonna work out of the box on my system, you will need to do these:

0) setup tpm-tools on your system
1) modify init and import.sh according to your setup (it's commented)
2) create encryption key via tpm and store it in initramfs (see bellow)
3) copy /var/lib/tpm/system.data into initramfs (see bollow)
4) build initramfs and make it load during boot
    use google, there are more ways to do this, 
    easiest one is to compile custom kernel and set CONFIG_INITRAMFS_SOURCE="/usr/src/initramfs".
5) Test
6) Boot

== Encryption key ==

Basically you will want to generate a key, seal it with tpm and place it in initramfs as /key.enc.

openssl rand 32 -hex | tpm\_sealdata > key.enc

During boot, this key will be decrypted via tpm, used to unlock your encrypted partitions and then shreded in memory.

== /var/lib/tpm/system.data ==

You will need to copy this file from your main installation (where you initialized TPM via tpm-tools).

== Binary replacement ==
You will need tpm-tools utilities (tcsd, tpm\_*) , cryptsetup (static) and busybox (static).
Dynamic libraries needed for tpm-tools packages can be extracted with lddtree by following guide here:
https://wiki.gentoo.org/wiki/Custom_Initramfs#lddtree


== Testing ==
=== chroot ===
You can actually chroot into initramfs and "emulate" what would happen on boot like this:

# mount -t proc /proc ./initramfs/proc
# mount --rbind /sys ./initramfs/sys
# mount --make-rslave ./initramfs/sys
# mount --rbind /dev ./initramfs/dev
# mount --make-rslave ./initramfs/dev
# chroot ./initramfs /init

Insert "rescue_shell" call in ./initramfs/init script to do step by step debugging (you won't be able to execute systemd init though).

=== Live ===
Most commands in init have "|| rescue_shell" appended to them, e.g. on failure you will be dropped into busybox shell.
Afterwards you can quite easily debug from there (assuming you know how shell works). 
You will probably want to load import.sh functions, this needs to be done manually via ". import.sh".

Feel free to experiment with initramfs/init script.

== Tree ==
├── initramfs                   // main initramfs
│   ├── bin
│   │   ├── busybox
│   │   ├── tpm\_sealdata
│   │   └── tpm\_unsealdata
│   ├── dev                     // this will be further populated by busyboxs "mdev -s"
│   │   ├── console
│   │   ├── kmsg
│   │   ├── loop0
│   │   ├── loop1
│   │   ├── loop2
│   │   ├── loop3
│   │   ├── loop4
│   │   ├── loop5
│   │   ├── null
│   │   ├── random
│   │   ├── tpm
│   │   ├── tpm0
│   │   ├── tty
│   │   ├── tty0
│   │   └── urandom
│   ├── etc                     // all this crap is required because tcsd expects working tcp sockets
│   │   ├── group
│   │   ├── host.conf
│   │   ├── hosts
│   │   ├── nsswitch.conf
│   │   ├── passwd
│   │   ├── resolv.conf
│   │   └── tcsd.conf
│   ├── import.sh               // helper functions for init
│   ├── init                    // main init script
│   ├── key.enc                 // your tpm encrypted key (generate via 
│   ├── lib64                   // this crap is needed for tcsd and other tpm utilities to run (generated with lddtree)
│   │   ├── ld-linux-x86-64.so.2
│   │   ├── libc.so.6
│   │   ├── libdl.so.2
│   │   ├── libnsl.so.1
│   │   ├── libnss\_compat.so.2
│   │   ├── libnss\_dns.so.2
│   │   ├── libnss\_files.so.2
│   │   ├── libpthread.so.0
│   │   ├── libresolv.so.2
│   │   └── libz.so.1
│   ├── mnt                     // here mounts the root filesystem (unencrypted in my case, but that's just few lines of code to change in init script)
│   │   └── root
│   ├── proc
│   ├── sbin
│   │   ├── cryptsetup          // used for LUKS (static)
│   │   ├── nologin             // tcsd requires tss:tss group (that means we need all this crap)
│   │   ├── tcsd                // tcsd (TPM daemon)
│   │   ├── tpm\_selftest        // tpm-tools libraries
│   │   ├── tpm\_setactive
│   │   ├── tpm\_setenable
│   │   ├── tpm\_takeownership
│   │   └── tpm\_version
│   ├── sys
│   ├── usr
│   │   └── lib64               // more dynamic libraries
│   │       ├── libcrypto.so.1.0.0
│   │       ├── libf2fs.so -> libf2fs.so.1
│   │       ├── libf2fs.so.1 -> libf2fs.so.1.0.0
│   │       ├── libf2fs.so.1.0.0
│   │       ├── libgcc\_s.so.1
│   │       ├── libgmp.so.10
│   │       ├── libnss\_compat.so.2
│   │       ├── libnss\_nis.so.2
│   │       ├── libssl.so.1.0.0
│   │       ├── libtpm\_unseal.so.1 -> libtpm\_unseal.so.1.0.0
│   │       ├── libtpm\_unseal.so.1.0.0
│   │       ├── libtspi.so -> libtspi.so.1
│   │       ├── libtspi.so.1 -> libtspi.so.1.2.0
│   │       └── libtspi.so.1.2.0
│   └── var
│       ├── lib
│       │   └── tpm             // tscd will not work unless you copy this here (see above)
│       │       └── system.data (you will need to copy this file from your system in order for tpm to work properly)
│       └── run
│           └── nscd
└── README.md   // this readme

