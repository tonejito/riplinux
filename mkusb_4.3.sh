#!/bin/sh
#
# This is mkusb.sh. (12-22-2007)
#
# sh mkusb.sh -h "For Help!"
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

   The USB device should be at least 75 MB for RIPLinuX-4.3.iso.
   The USB device should be at least 40 MB for RIPLinux-4.3-non-X.iso.
   
================== Install RIPLinuX to a USB device =================

   # sh mkusb.sh RIPLinuX-4.3.iso /dev/sdb  "You'll loose anything
                                             on the USB drive!"
   
   The above example assumes that's the name of the ISO image, and
   the USB drive is on /dev/sdb!

   # fdisk -l  "To find the device the USB drive is on!"
               "For example, if it says /dev/sdb4, just put '/dev/sdb' etc. "

   If you've already run mkusb and don't want the usb drive formatted
   again, you can use the '-f' option. This way you won't loose anything
   on the usb drive.
   
   # sh mkusb.sh -f RIPLinuX-4.3.iso /dev/sdb
   
   Instead of specifying an ISO image you can specify a source directory
   that contains the contents of the ISO image, laid out the same way
   as the ISO image.
    
   # sh mkusb.sh source_directory /dev/sdb

   If you had RIPLinuX on CD mounted under /mnt/cdrom, you could do this.

   sh mkusb.sh /mnt/cdrom /dev/sdb 

   If you want to change or add anything to the Linux system, do this.

   # mkdir /rip1 /rip2
   # mount -t vfat /dev/sdb /rip1
   # cd /rip2
   /rip2# gzip -dc /rip1/boot/rootfs.cgz | cpio -iumdv

   Make the changes in the /rip2 directory, then cpio/gzip the system.

   # rm /rip1/boot/rootfs.cgz
   /rip2# find . | bin/cpio -v -o -H newc | gzip -9 >/rip1/boot/rootfs.cgz
                     ^^^
           "Use the RIPLinuX 'bin/cpio' here!"

   # rm -r /rip2
   # umount /rip1
   # rmdir /rip1

   To boot the RIPLinuX system, the BIOS must support booting from a USB device.
   $msg_cat
EOF
   exit
}

if [ "$1" = "-h" ]; then
   help
fi

error() {
   umount /tmp/rip1 2>/dev/null
   rmdir /tmp/rip1 2>/dev/null
   rm -f /tmp/rip1 2>/dev/null
   rm -f /tmp/makeboot.bin /tmp/mkboot
   rmdir /tmp/empty_dir 2>/dev/null
   umount /tmp/usb 2>/dev/null && rmdir /tmp/usb
   exit
}

if [ -n "$1" ]; then

if [ "$1" = "-f" ]; then
  format=no
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

umount /tmp/rip1 2>/dev/null
rmdir /tmp/rip1 2>/dev/null
rm -f /tmp/rip1 2>/dev/null

if [ -d "$1" ]; then
   ln -s $1 /tmp/rip1 || error
else
if ! grep -q "loop" /proc/devices ; then
   echo "ERROR: I need loop support in the kernel, or loaded as a module!"
   echo "modprobe loop"
   exit
elif ! grep -q "iso9660" /proc/filesystems ; then
   echo "ERROR: I need iso9660 support in the kernel, or loaded as a module!"
   echo "modprobe iso9660"
   exit
fi
   mkdir -p /tmp/rip1
   mount -r -t iso9660 -o loop $1 /tmp/rip1 || error
fi
else
echo "
----------------------------------------------------------------------
Usage: sh mkusb.sh RIPLinuX-4.3.iso /dev/sdb

The above example assumes that's the name of the ISO image, and
the USB device is on /dev/sdb!

Instead of specifying an ISO image you can specify a source directory
that contains the contents of the ISO image, laid out the same way
as the ISO image.

sh mkusb.sh source_directory /dev/sdb

If you have RIPLinuX on CD mounted under /mnt/cdrom, you could do this.

sh mkusb.sh /mnt/cdrom /dev/sdb

