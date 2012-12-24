#/bin/sh

if test -n $1
then
   $NAME = $1
else
  echo "Missing name for firmware class! Assuming 1-1.2"
fi

echo "Loading to /sys/class/firmware/$1/"
echo 1 > /sys/class/firmware/$1/loading
cat /lib/firmware/rtlwifi/rtl8192cufw.bin > /sys/class/firmware/$1/data
echo 0 > /sys/class/firmware/$1/loading
echo "Done"

sleep 1

echo "wlan up!"
ifconfig wlan0 up
