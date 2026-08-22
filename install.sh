#!/bin/sh

set -eu

LABEL="com.github.macos-nfs-mount"
INSTALL_SCRIPT="/usr/local/libexec/macos-nfs-mount"
INSTALL_CONFIG="/etc/macos-nfs-mount.conf"
INSTALL_PLIST="/Library/LaunchDaemons/$LABEL.plist"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SOURCE_SCRIPT="$SCRIPT_DIR/bin/macos-nfs-mount"
SOURCE_PLIST="$SCRIPT_DIR/launchd/$LABEL.plist"
CONFIG_FILE=""

usage() {
    cat <<'EOF'
Usage: sudo ./install.sh --config CONFIG_FILE

Installs the retrying NFS LaunchDaemon. CONFIG_FILE is copied to
/etc/macos-nfs-mount.conf with root-only permissions.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --config)
            [ "$#" -ge 2 ] || { usage >&2; exit 64; }
            CONFIG_FILE=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac
done

[ -n "$CONFIG_FILE" ] || { usage >&2; exit 64; }
[ "$(/usr/bin/id -u)" -eq 0 ] || { printf '%s\n' "Run this installer with sudo." >&2; exit 1; }
[ -f "$SOURCE_SCRIPT" ] || { printf 'Missing %s\n' "$SOURCE_SCRIPT" >&2; exit 1; }
[ -f "$SOURCE_PLIST" ] || { printf 'Missing %s\n' "$SOURCE_PLIST" >&2; exit 1; }

"$SOURCE_SCRIPT" --check "$CONFIG_FILE"
/usr/bin/plutil -lint "$SOURCE_PLIST"

if /bin/launchctl print "system/$LABEL" >/dev/null 2>&1; then
    /bin/launchctl bootout "system/$LABEL"
fi

/usr/bin/install -d -o root -g wheel -m 0755 /usr/local/libexec
/usr/bin/install -o root -g wheel -m 0755 "$SOURCE_SCRIPT" "$INSTALL_SCRIPT"
/usr/bin/install -o root -g wheel -m 0600 "$CONFIG_FILE" "$INSTALL_CONFIG"
/usr/bin/install -o root -g wheel -m 0644 "$SOURCE_PLIST" "$INSTALL_PLIST"

/bin/launchctl bootstrap system "$INSTALL_PLIST"
/bin/launchctl enable "system/$LABEL"
/bin/launchctl kickstart -k "system/$LABEL"

printf '\nInstalled %s.\n' "$LABEL"
printf 'The service retries every 60 seconds until the configured NFS export is mounted.\n'
printf 'Verify with:\n  sudo launchctl print system/%s\n  mount -t nfs\n  nfsstat -m\n' "$LABEL"
