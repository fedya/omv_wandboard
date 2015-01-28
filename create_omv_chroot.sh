#!/bin/bash
#set -x
# Disks to check
#disks="
#/dev/sda
#/dev/sdb"

#disks=$(for dev in $( grep -Hv '^0$' /sys/block/s*/removable | sed 's/removable:.*$/device\/uevent/' | xargs grep -H '^DRIVER=sd' |
#       sed 's/device.uevent.*$/size/' | xargs grep -Hv '^0$' | cut -d / -f 4;) ;do echo "$dev";done)

# remove me for autodect
#flash_disk=`grep -Hv '^0$' /sys/block/s*/removable | sed 's/removable:.*$/device\/uevent/' | xargs grep -H '^DRIVER=sd' |
#        sed 's/device.uevent.*$/size/' | xargs grep -Hv '^0$' | cut -d / -f 4`

flash_disk=/dev/"$@"
kernel_version=3.17.4-armv7-x3

# Setting up path
PATH="$PATH:/usr/bin:/usr/sbin"

clear_disk () {
	echo "Wipe fisr 10Mb of $flash_disk"
	sudo dd if=/dev/zero of=$flash_disk bs=1M count=10 > /dev/null 2>&1
	echo "DONE"
	}

burn_uboot () {
	echo "Install u-boot"
	sudo dd if=u-boot.imx of=$flash_disk seek=1 conv=fsync bs=1k > /dev/null 2>&1
	echo "DONE"
	sleep 2
	sync
	}
                                                                                                                                                                                                                   
flash_partitions () {                                                                                                                                                                                                     
        echo "Partitioning"                                                                                                                                                                                        
	sudo sfdisk --in-order --Linux --unit M $flash_disk > /dev/null 2>&1 <<-__EOF__
	1,,0x83,-
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

# download prebuilt chroot env
download_env () {
	sleep 2
	echo "Prepare minimal system"
	if [ ! -f omv_armvhl_minimal.tar.xz ]
	then
	curl -L http://file-store.rosalinux.ru/api/v1/file_stores/057042837fd0f47220b04cae27e4cecdf96f6353 -o omv_armvhl_minimal.tar.xz
	fi
	echo "Prepare kernel stuff (modules, firmwares, etc)"
	if [ ! -f ${kernel_version}.zImage ]
	then
	curl -L http://file-store.rosalinux.ru/download/0ab4eca78684e6e4bb984853a40e92cc2efbe8f2 -o ${kernel_version}.zImage
	fi
	if [ ! -f u-boot.imx ]
	then
	curl -L http://file-store.rosalinux.ru/download/2e99e48894a7d9707331c2e17e612de0c40f9f43 -o u-boot.imx
	fi
	if [ ! -f ${kernel_version}-modules.tar.gz ]
	then
	curl -L http://file-store.rosalinux.ru/download/971166023873486bc257ec994111dd317a58f9cf  -o ${kernel_version}-modules.tar.gz
	fi
	if [ ! -f ${kernel_version}-firmware.tar.gz ]
	then
	curl -L http://file-store.rosalinux.ru/download/284688fdfb89a0861e954a998ed8db9d7a03189f  -o ${kernel_version}-firmware.tar.gz
	fi
	if [ ! -f ${kernel_version}-dtbs.tar.gz ]
	then
	curl -L http://file-store.rosalinux.ru/download/9d70a362c4b74f829b053f01622b31b4edde20a5  -o ${kernel_version}-dtbs.tar.gz
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
	# Wandboard Quad (Original)
	# sudo sh -c "echo 'dtb=imx6q-wandboard-revb1.dtb' >> /media/rootfs/boot/uEnv.txt"
	# Wandboard Quad (new C1)
	echo "set device tree binary"
	sudo sh -c "echo 'dtb=imx6q-wandboard.dtb' >> /media/rootfs/boot/uEnv.txt"
	# Wandboard Dual/Solo (Original)
	# sudo sh -c "echo 'dtb=imx6dl-wandboard-revb1.dtb' >> /media/rootfs/boot/uEnv.txt"
	# Wandboard Dual/Solo (new C1)
	# sudo sh -c "echo 'dtb=imx6dl-wandboard.dtb' >> /media/rootfs/boot/uEnv.txt"
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
	sudo sh -c "echo '/dev/mmcblk0p1  /  auto  errors=remount-ro  0  1' >> /media/rootfs/etc/fstab"
	echo "Set up WiFi"
	sudo mkdir -p /media/rootfs/lib/firmware/brcm/
	sudo cp -v ./brcmfmac43*-sdio.bin /media/rootfs/lib/firmware/brcm/
	sudo cp -v ./brcmfmac43*-sdio.txt /media/rootfs/lib/firmware/brcm/
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
