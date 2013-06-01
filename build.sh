#!/bin/sh
rm usr/*.bz2 usr/*.o
make ARCH=arm zImage modules -j4
cat arch/arm/boot/zImage arch/arm/boot/imx23-olinuxino.dtb > arch/arm/boot/zImage_dtb
echo "Done"
ls -alh arch/arm/boot/Image
ls -alh usr/initramfs_data.cpio.bz2
