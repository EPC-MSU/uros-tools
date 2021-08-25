FROM debian:stable-slim

RUN apt update && apt install -y cpio parted

Запуск с доступом к устройствам(напр USB)
docker run --privileged -ti debian:stable-slim bash

Проброс путей
-v /dev/:/dev/

Одно устройство через флаг device
$ docker run --device=/dev/sda:/dev/xvdc --rm -it ubuntu fdisk  /dev/xvdc

Command (m for help): q
$ docker run --device=/dev/sda:/dev/xvdc:r --rm -it ubuntu fdisk  /dev/xvdc
You will not be able to write the partition table.

Command (m for help): q


docker run --rm -v /home/nikatar/Документы/ЦИФ/uiiob-tools/initer/:/initer/ --device=/dev/sda -ti debian:stable-slim /bin/bash -c '/initer/init.sh image /dev/sda'

docker run --rm -v /home/nikatar/Документы/ЦИФ/uiob-tools/initer/:/initer/ --device=/dev/sda -ti debian:jessie-slim /bin/bash -c 'apt update && apt install -y cpio parted && /initer/init.sh image device'


docker commit --change='CMD apt update && apt install -y cpio parted' -m 'modify' 000ca6126669 epc/initier:0.1
