#!/bin/sh
# Build + install the kernel tree you're standing in, then record it in this repo.
#
#   emerge -uDN @world                             # pulls the new gentoo-sources
#   cd /usr/src/linux-X.Y.Z-gentoo
#   kernel-update   # symlink in /usr/local/sbin -> /home/saurav/workspace/kernel-config/scripts/kernel-update.sh [-y]
#
# Run as root. -y skips the "new symbols, continue?" prompt.
# JOBS=N overrides the default of -j10.
set -eu

REPO=$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)
OWNER=$(stat -c %U "$REPO")
JOBS=${JOBS:-10}
YES=0; [ "${1:-}" = "-y" ] && YES=1

die() { echo "kernel-update: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die "run as root"
[ -f Kconfig ] && [ -f Makefile ] && grep -q '^PATCHLEVEL' Makefile || die "not in a kernel source tree"

SRC=$(pwd -P)
NAME=$(basename "$SRC")
ver=$(make -s kernelversion)

# 1. Config: keep an existing .config, otherwise start from the last tracked one.
if [ -f .config ]; then
    echo ">> using existing $SRC/.config"
else
    echo ">> seeding .config from $REPO/config"
    cp "$REPO/config" .config
fi

new=$(make -s listnewconfig 2>/dev/null || true)
if [ -n "$new" ]; then
    echo ">> new symbols in $ver (taking defaults):"
    echo "$new" | sed 's/^/   /'
    if [ $YES = 0 ]; then
        printf 'continue? [y/N] '; read -r a; [ "$a" = y ] || die "stopped; run 'make oldconfig' to answer them by hand"
    fi
fi
make -s olddefconfig

# 2. /usr/src/linux must point here before 'make install' (the DTB hook copies from it).
eselect kernel set "$NAME"

# 3. Build and install. make install -> installkernel -> dracut + grub + DTB hook.
make -j"$JOBS"
make -j"$JOBS" modules_install
make install

# 4. Record it. Git runs as the repo owner, so root never owns files in the repo.
echo ">> snapshotting into $REPO"
runuser -u "$OWNER" -- "$REPO/scripts/snapshot.sh" "$SRC"
cd "$REPO"
if runuser -u "$OWNER" -- git diff --quiet; then
    echo ">> config unchanged since last commit"
else
    runuser -u "$OWNER" -- git commit -qam "$ver-gentoo"
fi
runuser -u "$OWNER" -- git tag -f "$ver" >/dev/null
runuser -u "$OWNER" -- git push -q origin main 2>/dev/null &&
runuser -u "$OWNER" -- git push -qf origin "$ver" 2>/dev/null &&
    echo ">> pushed $ver" ||
    echo ">> push failed; as $OWNER: cd $REPO && git push && git push -f origin $ver"

echo ">> done: $ver installed. Reboot when ready."
