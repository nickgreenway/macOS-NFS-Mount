#!/bin/sh

set -eu

LABEL="com.github.macos-nfs-mount"
INSTALL_SCRIPT="/usr/local/libexec/macos-nfs-mount"
INSTALL_CONFIG="/etc/macos-nfs-mount.conf"
INSTALL_PLIST="/Library/LaunchDaemons/$LABEL.plist"
REMOVE_CONFIG=false

usage() {
    cat <<'EOF'
Usage: sudo ./uninstall.sh [--remove-config]

The active NFS share is not unmounted. The root-owned configuration is kept
unless --remove-config is supplied.
EOF
}

case "${1:-}" in
    "") ;;
    --remove-config) REMOVE_CONFIG=true ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
esac

[ "$#" -le 1 ] || { usage >&2; exit 64; }
[ "$(/usr/bin/id -u)" -eq 0 ] || { printf '%s\n' "Run this uninstaller with sudo." >&2; exit 1; }

if /bin/launchctl print "system/$LABEL" >/dev/null 2>&1; then
    /bin/launchctl bootout "system/$LABEL"
fi

/bin/rm -f "$INSTALL_PLIST" "$INSTALL_SCRIPT"
if [ "$REMOVE_CONFIG" = true ]; then
    /bin/rm -f "$INSTALL_CONFIG"
fi

printf 'Removed %s. The active NFS share, if any, was left mounted.\n' "$LABEL"
if [ "$REMOVE_CONFIG" = false ] && [ -f "$INSTALL_CONFIG" ]; then
    printf 'Preserved %s.\n' "$INSTALL_CONFIG"
fi
