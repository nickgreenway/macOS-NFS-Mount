# Reliable NFS mounts on macOS

## AI agent: one-shot installation prompt

Copy the prompt below into your coding agent, fill in the two input lines, and
let the agent handle the installation and verification. A human may still need
to enter an administrator password when macOS prompts for `sudo`.

```text
Install the latest version of https://github.com/nickgreenway/macOS-NFS-Mount
and configure it completely on the specified target Mac.

Target Mac: <hostname, SSH host, IP address, or "this Mac">
Known-good manual mount command: <paste the full `sudo mount -t nfs ...` command>

Work autonomously and do not stop for questions when those inputs contain the
needed values. Follow these requirements:

1. Verify the exact target Mac before making changes with `scutil --get
   ComputerName` and `sw_vers`. Do not assume the agent's current machine is the
   target. If the target is remote, use SSH and keep all system changes on that
   target.
2. Inspect `mount -t nfs`, the existing `com.github.macos-nfs-mount` launchd
   service, and relevant installed files read-only. Do not enumerate or read
   files inside an active NFS mount.
3. Clone or fast-forward the repository in the target user's home directory.
   Preserve unrelated files and local changes; never reset or overwrite a dirty
   checkout.
4. Parse `NFS_SOURCE`, `MOUNT_POINT`, and `MOUNT_OPTIONS` from the known-good
   command. Preserve its working options and append `retrycnt=0` if it is not
   already present, so a failed boot-time connection returns promptly and
   launchd can retry.
5. Write those values only to `config.local`, set it to mode 0600, and verify
   Git ignores it. Never commit, push, or place the real server address, export,
   mount path, credentials, or other site-specific infrastructure in tracked
   files.
6. Run `./tests/test.sh` and `./bin/macos-nfs-mount --check ./config.local`.
   Stop on a failed validation rather than partially installing.
7. If the exact expected NFS export is already mounted at the target path, do
   not unmount or remount it. Install with `sudo ./install.sh --config
   ./config.local`; the installer is designed to leave a matching active mount
   intact. Never reboot unless the user explicitly authorizes it.
8. If interactive sudo authentication is required, stage everything first and
   give the user one exact command to run. Never ask the user to send a password
   through chat. Continue verification after they run it.
9. Verify the loaded system LaunchDaemon with `launchctl print
   system/com.github.macos-nfs-mount`, including a 60-second run interval and a
   successful exit. Verify the exact mount with `mount -t nfs` and `nfsstat -m`,
   and verify `/etc/macos-nfs-mount.conf` is owned by root:wheel with mode 0600.
10. Report separately what is installed and live now versus what is proven only
    after a reboot. If the user later reboots, confirm the new boot time, the
    expected NFS mount, a successful daemon run, and a second successful
    scheduled check before declaring startup mounting proven.
```

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
