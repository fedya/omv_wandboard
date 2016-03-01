#!/bin/bash
# RUN this script on Wandboard when you want update kernel
# root

source ./create_omv_chroot.sh
mirror="http://file-store.openmandriva.org/download/"

download_env () {
        echo "Prepare kernel stuff (modules, firmwares, etc)"
        if [ ! -f ${kernel_version}.zImage ]
        then
        curl -L $mirror/$KERNEL_SHA -o ${kernel_version}.zImage
        fi
        if [ ! -f ${kernel_version}-modules.tar.gz ]
        then
        curl -L $mirror/$MODULES_SHA  -o ${kernel_version}-modules.tar.gz
        fi
        if [ ! -f ${kernel_version}-firmware.tar.gz ]
        then
        curl -L $mirror/$FIRMWARE_SHA  -o ${kernel_version}-firmware.tar.gz
        fi
        if [ ! -f ${kernel_version}-dtbs.tar.gz ]
        then
        curl -L $mirror/$DTBS_SHA  -o ${kernel_version}-dtbs.tar.gz
        fi
        echo "Done"
        }

download_env

# dtbs, modules, firmwares
mkdir -p /boot/dtbs/${kernel_version}/
tar -xf ${kernel_version}-dtbs.tar.gz -C /boot/dtbs/${kernel_version}/
tar -xf ${kernel_version}-modules.tar.gz -C /
tar -xf ${kernel_version}-firmware.tar.gz -C /lib/firmware
# kernel
cp -v ${kernel_version}.zImage /boot/vmlinuz-${kernel_version}
sh -c "echo 'uname_r=${kernel_version}' > /boot/uEnv.txt"
