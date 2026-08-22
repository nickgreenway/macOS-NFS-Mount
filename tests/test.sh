#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/macos-nfs-mount-tests.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

for script in \
    "$REPO_DIR/bin/macos-nfs-mount" \
    "$REPO_DIR/install.sh" \
    "$REPO_DIR/uninstall.sh" \
    "$REPO_DIR/tests/test.sh"
do
    /bin/sh -n "$script"
done

/usr/bin/plutil -lint "$REPO_DIR/launchd/com.github.macos-nfs-mount.plist"

cp "$REPO_DIR/config.example" "$TMP_DIR/valid.conf"
"$REPO_DIR/bin/macos-nfs-mount" --check "$TMP_DIR/valid.conf"

cat >"$TMP_DIR/duplicate.conf" <<'EOF'
NFS_SOURCE=nas.example.net:/exports/media
NFS_SOURCE=other.example.net:/exports/media
MOUNT_POINT=/Volumes/NAS/media
MOUNT_OPTIONS=vers=3,hard
EOF

if "$REPO_DIR/bin/macos-nfs-mount" --check "$TMP_DIR/duplicate.conf" >/dev/null 2>&1; then
    printf '%s\n' "Expected duplicate configuration key to fail" >&2
    exit 1
fi

cat >"$TMP_DIR/relative.conf" <<'EOF'
NFS_SOURCE=nas.example.net:/exports/media
MOUNT_POINT=Volumes/NAS/media
MOUNT_OPTIONS=vers=3,hard
EOF

if "$REPO_DIR/bin/macos-nfs-mount" --check "$TMP_DIR/relative.conf" >/dev/null 2>&1; then
    printf '%s\n' "Expected relative mount point to fail" >&2
    exit 1
fi

private_ip='10.0.50.'"40"
private_export='/var/nfs/shared/'"media"
private_mount='/Volumes/Europa/'"media"
if /usr/bin/grep -R -n -F \
    --exclude-dir=.git \
    --exclude=config.local \
    -e "$private_ip" \
    -e "$private_export" \
    -e "$private_mount" \
    "$REPO_DIR"
then
    printf '%s\n' "Private infrastructure value found in tracked project content" >&2
    exit 1
fi

printf '%s\n' "All tests passed."
