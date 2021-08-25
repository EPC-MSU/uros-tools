#!/bin/sh
root_device="/dev/sda"
service_part=${root_device}7
printer=/usr/bin/printf
mntdir=$(mktemp -d)
mount ${service_part} ${mntdir}
bootfile=${mntdir}/bootfile
partfile=${mntdir}/partfile
partvalue=$(/bin/cat $partfile | /usr/bin/hexdump -v -e '/1 "%02X"')
if [ "y$partvalue" != "y01" ]; then
    $printer '\x01' > $partfile
else
    $printer '\x02' > $partfile
fi
$printer '\x00' > $bootfile
umount ${mntdir}
