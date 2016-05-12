#!/bin/bash
#
# This is mkextlin.sh. (May 11, 2011)
#
# bash mkextlin.sh -h "For Help!"
#
PATH="/bin:/sbin:/usr/bin:/usr/sbin:$PATH"

help() {
    msg="Press enter to scroll, q to Quit!"
if [ -x "`type -path less`" ]; then
    pager=less
elif [ -x "`type -path more`" ]; then
    pager=more
else
    pager=cat
    msg_cat="
    Press [Shift]-[Page-Up] to scroll back!"
fi

$pager << EOF

$msg

===========================================================================
  If you want to install Linux to a Linux partition on a USB Flash drive.
===========================================================================

   The USB device should be at least 512 MB to hold the contents of
   rootfs.cgz from RIPLinuX-X.X.iso.

========================================================================

   It will create a partition and put an ext2/3/4 or btrfs filesystem
   on it, then the Linux system will be extracted to it. You'll be able
   to boot and use it, just like if it was installed to a hard drive
   Linux partition.

   # fdisk -l  "To find the device the USB drive is on!"
               "For example, if it says /dev/sdb1, just put '/dev/sdb' etc."

   Specify type of filesystem with '-t' option (ext2, ext3, ext4, or btrfs).

   # bash mkextlin.sh -t ext3 RIPLinuX-X.X.iso /dev/sdb

   The above example assumes the USB drive is on /dev/sdb!

   Instead of specifying an ISO image you can specify a source directory
   that contains the contents of the ISO image, laid out the same way
   as the ISO image.

   # bash mkextlin.sh -t ext3 source_directory /dev/sdb

   If you had RIPLinuX on CD mounted under /mnt/cdrom, you could do this.

   bash mkextlin.sh -t ext3 /mnt/cdrom /dev/sdb 

   To boot the Linux system, the BIOS must support booting from a USB device.
   $msg_cat
EOF
   exit
}

if [ "$1" = "-h" ]; then
   help
elif [ -n "$1" ]; then

if [ -x "`type -path mktemp`" ]; then
  tmpdir="`mktemp -d`"
if [ ! $? = 0 ]; then
  mkdir /tmp/tmp.$$ && tmpdir=/tmp/tmp.$$
fi
else
  mkdir /tmp/tmp.$$ && tmpdir=/tmp/tmp.$$
fi

if [ -z "$tmpdir" ]; then
  echo "Error creating temp directory."
  exit
fi

chmod 1777 /tmp

error() {
    umount $tmpdir/extlinux 2>/dev/null
    umount $tmpdir/rip1 2>/dev/null
    exit 1
}

if [ "$1" = "-t" ]; then
  fs=$2
if ! echo $fs | grep -q -w -E "ext2|ext3|ext4|btrfs" ; then
  echo "After '-t', put ext2, ext3, ext4, or btrfs"
  exit
fi
  shift 2
else
  exit
fi

if [ ! -f "$1" -a ! -d "$1" ]; then
   echo "ERROR: Can't find ISO image, or source directory \`$1'!"
   exit
fi

if [ ! -b "$2" ]; then
   echo "ERROR: Can't find USB device \`$2'!"
   exit
fi

if echo $2 | grep -q "[0-9]$" ; then
  echo "ERROR: The device '$2' can't end in a number!"
  exit
fi

if [ ! -x "`type -path fdisk`" ]; then
    echo "ERROR: Can't find \`fdisk'!"
    exit
fi

if [ ! -x "`type -path cpio`" ]; then
    echo "ERROR: Can't find \`cpio'!"
    exit
fi

if [ "$fs" = "btrfs" ]; then
if [ ! -x "`type -path mkfs.btrfs`" ]; then
    echo "ERROR: Can't find \`mkfs.btrfs'!"
    exit
fi
else
if [ ! -x "`type -path mke2fs`" ]; then
    echo "ERROR: Can't find \`mke2fs'!"
    exit
fi
fi

