#!/bin/sh

get_root_mount_block() {
  awk '{if ( $2 == "/" ) { print $1, $3; exit; }}' /proc/mounts
}

main() {
  # I'm a posix standard script!
  # shellcheck disable=SC2046
  set -- $(get_root_mount_block)
  BLOCK="$1"
  FSTYPE="$2"

  if [ "ext3" != "$FSTYPE" ] && [ "ext4" != "$FSTYPE" ] ; then
    logger "The rootfs is not on a ext3/ext4 partition, please manually resize the partition."
    return
  fi

  logger "Resizeing root block $BLOCK($FSTYPE)"
  resize2fs "$BLOCK"
}

main

