#/bin/sh

if test -z $1
then
   echo "Missing firmware name! Options are rtl or linksys"
   exit 0
else
   if [ $1 == "rtl" ]
   then
      echo "Selecting RTL"
      export FIRMWARE="rtlwifi/rtl8192cufw/bin"
   elif [ $1 == "linksys" ]
   then
      echo "Selecting linksys"
      export FIRMWARE="isl3886usb"
   else
      echo Unknown value $1 - Options are rtl or linksys
      exit 0
   fi
fi

if [ $# == 2 ]
then
   echo Setting firmware class as $2
   export USB_NAME=$2
else
  echo "Missing name for firmware class! Assuming 1-1.2"
  export USB_NAME="1-1.2"
fi

#export | less

echo Loading to /sys/class/firmware/$USB_NAME/
echo Firmware from /lib/firmware/$FIRMWARE
echo 1 > /sys/class/firmware/$USB_NAME/loading
cat /lib/firmware/$FIRMWARE > /sys/class/firmware/$USB_NAME/data
echo 0 > /sys/class/firmware/$USB_NAME/loading
echo "Done"
