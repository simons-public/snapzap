#!/usr/bin/env bash
#
# create testpool
#

DEVICES=(vda vdb vdc vdd)

mkdir testpool

for i in ${DEVICES[@]}; do
    truncate -s 1G testpool/$i.raw
done

find $PWD/testpool/*.raw |\
    xargs zpool create -o ashift=12 testpool raidz2

zpool list
