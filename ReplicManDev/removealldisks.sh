#!/bin/bash
exclude=$(cut -d/ -f3 LocalDisks.txt)

for sysfile in /sys/block/sd* ; do

dev=$(basename $sysfile)
del=$sysfile/device/delete

if [[ $exclude == *$dev* ]] ; then
    echo "Device $dev excluded"

elif [ ! -w $del ] ; then
    echo "$del does not exist or is not writable"

else
    echo 1 > $del
fi

done
