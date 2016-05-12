#!/bin/bash
#
# This is mkusb.sh. (Jan 9, 2012)
#
# bash mkusb.sh -h "For Help!"
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

========================================================================
          If you want to boot RIPLinuX from a USB flash drive.
========================================================================

   The USB device should have at least 150 MB free for RIPLinuX-X.X.iso.

================== Install RIPLinuX to a USB device =================

# bash mkusb.sh RIPLinuX-X.X.iso /dev/sdb1

The above example assumes the USB drive is on /dev/sdb1!

# fdisk -l  "To find the device the USB drive is on!"

If the USB drive is not partitioned and FAT16/32 formatted,
use the '-f' option, because it must be partitioned and FAT
formatted. You'll loose anything on the USB drive!

# bash mkusb.sh -f RIPLinuX-X.X.iso /dev/sdb  "The device must not end
                                               with a number!"

Instead of specifying an ISO image you can specify a source directory
that contains the contents of the ISO image, laid out the same way
as the ISO image.

# bash mkusb.sh source_directory /dev/sdb1

If you had RIPLinux on CD mounted under /mnt/hdd, you could do this.

# bash mkusb.sh /mnt/hdd /dev/sdb1
$msg_cat
EOF
   exit
}

if [ "$1" = "-h" ]; then
   help
elif [ -n "$1" ]; then
  mkdir -p /tmp
  chmod 1777 /tmp
if [ -x "`type -path mktemp`" ]; then
  tmpdir="`mktemp -d`"
if [ ! $? = 0 ]; then
  mkdir -p /tmp/tmp.$$ && tmpdir=/tmp/tmp.$$
fi
else
  mkdir -p /tmp/tmp.$$ && tmpdir=/tmp/tmp.$$
fi

if [ -z "$tmpdir" ]; then
  echo "Error creating temp directory."
  exit
fi

error() {
   umount $tmpdir/rip1 2>/dev/null
   umount $tmpdir/usb 2>/dev/null
   exit
}

if [ "$1" = "-f" ]; then
  format=yes
  shift
fi

if [ ! -f "$1" -a ! -d "$1" ]; then
   echo "ERROR: Can't find ISO image, or source directory \`$1'!"
   exit
fi

if [ ! -b "$2" ]; then
   echo "ERROR: Can't find USB device \`$2'!"
   exit
fi

if ! grep -q -w -E "msdos|vfat" /proc/filesystems ; then
if grep -q -E "msdos\.ko|vfat\.ko" /lib/modules/`uname -r`/modules.dep 2>/dev/null ; then
     modprobe vfat 2>/dev/null
   if [ ! $? = 0 ]; then
     modprobe msdos 2>/dev/null && loaded=yes
   else
     loaded=yes
   fi
fi
   if [ ! "$loaded" = "yes" ]; then
     echo "ERROR: I need msdos or vfat support in the kernel, or loaded as a module!"
     echo "modprobe vfat"
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
   mount -r -t iso9660 -o loop $1 $tmpdir/rip1 || error
fi
else
echo "
----------------------------------------------------------------------
Usage: bash mkusb.sh RIPLinuX-X.X.iso /dev/sdb1

The above example assumes the USB device is on /dev/sdb1!

Instead of specifying an ISO image you can specify a source directory
that contains the contents of the ISO image, laid out the same way
as the ISO image.

bash mkusb.sh source_directory /dev/sdb1

If you have RIPLinuX on CD mounted under /mnt/hdd, you could do this.

bash mkusb.sh /mnt/hdd /dev/sdb1

