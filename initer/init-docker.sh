#!/bin/bash

set -e

IMAGE="uiob-tools/initer"

create_image() {
	if [[ -z $(docker image ls | grep $IMAGE) ]]; then
		echo -e "\033[32m Initial creation of the environment  \033[0m"
		docker run --name initer -tid debian:bullseye-slim bash
		docker exec initer /bin/bash -c "apt update && apt install -y cpio parted fdisk"
		docker commit initer $IMAGE
		docker stop initer && docker rm initer
	fi
}

init_sh() {
	echo -e "\033[32m Create UROS filesystem for $DEVICE \033[0m"
	docker run --rm -v $PWD:/initer/ -v $PATH_SWU:$PATH_SWU --device=$DEVICE -ti $IMAGE /bin/sh -c "./initer/init.sh $PATH_SWU $DEVICE"
}

help() {
	echo -e "\033[32m Docker environment for work with init.sh \033[0m"
	echo -e "\033[32m Help page: ./init-docker.sh help \033[0m"
	echo -e "\033[32m Usage: ./init-docker.sh <file>.swa /dev/sdX \033[0m"
	echo -e "\033[32m Show device list: lsblk \033[0m"
	echo -e "\033[31m Device filesystem will be completely overwritten! \033[0m"
}

parse_opts() {
	if [[ "$#" == "1" ]] && [[ "$1" == "help" ]]; then
		help
		exit 0
	 
	elif [[ "$#" != "2" ]]; then
		echo -e "\033[31m Invalid arguments \033[0m"
		help
		exit 1
	else
		create_image
		PATH_SWU="$1"
#		SWU=$(echo "$1" | awk -F '/' '{print $NF}')
		DEVICE="$2"
		init_sh
	fi
}

parse_opts $*
