#!/bin/sh
# Snapshot the current kernel config + boot bits into this repo.
# Usage: scripts/snapshot.sh [srctree]   (default /usr/src/linux)
# Runs as a normal user; source tree is only read. Commits and tags nothing:
# review `git diff`, then commit and `git tag <version>` yourself.
set -eu

REPO=$(cd "$(dirname "$0")/.." && pwd)
SRC=$(readlink -f "${1:-/usr/src/linux}")
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# savedefconfig without writing into the (root-owned) tree.
# kconfig's cc-option probes mkdir in cwd, hence running from $TMP.
(cd "$TMP" && KCONFIG_CONFIG="$SRC/.config" "$REPO/scripts/kconfig-env.sh" "$SRC" \
    --savedefconfig="$REPO/defconfig" 2>/dev/null)
cp "$SRC/.config" "$REPO/config"

cp /etc/default/grub                       "$REPO/boot/grub.default"
cp /etc/dracut.conf.d/90-qcom-firmware.conf "$REPO/boot/dracut.conf.d/"
cp /etc/kernel/postinst.d/20-copy-dtb.install "$REPO/boot/postinst.d/"

if [ -r /proc/config.gz ] && ! zcat /proc/config.gz | cmp -s - "$SRC/.config"; then
    echo "note: running kernel's /proc/config.gz differs from $SRC/.config" >&2
fi

ver=$(make -s -C "$SRC" kernelversion 2>/dev/null || basename "$SRC")
echo "Snapshotted $ver. Review: git -C $REPO diff --stat"
