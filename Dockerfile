#FROM debian:bullseye-slim
FROM python:3.8.11-slim-bullseye

COPY snapshoter/requirements.txt /uros-tools/snapshoter/requirements.txt
WORKDIR /uros-tools

#initer
RUN apt update && apt install -y udev cpio parted fdisk mtools dosfstools

#snapshoter
RUN apt update && apt install -y python3-pip
RUN pip install --upgrade pip && pip install -r snapshoter/requirements.txt

#flashrom
RUN apt update && apt install -y libpci3 libftdi1
