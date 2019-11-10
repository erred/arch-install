#!/usr/bin/env bash

set -euxo pipefail

sudo apt install -y squashfs-tools
sudo curl -LO http://mirror.rackspace.com/archlinux/iso/latest/arch/x86_64/airootfs.sfs
sudo unsquashfs airootfs.sfs
sudo mount -o bind squashfs-root squashfs-root
sudo mount -t proc none squashfs-root/proc
sudo mount -t sysfs none squashfs-root/sys
sudo mount -o bind /dev squashfs-root/dev
sudo mount -o bind /dev/pts squashfs-root/dev/pts
sudo mount -o bind squashfs-root/mnt squashfs-root/mnt
sudo cp -L /etc/resolv.conf squashfs-root/etc
sudo cp setup.sh squashfs-root
