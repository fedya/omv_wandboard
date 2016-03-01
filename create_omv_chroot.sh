#!/bin/bash
flash_disk=/dev/"$@"

kernel_version=4.4.3-armv7-x5
# sha's for kernel stuff
KERNEL_SHA="fd1ddda8edab80663c5bca51697579fc412368b0"
UBOOT_SHA="3a7ab78fab5bb0f48d6d074f55551a10f1df39b1"
SPL_SHA="8f40939dfe0c82010fdb81181b5c016e0b552e56"
MODULES_SHA="00f0c79841b4cd24e538c7af0767ab76557b83af"
FIRMWARE_SHA="278da9b4bd44b96dd6a891392fddd9a56b7f6e63"
DTBS_SHA="19fd8fc557b13707b5cf39eeea6a0708f8691a20"
OMV_IMAGE_SHA="057042837fd0f47220b04cae27e4cecdf96f6353"
mirror="http://file-store.openmandriva.org/download/"

# Setting up path
PATH="$PATH:/usr/bin:/usr/sbin"

clear_disk () {
	echo "Wipe first 10Mb of $flash_disk"
	sudo dd if=/dev/zero of=$flash_disk bs=1M count=10 > /dev/null 2>&1
	echo "DONE"
	}

burn_uboot () {
	echo "Install u-boot/SPL"
	sudo dd if=SPL of=$flash_disk seek=1 bs=1k > /dev/null 2>&1
	sudo dd if=u-boot.img of=$flash_disk seek=69 bs=1k > /dev/null 2>&1
	echo "DONE"
	sleep 2
	sync
	}
                                                                                                                                                                                                                   
flash_partitions () {                                                                                                                                                                                                     
        echo "Partitioning"                                                                                                                                                                                        
	sudo sfdisk --in-order --Linux --unit M $flash_disk > /dev/null 2>&1 <<-__EOF__
	1,,0x83,*
	__EOF__
        echo "DONE"
	sync
        }

create_fs () {
	sleep 2
	echo "Creating ext4 filesystem in $flash_disk'1'"
	sudo mkfs.ext4 $flash_disk"1" -L rootfs > /dev/null 2>&1
	echo "DONE"
	sync
	}

download_env () {
	sleep 2
	echo "Prepare minimal system"
	if [ ! -f omv_armvhl_minimal.tar.xz ]
	then
	# uncomment me if you want MINIMAL image
	curl -L http://file-store.rosalinux.ru/api/v1/file_stores/$OMV_IMAGE_SHA -o omv_armvhl_minimal.tar.xz
	# KDE4.13 image
	#curl -L http://file-store.rosalinux.ru/api/v1/file_stores/ef91c739fee59b434dadbcaf4d343d8f9b7fc1a9 -o omv_armvhl_minimal.tar.xz
	fi
	echo "Prepare kernel stuff (modules, firmwares, etc)"
	if [ ! -f ${kernel_version}.zImage ]
	then
	curl -L $mirror/$KERNEL_SHA -o ${kernel_version}.zImage
	fi
	if [ ! -f u-boot.imx ]
	then
	curl -L $mirror/$UBOOT_SHA -o u-boot.img
	fi
	if [ ! -f SPL ]
	then
	curl -L $mirror/$SPL_SHA -o SPL
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
	if [ ! -e brcmfmac4329-sdio.bin ] && [ ! -e brcmfmac4330-sdio.bin ] && [ ! -e brcmfmac4329-sdio.txt ] && [ ! -e brcmfmac4320-sdio.txt ]
	then
	curl -L -O https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/plain/brcm/brcmfmac4329-sdio.bin
	curl -L -O https://git.kernel.org/cgit/linux/kernel/git/firmware/linux-firmware.git/plain/brcm/brcmfmac4330-sdio.bin
	curl -L -O https://raw.githubusercontent.com/Freescale/meta-fsl-arm-extra/master/recipes-bsp/broadcom-nvram-config/files/wandboard/brcmfmac4329-sdio.txt
	curl -L -O https://raw.githubusercontent.com/Freescale/meta-fsl-arm-extra/master/recipes-bsp/broadcom-nvram-config/files/wandboard/brcmfmac4330-sdio.txt
	fi
	echo "Done"
	}

extract_env () {
	sudo mkdir -p /media/rootfs/
	sudo mount $flash_disk"1" /media/rootfs/
	sudo bsdtar -xf omv_armvhl_minimal.tar.xz -C /media/rootfs/
	sync
	sudo sh -c "echo 'uname_r=${kernel_version}' > /media/rootfs/boot/uEnv.txt"
	echo "set video mode"
	sudo sh -c "echo 'cmdline=video=HDMI-A-1:1024x768@60e' >> /media/rootfs/boot/uEnv.txt"
	echo "copy kernel image"
	sudo cp -v ${kernel_version}.zImage /media/rootfs/boot/vmlinuz-${kernel_version}
	echo "copy device tree binaries"
	sudo mkdir -p /media/rootfs/boot/dtbs/${kernel_version}/
	sync
	sudo tar -xf ${kernel_version}-dtbs.tar.gz -C /media/rootfs/boot/dtbs/${kernel_version}/
	echo "copy modules"
	sudo tar -xf ${kernel_version}-modules.tar.gz -C /media/rootfs/
	sync
	echo "make root partition writable on the board"
	sudo sh -c "echo '/dev/root  /  auto  errors=remount-ro  0  1' >> /media/rootfs/etc/fstab"
	echo "Set up WiFi"
	sudo mkdir -p /media/rootfs/lib/firmware/brcm/
	sudo cp -v ./brcmfmac43*-sdio.bin /media/rootfs/lib/firmware/brcm/
	sudo cp -v ./brcmfmac43*-sdio.txt /media/rootfs/lib/firmware/brcm/
	sudo tar -xf ${kernel_version}-firmware.tar.gz /media/rootfs/lib/firmware/
	echo "unmount $flash_disk"
	sudo umount /media/rootfs
	sync
	echo "Default name:password"
	echo "root:root"
	echo "omv:omv"
	}

download_env
clear_disk
burn_uboot
flash_partitions
create_fs
extract_env
