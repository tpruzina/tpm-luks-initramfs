# TPM/LUKS enabled linux initramfs
![Flowchart](https://github.com/tpruzina/tpm-luks-initramfs/raw/master/doc/flow.png)

This repository contains custom initramfs that loads encrypted filesystem (poormans bitlocker for linux) with TPM/LUKS.
Largely a DIY guide rather than drop-in-and-it-works. Have fun.

## Notes
It's meant to be used with gentoo (systemd+openrc) on x86\_64, anything else will require modification of init and import.sh scripts as well as recompilation of provided binaries.
Building static trousers and tpm-tools is pain hence lddtree utility was used to extract shared libraries (glibc-1.26, openssl).
You are strongly encouraged to replace all binaries provided with your own, firstly my binaries might not work on your system, secondly you _shouldn't_ trust me :-)

This README doesn't teach you how to use tpm-tools, cryptsetup nor kernel and initramfs. I suggest these articles for details:

[encryption with tpm - guide](https://pagefault.blog/2016/12/23/guide-encryption-with-tpm/)

[custom initramfs - gentoo wiki](https://wiki.gentoo.org/wiki/Custom\_Initramfs)

[custom initramfs examples](https://wiki.gentoo.org/wiki/Custom_Initramfs/Examples)

## Warning, Danger Will Robinson
This is more or less a guide how to setup this, not a copy&paste tutorial. You are expected to use google-fu.
Please create issue on bug tracker here if you find things unclear/flatout broken, much appreciated.
If anybody managed to build tpm-tools statically I would very much want to hear about it so I can get rid of this dynamic libraries.

## Dependencies
* [trousers](https://github.com/srajiv/trousers)
* [tpm-tools](https://github.com/srajiv/tpm-tools)
* [cryptsetup](https://gitlab.com/cryptsetup/cryptsetup)
* [openssl](https://www.openssl.org/)
* [busybox](https://busybox.net/)
* [linux kernel](https://www.kernel.org)

## INSTALL
You will need to:

0) setup tpm-tools on your system
1) modify `init` and `import.sh` according to your setup (it's commented)
2) create encryption key via tpm and store it in initramfs (see bellow)
3) copy `/var/lib/tpm/system.data` into initramfs
4) build initramfs file and make it load during boot (there are multiple ways to do this, 
    easiest one is IMO to compile custom kernel and set `CONFIG_INITRAMFS_SOURCE="/usr/src/initramfs`)
5) Test
6) Boot

## Encryption key

Basically you will want to generate a key, seal it with tpm and place it in initramfs as `/key.enc`.

```openssl rand 32 -hex | tpm\_sealdata > key.enc```

During boot, this key will be decrypted via tpm, used to unlock your encrypted partitions and then shreded in memory.

### To (un)seal or to (un)bind
It is also possible to increase the seal this key against PCR registers, but if your PCR registers change, then you might get screwed (updating BIOS, ...), so make sure you know what you are doing.
Rough list of PCRs is defined in [TCG Client Implementation](https://trustedcomputinggroup.org/wp-content/uploads/TCG_PCClientImplementation_1-21_1_00.pdf):

```
PCR 0-4         BIOS, ROM, MBR
PCR 5-7         OS loaders
PCR 8-15        OS
PCR 16          Debug
PCR 17-22       Trusted OS
PCR 23          AS
```

Futher info in [TPM fundamentals](http://www.cs.unh.edu/~it666/reading_list/Hardware/tpm_fundamentals.pdf).

### Use nvram to store the key onchip
TODO (?)

## var/lib/tpm/system.data

You will need to copy this file from your main installation (where you initialized TPM via tpm-tools).

### Binary replacement
You will need tpm-tools utilities (tcsd, tpm_*) , cryptsetup (static) and busybox (static).
Dynamic libraries needed for tpm-tools packages can be extracted with lddtree by following guide here:
[lddtree usage - gentoo wiki](https://wiki.gentoo.org/wiki/Custom_Initramfs#lddtree)


## Testing
### chroot
Chroot into initramfs and "emulate" what would happen on boot like this:

```mount -t proc /proc ./initramfs/proc
mount --rbind /sys ./initramfs/sys
mount --make-rslave ./initramfs/sys
mount --rbind /dev ./initramfs/dev
mount --make-rslave ./initramfs/dev
chroot ./initramfs /busybox/sh
. import.sh
```

You won't be able to execute init though.

### Live
Most commands in init have `|| rescue_shell` appended to them, e.g. on failure you will be dropped into busybox shell.
Afterwards you can quite easily debug from there (assuming you know how shell works). 
You will probably want to load `import.sh` functions, this needs to be done manually via `. import.sh`.

Feel free to experiment with /init script.

## Tree
```├── initramfs                   // main initramfs
│   ├── bin
│   │   ├── busybox
│   │   ├── tpm\_sealdata
│   │   └── tpm\_unsealdata
│   ├── dev                     // this will be further populated by busyboxs "mdev -s"
│   │   ├── console
│   │   ├── kmsg
│   │   ├── loop0
│   │   ├── ...
│   │   ├── loop5
│   │   ├── null
│   │   ├── random
│   │   ├── tpm
│   │   ├── tpm0
│   │   ├── tty
│   │   ├── tty0
│   │   └── urandom
│   ├── etc                     // all this crap is required because tcsd expects working tcp sockets and user/group tss
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
│   │   ├── tpm\_selftest       // tpm-tools libraries
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
```

# Issues
Accepting issues/pull requests, feel free to drop a comment [@pruzinat](https://twitter.com/).

## License
All the scripts are licensed under WTFPLv2 (see COPYING).
Binaries are included for convenience only, see respective projects (Dependencies) in for licensing.
