# kernel-config

Gentoo `gentoo-sources` kernel config for a Lenovo Yoga Slim 7x
(Snapdragon X Elite, x1e80100, `LENOVO/83ED`), aarch64.

One tag per kernel version. Compare with `git diff 7.3.3 7.3.4 -- defconfig`.

## Layout

| Path | What |
|---|---|
| `defconfig` | `make savedefconfig` output. The file to read and diff. |
| `config` | Full `.config`. Restore with `cp config /usr/src/linux/.config && make olddefconfig`. |
| `boot/grub.default` | `/etc/default/grub` (cmdline lives here) |
| `boot/dracut.conf.d/` | firmware + early drivers for the initramfs |
| `boot/postinst.d/` | copies the yoga-slim7x DTB into `/boot/dtbs` after install |
| `scripts/kernel-update.sh` | build + install the tree you're in, snapshot, commit, tag, push |
| `scripts/snapshot.sh` | refresh everything above from the live system |
| `scripts/kernel-debug-config.sh` | enables lockup detectors / pstore / GPU crash state |

## Updating

New kernel, as root:

```sh
emerge -uDN @world            # new gentoo-sources lands in its own /usr/src dir
cd /usr/src/linux-X.Y.Z-gentoo
kernel-update   # symlink in /usr/local/sbin -> /home/saurav/workspace/kernel-config/scripts/kernel-update.sh
```

It seeds `.config` from this repo if the tree has none, lists new symbols and asks
before taking their defaults (`-y` skips the prompt), runs `eselect kernel set`,
builds, runs `modules_install` and `make install` (dracut, grub, DTB hook), then commits, tags
and pushes the result as the repo owner.

To snapshot without building: `scripts/snapshot.sh`, then commit and tag yourself.

The script runs kconfig's `conf` directly with srctree pointed at the root-owned
tree, so it needs no root and writes nothing into `/usr/src`.

## Why the odd bits

Cmdline (`boot/grub.default`):

- `clk_ignore_unused pd_ignore_unused`: needed for boot and the video codec.
  Without them, unused-clock/PD cleanup kills things firmware left running.
- `efi=noruntime`: TODO, reason not recorded (presumably flaky EFI runtime services on X1E).
- `sbsa_gwdt.timeout=60`, `reserve_mem=…:oops`, `ramoops.*`,
  `panic_on_rcu_stall=1`, `log_buf_len=16M`: diagnostics for the silent
  hang/reset (GMU stops answering GX_BW_PERF_VOTE → GPU hang → SoC reset).
  Panics land in pstore (`/sys/fs/pstore/`) and survive the reset.
- `cma=128M`: TODO, reason not recorded.

Elsewhere:

- `typec_displayport` is no longer blacklisted (dropped 2026-11-14; the Belkin
  dock runs over a USB2-only cable, so no alt-mode is possible). On a SuperSpeed
  cable, UCSI enters DP alt-mode and the dock's USB disappears. Fix:
  `echo 'blacklist typec_displayport' > /etc/modprobe.d/no-typec-dp.conf`, then rerun dracut.
- dracut firmware list: the GPU (`gen70500_*`), BT, ath12k and board firmware
  must be in the initramfs or those devices probe without firmware.

## Patches

None. 7.3.4 is stock gentoo-sources (verified with `qcheck sys-kernel/gentoo-sources`).
If a kernel patch is ever needed, put it in
`/etc/portage/patches/sys-kernel/gentoo-sources/` so it is reapplied on every emerge,
not hand-applied to `/usr/src`, where a re-emerge silently drops it.

## History

Starts at 7.3.4 (2026-11-14). Earlier kernels deliberately not tracked.