For complete Help! type \`sh mkusb.sh -h'.
----------------------------------------------------------------------
"
exit
fi

sys_cfg() {
cat << EOF
DEFAULT menu.c32
PROMPT 0
MENU TITLE RIPLinuX

LABEL Boot Linux rescue system!
KERNEL kernel
APPEND vga=normal initrd=rootfs.cgz root=/dev/ram0 rw

LABEL Boot Linux rescue system! (skip keymap prompt)
KERNEL kernel
APPEND vga=normal nokeymap initrd=rootfs.cgz root=/dev/ram0 rw

LABEL Boot Linux rescue system to X!
KERNEL kernel
APPEND vga=normal xlogin initrd=rootfs.cgz root=/dev/ram0 rw

LABEL Boot Linux rescue system to X! (skip keymap prompt)
KERNEL kernel
APPEND vga=normal xlogin nokeymap initrd=rootfs.cgz root=/dev/ram0 rw

LABEL Edit and put 'root=/dev/XXXX' Linux partition to boot!
KERNEL kernel
APPEND vga=normal ro root=/dev/XXXX

LABEL Boot memory tester!
KERNEL memtest
APPEND -

LABEL Boot GRUB bootloader!
KERNEL grub.exe
APPEND --config-file=/boot/syslinux/menu.lst

LABEL Boot MBR on first hard drive!
KERNEL chain.c32
APPEND hd0 0

LABEL Boot partition #1 on first hard drive!
KERNEL chain.c32
APPEND hd0 1

LABEL Boot partition #2 on first hard drive!
KERNEL chain.c32
APPEND hd0 2

LABEL Boot partition #3 on first hard drive!
KERNEL chain.c32
APPEND hd0 3

LABEL Boot partition #4 on first hard drive!
KERNEL chain.c32
APPEND hd0 4

LABEL Boot MBR on second hard drive!
KERNEL chain.c32
APPEND hd1 0

LABEL Boot partition #1 on second hard drive!
KERNEL chain.c32
APPEND hd1 1

LABEL Boot partition #2 on second hard drive!
KERNEL chain.c32
APPEND hd1 2

LABEL Boot partition #3 on second hard drive!
KERNEL chain.c32
APPEND hd1 3

LABEL Boot partition #4 on second hard drive!
KERNEL chain.c32
APPEND hd1 4
EOF
}

for f in kernel rootfs.cgz makeboot/makeboot.bin ; do
if [ ! -f /tmp/rip1/boot/$f ]; then
    umount /tmp/rip1 2>/dev/null
    rmdir /tmp/rip1 2>/dev/null
    rm -f /tmp/rip1 2>/dev/null
    echo "ERROR: Can't find \`/boot/$f' on \`$1'!"
    exit
fi
done

echo "*** Working, please wait... ***"
umount $2 2>/dev/null

if [ ! "$format" = "no" ]; then
if [ -x /tmp/rip1/boot/makeboot/makeboot.bin ]; then
    echo "/tmp/rip1/boot/makeboot/makeboot.bin \\" > /tmp/mkboot
else
    cp /tmp/rip1/boot/makeboot/makeboot.bin /tmp || error
    chmod 755 /tmp/makeboot.bin || error
    echo "/tmp/makeboot.bin \\" > /tmp/mkboot
fi

echo "-o $2 -v -F -Y -Z -D -L RIPLinuX -b /tmp/rip1/boot/makeboot/ldlinux.bss \\
-m /tmp/rip1/boot/makeboot/mbrfat.bin \\
-c /tmp/rip1/boot/makeboot/ldlinux.sys /tmp/empty_dir" >> /tmp/mkboot

mkdir -p /tmp/empty_dir
sh /tmp/mkboot || error
rmdir /tmp/empty_dir 2>/dev/null
rm -f /tmp/makeboot.bin /tmp/mkboot
fi

   mkdir -p /tmp/usb
   mount $2 /tmp/usb || error

if [ "$format" = "no" ]; then
   if [ ! -f /tmp/usb/boot/syslinux/ldlinux.sys ]; then
     echo "ERROR: There's no '/boot/syslinux/ldlinux.sys' on $2!
       You probably need to run 'mksub.sh' without the '-f' option!
       You'll loose anything on the USB drive!"
     error  
   fi
fi

   echo "*** Copying rootfs.cgz and kernel to $2..."
   mkdir -p /tmp/usb/boot/syslinux
   rm -f /tmp/usb/boot/syslinux/kernel /tmp/usb/boot/syslinux/rootfs.cgz
   cp /tmp/rip1/boot/kernel /tmp/usb/boot/syslinux || error
   cp /tmp/rip1/boot/rootfs.cgz /tmp/usb/boot/syslinux || error
   sys_cfg > /tmp/usb/boot/syslinux/syslinux.cfg

for f in /tmp/rip1/boot/memtest /tmp/rip1/boot/grub4dos/grub.exe \
/tmp/rip1/boot/makeboot/menu.lst /tmp/rip1/boot/doc/grub.txt
do
    rm -f /tmp/usb/boot/syslinux/`basename $f`
    cp $f /tmp/usb/boot/syslinux
done

if [ ! "$format" = "no" ]; then
    mv /tmp/usb/ldlinux.sys /tmp/usb/boot/syslinux
for f in  /tmp/rip1/boot/isolinux/menu.c32 /tmp/rip1/boot/isolinux/chain.c32
do
    rm -f /tmp/usb/boot/syslinux/`basename $f`
    cp $f /tmp/usb/boot/syslinux
done
fi

   mkdir -p /tmp/usb/boot/syslinux/doc
   cp /tmp/rip1/boot/doc/* /tmp/usb/boot/syslinux/doc

umount /tmp/usb 2>/dev/null && rmdir /tmp/usb
umount /tmp/rip1 2>/dev/null
rmdir /tmp/rip1 2>/dev/null
rm -f /tmp/rip1 2>/dev/null

echo "
*** The USB drive should be ready to boot!
    Give it no more than 15 seconds to boot!
    Done!"
exit 0