if [ -d "$1" ]; then
   if [ "$1" = "." ]; then
     dir="`basename "$PWD"`"
   if [ "$dir" = "boot" -a -f rootfs.cgz ]; then
     dir="`dirname "$PWD"`"
   elif [ -d boot -a -f boot/rootfs.cgz ]; then
     dir="$PWD"
   else
     echo "Don't put '.', put the full path to the directory!"
     exit
   fi
   else
     dir="$1"
   fi
     ln -s "$dir" $tmpdir/rip1 || error
else
if ! grep -q -w "loop" /proc/devices ; then
     unset loaded
if grep -q "loop\.ko" /lib/modules/`uname -r`/modules.dep 2>/dev/null ; then
     modprobe loop 2>/dev/null && loaded=yes
fi
   if [ ! "$loaded" = "yes" ]; then
     echo "ERROR: I need loop support in the kernel, or loaded as a module!"
     echo "modprobe loop"
     exit
   fi
fi
if ! grep -q -w "iso9660" /proc/filesystems ; then
     unset loaded
if grep -q "iso9660\.ko" /lib/modules/`uname -r`/modules.dep 2>/dev/null ; then
     modprobe iso9660 2>/dev/null && loaded=yes
fi
   if [ ! "$loaded" = "yes" ]; then
     echo "ERROR: I need iso9660 support in the kernel, or loaded as a module!"
     echo "modprobe iso9660"
     exit
   fi
fi
   mkdir -p $tmpdir/rip1
   mount -r -o loop $1 $tmpdir/rip1 || exit
fi
else
   help
fi

extlinux_conf() {
pt=$1
echo "DEFAULT menu.c32
PROMPT 0
MENU TITLE RIPLinuX

LABEL Boot Linux system!
KERNEL kernel32
APPEND vga=normal video=640x400 rootdelay=6 root=$pt ro

LABEL Edit and put 'root=/dev/XXXX' Linux partition to boot!
KERNEL kernel32
APPEND vga=normal ro root=/dev/XXXX

LABEL Boot Memory Tester!
KERNEL memtest
APPEND -

LABEL Boot GRUB bootloader!
KERNEL grub.exe
APPEND --config-file=(hd0,0)/boot/extlinux/menu.lst" > $tmpdir/extlinux/boot/extlinux/extlinux.conf
}

grub_conf() {
pt=$1
echo "title ------------------------- ( RIPLinuX ) -------------------------
root (hd0)

title Boot Linux system!
kernel (hd0,0)/boot/extlinux/kernel32 vga=normal video=640x400 rootdelay=6 root=$pt ro

title Boot Memory Tester!
map --mem=-2880 (hd0,0)/boot/extlinux/memtest (fd0)
map --hook
chainloader (fd0)+1

title Find and load NTLDR of Windows NT/2K/XP!
find --set-root --ignore-floppies --ignore-cd /ntldr
map () (hd0)
map (hd0) ()
map --rehook
find --set-root --ignore-floppies --ignore-cd /ntldr
chainloader /ntldr

title Find and load BOOTMGR of Windows VISTA/7!
find --set-root --ignore-floppies --ignore-cd /bootmgr
map () (hd0)
map (hd0) ()
map --rehook
find --set-root --ignore-floppies --ignore-cd /bootmgr
chainloader /bootmgr

title Boot MBR on first hard drive!
rootnoverify (hd1)
map (hd1) (hd0)
chainloader +1

title Boot partition #1 on first hard drive!
rootnoverify (hd1,0)
map (hd1) (hd0)
chainloader +1

title Boot partition #2 on first hard drive!
rootnoverify (hd1,1)
map (hd1) (hd0)
chainloader +1

title Boot partition #3 on first hard drive!
rootnoverify (hd1,2)
map (hd1) (hd0)
chainloader +1

title Boot partition #4 on first hard drive!
rootnoverify (hd1,3)
map (hd1) (hd0)
chainloader +1

title Boot MBR on second hard drive!
rootnoverify (hd2)
map (hd2) (hd0)
chainloader +1

title Boot partition #1 on second hard drive!
rootnoverify (hd2,0)
map (hd2) (hd0)
chainloader +1

title Boot partition #2 on second hard drive!
rootnoverify (hd2,1)
map (hd2) (hd0)
chainloader +1

title Boot partition #3 on second hard drive!
rootnoverify (hd2,2)
map (hd2) (hd0)
chainloader +1

title Boot partition #4 on second hard drive!
rootnoverify (hd2,3)
map (hd2) (hd0)
chainloader +1

title --- For help press 'c', type: 'help'
root (hd0)

title --- For usage examples, type: 'cat (hd0,0)/boot/extlinux/grub.txt'
root (hd0)" > $tmpdir/extlinux/boot/extlinux/menu.lst
}

