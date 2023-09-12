#!/bin/bash

if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    echo "Hey, you should source this script, not execute it!"
    exit 1
fi

checkRC() {
  op=${2}
  rc=${1}

  if [ ${rc} -eq 0 ]; then
    echo "operation ${op} went OK"
    return 0
  else
    echo "operation ${op} finished with non-zero RC: ${rc}"
    exit 11
    return 1
  fi
}

isnotdirectory() {
  if [ -d "$1" ]; then
    return 1 #aka False
  else
    return 0 #aka True
  fi
}

ismounted() {
  if grep -qs "$1" /proc/mounts; then
    return 0 #aka True
  else
    return 1 #aka False
  fi
}

isnotmounted() {
  if grep -qs "$1" /proc/mounts; then
    return 1 #aka False
  else
    return 0 #aka True
  fi
}

check_if_mounted_umount_when_requested() {

  if ismounted ${backup_mount}; then
    echo "INFO: ${backup_mount} is mounted."
    if ${UMOUNT}; then
      umount ${backup_mount}
      if ismounted ${backup_mount}; then
        echo "ERROR: umount failed"
        exit 1
      fi
      echo "Argument \"-u/--umount\" specified, so ending here.."
      exit 0
    fi

    if ${IGNOREMOUNT}; then
      echo "INFO: --ignoremount option used so lets continue to backup."
      return 0
    else
      echo "${backup_mount} is mounted."
      echo "ERROR: That can mean something strange. Stopping backup procedure"
      echo "ERROR: if this was intentional, use \"-i\" switch"
      exit 1
    fi
  else
    if ${UMOUNT}; then
      echo "ERROR: mount ${backup_mount} is not mounted and umount requested. Nothing to do."
      exit 1
    fi
    echo "INFO: ${backup_mount} not mounted, correct, continue."
    return 0
  fi
}
