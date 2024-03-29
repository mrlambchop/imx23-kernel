#!/bin/sh
################################################################################
# This script is meant to be run as the "init" script of an initramfs, which
# should be a writable filesystem (tmpfs or ramfs, tmpfs preferred).
#
# DO NOT ATTEMT TO RUN THIS IN AN INITRD (ramdisk) without modification
#
################################################################################

export PATH="/bin:/sbin:/usr/bin:/usr/sbin"

# Path to directory to mount $ROOTDEV under in initrd
NEWROOT="/newroot"

# Commands used in this initrd script
# Hardcode busybox to ensure availability of commands when /proc isn't
# mounted or symlinks aren't made yet
BBINSTALL="/bin/busybox --install -s"
CAT="/bin/busybox cat"
CHMOD="/bin/busybox chmod"
MOUNT="/bin/busybox mount"
UMOUNT="/bin/busybox umount"
SHELL="/bin/busybox setsid cttyhack sh"
MKDIR="/bin/busybox mkdir"
GREP="/bin/busybox grep"
AWK="/bin/busybox awk"
SWITCH="/bin/busybox switch_root"

# mdev (busybox symlinks should be usable when using this)
MDEV="/sbin/mdev"

#make the basic directories
$MKDIR -p /usr
$MKDIR -p /usr/bin
$MKDIR -p /usr/sbin

# Kernel command-line (convenience variable)
KCMD="/proc/cmdline"


#Wifi function
wifi () {
        echo ''
        echo 'Launching linksys WiFi'
        sleep 2
        echo 'Bringing up interface and assocate to linksys'
        ifconfig wlan0 up
        sleep 1
        iwconfig wlan0 essid linksys
        sleep 5
        udhcpc -p /var/run/udhcpc.pid -i wlan0 -b -s /etc/udhcpc/default.script
}

# Function for dropping to a shell
shell () {
        echo ''
        echo '  Entering rescue shell.'
        echo '  Type rootdev root_device to set device to boot.'
        echo '     ex: rootdev /dev/sda1'
        echo '  Exit shell to continue booting.'
        echo '  STARTING WIFI'
        wifi
        $SHELL
}


# Create rootdev function
echo '#!/bin/sh' > /bin/rootdev
echo 'echo "$1" > /rootdev' >> /bin/rootdev
echo 'exit $?' >> /bin/rootdev
$CHMOD 0755 /bin/rootdev
RDEV="/bin/rootdev"


# EXECUTION BEGINS HERE
echo "Entering initramfs"

# install all busybox symlinks before doing anything else
# /proc still needs to be mounted before the symlinks will work
echo "Creating busybox symlinks"
$BBINSTALL

#dropbear hack
ln -s /bin/dropbearmulti /bin/dropbear
ln -s /bin/dropbearmulti /bin/dropbearkey
ln -s /bin/dropbearmulti /bin/scp
ln -s /bin/dropbearmulti /bin/dbclient
ln -s /bin/dropbearmulti /bin/ssh

# Ensure that basic directories exist
for dir in /proc /sys /dev
do
        [ -d $dir ] || $MKDIR $dir
done

# Mount /proc, necessary for other mounts
echo "Mounting procfs"
$MOUNT -t proc proc /proc

# Mount /sys, necessary to create the device mapper control device
echo "Mounting sysfs"
$MOUNT -t sysfs sys /sys

# Mount tmpfs on /dev and set up /dev/pts
echo "Mounting tmpfs on /dev and running mdev ..."
$MOUNT -t tmpfs dev /dev
$MKDIR -p /dev/pts
$MOUNT -t devpts devpts /dev/pts
# Run mdev and populate /dev with device nodes
echo "$MDEV" > /proc/sys/kernel/hotplug
$MDEV -s

# Drop to shell if "shell" was passed as kernel param
$GREP -q 'shell' /proc/cmdline && shell

# Get the args to pass to init, minus key=val pairs
INIT_ARGS="$($AWK '{gsub(/[[:graph:]]+=[[:graph:]]+/,""); print}' $KCMD)"
# remove any initramfs commands from INIT_ARGS
INIT_ARGS="$(echo $INIT_ARGS | $AWK '{gsub(/noresume/,""); print}')"
INIT_ARGS="$(echo $INIT_ARGS | $AWK '{gsub(/shell/,""); print}')"

# Init to run after switch_root to real system
INIT="$($AWK '/.*init=/ {sub(/.*init=/,""); sub(/[ ].*/,""); print}' $KCMD)"
INIT="${INIT:-/sbin/init}"

# Get the default root device if it exists on the kernel command-line
RTDEV="$($AWK '/root=/ {sub(/.*root=/,""); sub(/[ ].*/,""); print}' $KCMD)"

# check if /rootdev is empty or missing
if [ ! -s /rootdev ]
then
        # Get root dev from kernel boot command-line
        # uses some awk magic to extract first "root=.*",
        # then extracts the ".*" from within that
        $RDEV "$RTDEV" || echo "Failed to make /rootdev"
fi

# Check if ROOTDEV is a number (major and minor)
if [ ! $($GREP -q '^/dev/.*' /rootdev) ]
then
        # get the major number (first digit only)
        MAJOR="$($AWK '{ print substr($0,1,1) }' /rootdev)"

        # get the minor number (everything after the first digit)
        MINOR="$($AWK '{ print substr($0,2) }' /rootdev)"
        # make sure the minor number doesn't have leading 0's
        MINOR="$(echo $MINOR | $AWK '{ sub(/^0+/,"",$0); print $0 }')"

        # get the /dev node name using the major and minor numbers by
        # looking it up in /proc/diskstats
        DISKS="/proc/diskstats"
        BOOT="$($AWK '$1 ~'$MAJOR' && $2 ~'$MINOR' { print $3 }' $DISKS)"
        $RDEV "/dev/$BOOT"
fi

# Mount the root partition
# ensure that the directory we mount to exists
SUCCESS=0
[ -d "$NEWROOT" ] || $MKDIR "$NEWROOT"
while [ $SUCCESS -ne 1 ]
do
        ROOTDEV="$($CAT /rootdev)"
        if ! $MOUNT -o ro "$ROOTDEV" "$NEWROOT"
        then
                echo ""
                echo "Couldn't mount root FS read-only!"
                echo "Tell me your root device by doing:"
                echo "rootdev YOUR_ROOT_DEVICE"
                shell
        else
                SUCCESS=1
        fi
done

if [ ! -e "$NEWROOT/$INIT" ]
then
        echo ""
        echo "$ROOTDEV successfully mounted but no $INIT found!"
        shell
fi

# Reset kernel hotplugging
echo "Resetting kernel hotplugging"
echo "" > /proc/sys/kernel/hotplug

# Umount /sys
echo "Unmounting /sys"
$UMOUNT /sys

# Umount /dev tree
echo "Unmounting /dev"
$UMOUNT /dev/pts &&
$UMOUNT /dev

# Umount /proc
echo "Unmounting /proc"
$UMOUNT /proc

# Change to the new root partition and execute /sbin/init
echo "Executing switch_root and spawning init"
if ! exec $SWITCH "$NEWROOT" "$INIT" $INIT_ARGS
#if ! exec $SWITCH "$NEWROOT" "$INIT" "$@"
then
        echo ""
        echo "Couldn't switch_root"
        $MOUNT -t proc proc /proc
        exec $SHELL
fi
