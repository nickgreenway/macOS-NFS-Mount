# Reliable NFS mounts on macOS

This project installs a small root-owned `launchd` service that mounts an NFS
export after startup and retries when the Mac starts before the network or NFS
server is ready.

The repository contains no site-specific addresses or paths. Your NFS server,
export, mount point, and options live in a local configuration file that is
ignored by Git and is installed on the Mac as `/etc/macos-nfs-mount.conf` with
mode `0600`.

## Why the old version was unreliable

The original LaunchDaemon used `RunAtLoad` by itself. That gives the mount one
chance during boot. If networking or the NFS server is not ready at that exact
moment, the command fails and is never attempted again.

The current service:

- runs once when loaded and retries every 60 seconds;
- exits immediately when the expected export is already mounted;
- refuses to mount over a different filesystem at the configured path;
- uses absolute executable paths, which `launchd` jobs need;
- keeps private infrastructure values out of the public repository; and
- uses current `launchctl bootstrap` and `kickstart` commands.

## Requirements

- macOS with NFS client support
- an NFS export reachable from the Mac
- an administrator account (`resvport` mounts require root)

## Install

Clone the repository, then make a private local configuration:

```sh
git clone https://github.com/nickgreenway/macOS-NFS-Mount.git
cd macOS-NFS-Mount
cp config.example config.local
chmod 600 config.local
```

Edit `config.local`:

```ini
NFS_SOURCE=nas.example.net:/exports/media
MOUNT_POINT=/Volumes/NAS/media
MOUNT_OPTIONS=vers=3,resvport,hard,rw,nfc,rsize=65536,wsize=65536,timeo=600,retrycnt=0
```

Use the same source, mount point, and options that work with your manual
`mount -t nfs` command. `retrycnt=0` limits a failed initial connection attempt
so the LaunchDaemon can try again on its next interval rather than remaining
stuck for a long time.

Validate and install:

```sh
./bin/macos-nfs-mount --check ./config.local
sudo ./install.sh --config ./config.local
```

The installer does not unmount an active share. It installs the service and
asks it to run; if the expected share is already mounted, the service exits
successfully without changing it.

## Verify

Inspect the service:

```sh
sudo launchctl print system/com.github.macos-nfs-mount
```

Inspect active NFS mounts and their negotiated options:

```sh
mount -t nfs
nfsstat -m
```

Inspect recent service messages:

```sh
log show --last 10m --predicate 'senderImagePath ENDSWITH "/logger" AND eventMessage CONTAINS "macos-nfs-mount"'
```

After a reboot, the mount may take up to 60 seconds to appear if the first
attempt happens before the network or server is ready.

## Update an installation

Pull the repository and run the installer again. The root-owned configuration
is replaced only by the file you explicitly pass with `--config`.

```sh
git pull --ff-only
sudo ./install.sh --config ./config.local
```

## Uninstall

```sh
sudo ./uninstall.sh
```

This unloads the LaunchDaemon and removes the installed script and plist. It
preserves `/etc/macos-nfs-mount.conf` by default and does not unmount an active
share. To remove the installed configuration too, use:

```sh
sudo ./uninstall.sh --remove-config
```

## Privacy and public repositories

Private RFC1918 addresses such as `10.x.x.x` are not directly reachable from
the public internet, but publishing them can still reveal network layout,
hostnames, exports, and naming conventions. Keep those values in
`config.local`, which this repository ignores, and commit only
`config.example` with fictional values.

Before every public commit, run:

```sh
./tests/test.sh
git diff --cached
```

The test suite includes a guard against accidentally committing the original
author's current infrastructure values. Remember that deleting a value in a
later commit does not remove it from existing Git history.

## NFS safety note

`hard` mounts prioritize data integrity, but file operations can wait
indefinitely while the server is unavailable. That is usually appropriate for
writable media, but it can also make applications appear hung during an NFS
outage. Choose mount options deliberately for your workload.
