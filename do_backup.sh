#!/bin/bash

echo "start of script"

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"   #gets the script directory
scriptname="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"  # gets the name of the script itself

source "${scriptdir}/backup.conf"
source "${scriptdir}/secrets"
source "${scriptdir}/libs/common.sh"
source "${scriptdir}/libs/argparsing.sh"

# check if mountpoint is present:

if isnotdirectory ${backup_mount}; then
  echo "ERROR: \"${backup_mount}\" mountpoint is missing"
  exit 1
fi

# check if the mount is not mounted already..:

check_if_mounted_umount_when_requested

# do the mount:

sshfs -o 'reconnect,allow_other,idmap=user,uid=0,gid=0,cache=no,noauto_cache,entry_timeout=0'  ${ssh_host}:${target_path} ${backup_mount}
checkRC $? "Mount ${backup_mount}" || exit 1

if isnotmounted ${backup_mount}; then
  echo "ERROR: mount of ${backup_mount} failed."
  exit 1
fi

if ${MOUNTONLY}; then
  echo "Argument \"-m/--mountonly\" specified, so ending here.."
  exit 0
fi

# check if the repo is there..

if isnotdirectory ${backup_repo_path}; then
  echo "Backup repo path ${backup_repo_path} is missing. EXIT"
  exit 1
fi

if ${OSONLY} || ${PRUNEONLY}; then
  echo "NOTE: -o/--osonly or -p/--pruneonly flag used, we'll skip data backup."
else

# * * * backup HOME * * *
# iterate over files in /home/users

homedirs=$(ls -1t ${home_path}/ | xargs )

for directory in ${homedirs}; do

  directory="${home_path}/${directory}"

  echo "processing: $directory"

  # check if $directory is really directory
  if isnotdirectory ${directory}; then
    echo "${directory} is not directory, skipping.."
    continue
  fi

  # get just the directory name = strip the path off
  subdir=$(basename $directory)
  archive_prefix="home_users_${subdir}"

  ignore_users="nopenobody"
  if [[ "$ignore_users" =~ .*"$subdir".* ]]; then
    echo "subdir is in ignore_users. continue with next one."
    sleep 1
    continue
  fi

  # backup the dir..:

  borg_cmd="borg create \
    --numeric-ids \
    --stats \
    --one-file-system \
    --show-rc \
    --exclude-caches \
    --compression zstd,5 \
    --exclude '/home/*/.cache/*' \
    --exclude '/home/*/Downloads/*' \
    --exclude '/home/*/temp/*' \
    --exclude '/home/*/tmp/*' \
    --exclude '*.pyc' \
    --exclude '._.DS_Store' \
    --exclude '.DS_Store' \
    --exclude '/home/*/mnt_LSSTdata' \
    ${backup_repo_path}::"${archive_prefix}-{now}" ${directory}"

  borg_cmd=$(echo "${borg_cmd}" | tr -s ' ')

  echo -e "executing $borg_cmd"
  eval $borg_cmd
  rc=$?

  if [ ${rc} -eq 0 ]; then
    echo "operation on ${directory} went OK"
  else
    echo "operation on ${directory} finished with non-zero RC: ${rc}"
  fi

done

fi  # end of "osonly"/"pruneonly" skip-block..

if ${PRUNEONLY}; then
  echo "NOTE: -p/--pruneonly flag used, we'll skip sys data backup."
else
  # * * * /etc -> sys_repo * * *

directory="/etc"
archive_prefix="etc"

borg_cmd="borg create \
  --numeric-ids \
  --stats \
  --one-file-system \
  --show-rc \
  --exclude-caches \
  --compression zstd,5 \
  ${sys_repo_path}::"${archive_prefix}-{now}" ${directory}"

borg_cmd=$(echo "${borg_cmd}" | tr -s ' ')
echo -e "executing $borg_cmd"
eval $borg_cmd
checkRC $? "Backup of ${directory}"

# * * * postgres -> sys_repo * * *

archive_prefix="postgres"

rm -f /tmp/dumpall.sql

orig_umask=$(grep -e "^UMASK" /etc/login.defs | awk '{print $2}')
umask 077
echo "INFO: dumping postgres"
pg_dumpall -f /tmp/dumpall.sql

umask $orig_umask

borg_cmd="borg create \
  --numeric-ids \
  --stats \
  --one-file-system \
  --show-rc \
  --exclude-caches \
  --compression zstd,5 \
  ${sys_repo_path}::"${archive_prefix}-{now}" /tmp/dumpall.sql"

borg_cmd=$(echo "${borg_cmd}" | tr -s ' ')
echo -e "executing $borg_cmd"
eval $borg_cmd
checkRC $? "Backup of postgresql"

rm -f /tmp/dumpall.sql
rm -f /tmp/dumpall.sql

# * * * /root -> sys_repo * * *

directory="/root"
archive_prefix="root"

borg_cmd="borg create \
  --numeric-ids \
  --stats \
  --one-file-system \
  --show-rc \
  --exclude-caches \
  --compression zstd,5 \
  ${sys_repo_path}::"${archive_prefix}-{now}" ${directory}"

borg_cmd=$(echo "${borg_cmd}" | tr -s ' ')
echo -e "executing $borg_cmd"
eval $borg_cmd
checkRC $? "Backup of ${directory}"

fi  # end of sys / pruneonly skip-block

# ---------------------------------------------------------------------------
# * enforce rentention policy @sys repo:

archive_prefixes=$(borg list ${sys_repo_path} | cut -d '-' -f 1 | sort | uniq)

for prefix in ${archive_prefixes}; do
  echo "processing $prefix.."
  borg prune --show-rc --list --keep-daily=${backup_retention_daily} --keep-weekly=${backup_retention_weekly} --keep-monthly=${backup_retention_monthly} --prefix="${prefix}-" ${sys_repo_path}
done

# * enforce retention policy @home repo:

archive_prefixes=$(borg list ${backup_repo_path} | cut -d '-' -f 1 | sort | uniq)

for prefix in ${archive_prefixes}; do
  echo "processing $prefix.."
  borg prune --show-rc --list --keep-daily=${backup_retention_daily} --keep-weekly=${backup_retention_weekly} --keep-monthly=${backup_retention_monthly} --prefix="${prefix}-" ${backup_repo_path}
done

# ---------------------------------------------------------------------------
# * compact repositories

borg compact ${sys_repo_path}
borg compact ${backup_repo_path}


# umount the remote sshfs
umount ${backup_mount}

echo "INFO: umount done, script done."
