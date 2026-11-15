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
| `patches/` | locally carried patches (see below) |
| `scripts/snapshot.sh` | refresh everything above from the live system |
| `scripts/kernel-debug-config.sh` | enables lockup detectors / pstore / GPU crash state |

## Updating

```sh
scripts/snapshot.sh            # reads /usr/src/linux, writes into the repo
git diff
git commit -am "7.3.5-gentoo" && git tag 7.3.5
```

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

| Patch | Status |
|---|---|
| `i2c-qcom-geni-restore-clk-sel.patch` | Backport of upstream 8cb5c17be3a2. Fixes the dead keyboard/touchpad from cb97bf3d4f91. Already in the 7.3.x trees. Keep it for reference. |
| `tsens-drop-init.patch` | Drops `__init` from `tsens.c:init_common()`. Present in all 7.3.x trees here; check whether that's upstream or hand-applied before relying on it. |

## History

Starts at 7.3.4 (2026-11-14). Earlier kernels deliberately not tracked.
