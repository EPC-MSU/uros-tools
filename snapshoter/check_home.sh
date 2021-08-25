#!/bin/sh

root_device="/dev/sda"
home_device="${root_device}3"
if [ x"$(mount | grep $home_device | grep 'rw')" = x ]; then
	echo "Creating home filesystem ..."
	mkfs.ext4 $home_device
	tune2fs -c 1 $home_device
	mount $home_device /home/ -o rw
fi

username="uiob"
homepath="/home/${username}"
if [ ! -d $homepath  ] ; then
	echo "Creating home dir ..."
	mkdir $homepath
fi

perm=755
if [ ! x"$(stat -c '%a' $homepath)" = x"$perm" ] ; then
	echo "Setting home dir permissions ..."
	chmod $perm $homepath
fi

gid=1000
uid=1000
if [ ! x"$(stat -c '%g' $homepath)" = x"$gid" -o ! x"$(stat -c '%u' $homepath)" = x"$uid" ] ; then
	echo "Setting home dir owner ..."
	chown $gid:$uid $homepath
fi

conffile="tango.conf"
conffilepath="${homepath}/${conffile}"
if [ ! -f $conffilepath ] ; then
	echo "Copying ${conffile} to home dir ..."
	cp -p /tmp/$conffile $conffilepath
fi

fperm=666
if [ ! x"$(stat -c '%a' $conffilepath)" = x"$fperm" ] ; then
	echo "Setting ${conffile} permissions ..."
	chmod $fperm $conffilepath
fi

echo "Preinstall script complete."