for f in kernel32 rootfs.cgz syslinux/extlinux.bin ; do
if [ ! -f $tmpdir/rip1/boot/$f ]; then
    umount $tmpdir/rip1 2>/dev/null && rm -rf $tmpdir
    echo "ERROR: Can't find \`/boot/$f' on \`$1'!"
    exit
fi
done

if mount | grep -q $2;
then
	umount $2 2>/dev/null ||
	umount $2"1" 2>/dev/null ||
	{
		echo "ERROR: failed to unmount partition \`$2'"
		exit
	}
fi

echo "*** Creating partition on $2... ***"

dd if=$2 of=$tmpdir/mbr.bin bs=512 count=1 1>/dev/null 2>/dev/null
dd if=/dev/zero of=$2 bs=512 count=1 1>/dev/null 2>/dev/null
echo -e "n\np\n1\n\n\na\n1\nw\n" | fdisk $2 1>/dev/null 2>/dev/null || fdisk_error=yes
if [ "$fdisk_error" = "yes" ]; then
  dd if=$tmpdir/mbr.bin of=$2 bs=512 count=1 1>/dev/null 2>/dev/null
  rm -f $tmpdir/mbr.bin
  echo "ERROR: Fdisk had a problem partitioning $2"
  exit
fi

sleep 3
dev=$2"1"

if [ ! -b "$dev" ]; then
   echo "ERROR: Can't find USB device \`$dev'!"
   exit
fi

 echo "*** Creating $fs filesystem on $dev..."
 if [ "$fs" = "btrfs" ]; then
   mkfs.btrfs $dev || error
 else
   mke2fs -q -t $fs $dev || error
 fi

mkdir -p $tmpdir/extlinux
mount $dev $tmpdir/extlinux || error

echo "*** Extracting rootfs.cgz to $dev..."
( cd $tmpdir/extlinux && gzip -dc $tmpdir/rip1/boot/rootfs.cgz | cpio --quiet -iumd || error )

mkdir -p $tmpdir/extlinux/boot/extlinux
rm -f $tmpdir/extlinux/init
cp $tmpdir/rip1/boot/kernel32 $tmpdir/extlinux/boot/extlinux || error
cp $tmpdir/rip1/boot/isolinux/memtest $tmpdir/extlinux/boot/extlinux
cp $tmpdir/rip1/boot/grub4dos/grub.exe $tmpdir/extlinux/boot/extlinux
cp $tmpdir/rip1/boot/isolinux/menu.c32 $tmpdir/extlinux/boot/extlinux || error
cp $tmpdir/rip1/boot/doc/grub.txt $tmpdir/extlinux/boot/extlinux

if [ -x $tmpdir/rip1/boot/syslinux/extlinux.bin ]; then
    $tmpdir/rip1/boot/syslinux/extlinux.bin -i $tmpdir/extlinux/boot/extlinux 2>/dev/null
else
    cp $tmpdir/rip1/boot/syslinux/extlinux.bin $tmpdir || error
    chmod 755 $tmpdir/extlinux.bin || error
    $tmpdir/extlinux.bin -i $tmpdir/extlinux/boot/extlinux 2>/dev/null 
    rm -f $tmpdir/extlinux.bin 
fi
    extlinux_conf $dev
    grub_conf $dev

    echo "$dev  /   $fs   defaults  1  1" > $tmpdir/extlinux/etc/fstab

    umount $tmpdir/extlinux 2>/dev/null || error=yes
    cat $tmpdir/rip1/boot/syslinux/mbr.bin > $2
    umount $tmpdir/rip1 2>/dev/null || error=yes
    [ "$error" = "yes" ] || rm -rf $tmpdir

echo "
*** The Linux system on the USB drive should be ready to boot!
    Done!"
    exit 0
