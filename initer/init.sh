#!/bin/bash

set -e

# Last 2 HEX digits should be attached
UUID_PREFIX="47ca5ce5-c7f2-45ae-97f9-d717f80f63"
FAT_SERIAL_PREFIX="5DC62E"


if [ "$1" = "" -o "$2" = "" ]; then
	echo "This script initializes SSD for use in UIOB system."
	echo "See https://ximc.ru/issues/16479 for more info."
	echo "Usage: $0 swu-update-file ssd-drive-path"
	echo "For example: $0 update.swu /dev/sdXX"
	echo "WARNING: This will destroy all data on the chosen device."
	exit
fi

current_script_location()
{
	local SOURCE="${BASH_SOURCE[0]}"
	while [[ -h "$SOURCE" ]]; do # resolve $SOURCE until the file is no longer a symlink
		local DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
		SOURCE="$(readlink "$SOURCE")"
		
		# If $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
		[[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
	done
	
	cd -P "$( dirname "$SOURCE" )" && pwd
}


swu="$(readlink -f $1)"
disk="$2"

script="$(current_script_location)/script.sfdisk"
tmpdir=$(mktemp -d)
cp "${script}" "${tmpdir}"
cd "${tmpdir}"

echo "Extracting swu update..."
cpio -idv < "${swu}"
echo "OK"

echo -e "\nWriting drive partition table..."
sfdisk "${disk}" < "${script}"
sync
partprobe "${disk}"
echo "OK"

echo -e "\nWaiting for partition to appear..."
for i in $(seq 1 7); do
	echo -n "    ${disk}${i}... "
	while [ ! -b "${disk}${i}" ] ; do
		sleep 1
		echo -n "."
	done
	echo
done
echo "OK"

echo -e "\nSync..."
sync
echo "OK"

echo -e "\nCopying first partition, please wait..."
zcat ssd.ext4.gz | dd of="${disk}1" bs=1M
echo -e "OK\nChecking copied partition..."
e2fsck -f "${disk}1"
echo -e "OK\nSetting copied partition UUID..."
echo "y" | tune2fs -c 1 -U "${UUID_PREFIX}01" "${disk}1"
echo "OK"

echo -e "\nCopying boot partition, please wait..."
zcat boot.fat.gz | dd of="${disk}5" bs=1M
echo -e "OK\nSetting copied partition UUID..."
mlabel -N "${FAT_SERIAL_PREFIX}05" -i "${disk}5" ::
echo "OK"

echo -e "\nCreating remaining partition filesystems..."
for i in 2 3 ; do
	mkfs.ext4 -F "${disk}${i}" -U "${UUID_PREFIX}0${i}"
	tune2fs -c 1 "${disk}${i}"
done
for i in 6 7 ; do
	mkfs.fat -i "${FAT_SERIAL_PREFIX}0${i}" "${disk}${i}"
done
echo "OK"

echo -e "\nSync..."
sync
echo "OK"

echo -e "\nChecking home dir and copying files..."
mntdir="$(mktemp -d)"
home="${mntdir}"/uiob/
mount "${disk}3" "${mntdir}"
mkdir "${home}"
user=1000
group=1000
chown "${user}":"${group}" "${home}"
mkdir -p "${mntdir}/root/var/log/journal/"
umount "${mntdir}"
echo "OK"

echo -e "\nWriting boot flags..."
part="${disk}7"
mount "${part}" "${mntdir}"
echo -ne "\x01" > "${mntdir}/partfile"
echo -ne "\x01" > "${mntdir}/bootfile"
umount "${part}"
echo "OK"

echo -e "\nCleaning up..."
rmdir "${mntdir}"
cd /
rm -r "${tmpdir}"
echo "OK"
