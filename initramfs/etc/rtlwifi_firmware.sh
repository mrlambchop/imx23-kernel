#!/bin/sh

load_firmware() {
	if [ ! -e /lib/firmware/$FIRMWARE ]; then
		echo $FIRMWARE not found >/dev/console
		return
	fi
	echo Loading $FIRMWARE into $DEVPATH >/dev/console
	mount -t sysfs sysfs /sys
	echo 1 > /sys/$DEVPATH/loading
	cat /firmware/$FIRMWARE > /sys/$DEVPATH/data
	echo 0 > /sys/$DEVPATH/loading
	umount /sys
}

case $ACTION in
	add)
		case "$FIRMWARE" in
			"") ;;
			*) load_firmware ;;
		esac
	;;
esac
