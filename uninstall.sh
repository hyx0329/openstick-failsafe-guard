#!/bin/sh

# shellcheck disable=SC2010
for i in $(ls -1  /etc/systemd/system/ | grep openstick ) ; do systemctl disable "$i"; done

rm /etc/systemd/system/openstick-*
#rm /etc/systemd/system/adbd.service
rm /usr/sbin/openstick-*