For complete Help, type \`bash mkusb.sh -h'.
----------------------------------------------------------------------
"
exit
fi

for f in kernel32 kernel64 rootfs.cgz syslinux/syslinux.bin syslinux/mkdosfs.bin ; do
if [ ! -f $tmpdir/rip1/boot/$f ]; then
    umount $tmpdir/rip1 2>/dev/null && rm -rf $tmpdir
    echo "ERROR: Can't find \`/boot/$f' on \`$1'!"
    exit
fi
done

dev=$2
umount $dev 2>/dev/null

if [ "$2" = "/dev/mmcblk0p1" ]; then
  mbr_dev="`echo $2 | cut -b 1-12`"
else
  mbr_dev="`echo $2 | cut -b 1-8`"
fi

  if [ "$format" = "yes" ]; then

if echo $dev | grep -q "[1-9]$" ; then
  echo "ERROR: The device '$dev' can't end in a number with the '-f' option!"
  exit
fi

if [ ! -x "`type -path fdisk`" ]; then
    echo "ERROR: Can't find \`fdisk'!"
    exit
fi

    echo "*** Creating partition on $dev..."

dd if=$2 of=$tmpdir/mbr.bin bs=512 count=1 1>/dev/null 2>/dev/null
dd if=/dev/zero of=$2 bs=512 count=1 1>/dev/null 2>/dev/null
echo -e "n\np\n1\n\n\nt\nb\na\n1\nw\n" | fdisk $2 1>/dev/null 2>/dev/null || fdisk_error=yes
if [ "$fdisk_error" = "yes" ]; then
  dd if=$tmpdir/mbr.bin of=$2 bs=512 count=1 1>/dev/null 2>/dev/null
  rm -f $tmpdir/mbr.bin
  echo "ERROR: Fdisk had a problem partitioning $2"
  exit
fi

sleep 3

if [ "$2" = "/dev/mmcblk0" ]; then
  dev=$2"p1"
  mbr_dev="`echo $dev | cut -b 1-12`"
else
  dev=$2"1"
  mbr_dev="`echo $dev | cut -b 1-8`"
fi

if [ ! -b "$dev" ]; then
   echo "ERROR: Can't find USB device \`$dev'!"
   exit
fi

    echo "*** FAT32 formatting $dev..."

if [ -x $tmpdir/rip1/boot/syslinux/mkdosfs.bin ]; then
    $tmpdir/rip1/boot/syslinux/mkdosfs.bin -F 32 -I $dev 1>/dev/null || error
else
    cp $tmpdir/rip1/boot/syslinux/mkdosfs.bin $tmpdir || error
    chmod 755 $tmpdir/mkdosfs.bin || error
    $tmpdir/mkdosfs.bin -F 32 -I $dev 1>/dev/null || error
    rm -f $tmpdir/mkdosfs.bin
fi
else
if ! echo $dev | grep -q "[1-9]$" ; then
  echo "ERROR: The device '$dev' must end with a number!"
  exit
fi
  fi

   mkdir -p $tmpdir/usb
   mount -t vfat $dev $tmpdir/usb 2>/dev/null || \
   mount -t msdos $dev $tmpdir/usb || error

   echo "*** Copying rootfs.cgz and kernels to $dev..."
   mkdir -p $tmpdir/usb/boot/syslinux || error
   rm -f $tmpdir/usb/boot/syslinux/kernel32 $tmpdir/usb/boot/syslinux/rootfs.cgz
   rm -f $tmpdir/usb/boot/syslinux/kernel64
   cp $tmpdir/rip1/boot/kernel32 $tmpdir/usb/boot/syslinux || error
   cp $tmpdir/rip1/boot/kernel64 $tmpdir/usb/boot/syslinux || error
   cp $tmpdir/rip1/boot/rootfs.cgz $tmpdir/usb/boot/syslinux || error

for f in $tmpdir/rip1/boot/isolinux/memtest $tmpdir/rip1/boot/grub4dos/grub.exe \
$tmpdir/rip1/boot/doc/grub.txt \
$tmpdir/rip1/boot/isolinux/menu.c32 \
$tmpdir/rip1/boot/isolinux/hdt.c32 $tmpdir/rip1/boot/isolinux/pci.ids \
$tmpdir/rip1/boot/isolinux/modules.pci $tmpdir/rip1/boot/isolinux/chain.c32 \
$tmpdir/rip1/boot/isolinux/f1.txt $tmpdir/rip1/boot/isolinux/f2.txt \
$tmpdir/rip1/boot/isolinux/f3.txt \
$tmpdir/rip1/boot/isolinux/kbdmap.c32 \
$tmpdir/rip1/boot/isolinux/plpbt
do
    rm -f $tmpdir/usb/boot/syslinux/`basename $f`
    cp $f $tmpdir/usb/boot/syslinux
done
rm -f $tmpdir/usb/boot/syslinux/menu.lst $tmpdir/usb/boot/syslinux/syslinux.cfg
cp $tmpdir/rip1/boot/syslinux/mkusb.lst $tmpdir/usb/boot/syslinux/menu.lst
cp $tmpdir/rip1/boot/syslinux/mkusb.cfg $tmpdir/usb/boot/syslinux/syslinux.cfg

   rm -rf $tmpdir/usb/boot/syslinux/doc $tmpdir/usb/boot/syslinux/maps
   cp -R $tmpdir/rip1/boot/doc $tmpdir/usb/boot/syslinux
   cp -R $tmpdir/rip1/boot/isolinux/maps $tmpdir/usb/boot/syslinux

   umount $tmpdir/usb 2>/dev/null || error=yes

if [ -x $tmpdir/rip1/boot/syslinux/syslinux.bin ]; then
    $tmpdir/rip1/boot/syslinux/syslinux.bin -i -d /boot/syslinux $dev || error
else
    cp $tmpdir/rip1/boot/syslinux/syslinux.bin $tmpdir || error
    chmod 755 $tmpdir/syslinux.bin || error
    $tmpdir/syslinux.bin -i -d /boot/syslinux $dev || error
    rm -f $tmpdir/syslinux.bin
fi

if [ -f $tmpdir/rip1/boot/syslinux/mbr.bin ]; then
  cat $tmpdir/rip1/boot/syslinux/mbr.bin > $mbr_dev
fi

umount $tmpdir/rip1 2>/dev/null || error=yes
[ "$error" = "yes" ] || rm -rf $tmpdir

echo "
*** The USB drive should be ready to boot!
    Done!"
    exit 0
