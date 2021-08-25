from argparse import ArgumentParser
import subprocess
import os
import gzip
import shutil
import json
import datetime
import tempfile
import libconf
import crypt
import re
import fileinput
import inspect


# parse cmdline opts
parser = ArgumentParser()

parser.add_argument(
    "-p", "--partition", required=True,
    help="Root partition (for example, /dev/sdX1)"
)
parser.add_argument(
    "-b", "--bootimage", required=True,
    help="Boot partition (for example, /dev/sdX1)"
)
parser.add_argument(
    "-s", "--semversion", required=True,
    help="Image version in semversion notation: MAJOR.MINOR.BUGFIX[-suffix]"
)
parser.add_argument(
    "-n", "--name", required=True,
    help="Image name"
)

args = parser.parse_args()


# detect current script directory path
current_script_dir = os.path.dirname(os.path.abspath(inspect.getframeinfo(inspect.currentframe()).filename))


# dd image to temp dir
with tempfile.NamedTemporaryFile() as partition_tmp_file, \
        tempfile.TemporaryDirectory() as mountpoint:
    print("Copying partition to temporary directory, please wait...")
    subprocess.run(
        ["dd", "if={}".format(args.partition), "of={}".format(partition_tmp_file.name), "bs=1M"],
        check=True
    )

    # run filesystem check: first write new dates into last_mount_time and last_write_time fields of the FS superblock
    # by mount-umount this assumes that the PC this script is being run on has correct date and inode count is not too
    # large (less than epoch in seconds) this is needed because if the filesystem last mount date or last write date
    # is set close to 01 Jan 1970 then fsck will skip low_dtime_check
    print("Mounting to reset fs superblock datetime...")
    subprocess.run(["mount", partition_tmp_file.name, mountpoint], check=True)

    exception = None
    unmount_attempts = 3
    for i in range(unmount_attempts):
        try:
            subprocess.run(["umount", mountpoint], check=True)
        except subprocess.CalledProcessError as e:
            exception = e
            print(
                "When unmounting {mountpoint_name} exception caught: {e}.".format(
                    mountpoint_name=mountpoint,
                    e=e
                    )
                )
            if i < unmount_attempts - 1:
                print("Try again...")
        else:
            break
    else:
        if exception is not None:
            raise exception

    # now run forced fsck on the file with preen option
    # todo: should we call fsck.ext4 explicitly?
    # if errors are found then fsck will return non-zero code and the script will terminate here
    print("Running fsck...")
    subprocess.run(["fsck", "-f", "-p", partition_tmp_file.name], check=True)

    # mount the file
    print("Cleaning the image...")
    subprocess.run(["mount", partition_tmp_file.name, mountpoint], check=True)

    # clean the image
    dirlist = [
        "/var/lib/apt/lists/",
        "/var/log/",
        "/var/spool/exim4/input/",
        "/var/cache/apt/",
    ]
    filelist = [
        "/root/.bash_history",
    ]
    for entry in filelist:
        try:
            os.remove(mountpoint + entry)
        except OSError:
            pass
    for entry in dirlist:
        try:
            for name in os.listdir(os.path.join(mountpoint, entry)):
                filepath = os.path.join(mountpoint, entry, name)
                if os.path.isfile(filepath):
                    try:
                        os.remove(filepath)
                    except OSError:
                        pass
        except FileNotFoundError:
            pass

    # embed metainfo
    metafilepath = os.path.join(mountpoint, "etc", "ximc")
    obj = {
        "version": args.semversion,
        "date": datetime.datetime.now().date().isoformat()
    }
    with open(metafilepath, "w") as f:
        json.dump(obj, f, indent=2)

    # replace root password with pregenerated one
    shadowfile = "/etc/shadow"
    password = "Aem3Ohp5ohchigie"
    salt = crypt.mksalt(crypt.METHOD_SHA512)
    fullstring = "root:{hash}:17176:0:99999:7:::".format(hash=crypt.crypt(password, salt))
    for line in fileinput.input([os.path.join(mountpoint, shadowfile)], inplace=True):
        print(re.sub("^root:.*$", fullstring, line), end="")

    # umount & zerofree
    subprocess.run(["umount", mountpoint], check=True)
    print("Running zerofree, please wait...")
    subprocess.run(["zerofree", "-v", partition_tmp_file.name], check=True)

    with tempfile.TemporaryDirectory(
        prefix="snapshoter_tmp_{name}_{version}_".format(name=args.name, version=args.semversion),
        dir=os.getcwd()
    ) as swu_tmp_dir:
        # gzip image
        gzfilename = "ssd.ext4.gz"
        print("Compressing partition image, please wait...")
        with open(partition_tmp_file.name, "rb") as f_in:
            with gzip.open(os.path.join(swu_tmp_dir, gzfilename), "wb") as f_out:
                shutil.copyfileobj(f_in, f_out)

        # boot fat image with uImage and uInitramfs
        bootimgfilename = "boot.fat.gz"
        print("Compressing boot image, please wait...")
        with open(args.bootimage, "rb") as f_in:
            with gzip.open(os.path.join(swu_tmp_dir, bootimgfilename), "wb") as f_out:
                shutil.copyfileobj(f_in, f_out)

        # create sw-description
        checkname = "check_home.sh"
        switchname = "partition_switcher.sh"
        # tangoconf = "tango.conf"
        conf = {
            "software": {
                "version": args.semversion,
                "hardware-compatibility": ["all"],
                "scripts": (
                    {
                        "filename": checkname,
                        "type": "preinstall"
                    },
                    {
                        "filename": switchname,
                        "type": "postinstall"
                    },
                ),
                "images": (
                    {
                        "filename": gzfilename,
                        "device": "/dev/sys-unused",
                        "compressed": True
                    },
                    {
                        "filename": bootimgfilename,
                        "device": "/dev/boot-unused",
                        "compressed": True
                    },
                )
            }
        }
        swdescname = "sw-description"
        with open(os.path.join(swu_tmp_dir, swdescname), "w") as f:
            libconf.dump(conf, f)

        # copy files
        for filename in [
            checkname,
            switchname,
            # tangoconf,
        ]:
            shutil.copy2(src=os.path.join(current_script_dir, filename), dst=os.path.join(swu_tmp_dir, filename))

        # exec swupdate build (cpio)
        swu_files = [
            swdescname,  # NOTE: Should be first!
            checkname,
            switchname,
            gzfilename,
            bootimgfilename
        ]

        out_file_path = os.path.join(
            os.getcwd(),
            "{name}-{version}.swu".format(name=args.name, version=args.semversion)
        )

        # temporarily disable creation by libarchive because it doesn't support new cpio with crc ("070702" magic)
        """
        with file_writer(out_file_path, "crc") as archive:
            for file in swu_files:
                archive.add_files(file)
        """

        # create archive through command line as a workaround
        # with open(out_file_path, "wb") as f:
        #     pass

        saved_cwd = os.getcwd()
        os.chdir(swu_tmp_dir)
        try:
            subprocess.run(
                ["cpio", "--create", "--format=crc", "-O", out_file_path],
                input="\n".join(swu_files).encode(),
                check=True
            )
        finally:
            os.chdir(saved_cwd)

# done
print("Created update file {}".format(out_file_path))
