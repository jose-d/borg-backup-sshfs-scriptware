# borg-backup-sshfs-scriptware

Scripting around borg backup and sshfs 

## I. About this scriptware (general info)

This backup script was developed with the idea being executed by external scheduler, eg. cron. As more modern approaches are available today, this script is not actively used nor developed.

Main compoments:

- `libs/*.sh` - common functions used by main script
- `backup.conf` - customization of backup policies
- `do_backup.sh` - main script
- `secrets` - plaintext file containing borg password - eg.: ```export BORG_PASSPHRASE='*redactedPassword*'```

### high-level backup workflow description

1. script checks if sshfs is already mounted. If yes, we end here.
2. remote backup repo is mounted using sshfs, mount is checked for borg repo directory
3. borg backup of home directories is performed into _backup_repo_path_
4. borg backup of /etc dir is done into _sys_repo_path_
5. local postgres is dumped with pg_dumpall, this dump is backed up into _sys_repo_path_ and finally removed
6. borg backup of /root dir is done into _sys_repo_path_
7. borg prune is executed on both repositories
8. borg compact is executed on both repositories
9. sshfs mount is unmounted

### CLI switches:

 * `-o`,`--osonly` - backup only system part
 * `-d`,`--debug` - show more info
 * `-u`,`--umount` - umounts (if mounted) ssfs mount (possibly previously mounted with `-m`. No backup is performed.
 * `-m`,`--mountonly` - mounts sshfs mount only. No backup is performed.
 * `-i`,`--ignoremount` - proceeds with backup in case the mount is already mounted, eg. in case of script development
 * `-v`,`--verbose` - show more info
 * `-s`,`--skipcheck` - skip repository check at the end of procedure
 * `-p`,`--pruneonly` - only perform repository prune. No backup is performed.

### dependencies

* borgbackup, sshfs - at recent debian avaiable from standard repositories..

## II. usage tips

Before any borg action, source secrets: `source secrets` to have BORG_PASSWORD in environment.

Usually `./do_backup.sh -m` is needed before any borg-related action to ensure the repository is available (= mounted via sshfs).

At the end of session, do `./do_backup.sh -u` to ensure mountpoint is cleanly unmounted and is not possibly blocking regular backups.

### RESTORE howto

Most useful usecase I.M.O :).

Task definition: we want to restore `authorized_keys` file of user 'eve'.

1. `./do_backup.sh -m` to mount remote sshfs
2. `source secrets` - to have BORG_PASSWORD in environment
3. `borg list /mnt/mp/repopath | grep eve` - to see archives containing username `eve` - gives us:

```
root@host:~/backup# borg list /mnt/mp/repopath | grep eve
home_users_eve-2022-06-14T18:47:37  Tue, 2022-06-14 18:47:39 [426a9423b744a8c09169d07ba0e833f3fdb1d6729c99a33ecca0ee042bff1cb1]
home_users_eve-2022-06-14T21:05:03  Tue, 2022-06-14 21:05:05 [cb9cb7ed46665666f3594466910fc26aacfd064546f63225c42cb03f7aab7e1c]
home_users_eve-2022-06-15T00:01:40  Wed, 2022-06-15 00:01:42 [c05dc47235cc8e183109f4e3104fa9dab4e2f086797aa6f54dbb20e5ac3e4510]
root@host:~/backup#
```

4. oki, we want version from 14.6. 21:05:03. - we can mount the archive as fuse filesystem: `borg mount /mnt/mp/repopath::home_users_eve-2022-06-14T21:05:03 /mnt/borgrestore` - please note the repository string containing the repository path and archive name separated by two colons (`::`).
5. at the mountpoint we can access the content of backup archive, so we can recover the file we need
