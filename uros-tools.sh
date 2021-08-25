#!/bin/bash

set -e

IMAGE="uros-tools"

check_image() {
	if [[ -z $(docker image ls | grep $IMAGE) ]]; then
		echo -e "\033[33m Initial creation of the environment \033[0m"
		docker build --no-cache -t $IMAGE . 
	fi
}

initer() {
	check_image
	echo "$1"
	echo "$*"
	docker run --rm --privileged -v $PWD/"$1":$PWD/"$1" --device="$2" -ti $IMAGE /bin/bash -c "./initer/init.sh $*"
}

snapshoter() {
	check_image
	docker run --rm --privileged -v $PWD/snapshoter:/uros-tools/snapshoter --device="$2" -ti $IMAGE /bin/bash -c "python3 snapshoter/snapshoter.py $*"
}

flashrom() {
	check_image
	docker run --rm --privileged -ti $IMAGE /bin/bash -c "./flashrom/flashrom -p ft2232_spi:type=arm-usb-tiny,port=A,divisor=8 -w "${!#}""
	echo -e "test flashrom is here"
}

help() {
	echo -e "\033[33m ### UROS-TOOLS WITH DOCKER ENVIRONMENT ### \033[0m"
	echo -e "\033[32m Create working UROS storage from .swu in current folder:\033[0m ./uros-tools.sh initer /path/to/<file>.swu"
	echo -e "\033[32m Create .swu from UROS storage: \033[0m ./uros-tools.sh snapshoter -p <partition> -b <boot file> -s <update version> -n <name_version>"
	echo -e "\033[32m Flash .rom to your board: \033[0m ./uros-tools.sh flashrom ЧИТАЙ"
	echo -e "\033[32m Show this help page: \033[0m ./uros-tools.sh help"
	echo -e "\033[33m ########################################### \033[0m"
}

parse_opts() { 
	case "$1" in

		"initer")
			shift
			initer $*
			;;

		"snapshoter")
			shift
			snapshoter $*
			;;

		"flashrom")
			shift
			flashrom $*
			;;

		"help")
			help
			;;

		*)
			echo -e "\n \033[31m Choose tool. See ./uros-tools.sh help \033[0m"
			exit 1
			;;
			
	esac
}

parse_opts $*
